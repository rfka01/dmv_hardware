# docs/messungen/ – Meßergebnisse, nicht Prosa

Hier liegen **Meßdaten und daraus erzeugte Tabellen**. Der Unterschied zu
den Dokumenten eine Ebene höher: dort steht, was wir verstanden haben,
hier steht, was das Gerät gesagt hat. Wer eine Zahl anzweifelt, soll die
Messung wiederholen können, statt uns glauben zu müssen.

Alles hier ist **eigene Messung** – kein fremder Code, keine abgetippte
Tabelle aus einem Handbuch.

## Tastencodes

| Datei | Inhalt |
|---|---|
| `DMV-Tastencodes.txt` | 95 Tasten × 8 Belegungen × 3 Schaltzustände, wie sie **bei DOS 3.3 ankommen** |
| `kbscan/kb_0.prn` … `kb_7.prn` | die acht Rohmessungen, je eine Zeile pro Messung |
| `kbscan/reihe.json` | die Meßreihenfolge, mit der die Zeilen zu Tasten werden |

**Gemessen, nicht abgeschrieben.** Die Tabelle steht im NCR System
Technical Manual, Figure 2.32 — aber als Scan von 1984, und beim Lesen
fielen zwei Zellen auf, die nicht stimmen können. Die Messung hat einen
davon bestätigt: `S` mit Control gibt **13**, nicht 11 wie gedruckt.
Abschreiben hätte den Druckfehler mitgenommen.

Gemessen wird in MAME gegen die **Originalfirmware** des Tastatur-8741
(`dmv_kbmcu.bin`), über alle acht Stellungen des Landesschalters. Es ist
nicht der Rohcode der Tastatur: der Konsolentreiber von IO.SYS setzt
unterwegs um (CLR wird 7Fh, die Umlauttasten gehen auf 80h–9Fh, die
verdrängten ASCII-Sonderzeichen liegen auf dem Ziffernblock). Genau
diese Sicht braucht ein Programm, das unter DOS Tasten liest.

Ergebnis in einem Satz: **73 der 95 Tasten liefern in allen acht
Belegungen dasselbe, 22 nicht.**

### Wiederholen

```
cd os/msdos33/src/bau
nasm -f bin kbdump.nasm -o KBDUMP.COM        # Meßhilfe aufs Abbild
python3 mach_kbscan.py --mame ~/mame --sprache 3 --cfg cfg_de \
        --liste reihe.json > kbscan.lua
mame dmv ... -cfg_directory cfg_de -autoboot_script kbscan.lua \
        -printout kb_3.prn
python3 lies_kbscan.py reihe.json kb_*.prn \
        --tabelle ../../../../docs/messungen/DMV-Tastencodes.txt
```

**Die Läufe müssen hintereinander laufen, jeder mit eigenem
`-cfg_directory`.** Dort steht die Schalterstellung, und zwei
gleichzeitige MAME-Instanzen überschreiben sich die Datei.

`reihe.json` muß zu den `.prn` passen — sie wird aus MAMEs
`dmv_keyb.cpp` erzeugt, und wenn MAME die Matrix umsortiert,
verschiebt sich die Zuordnung. Deshalb liegt sie hier mit bei, statt
beim Auswerten neu gebaut zu werden.

`lies_kbscan.py` beschriftet jede Datei **aus ihrem eigenen Kopf**: die
erste Zeile ist der Landescode, den IO.SYS selbst erkannt hat. Diese
Selbstbeschriftung hat die Messung gerettet, siehe unten.

### Was dabei im Weg stand

Vier Dinge, die beim Nachbauen sonst wieder Zeit kosten:

- **Die Doppelnull-Taste liefert zwei Bytes** (`30 30`). Eine Marke im
  Tastenstrom als Rahmen scheidet damit aus; KBDUMP rahmt über die Zeit.
- **Eine Messung, die nichts liefert, erzeugt auch keine Zeile.** Dann
  verschiebt sich alles. Deshalb drückt das Skript nach jeder Messung
  **ESC** als Spurtaste: ESC gibt in jeder Belegung und jedem
  Schaltzustand `1Bh`, jede Zeile endet darauf, und was davor steht ist
  die Messung.
- **Ctrl-F20 startet die Maschine neu.** Das macht die Tastatur selbst,
  kein Programm kann es abfangen. Der erste Lauf blieb reproduzierbar
  bei 272 von 285 Messungen stehen — bei 650 wie bei 780 Sekunden, es
  war also nicht die Zeit. Diese eine Messung fällt aus (`!!`).
- **Der Landesschalter läßt sich aus dem Lua-Skript nicht stellen.**
  MAME übernimmt DIP-Stellungen beim **Start** aus `cfg/dmv.cfg` und
  schreibt sie erst beim **Beenden** zurück; ein `f:set_value()` wirkt
  also nicht im laufenden, sondern erst im nächsten Lauf. Der erste
  Entwurf setzte den Schalter so und deutete das Ergebnis als
  „`set_value` auf die Vorgabe schlägt nicht durch", hat zweistufig
  gesetzt und daraus geschlossen, MAMEs Zählung sei gegen die von NCR
  verschoben. **Beides war falsch.** Die acht Läufe trugen jeweils die
  Stellung ihres Vorgängers, und MAMEs Beschriftung stimmt mit NCRs
  überein: Schalter 0 ist US, 3 ist Deutsch, der Index aus dem IOCTL ist
  die Schalternummer plus acht. Daß die Tabelle dennoch stimmt,
  verdankt sie allein der Kopfzeile jeder Datei. `mach_kbscan.py`
  schreibt die Stellung jetzt mit `--sprache`/`--cfg` nach `dmv.cfg`;
  die Kopfzeile bleibt als Gegenprobe.
