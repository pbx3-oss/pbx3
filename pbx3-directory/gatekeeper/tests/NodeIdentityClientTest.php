<?php

declare(strict_types=1);

namespace Pbx3\Gatekeeper\Tests;

use GuzzleHttp\Client;
use GuzzleHttp\Handler\MockHandler;
use GuzzleHttp\HandlerStack;
use GuzzleHttp\Middleware;
use GuzzleHttp\Psr7\Response;
use PHPUnit\Framework\TestCase;
use Pbx3\Gatekeeper\NodeIdentityClient;

final class NodeIdentityClientTest extends TestCase
{
    public function test_fetch_normalizes_api_base_and_maps_body(): void
    {
        $history = [];
        $mock = new MockHandler([
            new Response(200, [], json_encode([
                'ok' => true,
                'id' => '2H7K9exampleKSUID00000001',
                'shortuid' => 'jgfnd7',
                'fqdn' => 'jgfnd7.pbx3.com',
                'sitename' => 'Lab Home',
            ], JSON_THROW_ON_ERROR)),
        ]);
        $stack = HandlerStack::create($mock);
        $stack->push(Middleware::history($history));
        $http = new Client(['handler' => $stack, 'http_errors' => false]);

        $client = new NodeIdentityClient($http, 'fleet-token-test');
        $out = $client->fetch('https://192.168.1.31:44300');

        $this->assertTrue($out['ok']);
        $this->assertSame('2H7K9exampleKSUID00000001', $out['id']);
        $this->assertSame('jgfnd7', $out['shortuid']);
        $this->assertSame('jgfnd7.pbx3.com', $out['fqdn']);
        $this->assertSame('Lab Home', $out['sitename']);
        $this->assertSame('https://192.168.1.31:44300/api', $out['api_base_url']);

        $this->assertCount(1, $history);
        $req = $history[0]['request'];
        $this->assertSame('GET', $req->getMethod());
        $this->assertSame(
            'https://192.168.1.31:44300/api/fleet/identity',
            (string) $req->getUri()
        );
        $this->assertSame('Bearer fleet-token-test', $req->getHeaderLine('Authorization'));
    }

    public function test_fetch_requires_token(): void
    {
        $this->expectException(\RuntimeException::class);
        $this->expectExceptionMessage('PBX3_FLEET_SERVICE_TOKEN');
        (new NodeIdentityClient(new Client(['http_errors' => false]), ''))->fetch('https://h/api');
    }
}
