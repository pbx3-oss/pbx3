<?php

require 'aws/aws-autoloader.php'; //path to autoloader.php
require '../s3_config.php'; //file to be created outside the root to store aws key + secret

use Aws\S3\S3Client;
use Aws\Exception\AwsException;

class S3 {
    private $bucket;
    private $client;

    public function __construct($bucket, $region, $verify = true) {
        $this->bucket = $bucket;
        $this->client = new S3Client([
            'version' => 'latest',
            'region' => $region,
            'http' => ['verify' => $verify],
            'credentials' => [
                'key' => AWS_KEY,
                'secret' => AWS_SECRET
            ]
        ]);

        if (!$this->client->doesBucketExistV2(['Bucket' => $bucket])) {
            throw new Exception('Bucket does not exist.');
        }
    }

    public function uploadFile($path, $tmpFile, $contentType, $allowOverwrite = false, $cacheLength = 31536000) {
        if ($this->client->doesObjectExist($this->bucket, $path) && !$allowOverwrite) {
            throw new Exception("File: '$path' already exists. This is to prevent overwriting it.");
        }

        $result = $this->client->putObject([
            'Bucket' => $this->bucket,
            'Key' => $path,
            'Body' => fopen($tmpFile, 'r+'),
            'CacheControl' => "max-age=$cacheLength",
            'ContentType' => $contentType
        ]);

        return $result !== null;
    }

    public function downloadFile($path) {
        if (!$this->client->doesObjectExist($this->bucket, $path)) {
            throw new Exception("File: '$path' does not exist");
        }

        $filename = basename($path);
        $cmd = $this->client->getCommand('GetObject', [
            'Bucket' => $this->bucket,
            'Key' => $path,
            'ResponseContentDisposition' => "attachment; filename='$filename'"
        ]);

        $request = $this->client->createPresignedRequest($cmd, '+20 minutes');
        $presignedUrl = (string) $request->getUri();
        header('Location: ' . $presignedUrl);
        return true;
    }

    public function downloadFolder($dir) {
        return $this->downloadBucket($dir);
    }

    public function downloadBucket($dir = null) {
        $source = $this->getSource($dir);
        $nameOfZipFile = $this->getZipFileName($dir);
        $dest = sys_get_temp_dir() . "/tmp-folder-s3-files";

        if (!mkdir($dest, 0775)) {
            throw new Exception("Error creating temporary folder on server: '$dest'");
        }

        $manager = new \Aws\S3\Transfer($this->client, $source, $dest);
        $manager->transfer();

        $this->createTarGz($dest, $nameOfZipFile);
        $this->sendFileToClient("$dest/$nameOfZipFile.tar.gz");

        $this->removeTemporaryFolder($dest);
        return true;
    }

    public function deleteFile($path) {
        if (!$this->client->doesObjectExist($this->bucket, $path)) {
            throw new Exception("File: '$path' does not exist");
        }

        $this->client->deleteObject(['Bucket' => $this->bucket, 'Key' => $path]);
        return !$this->client->doesObjectExist($this->bucket, $path);
    }

    public function deleteFolder($dir) {
        $results = $this->client->getPaginator('ListObjects', ['Bucket' => $this->bucket, 'Prefix' => "$dir/"]);
        foreach ($results as $result) {
            if (empty($result['Contents'])) {
                throw new Exception("Folder: '$dir/' does not exist.");
            }
            foreach ($result['Contents'] as $object) {
                $this->deleteFile($object['Key']);
            }
        }
        return true;
    }

    public function renameFile($oldName, $newName) {
        if (!$this->client->doesObjectExist($this->bucket, $oldName)) {
            throw new Exception("File: '$oldName' does not exist");
        }
        if ($oldName === $newName) {
            throw new Exception("New name is same as old name on File: '$oldName'");
        }
        if ($this->client->doesObjectExist($this->bucket, $newName)) {
            throw new Exception("File: '$newName' already exists. This is to prevent overwriting it.");
        }

        $this->client->copyObject([
            'Bucket' => $this->bucket,
            'Key' => $newName,
            'CopySource' => "$this->bucket/$oldName"
        ]);

        return $this->client->doesObjectExist($this->bucket, $newName) && $this->deleteFile($oldName);
    }

    public function renameFolder($oldName, $newName) {
        if ($oldName === $newName) {
            throw new Exception("New name is same as old name on File: '$oldName'");
        }

        $results = $this->client->getPaginator('ListObjects', ['Bucket' => $this->bucket, 'Prefix' => "$oldName/"]);
        foreach ($results as $result) {
            if (empty($result['Contents'])) {
                throw new Exception("Folder: '$oldName/' does not exist.");
            }
            foreach ($result['Contents'] as $object) {
                $newNameFull = str_replace($oldName, $newName, $object['Key']);
                $this->renameFile($object['Key'], $newNameFull);
            }
        }
        return true;
    }

    private function getSource($dir) {
        return !empty($dir) ? "s3://$this->bucket/$dir" : "s3://$this->bucket";
    }

    private function getZipFileName($dir) {
        return !empty($dir) ? basename($dir) : $this->bucket;
    }

    private function createTarGz($dest, $nameOfZipFile) {
        $a = new PharData("$dest/$nameOfZipFile.tar");
        $a->buildFromDirectory($dest);
        $a->compress(Phar::GZ);
    }

    private function sendFileToClient($filePath) {
        header('Content-Description: File Transfer');
        header('Content-Type: application/octet-stream');
        header('Content-Length: ' . filesize($filePath));
        header("Content-Disposition: attachment; filename=" . basename($filePath));
        readfile($filePath);
    }

    private function removeTemporaryFolder($dest) {
        $files = new RecursiveIteratorIterator(
            new RecursiveDirectoryIterator($dest, RecursiveDirectoryIterator::SKIP_DOTS),
            RecursiveIteratorIterator::CHILD_FIRST
        );
        foreach ($files as $fileinfo) {
            $todo = ($fileinfo->isDir() ? 'rmdir' : 'unlink');
            $todo($fileinfo->getRealPath());
        }
        rmdir($dest);
    }
}