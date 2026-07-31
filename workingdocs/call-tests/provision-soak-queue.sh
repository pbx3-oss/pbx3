#!/usr/bin/env bash
# Provision dedicated soak queue for traffic-profile rrmemory (not L1 2060).
# Creates/updates queue pkey 2160 on catcher tenant: strategy=rrmemory,
# members = first AGENT_N soak answerers (default 2120..2123), GenAst Commit.
#
# Usage: ./provision-soak-queue.sh
# Requires: lab.env (GOLDEN_SSH, CATCHER_DOMAIN), soak phones already provisioned.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

if [[ ! -f lab.env ]]; then
  echo "Missing lab.env" >&2
  exit 1
fi
# shellcheck disable=SC1091
source ./lab.env

: "${GOLDEN_SSH:?Set GOLDEN_SSH in lab.env}"
: "${CATCHER_DOMAIN:?}"
CLUSTER_SU="${CATCHER_DOMAIN%%.*}"
QUEUE_PKEY="${SOAK_QUEUE_PKEY:-2160}"
AGENT_N="${SOAK_QUEUE_AGENT_N:-4}"
ANSWERER_FIRST="${SOAK_ANSWERER_FIRST:-2120}"
STRATEGY="${SOAK_QUEUE_STRATEGY:-rrmemory}"

MEMBERS=""
for ((i = 0; i < AGENT_N; i++)); do
  ext=$((ANSWERER_FIRST + i))
  if [[ -n "$MEMBERS" ]]; then
    MEMBERS+=" "
  fi
  MEMBERS+="$ext"
done

echo "Provisioning soak queue ${QUEUE_PKEY} on ${CLUSTER_SU}: strategy=${STRATEGY} members=${MEMBERS}"

# shellcheck disable=SC2086
$GOLDEN_SSH "cat > /tmp/pbx3-provision-soak-queue.php" <<'PHP'
<?php
declare(strict_types=1);

require '/opt/pbx3api/vendor/autoload.php';
$app = require '/opt/pbx3api/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

use App\Models\Queue;

$cluster = getenv('CLUSTER_SU') ?: 'pb0wsk';
$pkey = getenv('QUEUE_PKEY') ?: '2160';
$members = getenv('QUEUE_MEMBERS') ?: '2120 2121 2122 2123';
$strategy = getenv('QUEUE_STRATEGY') ?: 'rrmemory';

$q = Queue::query()->where('cluster', $cluster)->where('pkey', $pkey)->first();
$created = false;
if (!$q) {
    $q = new Queue();
    $q->id = generate_ksuid();
    $q->shortuid = generate_shortuid();
    $q->pkey = $pkey;
    $q->cluster = $cluster;
    $created = true;
}

$q->active = 'YES';
$q->cname = 'SIPp soak RR';
$q->description = 'Traffic-profile rrmemory (not L1 2060)';
$q->members = $members;
$q->strategy = $strategy;
$q->timeout = 30;
$q->options = $q->options ?: 'CiIknrtT';
$q->save();

if (function_exists('set_commit_dirty')) {
    set_commit_dirty();
}

fwrite(STDERR, "provision-soak-queue: " . ($created ? "created" : "updated") . " {$pkey} shortuid={$q->shortuid} strategy={$strategy} members={$members}\n");
echo "SOAK_QUEUE_PKEY={$pkey}\n";
echo "SOAK_QUEUE_SHORTUID={$q->shortuid}\n";
echo "SOAK_QUEUE_STRATEGY={$strategy}\n";
echo "SOAK_QUEUE_MEMBERS=\"{$members}\"\n";
PHP

# shellcheck disable=SC2086
OUT="$($GOLDEN_SSH "sudo CLUSTER_SU=$(printf %q "$CLUSTER_SU") QUEUE_PKEY=$(printf %q "$QUEUE_PKEY") QUEUE_MEMBERS=$(printf %q "$MEMBERS") QUEUE_STRATEGY=$(printf %q "$STRATEGY") php /tmp/pbx3-provision-soak-queue.php")"

# shellcheck disable=SC2086
$GOLDEN_SSH bash -s <<'COMMIT'
set -euo pipefail
if [[ -x /opt/pbx3/scripts/genAst.sh ]]; then
  echo "Running GenAst Commit…"
  sudo /opt/pbx3/scripts/genAst.sh
else
  echo "WARN: genAst.sh missing — Commit from SPA" >&2
fi
# Asterisk queue section name is shortuid; reload so new queues appear without full restart
sudo asterisk -rx "module reload app_queue.so" >/dev/null || true
COMMIT

ENV_FILE="${SOAK_QUEUE_ENV:-$ROOT/soak-queue.env}"
{
  echo "# generated $(date -u +%Y-%m-%dT%H:%M:%SZ) by provision-soak-queue.sh"
  echo "$OUT"
  echo "SOAK_QUEUE_AGENT_N=$AGENT_N"
  echo "SOAK_ANSWERER_FIRST=$ANSWERER_FIRST"
} >"$ENV_FILE"
chmod 600 "$ENV_FILE"
echo "Wrote $ENV_FILE"
echo "Next: rsync soak-queue.env to sippuac; ./run-queue-rr.sh start"
