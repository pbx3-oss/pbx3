<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper\Tests;

use PHPUnit\Framework\TestCase;
use Pbx3\Gatekeeper\InstanceEdgeLabelSync;

final class InstanceEdgeLabelSyncTest extends TestCase
{
    public function test_push_skips_when_no_setid(): void
    {
        InstanceEdgeLabelSync::pushToSbc('kid1', 'Lab Home', 0);
        $this->addToAssertionCount(1);
    }

    public function test_push_rejects_empty_label(): void
    {
        $this->expectException(\InvalidArgumentException::class);
        InstanceEdgeLabelSync::pushToSbc('kid1', '  ', 2);
    }
}
