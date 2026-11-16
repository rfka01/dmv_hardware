"""chdio.py - Sektoren einer unkomprimierten CHD (Fassung 5) lesen und schreiben.

Gegenstueck zu scripts/mkchd.py im Repo dmv_os: das Skript baut eine leere
Platte, dieses hier sieht hinein und legt Dateien ab, ohne MAME zu starten.
chdman gibt es in unserer Pruefumgebung nicht; unkomprimiert ist das Format
einfach genug.

    from chdio import Chd
    c = Chd('DMV_HD_v221.chd')          # 'r+b' zum Schreiben
    mbr = c.read(0)                     # ein Sektor
    teil = c.read(17, 65399)            # eine ganze Partition
    c.write(17, geaendert)

Gelesen und geschrieben wird in LBA-Sektoren zu 512 Byte. Hunkweise, nicht
sektorweise - das ist rund tausendmal schneller als eine Schleife mit seek
je Sektor.

Code: Claude (Anthropic), Idee und Prompts: rfka01. Lizenz: MIT
"""
import struct


class Chd:
    def __init__(self, path, mode='rb'):
        self.f = open(path, mode)
        h = self.f.read(124)
        assert h[:8] == b'MComprHD', 'keine CHD'
        assert struct.unpack('>I', h[12:16])[0] == 5, 'nur Fassung 5'
        assert h[16:32] == b'\0' * 16, 'nur unkomprimiert'
        self.logbytes, self.mapoff, self.metaoff = struct.unpack('>QQQ', h[32:56])
        self.hunkbytes, self.unitbytes = struct.unpack('>II', h[56:64])
        self.nhunks = (self.logbytes + self.hunkbytes - 1) // self.hunkbytes
        self.f.seek(self.mapoff)
        self.map = list(struct.unpack('>%dI' % self.nhunks,
                                      self.f.read(4 * self.nhunks)))

    def off(self, lba):
        hunk = lba * self.unitbytes // self.hunkbytes
        return (self.map[hunk] * self.hunkbytes
                + (lba * self.unitbytes) % self.hunkbytes)

    def read(self, lba, n=1):
        out = []
        spr = self.hunkbytes // self.unitbytes
        i = 0
        while i < n:
            k = min(spr - ((lba + i) % spr), n - i)
            self.f.seek(self.off(lba + i))
            out.append(self.f.read(self.unitbytes * k))
            i += k
        return b''.join(out)

    def write(self, lba, data):
        assert len(data) % self.unitbytes == 0
        n = len(data) // self.unitbytes
        spr = self.hunkbytes // self.unitbytes
        i = 0
        while i < n:
            k = min(spr - ((lba + i) % spr), n - i)
            self.f.seek(self.off(lba + i))
            self.f.write(data[i * self.unitbytes:(i + k) * self.unitbytes])
            i += k
