<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper;

/**
 * Persistence surface for {@see MacIndexStore} (S3 in prod; in-memory in tests).
 */
interface MacIndexPersistence
{
    /**
     * @return array{version: int, updated_at: string, entries: list<array<string, mixed>>}
     */
    public function getMacIndex(): array;

    /** @param array{version: int, updated_at: string, entries: list<array<string, mixed>>} $index */
    public function putMacIndex(array $index): void;

    public function putProvisionMacMap(string $mapBody): void;

    /** Empty string if artifact missing. */
    public function getProvisionMacMap(): string;

    /** @return array<string, mixed> */
    public function getCatalog(): array;

    public function nowIso(): string;
}
