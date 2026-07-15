<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper\Tests;

use PHPUnit\Framework\TestCase;
use Pbx3\Gatekeeper\SbcSetidGuard;

final class SbcSetidGuardTest extends TestCase
{
    public function test_normalize_optional(): void
    {
        $this->assertNull(SbcSetidGuard::normalizeOptional(null));
        $this->assertNull(SbcSetidGuard::normalizeOptional(''));
        $this->assertSame(2, SbcSetidGuard::normalizeOptional(2));
        $this->assertSame(3, SbcSetidGuard::normalizeOptional('3'));
    }

    public function test_normalize_rejects_zero(): void
    {
        $this->expectException(\InvalidArgumentException::class);
        $this->expectExceptionCode(422);
        SbcSetidGuard::normalizeOptional(0);
    }

    public function test_assert_live_rejects_unknown(): void
    {
        $this->expectException(\InvalidArgumentException::class);
        $this->expectExceptionCode(422);
        SbcSetidGuard::assertLive(99, [2, 3]);
    }

    public function test_assert_live_accepts_known(): void
    {
        SbcSetidGuard::assertLive(2, [2, 3]);
        $this->addToAssertionCount(1);
    }
}
