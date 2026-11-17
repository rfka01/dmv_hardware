# Prüfstand – die DMV in MAME prüfen

*English below.*

## Deutsch

Was hier liegt, ist kein Emulator, sondern das Zubehör: die Aufrufe für die
üblichen Ausbaustufen, ein Prüfstand, der den Bildschirm als Text ausgibt und
nach einem Zeitplan tippt, und zwei Werkzeuge, die Dateien in eine
Festplattenabbildung legen, ohne die Maschine dafür zu starten.

Gedacht ist es für alle, die rings um die DMV arbeiten – Firmware, Betriebs­-
systeme, Anwendungen. Jeder Thread hat sich das bisher selbst zusammengesucht,
und jeder ist in dieselben Fallen getappt (weiter unten).

| Datei | Zweck |
|---|---|
| [`dmvtest.lua`](dmvtest.lua) | Bildschirm als Text, Tasten, Ablaufplan – MAME ohne Fenster bedienen |
| [`chdio.py`](chdio.py) | Sektoren einer unkomprimierten CHD lesen und schreiben |
| [`putfile.py`](putfile.py) | eine Datei in die DOS-Partition einer Platte legen, ohne MAME |
| [`mkchd.py`](mkchd.py) | eine leere, unkomprimierte CHD mit frei gewählter Geometrie bauen (`chdman` gibt es in der Prüfumgebung nicht) |
| [`mame_holen.sh`](mame_holen.sh) | ein lauffähiges MAME mit dem DMV-Treiber bereitstellen: aus dem Release-Anhang des Forks holen oder bauen |

