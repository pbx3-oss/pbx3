<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper\Tests;

use PHPUnit\Framework\TestCase;
use Pbx3\Gatekeeper\SipOptionsProbe;

final class SipOptionsProbeTest extends TestCase
{
    public function test_empty_host_is_not_ok(): void
    {
        $r = SipOptionsProbe::probe('', 5060, 0.5);
        $this->assertFalse($r['ok']);
        $this->assertNull($r['rtt_ms']);
        $this->assertNull($r['status_line']);
    }

    public function test_unreachable_host_is_not_ok(): void
    {
        // RFC 5737 TEST-NET-1 — should not answer SIP
        $r = SipOptionsProbe::probe('192.0.2.1', 5060, 0.4);
        $this->assertFalse($r['ok']);
    }
}
