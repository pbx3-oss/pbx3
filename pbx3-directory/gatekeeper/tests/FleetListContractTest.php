<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper\Tests;

use PHPUnit\Framework\TestCase;

/**
 * Contract shapes consumed by pbx3spa Fleet views (no live S3).
 */
final class FleetListContractTest extends TestCase
{
    public function test_empty_catalog_shape(): void
    {
        $catalog = $this->fixture('catalog_empty.json');

        $this->assertSame(1, $catalog['version']);
        $this->assertArrayHasKey('updated_at', $catalog);
        $this->assertIsArray($catalog['instances']);
        $this->assertSame([], $catalog['instances']);
    }

    public function test_catalog_instance_fields_for_spa(): void
    {
        $catalog = $this->fixture('catalog_with_instance.json');
        $this->assertCount(1, $catalog['instances']);
        $row = $catalog['instances'][0];
        foreach (['id', 'fqdn', 'api_base_url', 'label', 'status'] as $key) {
            $this->assertArrayHasKey($key, $row, "missing {$key}");
            $this->assertNotSame('', $row[$key]);
        }
        $this->assertArrayHasKey('environment', $row);
    }

    public function test_tenants_list_wrap(): void
    {
        $payload = $this->fixture('tenants_list.json');
        $this->assertArrayHasKey('tenants', $payload);
        $this->assertIsArray($payload['tenants']);
        $row = $payload['tenants'][0];
        foreach (['shortuid', 'instance_id', 'fqdn', 'status'] as $key) {
            $this->assertArrayHasKey($key, $row, "missing {$key}");
        }
        $this->assertTrue(
            isset($row['label']) || isset($row['pkey']) || isset($row['cname']),
            'SPA name fallback needs label|pkey|cname'
        );
    }

    public function test_jobs_list_wrap(): void
    {
        $payload = $this->fixture('tenant_moves_list.json');
        $this->assertArrayHasKey('jobs', $payload);
        $this->assertIsArray($payload['jobs']);
        $row = $payload['jobs'][0];
        foreach (['job_id', 'tenant_shortuid', 'state', 'updated_at', 'created_at'] as $key) {
            $this->assertArrayHasKey($key, $row, "missing {$key}");
        }
    }

    /** @return array<string, mixed> */
    private function fixture(string $name): array
    {
        $path = __DIR__.'/fixtures/'.$name;
        $raw = file_get_contents($path);
        $this->assertNotFalse($raw, "missing fixture {$name}");
        $data = json_decode($raw, true);
        $this->assertIsArray($data);

        return $data;
    }
}
