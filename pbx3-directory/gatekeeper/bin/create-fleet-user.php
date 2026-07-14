#!/usr/bin/env php
<?php

declare(strict_types=1);

/**
 * Bootstrap a fleet operator user on the gatekeeper auth DB.
 *
 * Usage:
 *   php bin/create-fleet-user.php --email admin@example.com --password 'long-secret' [--name 'Fleet Admin']
 */

require_once dirname(__DIR__).'/vendor/autoload.php';

use Pbx3\Gatekeeper\Env;
use Pbx3\Gatekeeper\UserStore;

Env::load(dirname(__DIR__).'/.env');

$email = '';
$password = '';
$name = '';

for ($i = 1; $i < $argc; $i++) {
    $arg = $argv[$i];
    if ($arg === '--email' && isset($argv[$i + 1])) {
        $email = $argv[++$i];
    } elseif ($arg === '--password' && isset($argv[$i + 1])) {
        $password = $argv[++$i];
    } elseif ($arg === '--name' && isset($argv[$i + 1])) {
        $name = $argv[++$i];
    } elseif ($arg === '--help' || $arg === '-h') {
        fwrite(STDOUT, "Usage: php bin/create-fleet-user.php --email EMAIL --password PASS [--name NAME]\n");
        exit(0);
    }
}

if ($email === '' || $password === '') {
    fwrite(STDERR, "Required: --email and --password\n");
    exit(1);
}

try {
    $user = UserStore::createUser($email, $password, $name);
    fwrite(STDOUT, 'Created user id='.$user['id'].' email='.$user['email']."\n");
    exit(0);
} catch (Throwable $e) {
    fwrite(STDERR, $e->getMessage()."\n");
    exit(1);
}
