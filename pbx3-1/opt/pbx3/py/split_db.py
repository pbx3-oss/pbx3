#!/usr/bin/env python3
"""
SQLite Database Split Utility

This utility splits a SQLite database into multiple sub-databases based on
cluster/tenant identifiers. It preserves schema, relationships, and data integrity.

Usage:
    python split_db.py <source_db> <schema_file> [--output-dir <dir>] [--clusters <cluster1,cluster2,...>]
"""

import sqlite3
import argparse
import os
import sys
import re
from pathlib import Path
from typing import Dict, List, Set, Tuple, Optional


class DatabaseSplitter:
    """Splits an SQLite database by cluster/tenant."""
    
    def __init__(self, source_db: str, schema_file: str, output_dir: str = None):
        self.source_db = source_db
        self.schema_file = schema_file
        self.output_dir = output_dir or os.path.dirname(source_db)
        self.source_conn = None
        self.tables_info = {}
        self.cluster_tables = set()
        self.global_tables = set()
        self.foreign_key_tables = {}  # table -> list of (foreign_table, foreign_column)
        
    def connect(self):
        """Connect to source database."""
        if not os.path.exists(self.source_db):
            raise FileNotFoundError(f"Source database not found: {self.source_db}")
        self.source_conn = sqlite3.connect(self.source_db)
        self.source_conn.row_factory = sqlite3.Row
        
    def close(self):
        """Close database connection."""
        if self.source_conn:
            self.source_conn.close()
            
    def parse_schema(self):
        """Parse the schema file to identify tables and their structure."""
        if not os.path.exists(self.schema_file):
            raise FileNotFoundError(f"Schema file not found: {self.schema_file}")
            
        with open(self.schema_file, 'r') as f:
            schema_content = f.read()
            
        # Extract table definitions
        table_pattern = r'CREATE TABLE IF NOT EXISTS (\w+)\s*\((.*?)\);'
        matches = re.finditer(table_pattern, schema_content, re.DOTALL | re.IGNORECASE)
        
        for match in matches:
            table_name = match.group(1)
            table_def = match.group(2)
            
            # Check if table has cluster column
            has_cluster = 'cluster' in table_def.lower()
            
            # Extract column names
            columns = []
            for line in table_def.split('\n'):
                line = line.strip()
                if line and not line.startswith('--') and not line.startswith('PRIMARY KEY') and not line.startswith('UNIQUE'):
                    # Extract column name (first word before space or comma)
                    col_match = re.match(r'^(\w+)', line)
                    if col_match:
                        columns.append(col_match.group(1))
            
            self.tables_info[table_name] = {
                'columns': columns,
                'has_cluster': has_cluster,
                'definition': match.group(0)
            }
            
            if has_cluster:
                self.cluster_tables.add(table_name)
            else:
                self.global_tables.add(table_name)
        
        # Identify foreign key relationships
        self._identify_foreign_keys()
        
        print(f"Found {len(self.tables_info)} tables:")
        print(f"  - {len(self.cluster_tables)} cluster-specific tables")
        print(f"  - {len(self.global_tables)} global tables")
        
    def _identify_foreign_keys(self):
        """Identify foreign key relationships between tables."""
        # Common patterns: table_pkey references table.pkey
        # e.g., IPphone_FKEY.pkey references IPphone.pkey
        for table_name, info in self.tables_info.items():
            fk_relations = []
            
            # Check for composite foreign keys (e.g., IPphone_FKEY references IPphone)
            if '_FKEY' in table_name:
                base_table = table_name.replace('_FKEY', '')
                if base_table in self.tables_info:
                    fk_relations.append((base_table, 'pkey'))
            
            # Check for other common patterns
            # IPphoneCOSopen, IPphoneCOSclosed reference IPphone
            if 'IPphoneCOS' in table_name:
                fk_relations.append(('IPphone', 'pkey'))
                fk_relations.append(('COS', 'pkey'))
            
            # UserPanel references User and Panel
            if table_name == 'UserPanel':
                fk_relations.append(('User', 'pkey'))
                fk_relations.append(('Panel', 'pkey'))
            
            # PanelGroupPanel references PanelGroup and Panel
            if table_name == 'PanelGroupPanel':
                fk_relations.append(('PanelGroup', 'pkey'))
                fk_relations.append(('Panel', 'pkey'))
            
            if fk_relations:
                self.foreign_key_tables[table_name] = fk_relations
    
    def get_clusters(self, filter_clusters: List[str] = None) -> List[str]:
        """Get list of clusters from the database."""
        cursor = self.source_conn.cursor()
        cursor.execute("SELECT pkey FROM Cluster ORDER BY pkey")
        clusters = [row[0] for row in cursor.fetchall()]
        
        if filter_clusters:
            clusters = [c for c in clusters if c in filter_clusters]
            
        return clusters
    
    def create_sub_database(self, cluster: str) -> sqlite3.Connection:
        """Create a new sub-database for a cluster with full schema."""
        db_path = os.path.join(self.output_dir, f"{cluster}.db")
        
        # Remove existing database if it exists
        if os.path.exists(db_path):
            os.remove(db_path)
        
        conn = sqlite3.connect(db_path)
        
        # Read and execute schema
        with open(self.schema_file, 'r') as f:
            schema_sql = f.read()
        
        # Execute schema creation
        conn.executescript(schema_sql)
        conn.commit()
        
        return conn
    
    def copy_global_tables(self, target_conn: sqlite3.Connection):
        """Copy global tables (no cluster column) to target database."""
        cursor = self.source_conn.cursor()
        target_cursor = target_conn.cursor()
        
        for table_name in self.global_tables:
            if table_name == 'Cluster':
                continue  # Handle Cluster separately
            
            # Skip tables that are handled in foreign key section to avoid duplicates
            # But keep PanelGroupPanel as it's truly global
            if table_name in self.foreign_key_tables and table_name != 'PanelGroupPanel':
                continue
            
            try:
                # Get all data from source
                cursor.execute(f"SELECT * FROM {table_name}")
                rows = cursor.fetchall()
                
                if not rows:
                    continue
                
                # Get column names
                columns = [description[0] for description in cursor.description]
                placeholders = ','.join(['?' for _ in columns])
                column_names = ','.join(columns)
                
                # Insert into target
                insert_sql = f"INSERT INTO {table_name} ({column_names}) VALUES ({placeholders})"
                target_cursor.executemany(insert_sql, rows)
                
                print(f"  Copied {len(rows)} rows from global table: {table_name}")
            except sqlite3.Error as e:
                print(f"  Warning: Could not copy {table_name}: {e}")
        
        target_conn.commit()
    
    def copy_cluster_data(self, target_conn: sqlite3.Connection, cluster: str):
        """Copy cluster-specific data to target database."""
        cursor = self.source_conn.cursor()
        target_cursor = target_conn.cursor()
        
        # First, copy the Cluster record itself
        cursor.execute("SELECT * FROM Cluster WHERE pkey = ?", (cluster,))
        cluster_row = cursor.fetchone()
        if cluster_row:
            columns = [description[0] for description in cursor.description]
            placeholders = ','.join(['?' for _ in columns])
            column_names = ','.join(columns)
            insert_sql = f"INSERT INTO Cluster ({column_names}) VALUES ({placeholders})"
            target_cursor.execute(insert_sql, cluster_row)
            print(f"  Copied Cluster record: {cluster}")
        
        # Copy cluster-specific tables
        for table_name in self.cluster_tables:
            if table_name == 'Cluster':
                continue  # Already handled
            
            try:
                # Check if table exists and has cluster column
                cursor.execute(f"PRAGMA table_info({table_name})")
                columns_info = cursor.fetchall()
                has_cluster_col = any(col[1].lower() == 'cluster' for col in columns_info)
                
                if not has_cluster_col:
                    continue
                
                # Get data for this cluster (including NULL cluster values for 'default' cluster)
                if cluster == 'default':
                    cursor.execute(f"SELECT * FROM {table_name} WHERE cluster = ? OR cluster IS NULL", (cluster,))
                else:
                    cursor.execute(f"SELECT * FROM {table_name} WHERE cluster = ?", (cluster,))
                rows = cursor.fetchall()
                
                if not rows:
                    continue
                
                # Get column names
                columns = [description[0] for description in cursor.description]
                placeholders = ','.join(['?' for _ in columns])
                column_names = ','.join(columns)
                
                # Insert into target
                insert_sql = f"INSERT INTO {table_name} ({column_names}) VALUES ({placeholders})"
                target_cursor.executemany(insert_sql, rows)
                
                print(f"  Copied {len(rows)} rows from {table_name} for cluster {cluster}")
            except sqlite3.Error as e:
                print(f"  Warning: Could not copy {table_name} for cluster {cluster}: {e}")
        
        target_conn.commit()
    
    def copy_foreign_key_data(self, target_conn: sqlite3.Connection, cluster: str):
        """Copy data from tables with foreign key relationships."""
        cursor = self.source_conn.cursor()
        target_cursor = target_conn.cursor()
        
        for table_name, fk_relations in self.foreign_key_tables.items():
            try:
                # Check if table exists
                cursor.execute(f"SELECT name FROM sqlite_master WHERE type='table' AND name='{table_name}'")
                if not cursor.fetchone():
                    continue
                
                # Build query to get related data
                # For tables like IPphone_FKEY, we need to get rows where the referenced
                # IPphone belongs to this cluster
                if table_name == 'IPphone_FKEY':
                    # Get all IPphone pkeys for this cluster
                    cursor.execute("SELECT pkey FROM IPphone WHERE cluster = ?", (cluster,))
                    ipphone_pkeys = {row[0] for row in cursor.fetchall()}
                    
                    if not ipphone_pkeys:
                        continue
                    
                    # Get FKEY rows for these IPphones
                    placeholders = ','.join(['?' for _ in ipphone_pkeys])
                    cursor.execute(f"SELECT * FROM {table_name} WHERE pkey IN ({placeholders})", 
                                  list(ipphone_pkeys))
                    rows = cursor.fetchall()
                    
                elif table_name in ['IPphoneCOSopen', 'IPphoneCOSclosed']:
                    # Get IPphone pkeys for this cluster
                    cursor.execute("SELECT pkey FROM IPphone WHERE cluster = ?", (cluster,))
                    ipphone_pkeys = {row[0] for row in cursor.fetchall()}
                    
                    if not ipphone_pkeys:
                        continue
                    
                    placeholders = ','.join(['?' for _ in ipphone_pkeys])
                    cursor.execute(f"SELECT * FROM {table_name} WHERE IPphone_pkey IN ({placeholders})", 
                                  list(ipphone_pkeys))
                    rows = cursor.fetchall()
                    
                elif table_name == 'UserPanel':
                    # Get User pkeys for this cluster
                    cursor.execute("SELECT pkey FROM User WHERE cluster = ?", (cluster,))
                    user_pkeys = {row[0] for row in cursor.fetchall()}
                    
                    if not user_pkeys:
                        continue
                    
                    placeholders = ','.join(['?' for _ in user_pkeys])
                    cursor.execute(f"SELECT * FROM {table_name} WHERE User_pkey IN ({placeholders})", 
                                  list(user_pkeys))
                    rows = cursor.fetchall()
                    
                else:
                    # Generic: get all rows (may need refinement)
                    cursor.execute(f"SELECT * FROM {table_name}")
                    rows = cursor.fetchall()
                
                if not rows:
                    continue
                
                # Get column names
                columns = [description[0] for description in cursor.description]
                placeholders = ','.join(['?' for _ in columns])
                column_names = ','.join(columns)
                
                # Insert into target
                insert_sql = f"INSERT INTO {table_name} ({column_names}) VALUES ({placeholders})"
                target_cursor.executemany(insert_sql, rows)
                
                print(f"  Copied {len(rows)} rows from {table_name} (FK relationships)")
            except sqlite3.Error as e:
                print(f"  Warning: Could not copy {table_name}: {e}")
        
        target_conn.commit()
    
    def split_database(self, filter_clusters: List[str] = None):
        """Split the database into sub-databases by cluster."""
        print(f"\nSplitting database: {self.source_db}")
        print(f"Schema file: {self.schema_file}")
        print(f"Output directory: {self.output_dir}\n")
        
        # Parse schema
        self.parse_schema()
        
        # Get clusters
        clusters = self.get_clusters(filter_clusters)
        
        if not clusters:
            print("No clusters found to split.")
            return
        
        print(f"\nFound {len(clusters)} cluster(s) to process: {', '.join(clusters)}\n")
        
        # Process each cluster
        for cluster in clusters:
            print(f"Processing cluster: {cluster}")
            
            # Create sub-database
            target_conn = self.create_sub_database(cluster)
            
            try:
                # Copy global tables
                print("  Copying global tables...")
                self.copy_global_tables(target_conn)
                
                # Copy cluster-specific data
                print(f"  Copying cluster-specific data for {cluster}...")
                self.copy_cluster_data(target_conn, cluster)
                
                # Copy foreign key relationships
                print("  Copying foreign key relationships...")
                self.copy_foreign_key_data(target_conn, cluster)
                
                print(f"  ✓ Completed cluster: {cluster}\n")
            finally:
                target_conn.close()
        
        print(f"\n✓ Database split complete!")
        print(f"  Created {len(clusters)} sub-database(s) in {self.output_dir}")
        print(f"  Files:")
        for cluster in clusters:
            db_path = os.path.join(self.output_dir, f"{cluster}.db")
            if os.path.exists(db_path):
                size = os.path.getsize(db_path)
                size_mb = size / (1024 * 1024)
                print(f"    - {cluster}.db ({size_mb:.2f} MB)")


