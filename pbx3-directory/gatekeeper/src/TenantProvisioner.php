<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper;

use GuzzleHttp\Client;
use GuzzleHttp\Exception\GuzzleException;

/**
 * Fleet-first tenant create — push node create → catalog meta → SBC domain.
 *
 * @see pbx3/workingdocs/FLEET_TENANT_CREATE_REQUIREMENTS.md
 */
final class TenantProvisioner
{
    private Client $http;

    private string $fleetToken;

    public function __construct(
        private readonly S3Registrar $registrar,
        private readonly SbcFleetClient $sbc,
        ?Client $http = null,
        ?string $fleetToken = null,
    ) {
        $this->fleetToken = $fleetToken ?? (getenv('PBX3_FLEET_SERVICE_TOKEN') ?: '');
        $this->http = $http ?? new Client([
            'timeout' => 60,
            'http_errors' => false,
            'verify' => filter_var(getenv('PBX3_FLEET_HTTP_VERIFY') ?: 'true', FILTER_VALIDATE_BOOL),
        ]);
    }

    /**
     * @param  array<string, mixed>  $body
     * @return array<string, mixed>
     */
    public function provision(array $body): array
    {
        $req = self::normalizeRequest($body);
        $instance = $this->requireInstance($req['instance_id']);
        $apiBase = rtrim((string) ($instance['api_base_url'] ?? ''), '/');
        if ($apiBase === '') {
            throw new \InvalidArgumentException(
                "Instance {$req['instance_id']} has no api_base_url in catalog",
                422
            );
        }
        $setid = isset($instance['sbc_dispatcher_setid']) ? (int) $instance['sbc_dispatcher_setid'] : 0;
        if ($setid < 1) {
            throw new \InvalidArgumentException(
                "Instance {$req['instance_id']} needs sbc_dispatcher_setid first (Provision edge)",
                422
            );
        }

        $stages = [
            'node' => 'skipped',
            'catalog' => 'pending',
            'sbc' => 'pending',
        ];

        $nodeTenant = null;
        if ($req['resume']) {
            $nodeTenant = [
                'shortuid' => $req['shortuid'],
                'fqdn' => $req['fqdn'],
                'pkey' => $req['pkey'],
                'description' => $req['description'],
                'cname' => $req['fqdn'],
            ];
            $stages['node'] = 'resumed';
        } else {
            $nodeBody = [
                'pkey' => $req['pkey'],
                'description' => $req['description'],
            ];
            if ($req['clusterclid'] !== null) {
                $nodeBody['clusterclid'] = $req['clusterclid'];
            }
            if ($req['localarea'] !== null) {
                $nodeBody['localarea'] = $req['localarea'];
            }
            try {
                $nodeTenant = $this->nodeCreateTenant($apiBase, $nodeBody);
                $stages['node'] = 'ok';
            } catch (\Throwable $e) {
                $stages['node'] = 'failed';
                throw new \RuntimeException(
                    'Node create failed: '.$e->getMessage(),
                    $e->getCode() >= 400 && $e->getCode() < 600 ? (int) $e->getCode() : 502,
                    $e
                );
            }
        }

        $shortuid = strtolower(trim((string) ($nodeTenant['shortuid'] ?? '')));
        $fqdn = strtolower(trim((string) ($nodeTenant['fqdn'] ?? $nodeTenant['cname'] ?? '')));
        if ($shortuid === '' || $fqdn === '') {
            throw new \RuntimeException(
                'Node create response missing shortuid/fqdn',
                502
            );
        }

        $catalogRecord = self::buildCatalogRecord(
            $shortuid,
            $fqdn,
            $req['instance_id'],
            $req['pkey'],
            $req['description']
        );

        try {
            $meta = $this->registrar->registerTenant($catalogRecord);
            $stages['catalog'] = 'ok';
        } catch (\Throwable $e) {
            $stages['catalog'] = 'failed';
            $stages['sbc'] = 'skipped';

            return [
                'ok' => false,
                'partial' => true,
                'stages' => $stages,
                'error' => 'Catalog register failed: '.$e->getMessage(),
                'resume' => [
                    'instance_id' => $req['instance_id'],
                    'pkey' => $req['pkey'],
                    'description' => $req['description'],
                    'shortuid' => $shortuid,
                    'fqdn' => $fqdn,
                    'resume' => true,
                ],
                'node_tenant' => $nodeTenant,
            ];
        }

        try {
            $sbc = $this->sbc->registerDomain($fqdn, $setid);
            $stages['sbc'] = 'ok';

            return [
                'ok' => true,
                'partial' => false,
                'stages' => $stages,
                'tenant' => $meta,
                'node_tenant' => $nodeTenant,
                'sbc' => $sbc,
                'sbc_dispatcher_setid' => $setid,
            ];
        } catch (\Throwable $e) {
            $stages['sbc'] = 'failed';

            return [
                'ok' => true,
                'partial' => true,
                'stages' => $stages,
                'tenant' => $meta,
                'node_tenant' => $nodeTenant,
                'sbc_error' => $e->getMessage(),
                'sbc_dispatcher_setid' => $setid,
                'repair' => 'Register on SBC',
            ];
        }
    }

