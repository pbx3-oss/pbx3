<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper\Tests;

use PHPUnit\Framework\TestCase;
use Pbx3\Gatekeeper\DialCohortStore;

final class DialCohortStoreTest extends TestCase
{
    public function test_normalize_prefix_width_bounds(): void
    {
        $this->assertSame(2, DialCohortStore::normalizePrefixWidth(2));
        $this->assertSame(4, DialCohortStore::normalizePrefixWidth(4));
        $this->expectException(\InvalidArgumentException::class);
        DialCohortStore::normalizePrefixWidth(5);
    }

    public function test_normalize_routing_prefix_exact_width(): void
    {
        $this->assertSame('81', DialCohortStore::normalizeRoutingPrefix('81', 2));
        $this->assertSame('81', DialCohortStore::normalizeRoutingPrefix('8-1', 2));
        $this->assertSame('', DialCohortStore::normalizeRoutingPrefix('', 2));
        $this->expectException(\InvalidArgumentException::class);
        DialCohortStore::normalizeRoutingPrefix('811', 2);
    }

    public function test_normalize_members_dedupes(): void
    {
        $this->assertSame(
            ['9wvvnb', 'dhbm8x'],
            DialCohortStore::normalizeMembers(['9wvvnb', 'dhbm8x', '9wvvnb', '', 'BAD!'])
        );
    }

    public function test_build_index_row_counts_ready_prefixes(): void
    {
        $row = DialCohortStore::buildIndexRow(
            [
                'id' => 'dc_abc',
                'name' => 'Acme',
                'members' => ['aaa', 'bbb', 'ccc'],
                'prefix_width' => 2,
                'status' => 'active',
                'updated_at' => '2026-08-06T12:00:00Z',
            ],
            [
                'aaa' => ['routing_prefix' => '81'],
                'bbb' => ['routing_prefix' => ''],
                'ccc' => ['routing_prefix' => '82'],
            ]
        );

        $this->assertSame(3, $row['member_count']);
        $this->assertSame(2, $row['prefixes_ready']);
        $this->assertSame('Acme', $row['name']);
        $this->assertSame(2, $row['prefix_width']);
    }

    public function test_new_cohort_id_shape(): void
    {
        $id = DialCohortStore::newCohortId();
        $this->assertMatchesRegularExpression('/^dc_[a-f0-9]{24}$/', $id);
    }

    public function test_normalize_shortuid_rejects_bad(): void
    {
        $this->expectException(\InvalidArgumentException::class);
        DialCohortStore::normalizeShortuid('Bad_UID');
    }
}
