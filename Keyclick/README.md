# Keyclick

*English below.*

## Deutsch

Die NCR Decision Mate V hat einen ziemlich nervigen Tastaturton, der mit dem originalen Tastaturcontroller auf dem Motherboard nicht abgeschaltet werden kann. Die neue Firmware [EXTKB](../EXTKB) kann den Ton abschalten und auf niedrige Intensität setzen. Dazu gibt es dieses Utility, das die Parameter `ON`, `OFF` und `LOW` kennt. Auf DOS, CP/M-80 und CP/M-86 ist es getestet.

### Dateien

| | |
|---|---|
| `Images/KEYCLICK.IMG` | 360-KB-DOS-Diskette: `KEYCLICK.COM`, Beschreibung `KEYCLICK.TXT`, Quelle, `BUILD.BAT` |
| `Images/KEYCLICK_CPM.IMG` | 320-KB-CP/M-Diskette: `KEYCLICK.COM` (CP/M-80), `KEYCLICK.CMD` (CP/M-86), `KEYCLICK.68K` (CP/M-68K), `KEYCLICK.DOC`, Quellen |
| `Sourcen/DOS/` | MS-DOS-Version (MASM 5.10) |
| `Sourcen/CPM/` | CP/M-80 (8080, `ASM`/`LOAD`), CP/M-86 (MASM-Syntax + `MKCMD.PY`), CP/M-68K (GNU as + `MK68K.PY`) |

### Aufruf

```
KEYCLICK        zeigt die Einstellung
KEYCLICK ON     Tastaturklick an
KEYCLICK OFF    Tastaturklick aus
KEYCLICK LOW    nur ein leiser Knack
```

Unter DOS liefert KEYCLICK einen ERRORLEVEL: 0 erledigt, 1 falscher Parameter, 2 Originalfirmware, 3 keine Antwort, 4 erste Patch-Version ohne LOW. Nach jedem Reset ist der Klick wieder an; wer ihn nie hören will, schreibt `KEYCLICK OFF` in die AUTOEXEC.BAT. Bell und Musik (`ESC M`) bleiben unverändert.

### Wie es funktioniert

Den Klick erzeugt nicht die Tastatur, sondern der Lautsprecher auf dem Motherboard, den der 8741 über P2.0 ansteuert. Die Originalfirmware spielt jedes Mal, wenn sie einen Tastencode an den Rechner weitergibt, einen Ton von etwa 870 Hz und 20 ms – ohne Möglichkeit, ihn abzuschalten. EXTKB nutzt freie Bereiche des ROMs und die freien Befehle des Controllers:

- `02h` Klick aus, `03h` Klick an, `04h` LOW: statt des Tons ein einzelner Impuls von 0,5 ms
- Statusregister (Port 41h): Bit 6 = neue Firmware vorhanden, Bit 5 = aus, Bit 4 = LOW
- Die Einstellung liegt im RAM des 8741; der Selbsttest beim Einschalten setzt sie zurück.

Die Originalfirmware bleibt bei den Befehlen `02h` bis `05h` in ihrem Befehlsverteiler hängen und fragt die Tastatur nicht mehr ab. KEYCLICK prüft deshalb zuerst Bit 6 und schickt ohne neue Firmware nichts.

### Firmware

KEYCLICK braucht die Firmware [EXTKB](../EXTKB) (Einbau in MAME und auf der echten DMV ist dort beschrieben). Sie enthält die Klicksteuerung zusammen mit Synthesizer, Rennwerk und dem Knack statt Piep beim Einschalten. Die frühere Firmware Keyclick v4 (CRC32 `82709883`) funktioniert mit KEYCLICK ebenso, ist aber durch EXTKB ersetzt und liegt nur noch in der Git-Historie.

### Test

DOS, CP/M-80 und CP/M-86 sind in MAME getestet. KEYCLICK.68K für CP/M-68K ist gebaut und nur in einer Emulation von 68000 und 8741 geprüft, weil CP/M-68K auf der DMV derzeit nicht zuverlässig läuft.

## English

The NCR Decision Mate V has a rather annoying key click that cannot be switched off with the original keyboard controller on the motherboard. The new firmware [EXTKB](../EXTKB) can switch the click off or set it to low intensity. This utility knows the parameters `ON`, `OFF` and `LOW`. It has been tested under DOS, CP/M-80 and CP/M-86.

### Files

| | |
|---|---|
| `Images/KEYCLICK.IMG` | 360 KB DOS disk: `KEYCLICK.COM`, description `KEYCLICK.TXT` (German), source, `BUILD.BAT` |
| `Images/KEYCLICK_CPM.IMG` | 320 KB CP/M disk: `KEYCLICK.COM` (CP/M-80), `KEYCLICK.CMD` (CP/M-86), `KEYCLICK.68K` (CP/M-68K), `KEYCLICK.DOC` (German/English), sources |
| `Sourcen/DOS/` | MS-DOS version (MASM 5.10) |
| `Sourcen/CPM/` | CP/M-80 (8080, `ASM`/`LOAD`), CP/M-86 (MASM syntax + `MKCMD.PY`), CP/M-68K (GNU as + `MK68K.PY`) |

### Usage

```
KEYCLICK        show the current setting
KEYCLICK ON     key click on
KEYCLICK OFF    key click off
KEYCLICK LOW    just a faint tick
```

Under DOS KEYCLICK returns an ERRORLEVEL: 0 done, 1 wrong parameter, 2 original firmware, 3 no answer, 4 first patch version without LOW. The click is on again after every reset; put `KEYCLICK OFF` into AUTOEXEC.BAT to never hear it. Bell and music (`ESC M`) are not affected.

### How it works

The click is not made by the keyboard but by the speaker on the motherboard, which the 8741 drives through P2.0. The original firmware plays a tone of about 870 Hz for 20 ms whenever it passes a key code to the computer, with no way to turn it off. EXTKB uses unused areas of the ROM and the free commands of the controller:

- `02h` click off, `03h` click on, `04h` LOW: a single 0.5 ms pulse instead of the tone
- status register (port 41h): bit 6 = new firmware present, bit 5 = off, bit 4 = LOW
- The setting lives in the 8741 RAM; the self test at power-on resets it.

With commands `02h` to `05h` the original firmware hangs in its command dispatcher and stops scanning the keyboard. KEYCLICK therefore checks bit 6 first and sends nothing without the new firmware.

### Firmware

KEYCLICK needs the firmware [EXTKB](../EXTKB) (installation in MAME and on a real DMV is described there). It contains the click control together with the synthesizer, the race and the tick instead of the beep at power-on. The earlier Keyclick v4 firmware (CRC32 `82709883`) works with KEYCLICK as well, but is replaced by EXTKB and kept only in the git history.

### Tests

DOS, CP/M-80 and CP/M-86 have been tested in MAME. KEYCLICK.68K for CP/M-68K is built and only checked in an emulation of the 68000 and the 8741, because CP/M-68K does not run reliably on the DMV at the moment.

---

MIT License, see [LICENSE](../LICENSE). Code: Claude (Anthropic) · Prompts: rfka01
