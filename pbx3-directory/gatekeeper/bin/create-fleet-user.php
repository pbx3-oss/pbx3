#!/usr/bin/env php
<?php

declare(strict_types=1);

/**
 * Bootstrap a fleet operator user on the gatekeeper auth DB.
 *
 * Usage:
 *   php bin/create-fleet-user.php --email admin@example.com --password 'long-secret' [--name 'Fleet Admin']
 *   php bin/create-fleet-user.php --email reader@example.com --password 'long-secret' --abilities fleet_read
 *   php bin/create-fleet-user.php ... --abilities fleet_read,fleet_moves
 *
 * Default abilities: fleet_admin (full power). Valid: fleet_read, fleet_instances, fleet_moves, fleet_edge, fleet_dial_cohorts, fleet_admin.
 */

require_once dirname(__DIR__).'/vendor/autoload.php';

use Pbx3\Gatekeeper\Env;
use Pbx3\Gatekeeper\FleetAbilities;
use Pbx3\Gatekeeper\UserStore;

Env::load(dirname(__DIR__).'/.env');

$email = '';
$password = '';
$name = '';
$abilitiesArg = '';

for ($i = 1; $i < $argc; $i++) {
    $arg = $argv[$i];
    if ($arg === '--email' && isset($argv[$i + 1])) {
        $email = $argv[++$i];
    } elseif ($arg === '--password' && isset($argv[$i + 1])) {
        $password = $argv[++$i];
    } elseif ($arg === '--name' && isset($argv[$i + 1])) {
        $name = $argv[++$i];
    } elseif ($arg === '--abilities' && isset($argv[$i + 1])) {
        $abilitiesArg = $argv[++$i];
    } elseif ($arg === '--help' || $arg === '-h') {
        fwrite(STDOUT, "Usage: php bin/create-fleet-user.php --email EMAIL --password PASS [--name NAME] [--abilities LIST]\n");
        fwrite(STDOUT, 'Abilities (comma-separated): '.implode(', ', FleetAbilities::ALL)."\n");
        fwrite(STDOUT, "Default: fleet_admin\n");
        exit(0);
    }
}

if ($email === '' || $password === '') {
    fwrite(STDERR, "Required: --email and --password\n");
    exit(1);
}

$abilities = null;
if ($abilitiesArg !== '') {
    $abilities = array_map('trim', explode(',', $abilitiesArg));
}

try {
    $user = UserStore::createUser($email, $password, $name, $abilities);
    fwrite(
        STDOUT,
        'Created user id='.$user['id'].' email='.$user['email']
        .' abilities='.implode(',', $user['abilities'])."\n"
    );
    exit(0);
} catch (Throwable $e) {
    fwrite(STDERR, $e->getMessage()."\n");
    exit(1);
}
