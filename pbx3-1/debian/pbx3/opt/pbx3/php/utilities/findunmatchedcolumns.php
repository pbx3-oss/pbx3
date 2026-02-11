<?php

/**
 * 
 * $db = new SQLite3('path/to/database.db');
 * $srcroot = '/path/to/source/tree';
 * $outputFile = 'output.sql';
 *
 * getUnmatchedColumnsAndGenerateSQL($db, $srcroot, $outputFile);
 * 
 * 
 */


 function getUnmatchedColumnsAndGenerateSQL($dbFileName, $tableName, $srcroot, $outputFile) {
     // Open the SQLite3 database
     $db = new SQLite3($dbFileName);
 
     // Prepare the output file
     $fileHandle = fopen($outputFile, 'w');
     if (!$fileHandle) {
         throw new Exception("Unable to open file: $outputFile");
     }
 
     // Step 1: Retrieve all column names from the specified table in the SQLite3 database
     $columns = [];
     $columnsResult = $db->query("PRAGMA table_info($tableName)");
     while ($columnRow = $columnsResult->fetchArray(SQLITE3_ASSOC)) {
         $columns[] = [
             'table' => $tableName,
             'name' => $columnRow['name']
         ];
     }
 
     // Step 2: Search each column name within the source tree
     foreach ($columns as $column) {
         $columnName = $column['name'];
         $found = false;
 
         $directory = new RecursiveDirectoryIterator($srcroot);
         $iterator = new RecursiveIteratorIterator($directory);
         foreach ($iterator as $file) {
             if ($file->isFile()) {
                 $contents = file_get_contents($file->getPathname());
                 if (strpos($contents, $columnName) !== false) {
                     $found = true;
                     break;
                 }
             }
         }
 
         // Step 3: Generate ALTER TABLE DROP COLUMN statement if not found
         if (!$found) {
             $alterStatement = "ALTER TABLE $tableName DROP COLUMN $columnName;";
             fwrite($fileHandle, $alterStatement . PHP_EOL);
         }
     }
 
     // Close the file handle
     fclose($fileHandle);
 }
 
 // Command line interface for the script
 if ($argc !== 5) {
     echo "Usage: php script.php <database_file> <table_name> <source_tree_root> <output_file>\n";
     exit(1);
 }
 
 $dbFileName = $argv[1];
 $tableName = $argv[2];
 $srcroot = $argv[3];
 $outputFile = $argv[4];
 
 try {
     getUnmatchedColumnsAndGenerateSQL($dbFileName, $tableName, $srcroot, $outputFile);
     echo "SQL statements written to $outputFile\n";
 } catch (Exception $e) {
     echo "Error: " . $e->getMessage() . "\n";
     exit(1);
 }
 ?>
 