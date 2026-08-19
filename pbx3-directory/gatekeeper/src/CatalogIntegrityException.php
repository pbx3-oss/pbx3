<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper;

/**
 * Catalog referential integrity — e.g. block instance Decom while active tenants remain (#5i).
 */
final class CatalogIntegrityException extends \InvalidArgumentException
{
    /**
     * @param  list<array{shortuid: string, fqdn: string, pkey?: string, cname?: string}>  $blockingTenants
     */
    public function __construct(
        string $message,
        public readonly array $blockingTenants,
        int $code = 422,
    ) {
        parent::__construct($message, $code);
    }
}
