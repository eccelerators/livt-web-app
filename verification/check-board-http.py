#!/usr/bin/env python3
"""Opt-in checks of complete responses from the FPGA demo, without flashing it."""
import argparse
import ast
import hashlib
import json
from pathlib import Path
import re
import socket
import time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--host', default='10.0.0.2')
parser.add_argument('--port', type=int, default=80)
parser.add_argument('--timeout', type=float, default=10)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parent.parent
args.output.mkdir(parents=True, exist_ok=True)


def page(name):
    source = (root / 'src' / (name + 'HtmlStore.lvt')).read_text()
    literal = re.search(r"(['\"])(<!doctype html>.*?)\1\.Encode\(\)", source, re.S)
    if literal is None:
        raise RuntimeError(f'Cannot find the declared {name} page')
    return ast.literal_eval(literal.group(1) + literal.group(2) + literal.group(1)).encode()


home, about, status = page('Index'), page('About'), page('Status')
counter_offsets = (1126, 1160, 1197, 1232, 1272, 1313)
cases = [
    ('home', 'GET', '/', '200 OK', home),
    ('about', 'GET', '/about', '200 OK', about),
    ('status', 'GET', '/status', '200 OK', status),
    ('about-query', 'GET', '/about?x=1', '200 OK', about),
    ('missing', 'GET', '/missing', '404 Not Found', b'Not Found\n'),
    ('trailing-slash', 'GET', '/about/', '404 Not Found', b'Not Found\n'),
    ('method', 'POST', '/', '405 Method Not Allowed', b'Method Not Allowed\n'),
    ('home-again', 'GET', '/', '200 OK', home),
]
results = []
for name, method, target, code, expected in cases:
    # One complete HTTP/1.1 request segment, including Host, with no request body.
    request = f'{method} {target} HTTP/1.1\r\nHost: {args.host}\r\nConnection: close\r\n\r\n'.encode()
    started = time.monotonic()
    with socket.create_connection((args.host, args.port), timeout=args.timeout) as connection:
        connection.sendall(request)
        chunks = []
        while True:
            chunk = connection.recv(4096)
            if not chunk:
                break
            chunks.append(chunk)
            if sum(map(len, chunks)) > 4096:
                raise RuntimeError(f'{name}: response exceeds the demo budget')
    response = b''.join(chunks)
    (args.output / (name + '.http')).write_bytes(response)
    header, separator, body = response.partition(b'\r\n\r\n')
    media = 'text/html' if code == '200 OK' else 'text/plain'
    allow = 'Allow: GET\r\n' if code.startswith('405') else ''
    expected_header = (
        f'HTTP/1.0 {code}\r\nContent-Type: {media}\r\n{allow}'
        f'Content-Length: {len(expected)}\r\nConnection: close'
    ).encode()
    if not separator or header != expected_header:
        raise RuntimeError(f'{name}: unexpected HTTP headers: {header!r}')
    comparable = bytearray(body)
    if name == 'status' and len(body) == len(expected):
        for offset in counter_offsets:
            if body[offset] not in b'0123456789ABCDEF':
                raise RuntimeError(f'{name}: invalid counter digit at {offset}')
            comparable[offset] = expected[offset]
    if comparable != expected:
        raise RuntimeError(f'{name}: body mismatch ({len(body)} bytes, expected {len(expected)})')
    results.append({'case': name, 'status': code, 'body_bytes': len(body),
                    'body_sha256': hashlib.sha256(body).hexdigest(),
                    'elapsed_ms': round((time.monotonic() - started) * 1000, 2)})
    (args.output / 'results.json').write_text(json.dumps(results, indent=2) + '\n')
    print(f'PASS: {name}: {code}, complete {len(body)}-byte body', flush=True)

print(f'PASS: {len(results)} complete HTTP responses; captured in {args.output}')