Gebraucht wird MAME mit dem DMV-Treiber aus
[rfka01/mame](https://github.com/rfka01/mame) und für `putfile.py` das Paket
`mtools`.

**Welcher Zweig — vorher entscheiden, nicht hinterher:**

| Zweig | Was drin ist |
|---|---|
| `master` | der DMV-Treiber und alles historisch Belegte |
| `homebrew-vzekc` | `master` **plus** Erfundenes: **K0815** (1 MB SRAM), **K235+** mit der eigenen Firmware, K238 |

Wer mit der K0815 oder der K235+ prüft, braucht `homebrew-vzekc`. In `master`
gibt es beide Module nicht, und MAME sagt das nicht deutlich: `-slot2 k0815`
wird mit einer Zeile im Protokoll stillschweigend verworfen, die Maschine läuft
mit falscher Bestückung weiter, und man mißt am Ende etwas anderes als gedacht.
Mit `./dmv dmv -listslots | grep k0815` ist in einer Sekunde geklärt, ob der
richtige Bau vorliegt. Den früher hier genannten Zweig `homebrew` gibt es am
Fork nicht mehr.

### Die üblichen Aufrufe

```sh
# Diskette, Farbmaschine, K235 mit NCRs Firmware
./dmv dmv -slot1 k208 -slot7a k235,bios=33473 -flop1 DISKETTE.IMG

# 80 Spuren (720 KB / QD800) brauchen das andere Laufwerk
./dmv dmv -slot1 k208 -slot7a k235p -i8272:0 525qd -flop1 DISKETTE.IMD

# Festplatte: eingebauter Controller K012 (WD1010, IFSEL 4A, C0h-C7h)
./dmv dmv -slot1 k208 -slot2a k012 -slot7a k235p -hard1 PLATTE.chd

# freistehende Platten statt K012 (in MAME derselbe Baustein)
./dmv dmv -slot1 k208 -slot3 c3282 -slot7a k235p -hard1 PLATTE.chd

# Monochrom statt Farbe
./dmv dmv -bios m07 ...

# Vollausbau 1020 KB: K0815 in einen der Steckplaetze 2-6, K235+ dahinter
# (braucht den Zweig homebrew-vzekc und k235_fw24.bin, siehe unten)
./dmv dmv -slot2 k0815 -slot7a k235p -flop1 DISKETTE.IMG
```

- **Kein `-flop1` angeben, wenn von Platte gestartet werden soll** – sonst
  nimmt das Z80-ROM das Laufwerk A:.
- Weitere Einheiten: `-hard2`, `-hard3`, `-hard4`. Unser INT 13h spricht nur
  die ersten drei an; MAMEs vierte gibt es auf keiner DMV.
- Speicher: `-slot1 k200` (64 KB), `k202` (192 KB), `k208` (448 KB).
  Ohne Karte hat die Maschine nur die 64 KB der Hauptplatine, und MS-DOS 3.30
  bricht mit „braucht mindestens 128 KB“ ab.
  Die **K0815** (1 MB) gehört dagegen in die Steckplätze 2–6, **nicht** in
  Steckplatz 1 — dort nimmt MAME nur `k200`/`k202`/`k208`. Oberhalb von
  512 KB gilt die DMA-Grenze der Hauptplatine
  (`../docs/DMV-Module-und-Anschluesse.md`): wer dort Transfers prüft, prüft
  auch den Umweg über einen Zwischenpuffer, nicht nur den Treiber.
- 16-Bit-Module: `-slot7a k230` / `k235` / `k235p`, `-slot7 k231` / `k234`
  (68008) / `k238` / `k220` (Diagnose).
- Weiteres in den Steckplätzen 2–6: `k211`, `k801` (seriell), `k210`
  (Centronics), `k806` (Maus), `k803` (Uhr), `k233` (Shared RAM),
  `k0815` (1 MB SRAM).

### Eigene Firmware unterschieben

MAME prüft die Prüfsumme der ROM-Dateien, läuft aber trotzdem. Ein eigener
Suchpfad vorne dran genügt:

```sh
mkdir -p meineroms/dmv_k235p
cp ../K235FW/k235_fw24.bin meineroms/dmv_k235p/
./dmv dmv -rompath "meineroms;roms" -slot7a k235p ...
```

**Für die K235+ ist dieser Schritt nicht wahlfrei, sondern Voraussetzung.**
Ihre Vorgabe-Firmware heißt `k235_fw24.bin` und steckt **nicht** in `dmv.zip`
— das Archiv enthält nur NCRs `DMV_int_8088_PIC_33473.bin` für die alte K235.
Fehlt die Datei, startet MAME **gar nicht** („Required files are missing"),
und das sieht nach einem kaputten Bau aus, obwohl nur eine Datei am falschen
Ort liegt. Sie liegt in diesem Repo, in [`../K235FW/`](../K235FW/), und wird
über den eigenen Suchpfad untergeschoben; `mame_holen.sh` tut das selbst.

Wer NCRs Original will, nimmt `-slot7a k235p,bios=33473` — das testet nur
sieben Bänke, also höchstens 512 KB.

Für die K235 heißt die Datei `dmv_int_8088_pic_33473.bin`, für den
Tastaturcontroller `DMV Mainboard 8741AD.BIN` im Satz `dmv`. Wird eine
vorhandene Datei nur ersetzt, meldet MAME `WRONG CHECKSUMS` und startet
trotzdem.

### Ohne Fenster prüfen

`dmvtest.lua` liest das Zeichen-RAM des GDC und schreibt es als Text in eine
Datei, tippt nach einem Zeitplan und kann Esc. Ein Testlauf:

```lua
dofile("dmvtest.lua")
plan{
  {30.0, function() screen("Start von Platte") end},
  {32.0, function() key("REBOOT\n") end},
  {70.0, function() screen("nach REBOOT") end},
}
```

```sh
DMVOUT=/tmp/lauf.txt ./dmv dmv -slot1 k208 -slot2a k012 -slot7a k235p \
     -hard1 PLATTE.chd \
     -video none -sound none -nothrottle -seconds_to_run 75 \
     -skip_gameinfo -autoboot_script test.lua
```

**Die fünf Fallen, jede hat schon einmal eine halbe Stunde gekostet:**

1. **Ohne `-seconds_to_run` drosselt MAME auf Echtzeit**, auch mit
   `-nothrottle` und `-video none`. Mit der Angabe läuft es rund sechsmal so
   schnell. Die Zahl muß größer sein als die letzte Zeitmarke im Plan.
2. Der Rückgabewert von `emu.add_machine_frame_notifier` **muß in einer
   globalen Variablen liegen**. Sonst räumt der Sammler ihn weg und der Plan
   läuft nie an – ohne Fehlermeldung.
3. Der Adressraum des GDC heißt **`videoram`**, nicht `data`, und die Adresse
   ist der Zeichenindex, nicht der Byteversatz.
4. **Esc kommt über `natkeyboard` nicht an.** `escdown()`/`escup()` schalten
   direkt das ioport-Feld `:keyboard:COL.1 / Esc`.
5. **Tasten vor dem Prompt gehen verloren.** Ein `key()` zu früh im Plan
   verschwindet spurlos, und der Lauf sieht dann aus, als hätte das Programm
   nicht reagiert. Das Hochlaufen bis zur Eingabeaufforderung dauert gut
   30 Sekunden Maschinenzeit — erst einen `screen()` setzen, der den Prompt
   zeigt, dann tippen.

### MAME selbst bauen

Normalerweise macht das [`mame_holen.sh`](mame_holen.sh) von allein: erst im
Release-Anhang des Forks nachsehen, sonst bauen. Zwei Dinge, die dabei
auffallen:

- **Der OOM-Killer erwischt `luaengine.cpp`.** Auf zwei Kernen mit 7 GB
  reicht der Speicher nicht, wenn diese Datei neben einer zweiten schweren
  übersetzt wird. Der Abbruch sieht nach einem Übersetzungsfehler aus —
  `g++: fatal error: Killed signal terminated program cc1plus` —, ist aber
  keiner. Das Skript legt deshalb vorher Auslagerungsspeicher an und
  wiederholt `make` einmal; die bereits übersetzten Dateien bleiben ja
  liegen, der zweite Lauf holt nur das Fehlende nach.
- **Ein Zweigwechsel kostet wenig.** `homebrew-vzekc` liegt auf einem
  älteren upstream-Stand als `master`; umgeschaltet werden dabei nur
  wenige Kerndateien und die DMV-Dateien. Das ist eine Viertelstunde, nicht
  die volle Stunde.

### Festplatten

Eine leere Platte baut [`mkchd.py`](mkchd.py):

```sh
python3 mkchd.py pruef.chd 615 4 17        # Datei, Zylinder, Köpfe, Sektoren
```

Grenzen: höchstens 1024 Zylinder (CHS über INT 13h) und 8 Köpfe (drei
Kopfbits im SDH-Register des WD1001). Eingerichtet wird sie mit `DMVHDFMT`
(Spuren, Geometrieblock, Hauptbootsatz), dann `FDISK` und `FORMAT C: /S`.

Eine fertige, startfähige Platte wird **nicht** hier abgelegt: sie enthält
COMMAND.COM und MSDOS.SYS von Microsoft. Sie geht nur intern weiter.

Eine neue Fassung eines Werkzeugs bringt man ohne MAME auf die Platte:

```sh
python3 putfile.py PLATTE.chd DMVMON.COM
```

### Wo die Hardwarefakten stehen

Nebenan in [`../docs/`](../docs/): Anschlüsse, ROM-Abläufe, Zeitverhalten,
Tastaturcodes, GDC in `DMV-Hardware-Boot-und-Bildschirm.md`, die Module
und die Porttafel in `DMV-Module-und-Anschluesse.md`, die Erkennung in
`DMV-Erkennung.md`. Neue Befunde gehören dorthin, nicht in eine zweite
Sammlung.

---

## English

Not an emulator – the accessories around it: the MAME command lines for the
usual configurations, a test harness that dumps the screen as text and types
to a schedule, and two tools that put files into a hard disk image without
starting the machine.

| File | Purpose |
|---|---|
| [`dmvtest.lua`](dmvtest.lua) | screen as text, keystrokes, timed plan – drive MAME without a window |
| [`chdio.py`](chdio.py) | read and write sectors of an uncompressed CHD |
| [`putfile.py`](putfile.py) | put a file into the DOS partition of a disk image, without MAME |

Needs MAME with the DMV driver from
[rfka01/mame](https://github.com/rfka01/mame), and `mtools` for `putfile.py`.
Pick the branch first: `master` has the DMV driver and everything historically
attested, `homebrew-vzekc` adds the invented cards — K0815 (1 MB SRAM), K235+
and K238. With `master`, `-slot2 k0815` is silently ignored and the machine
runs with a different configuration than you think.

The K235+ needs `k235_fw24.bin`, which is **not** in `dmv.zip`; it lives in
[`../K235FW/`](../K235FW/) and goes in via a rompath of its own, or MAME will
not start at all.

The German part above has the command lines, how to substitute your own
firmware ROM, and five MAME pitfalls that cost half an hour each: without
`-seconds_to_run` MAME throttles to real time even with `-nothrottle`; the
return value of `emu.add_machine_frame_notifier` must be kept in a global or
the plan never runs; the GDC address space is called `videoram` and is
addressed per character, not per byte; Esc does not go through `natkeyboard` –
use the ioport field `:keyboard:COL.1 / Esc`; and keystrokes sent before the
prompt is up are lost without a trace.

Hardware facts (ports, ROM behaviour, timing, detection) are next door in
[`../docs/`](../docs/).

Code: Claude (Anthropic) · Prompts: rfka01 · MIT
