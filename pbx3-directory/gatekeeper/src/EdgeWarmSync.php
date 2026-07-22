<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper;

/**
 * S3-mediated warm sync: active backup+upload → standby pull --db-only.
 */
final class EdgeWarmSync
{
    public function __construct(
        private readonly SbcFleetClient $sbc,
        private readonly EdgePairPromoter $promoter,
    ) {
    }

    public static function fromEnv(): self
    {
        return new self(new SbcFleetClient(), EdgePairPromoter::fromEnv());
    }

    /**
     * @param  array<string, mixed>  $pair
     * @return array{
     *   ok: bool,
     *   backup_stamp: ?string,
     *   active_result: array<string, mixed>|null,
     *   standby_result: array<string, mixed>|null,
     *   standby_api_base: ?string,
     *   error: ?string
     * }
     */
    public function sync(array $pair): array
    {
        $id = (string) ($pair['id'] ?? '');
        if ($id === '') {
            return $this->fail(null, null, null, 'edge pair id missing');
        }
        if (! (bool) ($pair['enabled'] ?? true)) {
            return $this->fail(null, null, null, 'edge pair disabled');
        }

        $activeBase = $this->promoter->activeAdminApiBase($pair);
        if ($activeBase === '') {
            return $this->fail(null, null, null, 'cannot resolve active SBC admin API base');
        }

        try {
            $activeResult = $this->sbc->createBackup(true, $activeBase);
        } catch (\Throwable $e) {
            $err = 'active backup failed: '.$e->getMessage();
            EdgePairStore::setWarmSync($id, null, $err);

            return $this->fail(null, null, null, $err);
        }

        $stamp = isset($activeResult['backup_stamp']) ? (string) $activeResult['backup_stamp'] : '';
        if ($stamp === '' || empty($activeResult['ok'])) {
            $err = 'active backup missing stamp: '.json_encode($activeResult);
            EdgePairStore::setWarmSync($id, null, $err);

            return $this->fail($stamp !== '' ? $stamp : null, $activeResult, null, $err);
        }
        if (empty($activeResult['uploaded'])) {
            $err = 'active backup did not upload to S3 (check PBX3_ORG_BUCKET / IAM on active)';
            EdgePairStore::setWarmSync($id, $stamp, $err);

            return $this->fail($stamp, $activeResult, null, $err);
        }

        try {
            $standbyBase = $this->promoter->standbyAdminApiBase($pair);
        } catch (\Throwable $e) {
            $err = $e->getMessage();
            EdgePairStore::setWarmSync($id, $stamp, $err);

            return $this->fail($stamp, $activeResult, null, $err, null);
        }

        try {
            $standbyResult = $this->sbc->warmPull($stamp, true, $standbyBase);
        } catch (\Throwable $e) {
            $err = 'standby warm-pull failed: '.$e->getMessage();
            EdgePairStore::setWarmSync($id, $stamp, $err);

            return $this->fail($stamp, $activeResult, null, $err, $standbyBase);
        }

        if (empty($standbyResult['ok'])) {
            $err = 'standby warm-pull not ok: '.json_encode($standbyResult);
            EdgePairStore::setWarmSync($id, $stamp, $err);

            return $this->fail($stamp, $activeResult, $standbyResult, $err, $standbyBase);
        }

        EdgePairStore::setWarmSync($id, $stamp, null);

        return [
            'ok' => true,
            'backup_stamp' => $stamp,
            'active_result' => $activeResult,
            'standby_result' => $standbyResult,
            'standby_api_base' => $standbyBase,
            'error' => null,
        ];
    }

    /**
     * @param  array<string, mixed>|null  $activeResult
     * @param  array<string, mixed>|null  $standbyResult
     * @return array{
     *   ok: bool,
     *   backup_stamp: ?string,
     *   active_result: array<string, mixed>|null,
     *   standby_result: array<string, mixed>|null,
     *   standby_api_base: ?string,
     *   error: ?string
     * }
     */
    private function fail(
        ?string $stamp,
        ?array $activeResult,
        ?array $standbyResult,
        string $error,
        ?string $standbyBase = null,
    ): array {
        return [
            'ok' => false,
            'backup_stamp' => $stamp,
            'active_result' => $activeResult,
            'standby_result' => $standbyResult,
            'standby_api_base' => $standbyBase,
            'error' => $error,
        ];
    }
}
