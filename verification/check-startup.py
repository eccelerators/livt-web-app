#!/usr/bin/env python3
"""Verify packaged Arty startup using one physical clock observation.

Only temporary simulation copies change. This diagnostic is specific to the
100 MHz, single-clock WebApp IP; it must not flatten clock-domain crossings.
"""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--work-dir', type=Path, help='New directory to retain simulation sources and results')
args = parser.parse_args()
root = Path(__file__).resolve().parent.parent
sources = sorted((root / 'package').rglob('*.vhd'))
if not sources:
    raise RuntimeError('No packaged VHDL; run scripts/package-ip.py first')
ghdl = os.environ.get('LIVT_GHDL_PATH', 'ghdl')


def check(work):
    clock = work / 'startup_clock.vhd'
    clock.write_text("library ieee; use ieee.std_logic_1164.all; package startup_clock is signal clk : std_logic := '0'; end;\n")
    inputs = [clock]
    for original in sources:
        target = work / original.name
        # Keep context wiring, reset and all method/data logic intact. Observe
        # the same clock event rather than delta-delayed copies in each context.
        target.write_text(''.join(
            line.replace('this_lvt_context_in.clk', 'work.startup_clock.clk')
            if 'process(' in line or 'rising_edge(' in line else line
            for line in original.read_text().splitlines(keepends=True)
        ))
        inputs.append(target)
    bench = work / 'startup_tb.vhd'
    bench.write_text((root / 'verification/startup_tb.vhd').read_text().replace(
        'clk <= not clk after 5 ns;',
        'clk <= not clk after 5 ns; work.startup_clock.clk <= clk;'))
    inputs.append(bench)
    for command in ([ghdl, '-i', '--std=08', *map(str, inputs)],
                    [ghdl, '-m', '--std=08', 'startup_tb'],
                    [ghdl, '-r', '--std=08', 'startup_tb', '--assert-level=error', '--stop-time=110us']):
        subprocess.run(command, cwd=work, check=True, timeout=600)


if args.work_dir:
    work = args.work_dir.resolve()
    work.mkdir(parents=True, exist_ok=False)
    check(work)
else:
    with tempfile.TemporaryDirectory(prefix='webapp-startup-') as temporary:
        check(Path(temporary))
