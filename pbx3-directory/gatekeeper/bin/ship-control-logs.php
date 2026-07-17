#!/usr/bin/env php
<?php
/**
 * Ship rotated control-host logs to org S3 (Phase 4).
 * Uses Gatekeeper AWS SDK + instance role (no aws CLI required).
 *
 * Usage: php8.4 bin/ship-control-logs.php [--limit=N] [--dry-run]
 * Env: PBX3_ORG_BUCKET (from /etc/pbx3-gatekeeper/.env), PBX3_CONTROL_ID
 */

declare(strict_types=1);

use Aws\S3\S3Client;

require dirname(__DIR__) . '/vendor/autoload.php';

$envFile = getenv('GATEKEEPER_ENV') ?: '/etc/pbx3-gatekeeper/.env';
if (is_readable($envFile)) {
    foreach (file($envFile, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) as $line) {
        if ($line === '' || $line[0] === '#' || ! str_contains($line, '=')) {
            continue;
        }
        [$k, $v] = explode('=', $line, 2);
        $k = trim($k);
        $v = trim($v, " \t\"'");
        if ($k !== '' && getenv($k) === false) {
            putenv("{$k}={$v}");
            $_ENV[$k] = $v;
        }
    }
}

$limit = null;
$dryRun = false;
foreach (array_slice($argv, 1) as $arg) {
    if ($arg === '--dry-run') {
        $dryRun = true;
    } elseif (str_starts_with($arg, '--limit=')) {
        $limit = (int) substr($arg, 8);
    } elseif ($arg === '--limit' || $arg === '-h' || $arg === '--help') {
        fwrite(STDERR, "Usage: {$argv[0]} [--limit=N] [--dry-run]\n");
        exit($arg === '--limit' ? 2 : 0);
    }
}

$bucket = getenv('PBX3_ORG_BUCKET') ?: '';
$ctrlId = getenv('PBX3_CONTROL_ID') ?: 'control';
$enabled = filter_var(getenv('PBX3_LOG_UPLOAD_ENABLED') ?: 'true', FILTER_VALIDATE_BOOL);
$statePath = getenv('PBX3_LOG_SHIP_STATE') ?: '/var/lib/pbx3-gatekeeper/log-ship-state.json';
$region = getenv('AWS_DEFAULT_REGION') ?: 'us-east-1';

if (! $enabled) {
    echo "upload disabled\n";
    exit(0);
}
if ($bucket === '') {
    fwrite(STDERR, "PBX3_ORG_BUCKET unset\n");
    exit(0);
}

$candidates = [];
foreach (array_merge(glob('/var/log/syslog.[0-9]*') ?: [], glob('/var/log/syslog.*.gz') ?: []) as $path) {
    if (! is_file($path) || ! is_readable($path)) {
        continue;
    }
    $base = basename($path);
    if (! preg_match('/^syslog\.\d+/', $base)) {
        continue;
    }
    $candidates[] = ['syslog', $path];
}
foreach (array_merge(glob('/var/log/nginx/*.log.[0-9]*') ?: [], glob('/var/log/nginx/*.log.*.gz') ?: []) as $path) {
    if (! is_file($path) || ! is_readable($path)) {
        continue;
    }
    $candidates[] = ['nginx', $path];
}
usort($candidates, fn ($a, $b) => strcmp($a[1], $b[1]));

$state = [];
if (is_file($statePath)) {
    $decoded = json_decode((string) file_get_contents($statePath), true);
    $state = is_array($decoded) ? $decoded : [];
}

$s3 = null;
if (! $dryRun) {
    $s3 = new S3Client([
        'version' => 'latest',
        'region' => $region,
    ]);
    $policyKey = "control/{$ctrlId}/logs/policy.json";
    try {
        $s3->headObject(['Bucket' => $bucket, 'Key' => $policyKey]);
    } catch (Throwable) {
        try {
            $s3->putObject([
                'Bucket' => $bucket,
                'Key' => $policyKey,
                'Body' => json_encode([
                    'schema_version' => 1,
                    'classes' => ['syslog' => 30, 'nginx' => 30],
                    'updated_at' => gmdate('c'),
                ], JSON_PRETTY_PRINT),
                'ContentType' => 'application/json',
            ]);
        } catch (Throwable $e) {
            fwrite(STDERR, 'warn: could not write policy.json (IAM?): '.$e->getMessage()."\n");
        }
    }
}

$uploaded = 0;
$skipped = 0;
$errors = 0;
$count = 0;

foreach ($candidates as [$class, $path]) {
    if ($limit !== null && $count >= $limit) {
        break;
    }
    $count++;
    $stat = stat($path);
    if ($stat === false) {
        continue;
    }
    $fp = hash('sha256', $path.'|'.$stat['ino'].'|'.$stat['size'].'|'.$stat['mtime']);
    if (isset($state[$fp])) {
        $skipped++;
        continue;
    }
    $stamp = gmdate('Ymd\THis\Z', $stat['mtime']);
    $key = "control/{$ctrlId}/logs/{$class}/{$stamp}/".basename($path);

    if ($dryRun) {
        echo "DRY-RUN {$path} -> s3://{$bucket}/{$key}\n";
        $uploaded++;
        continue;
    }

    try {
        $params = [
            'Bucket' => $bucket,
            'Key' => $key,
            'SourceFile' => $path,
            'Tagging' => 'class='.$class,
        ];
        try {
            $s3->putObject($params);
        } catch (Throwable $e) {
            if (! str_contains($e->getMessage(), 'Tagging') && ! str_contains($e->getMessage(), 'AccessDenied')) {
                throw $e;
            }
            unset($params['Tagging']);
            $s3->putObject($params);
        }
        $state[$fp] = ['path' => $path, 'class' => $class, 'shipped_at' => gmdate('c')];
        $dir = dirname($statePath);
        if (! is_dir($dir)) {
            mkdir($dir, 0750, true);
        }
        file_put_contents($statePath, json_encode($state, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES)."\n");
        echo "uploaded {$path} -> s3://{$bucket}/{$key}\n";
        $uploaded++;
    } catch (Throwable $e) {
        fwrite(STDERR, "error: {$path}: ".$e->getMessage()."\n");
        $errors++;
    }
}

echo "Log ship: {$uploaded} uploaded, {$skipped} skipped, {$errors} errors\n";
exit($errors > 0 ? 1 : 0);
