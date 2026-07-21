<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper;

/** UDP SIP OPTIONS probe against edge VIP/EIP. */
final class SipOptionsProbe
{
    /**
     * @return array{ok:bool, rtt_ms:?int, status_line:?string}
     */
    public static function probe(string $host, int $port = 5060, float $timeoutSeconds = 3.0): array
    {
        $host = trim($host);
        if ($host === '') {
            return ['ok' => false, 'rtt_ms' => null, 'status_line' => null];
        }

        $callId = 'edge-probe-'.bin2hex(random_bytes(8)).'@gatekeeper';
        $branch = 'z9hG4bK'.bin2hex(random_bytes(6));
        $msg = "OPTIONS sip:{$host} SIP/2.0\r\n"
            ."Via: SIP/2.0/UDP 127.0.0.1:5099;branch={$branch};rport\r\n"
            ."Max-Forwards: 70\r\n"
            ."From: <sip:edge-probe@pbx3.com>;tag=edgeprobe\r\n"
            ."To: <sip:{$host}>\r\n"
            ."Call-ID: {$callId}\r\n"
            ."CSeq: 1 OPTIONS\r\n"
            ."Content-Length: 0\r\n"
            ."\r\n";

        $sock = @socket_create(AF_INET, SOCK_DGRAM, SOL_UDP);
        if ($sock === false) {
            return ['ok' => false, 'rtt_ms' => null, 'status_line' => null];
        }

        $sec = (int) floor($timeoutSeconds);
        $usec = (int) (($timeoutSeconds - $sec) * 1_000_000);
        socket_set_option($sock, SOL_SOCKET, SO_RCVTIMEO, ['sec' => $sec, 'usec' => $usec]);
        socket_set_option($sock, SOL_SOCKET, SO_SNDTIMEO, ['sec' => $sec, 'usec' => $usec]);

        $t0 = hrtime(true);
        $sent = @socket_sendto($sock, $msg, strlen($msg), 0, $host, $port);
        if ($sent === false) {
            socket_close($sock);

            return ['ok' => false, 'rtt_ms' => null, 'status_line' => null];
        }

        $buf = '';
        $from = '';
        $fromPort = 0;
        $recv = @socket_recvfrom($sock, $buf, 4096, 0, $from, $fromPort);
        socket_close($sock);
        $rttMs = (int) round((hrtime(true) - $t0) / 1_000_000);

        if ($recv === false || $buf === '') {
            return ['ok' => false, 'rtt_ms' => $rttMs, 'status_line' => null];
        }

        $line = explode("\r\n", $buf, 2)[0] ?? '';
        $ok = str_starts_with($line, 'SIP/2.0 200')
            || str_starts_with($line, 'SIP/2.0 401')
            || str_starts_with($line, 'SIP/2.0 407')
            || str_starts_with($line, 'SIP/2.0 483');

        return ['ok' => $ok, 'rtt_ms' => $rttMs, 'status_line' => $line];
    }
}
