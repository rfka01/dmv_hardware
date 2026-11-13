# MKSTART.PY - step 2 of EXTKB: power-on key and no ROM checksum for the
#              DMV keyboard controller (8741, mainboard ROM 32678)
#
#   python MKSTART.PY dmv_mb_8741_32678_synth.bin dmv_mb_8741_32678_extkb.bin
#
# Input: the synthesizer firmware (CRC32 bcb29bec, output of MKSYNTH.PY),
# which already contains Keyclick v4 and the race (Rennwerk).
# Output: EXTKB (CRC32 5c243b8c). MKEXTKB.PY runs both steps.
#
# 1. ROM checksum test removed
#    After the RAM test the original runs a sum over all 1024 bytes
#    (0DCh-0E8h, 100h-109h, 22Dh-245h) and reports C0h if it is not 0.
#    02Ch now jumps to a plain delay of the same length (about 23 ms,
#    100h) and then to the "test passed" path (2DAh: status C0h, then
#    032h). The delay matters: the keyboard needs about 30 ms after
#    power-on before it answers; without it the 8741 polls too early,
#    times out and reports 00h ("no keyboard") to the Z80. The freed
#    space holds the code below. The checksum byte 3FFh is still set, so
#    the sum stays 0 for anyone checking.
#
# 2. Key held at power-on: tick instead of beep
#    The original plays the power-on beep (about 600 ms) as soon as the
#    keyboard's first byte (its ID, bit 3 set) arrives (04Dh-056h).
#    Now the ID goes to the host as before, then the 8741 waits about
#    100 ms (12 scan timeouts of 8 ms):
#      - no key code in that time: the usual beep (056h)
#      - a key code (a key held since power-on; the keyboard sends it
#        about 10 ms after its ID): the LOW tick (10Ah) instead, and the
#        code is dropped; so are all further codes (typematic) until the
#        keyboard has been quiet for about 0.8 s (96 timeouts).
#    State in RAM 20h (cleared by the self test, used by nobody else):
#      0 = before the ID, 1 = waiting for a held key, 2 = key seen.
#    R7 (3Fh before the ID, as in the original) is the timeout counter.
import sys, zlib

src, dst = sys.argv[1], sys.argv[2]
d = bytearray(open(src, 'rb').read())
assert len(d) == 1024 and zlib.crc32(d) == 0xBCB29BEC, "not the synthesizer firmware bcb29bec"

STATE = 0x20                # RAM: start state
WIN0 = 0x0C                 # timeouts to wait for a held key (about 100 ms)
WINQ = 0x60                 # quiet timeouts that end the dropping (about 0.8 s)
TICK = 0x0A                 # 10Ah: LOW tick of Keyclick (ends with JMP 0A6h)

def asm(org, prog):
    """Two-pass mini assembler: labels (str) and tuples of bytes;
    ('j', label) = target of JZ/JNZ/DJNZ (same 256-byte page)."""
    lab = {}; pc = org
    for it in prog:
        if isinstance(it, str): lab[it] = pc
        else: pc += len(it)
    out = []; pc = org
    for it in prog:
        if isinstance(it, str): continue
        for b in it:
            if isinstance(b, tuple):
                t = lab[b[1]]
                assert (t & 0xF00) == ((pc + 1) & 0xF00), b
                out.append(t & 0xFF)
            else:
                out.append(b)
            pc += 1
    return bytes(out), lab

def put(org, code, end):
    """put code at org, fill the rest of the freed area up to end with 00"""
    assert org + len(code) <= end + 1, hex(org)
    d[org:end + 1] = code + bytes(end + 1 - org - len(code))

# Byte from the keyboard while R7 <> 0 (ROM 08Dh: MOV A,R7 / JNZ ...)
K, _ = asm(0x0DC, [
          (0xB8, STATE),             # MOV  R0,#20h
          (0xF0,),                   # MOV  A,@R0
          (0x96, 0xCF),              # JNZ  0CFh (W)     key during the wait
          (0xB0, 0x01),              # MOV  @R0,#1       ID: start waiting
          (0xFF,),                   # MOV  A,R7         A = 3Fh as the ROM expects
          (0x04, 0x4D),              # JMP  04Dh         store country code, ID to host
])
W, _ = asm(0x0CF, [
          (0x07,),                   # DEC  A            state 1 -> 0, state 2 -> 1
          (0xBF, WINQ),              # MOV  R7,#60h      (re)start the quiet time
          (0x96, 0xA6),              # JNZ  0A6h         key already seen: drop
          (0xB0, 0x02),              # MOV  @R0,#2       first key: seen
          (0x24, TICK),              # JMP  10Ah         tick, then 0A6h (code dropped)
])
DLY, _ = asm(0x100, [
          (0xBA, 0x12),              # MOV  R2,#18       18 x 1.3 ms, as long as
 'dl',    (0xB9, 0x00),              # MOV  R1,#0        the checksum loops were
          (0x14, 0xE9),              # CALL 0E9h         (DJNZ R1,$: 256 x 5 us)
          (0xEA, ('j', 'dl')),       # DJNZ R2,dl
          (0x44, 0xDA),              # JMP  2DAh         test passed
])
S2, _ = asm(0x23E, [
          (0xFB,),                   # MOV  A,R3         (ROM 054h/055h)
          (0x02,),                   # OUT  DBB,A        ID to the host
          (0xBF, WIN0),              # MOV  R7,#0Ch      wait instead of the beep
          (0x04, 0xA6),              # JMP  0A6h
])
T, _ = asm(0x22D, [
          (0xB8, STATE),             # MOV  R0,#20h      scan timeout with R7 <> 0
          (0xF0,),                   # MOV  A,@R0
          (0x96, ('j', 'u')),        # JNZ  u
          (0x02,),                   # OUT  DBB,A        no keyboard: 00h and the beep,
          (0x04, 0x56),              # JMP  056h         as in the ROM (0B3h)
 'u',     (0xEF, ('j', 'x')),        # DJNZ R7,x         still waiting
          (0x07,),                   # DEC  A
          (0x96, ('j', 'x')),        # JNZ  x            key was seen: just carry on
          (0x04, 0x56),              # JMP  056h         nothing held: the usual beep
 'x',     (0x04, 0xB7),              # JMP  0B7h         ROM timeout path
])

put(0x0DC, K, 0x0E8)                 # freed checksum code, page 0
put(0x0CF, W, 0x0D7)                 # old click code, dead since 0CDh
put(0x100, DLY, 0x109)               # freed checksum code, page 1
put(0x22D, T + S2, 0x245)            # freed checksum code, page 2

d[0x02C:0x02E] = bytes([0x24, 0x00])  # JMP 100h: RAM test passed -> delay, no checksum
d[0x08E:0x090] = bytes([0x96, 0xDC])  # JNZ 0DCh (K)
d[0x054:0x056] = bytes([0x44, 0x3E])  # JMP 23Eh (S2) instead of OUT DBB + beep
d[0x0B3:0x0B5] = bytes([0x44, 0x2D])  # JMP 22Dh (T)

d[0x3FF] = (d[0x3FF] - sum(d)) & 0xFF
assert sum(d) & 0xFF == 0
open(dst, 'wb').write(d)
assert zlib.crc32(d) == 0x5C243B8C, "EXTKB differs"
print(f"{dst}: CRC32 {zlib.crc32(d):08x}")
