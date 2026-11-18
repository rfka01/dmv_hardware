# DMV: Boot, Timing und Bildschirm

Belegte Hardwarefakten zur NCR Decision Mate V, gesammelt bei der
DOS-3.3-Portierung und beim GentleOS/16-Port. Quellen jeweils genannt.
Gedacht als Grundlage für jedes eigene System auf dieser Maschine und für
die MAME-Emulation.

Abschnitte, die NCRs MS-DOS-2.11-BIOS (`DM5SOURC`) beschreiben, nennen
Datei und Prozedur; der Quelltext selbst steht hier nicht (siehe
CONTRIBUTING.md).

## 1. Die Interruptvektortabelle muss gefüllt werden, bevor irgendetwas läuft

NCRs eigenes BIOS aus MS-DOS 2.11 (`basinit.asm`, Einsprung `HWINIT`)
macht als allererstes nach `CLI`: Vektor 0 auf `INT_TRAP` setzen und
diesen Eintrag mit einem selbstüberlappenden `REP MOVSW` über die ganze
Tabelle kopieren (510 Wörter ab Adresse 4). `INT_TRAP` in `iobase.asm` ist
ein nacktes `IRET` für alle nicht belegten Vektoren.

Erst danach setzt NCR seine eigenen Vektoren, und zwar genau sechs:
08h Timer, 12h Speichergröße, 14h RS232, 16h Tastatur, 1Ch
Timer-Rückgabe, 29h schnelle Zeichenausgabe.

Auf der DMV steht in der Vektortabelle beim Start Müll. Jeder nicht
besetzte `INT` springt ins Leere, und man sieht das Zero-Sled-Muster (CPU
frisst sich durch `00 00` = `add [bx+si],al`), das wie ein Neustart
aussieht, während das RAM intakt bleibt.

Belegter Fall: DR Draws GSX-Bildschirmtreiber `DDNCR.SYS` löst beim
Umschalten in die Grafik `INT 0DEh` aus. In Digital Researchs eigenem
Treiberquelltext `DDDMV2.A86` ist 222 (DEh) als spezielle Ausgabe an das
CP/M-Betriebssystem definiert — ein Concurrent-CP/M-Aufruf, den MS-DOS
nicht kennt. CL ist die Funktion (0 Bildschirm, 1 Tastatur, 2 „welcher
Bildschirm ist im Vordergrund“), AL ist 0FFh für ein und 00h für aus.
Unter 2.11 landet der Aufruf auf dem IRET-Trap, AL bleibt 0FFh — und das
ist zufällig die richtige Antwort („du bist vorn“). Ohne gefüllte Tabelle
stürzt dieselbe Software ab.

Regel: Tabelle komplett mit IRET füllen, dann die eigenen Vektoren
setzen.

**GentleOS/16-Umsetzung (nativer Boot):** Der Kernel-Start füllt die
gesamte IVT (256 Einträge) mit einem eigenen `IRET`-Handler, bevor
irgendetwas einen Interrupt auslösen kann. Das war die Ursache der
früheren Reboot-Schleife: der erste `INT 10h` sprang durch einen
Müllvektor.

## 2. Zeitbasis und Interruptcontroller

NCRs Initialisierung in `basinit.asm`, direkt nach der Vektortabelle:

| Baustein | Port | Wert | Bedeutung |
|---|---|---|---|
| 8259 ICW1 | 90h | 17h | flankengesteuert, Adressabstand 4, Single, ICW4 folgt |
| 8259 ICW2 | 91h | 08h | Vektorbasis 8: IRQ0 ist INT 08h |
| 8259 ICW4 | 91h | 03h | AEOI, 8088-Betrieb |
| 8253 Steuerwort | 83h | B6h | Kanal 2, LSB+MSB, Modus 3 |
| 8253 Kanal 2 | 82h | 5000 | 5000 × 2 µs (500 kHz) = 10 ms |

- 8259 auf 90h (Kommando) / 91h (Daten), Single-Modus, AEOI. Kein EOI
  nötig, kein Slave. Vektorbasis 8, IRQ0 ist INT 08h.
- **Vor DOS steht der 8259 anders.** Das ROM 33473 der K235 programmiert
  ihn beim Einschalttest mit ICW1 = 1Bh (**pegelgesteuert**), ICW2 = 08h,
  ICW4 = 01h (normales EOI, kein AEOI), prüft die Maske mit AAh, lässt
  einen Timer-Interrupt mit EOI (20h an 90h) laufen und sperrt danach
  alle Eingänge (Maske FFh). NCRs Beschreibung des Interruptsystems
  (System Information, „Description of 8088 Interrupt System“) nennt
  denselben Zustand. Erst das DOS-BIOS stellt auf flankengesteuert und
  AEOI um (Tabelle oben). Ein Programm, das ohne DOS startet (DMVDIAG,
  Bootmanager), findet also Pegelsteuerung, EOI-Pflicht und alles
  gesperrt vor.
- 8253 Kanal 2 auf 82h (Daten) / 83h (Steuerwort). Eingangstakt
  **500 kHz**. NCR teilt durch 5000, also 10 ms. PC-kompatible
  18,2065 Hz ergeben 27 463.
- Die DMV hat keinen PC-kompatiblen Vorteiler. Jede Rechnung mit
  1 193 182 Hz ist hier falsch.

### Der Taktbaum, aus dem die 500 kHz kommen

System Technical Manual, Appendix A, Blatt 9 (ausgewertet 8.11.2026).
Alles hängt an **einem 24-MHz-Quarz** am **8284A (D3)**:

| Abgriff | Takt | geht an |
|---|---|---|
| OSC (Pin 12) | 24 MHz | 8203, die Speichersteuerung (Blatt 1) |
| CLK (Pin 8) | 8 MHz | 8272 und das Schieberegister auf Blatt 7 |
| PCLK (Pin 2) | 4 MHz | über LX1 als `PCLK/` auf den Bus, J102–J107 a15 |
| 74LS393 D2 aus OSC | 6 MHz | über LX2 an den **8741** |
| 74LS393 D2 aus CLK | 4 MHz | J102–J107 c15 |
| dito | 2 MHz, `CLK1` | 74LS74 A5 → `WRCLK` an den FDC |
| dito | **500 kHz** | **8253 Kanal 2 (CLK2)** |

Damit ist der Zählwert belegt und nicht geschätzt: 2 µs je Takt,
27 463 × 2 µs = 54,926 ms = 18,2065 Hz.

**Kanal 0 des 8253 ist das Zeitglied des Diskettenmotors**, und er wird
**nicht** vom selben Takt gespeist: `CLK0` hängt an `HSYNCX`, dem
Zeilenrücklauf des Bildschirms (Blatt 6). `GATE0` kommt aus `HOL` und
`MON/` (74LS00 A6), `TOUT0` geht über die 74LS00-Kette B16 auf
`MOTORON/` (J110 Pin 16) und auf `MOTOR/`, also Statusbit 0 des
Anschlusses 13h. Die Nachlaufzeit des Motors hängt damit am
Bildschirmtakt.

### Der 8259 ist FLANKENGESTEUERT — und das hat Folgen

ICW1 = 17h hat LTIM = 0, und NCR vermerkt ausdrücklich „edge
triggered“ daneben. Eine Interruptleitung, die **aktiv bleibt**, löst
darum genau **einen** Interrupt aus; erst wenn sie losgelassen und wieder
gezogen wird, kommt der nächste.

Das ist keine Formsache. Die K806 zieht ihre Leitung bei jeder Bewegung
und bei jedem Öffnen und Schließen eines Schalters und lässt sie aktiv,
**bis Befehl 03 sie quittiert** (NCR, Bedienungsanleitung Maus-Adapter,
Doc 017-0033170). Ein Treiber, der nicht quittiert, bekommt einen
Interrupt und danach nie wieder.

Mit `MAUSTEST.COM` (DOS-3.3-Port) ist das vorgeführt — im Prüfstand
gemessen, mit abgeschaltetem Quittieren:

```
Q=a I=E 0Ah=   15 0Dh=    0 St=40 INT=j X=200 Y=150 stumm= 2112
```

Der Zähler friert bei 15 ein, das INT-Bit bleibt gesetzt, und „stumm“
(INT-Bit aktiv, aber kein Interrupt angekommen) läuft hoch.

Umgekehrt gilt: wer einen Interrupt **pegelgesteuert** nachbildet, baut
sich einen Interruptsturm, der die Maschine totlegt. Ein Prüfstand muss
die Flanke auswerten.

### Welche Leitung welches Modul zieht

**Nach dem Schaltplan der K235** (16-Bit Processor with PIC,
017-0033502 Rev. A, Blatt 3) und NCRs Beschreibung des
Interruptsystems:

| IR | INT | Quelle | Weg |
|---|---|---|---|
| 0 | 08h | 8253, TIMINT | J107-b8 |
| 1 | 09h | 8741 Tastatur, P24 (KEYINT) | J107-b7 |
| 2 | 0Ah | `INT/` aller Steckplätze 2–6 (c31), über 74LS00 invertiert | J107-c31 |
| 3 | 0Bh | Steckplatz 3, a2 (IRQ3) | J107-b3 |
| 4 | 0Ch | Steckplatz 4, a2 (IRQ4) | J107-b4 |
| 5 | 0Dh | Brücke S2: 1–2 = Platz 2a (Festplatte, IRQ2A), 1–3 = Platz 2 (IRQ2) | b31 / b2 |
| 6 | 0Eh | 8272, FLEXINT | J107-b6 |
| 7 | 0Fh | Brücke S1: 1–2 = Platz 5 (IRQ5), 1–3 = Platz 6 (IRQ6) | b5 / b9 |

- IRQ2…IRQ6 sind aktiv high und haben auf der K235 **Pull-ups (RR1,
  10 kΩ)**: ein leerer Steckplatz meldet auf seinem Eingang dauernd
  einen Interrupt. Nur Eingänge freigeben, hinter denen eine Karte
  steckt.
- `INT/` (c31) geht laut Schaltplan auch an den Z80.
- NCRs Zuordnung der Karten: K211/K801 (seriell) auf Platz 3 oder 4,
  K210/K212/K801 (Drucker) auf Platz 5, K803, K804 und K806 über
  `INT/`. NCRs eigene Betriebssysteme benutzen diese Interrupts nicht.
- Der K230/K231 fehlt der 8259; dort gibt es keine dieser Leitungen.

**Auf echter Hardware gemessen** (DMVFRAGE 1.00 und DMVDIAG 0.14–0.16,
Maschine A: C.07.00 Farbe, 8088; Maschine B: M.07.00 Mono, V20; beide
K235, 31.10./1.11.2026). Der 8259 steht wie nach dem ROM 33473
pegelgesteuert, das IRR zeigt also den Stand der Eingänge.

| | Ergebnis |
|---|---|
| Brücken | beide Maschinen S1 = 1–2 (IR7 = Platz 5), S2 = 1–2 (IR5 = Platz 2a) |
| Platz → IR | Platz 3 → IR3, Platz 4 → IR4, Platz 5 → IR7; Platz 2 und 6 bei dieser Brückenstellung ohne IR |
| Pull-ups | ein leerer Platz 3 oder 4 und der leere Platz 2a melden dauernd (IR und 13h-Bit gesetzt); ebenso ein Platz mit K215 |
| Leitung in Ruhe inaktiv | K210, K211, K801, K803, K806 (Platz belegt: IR und 13h-Bit 0) |
| treibt keine Leitung | K215 (kein Interruptausgang) |
| Quelle | K210: PC3 · K801 (2661): TxRDY · K211 (2651): **RxRDY**; Sender einschalten (TxRDY/TxEMT) löst nichts aus, ein Byte über die Rückschleife des 2651 schon |
| Diskette | 13h Bit 3 und IR6 stehen gemeinsam, wenn der 8272 eine Meldung offen hat (z. B. nach dem Abschalten des Motors) |

Abweichung von der früheren Annahme in MAME: dort meldete die K211 über
TxRDY, und K803/K806 galten als Karten ohne eigene Leitung (Pull-up
sichtbar). Der Fork rfka01/mame ist seit dem 1.11.2026 nachgeführt; DMVFRAGE
zeigt dort dasselbe Bild wie auf beiden Maschinen. Einmal kam beim Schalten
der K210 zusätzlich 13h Bit 7 (Maschine B, offene 8272-Meldung) – nicht
wiederholt, vermutlich Zufall; Bit 7 ist weiter offen.

Der Steckplatz hat **zwei** Interruptleitungen, und es ist wichtig,
welche ein Modul benutzt — hier ist schon einmal eine Sitzung auf IRQ5
gelaufen, wo IRQ2 richtig war.

