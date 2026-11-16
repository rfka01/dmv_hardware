#!/usr/bin/env python3
"""mkchd.py - eine leere, unkomprimierte CHD-Festplatte (Fassung 5) bauen.

    python3 Pruefstand/mkchd.py <datei.chd> <zylinder> <koepfe> <sektoren>

Eine Pruefplatte fuer MAME, mit frei gewaehlter Geometrie:

    python3 Pruefstand/mkchd.py /tmp/pruef.chd 437 4 17
    ./dmv dmv -slot2a k012 -hard1 /tmp/pruef.chd ...

Gebraucht wird das von jedem System, das die Platte anfasst - MS-DOS
(DMVHDFMT, FDISK, HDIMPORT), CP/M-68K, der Bootmanager. chdman ist in
unserer Pruefumgebung nicht uebersetzt; unkomprimiert ist das Format
aber einfach genug, um es selbst zu schreiben: Kopf (124 Byte), eine
Tafel mit vier Byte je Hunk (Versatz in Hunks, big endian), die Daten,
dahinter der Metadatenblock GDDD mit der Geometrie.

Grenzen unseres INT 13h: hoechstens 1024 Zylinder (10 Bit in der
CHS-Zaehlweise) und hoechstens 8 Koepfe (drei Kopfbits im SDH-Register
des WD1001). 17 Sektoren je Spur sind bei 5 Mbit/s und 512 Byte das
Uebliche.

DER FALLSTRICK steht unten bei datenoff und hat uns am 8.11.2026 einen
halben Nachmittag gekostet: der Datenbereich muss auf einem Vielfachen
von hunkbytes beginnen, sonst zerstoert der erste Schreibzugriff auf
den Plattenanfang die Tafel - und die Platte wird ab etwa drei
Vierteln ihrer Groesse unbrauchbar, ohne dass irgendetwas Alarm
schlaegt. Siehe dmv_os/docs/DMV-Datentraeger.md.

Code: Claude (Anthropic), Idee und Prompts: rfka01. Lizenz: MIT
"""
import hashlib
import struct
import sys


def main():
    if len(sys.argv) != 5:
        raise SystemExit(__doc__)
    ziel, zyl, kpf, spt = (sys.argv[1], int(sys.argv[2]),
                           int(sys.argv[3]), int(sys.argv[4]))
    bps = 512
    sektoren = zyl * kpf * spt
    hunkbytes = bps * 8                 # acht Sektoren je Hunk
    hunks = (sektoren * bps + hunkbytes - 1) // hunkbytes
    logisch = sektoren * bps

    kopflen = 124
    mapoff = kopflen
    #  Der Datenbereich MUSS auf einem Vielfachen von hunkbytes
    #  beginnen: MAME rechnet den Versatz eines Hunks als
    #  Tafeleintrag * hunkbytes zurueck (chd.cpp, unkomprimierter Fall).
    #  Bleibt der Anfang krumm, zeigen die Eintraege nach unten
    #  abgerundet mitten in die Tafel hinein - und der erste Schreibzugriff
    #  auf den Anfang der Platte ueberschreibt die Tafeleintraege der
    #  hinteren Hunks. Die Platte wird dann ab etwa drei Vierteln ihrer
    #  Groesse unlesbar, ohne dass irgendetwas Alarm schlaegt.
    roh_off = mapoff + hunks * 4
    datenoff = -(-roh_off // hunkbytes) * hunkbytes
    metaoff = datenoff + hunks * hunkbytes

    tafel = bytearray()
    for i in range(hunks):
        eintrag = (datenoff + i * hunkbytes) // hunkbytes
        assert eintrag * hunkbytes == datenoff + i * hunkbytes
        tafel += struct.pack('>I', eintrag)
    tafel += b'\0' * (datenoff - roh_off)        # Auffuellen bis zum Raster

    meta = ('CYLS:%d,HEADS:%d,SECS:%d,BPS:%d' % (zyl, kpf, spt, bps))
    meta = meta.encode('ascii') + b'\0'
    metakopf = struct.pack('>4sIQ', b'GDDD',
                           (0x01 << 24) | len(meta), 0)

    #  Pruefsummen: rawsha1 ueber die Rohdaten (hier lauter Nullen),
    #  sha1 ueber rawsha1 und die Metadaten - so rechnet es
    #  chd_file::compute_overall_sha1.
    roh = hashlib.sha1(b'\0' * logisch).digest()
    g = hashlib.sha1()
    g.update(roh)
    m = hashlib.sha1()
    m.update(b'GDDD')
    m.update(meta)
    g.update(m.digest())
    gesamt = g.digest()

    kopf = struct.pack('>8sIIIIIIQQQII20s20s20s',
                       b'MComprHD', kopflen, 5, 0, 0, 0, 0,
                       logisch, mapoff, metaoff, hunkbytes, bps,
                       roh, gesamt, b'\0' * 20)
    assert len(kopf) == kopflen, len(kopf)

    with open(ziel, 'wb') as f:
        f.write(kopf)
        f.write(tafel)
        leer = b'\0' * hunkbytes
        for _ in range(hunks):
            f.write(leer)
        f.write(metakopf)
        f.write(meta)
    print('%s: %d Zylinder, %d Koepfe, %d Sektoren, %d Byte'
          % (ziel, zyl, kpf, spt, logisch))


if __name__ == '__main__':
    main()
