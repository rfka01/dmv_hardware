# MKEXTKB.PY - builds EXTKB, the extended firmware for the keyboard
#              controller on the mainboard of the NCR Decision Mate V
#              (8741, replaces ROM 32678)
#
#   python MKEXTKB.PY dmv_mb_8741_32678.bin [dmv_mb_8741_32678_extkb.bin]
#
# Input: the original ROM 32678 (1 KB, CRC32 50d1dc4c, as in MAME).
# Output: EXTKB (CRC32 5c243b8c).
#
#   step 1  MKSYNTH.PY  original -> Keyclick v4 (82709883, KEYCLICK.LST)
#                       -> synthesizer + race (bcb29bec, SYNTH.LST)
#   step 2  MKSTART.PY  -> no ROM checksum, tick instead of the power-on
#                       beep while a key is held (5c243b8c, START.LST)
#
# EXTKB.LST lists all bytes that differ from the original, disassembled
# (python MKEXTKB.PY ... --list writes it again).
import sys, os, runpy, tempfile, zlib

here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
args = [a for a in sys.argv[1:] if a != '--list']
src = args[0]
dst = args[1] if len(args) > 1 else 'dmv_mb_8741_32678_extkb.bin'

def run(script, *argv):
    saved = sys.argv
    sys.argv = [script, *argv]
    try:
        runpy.run_path(os.path.join(here, script), run_name='__main__')
    finally:
        sys.argv = saved

with tempfile.TemporaryDirectory() as tmp:
    synth = os.path.join(tmp, 'dmv_mb_8741_32678_synth.bin')
    run('MKSYNTH.PY', src, synth)
    run('MKSTART.PY', synth, dst)

if '--list' in sys.argv:
    from upi41 import dis
    org = open(src, 'rb').read()
    new = open(dst, 'rb').read()
    diff = [a for a in range(1024) if org[a] != new[a]]
    # group changed bytes into ranges (gaps of up to 3 equal bytes are joined)
    ranges = []
    for a in diff:
        if ranges and a - ranges[-1][1] <= 4: ranges[-1][1] = a
        else: ranges.append([a, a])
    # a range that starts with the operand of an unchanged two-byte
    # instruction (JNZ 08Eh) is shown from that instruction
    for r in ranges:
        if r[0] == 0x08F: r[0] = 0x08E
    DATA = {0x206: (4, 'DB  command table 02h..05h'),
            0x3FD: (2, 'DB  unused'),
            0x3FF: (1, 'DB  checksum (sum of all bytes = 0)')}
    out = ['; EXTKB - all bytes that differ from the original ROM 32678,',
           '; disassembled (output of MKEXTKB.PY --list). Data tables are',
           '; shown as code as well; see SYNTH.A48 and the step lists',
           '; KEYCLICK.LST, SYNTH.LST and START.LST for the meaning.',
           f'; {len(diff)} bytes changed, CRC32 {zlib.crc32(new):08x}', '']
    for lo, hi in ranges:
        if hi - lo < 16:
            out.append(f'; --- {lo:03X}h-{hi:03X}h   original: ' + ' '.join(f'{b:02X}' for b in org[lo:hi + 1]))
        else:
            out.append(f'; --- {lo:03X}h-{hi:03X}h')
        pc = lo
        while pc <= hi:
            if pc in DATA:
                n, t = DATA[pc]
                out.append(f'{pc:03X}: ' + ' '.join(f'{b:02X}' for b in new[pc:pc + n]).ljust(12) + t)
                pc += n
                continue
            t, n = dis(new, pc)
            if pc + n - 1 > hi and pc != hi: n = 1; t = f'DB {new[pc]:02X}h'
            out.append(f'{pc:03X}: ' + ' '.join(f'{b:02X}' for b in new[pc:pc + n]).ljust(12) + t)
            pc += n
        out.append('')
    open(os.path.join(here, 'EXTKB.LST'), 'w', newline='\r\n').write('\n'.join(out))
    print(f"EXTKB.LST: {len(diff)} bytes in {len(ranges)} ranges")
