<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper\Tests;

use PHPUnit\Framework\TestCase;
use Pbx3\Gatekeeper\DidInventory;

final class DidInventoryTest extends TestCase
{
    public function test_normalize_adds_plus(): void
    {
        $this->assertSame('+442071234567', DidInventory::normalizeE164('442071234567'));
        $this->assertSame('+442071234567', DidInventory::normalizeE164('+442071234567'));
    }

    public function test_normalize_rejects_bad(): void
    {
        $this->expectException(\InvalidArgumentException::class);
        DidInventory::normalizeE164('not-a-number');
    }

    public function test_e164_key_strips_plus(): void
    {
        $this->assertSame('442071234567', DidInventory::e164Key('+442071234567'));
    }

    public function test_upsert_inserts_and_updates(): void
    {
        $dids = [
            ['e164' => '+441111111111', 'status' => 'active'],
        ];
        $dids = DidInventory::upsertDidRow($dids, [
            'e164' => '+442071234567',
            'status' => 'active',
            'carrier' => 'gamma',
        ]);
        $this->assertCount(2, $dids);

        $dids = DidInventory::upsertDidRow($dids, [
            'e164' => '+442071234567',
            'status' => 'reserved',
            'carrier' => 'gamma',
        ]);
        $this->assertCount(2, $dids);
        $match = null;
        foreach ($dids as $row) {
            if ($row['e164'] === '+442071234567') {
                $match = $row;
            }
        }
        $this->assertSame('reserved', $match['status']);
    }

    public function test_match_prefix_prefers_sip_prefix(): void
    {
        $this->assertSame(
            '019249264',
            DidInventory::matchPrefix([
                'e164' => '+441924918076',
                'sip_prefix' => '019249264',
            ])
        );
        $this->assertSame(
            '441924918076',
            DidInventory::matchPrefix(['e164' => '+441924918076'])
        );
    }

    public function test_delivery_kind_explicit_and_inferred(): void
    {
        $this->assertSame('block', DidInventory::deliveryKind([
            'e164' => '+441924918076',
            'sip_prefix' => '019249264',
            'delivery' => 'block',
        ]));
        $this->assertSame('singleton', DidInventory::deliveryKind([
            'e164' => '+441924918076',
            'sip_prefix' => '441924918076',
        ]));
        $this->assertSame('singleton', DidInventory::deliveryKind([
            'e164' => '+441924918076',
            'sip_prefix' => '01924918076',
            'delivery' => 'singleton',
        ]));
        $this->assertSame('block', DidInventory::deliveryKind([
            'e164' => '+441924918076',
            'sip_prefix' => '019249264',
        ]));
    }

    public function test_compare_did_projection_detects_missing_and_setid_drift(): void
    {
        $catalog = [
            [
                'e164' => '+441924918076',
                'match_prefix' => '01924918076',
                'tenant_shortuid' => 'aaa111',
                'sbc_dispatcher_setid' => 2,
                'status' => 'active',
                'delivery' => 'singleton',
            ],
            [
                'e164' => '+441111111111',
                'match_prefix' => '019249264',
                'tenant_shortuid' => 'bbb222',
                'sbc_dispatcher_setid' => 3,
                'status' => 'active',
                'delivery' => 'block',
            ],
        ];
        $sbc = [
            [
                'prefix' => '01924918076',
                'tenant_shortuid' => 'aaa111',
                'e164_key' => '441924918076',
                'setid' => 9,
                'ruleid' => 1,
            ],
        ];

        $report = DidInventory::compareDidProjection($catalog, $sbc);
        $this->assertFalse($report['ok']);
        $kinds = array_column($report['drifts'], 'kind');
        $this->assertContains('setid_mismatch', $kinds);
        $this->assertContains('missing_on_sbc', $kinds);
        $this->assertSame(2, $report['summary']['errors']);
    }

    public function test_compare_did_projection_orphan_warning(): void
    {
        $report = DidInventory::compareDidProjection([], [
            [
                'prefix' => '01924918076',
                'tenant_shortuid' => 'ghost',
                'e164_key' => '441924918076',
                'setid' => 2,
                'ruleid' => 7,
            ],
        ]);
        $this->assertFalse($report['ok']);
        $this->assertSame('orphan_on_sbc', $report['drifts'][0]['kind']);
        $this->assertSame('warning', $report['drifts'][0]['severity']);
    }
}
