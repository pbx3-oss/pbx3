<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper\Http;

final class JsonResponse
{
    /** @param array<string, mixed> $data */
    public static function send(int $code, array $data): never
    {
        http_response_code($code);
        header('Content-Type: application/json');
        header('Access-Control-Allow-Origin: *');
        header('Access-Control-Allow-Headers: Authorization, Content-Type, Accept');
        header('Access-Control-Allow-Methods: GET, POST, DELETE, OPTIONS');
        echo json_encode($data, JSON_UNESCAPED_SLASHES | JSON_PRETTY_PRINT);
        exit;
    }
}
