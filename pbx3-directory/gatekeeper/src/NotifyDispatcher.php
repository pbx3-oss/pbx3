<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper;

/** Transition-based fleet ops mail (reachability + catalog lifecycle). */
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

        $recipients = $this->recipients();
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

        $this->send($recipients, $subject, $this->withUiLink($body));
    }

    /**
     * Catalog status change (SPA Maintenance / Active / soft decommission).
     *
     * @param  array<string, mixed>  $instance
     */
    public function notifyInstanceLifecycle(array $instance, string $fromStatus, string $toStatus): void
    {
        $from = strtolower(trim($fromStatus));
        $to = strtolower(trim($toStatus));
        if ($from === $to || $to === '') {
            return;
        }

        $interesting = ['maintenance', 'decommissioned', 'active'];
        if (! in_array($to, $interesting, true)) {
            return;
        }
        // Only mail when entering/leaving maintenance or decommissioned (not active→active noise).
        if ($to === 'active' && ! in_array($from, ['maintenance', 'decommissioned'], true)) {
            return;
        }
        if ($to !== 'active' && ! in_array($to, ['maintenance', 'decommissioned'], true)) {
            return;
        }

        $recipients = $this->recipients();
        if ($recipients === []) {
            error_log('[gatekeeper-notify] no subscribers for lifecycle '.$from.'→'.$to.' — skip');

            return;
        }

        $id = (string) ($instance['id'] ?? '');
        $label = (string) ($instance['label'] ?? $id);
        $fqdn = (string) ($instance['fqdn'] ?? '');
        $by = (string) ($instance['updated_by'] ?? '');

        if ($to === 'maintenance') {
            $subject = "[PBX3 fleet] Instance maintenance: {$label}";
            $body = "Instance marked maintenance in the fleet catalog (probe skipped while in this state).\n\n";
        } elseif ($to === 'decommissioned') {
            $subject = "[PBX3 fleet] Instance decommissioned: {$label}";
            $body = "Instance soft-decommissioned in the fleet catalog (hidden from picker; node not stopped).\n\n";
        } else {
            $subject = "[PBX3 fleet] Instance active again: {$label}";
            $body = "Instance returned to active in the fleet catalog (was {$from}).\n\n";
        }

        $body .= "Label: {$label}\n"
            ."Id: {$id}\n"
            ."FQDN: {$fqdn}\n"
            ."Status: {$from} → {$to}\n";
        if ($by !== '') {
            $body .= "Updated by: {$by}\n";
        }

        $this->send($recipients, $subject, $this->withUiLink($body));
    }

    /**
     * Whitelist-gated misconfigured phone REGISTER loop (node-detected).
     *
     * @param  array{
     *   instance_id?:string,
     *   instance_label?:string,
     *   fqdn?:string,
     *   extension?:string,
     *   endpoint_uid?:string,
     *   endpoint_name?:string,
     *   source_ip?:string,
     *   count?:int,
     *   window_seconds?:int,
     *   sample?:string
     * }  $event
     */
    public function notifyMisconfigRegister(array $event): void
    {
        $recipients = $this->recipients();
        if ($recipients === []) {
            error_log('[gatekeeper-notify] no subscribers for misconfig_register — skip');

            return;
        }

        $label = (string) ($event['instance_label'] ?? $event['instance_id'] ?? 'instance');
        $id = (string) ($event['instance_id'] ?? '');
        $fqdn = (string) ($event['fqdn'] ?? '');
        $ext = (string) ($event['extension'] ?? '(unknown)');
        $uid = trim((string) ($event['endpoint_uid'] ?? ''));
        $name = trim((string) ($event['endpoint_name'] ?? ''));
        $ip = (string) ($event['source_ip'] ?? '(unknown)');
        $count = (int) ($event['count'] ?? 0);
        $window = (int) ($event['window_seconds'] ?? 600);
        $sample = trim((string) ($event['sample'] ?? ''));

        $extDisplay = $ext;
        if ($uid !== '' && strcasecmp($uid, $ext) !== 0) {
            $extDisplay = "{$ext} ({$uid})";
        }
        if ($name !== '') {
            $extDisplay .= " — {$name}";
        }

        $subject = "[PBX3 fleet] REGISTER auth loop: ext {$ext} on {$label}";
        $body = "Repeated failed REGISTER from a Fail2ban-whitelisted address (misconfigured phone likely).\n"
            ."Do not ban this IP — fix the handset credentials.\n\n"
            ."Label: {$label}\n"
            ."Id: {$id}\n"
            ."FQDN: {$fqdn}\n"
            ."Extension: {$extDisplay}\n"
            ."Source IP: {$ip}\n"
            ."Failures: {$count} in {$window}s\n";
        if ($sample !== '') {
            $body .= 'Sample: '.$sample."\n";
        }

        $this->send($recipients, $subject, $this->withUiLink($body));
    }

    /** @return list<string> */
    private function recipients(): array
    {
        $recipients = UserStore::notifyFailureEmails();
        $ops = trim((string) (getenv('GATEKEEPER_OPS_NOTIFY_EMAIL') ?: ''));
        if ($ops !== '' && filter_var($ops, FILTER_VALIDATE_EMAIL)) {
            $recipients[] = $ops;
        }

        return array_values(array_unique($recipients));
    }

    private function withUiLink(string $body): string
    {
        $uiBase = rtrim((string) (getenv('GATEKEEPER_FLEET_UI_URL') ?: ''), '/');
        if ($uiBase !== '') {
            $body .= "\nFleet UI: {$uiBase}/fleet/instances\n";
        }

        return $body;
    }

    /** @param  list<string>  $recipients */
    private function send(array $recipients, string $subject, string $body): void
    {
        try {
            $this->mailer->send($recipients, $subject, $body);
        } catch (\Throwable $e) {
            error_log('[gatekeeper-notify] send failed: '.$e->getMessage());
        }
    }
}
