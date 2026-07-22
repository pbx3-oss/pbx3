<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper;

use Aws\Ec2\Ec2Client;
use Aws\Exception\AwsException;

/**
 * Fence (best-effort) + EIP reassociate onto standby.
 * Managed Promote now: SIP-OPTIONS standby public IP; warn (confirm) if unseen.
 * LE stays cast-iron Phase D for first auto drills.
 */
final class EdgePairPromoter
{
    public function __construct(
        private readonly ?Ec2Client $ec2 = null,
    ) {
    }

    public static function fromEnv(): self
    {
        return new self(null);
    }

    /**
     * Standby member instance id for the pair’s current active_member.
     *
     * @param  array<string, mixed>  $pair
     */
    public function standbyInstanceId(array $pair): string
    {
        $active = (string) ($pair['active_member'] ?? 'a');
        $standbyMember = $active === 'a' ? 'b' : 'a';

        return $standbyMember === 'a'
            ? (string) $pair['member_a_instance_id']
            : (string) $pair['member_b_instance_id'];
    }

    /**
     * SIP OPTIONS against standby’s current public IP (not the VIP/EIP).
     *
     * @param  array<string, mixed>  $pair
     * @return array{
     *   ok:bool,
     *   host:?string,
     *   instance_id:string,
     *   rtt_ms:?int,
     *   status_line:?string,
     *   warning:?string
     * }
     */
    public function probeStandbySip(array $pair, float $timeoutSeconds = 3.0): array
    {
        $standbyId = $this->standbyInstanceId($pair);
        $region = (string) ($pair['region'] ?? 'us-east-1');
        $host = $this->publicIpForInstance($standbyId, $region);
        if ($host === null) {
            return [
                'ok' => false,
                'host' => null,
                'instance_id' => $standbyId,
                'rtt_ms' => null,
                'status_line' => null,
                'warning' => 'Cannot resolve public IP for standby '.$standbyId
                    .' — cannot confirm SIP before promote. Warm-sync / start OpenSIPS on standby,'
                    .' or confirm to promote anyway (Console/CLI break-glass is also ungated).',
            ];
        }

        $probe = SipOptionsProbe::probe($host, 5060, $timeoutSeconds);
        if ($probe['ok']) {
            return [
                'ok' => true,
                'host' => $host,
                'instance_id' => $standbyId,
                'rtt_ms' => $probe['rtt_ms'],
                'status_line' => $probe['status_line'],
                'warning' => null,
            ];
        }

        $detail = $probe['status_line'] ?? 'no SIP response';

        return [
            'ok' => false,
            'host' => $host,
            'instance_id' => $standbyId,
            'rtt_ms' => $probe['rtt_ms'],
            'status_line' => $probe['status_line'],
            'warning' => 'Cannot confirm SIP on standby '.$standbyId.' @ '.$host.':5060 ('.$detail.').'
                .' Promoting may put the VIP on a host without OpenSIPS (e.g. after fence without warm-sync/start).'
                .' Confirm to promote anyway — AWS Console/CLI break-glass remains ungated.',
        ];
    }

