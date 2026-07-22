#!/usr/bin/env php
<?php

declare(strict_types=1);

/**
 * Daily warm-sync backstop for the edge HA pair (S3-mediated).
 * Install: gatekeeper/deploy/pbx3-edge-warm-sync.{service,timer}
 */

require dirname(__DIR__).'/vendor/autoload.php';

use Pbx3\Gatekeeper\EdgePairStore;
use Pbx3\Gatekeeper\EdgeWarmSync;

$pairs = EdgePairStore::list();
if ($pairs === []) {
    fwrite(STDOUT, "edge-warm-sync: no edge pair — skip\n");
    exit(0);
}

$sync = EdgeWarmSync::fromEnv();
$failed = 0;
foreach ($pairs as $pair) {
    if (! ($pair['enabled'] ?? true)) {
        fwrite(STDOUT, 'edge-warm-sync: skip disabled '.$pair['id']."\n");
        continue;
    }
    fwrite(STDOUT, 'edge-warm-sync: sync '.$pair['id']."…\n");
    $result = $sync->sync($pair);
    if ($result['ok']) {
        fwrite(STDOUT, 'edge-warm-sync: ok stamp='.($result['backup_stamp'] ?? '')."\n");
    } else {
        $failed++;
        fwrite(STDERR, 'edge-warm-sync: FAIL '.$pair['id'].': '.($result['error'] ?? '?')."\n");
    }
}

exit($failed > 0 ? 1 : 0);