| Leitung | Weg (MAME) | wird zu |
|---|---|---|
| `out_int` eines Steckplatzes | `busint<N>_w` → `update_busint` (ODER über alle acht Steckplätze) → `m_slot7a->busint_w` → `ir2_w` | **IRQ2, INT 0Ah** |
| `out_irq` eines Steckplatzes | `irq2a_w` usw. → `update_irqs` → `ir5_w` (bzw. 3, 4, 7 je Steckplatz und DIP) | IRQ5 usw. |
| 8253 Kanal 2 (TIMINT) | `timint_w` → `ir0_w` | IRQ0, INT 08h |
| Tastatur | `keyint_w` → `ir1_w` | IRQ1, INT 09h |
| µPD765 | `flexint_w` → `ir6_w` | IRQ6, INT 0Eh |

**Die K806 liegt auf IRQ2, nicht auf IRQ5.** `k806.cpp` zieht die
`out_int`-Leitung; `out_irq` zieht sie nicht. Nachgemessen mit
`MAUSTEST.COM`: 15 Interrupts auf INT 0Ah, null auf INT 0Dh.

Die DIP-Schalter der K235 verteilen nur die `out_irq`-Leitungen (S:1 legt
INT7 auf Steckplatz 5 oder 6, S:2 legt INT5 auf 2a oder 2); `busint` ist
davon unabhängig, weil es ein ODER über alle Steckplätze ist. Das
bedeutet auch: **mehrere Module auf `busint` teilen sich eine Leitung**,
und jedes muss sie freigeben, sonst bleibt sie für alle aktiv.

### Die Interruptmaske NIE überschreiben

NCR setzt die Maske erst später, in `RE_INIT` (`iobase.asm`), das SYSINIT
nach der Geräteinstallation ruft — und zwar als Lesen-Ändern-Schreiben:
Maske von 91h lesen, nur Bit 0 (Timer) löschen, zurückschreiben, Flags
dabei erhalten. Da ICW1 die IMR ohnehin löscht, sind damit **alle IRQs
frei**.

Wer statt dessen fest `0FEh` nach 91h schreibt, sperrt IRQ1 bis IRQ7
aktiv — und damit jedes interruptgesteuerte Gerät: das Mausmodul, die
seriellen Module, alles. Genau dieser Fehler steckte im DOS-3.3-Port bis
v168. Aufgefallen ist er an DR Draw: der GSX-Treiber `DDNCR.SYS` hängt
sich an einen Hardware-Interrupt (sein Handler schickt EOI an Anschluss
90h und bedient ein Modul auf 30h/31h); unter 2.11 läuft er, unter DOS
3.3 kam nie ein Interrupt an. Seit v169 wird die Maske wie bei NCR
gelesen und nur Bit 0 freigegeben.

Gefahrlos ist das Freigeben, weil jeder nicht besetzte Vektor auf ein
IRET zeigt (Abschnitt 1) und der 8259 im AEOI-Betrieb läuft.

### K230 und K235: nicht jede 8088-Karte bekommt den Timer-Interrupt

Der 8253 sitzt auf der Hauptplatine; sein Kanal-2-Ausgang (TIMINT) geht
nur an den Steckplatz der CPU-Karte. Belegt in MAME (`bus/dmv/k230.cpp`,
`ncr/dmv.cpp`):

- **K235** – V20 *mit* 8259 auf 90h/91h. TIMINT wird IRQ0 → INT 08h.
- **K230** – 8088 *ohne* Interruptcontroller. TIMINT geht ins Leere; auf
  90h/91h antwortet nichts (auf der Hauptplatine unbelegt, Schreiben ist
  harmlos). Ein `HLT` wartet auf einer K230 für immer.

Nur die K235 überschreibt in `bus/dmv/k230.h` die Methoden `timint_w`,
`keyint_w`, `busint_w`, `flexint_w` und die Steckplatz-IRQs; die
Basisklasse der K230/K231 erbt die leeren Stummel aus `dmvbus.h`. Auf
einer K230 erreicht also **kein** Interrupt die CPU — auch nicht von
Tastatur, Diskettencontroller oder Steckplätzen.

Beide Karten laufen mit **5 MHz** (XTAL 15 MHz / 3); die K230 trägt einen
8088, die K235 einen V20. Das ist für Zählschleifen wichtig: auf dem V20
laufen sie deutlich schneller, woran schon NCRs `MOTORCK` gescheitert ist
(das beiliegende `V20_FIX.COM` hebt die Schleife an).

Den 8253 können beide Karten lesen (82h/83h). Auf einer K230 lässt sich
die Zeit daher nur durch Abfragen des Zählers messen — allerdings läuft
Kanal 2 in Modus 3 mit Teiler 27 463 über, der Zähler wrappt also
mehrfach je Sekunde und taugt nur, wenn ständig gepollt wird.

**Zwei erprobte Verfahren, die Karte zu erkennen:**

1. **Am Maskenregister (DOS-3.3-Port, `DMV_PicProbe`).** Nach
   ICW1/ICW2/ICW4 ist 91h das Maskenregister des 8259, rückschreibbar und
   rücklesbar. Zwei Muster (AAh, 55h) sind ein vollständiger Achtbittest;
   ohne Karte liest der Bus FFh (`map.unmap_value_high()`). Keine
   Wartezeit beim Start, unabhängig von der Taktrate. Die Maske wird dabei
   überschrieben und danach auf 00h gesetzt — genau der Zustand, den ICW1
   ohnehin hinterlässt.
2. **An der Zeit (GentleOS/16, nativer Boot).** Den 10-ms-Takt starten,
   Interrupts freigeben und Kanal 2 etwa 40 ms beobachten. Kommt ein
   Timer-Interrupt, ist es eine K235 und es läuft interruptgesteuert (die
   CPU darf `HLT`). Kommt keiner, ist es eine K230: Interrupts bleiben
   aus, Kanal 2 läuft frei in Modus 2 über die vollen 16 Bit (131 ms je
   Umlauf), und die Leerlaufschleife leitet die Ticks aus dem Zählerstand
   ab, statt `HLT` auszuführen.

**Ohne Interruptcontroller braucht die Tageszeit eine andere Quelle.**
Ein tickgetriebener Zähler steht auf einer K230 still — NCRs eigenes 2.11
verhält sich dort genauso (`timdrv.asm` führt die Zeit allein im Tick und
kennt die K803 nicht; die bediente bei NCR der getrennt geladene
`TIMDRIVE.SYS`). Der DOS-3.3-Port holt die Ticks ab v170 aus der K803:
eine absolute Tageszeit hat kein Überlaufproblem und 10-ms-Auflösung
statt 55 ms. Mitternacht darf dabei nur an einem **großen** Rücksprung
erkannt werden — ein kleiner stammt vom Leseversatz zwischen Hundertstel
und Uhrzeit, und wer den für Mitternacht nimmt, schiebt das Datum um
einen Tag vor.

K230 und K231 sind **nicht zu unterscheiden**: dasselbe ROM (32167, CRC
`f4a58880`; die K235 hat 33473), und `dmv.cpp` gibt `io_read`,
`io_write`, `busint_w` und alle `irq*_w` immer an beide Steckplätze
(`m_slot7` und `m_slot7a`), während Anschluss 13h Bit 1 das ODER aus
deren `av16bit()` ist. Die K234 (68008) ist vom 8088 aus gar nicht
feststellbar: ihre Anschlüsse liegen bei 0FFF00h–0FFFFFh im Adressraum
**des 68008**, und das Postfach der Firmware sagt nichts über die
Prozessorbestückung.

## 3. Boot-Übergabe Z80 → 8088

### Woher der Z80 startet, und wie das RAM an seine Stelle tritt

Appendix A, Blatt 4 (ausgewertet 8.11.2026). Das Mainboard-ROM ist
**D14, ein 2764**, im Plan ausdrücklich mit dem Bereich **A 0000 …
A 8191** beschriftet — also 0000h–1FFFh, acht Kilobyte, BA0–BA12
unmittelbar an den Adresseingängen. Freigegeben wird es von `MEMR/`
**und** `RAMOUTDIS/`.

`RAMOUTDIS/` kommt aus der Kippstufe **A11 (74LS74)**: `RAMSEL/`
(Anschluss 10h) setzt sie, `ROMSEL/` (11h) setzt sie zurück, und ihr
Ausgang wird mit BA13–BA15 (74LS32 F8) zu `RAMOUTDIS/` verknüpft, das
außer dem ROM auch die Speichersteuerung auf Blatt 1 erreicht. Das ist
die Mechanik hinter dem `OUT 10h`, mit dem MSLOAD vor dem Sprung in den
Monitor das RAM einblendet.

Auf demselben Blatt: der **8237-5 (C16)** mit Kanal 3 für die Diskette
und **Kanal 2 für die Grafikkarte** (`GDRQ2`/`DACK2/` auf J113), und die
acht Diagnosedioden als Register an BD0–BD7, getaktet von `ERR/` und
gelöscht von `ESET/` — das ist der Anschlussbereich 00h–0Fh.

- Das Z80-Mainboard-ROM übergibt nur, wenn das OEM-Feld des Bootsektors
  (Bytes 3–10) exakt `16BIT` mit Füllleerzeichen ist.
- Der Bootsektor wird nach 0000:2000 geladen und dort angesprungen.
- Postfach im RAM (Firmware-Liste, Systemhandbuch Anhang A):
  - `0:FE01` SB8 – Status vom 8-Bit-Teil
  - `0:FE04` CB16 – Kommando an den 8088 (0 Monitor, 1 STARTS,
    2 EXECUTE_SOFTWARE, 3 LEVEL0; ab 4 zurück auf den Z80)
  - `0:FE05` SB16 – Status zurück (0 gut, 0FFh Fehler)
  - `0:FE06` MEM16 – Anzahl der 64-KB-Erweiterungsbänke, ohne die 64 KB
    der Hauptplatine
  - `0:FE07` – 1 = von Platte gestartet, 0 = von Diskette
    (`dmv_os/docs/DMV-Bootmanager.md`, Abschnitt 2.2)
  - **`0:FE08` und `0:FE09`** – Ergebnis einer Probe des Z80-ROMs vor
    dem Laden (ROM 33610, Routine 0786h, am Code nachgelesen, noch nicht
    gemessen): RECALIBRATE auf A:, dann READ ID mit Kopfstellung
    Zylinder 2. **`FE09` = N** der gelesenen Kennung (2 = 512 Byte).
    **`FE08` = 0**, wenn die Kennung C = 2 trägt, sonst **1**. Bei
    `FE08 = 1` verdoppelt das ROM beim Laden jede Spurnummer
    (ROM 0709h–0713h): Doppelschritt, also eine 40-Spur-Diskette im
    80-Spur-Werk. Von einer 40-Spur-Diskette gestartet, verrät `FE08`
    damit die Spurzahl von A:. Vorbesetzung vor der Probe: FE08 = 1,
    FE09 = 2. **Nicht überschreiben.**
  - `0:FE10` – vom Z80-ROM benutzt (dreimal geschrieben, zweimal
    gelesen)

### Was im Postfachbereich frei ist – an beiden ROMs ausgemessen

Statt die OCR-Abschrift des Firmware-Listings zu befragen, sind am
25.10.2026 **beide ROMs nach absoluten Zugriffen auf `0:F800`–`0:FFFF`
durchsucht** worden: das 8088-ROM der K235 (33473) und das
Z80-Mainboard-ROM in beiden Fassungen (33609 monochrom, 33610 Farbe –
die sich hier als gleich erweisen).

| Adresse | Z80-ROM | 8088-ROM |
|---|---|---|
| FE01, FE04, FE05 | ja | ja |
| FE06 | **nein** | ja |
| FE07, FE08, FE09, FE10 | ja | nein |
| **FE11–FEF7** | **nichts** | **nichts** |

Zwei Dinge daran sind wichtig.

**`FE11`–`FEF7` ist frei.** Keines der beiden ROMs faßt dort etwas an,
und der Z80-Stapel liegt bei `F700` bzw. `F000` (`LD SP,nn` an den
ROM-Offsets 004Ah und 0379h) – er wächst nach unten und kann den
Bereich nicht erreichen. Dort ist also Platz für den Startblock des
Bootmanagers (`dmv_os/docs/DMV-Bootmanager.md`, 1a).

**Frei heißt nicht dauerhaft.** Am NEC-Abbild nachgemessen, Frame für
Frame: der MBR legt den Startblock bei `0:FE20` um Frame 860 an, bei
Frame 910 steht dort schon etwas anderes – DOS lädt MSDOS.SYS über den
Bereich. Es bleiben rund **60 Frames**. Nicht die Adresse ist schuld:
DOS nimmt sich den Speicher unter 64K ohnehin, eine andere Stelle im
Postfachbereich hielte genausowenig. Wer die Angabe später braucht,
muß sie sich früh holen und selbst aufheben.

Die Messung ist nur dicht abgetastet brauchbar. Bei Schritten von 200
Frames war an der Stelle immer eine Null zu sehen, und die Platte
startete trotzdem – weil `0 AND 18h` zufällig Einheit 0 ergibt und das
auf einer Einplattenmaschine richtig ist. Ein bloßer Start beweist bei
Einheit 0 also nichts.

