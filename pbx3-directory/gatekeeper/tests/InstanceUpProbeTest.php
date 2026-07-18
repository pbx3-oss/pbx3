<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper\Tests;

use PHPUnit\Framework\TestCase;
use Pbx3\Gatekeeper\InstanceUpProbe;

final class InstanceUpProbeTest extends TestCase
{
    public function test_up_url_derives_from_api_base(): void
    {
        $this->assertSame(
            'https://08jzwn.pbx3.com:44300/up',
            InstanceUpProbe::upUrl('https://08jzwn.pbx3.com:44300/api')
        );
        $this->assertSame(
            'https://host.example/up',
            InstanceUpProbe::upUrl('https://host.example')
        );
    }
}
