<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper;

/**
 * Minimal SMTP client (AUTH LOGIN + optional STARTTLS). No Composer mail dep.
 * Env: GATEKEEPER_SMTP_HOST, GATEKEEPER_SMTP_PORT, GATEKEEPER_SMTP_USER,
 * GATEKEEPER_SMTP_PASS, GATEKEEPER_SMTP_FROM, GATEKEEPER_SMTP_TLS (true|false).
 */
final class SmtpMailer implements Mailer
{
    public function __construct(
        private readonly string $host,
        private readonly int $port,
        private readonly string $user,
        private readonly string $pass,
        private readonly string $from,
        private readonly bool $startTls = true,
    ) {
    }

    public static function fromEnv(): ?self
    {
        $host = trim((string) (getenv('GATEKEEPER_SMTP_HOST') ?: ''));
        if ($host === '') {
            return null;
        }
        $from = trim((string) (getenv('GATEKEEPER_SMTP_FROM') ?: ''));
        if ($from === '') {
            throw new \RuntimeException('GATEKEEPER_SMTP_FROM required when GATEKEEPER_SMTP_HOST is set', 500);
        }
        $port = (int) (getenv('GATEKEEPER_SMTP_PORT') ?: '587');
        $user = (string) (getenv('GATEKEEPER_SMTP_USER') ?: '');
        $pass = (string) (getenv('GATEKEEPER_SMTP_PASS') ?: '');
        $tls = filter_var(getenv('GATEKEEPER_SMTP_TLS') ?: 'true', FILTER_VALIDATE_BOOL);

        return new self($host, $port > 0 ? $port : 587, $user, $pass, $from, $tls);
    }

    /** @param  list<string>  $to */
    public function send(array $to, string $subject, string $bodyText): void
    {
        $recipients = [];
        foreach ($to as $addr) {
            $addr = trim($addr);
            if ($addr !== '' && filter_var($addr, FILTER_VALIDATE_EMAIL)) {
                $recipients[] = $addr;
            }
        }
        if ($recipients === []) {
            throw new \InvalidArgumentException('No valid recipients');
        }

        $errno = 0;
        $errstr = '';
        $fp = @stream_socket_client(
            "tcp://{$this->host}:{$this->port}",
            $errno,
            $errstr,
            15,
            STREAM_CLIENT_CONNECT
        );
        if ($fp === false) {
            throw new \RuntimeException("SMTP connect failed: {$errstr} ({$errno})", 500);
        }
        stream_set_timeout($fp, 20);

        try {
            $this->expect($fp, 220);
            $this->cmd($fp, 'EHLO localhost', 250);
            if ($this->startTls) {
                $this->cmd($fp, 'STARTTLS', 220);
                if (! stream_socket_enable_crypto($fp, true, STREAM_CRYPTO_METHOD_TLS_CLIENT)) {
                    throw new \RuntimeException('SMTP STARTTLS failed', 500);
                }
                $this->cmd($fp, 'EHLO localhost', 250);
            }
            if ($this->user !== '') {
                $this->cmd($fp, 'AUTH LOGIN', 334);
                $this->cmd($fp, base64_encode($this->user), 334);
                $this->cmd($fp, base64_encode($this->pass), 235);
            }
            $this->cmd($fp, 'MAIL FROM:<'.$this->from.'>', 250);
            foreach ($recipients as $rcpt) {
                $this->cmd($fp, 'RCPT TO:<'.$rcpt.'>', 250);
            }
            $this->cmd($fp, 'DATA', 354);
            $headers = [
                'From: '.$this->from,
                'To: '.implode(', ', $recipients),
                'Subject: '.$this->encodeHeader($subject),
                'MIME-Version: 1.0',
                'Content-Type: text/plain; charset=UTF-8',
                'Content-Transfer-Encoding: 8bit',
                'Date: '.gmdate('D, d M Y H:i:s O'),
            ];
            $data = implode("\r\n", $headers)."\r\n\r\n".$this->dotStuff($bodyText)."\r\n.";
            fwrite($fp, $data."\r\n");
            $this->expect($fp, 250);
            $this->cmd($fp, 'QUIT', 221);
        } finally {
            fclose($fp);
        }
    }

    /** @param  resource  $fp */
    private function cmd($fp, string $line, int $expectCode): void
    {
        fwrite($fp, $line."\r\n");
        $this->expect($fp, $expectCode);
    }

    /** @param  resource  $fp */
    private function expect($fp, int $code): void
    {
        $response = '';
        while (($line = fgets($fp, 515)) !== false) {
            $response .= $line;
            if (isset($line[3]) && $line[3] === ' ') {
                break;
            }
            if (! isset($line[3]) || $line[3] !== '-') {
                break;
            }
        }
        $got = (int) substr($response, 0, 3);
        if ($got !== $code) {
            throw new \RuntimeException(
                "SMTP expected {$code}, got {$got}: ".trim($response),
                500
            );
        }
    }

    private function encodeHeader(string $subject): string
    {
        if (preg_match('/^[\x20-\x7E]*$/', $subject) === 1) {
            return $subject;
        }

        return '=?UTF-8?B?'.base64_encode($subject).'?=';
    }

    private function dotStuff(string $body): string
    {
        $body = str_replace(["\r\n", "\r"], "\n", $body);
        $lines = explode("\n", $body);
        foreach ($lines as &$line) {
            if (str_starts_with($line, '.')) {
                $line = '.'.$line;
            }
        }

        return implode("\r\n", $lines);
    }
}