**Für `FE06` findet sich im Z80-ROM kein direkter Schreibzugriff**,
obwohl die Firmware-Liste sagt, der Z80 trage die Bankzahl dort ein.
Entweder geschieht das indiziert – über `(HL)`, was eine Mustersuche
nicht sieht –, oder die Angabe ist ungenau. Nachgeprüft ist nur, daß
das 8088-ROM von dort liest; unser MSLOAD tut dasselbe und bekommt
brauchbare Werte, die Stelle wird also von irgendwem gefüllt.
- Das 4-KB-ROM der 8088-Karte liegt 128-fach gespiegelt über
  80000h–FFFFFh. Am ROM-Anfang steht `JMP DISPLAY`, deshalb funktioniert
  `FF00:0000` für Textausgabe: BX zeigt auf einen Zählstring (Längenbyte,
  dann Text), gelesen über DS — also DS auf 0 setzen und absolut
  adressieren.
- **Steuerzeichen von DISPLAY — je nach CPU-Karte verschieden.**
  Auf **beiden** ROMs wirkt nur `88h` (neue Zeile, rollt in Zeile 25).
  Das ROM der K235 (33473, Zeichenroutine 2F3h) kennt außerdem `00h`
  (übergangen), `01h` (Cursor oben links), `0Ch` (Schirm löschen) und
  `8Bh` (Rückschritt). Das ROM der K230/K231 (32167, Routine 263h)
  prüft vorher `test al,0F0h` und gibt **alle Codes 00h–0Fh als
  Zeichen** aus; `0Ch` erscheint dort als Akut „´“ und löscht nichts
  (in MAME mit K230 gesehen, 27.10.2026). Wer auf beiden Karten sauber
  ausgeben will, benutzt nur `88h`, setzt den Cursor selbst und löscht
  mit Leerzeichen. Nach Spalte 80 geht es in der nächsten Zeile
  weiter.
- **Löschroutine CLSCR in beiden ROMs** (gleich aufgebaut: Cursor 0,
  MASK, FIGS über 16 K Worte, ein WDAT, Rollzeiger und Bildbereiche
  zurück): 33473 bei `03FEh` (füllt mit Attribut E8h), 32167 bei
  `032Dh` (füllt mit **00h** – auf einer Farbkarte weißer Grund, auf
  Mono normal). Beide enden mit nahem `RET`; von außen erreichbar mit
  einem `RETF` des ROMs als Rücksprung (33473: `0521h`, 32167: `0458h`,
  jeweils das Ende von DISPLAY). DMVDIAG nutzt das ab 0.05 und füllt
  danach die 2000 Textworte mit dem eigenen Attribut nach.
  Der Cursor steht in `0:F800` (Spalte) und `0:F801` (Zeile); die
  Routine rechnet die Bildschirmadresse bei jedem Zeichen daraus neu, man
  kann ihn also durch Schreiben dieser beiden Bytes setzen. DISPLAY gibt
  keine Interrupts frei.
- **Prüfsummen (CRC-32) der ROMs**, aus `dmv.zip`: Hauptplatine 32664
  `6624610E` (M.05.00), 32676 `7796519E` (M.06.00), 32838 `D5CEB559`
  (C.06.00), 33609 `120951B6` (M.07.00), 33610 `BF25F3F0` (C.07.00);
  8088-Karte 32167 `F4A58880` (K230/K231), 33473 `104195DC` (K235).
  `DMV_68K.bin` ist kein K234-ROM, sondern bitgleich mit 33610.
- **Übergabe an den 16-Bit-Prozessor und zurück** (alle fünf
  Hauptplatinen-ROMs M.05.00 bis C.07.00 gleich, ROM 0580h): Für
  „16BIT" setzt das ROM `FE04 = 32h`, kopiert acht Bytes nach
  `0:F10C` und springt dorthin: `OUT 10h` (RAM einblenden),
  `OUT D0h` (Bus an die 8088-Karte), `NOP`, `JP F111h`. Gibt der 8088
  den Bus mit `OUT D0h` zurück, läuft der Z80 bei `F110h` weiter und
  dreht sich bei `F111h` im Kreis – im RAM, das der 8088 vorher
  beschreiben kann. **Damit kann ein 8088-Programm eigenen Z80-Code
  ausführen lassen**: Code nach `0:F111` legen, `OUT D0h`; der Z80
  arbeitet ihn ab und gibt mit `OUT D0h` zurück, der 8088 läuft hinter
  seinem `OUT D0h` weiter. Das Z80-ROM selbst greift nie auf
  `D8h–DFh` (K234) zu.
- **Neustart aus einem 8088-Programm** (DMVDIAG 0.17, DMVFRAGE 1.01,
  DMVINFO 1.00; in MAME getestet mit K230 und K235): Der Kaltstart des
  Z80-ROMs testet das RAM und überschreibt dabei auch den Code, den der
  8088 nach seinem `OUT D0h` noch holen würde – ein `JMP FFFF:0000`
  hinter dem `OUT D0h` kommt nicht mehr an (der 8088 läuft in
  überschriebenes RAM, der Z80 bleibt bei ROM 05FCh stehen und wartet
  auf FE05). Beide 8088-ROMs (32167 und 33473) haben bei `FF00:0018`
  dieselbe Befehlsschleife: `OUT 11h`, `OUT D0h`, `NOP`, `OUT 10h`,
  dann Befehl aus `FE04` (0–3, sonst wieder von vorn). Dorthin springt
  der 8088 mit DS = ES = SS = 0, SP = 0 (wie nach `FF00:0003`), nachdem
  er nach `0:F111` den Z80-Code `DI`, `OUT (11h),A`, `JP 0000h` gelegt
  hat. Der Z80 startet kalt und findet den 8088 in seiner Schleife, so
  wie nach dem Einschalten (ROM 05F0h: `FE04 = 33h`, `OUT D0h`).
  Vorher die beiden Worte bei `FF00:0018` prüfen.
  Anders als Ctrl-F20 (RESET über den Tastatur-8741) zieht dieser
  Neustart keine RESET-Leitung: 8259, Steckkarten und K234/K238 bleiben
  im alten Zustand, soweit das Z80-ROM sie nicht selbst einstellt. Auf
  echter Hardware noch nicht geprüft.
- **Diskettencontroller laut Schaltplan** (System Technical Manual,
  Anhang A, Blatt „Flex Disk Contr."; in der Sammlung `sysschem` als
  Blatt 5): 8272 (E6) mit **4 MHz** an CLK (Pin 19); MAME setzt
  `I8272A(config, m_fdc, 8'000'000, true)`, rechnet die Zeiten aber aus
  der Datenrate (250 kbit/s) und kommt so auf dieselben Werte wie ein
  8272 mit 4 MHz. **RDY (Pin 35) hängt über den Treiber D6
  am `READY/` des Laufwerks (J110-34)** und geht zugleich als `FDCRDY`
  auf Anschluss 13h Bit 2. Ein 5¼-Zoll-Laufwerk meldet READY nur mit
  eingelegter, drehender Diskette; MAMEs upd765 führt SEEK und
  RECALIBRATE ohne READY nicht aus (ST0: NR, abgebrochen). **Ohne
  Diskette gibt es also keinen Schritt und keine Spurzahlmessung**;
  DMVDIAG ab 0.08 belegt das mit der Probe T. Spur 0 (`TRACK0/`,
  J110-26) und „zweiseitig" erreichen den 8272 nur über seine
  Umschaltung Lesen/Positionieren (`RW/SEEK`); der Eingang `2SIDED/`
  liegt auf Masse (ST3 meldet immer zweiseitig). Nur zwei
  Laufwerksauswahlen (`SEL0/`, `SEL1/`).
- **Diskettenzeiten im NCR-BIOS von DOS 2.11** (`DM5SOURC`: `dskdrv.asm`,
  `flxpimc.asm`):
  - SPECIFY `03 D6 02` für 48 tpi, `03 E6 02` für 96 tpi (umgeschaltet,
    wenn die Diskette mehr als 200 KB je Seite hat). Bei 4 MHz am 8272:
    Schritt 6 ms bzw. 4 ms, Kopf entladen 192 ms, Kopf laden 4 ms, DMA.
    6 ms ist die Schrittzeit aus dem Laufwerksdatenblatt („track to
    track < 6 ms“, System Technical Manual Fig. 2.17) – ein Hinweis
    mehr auf 4 MHz.
  - Motor: Anschluss 13h Bit 0 = 1 heißt „Motor aus“; dann `OUT 14h`
    und eine Zählschleife mit 65535 Durchläufen um einen `AAM`, laut
    Kommentar der Quelle auf etwa 1 s ausgelegt. Auf READY wird nicht
    gewartet. Das
    Datenblatt nennt Anlauf unter 400 ms und READY bis 800 ms nach
    Motor ein. Abgeschaltet wird nach 838 Takten von 8253 Kanal 0
    (Bildtakt 56 Hz) = 14,9 s (PITTEST).
  - Wiederholungen: je 5 beim Lesen und Schreiben.
  - Gerechnet (Datenblatt-Taktzahlen): 8088 mit 5 MHz ≈ 1,2–1,3 s,
    V20 mit 5 MHz ≈ 0,4 s, V20 mit 7,5 MHz ≈ 0,27 s.
- **V20FIX** (`V20_FIX.COM`, 231 Bytes, Diskette „DOS – V20FIX – FMT20 –
  Uhr 5“, vermutlich Homebrew für die umgebaute K235): legt eine neue
  Zählschleife nach `0:2E00`, die durch einen Rücksprung-Trick zweimal
  mit je D000h Durchläufen läuft, und lenkt die Motor-Warteschleife des
  BIOS bei `0:31DE` mit einem Sprung dorthin um. Das ergibt
  106 496 statt 65 535 Durchläufe, auf dem V20 mit 7,5 MHz ≈ 0,44 s.
  Es prüft weder Bytes noch CPU und gilt nur für genau dieses IO.SYS
  (2.11, „NCR-version 2.11 (02.00)“); `0:2E00` liegt in einem 2-KB-
  Nullblock des IO.SYS (`0:265E–0:2E5D`) unbekannten Zwecks. In MAME
  übersteht der Patch DIR, CHKDSK und COPY. Eigene Treiber warten nach
  `OUT 14h` auf READY (13h Bit 2) mit einer Zeitgrenze über den 8253.
- **Anschluss 13h laut Schaltplan** (Blatt mit `SYSSTAT/`, 74LS244 F8):
  Bit 0 `MOTOR/`, Bit 1 `16BITAV/`, Bit 2 `FDCRDY`, Bit 3 `FLEXINT`,
  **Bit 4–7 `IRQ3`…`IRQ0`** aus den Steckplätzen (J105…J102, Stift a2).
  `hw/dmvhw.def` führt Bit 7 als „Indexloch" – **offen**, am Gerät zu
  klären; ein Indexsignal ist auf diesem Blatt nicht zu sehen. Bit 4–6
  sind gemessen: Platz 4 / 3 / 2, aktiv 1 (DMVFRAGE, 1.11.2026).
- **Steckplatzbus ohne Pull-ups:** zwischen lokalem Datenbus und
  BD0–BD7 sitzt ein 74LS245 (F11), Richtung „zum Rechner" nur bei
  IFSEL-Zugriffen. Ohne Karte schwebt BD und liefert den zuletzt
  getriebenen Wert – das ist der Grund für die Scheinkarten im
  Startbildschirm. MAME liefert dort FFh. **Gemessen** (DMVDIAG 0.16,
  beide Maschinen, 8088 und V20): ein leerer Anschluss liefert das
  **untere Byte seiner eigenen Portadresse** (B0h–B3h auf B0h–B3h, C2h/C3h
  auf C2h/C3h, CEh auf CEh) – der gemultiplexte Adress-/Datenbus des
  8088 hält die Adresse aus dem ersten Buszyklus. Ein vorher in den
  Speicher geschriebenes Füllmuster wirkt dagegen nicht. Eine Probe muss
  also „Wert = unteres Adressbyte“ als leer werten; DMVDIAG 0.16 tut das
  noch nicht und meldet solche Hälften als „belegt“ bzw. „stabil“.
- **Start der K234 in NCRs CP/M-68K 1.2** (Bootdiskette 1.01, am Code
  nachgelesen): Gestartet wird **vom Z80 aus** mit `OUT DFh`; jeder
  Start setzt den 68008 zurück, er holt SSP und PC aus `0:0000–0007`
  (der Z80 legt vorher das PC-Wort nach `0:0006`). Zurück gibt der
  68008 mit einem Schreibzugriff auf `FFFDFh` (`move.b #$7f,$fffdf`),
  danach läuft der Z80 hinter seinem `OUT DFh` weiter. NCR nutzt das als
  Wechselspiel: der 68008 legt Z80-Code ab und läutet, der Z80 führt ihn
  aus und startet den 68008 neu. Ein `OUT D8h` **vom 8088** aus (so
  DMVDEMO `/6`) blieb auf echter Hardware ohne Wirkung. Mit einer
  K230/K231 statt K235 nimmt die 8088-Karte `D8h–DFh` als `D0h`
  (keine Auswertung von BA3) – dann ist eine K234-Probe zu unterlassen. `OUT 00h` in diesem ROM schreibt die
  Frontleuchten, nicht den Prozessorwechsel.