    /**
     * @param  array<string, mixed>  $pair
     * @return array{
     *   ok:bool,
     *   active_member:string,
     *   standby_instance_id:string,
     *   error:?string,
     *   fenced:bool,
     *   standby_sip?:array<string, mixed>
     * }
     */
    public function promote(array $pair, bool $fence = true, ?array $standbySip = null): array
    {
        $active = (string) ($pair['active_member'] ?? 'a');
        $standbyMember = $active === 'a' ? 'b' : 'a';
        $standbyId = $standbyMember === 'a'
            ? (string) $pair['member_a_instance_id']
            : (string) $pair['member_b_instance_id'];
        $activeId = $active === 'a'
            ? (string) $pair['member_a_instance_id']
            : (string) $pair['member_b_instance_id'];
        $alloc = (string) ($pair['allocation_id'] ?? '');
        $region = (string) ($pair['region'] ?? 'us-east-1');

        $fenced = false;
        if ($fence) {
            $fenced = $this->tryFence($activeId);
        }

        try {
            $client = $this->ec2 ?? new Ec2Client([
                'version' => 'latest',
                'region' => $region,
            ]);
            $client->associateAddress([
                'AllocationId' => $alloc,
                'InstanceId' => $standbyId,
                'AllowReassociation' => true,
            ]);
        } catch (AwsException $e) {
            return [
                'ok' => false,
                'active_member' => $active,
                'standby_instance_id' => $standbyId,
                'error' => $e->getAwsErrorMessage() ?: $e->getMessage(),
                'fenced' => $fenced,
                'standby_sip' => $standbySip,
            ];
        } catch (\Throwable $e) {
            return [
                'ok' => false,
                'active_member' => $active,
                'standby_instance_id' => $standbyId,
                'error' => $e->getMessage(),
                'fenced' => $fenced,
                'standby_sip' => $standbySip,
            ];
        }

        EdgePairStore::setActiveMember((string) $pair['id'], $standbyMember);
        $cooldownMin = (int) (getenv('GATEKEEPER_EDGE_PROMOTE_COOLDOWN_MIN') ?: 30);
        if ($cooldownMin > 0) {
            EdgePairStore::setPromoteCooldown(
                (string) $pair['id'],
                gmdate('c', time() + ($cooldownMin * 60))
            );
        }

        return [
            'ok' => true,
            'active_member' => $standbyMember,
            'standby_instance_id' => $standbyId,
            'error' => null,
            'fenced' => $fenced,
            'standby_sip' => $standbySip,
        ];
    }

    private function tryFence(string $instanceId): bool
    {
        $key = trim((string) (getenv('GATEKEEPER_EDGE_SSH_KEY') ?: ''));
        if ($key === '' || ! is_file($key)) {
            return false;
        }
        // Best-effort: resolve public IP and stop opensips. Failures are non-fatal.
        try {
            $region = (string) (getenv('AWS_DEFAULT_REGION') ?: 'us-east-1');
            $client = $this->ec2 ?? new Ec2Client([
                'version' => 'latest',
                'region' => $region,
            ]);
            $res = $client->describeInstances(['InstanceIds' => [$instanceId]]);
            $ip = $res['Reservations'][0]['Instances'][0]['PublicIpAddress'] ?? null;
            if (! is_string($ip) || $ip === '') {
                return false;
            }
            $cmd = sprintf(
                'ssh -i %s -o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=no ubuntu@%s %s',
                escapeshellarg($key),
                escapeshellarg($ip),
                escapeshellarg('sudo systemctl stop opensips')
            );
            exec($cmd.' 2>/dev/null', $out, $code);

            return $code === 0;
        } catch (\Throwable) {
            return false;
        }
    }

    /**
     * Resolve current public IPv4 for an instance (standby admin API reachability).
     */
    public function publicIpForInstance(string $instanceId, string $region = 'us-east-1'): ?string
    {
        $instanceId = trim($instanceId);
        if ($instanceId === '') {
            return null;
        }
        try {
            $client = $this->ec2 ?? new Ec2Client([
                'version' => 'latest',
                'region' => $region !== '' ? $region : 'us-east-1',
            ]);
            $res = $client->describeInstances(['InstanceIds' => [$instanceId]]);
            $ip = $res['Reservations'][0]['Instances'][0]['PublicIpAddress'] ?? null;

            return is_string($ip) && $ip !== '' ? $ip : null;
        } catch (\Throwable) {
            return null;
        }
    }

    /**
     * Standby Filament/API base (HTTP on public IP — LE lives on VIP FQDN).
     * Env GATEKEEPER_EDGE_STANDBY_API_SCHEME=https to override (default http).
     */
    public function standbyAdminApiBase(array $pair): string
    {
        $active = (string) ($pair['active_member'] ?? 'a');
        $standbyMember = $active === 'a' ? 'b' : 'a';
        $standbyId = $standbyMember === 'a'
            ? (string) $pair['member_a_instance_id']
            : (string) $pair['member_b_instance_id'];
        $region = (string) ($pair['region'] ?? 'us-east-1');
        $ip = $this->publicIpForInstance($standbyId, $region);
        if ($ip === null) {
            throw new \RuntimeException(
                "cannot resolve public IP for standby instance {$standbyId}",
                502
            );
        }
        $scheme = strtolower(trim((string) (getenv('GATEKEEPER_EDGE_STANDBY_API_SCHEME') ?: 'http')));
        if ($scheme !== 'http' && $scheme !== 'https') {
            $scheme = 'http';
        }

        return $scheme.'://'.$ip.'/api';
    }
}
