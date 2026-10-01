<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper\Tests\Support;

use Pbx3\Gatekeeper\MacIndexPersistence;

/** In-memory MacIndexPersistence for C7/C8 unit tests. */
final class InMemoryMacIndexPersistence implements MacIndexPersistence
{
    /** @var array{version: int, updated_at: string, entries: list<array<string, mixed>>} */
    private array $index = [
        'version' => 1,
        'updated_at' => '2026-10-01T00:00:00Z',
        'entries' => [],
    ];

    private string $map = '';

    /** @var array<string, mixed> */
    private array $catalog;

    public function __construct(?array $catalog = null)
    {
        $this->catalog = $catalog ?? [
            'version' => 1,
            'instances' => [
                [
                    'id' => 'inst-a',
                    'fqdn' => '08jzwn.pbx3.com',
                    'sbc_backend_uri' => 'sip:44.196.98.191:5060',
                ],
                [
                    'id' => 'inst-b',
                    'fqdn' => 'bzy54n.pbx3.com',
                ],
            ],
        ];
    }

    public function getMacIndex(): array
    {
        return $this->index;
    }

    public function putMacIndex(array $index): void
    {
        $this->index = $index;
    }

    public function putProvisionMacMap(string $mapBody): void
    {
        $this->map = $mapBody;
    }

    public function getProvisionMacMap(): string
    {
        return $this->map;
    }

    public function getCatalog(): array
    {
        return $this->catalog;
    }

    public function nowIso(): string
    {
        return '2026-10-01T12:00:00Z';
    }
}
