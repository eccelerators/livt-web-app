#!/usr/bin/env python3
"""Elaborate the copied WebApp IP; packaging alone does not validate its HDL."""
import os
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parent.parent
sources = sorted((root / 'package').rglob('*.vhd'))
if not sources:
    raise RuntimeError('No packaged VHDL; run scripts/package-ip.py first')
ghdl = os.environ.get('LIVT_GHDL_PATH', 'ghdl')
log_path = root / '.livt/vendor/packaged-hdl.log'
log_path.parent.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(prefix='webapp-packaged-hdl-') as scratch:
    with log_path.open('w') as log:
        for command in ([ghdl, '-i', '--std=08', *map(str, sources)],
                        [ghdl, '-m', '--std=08', 'webapp_wrapper']):
            result = subprocess.run(command, cwd=scratch, stdout=log, stderr=subprocess.STDOUT)
            if result.returncode:
                raise RuntimeError(f'Packaged HDL failed elaboration; see {log_path}')
print('PASS: packaged WebApp HDL elaboration')
