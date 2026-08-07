<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper;

use BaconQrCode\Renderer\Image\SvgImageBackEnd;
use BaconQrCode\Renderer\ImageRenderer;
use BaconQrCode\Renderer\RendererStyle\RendererStyle;
use BaconQrCode\Writer;
use PragmaRX\Google2FA\Google2FA;

/** Opt-in TOTP helpers for Gatekeeper SQLite users (control plane only). */
final class TotpService
{
    public const RECOVERY_CODE_COUNT = 8;

    private Google2FA $google2fa;

    public function __construct(?Google2FA $google2fa = null)
    {
        $this->google2fa = $google2fa ?? new Google2FA;
    }

    public function issuer(): string
    {
        $issuer = trim((string) (getenv('GATEKEEPER_TOTP_ISSUER') ?: ''));

        return $issuer !== '' ? $issuer : 'Aelintra Fleet';
    }

    public function generateSecret(): string
    {
        return $this->google2fa->generateSecretKey(32);
    }

    public function encryptSecret(string $plain): string
    {
        $key = $this->encryptionKey();
        $iv = random_bytes(16);
        $cipher = openssl_encrypt($plain, 'AES-256-CBC', $key, OPENSSL_RAW_DATA, $iv);
        if ($cipher === false) {
            throw new \RuntimeException('Failed to encrypt TOTP secret', 500);
        }

        return base64_encode($iv.$cipher);
    }

    public function decryptSecret(?string $encrypted): ?string
    {
        if ($encrypted === null || $encrypted === '') {
            return null;
        }
        $raw = base64_decode($encrypted, true);
        if ($raw === false || strlen($raw) < 17) {
            return null;
        }
        $iv = substr($raw, 0, 16);
        $cipher = substr($raw, 16);
        $plain = openssl_decrypt($cipher, 'AES-256-CBC', $this->encryptionKey(), OPENSSL_RAW_DATA, $iv);

        return $plain === false || $plain === '' ? null : $plain;
    }

    public function otpauthUrl(string $email, string $plainSecret): string
    {
        return $this->google2fa->getQRCodeUrl(
            $this->issuer(),
            $email,
            $plainSecret
        );
    }

    public function qrDataUri(string $otpauthUrl): string
    {
        $renderer = new ImageRenderer(
            new RendererStyle(220),
            new SvgImageBackEnd
        );
        $writer = new Writer($renderer);
        $svg = $writer->writeString($otpauthUrl);

        return 'data:image/svg+xml;base64,'.base64_encode($svg);
    }

    public function verify(string $plainSecret, string $code): bool
    {
        $code = preg_replace('/\s+/', '', $code) ?? '';
        if ($code === '' || ! ctype_digit($code)) {
            return false;
        }

        return (bool) $this->google2fa->verifyKey($plainSecret, $code, 1);
    }

    /**
     * @return list<string>
     */
    public function generateRecoveryCodes(): array
    {
        $codes = [];
        for ($i = 0; $i < self::RECOVERY_CODE_COUNT; $i++) {
            $codes[] = strtoupper(bin2hex(random_bytes(2)).'-'.bin2hex(random_bytes(2)));
        }

        return $codes;
    }

    /**
     * @param  list<string>  $plainCodes
     */
    public function hashRecoveryCodes(array $plainCodes): string
    {
        $hashed = [];
        foreach ($plainCodes as $c) {
            $hash = password_hash(strtoupper(trim($c)), PASSWORD_DEFAULT);
            if ($hash === false) {
                throw new \RuntimeException('password_hash failed', 500);
            }
            $hashed[] = $hash;
        }

        return json_encode(array_values($hashed), JSON_THROW_ON_ERROR);
    }

    /**
     * @return list<string>
     */
    public function decodeRecoveryHashes(?string $json): array
    {
        if ($json === null || $json === '') {
            return [];
        }
        $decoded = json_decode($json, true);

        return is_array($decoded)
            ? array_values(array_filter($decoded, static fn ($h) => is_string($h) && $h !== ''))
            : [];
    }

    /**
     * @param  callable(string):void  $persistHashes  receive JSON of remaining hashes
     */
    public function consumeRecoveryCode(?string $json, string $code, callable $persistHashes): bool
    {
        $code = strtoupper(trim(preg_replace('/\s+/', '', $code) ?? ''));
        if ($code === '') {
            return false;
        }

        $hashes = $this->decodeRecoveryHashes($json);
        foreach ($hashes as $i => $hash) {
            if (password_verify($code, $hash)) {
                unset($hashes[$i]);
                $persistHashes(json_encode(array_values($hashes), JSON_THROW_ON_ERROR));

                return true;
            }
        }

        return false;
    }

    private function encryptionKey(): string
    {
        $material = trim((string) (getenv('GATEKEEPER_TOTP_KEY') ?: ''));
        if ($material === '') {
            $material = trim((string) (getenv('GATEKEEPER_API_TOKEN') ?: ''));
        }
        if ($material === '') {
            $material = 'gatekeeper-totp-dev-key';
        }

        return hash('sha256', $material, true);
    }
}
