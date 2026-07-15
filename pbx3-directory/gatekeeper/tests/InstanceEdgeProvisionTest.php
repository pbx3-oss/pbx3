<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper\Tests;

use PHPUnit\Framework\TestCase;
use Pbx3\Gatekeeper\InstanceEdgeProvision;

final class InstanceEdgeProvisionTest extends TestCase
{
    public function test_resolve_defaults_to_fqdn(): void
    {
        $this->assertSame(
            'sip:08jzwn.pbx3.com:5060',
            InstanceEdgeProvision::resolveBackendUri(null, null, '08jzwn.pbx3.com')
        );
    }

    public function test_resolve_prefers_body_then_catalog(): void
    {
        $this->assertSame(
            'sip:10.0.0.5:5060',
            InstanceEdgeProvision::resolveBackendUri('sip:10.0.0.5:5060', 'sip:old.example:5060', '08jzwn.pbx3.com')
        );
        $this->assertSame(
            'sip:old.example:5060',
            InstanceEdgeProvision::resolveBackendUri(null, 'sip:old.example:5060', '08jzwn.pbx3.com')
        );
    }

    public function test_normalize_host_without_port(): void
    {
        $this->assertSame(
            'sip:bzy54n.pbx3.com:5060',
            InstanceEdgeProvision::normalizeSipUri('bzy54n.pbx3.com')
        );
    }
}