    /**
     * @param  array<string, mixed>  $body
     * @return array{
     *   instance_id: string,
     *   pkey: string,
     *   description: string,
     *   clusterclid: ?string,
     *   localarea: ?string,
     *   resume: bool,
     *   shortuid: string,
     *   fqdn: string
     * }
     */
    public static function normalizeRequest(array $body): array
    {
        $instanceId = trim((string) ($body['instance_id'] ?? ''));
        $pkey = trim((string) ($body['pkey'] ?? ''));
        $description = trim((string) ($body['description'] ?? ''));
        if ($instanceId === '') {
            throw new \InvalidArgumentException('instance_id required', 422);
        }
        if ($pkey === '') {
            throw new \InvalidArgumentException('pkey required', 422);
        }
        if ($description === '') {
            throw new \InvalidArgumentException('description required', 422);
        }

        $resume = ! empty($body['resume']);
        $shortuid = strtolower(trim((string) ($body['shortuid'] ?? '')));
        $fqdn = strtolower(trim((string) ($body['fqdn'] ?? '')));
        if ($resume && ($shortuid === '' || $fqdn === '')) {
            throw new \InvalidArgumentException(
                'resume requires shortuid and fqdn from the prior node create',
                422
            );
        }

        $clusterclid = null;
        if (array_key_exists('clusterclid', $body) && $body['clusterclid'] !== null) {
            $clusterclid = trim((string) $body['clusterclid']);
            if ($clusterclid !== '' && ! preg_match('/^\d*$/', $clusterclid)) {
                throw new \InvalidArgumentException('clusterclid must be digits only', 422);
            }
        }
        $localarea = null;
        if (array_key_exists('localarea', $body) && $body['localarea'] !== null) {
            $localarea = trim((string) $body['localarea']);
            if ($localarea !== '' && ! preg_match('/^\d*$/', $localarea)) {
                throw new \InvalidArgumentException('localarea must be digits only', 422);
            }
        }

        return [
            'instance_id' => $instanceId,
            'pkey' => $pkey,
            'description' => $description,
            'clusterclid' => $clusterclid,
            'localarea' => $localarea,
            'resume' => $resume,
            'shortuid' => $shortuid,
            'fqdn' => $fqdn,
        ];
    }

    /**
     * Catalog meta for registerTenant (shortuid + tenant_shortuid for schema/CLI parity).
     *
     * @return array<string, mixed>
     */
    public static function buildCatalogRecord(
        string $shortuid,
        string $fqdn,
        string $instanceId,
        string $pkey,
        string $description,
    ): array {
        $fqdn = strtolower(trim($fqdn));
        $shortuid = strtolower(trim($shortuid));

        return [
            'shortuid' => $shortuid,
            'tenant_shortuid' => $shortuid,
            'instance_id' => $instanceId,
            'cname' => $fqdn,
            'fqdn' => $fqdn,
            'status' => 'active',
            'pkey' => $pkey,
            // Name = pkey (FLEET_NAMING_LOCK). Description is notes only — never catalog Name.
            'label' => $pkey,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function requireInstance(string $instanceId): array
    {
        $catalog = $this->registrar->getCatalog();
        foreach ($catalog['instances'] ?? [] as $row) {
            if (is_array($row) && (string) ($row['id'] ?? '') === $instanceId) {
                return $row;
            }
        }
        throw new \RuntimeException("Instance not found: {$instanceId}", 404);
    }

    /**
     * @param  array<string, mixed>  $body
     * @return array<string, mixed>
     */
    private function nodeCreateTenant(string $apiBase, array $body): array
    {
        if ($this->fleetToken === '') {
            throw new \RuntimeException('PBX3_FLEET_SERVICE_TOKEN not configured on gatekeeper', 503);
        }
        $url = $apiBase.'/fleet/tenants';
        try {
            $res = $this->http->request('POST', $url, [
                'headers' => [
                    'Authorization' => 'Bearer '.$this->fleetToken,
                    'Accept' => 'application/json',
                    'Content-Type' => 'application/json',
                ],
                'json' => $body,
            ]);
        } catch (GuzzleException $e) {
            throw new \RuntimeException('Node HTTP error: '.$e->getMessage(), 502, $e);
        }
        $code = $res->getStatusCode();
        $raw = (string) $res->getBody();
        $decoded = json_decode($raw, true);
        if (! is_array($decoded)) {
            throw new \RuntimeException("Node returned non-JSON ({$code})", 502);
        }
        if ($code < 200 || $code >= 300) {
            $msg = (string) ($decoded['message'] ?? $decoded['Error'] ?? $raw);
            throw new \RuntimeException($msg !== '' ? $msg : "Node HTTP {$code}", $code >= 400 ? $code : 502);
        }

        return $decoded;
    }
}
