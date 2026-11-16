# MKROM.PY - firmware 2.4 for the K235 / K235+ 16-bit modules of the
#            NCR Decision Mate V
#
#   python MKROM.PY dmv_int_8088_pic_33473.bin k235_fw24.bin
#
# Input: the original K235 ROM 33473 (4 KB, CRC32 104195dc, as in MAME).
# Needs nasm in the PATH.  K235FW.ASM takes the parts it keeps from 33473
# (entries, 8259 test, keyboard and CRT drivers) with incbin from a copy
# named 33473.bin next to it; all other code is new.  The last byte is set
# so that the sum of all 4096 bytes is 0 (ROM test of the firmware).
import os, shutil, subprocess, sys, tempfile, zlib

src, dst = sys.argv[1], sys.argv[2]
d = open(src, 'rb').read()
assert len(d) == 4096 and zlib.crc32(d) == 0x104195DC, "not ROM 33473"

here = os.path.dirname(os.path.abspath(__file__))
with tempfile.TemporaryDirectory() as tmp:
    shutil.copy(src, os.path.join(tmp, '33473.bin'))
    shutil.copy(os.path.join(here, 'K235FW.ASM'), os.path.join(tmp, 'K235FW.ASM'))
    subprocess.run(['nasm', '-f', 'bin', '-o', 'fw.bin', 'K235FW.ASM'], cwd=tmp, check=True)
    rom = bytearray(open(os.path.join(tmp, 'fw.bin'), 'rb').read())

assert len(rom) == 4096
rom[0xFFF] = 0
rom[0xFFF] = (-sum(rom)) & 0xFF
open(dst, 'wb').write(rom)
print('%s: CRC32 %08x' % (dst, zlib.crc32(rom)))