- Umschaltung: `OUT 11h` ROMSEL (Karten-ROM über 0000h–1FFFh, acht
  Kilobyte), `OUT 10h` RAMSEL zurück, `OUT 00h` Prozessorwechsel. Wer aus
  einer Adresse unter 2000h heraus umschaltet, holt den nächsten Befehl
  aus dem ROM.
- Ohne RAM-Erweiterung (K200/K202/K208) hat die 8088-Karte nur die 64 KB
  der Hauptplatine; Lesen darüber liefert 0FFh.
- Die Diskettenleistung ist durch die Drehzahl begrenzt: 9 Sektoren je
  Umdrehung bei 300 U/min sind ~23 KB/s. Multi-Track-Lesen (MT-Bit)
  bringt gegenüber kopfweisem Lesen nichts Messbares.

### Zurück in den 16-Bit-Monitor — und sein Paßwort

`CB16 = 0` und ein Fernsprung auf `F000:0003` (BEGIN im gespiegelten
ROM) führt in den Monitor der 8088-Karte. MSLOAD tut das, wenn die
Maschine zu wenig Speicher hat und der Benutzer ENTER drückt.

**Zwei Fallen, beide am 25.10.2026 in MAME gemessen:**

1. **Vorher muß `OUT 41h,1` kommen.** Wer auf eine Taste wartet, ohne
   den 8741 angestoßen zu haben, wartet ewig — das Kommando ist
   zugleich seine Initialisierung (Abschnitt 4). Im Bootsektor und im
   übrigen Ladeweg faßt niemand die Tastatur an, es gibt also keinen,
   der das sonst täte. Bis v199 fehlte es in MSLOAD: die Meldung stand
   da, ENTER bewirkte nichts, und von außen sah es aus wie ein Hänger.
   Im **Bootsektor** fehlte es noch bis v215 — dort fiel es nur nicht
   auf, weil der Fehlerzweig bloß „Fehler“ ausgab und niemand ihn je
   zu Ende probiert hat. Am 15.11.2026 in MAME gemessen: die Schleife
   las endlos `08h` von 41h, Bit 0 kam nie. Mit dem Anstoß kommt erst
   der Landescode (`89h` / `E8h`), dann die Taste (`09h` / Zeichen).

   Seit v218 **wartet auch MSLOAD im 64-KB-Zweig auf eine Taste**,
   bevor es in den Monitor springt: der Monitor der Logo-Firmware
   löscht als erstes den Schirm, und die Meldung war in dem Augenblick
   weg, in dem er sich meldete. Antwortet der 8741 auf den Anstoß gar
   nicht, läuft die begrenzte Warteschleife wie bisher durch und es
   geht ohne Taste weiter — hängenbleiben kann die Maschine dort also
   nicht.
   Der 8741 antwortet auf dieses Kommando zuerst mit dem **Landescode**
   (Statusbit 7 gesetzt) — das eine Byte muß gelesen und verworfen
   werden, sonst bleibt es im Puffer stehen und keine Taste kommt nach.
2. **Der Monitor fragt vier Zeichen ab, ohne Echo** — man sieht gar
   nichts und hält auch das leicht für einen Hänger. Im ROM der Karte
   (33473, K235) bei `0632h`:

   ```
   0632  mov cx,4            vier Zeichen holen
   0639  call 02E0h          ein Zeichen, ohne Echo
   0642  lea si,[062Eh]      dort steht '0815'
   064A  repe cmpsb
   064D  jz   0652h          stimmt: Monitor starten
   064F  jmp  0018h          falsch: zurück, wortlos
   ```

   **Das Paßwort ist `0815`.** Stimmt es, meldet sich
   `MONITOR 8088/8087 V1.0I` (auf der K230/K231 `V0.0`, siehe Punkt 4)
   / `NCR-DECISION MATE V` mit dem Prompt `*`. Stimmt es nicht,
   passiert nichts Sichtbares.
3. **`M` und `P` sind keine vollständigen Befehle.** Das hat uns lange
   aufgehalten: jede Form wie `M 0` oder `P 41` endet mit
   `SYNTAX ERROR`. Am 15.11.2026 aus dem ROM 33473 geholt und in MAME
   bestätigt — beide lesen nach dem Buchstaben mit `LODSW` **zwei**
   Zeichen und lassen nur `'B '` (2042h) oder `'W '` (2057h) gelten,
   Byte oder Wort; der Buchstabe landet in `0:FD10`. Es heißt also
   `MB`, `MW`, `PB`, `PW`, und alles muß groß geschrieben sein.

   ```
   06B8  Vergleichskette der Befehlsbuchstaben
         R→086Dh  M→097Fh  P→092Bh  G→06F6h  S→06EFh  E→0018h
   097F  lodsw / cmp ax,2042h ('B ') / cmp ax,2057h ('W ')
   0AC1  Zahlenleser: Hexziffern, ':' schaltet auf seg:off,
         ',' '=' und NEWL beenden
   0AE9  Hexziffernprüfung ('0'-'9','A'-'F') - sonst 0B69h
   0B69  SYNTAX ERROR
   ```

   Geprüft: `MB 0:FE00` zeigt 16 Byte mit Textspalte, `MB 0:0,F` einen
   Bereich, `MB 0:FE06=7` schreibt (Rücklesen zeigt `07`), `PB 41`
   antwortet `0041=0C`. `G` und `S` nehmen nach einem Leerzeichen eine
   Adresse in derselben Schreibweise; `S` setzt dabei `0:FD15` auf
   `F0h`, `G` auf 0.

4. **Die beiden ROMs tragen NICHT denselben Monitor.** Alles oben
   Genannte ist an der 33473 abgelesen; die 32167 der K230/K231 kann
   weniger. Nachgesehen in beiden ROM-Abzügen und am 18.11.2026 auf
   der K230 in MAME nachgestellt (bis dahin stand hier und in
   `dmv_os` die Annahme, beide seien gleich):

   | | 32167 (K230, K231) | 33473 (K235, K235+) |
   |---|---|---|
   | Kopfzeile | `MONITOR 8088/8087 V0.0` | `MONITOR 8088/8087 V1.0I` |
   | Vergleichskette | `0514h`, fünf Buchstaben | `06B8h`, sechs |
   | `P` (Anschlüsse) | **gibt es nicht**, `PB 41` → `SYNTAX ERROR` | `PB`/`PW` wie oben |
   | `MB a` | EIN Byte, `0000:FE06=07H` | 16 Byte mit Textspalte |
   | `MB a,e` | `SYNTAX ERROR` am Komma | zeigt den Bereich |
   | `MW a` | endloser Wortabzug, acht je Zeile | 16 Byte wortweise |
   | `R` | acht Register in einer Zeile | zwei Zeilen |

   Gleich sind `MB a=b`, `MW a=w` (niederwertiges Byte zuerst), `G`,
   `S`, `E`, der Zwang zu Großbuchstaben und die Forderung nach `B `
   oder `W ` hinter dem `M`. Ob sich der endlose `MW`-Abzug der 32167
   mit Ctrl-C anhalten läßt, ist offen — über die Tastaturnachbildung
   in MAME kam weder ENTER noch Ctrl-C an.

   Die Kopfzeile steht in beiden ROMs im Klartext (`0482h` bzw.
   `0602h`, abgeschlossen mit `88h`) und ist damit der zuverlässige
   Weg, die Fassung zur Laufzeit zu bestimmen; welche Befehle sie
   kennt, verrät sicherer die Vergleichskette: `3C 52 74 .. 3C 4D 74
   ..`, und dahinter steht bei der 33473 ein `CMP AL,'P'`
   (`3C 50`), bei der 32167 nicht. `dmv_os/tools/dmvmon` macht
   genau das.

Die Einsprungadresse des Monitors ist je nach Karte eine andere
(`04B2h` bei der externen 32167, `0632h` bei der internen PIC 33473) —
deshalb wird die Sprungtabelle nicht nachgebaut, sondern das ROM liest
sie über BEGIN selbst. Zum Nachstellen liegt
`os/msdos33/src/bau/monitor.lua` bereit: es drückt ENTER, tippt das
Paßwort und zieht einen Abzug.

## 4. Tastatur (8741)

Konstanten nach `basinit.asm`:

| Name | Wert | Bedeutung |
|---|---|---|
| Kommando „Landescode liefern“ | 01h | an Port 41h |
| Kommando-/Statusport | 41h | |
| Datenport | 40h | |
| Statusbit 0 | 01h | Zeichen da |
| Statusbit 7 | 80h | das Zeichen ist der Landescode |

- `OUT 41h,1` ist zugleich die nötige Initialisierung; ohne sie liefert
  der 8741 gar nichts.
- Statusbit 7 gilt nur für dieses eine Byte: NCRs Firmware
  (`DMV_MB_8741_32678_Var1`) setzt es vor der Antwort (222h, `MOV STS,A`),
  wartet, bis die CPU das Byte gelesen hat (OBF), und löscht es wieder
  (227h). Unter MAME mit `-bios c71` (homebrew-Firmware) gingen Tasten
  verloren, solange ein Treiber Bit 7 auswertete; sicher ist, die Antwort
  auf `01h` einmal abzuholen und Bit 7 danach nicht mehr zu beachten.
- **Antwort auf `01h` (in MAME gemessen):** Status mit Bit 7 gesetzt, das
  Datenbyte ist `E8h + Landescode`.
  **Bit 7 bleibt danach stehen:** in MAME kam jede folgende Taste mit
  Status 89h (DMVDIAG 0.06, 27.10.2026). Bit 7 kennzeichnet also nur die
  erste Antwort nach `01h`; wer es bei jeder Taste prüft und verwirft,
  bekommt keine Taste mehr. Auf echter Hardware noch nicht nachgesehen. 
  **Tasten vor dem Befehl kommen zuerst** (in MAME gemessen, CP/M 3
  v000, 6.11.2026): was vor `OUT 41h,1` gedrückt wurde, liegt im 8741 und
  wird **vor** dem Landescode geliefert, mit Bit 7 = 0. Wer das erste Byte
  nach `01h` ungeprüft als Landescode nimmt, verliert die Taste und liest
  den Code später als Zeichen E8h–EFh. Richtig: bis zum Byte mit Bit 7
  weiterlesen und die Tasten davor aufheben. Beim Start von Diskette
  vergehen in MAME rund 25 s bis zum ersten Befehl des Systems. Der Landescode (0–7) sind die
  DIP-Schalter unter der Tastatur; Version-1-Tastaturen: 0 US,
  1 UK/Int., 2 Dänisch, 3 Deutsch, 4 Schwedisch/Finnisch, 5 Norwegisch,
  6 Spanisch, 7 Italienisch. Version-2-Tastaturen (Schweiz, Frankreich,
  …) belegen dieselben Codes anders und sind daran nicht zu erkennen.
- Die Tastatur sendet das Zeichen, das auf der Taste steht. Auf der
  deutschen Tastatur sitzt Y also dort, wo die US-Tastatur Z hat
  (QWERTZ); auf der italienischen sind W und Z vertauscht (QZERTY).
  Programme, die die Tastatur als Fläche benutzen (Klaviatur, Spiele),
  müssen das je nach Landescode zurückrechnen. Den Code brauchen sie
  nicht selbst zu erfragen: seit v199 gibt ihn das Bildschirm-IOCTL
  unter `'K'` heraus, mit Rohbyte und Index
  (`dmv_os/docs/DMV-Schnittstellen.md`, Abschnitt 6). Ein eigenes `OUT 41h,1` im
  laufenden Betrieb wäre auch riskant — es ist zugleich die
  Initialisierung des 8741 und greift in den Tastenstrom hinein.
- Sondertasten kommen als 80h–9Fh. Die Eingabetaste ist **88h, nicht
  0Dh**; NCRs Tabelle `KBDTBL` setzt sie auf 0Dh um.
- 88h ist gleichzeitig der Bildschirm-Steuercode „neue Zeile“ (NEWL) der
  Firmware. Dieselbe Zahl, zwei Bedeutungen.
- Die deutsche Tastatur sendet die ISO-646-Codes 7Bh/7Ch/7Dh und
  5Bh/5Ch/5Dh für die Umlaute; der Landescode steuert die Umsetztabelle.
  Wie das für die anderen Belegungen aussieht und wo es klemmt: die zwei
  Unterabschnitte am Ende dieses Abschnitts.
