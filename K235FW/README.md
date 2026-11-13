# K235FW – Firmware 2.0 für K235 und K235+

*English below.*

## Deutsch

Neue Firmware für die 16-Bit-Prozessormodule der NCR Decision Mate V mit
Interruptcontroller: die originale **K235** von NCR und die **K235+**. Sie
ist speziell für die beiden Neuentwicklungen entstanden, die im Forum des
[VzEkC e.V.](https://forum.classic-computing.de/forum/index.php?thread/35252-ncr-dmv-neue-erweiterungen/)
entwickelt wurden: die Speicherkarte **K0815** (1 MB SRAM) und das
16-Bit-Modul **K235+** (1 MB Adressraum, EPROM nur oben im Adressraum).

**Stand: in MAME getestet, ein Test auf echter Hardware steht noch aus.**

**Download:** [`k235_fw20.bin`](k235_fw20.bin) (4 KB, 2732, CRC32 `508eafee`)

### Was neu ist

- **Speichertest** in 4-KB-Blöcken mit drei Mustern (Adresse, 55AAh,
  AA55h), etwa doppelt so schnell wie das Original. Er hört beim ersten
  Block auf, der kein RAM ist oder nur die Bank 512 KB tiefer spiegelt.
  Damit stimmt er auf allen Ausbaustufen.
- **Anzeige** mittig in drei Zeilen: „NCR“, „Decision Mate V – RAM test“
  und ein Balken mit hochzählender KB-Angabe. Auf Farb- und Monokarte
  jeweils passend (Kennung im Hauptplatinen-ROM). Fehler zeigen Adresse,
  Soll- und Ist-Wert und die Bitmaske und warten auf CR oder etwa 10 s.
- **„M“ während des Tests** springt danach in den Monitor.
- **Monitor ohne Passwort**, Groß- und Kleinbuchstaben, mit Speichertest
  `Z`, Intel-HEX-Laden `L`, Einzelschritt und Haltepunkt.
- **Terminalbedienung**: Steckt eine K211 auf IFSEL 1A, laufen Test und
  Monitor zusätzlich seriell mit 9600 8N1.

| Ausbau | K235 | K235+ |
|---|---|---|
| nur Hauptplatine, 64 KB | 64 KB | 64 KB |
| K200, 128 KB | 128 KB | 128 KB |
| K202, 256 KB | 256 KB | 256 KB |
| K208, 512 KB | 512 KB | 512 KB |
| K0815, 1 MB | 512 KB | 1020 KB |

Die alte K235 blendet ihr EPROM in den oberen 512 KB ein, deshalb bleibt es
dort bei 512 KB. In `0:FE06` steht wie bisher die Zahl der Bänke über
Bank 0; eine angebrochene letzte Bank zählt mit (15 bei 1020 KB).
Betriebssysteme müssen auf der K235+ unterhalb von FF000h bleiben.

Unverändert aus dem NCR-ROM 33473 übernommen: die Einsprünge FF00:0000 und
FF00:0003, das Postfach-Protokoll zum Z80, der 8259-Test sowie die Treiber
für Bildschirm und Tastatur. FF00:0632 führt weiter in den Monitor.

### Monitor

Einstieg: „M“ während des Speichertests oder Ctrl-N am Ende des
Selbsttests. Prompt `*`, alle Zahlen hexadezimal, Adresse `a` =
`seg:off` oder nur `off`. Ctrl-C bricht ab, Ctrl-S hält die Ausgabe an.

| Befehl | Wirkung |
|---|---|
| `D [a [n]]` | Speicher zeigen (Hex und ASCII), `D` allein macht weiter |
| `E a b b …` | Bytes schreiben; `E a` allein: Byte für Byte ändern, `.` beendet |
| `F a n b` | Füllen |
| `M a n a2` | Kopieren |
| `C a n a2` | Vergleichen |
| `S a n b …` | Suchen (bis 16 Byte) |
| `I p` / `O p b` | Port lesen / schreiben |
| `R` / `R rr v` | Register zeigen / setzen |
| `G [a [bp]]` | Starten, wahlweise mit Haltepunkt |
| `T [n]` | Einzelschritte |
| `Z [s1 [s2]]` | RAM-Test der Segmente s1 bis s2 (zerstört den Inhalt) |
| `L` | Intel-HEX laden (über die K211) |
| `X` | Firmware, RAM, Postfach FE00–FE0F, K211, 8087 |
| `Q` | Selbsttest neu, danach bootet der Z80 |
| `?` | Kurzhilfe |

### Einbau

- **K235:** an Stelle des EPROMs 33473 (2732).
- **K235+:** EPROM 2732 in E2, J1 auf 2-3, J2 und J3 offen, S3 alle ON
  (4-KB-Fenster FF000h–FFFFFh).
- **MAME:** im Branch `homebrew-vzekc` von
  [rfka01/mame](https://github.com/rfka01/mame/tree/homebrew-vzekc) ist sie
  als BIOS-Option `fw20` enthalten, für die K235+ als Vorgabe:
  `dmv -slot7a k235p -slot3 k0815` bzw. `dmv -slot7a k235,bios=fw20`.
  Für die Terminalbedienung zusätzlich `-slot4 k211 -bitb socket.127.0.0.1:2323`
  und vorher ein Programm, das auf diesem Port lauscht (z. B. `ncat -l -C 127.0.0.1 2323`).

Für K230 und K231 (ROM 32167, ohne 8259) ist die Firmware nicht geeignet.

### Dateien

| | |
|---|---|
| `k235_fw20.bin` | die Firmware |
| `Sourcen/K235FW.ASM` | Quelle (nasm), nur der neue Code |
| `Sourcen/MKROM.PY` | baut die Firmware aus dem Original-ROM 33473: `python MKROM.PY dmv_int_8088_pic_33473.bin k235_fw20.bin` |

## English

New firmware for the 16-bit processor modules with interrupt controller of
the NCR Decision Mate V: the original NCR **K235** and the **K235+**. It was
written for the two new developments from the
[VzEkC e.V.](https://forum.classic-computing.de/forum/index.php?thread/35252-ncr-dmv-neue-erweiterungen/)
forum: the **K0815** memory card (1 MB SRAM) and the **K235+** 16-bit module
(1 MB address space, EPROM only at the top).

**Status: tested in MAME, a test on real hardware is still pending.**

**Download:** [`k235_fw20.bin`](k235_fw20.bin) (4 KB, 2732, CRC32 `508eafee`)

### What is new

- **Memory test** in 4 KB blocks with three patterns (address, 55AAh,
  AA55h), about twice as fast as the original. It stops at the first block
  that is no RAM or only mirrors the bank 512 KB below, so it is right for
  every configuration.
- **Display** centred in three lines: "NCR", "Decision Mate V – RAM test"
  and a bar with a KB counter, suited to the colour and the mono board (id
  in the mainboard ROM). Errors show address, written and read value and
  the bit mask, then wait for CR or about 10 s.
- **"M" during the test** enters the monitor afterwards.
- **Monitor without password**, upper and lower case, with RAM test `Z`,
  Intel HEX loader `L`, single step and breakpoint.
- **Terminal operation**: with a K211 on IFSEL 1A the test and the monitor
  also run on the serial port at 9600 8N1.

| Configuration | K235 | K235+ |
|---|---|---|
| mainboard only, 64 KB | 64 KB | 64 KB |
| K200, 128 KB | 128 KB | 128 KB |
| K202, 256 KB | 256 KB | 256 KB |
| K208, 512 KB | 512 KB | 512 KB |
| K0815, 1 MB | 512 KB | 1020 KB |

The old K235 maps its EPROM into the upper 512 KB, so it stays at 512 KB.
`0:FE06` holds the number of banks above bank 0 as before; a partial last
bank counts (15 for 1020 KB). Operating systems must stay below FF000h on
the K235+.

Kept unchanged from the NCR ROM 33473: the entries FF00:0000 and
FF00:0003, the mailbox protocol with the Z80, the 8259 test and the screen
and keyboard drivers. FF00:0632 still enters the monitor.

### Monitor

Entry: "M" during the memory test or Ctrl-N at the end of the self test.
Prompt `*`, all numbers hexadecimal, address `a` = `seg:off` or just
`off`. Ctrl-C aborts, Ctrl-S pauses the output.

| Command | Action |
|---|---|
| `D [a [n]]` | dump memory (hex and ASCII), `D` alone continues |
| `E a b b …` | write bytes; `E a` alone: edit byte by byte, `.` ends |
| `F a n b` | fill |
| `M a n a2` | move |
| `C a n a2` | compare |
| `S a n b …` | search (up to 16 bytes) |
| `I p` / `O p b` | read / write port |
| `R` / `R rr v` | show / set registers |
| `G [a [bp]]` | go, optionally with breakpoint |
| `T [n]` | single steps |
| `Z [s1 [s2]]` | RAM test of segments s1 to s2 (destroys the contents) |
| `L` | load Intel HEX (via the K211) |
| `X` | firmware, RAM, mailbox FE00–FE0F, K211, 8087 |
| `Q` | self test again, then the Z80 boots |
| `?` | short help |

### Installation

- **K235:** in place of EPROM 33473 (2732).
- **K235+:** EPROM 2732 in E2, J1 on 2-3, J2 and J3 open, S3 all ON (4 KB
  window FF000h–FFFFFh).
- **MAME:** included as BIOS option `fw20` in the `homebrew-vzekc` branch of
  [rfka01/mame](https://github.com/rfka01/mame/tree/homebrew-vzekc), default
  for the K235+: `dmv -slot7a k235p -slot3 k0815` or
  `dmv -slot7a k235,bios=fw20`. For terminal operation add
  `-slot4 k211 -bitb socket.127.0.0.1:2323` and start a program listening on
  that port first (e.g. `ncat -l -C 127.0.0.1 2323`).

Not suitable for the K230 and K231 (ROM 32167, no 8259).

### Files

| | |
|---|---|
| `k235_fw20.bin` | the firmware |
| `Sourcen/K235FW.ASM` | source (nasm), new code only |
| `Sourcen/MKROM.PY` | builds the firmware from the original ROM 33473: `python MKROM.PY dmv_int_8088_pic_33473.bin k235_fw20.bin` |
