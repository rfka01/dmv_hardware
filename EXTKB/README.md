# EXTKB – erweiterte Firmware für den Tastaturcontroller

*English below.*

## Deutsch

EXTKB ersetzt die Firmware des Tastaturcontrollers **auf dem Motherboard** der NCR Decision Mate V (8741, ROM 32678). Dieser Controller fragt die Tastatur ab und steuert den Lautsprecher. Der eigene 8741 in der Tastatur bleibt unverändert. EXTKB behält alles, was das Original kann, und fügt hinzu:

- **Klick einstellbar:** Den Tastaturton kann man abschalten oder auf einen leisen Knack stellen (`ON`, `OFF`, `LOW`). Das Utility dazu liegt in [`../Keyclick`](../Keyclick).
- **Knack statt Piep beim Einschalten:** Wer beim Einschalten eine Taste gedrückt hält, hört statt des lauten Pieps vor dem Speichertest nur den leisen Knack. Ohne gedrückte Taste piept die DMV wie gewohnt.
- **Synthesizer:** Der 8741 erzeugt drei Rechteckstimmen und einen Rauschgenerator, frei in der Frequenz. Der Rechner stellt nur die Register. Demo und Programmierschnittstelle in [SYNDEMO](https://github.com/rfka01/dmv_soft/tree/main/SYNDEMO), MOD-Player und Tracker in [DMVTRAK](https://github.com/rfka01/dmv_soft/tree/main/DMVTRAK).
- **Rennwerk:** ein eingebauter Divisionstest des 8741 für Geschwindigkeitsvergleiche.
- **Keine ROM-Prüfsumme mehr im Selbsttest:** Sie hätte den Platz für den Startknack gekostet. Das Prüfsummenbyte ist weiter gesetzt, die Summe aller Bytes bleibt 0.

EXTKB fasst die früheren Firmwares Keyclick v4 und Synthesizer zusammen und ersetzt sie. `KEYCLICK`, `SYNDEMO` und `DMVTRAK` laufen unverändert.

### Dateien

| | |
|---|---|
| `dmv_mb_8741_32678_extkb.bin` | die Firmware, 1 KB, CRC32 `5c243b8c`, SHA1 `3bd0e39ce42f3e9df0e075c20159e76aa6cb62b1` |
| `Sourcen/MKEXTKB.PY` | baut die Firmware aus dem Original-ROM 32678 (ruft `MKSYNTH.PY` und `MKSTART.PY` auf) |
| `Sourcen/SYNTH.A48` | Quelltext von Synthesizer, Rennwerk und Klicksteuerung (Assembler `asm48.py`) |
| `Sourcen/upi41.py` | Disassembler und Simulator des 8741 |
| `Sourcen/EXTKB.LST` | alle 550 gegenüber dem Original geänderten Bytes, disassembliert |
| `Sourcen/KEYCLICK.LST`, `SYNTH.LST`, `START.LST` | die Änderungen Schritt für Schritt: Keyclick v4, Synthesizer und Rennwerk, Startknack ohne Prüfsumme |

Bauen (Python 3):

```
python MKEXTKB.PY dmv_mb_8741_32678.bin dmv_mb_8741_32678_extkb.bin
```

Das Skript prüft die CRC32 des Original-ROMs (`50d1dc4c`), der Zwischenstufen und des Ergebnisses. Mit `--list` schreibt es `EXTKB.LST` neu.

### Schnittstelle

Ports 40h (Daten) und 41h (Befehl/Status). Vor jedem Byte warten, bis Status Bit 1 (IBF) = 0 ist.

| Befehl an 41h | Wirkung |
|---|---|
| `00h` | Selbsttest (schickt das Boot-ROM bei jedem Reset; setzt den Klick wieder auf an) |
| `01h` | Ländercode der Tastatur |
| `02h` | Klick aus |
| `03h` | Klick an |
| `04h` | Klick LOW (ein einzelner Impuls von 0,5 ms) |
| `05h` | Synthesizer ein; jeder weitere Befehl beendet ihn |
| `06h`, `07h` | Musik (`ESC M`) und Glocke wie im Original |

Status (IN 41h), obere vier Bits, solange der Synthesizer nicht läuft:

| Status | Bedeutung |
|---|---|
| `C0h` / `E0h` / `D0h` | EXTKB oder Synthesizer-Firmware: Klick an / aus / LOW |
| `40h` / `60h` / `50h` | Keyclick v4 (kein Synthesizer) |
| `00h` | Original-Firmware |

Bit 7 = Synthesizer, Bit 6 = Klicksteuerung, Bit 5 = aus, Bit 4 = LOW. Läuft der Synthesizer, ist Bit 2 (F0) gesetzt und die Bits 7..4 zeigen den Timer des 8741.

**Wichtig:** Die Original-Firmware bleibt bei den Befehlen `02h` bis `05h` in ihrem Befehlsverteiler hängen und fragt die Tastatur nicht mehr ab. Programme prüfen deshalb zuerst Bit 6 (Klick) bzw. Bit 7 (Synthesizer).

Register des Synthesizers, Uhr und Rennwerk sind in [`SYNTH.TXT`](https://github.com/rfka01/dmv_soft/blob/main/SYNDEMO/Sourcen/DOS/SYNTH.TXT) beschrieben.

### Taste beim Einschalten

Die Kennung der Tastatur geht wie bisher an den Z80. Danach wartet der 8741 etwa 100 ms. Kommt in dieser Zeit ein Tastencode (eine seit dem Einschalten gehaltene Taste), spielt er den LOW-Knack statt des Pieps und verwirft den Code und alle Wiederholungen, bis die Tastatur 0,8 s still war. Sonst piept er wie gewohnt.

In MAME zählt auch die Taste, mit der man den Infobildschirm beim Start wegdrückt: Wer sie nur antippt oder mit Shift-F3 neu startet, hört den Piep.

### Einbau

- **MAME:** Im Fork [rfka01/mame](https://github.com/rfka01/mame) lädt `dmv.cpp` EXTKB als BIOS `c71` („C.07.01“). Lokal in einem anderen Stand:
  `ROMX_LOAD( "dmv_mb_8741_32678_extkb.bin", 0x00000, 0x00400, CRC(5c243b8c) SHA1(3bd0e39ce42f3e9df0e075c20159e76aa6cb62b1), ROM_BIOS(n) )`
- **Echte DMV:** Der Tastaturcontroller ist ein 8741(A) mit EPROM. Er muss mit der neuen Firmware programmiert werden; das können nicht alle Programmiergeräte.

Die Firmware gilt für ROM 32678. Ältere Motherboards mit ROM 32121 brauchen eine eigene Anpassung.

### Test

In einer zyklengenauen Simulation beider 8741 (Motherboard und Tastatur) geprüft: Start mit und ohne gehaltene Taste, alle Klickeinstellungen, Synthesizer und Rennwerk wie in der Synthesizer-Firmware. In MAME getestet, auf echter Hardware noch nicht.

## English

EXTKB replaces the firmware of the keyboard controller **on the motherboard** of the NCR Decision Mate V (8741, ROM 32678). This controller scans the keyboard and drives the speaker. The keyboard's own 8741 is not changed. EXTKB keeps everything the original does and adds:

- **Adjustable click:** the key click can be switched off or set to a faint tick (`ON`, `OFF`, `LOW`). The utility for it is in [`../Keyclick`](../Keyclick).
- **Tick instead of beep at power-on:** hold a key while switching on and you hear only the faint tick instead of the loud beep before the memory test. Without a key held the DMV beeps as usual.
- **Synthesizer:** the 8741 generates three square-wave voices and a noise generator, free in frequency; the computer only sets registers. Demo and programming interface in [SYNDEMO](https://github.com/rfka01/dmv_soft/tree/main/SYNDEMO), MOD player and tracker in [DMVTRAK](https://github.com/rfka01/dmv_soft/tree/main/DMVTRAK).
- **Race (Rennwerk):** a built-in division benchmark of the 8741 for speed comparisons.
- **No ROM checksum in the self test any more:** it would have cost the space for the power-on tick. The checksum byte is still set; the sum of all bytes stays 0.

EXTKB combines and replaces the earlier Keyclick v4 and synthesizer firmwares. `KEYCLICK`, `SYNDEMO` and `DMVTRAK` work unchanged.

### Files

| | |
|---|---|
| `dmv_mb_8741_32678_extkb.bin` | the firmware, 1 KB, CRC32 `5c243b8c`, SHA1 `3bd0e39ce42f3e9df0e075c20159e76aa6cb62b1` |
| `Sourcen/MKEXTKB.PY` | builds the firmware from the original ROM 32678 (calls `MKSYNTH.PY` and `MKSTART.PY`) |
| `Sourcen/SYNTH.A48` | source of synthesizer, race and click control (assembler `asm48.py`) |
| `Sourcen/upi41.py` | 8741 disassembler and simulator |
| `Sourcen/EXTKB.LST` | all 550 bytes changed against the original, disassembled |
| `Sourcen/KEYCLICK.LST`, `SYNTH.LST`, `START.LST` | the changes step by step: Keyclick v4, synthesizer and race, power-on tick without checksum (partly German) |

Building (Python 3):

```
python MKEXTKB.PY dmv_mb_8741_32678.bin dmv_mb_8741_32678_extkb.bin
```

The script checks the CRC32 of the original ROM (`50d1dc4c`), of the intermediate steps and of the result. With `--list` it writes `EXTKB.LST` again.

### Interface

Ports 40h (data) and 41h (command/status). Before each byte wait until status bit 1 (IBF) = 0.

| Command to 41h | Effect |
|---|---|
| `00h` | self test (sent by the boot ROM on every reset; switches the click back on) |
| `01h` | keyboard country code |
| `02h` | click off |
| `03h` | click on |
| `04h` | click LOW (a single 0.5 ms pulse) |
| `05h` | synthesizer on; any further command ends it |
| `06h`, `07h` | music (`ESC M`) and bell as in the original |

Status (IN 41h), upper four bits, while the synthesizer is not running:

| Status | Meaning |
|---|---|
| `C0h` / `E0h` / `D0h` | EXTKB or synthesizer firmware: click on / off / LOW |
| `40h` / `60h` / `50h` | Keyclick v4 (no synthesizer) |
| `00h` | original firmware |

Bit 7 = synthesizer, bit 6 = click control, bit 5 = off, bit 4 = LOW. While the synthesizer runs, bit 2 (F0) is set and bits 7..4 show the 8741 timer.

**Important:** with commands `02h` to `05h` the original firmware hangs in its command dispatcher and stops scanning the keyboard. Programs therefore check bit 6 (click) or bit 7 (synthesizer) first.

Synthesizer registers, clock and race are described in [`SYNTH.TXT`](https://github.com/rfka01/dmv_soft/blob/main/SYNDEMO/Sourcen/DOS/SYNTH.TXT) (German).

### Key held at power-on

The keyboard ID goes to the Z80 as before. Then the 8741 waits about 100 ms. If a key code arrives in that time (a key held since power-on), it plays the LOW tick instead of the beep and drops the code and all repeats until the keyboard has been quiet for 0.8 s. Otherwise it beeps as usual.

In MAME the key used to dismiss the info screen at start counts as well: tap it briefly, or restart with Shift-F3, to hear the beep.

### Installation

- **MAME:** in the fork [rfka01/mame](https://github.com/rfka01/mame) `dmv.cpp` loads EXTKB as BIOS `c71` ("C.07.01"). For another source tree, locally:
  `ROMX_LOAD( "dmv_mb_8741_32678_extkb.bin", 0x00000, 0x00400, CRC(5c243b8c) SHA1(3bd0e39ce42f3e9df0e075c20159e76aa6cb62b1), ROM_BIOS(n) )`
- **Real DMV:** the keyboard controller is an 8741(A) with EPROM. It has to be programmed with the new firmware; not every programmer supports it.

The firmware is for ROM 32678. Older motherboards with ROM 32121 need their own adaptation.

### Tests

Checked in a cycle-accurate simulation of both 8741s (motherboard and keyboard): power-on with and without a held key, all click settings, synthesizer and race as in the synthesizer firmware. Tested in MAME, not yet on real hardware.

---

MIT License, see [LICENSE](../LICENSE) (NCR's original code in the firmware is not covered). Code: Claude (Anthropic) · Prompts: rfka01
