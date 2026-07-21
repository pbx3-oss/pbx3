#!/usr/bin/env php
<?php

declare(strict_types=1);

/**
 * Probe SBC edge pairs (SIP OPTIONS on VIP), notify, optional auto EIP promote.
 *
 * Usage:
 *   php bin/probe-edge-pairs.php
 */

require_once dirname(__DIR__).'/vendor/autoload.php';

use Pbx3\Gatekeeper\EdgePairProbe;
use Pbx3\Gatekeeper\Env;

Env::load(dirname(__DIR__).'/.env');

try {
    $result = EdgePairProbe::fromEnv()->run();
} catch (Throwable $e) {
    fwrite(STDERR, 'probe-edge-pairs failed: '.$e->getMessage()."\n");
    exit(1);
}

$line = sprintf(
    'probed=%d skipped=%d down=%d cleared=%d promoted=%d promote_failed=%d errors=%d',
    $result['probed'],
    $result['skipped'],
    $result['down'],
    $result['cleared'],
    $result['promoted'],
    $result['promote_failed'],
    count($result['errors'])
);
fwrite(STDOUT, $line."\n");
foreach ($result['errors'] as $err) {
    fwrite(STDERR, $err."\n");
}

exit(count($result['errors']) > 0 ? 2 : 0);