def main():
    parser = argparse.ArgumentParser(
        description='Split SQLite database into sub-databases by cluster/tenant',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Split all clusters
  python split_db.py /opt/sark/db/sark.db /opt/sark/db/db_v4_create.sql
  
  # Split specific clusters
  python split_db.py /opt/sark/db/sark.db /opt/sark/db/db_v4_create.sql --clusters default,tenant1
  
  # Specify output directory
  python split_db.py /opt/sark/db/sark.db /opt/sark/db/db_v4_create.sql --output-dir ./output
        """
    )
    
    parser.add_argument('source_db', help='Path to source SQLite database')
    parser.add_argument('schema_file', help='Path to SQL schema file (db_v4_create.sql)')
    parser.add_argument('--output-dir', '-o', help='Output directory for sub-databases (default: same as source)')
    parser.add_argument('--clusters', '-c', help='Comma-separated list of clusters to split (default: all)')
    
    args = parser.parse_args()
    
    # Parse cluster filter
    filter_clusters = None
    if args.clusters:
        filter_clusters = [c.strip() for c in args.clusters.split(',')]
    
    # Create splitter and run
    splitter = DatabaseSplitter(args.source_db, args.schema_file, args.output_dir)
    
    try:
        splitter.connect()
        splitter.split_database(filter_clusters)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
    finally:
        splitter.close()


if __name__ == '__main__':
    main()

