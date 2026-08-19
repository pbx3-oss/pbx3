<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper;

use GuzzleHttp\Client;
use GuzzleHttp\Exception\GuzzleException;

/**
 * Outbound SbcFleetAdapter client (gatekeeper → pbx3sbc-admin /api/fleet/*).
 */
final class SbcFleetClient
{
    private Client $http;

    private string $fleetToken;

    private string $sbcApiBase;

    public function __construct(?Client $http = null)
    {
        $this->fleetToken = getenv('PBX3_FLEET_SERVICE_TOKEN') ?: '';
        $this->sbcApiBase = ControlSettingsStore::sbcAdminApiUrl();
        $this->http = $http ?? new Client([
            'timeout' => 60,
            'http_errors' => false,
            // Warm-sync uses http://<member-ip>/api — do not follow 301→https://IP (LE cert is FQDN-only).
            'allow_redirects' => false,
            'verify' => filter_var(getenv('PBX3_FLEET_HTTP_VERIFY') ?: 'true', FILTER_VALIDATE_BOOL),
        ]);
    }

    /**
     * @return list<array{domain: string, setid: int, fleet_owned?: bool}>
     */
    public function listDomains(): array
    {
        $payload = $this->get('/fleet/domains');
        $raw = $payload['domains'] ?? null;
        if (! is_array($raw)) {
            throw new \RuntimeException('SBC /fleet/domains missing domains array', 502);
        }

        $out = [];
        foreach ($raw as $row) {
            if (! is_array($row)) {
                continue;
            }
            $domain = isset($row['domain']) ? trim((string) $row['domain']) : '';
            if ($domain === '') {
                continue;
            }
            $item = [
                'domain' => $domain,
                'setid' => (int) ($row['setid'] ?? 0),
            ];
            if (array_key_exists('fleet_owned', $row)) {
                $item['fleet_owned'] = (bool) $row['fleet_owned'];
            }
            $out[] = $item;
        }

        return $out;
    }

    /**
     * @return list<array{setid: int, destinations: int}>
     */
    public function listDispatcherSets(): array
    {
        $payload = $this->get('/fleet/dispatcher-sets');
        $raw = $payload['sets'] ?? null;
        if (! is_array($raw)) {
            throw new \RuntimeException('SBC /fleet/dispatcher-sets missing sets array', 502);
        }

        $out = [];
        foreach ($raw as $row) {
            if (! is_array($row)) {
                continue;
            }
            $setid = (int) ($row['setid'] ?? 0);
            if ($setid < 1) {
                continue;
            }
            $out[] = [
                'setid' => $setid,
                'destinations' => (int) ($row['destinations'] ?? 0),
            ];
        }

        return $out;
    }

    /**
     * Project tenant domain → dispatcher setid (adapter repointTenant).
     *
     * @return array<string, mixed>
     */
    public function repointTenant(string $tenantDomain, int $destDispatcherSetid): array
    {
        $tenantDomain = trim($tenantDomain);
        if ($tenantDomain === '' || $destDispatcherSetid < 1) {
            throw new \InvalidArgumentException('tenant_domain and dest_dispatcher_setid (>=1) required', 422);
        }

        return $this->post('/fleet/repoint', [
            'tenant_domain' => $tenantDomain,
            'dest_dispatcher_setid' => $destDispatcherSetid,
        ]);
    }

    /**
     * @return list<array{prefix: string, tenant_shortuid: string, e164_key: string, gwid: ?string, setid: ?int, ruleid: int}>
     */
    public function listDidRules(): array
    {
        $payload = $this->get('/fleet/did-rules');
        $raw = $payload['rules'] ?? null;
        if (! is_array($raw)) {
            throw new \RuntimeException('SBC /fleet/did-rules missing rules array', 502);
        }

        $out = [];
        foreach ($raw as $row) {
            if (! is_array($row)) {
                continue;
            }
            $prefix = isset($row['prefix']) ? (string) $row['prefix'] : '';
            $out[] = [
                'prefix' => $prefix,
                'tenant_shortuid' => (string) ($row['tenant_shortuid'] ?? ''),
                'e164_key' => (string) ($row['e164_key'] ?? ''),
                'gwid' => isset($row['gwid']) && $row['gwid'] !== null && $row['gwid'] !== ''
                    ? (string) $row['gwid']
                    : null,
                'setid' => isset($row['setid']) && $row['setid'] !== null && $row['setid'] !== ''
                    ? (int) $row['setid']
                    : null,
                'ruleid' => (int) ($row['ruleid'] ?? 0),
            ];
        }

        return $out;
    }

    /**
     * S10.5 — project catalog DID rows onto SBC inbound dr_rules.
     *
     * @param  list<array<string, mixed>>  $dids
     * @return array<string, mixed>
     */
    public function projectDids(array $dids, bool $dryRun = false, array $ensureTenants = []): array
    {
        return $this->post('/fleet/project-dids', [
            'dids' => $dids,
            'dry_run' => $dryRun,
            'ensure_tenants' => array_values($ensureTenants),
        ]);
    }

