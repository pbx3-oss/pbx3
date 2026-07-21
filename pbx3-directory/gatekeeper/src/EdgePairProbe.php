<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper;

/**
 * Probe edge VIP (SIP OPTIONS); notify on down/cleared; optional auto EIP promote.
 */
final class EdgePairProbe
{
    public function __construct(
        private readonly NotifyDispatcher $notify,
        private readonly EdgePairPromoter $promoter,
        private readonly float $timeoutSeconds = 3.0,
    ) {
    }

    public static function fromEnv(): self
    {
        return new self(
            NotifyDispatcher::fromEnv(),
            EdgePairPromoter::fromEnv(),
        );
    }

    /**
     * @return array{
     *   probed:int,
     *   skipped:int,
     *   down:int,
     *   cleared:int,
     *   promoted:int,
     *   promote_failed:int,
     *   errors:list<string>
     * }
     */
    public function run(): array
    {
        $probed = 0;
        $skipped = 0;
        $down = 0;
        $cleared = 0;
        $promoted = 0;
        $promoteFailed = 0;
        $errors = [];

        foreach (EdgePairStore::list() as $pair) {
            if (! ($pair['enabled'] ?? false)) {
                $skipped++;
                continue;
            }
            $id = (string) $pair['id'];
            $eip = (string) $pair['eip'];

            $ok = false;
            $rttMs = null;
            try {
                $result = SipOptionsProbe::probe($eip, 5060, $this->timeoutSeconds);
                $ok = $result['ok'];
                $rttMs = $result['rtt_ms'];
            } catch (\Throwable $e) {
                $errors[] = "{$id}: probe exception: ".$e->getMessage();
                $ok = false;
            }

            $probed++;
            try {
                $transition = EdgePairHealthStore::recordProbe($id, $ok, $rttMs);
            } catch (\Throwable $e) {
                $errors[] = "{$id}: health store: ".$e->getMessage();
                continue;
            }

            if ($transition === 'down' || $transition === 'cleared') {
                try {
                    $this->notify->notifyEdgeReachability($pair, $transition);
                    if ($transition === 'down') {
                        $down++;
                    } else {
                        $cleared++;
                    }
                } catch (\Throwable $e) {
                    $errors[] = "{$id}: notify: ".$e->getMessage();
                }
            }

            if ($transition === 'down' && $this->shouldAutoPromote($pair)) {
                try {
                    $result = $this->promoter->promote($pair, true);
                    if ($result['ok']) {
                        $promoted++;
                        $fresh = EdgePairStore::get($id) ?? $pair;
                        $this->notify->notifyEdgePromoted($fresh, $result);
                    } else {
                        $promoteFailed++;
                        $this->notify->notifyEdgePromoteFailed($pair, (string) ($result['error'] ?? 'unknown'));
                        $errors[] = "{$id}: promote failed: ".($result['error'] ?? 'unknown');
                    }
                } catch (\Throwable $e) {
                    $promoteFailed++;
                    $errors[] = "{$id}: promote exception: ".$e->getMessage();
                    try {
                        $this->notify->notifyEdgePromoteFailed($pair, $e->getMessage());
                    } catch (\Throwable) {
                    }
                }
            }
        }

        return [
            'probed' => $probed,
            'skipped' => $skipped,
            'down' => $down,
            'cleared' => $cleared,
            'promoted' => $promoted,
            'promote_failed' => $promoteFailed,
            'errors' => $errors,
        ];
    }

    /** @param  array<string, mixed>  $pair */
    private function shouldAutoPromote(array $pair): bool
    {
        if (($pair['mode'] ?? '') !== EdgePairStore::MODE_AUTO) {
            return false;
        }
        $flag = strtolower(trim((string) (getenv('GATEKEEPER_EDGE_AUTO_PROMOTE') ?: '')));
        if (! in_array($flag, ['1', 'true', 'yes', 'on'], true)) {
            return false;
        }
        $until = $pair['promote_cooldown_until'] ?? null;
        if (is_string($until) && $until !== '') {
            $ts = strtotime($until);
            if ($ts !== false && $ts > time()) {
                return false;
            }
        }

        return true;
    }
}
