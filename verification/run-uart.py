#!/usr/bin/env python3
"""Decode the real WebApp UART output before and after reset using unmodified HDL."""
import argparse
import os
from pathlib import Path
import re
import subprocess
import tempfile

HERE = Path(__file__).resolve().parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--generated', type=Path, default=HERE.parent / 'out/debug')
    parser.add_argument('--ghdl', default=os.environ.get('LIVT_GHDL_PATH', 'ghdl'))
    parser.add_argument('--clock-hz', type=int, choices=(10000000, 100000000), default=10000000,
                        help='Simulation clock; 10 MHz reduces cycles while retaining 115200-baud framing')
    args = parser.parse_args()
    generated = args.generated.resolve()
    candidates = list(generated.rglob('Livt.WebApp.WebApp.vhd'))
    if len(candidates) != 1:
        raise RuntimeError(f'Expected one generated WebApp entity: {candidates}')
    source = candidates[0].read_text().split('architecture ')[0]
    ports = re.findall(r'^\s*(get\w+) : (in|out) t_\w+;', source, re.M)
    if not ports:
        raise RuntimeError('No diagnostic getter ports found in WebApp entity')
    mappings = [name + " => " + ("(run => '0')" if direction == 'in' else 'open')
                for name, direction in ports]
    bench = (HERE / 'uart-banner.vhd').read_text().replace('@GETTER_PORTS@', ',\n    '.join(mappings))
    stage = Path(tempfile.mkdtemp(prefix='livt-webapp-uart-'))
    (stage / 'uart-banner.vhd').write_text(bench)
    print(f'Evidence: {stage}', flush=True)
    commands = [
        [args.ghdl, '-i', '--std=08', *map(str, generated.rglob('*.vhd')), str(stage / 'uart-banner.vhd')],
        [args.ghdl, '-m', '--std=08', 'uart_banner'],
        [args.ghdl, '-r', '--std=08', 'uart_banner', f'-gTEST_CLOCK_HZ={args.clock_hz}', '--assert-level=error'],
    ]
    for index, command in enumerate(commands):
        log = stage / f'{index}.log'
        try:
            with log.open('w') as output:
                result = subprocess.run(command, cwd=stage, stdout=output, stderr=subprocess.STDOUT,
                                        text=True, timeout=600)
        except subprocess.TimeoutExpired as error:
            raise RuntimeError(f'GHDL timed out; partial output retained in {log}') from error
        captured = log.read_text()
        if result.returncode:
            raise RuntimeError(f'GHDL failed; see {log}\n{captured[-2000:]}')
    if 'Simulation finished: WebApp UART banner and reset' not in captured:
        raise RuntimeError(f'Missing completion marker; see {stage}')
    print(captured)


if __name__ == '__main__':
    main()
