<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper;

/**
 * GET {api_base}/fleet/egress-qualify with fleet service token (after /up OK).
 */
final class InstanceEgressQualifyProbe
{
    /**
     * @return array{state:string, rtt_ms:?int, error:?string}
     */
    public static function probe(string $apiBaseUrl, int $timeoutSeconds = 8): array
    {
        $token = getenv('PBX3_FLEET_SERVICE_TOKEN') ?: '';
        if ($token === '') {
            return ['state' => 'Unknown', 'rtt_ms' => null, 'error' => 'PBX3_FLEET_SERVICE_TOKEN unset'];
        }

        $base = rtrim(trim($apiBaseUrl), '/');
        if ($base === '') {
            return ['state' => 'Unknown', 'rtt_ms' => null, 'error' => 'api_base_url empty'];
        }
        $url = $base.'/fleet/egress-qualify';
        $verifyTls = filter_var(getenv('PBX3_FLEET_HTTP_VERIFY') ?: 'true', FILTER_VALIDATE_BOOL);

        if (! function_exists('curl_init')) {
            return ['state' => 'Unknown', 'rtt_ms' => null, 'error' => 'curl required'];
        }

        $ch = curl_init($url);
        if ($ch === false) {
            return ['state' => 'Unknown', 'rtt_ms' => null, 'error' => 'curl_init failed'];
        }
        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_FOLLOWLOCATION => true,
            CURLOPT_TIMEOUT => $timeoutSeconds,
            CURLOPT_CONNECTTIMEOUT => min(5, $timeoutSeconds),
            CURLOPT_HTTPHEADER => [
                'Accept: application/json',
                'Authorization: Bearer '.$token,
            ],
            CURLOPT_SSL_VERIFYPEER => $verifyTls,
            CURLOPT_SSL_VERIFYHOST => $verifyTls ? 2 : 0,
        ]);
        $body = curl_exec($ch);
        $errno = curl_errno($ch);
        $err = curl_error($ch);
        $status = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        if ($errno !== 0 || $body === false) {
            return ['state' => 'Unknown', 'rtt_ms' => null, 'error' => "egress-qualify: {$err}"];
        }
        if ($status < 200 || $status >= 300) {
            return ['state' => 'Unknown', 'rtt_ms' => null, 'error' => "egress-qualify HTTP {$status}"];
        }

        $json = json_decode((string) $body, true);
        if (! is_array($json)) {
            return ['state' => 'Unknown', 'rtt_ms' => null, 'error' => 'egress-qualify invalid JSON'];
        }

        $state = (string) ($json['state'] ?? 'Unknown');
        if (! in_array($state, ['Avail', 'Unavail', 'Unknown'], true)) {
            $state = 'Unknown';
        }
        $rtt = $json['rtt_ms'] ?? null;
        $rttMs = is_numeric($rtt) ? (int) $rtt : null;

        return ['state' => $state, 'rtt_ms' => $rttMs, 'error' => null];
    }
}
