<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper\Tests;

use PHPUnit\Framework\TestCase;
use Pbx3\Gatekeeper\S3ClientFactory;

final class S3ClientFactoryTest extends TestCase
{
    /** @var list<string> */
    private array $keys = [
        'AWS_DEFAULT_REGION',
        'AWS_ENDPOINT',
        'AWS_USE_PATH_STYLE_ENDPOINT',
        'AWS_ACCESS_KEY_ID',
        'AWS_SECRET_ACCESS_KEY',
    ];

    /** @var array<string, string|false> */
    private array $saved = [];

    protected function setUp(): void
    {
        foreach ($this->keys as $key) {
            $this->saved[$key] = getenv($key);
            putenv($key);
            unset($_ENV[$key]);
        }
    }

    protected function tearDown(): void
    {
        foreach ($this->saved as $key => $val) {
            if ($val === false) {
                putenv($key);
                unset($_ENV[$key]);
            } else {
                putenv("{$key}={$val}");
                $_ENV[$key] = $val;
            }
        }
    }

    public function test_aws_default_has_no_endpoint(): void
    {
        $cfg = S3ClientFactory::config();
        $this->assertSame('us-east-1', $cfg['region']);
        $this->assertArrayNotHasKey('endpoint', $cfg);
        $this->assertArrayNotHasKey('credentials', $cfg);
    }

    public function test_garage_lab_endpoint_and_static_keys(): void
    {
        putenv('AWS_DEFAULT_REGION=garage');
        putenv('AWS_ENDPOINT=http://192.168.1.33:3900');
        putenv('AWS_USE_PATH_STYLE_ENDPOINT=true');
        putenv('AWS_ACCESS_KEY_ID=GKTEST');
        putenv('AWS_SECRET_ACCESS_KEY=secret');

        $cfg = S3ClientFactory::config();
        $this->assertSame('garage', $cfg['region']);
        $this->assertSame('http://192.168.1.33:3900', $cfg['endpoint']);
        $this->assertTrue($cfg['use_path_style_endpoint']);
        $this->assertSame('GKTEST', $cfg['credentials']['key']);
        $this->assertSame('secret', $cfg['credentials']['secret']);
    }

    public function test_path_style_defaults_false_when_endpoint_set(): void
    {
        putenv('AWS_ENDPOINT=https://s3.example');
        $cfg = S3ClientFactory::config();
        $this->assertFalse($cfg['use_path_style_endpoint']);
    }
}
