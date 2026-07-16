#!/usr/bin/env php
<?php

declare(strict_types=1);

/**
 * Probe fleet instances (/up), update health + last_seen_at, email on down/cleared.
 *
 * Intended for systemd timer on control.pbx3.com (every ~60s).
 *
 * Usage:
 *   php bin/probe-fleet-instances.php
 */

require_once dirname(__DIR__).'/vendor/autoload.php';

use Pbx3\Gatekeeper\Env;
use Pbx3\Gatekeeper\FleetInstanceProbe;
use Pbx3\Gatekeeper\NotifyDispatcher;
use Pbx3\Gatekeeper\S3Registrar;

Env::load(dirname(__DIR__).'/.env');

try {
    $probe = new FleetInstanceProbe(
        new S3Registrar(),
        NotifyDispatcher::fromEnv()
    );
    $result = $probe->run();
} catch (Throwable $e) {
    fwrite(STDERR, 'probe-fleet-instances failed: '.$e->getMessage()."\n");
    exit(1);
}

$line = sprintf(
    "probed=%d skipped=%d down=%d cleared=%d errors=%d",
    $result['probed'],
    $result['skipped'],
    $result['down'],
    $result['cleared'],
    count($result['errors'])
);
fwrite(STDOUT, $line."\n");
foreach ($result['errors'] as $err) {
    fwrite(STDERR, $err."\n");
}

exit(count($result['errors']) > 0 ? 2 : 0);
