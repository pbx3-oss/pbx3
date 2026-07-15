<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper;

/**
 * S10.5 residue — catalog helpers for node edge provision (URI resolve).
 */
final class InstanceEdgeProvision
{
    /**
     * Body override → catalog sbc_backend_uri → sip:{fqdn}:5060.
     */
    public static function resolveBackendUri(?string $bodyUri, ?string $catalogUri, string $fqdn): string
    {
        foreach ([$bodyUri, $catalogUri] as $candidate) {
            if (is_string($candidate) && trim($candidate) !== '') {
                return self::normalizeSipUri($candidate);
            }
        }
        $fqdn = strtolower(trim($fqdn));
        if ($fqdn === '') {
            throw new \InvalidArgumentException('fqdn required to default backend_uri', 422);
        }

        return self::normalizeSipUri('sip:'.$fqdn.':5060');
    }

    public static function normalizeSipUri(string $uri): string
    {
        $s = trim($uri);
        if ($s === '') {
            throw new \InvalidArgumentException('backend_uri required', 422);
        }
        if (! str_starts_with(strtolower($s), 'sip:')) {
            $s = 'sip:'.$s;
        }
        $hostPort = strtolower(substr($s, 4));
        $hostPort = trim($hostPort, '[]');
        if ($hostPort === '') {
            throw new \InvalidArgumentException('backend_uri must look like sip:host:port', 422);
        }
        if (! str_contains($hostPort, ':')) {
            $hostPort .= ':5060';
        }
        if (! preg_match('/^[a-z0-9._\-]+:\d+$/', $hostPort)) {
            throw new \InvalidArgumentException('backend_uri must look like sip:host:port', 422);
        }

        return 'sip:'.$hostPort;
    }

    /**
     * Orchestrate SBC provision-node + catalog patch.
     *
     * @param  array<string, mixed>  $body
     * @return array<string, mixed>
     */
    public static function provision(S3Registrar $registrar, SbcFleetClient $sbc, string $instanceId, array $body): array
    {
        $catalog = $registrar->getCatalog();
        $instance = null;
        foreach ($catalog['instances'] ?? [] as $row) {
            if (is_array($row) && (string) ($row['id'] ?? '') === $instanceId) {
                $instance = $row;
                break;
            }
        }
        if ($instance === null) {
            throw new \RuntimeException("Instance not found: {$instanceId}", 404);
        }

        $uri = self::resolveBackendUri(
            isset($body['backend_uri']) && is_string($body['backend_uri']) ? $body['backend_uri'] : null,
            isset($instance['sbc_backend_uri']) && is_string($instance['sbc_backend_uri'])
                ? $instance['sbc_backend_uri']
                : null,
            (string) ($instance['fqdn'] ?? '')
        );

        $existingSetid = isset($instance['sbc_dispatcher_setid'])
            ? (int) $instance['sbc_dispatcher_setid']
            : 0;
        $confirm = ! empty($body['confirm']);
        $dryRun = ! empty($body['dry_run']);
        $sourceIp = isset($body['source_ip']) && is_string($body['source_ip'])
            ? $body['source_ip']
            : null;
        $description = isset($body['description']) && is_string($body['description'])
            ? $body['description']
            : ((string) ($instance['label'] ?? $instance['fqdn'] ?? $instanceId));

        $sbcBody = [
            'instance_id' => $instanceId,
            'backend_uri' => $uri,
            'description' => $description,
            'dry_run' => $dryRun,
            'confirm' => $confirm,
        ];
        if ($existingSetid >= 1) {
            $sbcBody['setid'] = $existingSetid;
        }
        if ($sourceIp !== null && trim($sourceIp) !== '') {
            $sbcBody['source_ip'] = trim($sourceIp);
        }

        $edge = $sbc->provisionNode($sbcBody);
        if (empty($edge['ok'])) {
            $msg = (string) ($edge['message'] ?? $edge['errors'][0] ?? 'SBC provision-node failed');
            throw new \RuntimeException($msg, 422);
        }

        $setid = (int) ($edge['setid'] ?? 0);
        if ($setid < 1) {
            throw new \RuntimeException('SBC provision-node returned no setid', 502);
        }

        if ($dryRun) {
            return [
                'ok' => true,
                'dry_run' => true,
                'instance_id' => $instanceId,
                'backend_uri' => $uri,
                'edge' => $edge,
            ];
        }

        $actor = isset($body['updated_by']) && is_string($body['updated_by'])
            ? $body['updated_by']
            : null;
        $patched = $registrar->patchInstance($instanceId, [
            'sbc_dispatcher_setid' => $setid,
            'sbc_backend_uri' => $uri,
        ], $actor);

        return [
            'ok' => true,
            'dry_run' => false,
            'instance_id' => $instanceId,
            'backend_uri' => $uri,
            'sbc_dispatcher_setid' => $setid,
            'edge' => $edge,
            'instance' => $patched['instance'] ?? null,
        ];
    }
}