- **Ctrl-F20 startet die Maschine neu.** Das entscheidet die Tastatur
  selbst, bevor irgendetwas davon zur CPU gelangt — im Firmwarelisting
  des 8741 (NCR TSC System Information HW2 2.7) steht
  `XRL A,#0B3H` / `JZ RESET` mit dem Kommentar
  „IF A=F20 THEN RESET DM5“; B3h ist der Control-Code von F20
  (Position F54). **Kein Programm kann das abfangen**, auch kein
  Treiber: es gibt keinen Tastencode, den man verwerfen könnte. Gefunden
  beim Abklappern der Tastatur — der Meßlauf blieb reproduzierbar bei
  272 von 285 Messungen stehen, bei 650 wie bei 780 Sekunden, es war
  also nicht die Zeit.
- **Die Doppelnull-Taste liefert zwei Bytes** (`30 30`). Wer Tasten
  zählt oder im Tastenstrom nach einer Marke sucht, rechnet sonst falsch.
- Vollständige Tastenbelegung: NCR System Technical Manual, Figure 2.32
  (Version 1) und 2.33 (Version 2); die Firmware des Tastaturcontrollers
  als Listing in NCR TSC System Information HW2 2.4ff. Beides liegt bei
  rfka01, nicht im Repo. **Gegen die Originalfirmware nachgemessen**
  liegt die Tabelle aber im Repo:
  [`messungen/DMV-Tastencodes.txt`](messungen/DMV-Tastencodes.txt), 95
  Tasten × 8 Belegungen × 3 Schaltzustände, in der Form, in der die
  Codes **bei DOS ankommen**. 73 Tasten sind in allen acht Belegungen
  gleich, 22 nicht. Dabei bestätigte sich ein Druckfehler des
  Handbuchs: `S` mit Control gibt **13**, nicht 11.

### Die Codes liegen gruppenweise

An der Messung aller acht Belegungen nachgeprüft: was bei DOS ankommt,
liegt in zusammenhängenden Gruppen. Ein Programm braucht deshalb keine
Tabelle je Tastatur, um eine Taste zu benennen — es rechnet aus dem Code
(so macht es `DMVKEY /T`):

| Codes | Bedeutung |
|---|---|
| `00h`–`1Fh` | Steuerzeichen (`08h` Rückschritt, `09h` Tab, `0Dh` Eingabetaste, `1Bh` ESC, sonst Ctrl + Buchstabe) |
| `20h`–`7Eh` | ASCII |
| `7Fh` | CLR; Ctrl-CLR ist `8Ch` |
| `80h`–`9Fh` | Zeichen des Zeichengenerators — **außer** `81h`–`85h` und `91h`–`95h`, das ist der Cursorblock, und `8Ch` |
| `A0h`–`B3h` | Ctrl-F1 bis Ctrl-F20 |
| `B4h`–`BFh` | Ctrl + Ziffernblock |
| `C0h`–`D3h` | Shift-F1 bis Shift-F20 |
| `D4h`–`DFh` | Shift + Ziffernblock |
| `E0h`–`F3h` | F1 bis F20 |

Im Block sind `x` = `4`…`F` die Tasten `4 5 6 7 8 9 * + 1 2 3 /`; `0`,
Komma und Eingabe des Blocks haben keine geschaltete Form.

Drei Ausnahmen, alle gemessen:

- **Das Minus des Ziffernblocks** liefert mit Shift `F4h` und mit
  Control `F5h` — außerhalb seiner Gruppe und oberhalb von F20.
- **`A6h`–`A9h` (Ctrl-F7 bis Ctrl-F10)** kommen nie bei DOS an: der
  Treiber nimmt sie für den Bildschirmabzug (`dmv_os/docs/DMV-Schnittstellen.md`,
  Abschnitt 5).
- **`B3h` (Ctrl-F20)** kommt nie an, weil die Tastatur dabei die
  Maschine neu startet (siehe oben).

### Landesbelegung: zwölf Wechselplätze, zwölf Rettungsplätze

Die DMV schaltet die Belegung **in der Tastatur** um: DIP-Schalter unter
dem Gehäuse, der 8741 wählt daraus eine von acht fest eingebauten
Codetabellen. Der Rechner hat darauf keinen Einfluß und erfährt den Code
nur auf Nachfrage. Die Tastatur sendet, was auf der Taste steht — in
ISO-646-Codes, und die acht Belegungen unterscheiden sich in genau
**zwölf** Plätzen: `23h 24h 40h 5Bh 5Ch 5Dh 5Eh 60h 7Bh 7Ch 7Dh 7Eh`.

Was eine Belegung dort mit einem Landeszeichen besetzt, geht als
ASCII-Sonderzeichen verloren. Dafür gibt es eine Rettungsinsel: der
**Ziffernblock mit Shift** liefert `D4h`–`DFh`, und zwar in **allen acht
Belegungen identisch** (gemessen, `messungen/DMV-Tastencodes.txt`).

```
D4 Shift-4   D5 Shift-5   D6 Shift-6   D7 Shift-7
D8 Shift-8   D9 Shift-9   DA Shift-*   DB Shift-+
DC Shift-1   DD Shift-2   DE Shift-3   DF Shift-/
```

