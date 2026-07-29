<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper\Tests;

use PHPUnit\Framework\TestCase;
use Pbx3\Gatekeeper\TenantProvisioner;

final class TenantProvisionerTest extends TestCase
{
    public function test_normalize_requires_core_fields(): void
    {
        $this->expectException(\InvalidArgumentException::class);
        TenantProvisioner::normalizeRequest([
            'instance_id' => 'inst1',
            'pkey' => 'acme',
        ]);
    }

    public function test_normalize_happy_path(): void
    {
        $req = TenantProvisioner::normalizeRequest([
            'instance_id' => 'inst1',
            'pkey' => 'acme',
            'description' => 'Acme Corp',
            'clusterclid' => '01924',
            'localarea' => '01924',
        ]);
        $this->assertSame('inst1', $req['instance_id']);
        $this->assertSame('acme', $req['pkey']);
        $this->assertSame('Acme Corp', $req['description']);
        $this->assertSame('01924', $req['clusterclid']);
        $this->assertFalse($req['resume']);
    }

    public function test_normalize_rejects_non_digit_clid(): void
    {
        $this->expectException(\InvalidArgumentException::class);
        TenantProvisioner::normalizeRequest([
            'instance_id' => 'inst1',
            'pkey' => 'acme',
            'description' => 'Acme',
            'clusterclid' => 'ABC',
        ]);
    }

    public function test_resume_requires_shortuid_fqdn(): void
    {
        $this->expectException(\InvalidArgumentException::class);
        TenantProvisioner::normalizeRequest([
            'instance_id' => 'inst1',
            'pkey' => 'acme',
            'description' => 'Acme',
            'resume' => true,
            'shortuid' => 'abc123',
        ]);
    }

    public function test_build_catalog_record(): void
    {
        $rec = TenantProvisioner::buildCatalogRecord(
            'AbC123',
            'AbC123.pbx3.com',
            'inst1',
            'acme',
            'Acme Corp'
        );
        $this->assertSame('abc123', $rec['shortuid']);
        $this->assertSame('abc123', $rec['tenant_shortuid']);
        $this->assertSame('abc123.pbx3.com', $rec['fqdn']);
        $this->assertSame('abc123.pbx3.com', $rec['cname']);
        $this->assertSame('inst1', $rec['instance_id']);
        $this->assertSame('active', $rec['status']);
        $this->assertSame('acme', $rec['pkey']);
        $this->assertSame('Acme Corp', $rec['label']);
    }
}
