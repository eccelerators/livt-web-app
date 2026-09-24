#!/usr/bin/env python3
"""Build release Vivado IP and expose it to the sibling Arty board project."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import sys

root = Path(__file__).resolve().parent.parent
subprocess.run([os.environ.get('LIVT', 'livt'), 'vendor', 'vivado-ip', '-R'],
               cwd=root, check=True)
source = root / '.livt/vendor/package'
if not (source / 'component.xml').is_file():
    raise RuntimeError(f'Vivado did not produce {source / "component.xml"}')
destination = root / 'package'
if destination.exists():
    shutil.rmtree(destination)
shutil.copytree(source, destination)
with tempfile.TemporaryDirectory(prefix='webapp-ip-') as scratch:
    subprocess.run([os.environ.get('LIVT_VIVADO_PATH', 'vivado'), '-mode', 'batch',
                    '-source', str(root / 'scripts/finalize-ip.tcl'), '-nojournal',
                    '-log', str(root / '.livt/vendor/board-ip.log')],
                   cwd=scratch, check=True)
subprocess.run([sys.executable, str(root / 'verification/check-packaged-hdl.py')], check=True)
print(f'Arty IP repository ready: {destination}')
