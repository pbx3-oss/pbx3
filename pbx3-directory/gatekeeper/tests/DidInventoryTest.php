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
}
