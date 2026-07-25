#!/usr/bin/env php
<?php
/**
 * Normalize Asterisk-ish conf text for GenAst characterization diffs.
 *
 * Usage:
 *   genast-normalize.php <infile> > outfile
 *   genast-normalize.php --dir <indir> <outdir>
 *
 * Strips volatile banners/timestamps; sorts PJSIP [sections];
 * for extensions.conf-like files, sorts exten lines within a context by exten|priority|app.
 */
if ($argc < 2) {
    fwrite(STDERR, "Usage: genast-normalize.php <file> | --dir <in> <out>\n");
    exit(2);
}

if ($argv[1] === '--dir') {
    if ($argc < 4) {
        fwrite(STDERR, "Usage: genast-normalize.php --dir <in> <out>\n");
        exit(2);
    }
    $inDir = rtrim($argv[2], '/');
    $outDir = rtrim($argv[3], '/');
    if (!is_dir($inDir)) {
        fwrite(STDERR, "Not a directory: $inDir\n");
        exit(1);
    }
    if (!is_dir($outDir) && !mkdir($outDir, 0755, true)) {
        fwrite(STDERR, "Cannot create: $outDir\n");
        exit(1);
    }
    $files = scandir($inDir);
    $n = 0;
    foreach ($files as $f) {
        if ($f === '.' || $f === '..') {
            continue;
        }
        $path = $inDir . '/' . $f;
        if (!is_file($path)) {
            continue;
        }
        if (!preg_match('/\.(conf|tmpl)$/', $f) && $f !== 'extensions.conf') {
            // Still normalize anything that looks like conf
            if (!preg_match('/conf/', $f)) {
                continue;
            }
        }
        $raw = file_get_contents($path);
        if ($raw === false) {
            continue;
        }
        $norm = genast_normalize($raw, $f);
        file_put_contents($outDir . '/' . $f, $norm);
        $n++;
    }
    fwrite(STDERR, "Normalized $n file(s) → $outDir\n");
    exit(0);
}

$path = $argv[1];
$raw = file_get_contents($path);
if ($raw === false) {
    fwrite(STDERR, "Cannot read: $path\n");
    exit(1);
}
echo genast_normalize($raw, basename($path));
exit(0);

function genast_normalize(string $raw, string $name): string
{
    // Drop CR; trim trailing whitespace on lines
    $raw = str_replace("\r\n", "\n", $raw);
    $raw = str_replace("\r", "\n", $raw);

    $lines = explode("\n", $raw);
    $out = [];
    foreach ($lines as $line) {
        $t = rtrim($line);
        // Volatile GenAst / file banners
        if (preg_match('/^;\s*(Generated|Created|Date|Timestamp|commit)\b/i', $t)) {
            continue;
        }
        if (preg_match('/^;\s*\d{4}-\d{2}-\d{2}/', $t)) {
            continue;
        }
        if (preg_match('/^;\s*File generated/i', $t)) {
            continue;
        }
        $out[] = $t;
    }
    $text = implode("\n", $out);

    $isExt = (stripos($name, 'extension') !== false);
    if ($isExt) {
        return genast_normalize_dialplan($text);
    }
    return genast_normalize_ini_sections($text);
}

function genast_normalize_ini_sections(string $text): string
{
    $sections = [];
    $order = [];
    $cur = '_preamble';
    $sections[$cur] = [];
    $order[] = $cur;

    foreach (explode("\n", $text) as $line) {
        if (preg_match('/^\[([^\]]+)\]\s*$/', $line, $m)) {
            $cur = $m[1];
            if (!isset($sections[$cur])) {
                $sections[$cur] = [];
                $order[] = $cur;
            }
            continue;
        }
        $sections[$cur][] = $line;
    }

    // Keep preamble order; sort named sections alphabetically
    $named = array_values(array_filter($order, fn($k) => $k !== '_preamble'));
    sort($named, SORT_STRING);

    $parts = [];
    if (!empty($sections['_preamble'])) {
        $pre = rtrim(implode("\n", $sections['_preamble']));
        if ($pre !== '') {
            $parts[] = $pre;
        }
    }
    foreach ($named as $sec) {
        $body = $sections[$sec];
        // Drop trailing empties inside section for stability
        while (!empty($body) && end($body) === '') {
            array_pop($body);
        }
        $block = '[' . $sec . "]\n" . implode("\n", $body);
        $parts[] = rtrim($block);
    }
    return implode("\n\n", $parts) . "\n";
}

function genast_normalize_dialplan(string $text): string
{
    // Preserve context and line order (exten/same => pairs must stay adjacent).
    // Only collapse runs of blank lines for quieter diffs.
    $lines = explode("\n", $text);
    $out = [];
    $blank = 0;
    foreach ($lines as $line) {
        if ($line === '') {
            $blank++;
            if ($blank > 1) {
                continue;
            }
            $out[] = '';
            continue;
        }
        $blank = 0;
        $out[] = $line;
    }
    while (!empty($out) && end($out) === '') {
        array_pop($out);
    }
    return implode("\n", $out) . "\n";
}
