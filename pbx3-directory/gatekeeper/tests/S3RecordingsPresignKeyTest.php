<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper\Tests;

use PHPUnit\Framework\TestCase;
use Pbx3\Gatekeeper\S3RecordingsPresign;

final class S3RecordingsPresignKeyTest extends TestCase
{
    public function testAllowsTenantRecordingsMediaKey(): void
    {
        $this->assertTrue(S3RecordingsPresign::isAllowedRecordingsKey(
            'tenants/9wvvnb/recordings/media/2026/07/14/1716123456-9wvvnb-1000-2000.wav'
        ));
    }

    public function testAllowsPolicyJsonUnderRecordings(): void
    {
        $this->assertTrue(S3RecordingsPresign::isAllowedRecordingsKey(
            'tenants/9wvvnb/recordings/policy.json'
        ));
    }

    public function testRejectsMigrationPrefixOnOrgShape(): void
    {
        $this->assertFalse(S3RecordingsPresign::isAllowedRecordingsKey(
            'tenants/9wvvnb/migration/job1/export.zip'
        ));
    }

    public function testRejectsPathTraversalAndAbsolute(): void
    {
        $this->assertFalse(S3RecordingsPresign::isAllowedRecordingsKey(
            'tenants/9wvvnb/recordings/../meta.json'
        ));
        $this->assertFalse(S3RecordingsPresign::isAllowedRecordingsKey(
            '/tenants/9wvvnb/recordings/media/x.wav'
        ));
    }

    public function testRejectsEmptySuffix(): void
    {
        $this->assertFalse(S3RecordingsPresign::isAllowedRecordingsKey(
            'tenants/9wvvnb/recordings/'
        ));
        $this->assertFalse(S3RecordingsPresign::isAllowedRecordingsKey(
            'tenants/9wvvnb/recordings'
        ));
    }
}
