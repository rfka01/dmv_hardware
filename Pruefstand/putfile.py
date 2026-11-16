#!/usr/bin/env python3
"""putfile.py - eine Datei in die erste Partition einer DMV-Platte legen.

    python3 putfile.py <platte.chd> <datei> [ZIELNAME]

Ohne MAME und ohne chdman: die Partitionstabelle im Hauptbootsatz sagt, wo
die Partition liegt, mtools legt die Datei hinein, und das Ergebnis geht
zurueck in die CHD. Praktisch, um eine neue Fassung eines Werkzeugs auf die
Pruefplatte zu bringen, ohne die Maschine dafuer hochzufahren.

Gebraucht wird mtools (mcopy). getfile geht genauso mit 'mcopy -i ... ::/NAME .'

Code: Claude (Anthropic), Idee und Prompts: rfka01. Lizenz: MIT
"""
import os
import struct
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from chdio import Chd                                        # noqa: E402

if len(sys.argv) < 3:
    raise SystemExit(__doc__)
chd, src = sys.argv[1], sys.argv[2]
ziel = sys.argv[3] if len(sys.argv) > 3 else os.path.basename(src).upper()

c = Chd(chd, 'r+b')
e = c.read(0)[0x1BE:0x1BE + 16]
if not e[4]:
    raise SystemExit('kein erster Partitionseintrag')
lba = struct.unpack('<I', e[8:12])[0]
n = struct.unpack('<I', e[12:16])[0]

tmp = '/tmp/chd_partition.img'
open(tmp, 'wb').write(c.read(lba, n))
subprocess.run(['mcopy', '-o', '-i', tmp, src, '::/' + ziel], check=True,
               env=dict(os.environ, MTOOLS_SKIP_CHECK='1'))
c.write(lba, open(tmp, 'rb').read())
c.f.flush()
print('%s -> %s (Partition ab LBA %d, %d Sektoren)' % (src, ziel, lba, n))
