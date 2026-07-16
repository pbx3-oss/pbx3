<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper;

/** Lab-safe no-op when SMTP is unset — logs what would have been sent. */
final class LogMailer implements Mailer
{
    /** @param  list<string>  $to */
    public function send(array $to, string $subject, string $bodyText): void
    {
        $dest = implode(', ', $to);
        error_log("[gatekeeper-notify] SMTP unset — would send to={$dest} subject={$subject}");
        error_log('[gatekeeper-notify] body: '.str_replace("\n", ' | ', trim($bodyText)));
    }
}
