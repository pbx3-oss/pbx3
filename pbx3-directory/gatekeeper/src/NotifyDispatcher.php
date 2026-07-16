<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper;

/** Transition-based fleet failure mail (instance down / cleared). */
final class NotifyDispatcher
{
    public function __construct(
        private readonly Mailer $mailer,
    ) {
    }

    public static function fromEnv(): self
    {
        $smtp = SmtpMailer::fromEnv();

        return new self($smtp ?? new LogMailer());
    }

    /**
     * @param  array<string, mixed>  $instance  catalog row
     * @param  'down'|'cleared'  $transition
     */
    public function notifyInstanceReachability(array $instance, string $transition): void
    {
        if ($transition !== 'down' && $transition !== 'cleared') {
            return;
        }

        $recipients = UserStore::notifyFailureEmails();
        $ops = trim((string) (getenv('GATEKEEPER_OPS_NOTIFY_EMAIL') ?: ''));
        if ($ops !== '' && filter_var($ops, FILTER_VALIDATE_EMAIL)) {
            $recipients[] = $ops;
        }
        $recipients = array_values(array_unique($recipients));
        if ($recipients === []) {
            error_log('[gatekeeper-notify] no subscribers for instance '.$transition.' — skip');

            return;
        }

        $id = (string) ($instance['id'] ?? '');
        $label = (string) ($instance['label'] ?? $id);
        $fqdn = (string) ($instance['fqdn'] ?? '');
        $health = InstanceHealthStore::get($id);
        $lastOk = $health['last_ok_at'] ?? null;
        $lastProbe = $health['last_probe_at'] ?? null;
        $uiBase = rtrim((string) (getenv('GATEKEEPER_FLEET_UI_URL') ?: ''), '/');
        $link = $uiBase !== '' ? $uiBase.'/fleet/instances' : '';

        if ($transition === 'down') {
            $subject = "[PBX3 fleet] Instance down: {$label}";
            $body = "Instance unreachable from the control plane.\n\n"
                ."Label: {$label}\n"
                ."Id: {$id}\n"
                ."FQDN: {$fqdn}\n"
                .'Failure: /up probe failed (after '.InstanceHealthStore::DOWN_AFTER_MISSES." consecutive misses)\n"
                .'Last OK: '.($lastOk ?? '(never)')."\n"
                .'Last probe: '.($lastProbe ?? '(unknown)')."\n";
        } else {
            $subject = "[PBX3 fleet] Instance cleared: {$label}";
            $body = "Instance is reachable again.\n\n"
                ."Label: {$label}\n"
                ."Id: {$id}\n"
                ."FQDN: {$fqdn}\n"
                .'Last OK: '.($lastOk ?? '(unknown)')."\n"
                .'Last probe: '.($lastProbe ?? '(unknown)')."\n";
        }
        if ($link !== '') {
            $body .= "\nFleet UI: {$link}\n";
        }

        try {
            $this->mailer->send($recipients, $subject, $body);
        } catch (\Throwable $e) {
            error_log('[gatekeeper-notify] send failed: '.$e->getMessage());
        }
    }
}
