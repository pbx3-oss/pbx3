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

    /**
     * Tenant-move job reached a terminal failure or abort.
     *
     * @param  array<string, mixed>  $job
     * @param  'failed'|'aborted'  $outcome
     */
    public function notifyMoveJobTerminal(array $job, string $outcome): void
    {
        if ($outcome !== 'failed' && $outcome !== 'aborted') {
            return;
        }

        $recipients = $this->recipients();
        if ($recipients === []) {
            error_log('[gatekeeper-notify] no subscribers for move job '.$outcome.' — skip');

            return;
        }

        $jobId = (string) ($job['id'] ?? '(unknown)');
        $tenant = (string) ($job['tenant_shortuid'] ?? '');
        $fqdn = (string) ($job['tenant_fqdn'] ?? '');
        $source = (string) ($job['source_instance_id'] ?? '');
        $dest = (string) ($job['dest_instance_id'] ?? '');
        $error = trim((string) ($job['error'] ?? ''));
        $hint = trim((string) (($job['rollback']['hint'] ?? '') ?: ''));
        $actor = trim((string) ($job['last_action_by'] ?? $job['created_by'] ?? ''));
        $failedPhase = TenantMoveRunner::failedPhaseName($job);

        if ($outcome === 'failed') {
            $subject = "[PBX3 fleet] Move job failed: {$tenant}";
            $body = "A tenant-move job failed.\n\n";
        } else {
            $subject = "[PBX3 fleet] Move job aborted: {$tenant}";
            $body = "A tenant-move job was aborted (operator abort or post-cutover rollback).\n\n";
        }

        $body .= "Job: {$jobId}\n"
            ."Tenant: {$tenant}\n"
            ."FQDN: {$fqdn}\n"
            ."Source instance: {$source}\n"
            ."Dest instance: {$dest}\n"
            ."State: {$outcome}\n";
        if ($failedPhase !== null) {
            $body .= "Failed phase: {$failedPhase}\n";
        }
        if ($error !== '') {
            $body .= "Error: {$error}\n";
        }
        if ($hint !== '') {
            $body .= "Hint: {$hint}\n";
        }
        if ($actor !== '') {
            $body .= "Actor: {$actor}\n";
        }

        $this->send($recipients, $subject, $this->withUiLink($body, '/fleet/jobs'));
    }

    /**
     * SBC Fail2ban ban of an unknown / non-whitelisted IP (edge-detected).
     *
     * @param  array{
     *   source_ip?:string,
     *   jail?:string,
     *   sbc_fqdn?:string,
     *   currently_banned?:int
     * }  $event
     */
    public function notifyFail2banBan(array $event): void
    {
        $recipients = $this->recipients();
        if ($recipients === []) {
            error_log('[gatekeeper-notify] no subscribers for fail2ban_ban — skip');

            return;
        }

        $ip = (string) ($event['source_ip'] ?? '(unknown)');
        $jail = (string) ($event['jail'] ?? 'opensips-brute-force');
        $fqdn = (string) ($event['sbc_fqdn'] ?? '');
        $banned = (int) ($event['currently_banned'] ?? 0);

        $subject = "[PBX3 fleet] SBC Fail2ban ban: {$ip}";
        $body = "Fail2ban banned an IP on the SBC (unknown / non-whitelisted scanner).\n\n"
            ."Banned IP: {$ip}\n"
            ."Jail: {$jail}\n";
        if ($fqdn !== '') {
            $body .= "SBC: {$fqdn}\n";
        }
        if ($banned > 0) {
            $body .= "Currently banned (jail): {$banned}\n";
        }
        $body .= "\nReview Fail2ban status on the SBC admin panel if this looks wrong.\n";

        $this->send($recipients, $subject, $this->withUiLink($body));
    }

    /**
     * Edge VIP SIP probe transition.
     *
     * @param  array<string, mixed>  $pair
     * @param  'down'|'cleared'  $transition
     */
    public function notifyEdgeReachability(array $pair, string $transition): void
    {
        if ($transition !== 'down' && $transition !== 'cleared') {
            return;
        }

        $recipients = $this->recipients();
        if ($recipients === []) {
            error_log('[gatekeeper-notify] no subscribers for edge '.$transition.' — skip');

            return;
        }

        $id = (string) ($pair['id'] ?? '');
        $label = (string) ($pair['label'] ?? $id);
        $fqdn = (string) ($pair['fqdn'] ?? '');
        $eip = (string) ($pair['eip'] ?? '');
        $mode = (string) ($pair['mode'] ?? '');
        $health = EdgePairHealthStore::get($id);
        $lastOk = $health['last_ok_at'] ?? null;
        $lastProbe = $health['last_probe_at'] ?? null;

        if ($transition === 'down') {
            $subject = "[PBX3 fleet] Edge down: {$label}";
            $body = "SBC edge VIP unreachable from the control plane (SIP OPTIONS).\n\n"
                ."Label: {$label}\n"
                ."Id: {$id}\n"
                ."FQDN: {$fqdn}\n"
                ."EIP: {$eip}\n"
                ."Mode: {$mode}\n"
                .'Failure: SIP OPTIONS failed (after '.EdgePairHealthStore::DOWN_AFTER_MISSES." consecutive misses)\n"
                .'Last OK: '.($lastOk ?? '(never)')."\n"
                .'Last probe: '.($lastProbe ?? '(unknown)')."\n"
                ."If mode=managed: follow cast-iron promote checklist (CLI or AWS Console EIP).\n"
                ."If control is also dark: Console → Elastic IPs → Associate → standby.\n";
        } else {
            $subject = "[PBX3 fleet] Edge cleared: {$label}";
            $body = "SBC edge VIP is answering SIP OPTIONS again.\n\n"
                ."Label: {$label}\n"
                ."Id: {$id}\n"
                ."FQDN: {$fqdn}\n"
                ."EIP: {$eip}\n"
                .'Last OK: '.($lastOk ?? '(unknown)')."\n"
                .'Last probe: '.($lastProbe ?? '(unknown)')."\n";
        }

        $this->send($recipients, $subject, $this->withUiLink($body, '/fleet/edge'));
    }

    /**
     * Instance Egress PJSIP qualify transition (node AMI → ops-events).
     *
     * @param  array<string, mixed>  $event
     * @param  'down'|'cleared'  $transition
     */
    public function notifyEgressQualify(array $event, string $transition): void
    {
        if ($transition !== 'down' && $transition !== 'cleared') {
            return;
        }

        $recipients = $this->recipients();
        if ($recipients === []) {
            error_log('[gatekeeper-notify] no subscribers for egress '.$transition.' — skip');

            return;
        }

        $label = (string) ($event['instance_label'] ?? $event['instance_id'] ?? 'instance');
        $id = (string) ($event['instance_id'] ?? '');
        $fqdn = (string) ($event['fqdn'] ?? '');
        $trunk = (string) ($event['egress_trunk'] ?? 'Egress');
        $rtt = $event['rtt_ms'] ?? null;
        $consecutive = (int) ($event['consecutive_unavail'] ?? 0);

        if ($transition === 'down') {
            $subject = "[PBX3 fleet] Egress Unavail: {$label}";
            $body = "Fleet Egress trunk is Unavail (PJSIP OPTIONS qualify failed).\n"
                ."Outbound Dial via Egress may refuse until the SBC path recovers.\n\n"
                ."Label: {$label}\n"
                ."Id: {$id}\n"
                ."FQDN: {$fqdn}\n"
                ."Trunk: {$trunk}\n"
                ."State: Unavail\n";
            if ($consecutive > 0) {
                $body .= "Consecutive Unavail checks: {$consecutive}\n";
            }
        } else {
            $subject = "[PBX3 fleet] Egress cleared: {$label}";
            $body = "Fleet Egress trunk is Avail again.\n\n"
                ."Label: {$label}\n"
                ."Id: {$id}\n"
                ."FQDN: {$fqdn}\n"
                ."Trunk: {$trunk}\n"
                ."State: Avail\n";
            if ($rtt !== null && $rtt !== '') {
                $body .= "RTT: {$rtt} ms\n";
            }
        }

        $this->send($recipients, $subject, $this->withUiLink($body));
    }

    /**
     * Instance IRSF / high-cost destination velocity (node CDR → ops-events).
     *
     * @param  array{
     *   instance_id?:string,
     *   instance_label?:string,
     *   fqdn?:string,
     *   extension?:string,
     *   accountcode?:string,
     *   count?:int,
     *   window_minutes?:int,
     *   masked_prefixes?:list<string>,
     *   first_calldate?:string,
     *   last_calldate?:string,
     *   rule?:string
     * }  $event
     * @param  'down'|'cleared'  $transition
     */
    public function notifyVelocityIrsf(array $event, string $transition): void
    {
        if ($transition !== 'down' && $transition !== 'cleared') {
            return;
        }

        $recipients = $this->recipients();
        if ($recipients === []) {
            error_log('[gatekeeper-notify] no subscribers for velocity_irsf '.$transition.' — skip');

            return;
        }

        $label = (string) ($event['instance_label'] ?? $event['instance_id'] ?? 'instance');
        $id = (string) ($event['instance_id'] ?? '');
        $fqdn = (string) ($event['fqdn'] ?? '');
        $ext = (string) ($event['extension'] ?? '(unknown)');
        $account = trim((string) ($event['accountcode'] ?? ''));
        $count = (int) ($event['count'] ?? 0);
        $window = (int) ($event['window_minutes'] ?? 5);
        $masked = $event['masked_prefixes'] ?? [];
        if (! is_array($masked)) {
            $masked = [];
        }
        $masked = array_values(array_filter(array_map('strval', $masked)));
        $first = trim((string) ($event['first_calldate'] ?? ''));
        $last = trim((string) ($event['last_calldate'] ?? ''));

        if ($transition === 'down') {
            $subject = "[PBX3 fleet] Velocity IRSF: ext {$ext} on {$label}";
            $body = "High-cost outbound surge detected from CDR (IRSF-shaped).\n"
                ."Review the phone / credentials; auto-block (active=NO) ships in a later phase.\n\n";
        } else {
            $subject = "[PBX3 fleet] Velocity IRSF cleared: ext {$ext} on {$label}";
            $body = "High-cost outbound surge has been quiet under threshold.\n\n";
        }

        $body .= "Label: {$label}\n"
            ."Id: {$id}\n"
            ."FQDN: {$fqdn}\n"
            ."Extension (src): {$ext}\n";
        if ($account !== '') {
            $body .= "Accountcode: {$account}\n";
        }
        $body .= "Count: {$count} in {$window}m\n";
        if ($masked !== []) {
            $body .= 'Masked dest prefixes: '.implode(', ', array_slice($masked, 0, 12))."\n";
        }
        if ($first !== '' || $last !== '') {
            $body .= 'Burst window: '.($first !== '' ? $first : '?').' → '.($last !== '' ? $last : '?')."\n";
        }

        $this->send($recipients, $subject, $this->withUiLink($body));
    }

    /**
     * @param  array<string, mixed>  $pair
     * @param  array<string, mixed>  $result
     */
    public function notifyEdgePromoted(array $pair, array $result): void
    {
        $recipients = $this->recipients();
        if ($recipients === []) {
            error_log('[gatekeeper-notify] no subscribers for edge_promoted — skip');

            return;
        }

        $label = (string) ($pair['label'] ?? $pair['id'] ?? 'edge');
        $fqdn = (string) ($pair['fqdn'] ?? '');
        $member = (string) ($result['active_member'] ?? $pair['active_member'] ?? '');
        $inst = (string) ($result['standby_instance_id'] ?? '');
        $subject = "[PBX3 fleet] Edge promoted: {$label}";
        $body = "Auto (or Promote now) moved the EIP onto the standby.\n\n"
            ."Label: {$label}\n"
            ."FQDN: {$fqdn}\n"
            ."New active member: {$member}\n"
            ."Instance: {$inst}\n"
            ."Check Fleet Edge HA for fence + Phase D LE result; if LE failed run cast-iron Phase D.\n";

        $this->send($recipients, $subject, $this->withUiLink($body, '/fleet/edge'));
    }

    /** @param  array<string, mixed>  $pair */
    public function notifyEdgePromoteFailed(array $pair, string $error): void
    {
        $recipients = $this->recipients();
        if ($recipients === []) {
            error_log('[gatekeeper-notify] no subscribers for edge_promote_failed — skip');

            return;
        }

        $label = (string) ($pair['label'] ?? $pair['id'] ?? 'edge');
        $subject = "[PBX3 fleet] Edge promote FAILED: {$label}";
        $body = "EIP promote failed — use cast-iron checklist / AWS Console.\n\n"
            ."Label: {$label}\n"
            .'FQDN: '.((string) ($pair['fqdn'] ?? ''))."\n"
            ."Error: {$error}\n";

        $this->send($recipients, $subject, $this->withUiLink($body, '/fleet/edge'));
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

    private function withUiLink(string $body, string $path = '/fleet/instances'): string
    {
        $uiBase = rtrim((string) (getenv('GATEKEEPER_FLEET_UI_URL') ?: ''), '/');
        if ($uiBase !== '') {
            $path = '/'.ltrim($path, '/');
            $body .= "\nFleet UI: {$uiBase}{$path}\n";
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
