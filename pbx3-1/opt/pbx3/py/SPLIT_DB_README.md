# SQLite Database Split Utility

A Python utility to split a SQLite database into multiple sub-databases based on cluster/tenant identifiers. This is designed for the PBX3 database schema.

## Features

- **Automatic Schema Detection**: Parses the SQL schema file to identify table structures
- **Cluster-Based Splitting**: Separates data by cluster/tenant while preserving relationships
- **Foreign Key Handling**: Automatically handles dependent tables (e.g., `IPphone_FKEY`, `IPphoneCOSopen`)
- **Global Table Preservation**: Copies global tables (like `Device`, `COS`, `globals`) to all sub-databases
- **Data Integrity**: Maintains referential integrity across related tables

## Requirements

- Python 3.6 or higher
- SQLite3 (usually included with Python)

## Usage

### Basic Usage

Split all clusters into separate databases:

```bash
python /opt/pbx3/py/split_db.py /opt/pbx3/db/sqlite.db /opt/pbx3/db/db_v4_create.sql
```

### Split Specific Clusters

Only split certain clusters:

```bash
python /opt/pbx3/py/split_db.py /opt/pbx3/db/sqlite.db /opt/pbx3/db/db_v4_create.sql --clusters default,tenant1,tenant2
```

### Specify Output Directory

Save sub-databases to a specific directory:

```bash
python /opt/pbx3/py/split_db.py /opt/pbx3/db/sqlite.db /opt/pbx3/db/db_v4_create.sql --output-dir ./output
```

## How It Works

1. **Schema Analysis**: The script parses the SQL schema file to identify:
   - Tables with `cluster` columns (cluster-specific data)
   - Tables without `cluster` columns (global data)
   - Foreign key relationships between tables

2. **Cluster Discovery**: Reads all clusters from the `Cluster` table

3. **Database Creation**: For each cluster:
   - Creates a new SQLite database file (`sark_<cluster>.db`)
   - Applies the full schema from the SQL file
   - Copies global tables (shared across all clusters)
   - Copies cluster-specific data for that cluster
   - Copies related foreign key data

## Output

The utility creates one database file per cluster in the format:
- `<cluster_name>.db`

For example:
- `default.db`
- `tenant1.db`
- `tenant2.db`

## Table Classification

### Cluster-Specific Tables
These tables are split by cluster (only data matching the cluster is copied):
- `Agent`
- `Appl`
- `Cluster`
- `Greeting`
- `Holiday`
- `IPphone`
- `Queue`
- `Route`
- `callback`
- `dateSeg`
- `ivrmenu`
- `lineIO`
- `meetme`
- `speed`
- `User`
- And others with a `cluster` column

### Global Tables
These tables are copied to all sub-databases:
- `COS`
- `Carrier`
- `Device`
- `Device_FKEY`
- `globals`
- `mfgmac`
- `mcast`
- `page`
- `Panel`
- `PanelGroup`
- `PanelGroupPanel`
- `threat`
- `tt_help_core`
- `shorewall_blacklist`
- `shorewall_whitelist`
- `clid_blacklist`
- And others without a `cluster` column

### Foreign Key Tables
These tables are handled specially to maintain relationships:
- `IPphone_FKEY` → references `IPphone`
- `IPphoneCOSopen` → references `IPphone` and `COS`
- `IPphoneCOSclosed` → references `IPphone` and `COS`
- `UserPanel` → references `User` and `Panel`
- `PanelGroupPanel` → references `PanelGroup` and `Panel`

## Notes

- The original database is **not modified** - it remains intact
- Sub-databases are created with the full schema, including all triggers and constraints
- If a sub-database file already exists, it will be overwritten
- NULL cluster values are included in the 'default' cluster split
- The script provides progress output showing what's being copied

## Troubleshooting

### "No clusters found"
- Verify the source database has a `Cluster` table with data
- Check that the database path is correct

### "Schema file not found"
- Ensure the path to `db_v4_create.sql` is correct
- The schema file should be the same version as the database

### Foreign Key Errors
- The script attempts to maintain referential integrity
- If errors occur, check that related data exists in the source database

## Example Output

```
Splitting database: /opt/sark/db/sark.db
Schema file: /opt/sark/db/db_v4_create.sql
Output directory: /opt/sark/db

Found 35 tables:
  - 18 cluster-specific tables
  - 17 global tables

Found 2 cluster(s) to process: default, tenant1

Processing cluster: default
  Copying global tables...
  Copied 12 rows from global table: Device
  Copied 5 rows from global table: COS
  ...
  Copying cluster-specific data for default...
  Copied Cluster record: default
  Copied 45 rows from IPphone for cluster default
  ...
  Copying foreign key relationships...
  Copied 120 rows from IPphone_FKEY (FK relationships)
  ✓ Completed cluster: default

Processing cluster: tenant1
  ...
  ✓ Completed cluster: tenant1

✓ Database split complete!
  Created 2 sub-database(s) in /opt/sark/db
  Files:
    - default.db (2.45 MB)
    - tenant1.db (1.87 MB)
```

