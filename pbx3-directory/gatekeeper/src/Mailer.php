<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper;

/** Outbound mail adapter — SMTP for v1; other providers implement this later. */
interface Mailer
{
    /**
     * @param  list<string>  $to
     */
    public function send(array $to, string $subject, string $bodyText): void;
}