    /**
     * S10.5 — ensure domain row exists with setid.
     *
     * @return array<string, mixed>
     */
    public function registerDomain(string $domain, int $setid): array
    {
        $domain = strtolower(trim($domain));
        if ($domain === '' || $setid < 1) {
            throw new \InvalidArgumentException('domain and setid (>=1) required', 422);
        }

        return $this->post('/fleet/domains', [
            'domain' => $domain,
            'setid' => $setid,
        ]);
    }

    /**
     * Fleet Delete — remove SIP domain on edge (idempotent if absent).
     *
     * @return array<string, mixed>
     */
    public function deleteDomain(string $domain): array
    {
        $domain = strtolower(trim($domain));
        if ($domain === '') {
            throw new \InvalidArgumentException('domain required', 422);
        }

        return $this->requestJson('DELETE', '/fleet/domains/'.rawurlencode($domain), null);
    }

    /**
     * S10.5 residue — create/update dispatcher set + Asterisk Peer for a node.
     *
     * @param  array<string, mixed>  $body
     * @return array<string, mixed>
     */
    public function provisionNode(array $body): array
    {
        return $this->post('/fleet/provision-node', $body);
    }

    /**
     * Active VIP: create backup zip + upload to S3.
     *
     * @return array{ok:bool, zip?:string, backup_stamp?:string, epoch?:int, uploaded?:bool, message?:string}
     */
    public function createBackup(bool $upload = true, ?string $baseUrl = null): array
    {
        return $this->post('/fleet/backup', ['upload' => $upload], $baseUrl);
    }

    /**
     * Standby: pull S3 stamp and restore --db-only.
     *
     * @return array{ok:bool, backup_stamp?:string, zip?:string, epoch?:int, restarted?:bool, message?:string}
     */
    public function warmPull(?string $stamp = null, bool $restart = true, ?string $baseUrl = null): array
    {
        $body = ['restart' => $restart];
        if ($stamp !== null && $stamp !== '') {
            $body['stamp'] = $stamp;
        }

        return $this->post('/fleet/warm-pull', $body, $baseUrl);
    }

    /**
     * Phase D: Let's Encrypt on VIP holder (after promote).
     *
     * @return array{ok:bool, configured?:bool, domain?:string, expires_at?:string, message?:string}
     */
    public function leSetup(string $email, ?string $fqdn = null, ?string $baseUrl = null): array
    {
        $body = ['email' => $email];
        if ($fqdn !== null && $fqdn !== '') {
            $body['fqdn'] = $fqdn;
        }

        return $this->post('/fleet/le-setup', $body, $baseUrl);
    }

    /** @return array<string, mixed> */
    private function get(string $path, ?string $baseUrl = null): array
    {
        return $this->requestJson('GET', $path, null, $baseUrl);
    }

    /**
     * @param  array<string, mixed>  $body
     * @return array<string, mixed>
     */
    private function post(string $path, array $body, ?string $baseUrl = null): array
    {
        return $this->requestJson('POST', $path, $body, $baseUrl);
    }

    /**
     * @param  array<string, mixed>|null  $body
     * @return array<string, mixed>
     */
    private function requestJson(string $method, string $path, ?array $body = null, ?string $baseUrl = null): array
    {
        $base = $baseUrl !== null && $baseUrl !== ''
            ? rtrim($baseUrl, '/')
            : $this->sbcApiBase;
        if ($base === '') {
            throw new \RuntimeException('SBC admin API URL not set (Fleet → Edge HA or PBX3_SBC_ADMIN_API_URL) — cannot reach SBC adapter', 503);
        }
        if ($this->fleetToken === '') {
            throw new \RuntimeException('PBX3_FLEET_SERVICE_TOKEN not configured on gatekeeper', 503);
        }

        $url = $base.$path;
        $opts = [
            'headers' => [
                'Authorization' => 'Bearer '.$this->fleetToken,
                'Accept' => 'application/json',
            ],
            'timeout' => 600,
        ];
        if ($body !== null) {
            $opts['headers']['Content-Type'] = 'application/json';
            $opts['json'] = $body;
        }

        try {
            $res = $this->http->request($method, $url, $opts);
        } catch (GuzzleException $e) {
            throw new \RuntimeException("HTTP {$method} {$url}: ".$e->getMessage(), 502);
        }

        $code = $res->getStatusCode();
        $decoded = json_decode((string) $res->getBody(), true);
        if ($code >= 400) {
            $msg = is_array($decoded)
                ? ($decoded['message'] ?? $decoded['error'] ?? json_encode($decoded))
                : (string) $res->getBody();
            // Never bounce SBC adapter 401/403 as the operator's Gatekeeper session.
            $outCode = ($code === 401 || $code === 403) ? 502 : ($code >= 400 && $code < 600 ? $code : 502);
            throw new \RuntimeException(
                "HTTP {$method} {$url} → {$code}: {$msg}",
                $outCode
            );
        }

        return is_array($decoded) ? $decoded : [];
    }
}