**Zwölf Rettungsplätze für zwölf Wechselplätze** — es geht genau auf,
und keiner bleibt übrig. Die aufwendigste Belegung ist
Schwedisch/Finnisch mit elf Landeszeichen; einer bleibt frei. Die
deutsche Umsetzung von IO.SYS benutzt bisher sieben
(`D7`→`[`, `D8`→`]`, `D9`→`\`, `D4`→`{`, `D5`→`}`, `D6`→`|`,
`DC`→`@`); `DA DB DD DE DF` sind frei und würden `#`, `$`, `^`, `` ` ``
und `~` aufnehmen.

### Die Klemme: der Cursorblock sitzt auf den Glyphencodes

Die Sondertasten des Cursorblocks reichen `81h`–`85h` und `91h`–`95h`
**roh an DOS durch**. Dieselben Codes sind aber Glyphen des
Zeichengenerators (Abschnitt 7). Für Deutsch geht das auf — für die
anderen sieben Belegungen nicht:

| Belegung | gebrauchte Glyphencodes, die der Cursorblock schon hat |
|---|---|
| Deutsch | **keine** |
| UK/Int. | 83h `£` |
| Italienisch | 83h `£`, 94h `é` |
| Spanisch | 83h `£`, 85h `Ñ`, 95h `ñ` |
| Dänisch, Norwegisch | 81h `Æ`, 82h `Å`, 91h `æ`, 92h `å`, 93h `¤` |
| Schwed./Finn. | 82h `Å`, 84h `É`, 92h `å`, 93h `¤`, 94h `é` |

**Deutsch ist die einzige Gruppe-1-Belegung ohne Kollision.** Das ist
kein Zufall: NCRs Codewahl für die Sondertasten paßt zur deutschen
Tabelle, und `DMV_Layout DB 1` in `dmvcon.inc` ist damit nicht nur eine
Vorgabe, sondern die einzige Einstellung, für die die Codeverteilung
heute aufgeht. Dieselbe Enge in kleiner Form gibt es schon: `86h` ist
`Ö`, deshalb geht CLR als `7Fh` und Ctrl-CLR als `8Ch` heraus statt roh.

Wer eine weitere Belegung unterstützen will, muß die Sondertasten also
zuerst aus `80h`–`9Fh` herausholen — etwa als Zweibytefolge `00h` +
Code nach PC-DOS-Art, wofür `DMV_Pend` schon da ist. Das ist eine
**Änderung an `dmv_os/docs/DMV-Schnittstellen.md`** und betrifft jedes Programm, das
Cursortasten liest; am Platzbedarf liegt es nicht (die Tabellen für alle
acht kosten rund 130 Byte im residenten Teil, also ein halbes Prozent).

**Festgelegt (rfka01, 25.10.2026): es bleibt vorerst bei Englisch und
Deutsch.** Mehr ist nicht geplant, und der Treiber tut genau das — `B_Lang`
stellt `DMV_Layout` auf 1 bei Index 11 und sonst auf 0. Die Tabelle oben
steht hier als Begründung, nicht als Vorhaben: sie sagt, warum die
anderen sechs nicht einfach nachzuziehen sind, und was zuerst passieren
müßte, falls sich das einmal ändert.

### Töne über den 8741 (TONE, Befehl 06h)

Befehl 06h auf 41h, dann Tonbyte (n + 20h, n = 1–42, A 110 Hz bis
D 1175 Hz, f = 110 · 2^((n−1)/12)) und Längenbyte (Einheiten + 1Fh, eine
Einheit ~20,5 ms; Länge 0 = 256 Einheiten, vermeiden) auf 40h.

Fallstrick: Während der 8741 einen Ton spielt, liest er seinen
Eingangspuffer nicht — IBF (Statusbit 1) steht aber trotzdem schon wieder
auf 0. Mehrere Bytes direkt hintereinander überschreiben sich dann im
Puffer; der 8741 sieht ein Kommando ohne Daten und wartet ewig auf ein
Datenbyte, samt Tastatur. Sicheres Protokoll: bei IBF = 0 nur 06h
schreiben; erst wenn IBF danach wieder 0 ist (der 8741 hat das Kommando
genommen und wartet aktiv), Ton- und Längenbyte hintereinander. Ein
begonnenes Kommando immer zu Ende senden.

**Dasselbe Warten ist zugleich das Tempo einer Tonfolge.** Das `06h` für
den nächsten Ton geht sofort hinaus, denn der Eingangspuffer ist leer;
IBF wird danach aber erst wieder frei, wenn der 8741 das Kommando
abholt, und das tut er erst nach dem Ende des laufenden Tons. Wer also
vor jedem der drei Bytes auf IBF = 0 wartet, bekommt die Noten von
selbst nacheinander — ein Zeitgeber wird nicht gebraucht. Zwei Folgen
daraus:

- **Diese Wartestelle darf kein Zeitlimit haben.** Eine Länge von `FFh`
  dauert 4,6 s; ein Zeitlimit würde Töne abschneiden und, schlimmer, ein
  begonnenes Kommando unvollständig lassen. Absichern lässt sich nur die
  Wartestelle **vor** dem `06h`: dort ist noch nichts gesendet, und ein
  nicht vorhandener 8741 (unbelegter Port liest `FFh`, IBF also dauernd
  gesetzt) kostet dann nur den Ton und nicht den ganzen Rechner.
- **Zwischen den Noten wartet der Treiber, und in dieser Zeit tippt der
  Anwender weiter.** Steht ein Zeichen an (Statusbit 0), gehört es in
  den Tastaturvorrat des Treibers. NCRs IO.SYS liest es an dieser Stelle
  blind aus und verliert es; MS-DOS 3.3 legt es ab v204 in dieselbe
  Ablage, aus der `ESC [ 6 n` beantwortet wird.

Am 6.11.2026 in MAME mit `TONTEST.COM` (`src/bau/tontest.nasm`) und
`-wavwrite` nachgemessen, C-Dur-Tonleiter über `ESC M`:

| Tonbyte | Note | gemessen | Soll |
|---|---|---:|---:|
| 30h | c | 260,2 Hz | 261,6 Hz |
| 32h | d | 291,2 Hz | 293,7 Hz |
| 34h | e | 328,6 Hz | 329,6 Hz |
| 35h | f | 347,4 Hz | 349,2 Hz |
| 37h | g | 391,7 Hz | 392,0 Hz |
| 39h | a | 439,2 Hz | 440,0 Hz |
| 3Bh | h | 494,2 Hz | 493,9 Hz |
| 3Ch | c' | 522,2 Hz | 523,3 Hz |

Alle acht innerhalb eines Prozents. Die Längen kamen 4 % kürzer heraus
als gerechnet (10 Einheiten als 195 statt 205 ms), die Länge `7Fh` mit
1,97 s genau. An echter Hardware ist nichts davon nachgemessen.

## 5. GDC µPD7220

Nach der Firmware-Liste (`BOOTER_IO_DRIVER`): Kommando schreiben auf
A1h, Status lesen und Parameter schreiben auf A0h; Statusbit 1 (02h)
heißt FIFO voll.

Dazu aus der Messung an DR Draws Treiber: Statusbit 5 (20h) ist der
**Bildrücklauf (VSYNC)**. Grafiksoftware wartet darauf, bevor sie den
Bildspeicher anfasst (A0h lesen, Bit 20h prüfen, wiederholen). Ein
Emulator oder Prüfstand, der an A0h einen festen Wert liefert, lässt
jedes solche Programm endlos drehen — das sieht aus wie ein Absturz, ist
aber nur der fehlende Bildrücklauf.

Festwerte der Firmware: 80 Zeichen je Zeile, 25 Zeilen, CURSOR 49h,
MASK 4Ah, FIGS 4Ch, PRAM 70h, WDAT 20h (Wort, Replace), START/End-Idle
68h. Variablen: `0:F800` CURSX, `0:F801` CURSY, `0:F900/F901`
Cursoradresse, `0:F902` COAD (Pixelposition), `0:F903` SP1 (Anfang
Seite 1), `0:F906` LP12 (Länge Seite 1), `0:F90B` INVFLG (Attribut,
E8h = grün auf schwarz).

**Zurücklesen des Bildspeichers (RDAT).** Die DMV hat keinen
CPU-adressierbaren Bildspeicher; wer den Schirminhalt braucht, holt ihn
über den GDC. Am 14.10.2026 aus `upd7220.cpp` belegt — MAMEs
Fortsetzungslogik für lange Leseaufträge nennt ausdrücklich „a5105 and
**dmv** text scrolling“, die DMV-Firmware benutzt RDAT also selbst zum
Rollen des Textbereichs.

- Kommando `A0h | Typ << 3`: **A0h** liefert ganze Wörter (erst das
  untere, dann das obere Byte), **B0h** nur die unteren Bytes (die
  Zeichencodes), **B8h** nur die oberen (die Attribute). Typ 1 (A8h) ist
  ungültig.
- **Die Zahl der Einheiten steht vorher in FIGS, Parameter DC — beim
  LESEN als die ANZAHL SELBST, nicht als Anzahl minus eins.** Das
  Minus-eins gilt fürs Zeichnen von Figuren und für WDAT, nicht für
  RDAT. NCRs System Technical Manual (CP/M-86, Abschnitt GRAPHICS,
  „Figure") sagt es getrennt: *„Writing data: D1 = number of display
  words required, **minus 1**"* gegen *„Read data via CPU: D1 = number
  of words to be accessed."* MAME ist genauso asymmetrisch:
  `rdat()` läuft `while (m_figs.m_dc && …) { … m_dc--; }`, `wdat()`
  dagegen `for (i = 0; i < m_figs.m_dc + 1; i++)`.

  Das hat v183 bis v190 unbrauchbar gemacht: DMVSNAP forderte 2000
  Zellen an, setzte DC auf 1999, bekam 1999 Bytes, wartete auf das
  zweitausendste, lief in die Zeitsperre und warf **alles** weg.
  RDATTEST hatte keine Zeitsperre und blieb ganz stehen.
- Die Startadresse steht in **CURS** (EAD).
- **Gelesen wird auf A1h**, nicht auf A0h. A0h ist beim Lesen das
  Statusregister, A1h der Datenausgang (FIFO). Das ist genau umgekehrt
  zum Schreiben, wo A0h die Parameter nimmt und A1h die Kommandos.
- **Statusbit 0 (01h) heißt DATA READY.** Erst wenn es steht, liegt ein
  Byte bereit. Der GDC füllt die FIFO selbsttätig nach, solange DC noch
  nicht abgelaufen ist — ein Auftrag über die ganzen 2000 Zellen geht
  also in einem Stück, man muss nur Byte für Byte abholen.
- Benutzt von DMVSNAP (`tools/dmvsnap/`).

Beim schnellen Schreiben gelernt:

- **Die Richtung in FIGS ist eine Himmelsrichtung, und 0 ist NICHT
  „nach rechts".** Der erste FIGS-Parameter trägt in den unteren drei
  Bit die Zeichenrichtung. MAMEs Tabelle (`upd7220.cpp`):

  ```
  x_dir[8] = { 0, 1, 1, 1, 0,-1,-1,-1}
  y_dir[8] = { 1, 1, 0,-1,-1,-1, 0, 1}
  ```

  **Richtung 0 läuft senkrecht nach unten** (EAD += PITCH), **Richtung
  2 nach rechts** (EAD += 1). NCR empfiehlt ausdrücklich die 2:
  *„Perhaps the most easily understandable Direction setting is 2, as
  this accesses the addresses in ascending order, i.e. left to right,
  then the next line down."*

  Unser Treiber benutzt in `DMV_PutN` seit v157 die 2. Die Werkzeuge
  benutzten bis v190 die 0 und lasen und zeichneten damit **Spalten
  statt Zeilen**. Bei einem Muster, das in jeder Zeile gleich ist,
  fällt das nicht auf — nur an einer durchgehend gefüllten Zeile.
- **PITCH bleibt beim Umschalten auf Grafik stehen.** Im Zeichenbetrieb
  sind es 80 Worte je Bildzeile, im Grafikbetrieb wären es 40. Das
  Kommando 47h setzt sie; RESET und SYNC ebenfalls. Wer nur das IM-Bit
  im PRAM umschaltet, arbeitet weiter mit 80 — bei Richtung 2 ist das
  folgenlos, bei jeder senkrechten Richtung nicht.
- **CURS lädt auch MASK.** Der dritte CURS-Parameter enthält die
  Punktadresse dAD, und der GDC setzt MASK = 1 << dAD. Nach jedem CURS
  muss MASK für Wortzugriffe wieder auf FFFFh, sonst schreibt WDAT nur
  das linke Pixel jedes Wortes.
- **NCRs eigene Leseroutine** steht im System Technical Manual
  (CP/M-86, Seite 5-86f) als `SETREAD` / `FIFOCLR` / `READSCRN`. Sie
  setzt vor dem Lesen **PRAM-Byte 8 und 9 auf FFFF** und **MASK auf
  FFFF**, benutzt Richtung 2, D1 = Anzahl, und liest **acht Worte je
  Auftrag** — genau die FIFO-Tiefe —, wobei FIGS und RDAT für jeden
  Block neu geschickt werden. Vierzig Worte am Stück gehen in MAME
  auch; ob das auf echter Hardware gilt, ist offen.
- **Ein Lesevorgang wird durch ein Kommando abgebrochen**, nicht durch
  Warten: *„A read sequence can be discontinued by transmitting a
  command to the GDC."* Das ist auch der einzige Weg, denn auf
  „FIFO leer" zu warten hilft nicht — siehe die nächste Zeile.
- **Nach einem RDAT wird die FIFO nicht leer, solange Lesedaten darin
  stehen.** NCR warnt davor ausdrücklich: *„The status bit will not be
  reset as long as the buffer is full of read data, so if your new
  command byte is waiting for this bit to reset, your program will
  loop."* Wer vor jedem Kommando auf „FIFO leer" wartet, hängt sich
  nach dem ersten Lesen selbst auf.
- **FIGS bleibt über WDAT hinweg stehen, DC AUCH.** Das stand hier bis
  v189 falsch („nur DC fällt danach auf 0"). `upd7220.cpp` schreibt in
  `for (i = 0; i < m_figs.m_dc + 1; i++)` und rührt DC nicht an. Wer DC
  setzt, muss es selbst zurücknehmen — sonst schreibt das nächste
  einzelne WDAT sein Wort gleich DC+1 mal. Unser Treiber tut das seit
  v157 mit `DMV_Fig1` (`dmvcrt.inc`); NCRs `SETCCA` tut vor jedem
  Einzelzeichen dasselbe.
- **Beim Lesen läuft DC ab — aber nur so weit, wie die CPU abholt.**
  `read_vram_from_fifo` füllt in `while (m_figs.m_dc && m_fifo_ptr < …)
  { … m_figs.m_dc--; }` häppchenweise nach und räumt FIGS erst auf, wenn
  DC null ist. Eine *vollständig* abgeholte RDAT-Übertragung hinterlässt
  also DC = 0; eine **abgebrochene** hinterlässt DC stehen. Genau das
  trat in v183–v189 auf: DMVSNAP bricht die Leseschleife mit einer
  Zeitsperre ab, weil DATA READY auf echter Hardware nicht kommt, und
  liess DC auf 1999 liegen. Danach schrieb der Bildschirmtreiber jedes
  Zeichen 2000 mal über den Schirm — das war der „Bildschirmmüll" nach
  Ctrl-F7 und Ctrl-F8. **Regel: DC an jedem Ausgang zurücknehmen, auch
  am Fehlerausgang.**
- „FIFO nicht voll“ (Bit 1 = 0) garantiert nur einen freien Platz;
  „FIFO leer“ (Bit 2 = 1) garantiert 16. Für Blöcke auf „leer“ warten.
- Die Übertragung ist auf der DMV durch die CPU begrenzt, nicht durch den
  GDC (in MAME ist die FIFO dabei nie voll). Eine Assembler-Schleife
  (Byte holen, XLAT-Bitumkehr, XOR, OUT) ist rund neunmal schneller als
  derselbe Ablauf in C mit Funktionsaufruf je Byte.

## 6. Festplatte WD1001 — Zeitverhalten

- Ports: C0h Daten, C2h Sektorzahl, C3h Sektornummer, C4h/C5h Zylinder,
  C6h SDH, C7h Status/Kommando. Statusbits: 80h BUSY, 40h READY, 08h DRQ,
  01h ERROR.
- Ohne Controller liest der Bus 0FFh, und darin ist BUSY gesetzt. Jede
  Warteschleife auf „BUSY fällt“ läuft dann ewig. Lösung: den Controller
  einmal mit einem Schreib-Lese-Test suchen (55h auf C4h, AAh auf C3h,
  zurücklesen) und das Ergebnis merken; alle Warteschleifen mit
  Zeitgrenze.
- Unteres Nibble des Kommandos: nur bei RESTORE (1xh) und SEEK (7xh) ist
  es die Schrittweite (0 = Buffered Seek 35 µs, 1–15 = 0,5 bis 7,5 ms).
  Bei READ (20h) und WRITE (30h) stehen dort Mehrsektor- und
  Interruptbits — eine dort hineingeschriebene Schrittweite verbiegt die
  Übertragung.
- NCRs eigener Treiber kennt genau drei Kommandos: 10h RESTORE mit
  Schrittweite 0, 20h READ, 30h WRITE. Kein SEEK, kein langsames
  RESTORE.

### Die Schrittweite muss man selbst setzen — sonst erbt man sie

Der Controller nimmt die Schrittweite aus dem unteren Nibble von RESTORE
und SEEK und **behält** sie, auch für die impliziten Seeks bei READ und
WRITE. Wer nie ein RESTORE schickt, arbeitet mit der Schrittweite, die
der letzte vor ihm gesetzt hat — beim Start das Z80-ROM, das
Haupt-Bootsatz und Bootsektor liest (mit Schrittweite 15, siehe
`dmv_os/docs/DMV-Bootmanager.md`, Abschnitt 2.2); ein Lauf des alten DMVHDFMT stellte
sie ebenfalls auf 15 und ließ sie stehen.

Bei Schrittweite 15 kostet ein Schritt 7,5 ms, über 600 Zylinder also
viereinhalb Sekunden. Innerhalb einer Partition sind die Seeks kurz und
das fällt nicht auf; beim Wechsel des Laufwerksbuchstabens springt der
Kopf über die halbe Platte. **Das war die beobachtete Pause von vier
Sekunden** nach „D:“ und nach jedem Befehl, der ein anderes
Plattenlaufwerk anspricht (ein DIR listete sofort, weil die Spur schon
richtig lag, und brauchte danach wieder vier Sekunden, weil COMMAND.COM
das aktuelle Verzeichnis des anderen Laufwerks wieder braucht).

NCR löst es in `widrv10.asm` mit Buffered Step (Schrittweite 0) und
schickt ein RESTORE in `GETBPB` bei **jeder** BPB-Abfrage sowie in jedem
Fehlerzweig. Mindestens einmal beim Finden des Controllers je
vorhandener Einheit, mit kurzer Bereitschaftsprüfung statt der vollen
Zeitsperre.

### Wer zum Z80 zurückgeht, muß vorher Einheit 0 wählen

Gefunden am 16.11.2026, nachdem REBOOT und der Ausstieg aus dem Monitor
den Start von Platte zerschossen: die Maschine blieb mit
`WAITING FOR FIX-DISK` stehen, der Hardware-Reset mit Strg-F20 dagegen
startete sauber.

Zwei Gewohnheiten, die sich beißen:

1. **Wir wählen nach jedem Zugriff die Einheit ab.** `HD_Desel` in
   `dmvbios.inc` setzt die Einheitenbits des SDH-Registers (Bit 4–3)
   auf **3** — „Lampe aus“, genau wie NCRs `widrv10.asm`. Dasselbe tun
   der Festplatten-Bootsektor (`hdboot_dmv.nasm`), DMVPARK und
   DMVHDFMT. Nach jedem Plattenzugriff steht also eine Einheit
   angewählt, die es auf keiner DMV gibt.
2. **Das Z80-ROM fragt BEREIT ab, bevor es eine Einheit wählt.** Im
   Plattenzweig (07E4h, alle 7.00-ROMs byte-gleich):

   ```
   07FB  IN A,(C7) / AND 40h    BEREIT? — mit dem SDH, der gerade dasteht
   07FF  JR nz,0804h            ja: weiter
   0801  CALL 083Fh             nein: "WAITING FOR FIX-DISK", 200 Versuche
   ...
   081A  LD A,A0h / OUT (C6),A  Einheit 0 — erst hier
   ```

   Die Wartestelle bei 083Fh prüft in ihren 200 Durchläufen auch nur
   Bit 40h und schreibt kein SDH. Das Bit folgt der **angewählten**
   Einheit (ST506: die READY-Leitung des gewählten Laufwerks; in MAME
   `wd1000.cpp`, `drive_ready()`), und für Einheit 3 kommt es nie.

Beim Kaltstart paßt es zusammen, weil der Hardware-Reset das
SDH-Register auf 0 setzt — Einheit 0. Ein reiner Z80-Neustart
(`RST 0` über FF00:0018) setzt den Controller nicht zurück, die 3
bleibt stehen, und der Start von Platte fällt aus.

**Regel:** Wer die Maschine an den Z80 zurückgibt, schreibt vorher
`A0h` auf Anschluß `C6h`. Zwei Befehle, und sie schaden nicht, wenn
gar kein Controller steckt. Umgesetzt ab v221 in REBOOT.COM, in FDISKs
`REBOOT.ASM` und in DMVMON (dort vor dem Sprung in den Monitor, damit
auch dessen Ausstieg wieder von Platte startet — an NCRs eigenen ROMs
können wir nichts ändern). Dasselbe gilt für alles, was noch kommt:
Bootmanager, CP/M-Systeme, Werkzeuge, die neu starten.

### Der Diskettenwechsel braucht keine Zeitmessung

Anschluss 13h Bit 3 ist die Interruptleitung des µPD765, und der
Baustein setzt sie im Leerlauf auch, wenn sich die Bereitschaft eines
Laufwerks ändert — also beim Klappenöffnen und beim Diskettenwechsel
(MAME: `upd765.cpp`, `run_drive_ready_polling`, alle 1024 µs,
ST0 = ABRT | Einheit | NR). NCR benutzt genau das in `MEDIAC`
(`dskdrv.asm`): Bit 3 lesen, und wenn es steht, einen Merker für
**beide** Einheiten setzen (`FLTAB`) — welches Laufwerk es war, sagt die
Leitung nicht. Ein Einlaufwerkssystem meldet immer „weiß nicht“.

Vollständige Belegung von Anschluss 13h (nach `dmv.cpp`,
`sys_status_r`, und NCRs Gebrauch in `flxpimc.asm`):

| Bit | Bedeutung |
|---|---|
| 7 | Indexloch der Diskette |
| 6 / 5 / 4 | IRQ 2 / IRQ 3 / IRQ 4 |
| 3 | Interrupt des Diskettencontrollers (**live**, nicht gespeichert) |
| 2 | Laufwerk bereit |
| 1 | 16-Bit-Prozessor vorhanden (negiert) |
| 0 | Diskettenmotor läuft |

Eine frühere Notiz nannte Bit 2 „Transfer“ und Bit 3 „Seek complete“ —
beides falsch.

Alles zu Partitionen, Signaturen, Alt-Platten und den privaten
INT-13h-Funktionen steht in `dmv_os/docs/DMV-Datentraeger.md`.

## 7. Mono-DMV

- Beide Maschinen gibt es: Mono mit Mainboard-ROM 33609 „M.07.00“, Farbe
  mit 33610 „C.07.00“. Beide mit Grafikkarte und Zeichengenerator 76161.
- Erkennung zur Laufzeit über die Versionszeichenkette im
  Mainboard-ROM. **Am ROM (33609/33610, 8 KB) verifiziert:** Die
  Zeichenkette steht am ROM-Offset **0FF9h** als
  `08 20 'M'/'C' 2E 30 37 2E 30 30` (also ` M.07.00` bzw. ` C.07.00`).
  Das unterscheidende Byte ist **0FF9h**: `4Dh` ('M') = mono, `43h`
  ('C') = Farbe. (Die frühere Notiz „0FFAh“ war um eins daneben; bei
  0FFAh steht in beiden ROMs identisch `2E 30` = „.0“.) Das ROM liegt zur
  Laufzeit 128-fach über 80000h–FFFFFh gespiegelt, das Byte also physisch
  bei 0FEFF9h (z. B. F000:EFF9 oder FEFF:0009).
- Zeichengenerator 76161: nur 128 Glyphen, Bit 7 des Codes wird
  ignoriert. ASCII auf 20h–7Fh, Akzentzeichen auf 00h–1Fh und damit
  gespiegelt auch auf 80h–9Fh. Dadurch sind Backslash, eckige und
  geschweifte Klammern gleichzeitig mit den Umlauten darstellbar.
  DMV-Codes (NCR-Tabelle für Deutschland in `basinit.asm`): ae=90h,
  oe=96h, ue=99h, Ae=80h, Oe=86h, Ue=89h, sz=9Eh. Für my gibt es keinen
  gesicherten Code.
- **Alle 32 Akzentglyphen, am ROM-Abbild gerastert** (25.10.2026,
  `DMV Mono Board M1-76161.BIN`; die Farbkarte ist byteidentisch). Die
  Namen stehen maschinenlesbar in `../hw/dmvhw.def`:

  | | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
  |---|---|---|---|---|---|---|---|---|
  | **8xh** | Ä | Æ | Å | £ | É | Ñ | Ö | Ø |
  | **88h** | ç | Ü | à | è | ´ | ° | ↑ | ¨ |
  | **90h** | ä | æ | å | ¤ | é | ñ | ö | ø |
  | **98h** | ò | ü | ù | ì | § | ¿ | ß | ¡ |

  Das ist **genau die Vereinigungsmenge aller acht Gruppe-1-Belegungen**
  (Version-1-Tastaturen, Landescode-Index 8–15). Kein Glyph fehlt; übrig
  bleiben nur `´`, `¨` und `↑`, und `¨` wird von der französischen
  Belegung gebraucht. NCR hat den Baustein also für alle acht bestückt —
  wir nutzen bisher acht Glyphen davon. Was **nicht** da ist: `ã õ` für
  Portugiesisch (im Mainboard-ROM bei Index 90h vorhanden, aber der
  76161 wirft Bit 7 weg, auf dem Schirm daher unerreichbar), `ê î ô û`
  für die Schweizer Belegungen, `č ž š đ` für Jugoslawisch. Die Hälfte
  von Gruppe 2 ist auf dieser Hardware nicht darstellbar.
- 16 Rasterzeilen je Zeichenzeile (CSRFORM-Parameter 1, Bits 4–0 =
  Zeilen minus eins, Bit 7 = Cursor sichtbar). Der zweite
  Zeichengenerator für Text im Grafikbereich sitzt auf der Hauptplatine
  im CPU-ROM-Bereich 1000h–1FFFh, ebenfalls 16 Byte je Zeichen,
  erreichbar über ROMSEL/RAMSEL.
- **Am 21.10.2026 an den ROM-Abbildern Glyphe für Glyphe nachgerechnet**
  (33610 „C.07.00“ gegen `DMV Colour Board M3-76161.BIN` und
  `DMV Mono Board M1-76161.BIN`). Daraus vier Fakten, die jeder braucht,
  der Text selbst rastert:

  | | |
  |---|---|
  | **Bitlage** | **Bit 0 ist der linke Punkt** — dieselbe Richtung wie im Grafikspeicher. Die Bitlagen liegen also aufeinander; wer einen Textschirm in ein Bild rastert, braucht keine Punktschleife, sondern nur das Glyphenbyte und sein Gegenstück |
  | **Maske** | **Zugriff mit `Code AND 7Fh`.** Das Mainboard-ROM trägt **256** Glyphen in ZWEI verschiedenen Hälften: Index 10h ist `ä`, Index 90h ist `ã`. Der 76161 hat nur 128 und wirft Bit 7 weg. Ohne die Maske bekommt jeder Umlaut eine Tilde statt der Punkte — die DMV-Codes liegen ja bei 80h–9Eh |
  | **Abweichung** | Die beiden Zeichensätze sind sonst **bitgleich**. Einzige Ausnahme: **Code 3Ah, der Doppelpunkt** — im 76161 auf den Rasterzeilen 5 und 8, in der ROM-Kopie auf 6 und 9. In einem gerasterten Abzug sitzt der Doppelpunkt also einen Punkt tiefer als auf dem Schirm |
  | **Karten** | Mono- und Farb-76161 sind **byteidentisch** |

  Umschaltung wie bei der Firmware-Kennung: `OUT 11h` blendet das 8 KB
  große ROM über 0000h–1FFFh ein, `OUT 10h` holt das RAM zurück. Dabei
  sind die Interruptvektoren weg, also Interrupts aus — und **der Stapel
  darf nicht angefaßt werden**: Schreiben geht immer ins RAM, Lesen käme
  aus dem ROM, läge der Stapel unter 2000h. Alle `PUSH` vor `OUT 11h`,
  alle `POP` nach `OUT 10h`, dazwischen kein `CALL`. Ebenso darf der
  umschaltende Code selbst nicht unter 2000h liegen (daran ist IO.SYS
  v151 gestorben, siehe `B_FwRead` in `dmvbann.inc`).
- **Im Textbetrieb existiert kein Bild.** Der GDC setzt die Zeichen erst
  beim Anzeigen aus dem Zeichengenerator zusammen; im Bildspeicher liegen
  nur Zeichencode und Attribut. Ein Grafikabzug eines Textschirms liest
  deshalb die Zeichencodes als Punktmuster. Am Ausdruck vom 21.10.2026
  nachgemessen und damit belegt: Streifenabstand genau **16 Druckpunkte**
  = ein Bildspeicherwort, und ab **Bildzeile 44** wiederholt sich das
  Muster über 320 Bildzeilen unverändert — 2000 Zellen sind bei 40 Worten
  je Bildzeile genau 50 Bildzeilen, der Rest ist ungenutzter Speicher.
  DMVSNAP ab v195 erkennt den Fall und rechnet das Bild stattdessen aus
  Zeichen-ROM, Code und Attribut (`tools/dmvsnap/README.md`).
- **Das Attributbyte bedeutet auf den beiden Karten NICHT dasselbe.**
  Nach NCRs System Information, Abschnitt „Character Generator and
  Attribute Logic“, sind die Bits 8–15 des Bildspeicherworts so belegt
  (Bit 8 ist Bit 0 des Attributbytes; das untere Byte des Wortes ist der
  Zeichencode):

  | Bit | monochrom | Farbe |
  |---|---|---|
  | 8 | **invers** | **nicht bestückt, ohne Wirkung** |
  | 9 | Blinken | Blinken |
  | 10 | **halbe Helligkeit** | Vordergrund rot |
  | 11 | ohne Wirkung | Vordergrund grün |
  | 12 | ohne Wirkung | Vordergrund blau |
  | 13 | ohne Wirkung | Hintergrund rot (negative Logik) |
  | 14 | ohne Wirkung | Hintergrund grün (negative Logik) |
  | 15 | ohne Wirkung | Hintergrund blau (negative Logik) |

  Normalwert in Farbe laut NCR: E8h (Hintergrund schwarz, Vordergrund
  grün). Auf Mono ist E8h ebenfalls richtig, weil dort alle drei
  wirksamen Bits null sind.

  Auf der Monokarte sind die Bits 11–15 wirkungslos, auf der Farbkarte
  ist es Bit 8: die Widerstände R1–R3 und R5–R9 der Baugruppe
  017-0032479-A sind nicht bestückt (Schaltplan 017-0032489, Blatt 5,
  Bestückungshinweis 3). **Die halbe Helligkeit liegt auf beiden Karten
  nicht auf demselben Bit** — auf Mono auf Bit 10, auf Farbe gibt es sie
  gar nicht. Wer ein Attribut im Farbmodell
  zusammensetzt und es auf einer Monokarte ausgibt, bekommt aus
  „halbhell“ ein „invers und halbhell“, und „invers“ (Tausch der
  Farbfelder) wirkt gar nicht. Genau das war bis einschließlich v179 in
  MS-DOS 3.3 der Fall und in DR-DOS 3.41 bis v014 ebenso; sichtbar an Turbo
  Pascal, das den ganzen Schirm grün und gedimmt zeichnete.

  Am 13.10.2026 an den Pixeln nachgemessen und damit belegt: die
  Kopfzeile des Startbildschirms trägt E9h — nur Bit 0 — und erscheint
  in **vollem** Grün invers. Wäre Bit 0 die halbe Helligkeit, müsste sie
  gedimmt sein. Der Turbo-Pascal-Schirm trägt zusätzlich Bit 2 und ist
  dann halbhell. (Eine frühere Fassung dieses Abschnitts schrieb die
  halbe Helligkeit dem Bit 8 zu; das war um zwei Bits daneben. Wer eine
  Emulation danach gebaut hat, prüfe nach: gedimmt wird bei **Bit 10**
  des Wortes.)

  Am 14.10.2026 mit `TEXTTEST.COM` auf beiden Karten durchgemessen. Das
  Programm schreibt unmittelbar über den GDC in den Bildwiederholspeicher,
  der Konsolentreiber ist also nicht beteiligt. Ergebnis: auf Farbe sehen
  E8h/E9h und ECh/EDh gleich aus, auf Mono ergeben E8h bis EFh acht
  unterscheidbare Zustände. In der 8×8-Farbmatrix sind auf Mono genau die
  vier Zeilen gedimmt, deren Vordergrund das Rotbit trägt (rot, gelb,
  magenta, weiß).

  Empfohlene Werte:

  | Zweck | Mono | Farbe |
  |---|---|---|
  | normal | E8h | E8h (grün auf schwarz), FCh (weiß auf schwarz) |
  | invers | E9h | Vorder- und Hintergrundbits tauschen |
  | blinkend | EAh | EAh |
  | gedimmt | ECh | andere Vordergrundfarbe wählen |

  Auf Mono gibt es **kein „intensiv"**: normal ist bereits die höchste
  Stufe, hervorgehoben wird über invers oder über halbe Helligkeit des
  Umfelds. Das Attribut beim Bildschirmlöschen muss das Normalattribut
  sein, sonst leuchtet die ganze unbeschriebene Fläche.

  **Falle: IBM-Attribute auf der DMV.** Software, die PC-Attribute direkt
  schreibt, liefert hier Unsinn, und zwar gerade umgekehrt zur Absicht:

  | IBM | gemeint | DMV Mono | DMV Farbe |
  |---|---|---|---|
  | 07h | hellgrau auf schwarz | invers + blinken + halb | gelb auf weiß |
  | 0Fh | weiß auf schwarz | invers + blinken + halb | weiß auf weiß |
  | 70h | schwarz auf hellgrau | **normal** | blau auf blau |

  07h und 0Fh sind auf Mono nicht unterscheidbar, 70h ist dort das
  Normalattribut. Das gilt für DR-DOS-Werkzeuge und ANSI.SYS-Ersatz
  ebenso wie für eigene Treiber.

  Für ANSI folgt daraus: `ESC [ 7 m` (invers) setzt auf Mono nur Bit 0
  und darf Bit 2 nicht anfassen. `ESC [ 1 m` (fett) hat auf Mono keine
  Entsprechung und bleibt normal, `ESC [ 2 m` (schwach) wird Bit 2.
  Farbbefehle (30–37, 40–47) bleiben auf Mono ohne Wirkung, statt
  ersatzweise Helligkeit oder Inversion zu verstellen.

  **Das Attributbyte muss aus dem Zustand gerechnet, nicht am Byte
  gedreht werden.** Wer „halbhell ein“ als Bitoperation auf dem
  Attributbyte ausführt, verliert sie beim nächsten Farbbefehl, und
  „halbhell aus“ nimmt umgekehrt einer absichtlich gewählten Farbe ihren
  Rotanteil. Der Zustand ist Vordergrund, Hintergrund, invers, blinkend,
  halbhell; daraus entsteht das Byte jedes Mal neu. Auf Farbe wird bei
  invers getauscht und erst **danach** abgedunkelt, damit die Dimmung den
  sichtbaren Vordergrund trifft. In MS-DOS 3.3 ab v181 so gelöst
  (`DMV_MakeAttr`), nachgemessen mit `src/bau/probe_ansi.py`.

  **`ESC [ 6 n` muss beantwortet werden.** Daran — nicht an einem Eintrag
  in der CONFIG.SYS — erkennen Programme, ob die Konsole ANSI kann. Die
  Antwort `ESC [ Zeile ; Spalte R` geht in den Tastaturstrom zurück, als
  wäre sie getippt; die DMV liest Tasten ohne Puffer unmittelbar vom
  8741, es braucht also eine kleine eigene Ablage, die vor dem Baustein
  abgefragt wird. `ESC [ 5 n` wird mit `ESC [ 0 n` beantwortet. Ebenfalls
  ab v181.

  **Blinken blendet nur das Zeichen aus, der Hintergrund bleibt.** Eine
  inverse blinkende Zelle ist in der Dunkelphase deshalb ein voll
  leuchtender Balken, keine dunkle Zelle — „invers + blinken" taugt
  damit nicht zum Hervorheben. In MAME so umgesetzt, an echter Hardware
  noch nicht gegengeprüft.

- Die Helligkeitsstufe ist auf der Farbkarte nicht bestückt (siehe oben:
  R1–R3, R5–R9 der Baugruppe 017-0032479-A) — deshalb bildet NCRs eigener
  Treiber
  (`CRTCODE.INC`, `SHALF_INT`/`RHALF_INT`) sie dort über den Rotanteil
  nach: aus Grün wird Gelb. Das Gehäuse bestätigt die Zweiteilung: Mono
  hat vorne Helligkeit und Kontrast (Lautstärke hinten neben dem
  Tastaturstecker), die Farbmaschine vorne Helligkeit und Lautstärke,
  keinen Kontrastregler.
- Halbe Intensität wird als echte Hälfte modelliert (80h statt FFh) und
  gilt für alles, was in der Zelle leuchtet, Vorder- und Hintergrund.
  Nicht an einen Standardkontrast anpassen.
- Cursor: blinkender Unterstrich, nicht volles Feld.
- Attribute gibt es nur im Textbereich, nicht im Grafikbereich.
- **Der GDC wird im Bereich A0h–AFh über BA0 dekodiert**: gerade Adressen
  sind das Parameterregister, ungerade das Befehlsregister. Ein
  Schreibzugriff mit gesetztem **BA1** lädt zusätzlich den Zoom-Latch
  (74LS175 auf B6, Blatt 5 des Schaltplans 017-0032489). A2h ist also
  kein Spiegel von A0h, sondern A0h *plus* Latch — das Boot-ROM C.07.00
  benutzt ihn, das K235-ROM 33473 nicht. Gedehnt werden dabei nur die
  **Grafikebenen**, und zwar um den Wert des oberen Nibbels plus eins;
  der **Zeichenbereich bleibt ungedehnt**. Für uns folgt: A0h und A1h
  sind sicher, jede ungerade Portadresse oberhalb A1h ist es nicht.
  Waagrechter Zoom ist am 22.10.2026 an einer echten Farb-DMV bestätigt
  (erste Zoomstufe des DMVDEMO, per Video).
- Warnung aus der Dokumentation: keine Video-Timing-Parameter ändern
  (SYNC/VSYNC).
- **Beide Blinktakte kommen aus den CCHAR-Parametern des GDC**, nicht aus
  einer eigenen Zählkette der Karte: der **Cursor** blinkt 2 × BR Bilder
  hell und ebenso lang dunkel, die **Attribute** mit der halben Rate,
  davon drei Viertel der Zeit sichtbar und ein Viertel dunkel. Bei BR 11
  und 56,15 Hz sind das für den Cursor je 0,39 s; der Wert ist per Video
  an einer Mono-DMV bestätigt. A16 des GDC wird dafür **nicht** gebraucht
  — die frühere Annahme, die Karte zähle damit selbst, ist hinfällig.
  Das Attributblinken ist an echter Hardware noch nicht nachgemessen.
- Offen, nur an einer echten DMV zu klären: das Verhalten von invers plus
  blinken in der Dunkelphase; der Pegel der halben Helligkeit (in MAME
  als Hälfte des vollen Pegels modelliert, 80h); die Bildfrequenz der
  Farbkarte (Messung an HSYNC, P113 Pin 8c).

## 8. GSX-Treiber der DMV (DR Draw, GEM)

Auf der Festplatte `615-4-17_fmt20 - Daten` liegen im Verzeichnis
`DRAW86.DMV` mehrere GSX-Bildschirmtreiber nebeneinander:

| Datei | Größe | INT DEh | INT E0h | Maus |
|---|---|---|---|---|
| `DDNCR.SYS` | 11392 | 4× | 7× | ja (Modul auf 30h/31h, Interrupt) |
| `DDNCR.ORI` | 11264 | 4× | 7× | ja |
| `DDDMV2.SYS` | 7680 | 1× | 4× | **nein** |

`DDDMV2.SYS` hat keinen Maustreiber einkompiliert. Sein Quelltext
`DDDMV2.A86` zeigt es: die GSX-Funktion 28 (input locator) holt Zeichen
über `GET_CHAR_NO_ECHO` bzw. `CON_STAT` und schiebt den Grafikcursor mit
Tastencodes (05h/18h/04h/13h für die Richtungen, 17h schaltet die
Schrittweite um). Kein Zugriff auf ein Mausmodul.

`DDNCR.SYS` dagegen installiert einen Interrupt-Handler (EOI an Anschluss
90h) und bedient ein Modul auf 30h/31h — die Steckplatzgruppe IFSEL2.
Dieser Treiber braucht also eine freigegebene Interruptmaske
(Abschnitt 2), und sein Interrupt kommt auf **IRQ2 / INT 0Ah**.

**Offen (Stand 11.10.2026):** Draw8086 bleibt unter DOS 3.3 beim Start
von der Festplatte am Titelbild stehen und reagiert dort weder auf
Return noch auf die Leertaste noch auf die linke Maustaste; von Diskette
läuft es bis ins Menü, unter 2.11 läuft alles (nur Mausklicks brauchen
manchmal viele Versuche). Gemessen ist: alle Überlagerungen und Schriften
(DRAW.001, DRAW.BIN, FONTB.BIN, FONTC.BIN, DRMSG80.TXT) laden sauber von
der Platte, danach dreht das Programm in `INT 21h AH=06h` mit `DL=0FFh` —
der nicht blockierenden Konsolenabfrage. Es ist also kein
Dateisystemproblem. Der eigene Prüfstand des DOS-3.3-Ports stellt den
Unterschied Platte/Diskette nicht nach.

## 9. Maus K806

Die vollständige Schnittstelle (Anschlüsse, Status-Byte, Befehle 00–0A,
Schalterbyte, Jumper) steht in `DMV-Module-und-Anschluesse.md`, Abschnitt 6. Hier
nur, was mit Interrupts zu tun hat:

- Die Leitung ist **`out_int` → IRQ2 → INT 0Ah** (siehe Abschnitt 2),
  nicht IRQ5.
- Ein Interrupt kommt bei **jeder** Bewegung und **jedem** Öffnen und
  Schließen eines Schalters, und die Leitung bleibt aktiv, bis
  **Befehl 03** sie quittiert. Mit dem flankengesteuerten 8259 heißt das:
  ohne Quittierung genau ein Interrupt, danach nie wieder.
- NCRs Anleitung nennt ausdrücklich **zwei** Verfahren: Interrupt *oder*
  Abfrage des INT-Bits (Bit 6) im Status-Byte. Die Maus ist auf einer
  K230/K231 also nicht verloren, sie muss gepollt werden.
- `MAUSTEST.COM` (DOS-3.3-Port) misst das unter DOS 2.11 und 3.30 mit
  demselben Programm: Interrupts je Vektor, Status-Byte, Position,
  Schalter, 8259-Maske, und „stumm“ — wie oft das INT-Bit gesetzt war,
  ohne dass ein Interrupt ankam.

## 10. Wo die Quellen liegen

Alle hier genannten Quellen sind **nicht** im Repo; sie liegen bei
rfka01.

- `DM5SOURC211.zip` – NCRs vollständige MS-DOS-2.11-BIOS-Quellen für die
  DMV: `basinit.asm` (Hardware-Init, Landescodes, Zeichentabellen),
  `iobase.asm` (INT_TRAP, RE_INIT, Gerätekopfzeilen, CRT-Tabellen),
  `crtcode.inc` (Bildschirm, auch Grafikzeichen), `kbdcrt.asm`,
  `kbdcode.inc`, `dskdrv.asm` (auch MEDIAC), `flxpimc.asm`/`flxpimd.asm`
  (765), `widrv5.asm`/`widrv10.asm` (WD1001, auch die Schrittweite),
  `comdrv.asm`, `lpdrv.asm` (K210, Centronics), `timdrv.asm`,
  `config.asm`.
- NCR, Bedienungsanleitung „Maus-Adapter (K806-V001)“, Doc 017-0033170.
- Firmware-Liste des 16-Bit-Teils: Systemhandbuch Anhang A (Boot-Loader
  Level 0 und IO-Driver, mit allen Equates und Adressen).
- Festplatte `615-4-17_fmt20 - Daten`, Verzeichnis `DRAW86.DMV`:
  `DDDMV2.A86`, Digital Researchs Quelltext eines DMV-GSX-Treibers.
- ROM-Images (mono 33609, Farbe 33610, Zeichengenerator 76161,
  8741-Tastatur-MCU u. a.) im Projektarchiv `dmv.zip`.
- MAME-Treiber `ncr/dmv.cpp`, `ncr/dmv_keyb.cpp`, `bus/dmv/k230.cpp`
  (K230/K231/K234/K235), `bus/dmv/k806.cpp` (Maus), `bus/dmv/k210.cpp`,
  `devices/machine/upd765.cpp`, `devices/video/upd7220.cpp`. Für Tests:
  `-slot1 k208` (512 KB), `-slot7a k230` bzw. `k235`; Lua-Taps auf die
  I/O-Ports der CPU-Karte zeigen jeden GDC-, Tastatur- und DMA-Zugriff
  mit Zeitstempel.
