# Module, Anschlüsse und Kabel der NCR DMV

Stand: 13. November 2026. Was in der Maschine steckt und wie es
angesprochen wird: Prozessorkarten, Speicher und seine Grenzen,
Laufwerke, Plattencontroller, der Dekoder auf der Hauptplatine, die
Porttafel, die seriellen Adapter mit ihren Kabeln, Anschluss 13h, die
K806-Maus und der Prüfaufbau in MAME.

Das Dokument hieß bis zum 16.11.2026 `DMV-Module-und-Anschluesse.md` und lag im
Repo `dmv_os`. Es ist dorthin gewachsen, wo die Messungen anfielen –
beim Bau von MS-DOS 3.30 und DR DOS 3.41 –, beschreibt aber die
Maschine und gilt für jeden, der an der DMV arbeitet. Was ausschließlich
die beiden DOS-Ports betrifft (Gerätenamen, serieller Treiber, PRN-
Rückfallebene, DMVMODE), steht weiterhin in `dmv_os/docs/DMV-Serielle-Geraete.md`.

Wo „**festgelegt**“ steht, ist eine Entscheidung der DMV-Projekte
gemeint, keine Eigenschaft der Hardware – sie sagt, worauf unsere
Systeme sich einrichten.

Ergänzt, ersetzt aber nicht:

- `DMV-Hardware-Boot-und-Bildschirm.md` – Vektortabelle, Zeitbasis,
  Firmware-Postfach, Tastatur, GDC, Mono/Farbe, WD1001-Zeitverhalten
- `DMV-Erkennung.md` – was sich automatisch erkennen lässt, je Karte
  und Baustein
- `../Pruefstand/` – die MAME-Aufrufe und der Prüfstand dazu
- `dmv_os/docs/DMV-Datentraeger.md` – Formate, Boot-Kette, Signaturen,
  Partitionierung, private INT-13h-Funktionen
- `dmv_os/docs/DMV-Schnittstellen.md` – was jedes Betriebssystem den
  gemeinsamen Werkzeugen liefert

  liefert

Quellen für die Steckplatz- und Portangaben:

- NCR *System Technical Manual*, Hardware Description, Figure 2.11
  „Interface configuration“, und System Overview S. 1-4, 1-9, 1-10
  (Kit-Beschreibungen, NCR 3282 Winchester Disk Drives); dazu NCR TSC
  Augsburg, System Information HW3 1.1 „NCR 3282 Fixed Disk Interface
  017-0027022 Rev. D“ (06.11.84).
- **Bedienungsanleitungen und Schaltbilder der Module**: Centronics-
  Adapter K210 (Doc 017-0033059, Schaltbild 017-0031554), RS-232-Drucker-
  Adapter K212 (Doc 017-0033061, Schaltbild 017-0031865 — dieselbe
  Platine für K211, K212 und K213), umschaltbarer RS-232-Adapter K801
  (Doc 017-0033070, Schaltbild 017-0032712), gepufferter
  Synchron/Asynchron-Adapter K215 (Doc 017-0033064) samt dem
  beiliegenden Handbuch „NCR DECISION MATE V Schnittstellen-Beschreibung
  (RS 232-C)“. Die Porttafel in der K210-Anleitung ist die vollständige
  Fassung von Figure 2.11.
- **Fotos der K801** (Kit 3273-K801-V001, Teil 603-6091285) vom
  12.10.2026: Gehäuseoberseite mit der Schaltertafel, geöffnetes Gehäuse
  mit Platine und eingestecktem Kabelkonverter, ein Konvertermodul
  einzeln.
- MAME-Treiber `ncr/dmv.cpp` und `bus/dmv/*.cpp` im Fork rfka01/mame.

## 1. Grundgerät

- **Festgelegt:** NCR Decision Mate V, Mono (Mainboard-ROM 33609,
  „M.07.00“) oder Farbe (33610, „C.07.00“). Beide müssen laufen;
  erkannt wird zur Laufzeit (Byte 0FF9h im ROM, siehe
  `DMV-Hardware-Boot-und-Bildschirm.md`).
- **Festgelegt:** Zeichengenerator 76161 mit den DMV-Umlautcodes
  (ae 90h, oe 96h, ue 99h, Ae 80h, Oe 86h, Ue 89h, ß 9Eh).

## 2. CPU-Karte

| Karte | Steckplatz | Merkmal | Unterstützt |
|---|---|---|---|
| K235 | 7A (intern) | 8088/V20 **mit** 8259 auf 90h/91h, ROM 33473 | ja, empfohlen |
| K230 | 7A (intern) | 8088 ohne Interruptcontroller | ja |
| K231 | 7 (extern) | 8088 ohne Interruptcontroller | ja |
| K234 | 7 (extern) | 68008 | nur CP/M-68K, **zusammen mit der K235** (Abschnitt 2a) |

**Festgelegt (revidiert 8.10.2026): K235 empfohlen, K230 und K231
werden unterstützt.** Der 8253 sitzt auf der Hauptplatine, sein
Kanal-2-Ausgang geht aber nur an den Steckplatz der CPU-Karte, und nur
die K235 hängt ihn an einen 8259. Belegt in `bus/dmv/k230.h`: allein die
K235 überschreibt `timint_w`, `keyint_w`, `flexint_w` und die
Steckplatz-IRQs, die Basisklasse der K230/K231 erbt die leeren Stummel
aus `dmvbus.h`. Auf einer K230 erreicht also **kein** Interrupt die CPU,
auch nicht von Tastatur, Diskettencontroller oder Steckplätzen.

NCRs eigenes 2.11-BIOS erkennt die Karte nicht: `basinit.asm` schreibt
8259 und 8253 blind, und `timdrv.asm` führt die Zeit allein im Tick. Auf
einer K230 steht die Uhr dort also ebenso still. Was dort läuft, läuft,
weil alles pollt — die Tastaturabfrage in `basinit.asm`, der FDC in
`flxpimc.asm`, der WD1001 in `widrv10.asm`.

| | auf der K230/K231 |
|---|---|
| Start, Diskette, Platte, Tastatur, Bildschirm | unverändert |
| Diskettenwechsel | über die Wechselleitung, unverändert richtig (Abschnitt 4) |
| Datum | richtig (aus der K803 oder per Abfrage beim Start) |
| Uhrzeit | aus der K803; **ohne** K803 bleibt sie auf dem Startwert stehen |
| INT 1Ch, INT 1Ah AH=0 als Zeitquelle | nicht vorhanden |
| interruptgetriebene Treiber, Maus über Interrupt | nicht möglich; die K806 lässt sich stattdessen pollen |

Die Karte ist damit nicht aus dem Spiel: ein Lader, der sie gar nicht
anfaßt, kann trotzdem nur auf der K235 starten. Der Grund liegt nicht
im Controller, sondern in den **unteren Seiten** — 0400h bis 05FFh
gehört der Firmware, und deren Inhalt unterscheidet sich zwischen der
32167 (K230/K231) und der 33473 (K235/K235+). Verlagerter Ladercode,
der dort versehentlich seine Merker liest, verhält sich darum je Karte
anders (Abschnitt 3, „Verlagerter Ladercode"). Genau daran ist MS-DOS
3.30 auf der K230 bis v226 gescheitert.

- **Festgelegt:** Die Kartenart wird beim Start am Baustein erkannt,
  nicht mit einer Wartezeit: nach ICW1/ICW2/ICW4 ist 91h das
  Maskenregister des 8259, rückschreibbar und rücklesbar; zwei Muster
  (AAh, 55h) sind ein vollständiger Achtbittest, und ohne Karte liest der
  Bus FFh. Keine Verzögerung beim Start, und unabhängig von der Taktrate
  — die K235 trägt einen V20, die K230 einen 8088, beide mit 5 MHz
  (15 MHz / 3).
- **Umgebaute K235 (Homebrew, Maschine B):** Foto vom 27.10.2026 –
  Platine ASSY 017-0033501 A / SCHM 017-0033502 A, ROM 33473, NEC V20
  D70108C-8, Intel C8087-1, D8259AC-2, D8288, Taktgeber 8284A mit einem
  Quarz 22,1984 MHz (Aufdruck nach rfka01) statt 15 MHz. Der 8284A teilt
  durch 3: 7,40 MHz (zuerst als „7,5 MHz“ genannt). Ab Werk gab es die K235
  nur mit 5 MHz. MAME bleibt bei V20 mit 5 MHz. Den tatsächlichen Takt
  misst DMVDIAG (Seite 2, 1600 × AAM gegen 8253 Kanal 2).
  Folge für Software: Zählschleifen um einen AAM laufen auf dieser Karte etwa
  8,3-mal so schnell wie auf einer 8088-Karte mit 5 MHz (V20: AAM 15
  statt 83 Takte, dazu der höhere Takt). Wartezeiten darum nur über den
  8253 oder die K803, nie über Befehlszählung (siehe V20FIX in
  `DMV-Hardware-Boot-und-Bildschirm.md`).
- **Festgelegt:** Ohne Interruptcontroller kommt die Tageszeit aus der
  K803, nicht aus dem Tickzähler. Eine absolute Tageszeit hat kein
  Überlaufproblem und 10-ms-Auflösung statt 55 ms. Mitternacht wird nur
  an einem **großen** Rücksprung erkannt — ein kleiner stammt vom
  Leseversatz, und wer den für Mitternacht nimmt, schiebt das Datum um
  einen Tag vor.
- **Festgelegt:** Der Startbildschirm zeigt die Karte an. K230 und K231
  sind nicht zu unterscheiden (dasselbe ROM 32167, CRC f4a58880; die K235
  hat 33473), angezeigt wird darum K230.
- Umgesetzt im MS-DOS-3.3-Port ab v170 (`DMV_PicProbe` und
  `DMV_RtcTicks` in `BIOS/dmvclk.inc`).

## 2a. 68008-Karte K234 (CP/M-68K)

Quellen: NCR TSC Augsburg, System Information „K234 MC 68008
Processorboard", Schaltbild 017-0033573 Rev. A mit Stiftbelegung
(vom Benutzer am 13.10.2026 beigebracht); J. Zander, „DMV Information
16-Bit System + Interrupt Controller" (28.10.1991) mit NCRs Anhang
„Description of 8088 Interrupt System" (HW2 3.2/3.3, 06.11.84); MAME
`bus/dmv/k230.cpp` (`dmv_k234_device`).

- **Was die Karte ist:** 68008 mit 8 MHz, 8-Bit-Datenbus, kein ROM.
  Speicher linear 0–7FFFFh (512 KB, Bank 0 = Hauptplatine, Bank 1–7 aus
  Steckplatz 1), Anschlüsse speicherabgebildet: Port n liegt beim
  68008 auf **0FFF00h + n**. Steckplatz 7 (extern).
- **Starten:** ein Zugriff auf **D8h–DFh** (lesen oder schreiben) gibt
  den 68008 frei; er liest SSP und PC aus 0–7 des RAM und hält den Z80
  über THOLD/ fest. Jeder Wechsel an **D0h** (Umschaltung 16 Bit) hält
  den 68008 an (MAME: `switch16_w` setzt SNR zurück). NCRs eigenes
  CP/M-68K startet ihn mit `OUT (0DFh),A` aus dem Z80-Lader heraus.
  **Auf echter Hardware nur DFh benutzen:** mit `OUT D8h` lief die K234
  in einem ersten Test nicht an (DMVDIAG 0.15, Maschine A, 29.10.2026),
  mit DFh schon; MAME nimmt D8h–DFh gleich. Unser CP/M-68K startete bis
  v003 mit D8h und hing auf echter Hardware; ab v004 DFh (`P_SNR`).
- **Warum die K235 Pflicht ist:** Zander, Seite 3: wer eine 16-Bit-Karte
  **ohne** Interruptcontroller (K230) hat, kann die K234 nicht
  gleichzeitig betreiben — „Das liegt nicht am fehlenden Interrupt
  Controller"; nötig ist eine Nachverdrahtung mit 7407, 74LS32 und der
  Adressleitung BA3. Daraus: die K230 dekodiert D0h–DFh ohne BA3, ein
  Zugriff auf D8h zum Starten des 68008 schaltet sie mit; die K235
  trennt D0h–D7h (Umschaltung) und D8h–DFh (K234) über BA3, so wie MAME
  es abbildet. **Festgelegt (13.10.2026):** CP/M-68K setzt K234 **und**
  K235 voraus; die K235 ruht im Betrieb.
- **Stiftbelegung** (Pin assignments Processor 68008): b8 TIMINT, b10
  WAITP/, b11 HOLDDMA/, b12 PROCCH/ (= SWITCH 16/), b13 HOLDA16, b17
  16 BIT SET, b20 MEMRQ/, a12 INTAC/, a14 THOLD/, c14 HOLDA, c31 INT/.
- **Interrupts:** Die Karte hat **zwei** Eingänge, TIMINT (Kanal 2 des
  8253, b8) und den Businterrupt INT/ (c31; K803, K804, K806 oder
  umgebaute K211/K212). Ein PAL 20L10 (D7) setzt sie auf die IPL-Leitungen,
  ein PAL 16L8 (D6) an A1–A3 liefert im Quittungszyklus die
  Vektornummer. Tastatur (KEYINT b7) und Diskettencontroller (FLEXINT)
  führt die K234 nicht. MAME bildet keine Interrupts der K234 nach.
  **Gemessen** (K234INT unter NCRs CP/M-68K 1.2, zwei Maschinen,
  26.10.2026, `claude/DMV-Hardwaretest-CPM68K.md` im Projekt):
  - **TIMINT löst beim 68008 keinen Interrupt aus** — weder bei OUT2
    dauernd 0 oder 1 noch bei 100 Hz Rechteck oder Pulsen (beide
    Maschinen).
  - **INT/ kommt auf Ebene 7 mit Vektor A0h** (von der PAL, kein
    Autovektor; Maschine 2, Quelle K803 mit Bit 7 im Adresslatch).
    Ebene 7 ist nicht maskierbar; solange die Quelle steht, kommt der
    Interrupt immer wieder (rund 3500 je Sekunde). Auf Maschine 1 kam
    von der K803 nichts auf INT/ — Ausführung oder Brücke der Karte,
    offen.
  - CP/M-68K arbeitet deshalb weiter ohne Interrupt; ab v004 nimmt ein
    Fänger auf Vektor A0h (und 24, 31) den Interrupt der K803 weg
    (Latch 0) und kehrt zurück.
- **DMA:** HOLDDMA/ und HOLDA16 sind beschaltet, die Karte gibt den Bus
  also an den AM9517 ab. NCRs CP/M-68K benutzt trotzdem keinen DMA,
  sondern den uPD765 im Betrieb ohne DMA (SPECIFY mit ND); unser BIOS
  ebenso.
- **Zusammenarbeit (festgelegt 13.10.2026):** Z80 nur Startlader; der
  68008 macht alles Übrige selbst per Abfrage; die K235 ruht im Betrieb
  und wird später Startprozessor für den Plattenstart (gemeinsamer
  `16BIT`-MBR und Bootmanager; das ROM springt nach der Rückgabe mit
  OUT D0h auf dem Z80 nach 0F111h, dort legt der 8088 vorher ein paar
  Byte Z80-Code ab, die den 68008 starten).
- **Was der 68008 nicht sieht:** das Mainboard-ROM (die Einblendung über
  0000h–1FFFh schaltet der Z80; der Startsektor schreibt die
  Firmwarekennung deshalb nach 20F0h).
- **Der 8259 der K235 ist vom 68008 aus erreichbar** (bis 26.10.2026
  stand hier das Gegenteil). Seine Register hängen am Systembus (IOR/,
  IOW/, A0, D0–D7), das Chip-Select INTCSL/ kommt über b18 von der
  Hauptplatine (Schaltplan 017-0033502); INTA und INT gehen nur an den
  8088. Gemessen auf beiden Maschinen: Maske AAh/55h über 0FFF91h
  zurückgelesen; IRR (ICW1 pegelgesteuert, OCW3 0Ah) zeigt IR0 = OUT2
  des 8253 (TIMINT), IR2 = INT/ (K803 auf Maschine 2), IR5 und IR6
  unter NCRs 1.2 dauernd 1; eine Taste im 8741 setzt IR1 (KEYINT)
  **nicht**. Der 68008 kann so den Zustand der Interruptleitungen
  abfragen, aber nicht als Interrupt bekommen.
- **Startbildschirm der DOS-Systeme:** die K234 bleibt dort ungezeigt
  (`dmv_os/docs/DMV-Startbildschirm.md`), denn vom 8088 aus ist sie nicht messbar.

## 2b. Z8001-Karte K238 (erfunden, CP/M-8000)

Keine NCR-Karte: ein Gegenstück zur K234 mit Z8001, entworfen für
CP/M-8000 (`os/cpm/cpm8000/`). Es gibt sie nur in MAME, Fork rfka01/mame,
Branch `homebrew` (`bus/dmv/k238.cpp`); in `master` und bei MAME selbst
kommt sie nicht vor.

- **Wie die K234:** Steckplatz 7, kein ROM, K235 Pflicht (aus demselben
  Grund wie bei der K234: BA3), Start über D8h–DFh, der Z80 wird über
  THOLD angehalten.
- **Speicher:** Segment n des Z8001 ist RAM-Bank n (Bank 0 Hauptplatine,
  1–7 aus Steckplatz 1); Adresse = Segment × 10000h + Versatz.
- **Anschlüsse:** Die E/A-Befehle des Z8001 gehen unmittelbar an die
  Anschlüsse der DMV (nicht speicherabgebildet wie bei der K234).
- **Start:** Jeder Zugriff eines anderen Busmasters (Z80 oder 8088) auf
  D8h–DFh setzt den Z8001 zurück; er liest seinen Startzustand aus
  Segment 0: Wort 0000h reserviert, FCW bei 0002h (C000h = segmentiert,
  System), PC als segmentiertes Langwort bei 0004h–0007h (z. B.
  00004000h = 0:4000). Wie DMVRACE den 68008 startet, geht also auch hier:
  dieselben acht Byte wie die 8088-Vektoren 0 und 1.
- **Rückgabe:** Ein Zugriff des Z8001 selbst auf D8h–DFh hält ihn an und
  gibt den Z80 frei.
- **Interrupts:** keine; der 8259 der K235 ist von Steckplatz 7 aus nicht
  erreichbar.
- **Was der Z8001 nicht sieht:** das Mainboard-ROM, wie bei der K234.
  Der Startsektor von CP/M-8000 (`boot.z80`, ab v009) kopiert darum die
  neun Byte ab 0FF7h (Zählbyte 8, Kennung wie ` C.07.00`) nach 0:20F0h,
  solange das ROM noch eingeblendet ist; der BIOS liest sie dort für
  BIOS-Funktion 64 (`dmv_os/docs/DMV-Schnittstellen.md`, Abschnitt 9).
  Ab v012 legt CPMLDR dort auch die gemessene Spurzahl ab (0:20FA/20FB
  = Spurart + 1 für A:/B:, 0:20FC = `'D'`), damit CPM.SYS nicht noch
  einmal von Spur 79 rekalibriert.
- **Segmentierter Sprung:** Ein Sprung in ein anderes Segment braucht im
  Programm die Langform (Bit 15 des Segmentworts gesetzt, z. B. 8700h
  0006h für 7:0006); die Kurzform 0700h trägt den Versatz im Segmentwort
  und landet bei 7:0000.

## 3. Speicher

Steckplatz 1, nur ein Modul möglich: K200 (auf 128 KB), K202 (auf
256 KB), K208 (auf 512 KB), jeweils zusammen mit den 64 KB der
Hauptplatine. Die Größe meldet die Firmware in der Mailbox 0:FE06
(Anzahl Erweiterungsbänke).

- **Festgelegt:** Ohne Speichererweiterung startet keins der beiden
  Systeme.
- **DMA in den Erweiterungsbänken:** Der AM9517A gibt nur 16 Adressbits
  aus. Welche 64-KB-Bank er liest oder beschreibt, wählt ein
  Schreibzugriff auf **E0h–E7h** (Bank = Anschluss − E0h); dasselbe
  Register bestimmt, welche Bank der Z80 sieht. Belegt in MAME
  (`dmv.cpp`, `rambank_w`, DMA über `program_r`/`program_w`) und in
  NCRs IO.SYS, dem `os/msdos33/src/SRC/BIOS/dmvdisk.inc` folgt. Wer die
  Bank umschaltet, stellt danach E0h wieder her, bevor der Z80 läuft.
- **Der DMA erreicht nur die unteren 512 KB — gemessen am 13.11.2026.**
  Es bleibt bei **acht** Bänken: BA19 kommt während eines DMA nie auf
  den Bus, und auf E8h–EFh antwortet kein Banklatch. **Blatt 1 des
  Hauptplatinenplans zeigt, warum** (nachgesehen am 13.11.2026):

  - Das Bankregister **H1** ist ein **74LS175** (vier D-Flipflops),
    getaktet von `BSEL/` (Pin 9), zurückgesetzt von `RESET/` (Pin 1).
    Eingänge: **Pin 4 = BA2, Pin 5 = BA1, Pin 12 = BA0**; **Pin 13
    (4D) ist NC**. Ausgänge: Pin 2, 7, 10 führen weiter, **Pin 15
    (4Q) ist NC**, die vier Q̄ (3, 6, 11, 14) ebenfalls. Das vierte
    Flipflop ist an beiden Enden offen — das Register ist
    **dreistellig**.
  - Dahinter sitzt **L1**, ein **74LS126** (Vierfach-Bustreiber),
    dessen vier Freigaben (Pin 1, 4, 10, 13) gemeinsam an `HLDA16`
    hängen, also treiben, sobald der 16-Bit-Prozessor den Bus
    abgegeben hat. Die drei Stellen aus H1 werden zu **BA18** (Pin
    5→6), **BA17** (Pin 2→3) und **BA16** (Pin 9→8). Das vierte
    Gatter treibt **BA19** (Pin 11) — und sein Eingang **Pin 12
    liegt auf Masse**.

  BA19 wird während eines DMA also nicht etwa vergessen, sondern
  ausdrücklich auf 0 gehalten; auf den Bus kommt es nur vom
  16-Bit-Prozessor selbst (J102–J107/J107A a17). Die Grenze sitzt
  damit auf der **Hauptplatine** und ist von keiner Speicherkarte und
  keiner GAL aus zu verschieben. Wer sie aufheben will, muss BA3 an H1
  Pin 13 legen und H1 Pin 15 statt der Masse an L1 Pin 12 — ein
  Eingriff am Mainboard, den ein Betriebssystem nicht voraussetzen
  darf. Aufgefallen ist das mit der 1-MB-Karte
  **K0815** an einer **K235+** (VzEkC, F. Stassen 2025), die dem
  16-Bit-Prozessor **0–FEFFF am Stück gibt, also 1020 KB** — dem Z80
  und dem DMA weiterhin nur 512 KB. Die obersten 4 KB (FF000–FFFFF)
  hält der Speicherdekoder für das EPROM frei; ein Videospeicherloch
  wie beim PC ab A0000 hat die DMV nicht. Nutzbar sind damit 1.044.480
  Byte, und genau das meldet DOS 3.3 seit v209 auch (CHKDSK, echte
  Hardware, 13.11.2026). Der Startbildschirm nannte bis v222 die
  **runden 1024 KB** — er sollte beschreiben, was im Gerät steckt, nicht,
  was DOS davon behält. Am 16.11.2026 umentschieden (rfka01): ab **v223**
  zeigt er die genaue Zahl **1020 KB**, damit Startbildschirm und CHKDSK
  nicht zwei verschiedene Größen nennen. Siehe
  `dmv_os/docs/DMV-Startbildschirm.md`.

  Das ist kein Randfall, sondern bricht den Start sofort: MSINIT legt
  den FAT-Puffer ans **obere Ende des Speichers** (`FatLoc =
  MEMORY_SIZE − FAT-Länge`). Mit 1020 KB liegt er bei 0FEC0h, also in
  Bank 15, und schon die Clusterkette von MSDOS.SYS kommt nicht mehr
  an — die Maschine hängt unmittelbar nach dem Startbildschirm.
  Abhilfe im Treiber: jeden Transfer ab Bank 8 über einen
  Zwischenpuffer unterhalb von 512 KB leiten, wie es `FD_Bounce` in
  `dmvbios.inc` schon für Transfers über eine 64-KB-Grenze tut. Auf
  echter Hardware bestätigt: mit der Umlenkung startet DOS 3.3
  durch und meldet den vollen Speicher.
- **Ende eines DMA-Transfers:** Das EOP/ des AM9517A geht als Terminal
  Count an den uPD765 (MAME `dmac_eop`), zusätzlich setzt ein
  Schreibzugriff auf 12h TC. Ein Lesebefehl mit EOT = R endet damit nach
  dem einen Sektor normal (ST0 = 00h je Laufwerk), nicht mit „End of
  Cylinder“. **Gemessen am 19.11.2026 gilt das auf allen 8088-Karten
  gleichermaßen, auch auf der K230/K231:** 80 Lesebefehle mit EOT = FFh
  sind dort nacheinander normal beendet worden. Eine frühere Fassung
  dieses Absatzes behauptete das Gegenteil, siehe unten.
- **EOT im Lesebefehl: der letzte Sektor der Spur ist die Konvention,
  nicht die Rettung (berichtigt 19.11.2026).** NCRs `flxpimc.asm` von
  DOS 2.11 (`MOV AL,SECTRK / MOV COMSTR+7,AL`), der Bootsektor und
  `dmvbios.inc` setzen EOT alle auf die Sektoren je Spur, und das ist
  auch zu empfehlen: so beendet den Befehl das EOT und nicht erst der
  Terminal Count. **Notwendig ist es aber nicht** — mit EOT = FFh läuft
  der Start gemessen auf K230, K235 und K235+ ebenso. Der Wert steht im
  BPB bei Feld 18h, in der Bootsektorabschrift also bei `0:E018`.

  Diese Zeile stand hier zwischenzeitlich als Kartenunterschied
  („K230 braucht EOT = Sektoren je Spur"). Das war falsch und ist ein
  Lehrstück: der wirkliche Fehler lag in MSLOAD (siehe den nächsten
  Punkt), und **jede** Änderung, die dessen Codelänge um sieben Byte
  verschob, ließ die K230 starten — unabhängig davon, was sie tat. Wer
  am verlagerten Teil eines Laders messen will, muss die Codelänge
  gleichhalten (ein NOP als Ausgleich), sonst misst er die Verschiebung.
- **Verlagerter Ladercode behält die Offsets der Übersetzung — ein
  `cs:Variable` trifft dann die unteren Seiten, und was dort steht,
  hängt von der Prozessorkarte ab (gefunden 19.11.2026).** MSLOAD
  kopiert seinen Diskettencode nach `0:E200` und springt mit CS = 0
  hinein; die Marken darin behalten ihre Offsets aus dem Quellsegment.
  Die beiden Merker für das Doublestepping (Feinheit von Laufwerk und
  Diskette, 48 gegen 96 tpi) wurden dadurch bei `0:0504` und `0:0505`
  gelesen — dicht hinter der Vektortabelle, wo die Firmware ihre Daten
  hält. Sind die beiden Bytes dort verschieden, verdoppelt der Lader
  den Zylinder: er positioniert auf Zylinder 2 und verlangt dann
  Zylinder 1, der uPD765 antwortet mit ST0 = 40h, ST1 = 04h, ST2 = 10h
  (No Data, Wrong Cylinder), und der Lader wiederholt das endlos. Auf
  der K230 waren sie verschieden, auf der K235 gleich — daher sah es
  jahrelang nach einem Kartenunterschied im Controller aus. Der
  Fehlerpfad schrieb zudem in die Firmwaredaten hinein.

  **Für die Hardware heißt das:** wer wissen will, was ein Lader auf
  einer anderen Prozessorkarte tut, muss die unteren Seiten ansehen.
  0400h bis 05FFh ist nicht frei; die Firmware der 16-Bit-Karte legt
  dort ab, und der Inhalt unterscheidet sich zwischen 32167 (K230/K231)
  und 33473 (K235/K235+).

- **Festgelegt (1.11.2026, berichtigt): je System ein eigener
  Mindestausbau — und er ist nicht derselbe.**

  | | Boden | im Lader durchgesetzt? | gemessen |
  |---|---|---|---|
  | **MS-DOS 3.30** | **128 KB** (eine Bank, K200) | **ja**, MSLOAD bricht ohne Erweiterung ab | 131 072 gesamt, **66 992 frei** mit geladenem DMVKEY; das System belegt rund 59 KB |
  | **DR DOS 3.41** | **256 KB** (K202) | **ja**, ab drdos341 v017: Meldung nach dem Startbildschirm, Neustart auf Tastendruck | 196 608 gesamt, 121 120 frei; das System belegt rund 75 KB |

  **192 KB ist kein Ausbau.** Es gibt auf der DMV 64 KB (nur
  Hauptplatine), 128 KB (K200), 256 KB (K202), 512 KB (K208) und 1 MB
  (K0815); 192 KB ist nur der Speicher **auf** der K202. Mit 128 KB
  bleibt DR DOS in BIOSINIT stehen; der kleinste wirkliche Ausbau, mit
  dem es läuft, ist darum die K202 (rfka01, 19.11.2026). Woher die
  196 608 Byte der Messung oben kommen, ist offen.

  **Seit drdos341 v017** prüft das DMV-ROS `0:FE06` nach dem
  Startbildschirm: unter drei Bänken kommt „DR DOS braucht mindestens
  256 KB Arbeitsspeicher (Speichermodul K202 oder K208)“, und ein
  Tastendruck gibt die Maschine an den Z80 zurück wie `REBOOT.COM`
  (Kaltstart). MS-DOS bietet an dieser Stelle den Monitor an. In MAME
  getestet (64 KB: Meldung, Neustart, DR startet erneut von A:).

  **Empfohlen bleiben 256 KB (K202)** für den vollen Softwaresatz — als
  Empfehlung in der Doku, **nicht** als Riegel im Lader.

- **Warum die Festlegung vom 8.10.2026 („256 KB für beide Systeme")
  zurückgenommen ist.** Sie stützte sich auf zwei Begründungen, und
  keine trägt für MS-DOS:

  1. *DR DOS bleibt mit 128 KB in BIOSINIT hängen* — das Startfenster
     für den Kerneldatenbereich liegt dort 64 KB unter dem Speicherende
     (`bdos_r10` in `BIOSINIT.BIO`). Das ist ein Befund über **DR DOS**.
     Unser MS-DOS-Kern wird anders geladen und ist davon nicht berührt.
  2. *DMVRACE braucht etwa 60 KB (plus 16 KB für den 68008), DMVDEMO
     etwa 53 KB* — das sind **Anforderungen von Anwendungen**, und die
     liegen in einem anderen Repo (`dmv_goodies`). Daß ein Demo nicht
     paßt, ist kein Grund, warum das Betriebssystem den Start
     verweigern sollte; ein zu großes Programm sagt das selbst.

  **Am 1.11.2026 in MAME 0.289 nachgemessen** (rfka01): MS-DOS 3.30
  startet mit 128 KB anstandslos und läßt 66 992 Byte frei — genug für
  DMVKEY, DMVSNAP, die DOS-Werkzeuge und DMVDEMO. Kein Eingriff in DRs
  Startablauf; dessen eigener Boden bleibt.

- **Was das Betriebssystem verlangt und was die Programme verlangen,
  sind zwei Zahlen.** Der Lader setzt nur die erste durch. Unterhalb von
  128 KB geht es technisch nicht: `FAT_SEG` ist `1000h`, der FAT-Puffer
  von MSLOAD liegt also ab 10000h und damit auf einer Maschine mit nur
  der Hauptplatine im Leeren. Genau dort bricht MSLOAD ab, zeigt eine
  Meldung und bietet den Monitor an
  (`patches/SRC/BIOS/MSLOAD.ASM.diff`, `M64_*`).

## 4. Diskettenlaufwerke

- **Festgelegt:** Bis zu zwei Laufwerke, A: und B:, jeweils DD
  (40 Spuren, 48 tpi, TEAC FD-55B) oder QD (80 Spuren, 96 tpi, FD-55F).
  Keine HD-Laufwerke. Mit integrierter Festplatte (K012) gibt es nur ein
  Diskettenlaufwerk.
- **Festgelegt:** Zahl **und** Typ der Laufwerke werden per Test
  ermittelt: B: über den FDC (RECALIBRATE, SENSE DRIVE STATUS), die
  Spurzahl jedes Laufwerks durch Rekalibrieren von Spur 79. Ohne Diskette
  bleibt die Spurzahl unbekannt. Keine Konfigurationsdatei, kein SYSDEF.
- **Festgelegt:** Formate DD360, DD720, QD800 in allen Kombinationen;
  40-Spur-Medien im QD-Laufwerk mit Double Stepping, nie mit einfachem
  Stepping.
- **Festgelegt (8.10.2026): der Diskettenwechsel wird an der Hardware
  erkannt, nicht über die Zeit.** Anschluss 13h Bit 3 ist die
  Interruptleitung des µPD765, und der Baustein setzt sie im Leerlauf
  auch, wenn sich die Bereitschaft eines Laufwerks ändert — also beim
  Klappenöffnen und beim Diskettenwechsel (MAME: `upd765.cpp`,
  `run_drive_ready_polling`, alle 1024 µs, ST0 = ABRT | Einheit | NR).
  NCR macht genau das in `MEDIAC` (`dskdrv.asm`): Bit 3 lesen, und wenn
  es steht, einen Merker für **beide** Einheiten setzen (`FLTAB`) —
  welches Laufwerk es war, sagt die Leitung nicht. Ein
  Einlaufwerkssystem meldet immer „weiß nicht“.
  Für MS-DOS 3.30 heißt das: AH=15h meldet 02h („Diskette mit
  Wechselleitung“), DOS setzt daraufhin `fChangeline` und fragt AH=16h,
  statt die Zweisekundenheuristik `CHECK_TIME_OF_ACCESS` zu benutzen, die
  am Tickzähler hängt. **Voraussetzung für den Betrieb auf einer
  K230/K231** (Abschnitt 2). Umgesetzt ab v170.
  Falle dabei: mit gesetztem `fChangeline` deutet `hidensity` in
  `ms96tpi.inc` das Medienbyte F9h als PC-Format 1,2 MB und baut den BPB
  aus Festwerten. Auf der DMV ist F9h das QD800-Format; dieser Zweig muss
  abgeklemmt werden.

## 5. Festplatte

### Was NCR vorsieht (System Technical Manual)

| Ausbau | Modul | Steckplatz | IFSEL / Ports | Einheiten |
|---|---|---|---|---|
| Integrierte Platte | K012 „Integrated Fixed Disk“ | 2A | 4A, C0h–C7h | **1**, im Gehäuse neben **einem** Diskettenlaufwerk |
| Freistehende Platten | Schnittstelle zum NCR 3282 | 2–6 | 4A, C0h–C7h | **bis 3**, in Kette |

- **K012 und 3282 schließen sich aus.** Das Handbuch sagt, die 3282 seien
  für Systeme mit einem oder zwei integrierten Diskettenlaufwerken
  gedacht und ließen sich an Systeme mit integrierter Winchester-Platte
  nicht anschließen. Es gibt also immer nur **einen** Plattencontroller,
  und der liegt fest auf IFSEL 4A (Figure 2.11 zeigt für beide Platten
  nur 4A).
- **Kette:** 3282-0101 = Einzelgerät ohne weiteren Anschluss;
  3282-0102 = erstes Gerät mit Anschluss für ein 3282-0103;
  3282-0103 = Folgegerät mit Anschluss für ein weiteres 0103. Höchstens
  drei Einheiten. Jedes Gerät hat Laufwerk, Netzteil und Lüfter im
  eigenen Gehäuse.
- **NCR 3282 je Einheit:** 10 MB formatiert, 612 Spuren je Einheit,
  17 Sektoren je Spur (einer davon Ersatzsektor), 512 Byte, MFM,
  5 Mbit/s, 8-Bit-Schnittstelle, Motoranlauf 15 s.
- Die Erinnerung des Benutzers an ein externes Gehäuse mit Platz für
  **zwei** Platten passt nicht ganz zu NCRs „ein Laufwerk je
  3282-Gehäuse“ – möglicherweise ein anderes oder umgebautes Gehäuse.
  Für die Einheitenzahl ändert das nichts.

### Was MAME nachbildet

K012 (Steckplatz 2A) und C3282 (Steckplätze 2–6) sind derselbe WD1010
(Gerät `WD1000`) mit IFSEL-Jumper 0A–4A, Vorgabe 4A, und je vier
Einheiten (hdc:0–3). Die Einheit steht im SDH-Register in Bit 3–4. MAME
erlaubt also Ausbauten, die es bei NCR nicht gab: beide Controller
gleichzeitig und eine vierte Einheit.

### Für beide Systeme festgelegt

- **Ein** Plattencontroller, fest auf C0h–C7h (IFSEL 4A).
- **Einheiten 0–2 als HD1–HD3.** MAMEs vierte Einheit wird nicht
  angesprochen. Beide Ports melden über INT 13h AH=08h (DL=80h) dieselbe
  Zahl gefundener Einheiten (das 3.3-IO.SYS meldete bis v168 fest eine).
- Geometrie je Einheit aus dem DMVGEOM1-Block (Zylinder 0, Kopf 0,
  Sektor-ID 1, Kopie auf ID 2), Prüfsumme auswerten.
- **Eine Einheit ohne gültigen DMVGEOM1-Block gilt als nicht
  vorhanden** – kein stiller Rückfall auf 615/4/17.
- **Alt-Platten** (NCR-Originalformat, 2.11-Layouts 5/10/20 MB) werden
  nicht nativ eingebunden; Dateien davon nur über HDIMPORT.
- Höchstens 8 Köpfe (SDH-Kopfnummer 3 Bit), höchstens 1024 Zylinder
  (INT-13h-CHS).
- Controller einmal per Schreib-Lese-Test suchen (55h auf C4h, AAh auf
  C3h, zurücklesen, mehrfach), alle Warteschleifen mit Zeitgrenze; ein
  Controller ohne Laufwerk braucht eine begrenzte READY-Wartezeit. Ohne
  Controller muss das System sauber starten.
- Eingerichtet wird nur über DMVHDFMT (Spuren, DMVGEOM1, Haupt-Bootsatz
  mit `16BIT   `).
- **Festgelegt (8.10.2026): die Schrittweite muss einmal selbst gesetzt
  werden.** Der WD1001 nimmt sie aus dem unteren Nibble von RESTORE und
  SEEK und **behält** sie, auch für die impliziten Seeks bei READ und
  WRITE. Wer nie ein RESTORE schickt, arbeitet mit der Schrittweite des
  letzten vor ihm — beim Start das Z80-ROM, das Haupt-Bootsatz und
  Bootsektor liest; ein Lauf des alten DMVHDFMT stellte sie ausdrücklich
  auf 15 und ließ sie stehen. Bei 15 kostet ein Schritt 7,5 ms, über
  600 Zylinder also viereinhalb Sekunden. Innerhalb einer Partition fällt
  das nicht auf, beim Wechsel des Laufwerksbuchstabens schon: das war die
  beobachtete Pause von vier Sekunden nach „D:“ und nach jedem Befehl,
  der ein anderes Plattenlaufwerk anspricht.
  NCR löst es in `widrv10.asm` mit Buffered Step (Schrittweite 0) und
  schickt ein RESTORE in `GETBPB` bei **jeder** BPB-Abfrage sowie in
  jedem Fehlerzweig. Mindestens einmal beim Finden des Controllers je
  vorhandener Einheit, mit kurzer Bereitschaftsprüfung statt der vollen
  Zeitsperre. Umgesetzt ab v170 (`HD_Strate`).

## 6. Weitere Module

### Der Dekoder auf der Hauptplatine

Aus dem System Technical Manual, Appendix A, Blatt 8 (ausgewertet
8.11.2026). **F7, ein 74LS154**, bekommt als Adresseingänge **nur
BA4–BA7** und wird von `ADEN` und — über B7, ein 74LS00 — von `IOR/`
bzw. `IOW/` freigegeben. Seine sechzehn Ausgänge sind der ganze
Anschlussraum der Maschine, je 16 Adressen:

| Bereich | Ausgang | geht an |
|---|---|---|
| 00–0F | `ERROR/` | Fehleranzeige (Register an BD0–BD7, Dioden CR2) |
| 10–1F | `MULSEL/` | Unterdekoder A4, siehe unten |
| 20–2F | `DMACE/` | 8237 |
| 30–3F | `IFSEL2/` | Steckplatz, Hälften 2A/2B |
| 40–4F | `KBCS/` | 8741 |
| 50–5F | `FDCS/` | 8272 |
| 60–6F | `IFSEL0/` | Steckplatz, 0A/0B |
| 70–7F | `IFSEL1/` | Steckplatz, 1A/1B |
| 80–8F | `TIMSEL/` | 8253 |
| 90–9F | `INTCSL/` | 8259 (auf der K235) |
| A0–AF | `GDCSEL/` | Grafikkarte, über J113 |
| B0–BF | `IFSEL3/` | Steckplatz, 3A/3B |
| C0–CF | `IFSEL4/` | Steckplatz, 4A/4B — dort der Plattencontroller |
| D0–DF | `SWITCH16/` | 16-Bit-Umschaltung, J107/J107A b12 |
| E0–EF | `BSEL/` | Bankregister (74LS175 H1, Blatt 1; nur BA0–BA2 angeschlossen) |
| F0–FF | `(IFSEL5/)` | im Plan als „Reserved“ vermerkt, auf c11 geführt |

**A4, ein 74LS138**, hängt unter `MULSEL/` und unterteilt mit BA0–BA2:

| Port | Ausgang |
|---|---|
| 10h | `RAMSEL/` |
| 11h | `ROMSEL/` |
| 12h | TC setzen (74LS74 A5 → `TC` an den 8237) |
| 13h | `SYSSTAT/` |
| 14h | `MON/` (Diskettenmotor) |

Damit ist die ganze Anschlusstafel schaltplanfest, einschließlich
`OUT 10h` beim Sprung in den Monitor und `TCSET EQU 12h` im
Diskettentreiber.

**Der Anschlussraum ist acht Bit breit, und zwar in der Hardware.**
BA8–BA15 kommen in der Dekodierung nicht vor; jede Portadresse
wiederholt sich deshalb alle 256 Adressen, ein `OUT 1C0h` landet auf
demselben Ausgang wie `OUT C0h`. Das ist Z80-Erbe — bei ihm steht die
Portnummer in A0–A7 —, und die 16-Bit-Karten erben die Anschlusstafel
der Maschine, in die sie gesteckt werden. Die Leitungen fehlen dabei
nicht: Blatt 3 zeigt, dass F15/F16 (zwei 74LS244) **BA0–BA15
vollständig** auf J102–J106 treiben. Eine Karte könnte mehr als acht
Bit für sich auswerten, stünde damit aber allein — die Hauptplatine
antwortet weiter auf jedes Spiegelbild. NCRs eigene Karten gehen eher
in die andere Richtung und dekodieren **weniger** (siehe unten, K210
und die 2651-Platine lassen BA3 brach).

NCR selbst hat damit erst in der **DMV Version II** gebrochen: dort
liegen dieselben fünf Register des 2651 auf 600h, 601h, 604h, 606h und
607h, über DX angesprochen. Der schmale Anschlussraum ist also eine
Eigenschaft der ersten DMV, nicht der Prozessorkarte und nicht des
Betriebssystems. Zum Einordnen: der IBM PC dekodiert selbst nur zehn
Adressbits und spiegelt ab 400h ebenso.

### Die Porttafel

Vollständig aus der Bedienungsanleitung des Centronics-Adapters
(Doc 017-0033059, „NCR-DECISION MATE V Interface Configuration“ — die
lesbare Fassung von Figure 2.11). Die IFSEL-Leitung kommt vom
Steckplatz, die Hälfte aus Adressbit 3:

| Hälfte | Ports | IFSEL-Stift | Modul |
|---|---|---|---|
| 0A | 60h–67h | c28 | K210 / K212 / K213 |
| 0B | 68h–6Fh | c28 | *(von denselben Karten mitbelegt)* |
| 1A | 70h–77h | a28 | K211, alternativ K215 |
| 1B | 78h–7Fh | a28 | *(von der K211 mitbelegt)* |
| 2A | 30h–37h | c27 | K806 (Maus) |
| 2B | 38h–3Fh | c27 | K804 (IEEE 488) |
| 3A | B0h–B7h | a27 | K801 als Plotteranschluss unter p-System |
| 3B | B8h–BFh | a27 | K600 (Decision Net, DMA-Kanal 1) |
| 4A | C0h–C7h | c12 | Festplattencontroller (K012 oder 3282) |
| 4B | C8h–CFh | c12 | K803 (Echtzeituhr MM58167) |

Die K801 ist auf jede der zehn Hälften schaltbar. Ihre Anleitung nennt
als Standardeinstellungen Drucker, Kommunikation und Plotter; im
MAME-Fork steht sie auf 2B.

Notizen der Tafel: jede Portadresse darf im System nur einmal benutzt
werden, und für Plotter ist entweder K213 oder K801 zu verwenden.

**Zwei Korrekturen gegenüber dem Stand bis 11.10.2026:** die K804 liegt
auf **2B** (38h–3Fh), nicht auf 3A, und die K215 auf **1A** (70h–77h),
nicht auf 1B. Beides war früher falsch eingetragen und hatte sich bis in
die Modulerkennung durchgezogen.

### Welche Karten beide Hälften belegen

Das entscheidet sich an Adressbit 3, und die Schaltbilder sagen es
eindeutig:

| Karte | Dekodierung | belegt |
|---|---|---|
| K210 | 017-0031554: `IFSEL0/` (c28) direkt auf `CE/` des 8255, an die Adresseingänge nur `BA1` (a26) und `BA0` (c26). **BA3 nicht angeschlossen.** | 16 Ports, 0A **und** 0B, vierfach gespiegelt |
| K211 / K212 / K213 | 017-0031865: J2 schaltet `IFSEL0/`, J1 schaltet `IFSEL1/`; an den 2651 gehen `A0` (c26), `A1` (a26) und `A2` (c25, auf **R/W**). **BA3 (a25) liegt brach.** | 16 Ports, A- **und** B-Hälfte |
| K801 | 017-0032712: `BD3` (a25) läuft über Schalter S1 in ein 74LS136, die fünf `ISEL`-Leitungen über einen 74LS251 auf `CE/`. Die Karte **vergleicht** Adressbit 3 mit der Schalterstellung. | 8 Ports, genau eine Hälfte |
| K806 | Jumper J6 wählt die A-, J7 die B-Hälfte | 8 Ports, genau eine Hälfte |

Die Tafel zeigt dasselbe: bei „PRINTER 1“ und „COMMUNICATION“ reicht der
Balken von der A- in die B-Spalte, mit der Legende „Software and
Hardware“ für die A- und „Hardware“ für die B-Hälfte. Die K801 hat in
jeder der zehn Hälften einen eigenen, gleich großen Balken.

**MAME bildet das richtig ab** (`k210.cpp`, `k801.cpp`); das ist keine
Vereinfachung, sondern die Hardware. Falsch war nur die Beschriftung der
Steckbrücken — J1 und J2 waren vertauscht, korrigiert am 11.10.2026.

### Die Steckbrücken der 2651-Platine

Eine Platine für drei Module; das Kabel macht den Unterschied, die
Steckbrücke die Adresse:

| Steckbrücke | IFSEL | Modul |
|---|---|---|
| J2 geschlossen | 0 | K212 (Druckerkabel) |
| J1 geschlossen | 1 | K211 (Modemkabel) |
| J2 geschlossen | 0 | K213 (Plotterkabel) |

Auf der Platine sitzen die beiden als steckbarer Block, beschriftet
`PRINTER` und `MODEM`. Mehr Stellungen gibt es nicht: **ein 2651 kann
nur auf IFSEL 0 oder 1 sitzen.**

### Die Schaltertafel der K801, am Gerät abgelesen

Auf der Oberseite des K801-Gehäuses klebt NCRs Einstelltafel. Sie
bestätigt die Schalterdekodierung aus dem Schaltbild Stellung für
Stellung (Fotos vom 12.10.2026):

| Betriebsart | 4 | 2 | 1 | B | Kabelkonv. | ergibt |
|---|---|---|---|---|---|---|
| PRINTER | ○ | ○ | ○ | ○ | 2 | **0A**, 60h |
| COMMUNICATION | ○ | ○ | ● | ○ | 1 | **1A**, 70h |
| PLOTTER (CP/M, MS-DOS) | ○ | ○ | ○ | ○ | 3 | **0A**, 60h |
| PLOT. (UCSD-p) | ○ | ● | ● | ○ | 3 | **3A**, B0h |

(○ = OFF, ● = ON. Kopfzeile der Tafel: „DMV with Z80/8088 — CP/M MS·DOS
UCSD·p“, Schalterspalten „4 2 1 B“, letzte Spalte „CABLE CONV.“)

Die drei linken Schalter tragen die Wertigkeiten 4, 2 und 1 und bilden
die IFSEL-Nummer, der vierte (`B`) wählt die Hälfte — und die vier
dokumentierten Einstellungen landen genau auf den Plätzen, die NCRs
Porttafel nennt: Drucker und Plotter auf 0A neben K210, K212 und K213,
Kommunikation auf 1A neben der K211, und der Plotter unter dem p-System
auf 3A. Damit ist `k801.cpp` an der Hardware bestätigt.

Die Spalte **CABLE CONV.** nennt den passenden Kabelkonverter: 1 für
Modem/Kommunikation, 2 für Drucker, 3 für Plotter.

### Der Kabelkonverter der K801 sitzt IM Gehäuse

Das geöffnete Gerät zeigt, wo die Kabelwahl stattfindet: der Konverter
ist ein kleines Steckmodul auf der Platine, **vor** der Lötleiste TB1, an
der die Adern des festen Kabels hängen. Im fotografierten Gerät steckt
`CC01 — COMMUNIC. MODEM — K801`; das einzeln abgebildete Modul trägt zwei
Kontaktblöcke, beschriftet `PRINTER` und `MODEM`, unter einer weißen
Kunststoffkappe.

**Das ist für die Kabelprobe wichtig:** die Brücke DSR–DTR, die den
Druckerbetrieb kennzeichnet, liegt damit auf dem Konverter und nicht erst
im abgehenden Kabel — also auf der Rechnerseite, wo die Probe sie sieht.
Bei der K801 misst die Probe folglich das **Patchboard**, bei
K211/K212/K213 das Kabel; in beiden Fällen dasselbe Merkmal.

Auf der Platine (NCR 83, Eura Contact 84 10) sitzen ein SCN2651, der
Quarzoszillator COM1101A 5,0688 MHz, ein 74LS251 und ein 74LS136 für die
Adressdekodierung sowie 1488, 1489 und 75188 als Leitungstreiber — alles
so, wie Schaltbild 017-0032712 es zeigt. Der vierfache DIP-Schalter sitzt
unten auf der Platine und ist von außen durch den Gehäusedeckel
zugänglich.

### Festlegungen

| Modul | Zweck | Hälfte | Festlegung |
|---|---|---|---|
| K803 | Echtzeituhr MM58167 | 4B | **Pflicht** (siehe unten) |
| K806 | Maus (8741) | 2A | optional, automatisch erkannt, im Startbildschirm angezeigt |
| K210 | Drucker parallel (Centronics) | 0A (+0B) | **Standard für PRN** |
| K212 | Drucker seriell (RS-232) | 0A (+0B) | serielle Schnittstelle, schließt die K210 aus; bekommt dann PRN |
| K211 | RS-232 Kommunikation | 1A (+1B) | serielle Schnittstelle |
| K801 | RS-232 umschaltbar | wählbar 0A–4B | serielle Schnittstelle |
| K213 | Plotter | 0A (+0B) | nicht Thema |
| K215 | synchron/asynchron gepuffert | 1A | nicht Thema |
| K804 | IEEE 488 | 2B | nicht Thema |
| K600 | Decision Net | 3B, DMA-Kanal 1 | nicht Thema |
| K233 | 16 KB Shared RAM | – | nicht Thema |
| K220 | Diagnosemodul | – | nicht Thema |

- **Festgelegt:** PRN ist standardmäßig die K210.
- **Festgelegt:** Serielle Schnittstellen über K211, K212 oder K801,
  **höchstens zwei**, automatisch erkannt (AUX/COM1 und COM2). Die K210
  und die K212 schließen sich aus — sie liegen beide auf IFSEL 0 und
  belegen dort beide Hälften; die K210-Anleitung schließt den
  gleichzeitigen Betrieb mit K212 oder K213 ausdrücklich aus. Damit
  bleiben zwei steckbare Kombinationen:
  **K210 (0A) + K211 (1A) + K801 (2B)** mit parallelem Drucker, oder
  **K212 (0A) + K211 (1A) + K801 (2B)** mit seriellem.
- **Festgelegt:** K803 gehört verpflichtend zur Zielhardware. Die Systeme
  starten trotzdem ohne Uhr (mit Datumsabfrage), damit ein fehlendes oder
  defektes Modul den Start nicht verhindert.

### K213, K215 und K219 — die drei übrigen seriellen Kits

Alle drei sind für unsere Ports „nicht Thema“, gehören aber
festgehalten, weil sie in NCRs Tafel und in MAMEs Modulliste auftauchen
und beim Suchen sonst jedes Mal neu erarbeitet werden.

**K213 — RS-232-C (Plotter) Peripheral Adapter.** Dieselbe Platine wie
K211 und K212 (Schaltbild 017-0031865, 2651), Steckbrücke **J2** wie bei
der K212, also IFSEL 0 und damit 0A und 0B. Unterschied ist allein das
Kabel. Laut System Technical Manual dient das Kit zum Anschluss eines
kompatiblen Plotters (etwa NCR 5403). Steckplätze 2 bis 6. NCRs Tafel
vermerkt dazu Note 2: entweder K213 oder K801 — die K801 kann die
Plotterrolle übernehmen und tut das unter CP/M und MS-DOS auf 0A, unter
dem p-System auf 3A.

**K215 — gepufferter Synchron/Asynchron-Adapter** (Doc 017-0033064,
Kit-Installation 017-0033166). Steckplätze 2 bis 6, nach der Tafel auf
**1A** (70h–77h). Die Anleitung beschreibt sie als Verbindung zu einem
RS-232C-Modem mit 2 KB Puffer für hohe Übertragungsgeschwindigkeit; das
RS-232-Handbuch fasst sie als K211 für höhere Baudraten zusammen.

Das Kabel ist ein Modemkabel mit **voller** Verdrahtung, einschließlich
der beiden externen Taktleitungen TSET und RSET — die braucht der
Synchronbetrieb, denn dort liefert das Modem den Takt. 25-poliger
Subminiaturstecker Typ D.

Für uns ist die K215 vor allem deshalb interessant, weil **NCRs eigener
Treiber sie erkennt**: `COMDRV.ASM` versucht in `INIT` zuerst eine
gepufferte Schnittstelle zu initialisieren (`IWAITIE`), liest das
Befehlsregister zurück und vergleicht es; stimmt es überein, ist es eine
K215, sonst wird der ungepufferte Zweig genommen. Unsere eigene
Modulerkennung macht diesen Test **nicht** — eine K215 auf 1A würde von
der Moderegister-Probe vermutlich als 2651 gelesen und als K211
angezeigt. Das ist hinnehmbar, solange die Karte nicht zur Zielhardware
gehört; wer sie aufnimmt, muss NCRs Test nachbauen.

Nachtrag 1.11.2026: DMVDIAG ab 0.11 erkennt die K215 über ihren
Echobefehl; auf echter Hardware gefunden (Maschine A, 1A, Antwort 55/AA).
Die K215 hat **keinen Interruptausgang**: ihr Steckplatz zeigt den Pull-up
der K235 (DMVDIAG 0.16, Lauf L2). Als zweite Quelle für das Protokoll
dienen die Treiber des Terminalprogramms ASCOM für K211 und K215 (eine
Diskette aus dem Bestand, Quelltexte von 1983, hier nur ausgewertet): die
K215 liegt dort auf 70h, Daten auf x0, Befehl und Status auf x1;
Statusbit 0 = Antwort liegt bereit, Bit 1 = Eingang belegt (warten);
Befehle 00h Befehlsregister und 01h Modusregister des 2651, 03h dessen
Status holen (Bit 0 Sender frei, Bit 1 Zeichen da), 08h Zeichen lesen,
09h Zeichen schreiben. Das deckt sich mit der Auswertung von V1K215 und
mit der MAME-HLE. Die K211-Fassung derselben Treiber liest auf 70h
(Daten) und 71h (Status) und schreibt auf 74h (Daten), 76h (Modus) und
77h (Befehl) – BA2 unterscheidet Lesen und Schreiben, wie im Schaltbild;
Modus 4Eh, danach 30h–3Fh (interne Takte, Baudrate), Befehl 37h. Alle
diese Treiber fragen den Status ab und benutzen keinen Interrupt.

Eine Fassung von 1987 bedient zusätzlich die **DMV V2**: dieselben fünf
Register des 2651 dort auf **600h, 601h, 604h, 606h, 607h** (16-Bit-
Portadressen über DX), also dieselbe Anordnung in einem größeren
E/A-Raum.

**K219 — integriertes Modem.** Steckplätze 2 bis 6. Das System Technical
Manual nennt zwei unterstützte Modems, Bell 103 (300 Baud) und „Bell
2035“ (1200 Baud) — die geläufige Bezeichnung für das 1200-Baud-Verfahren
ist Bell 212A. Eingebaut sind zwei Buchsen für Telefonstecker, ein Kabel
zum Anschluss eines Telefons liegt bei.

**Die K219 fehlt in NCRs Porttafel.** Die Tafel stammt aus der
K210-Anleitung von 1982/83 und führt sie nicht auf, obwohl sie denselben
I/O-Bus belegt. Welche IFSEL-Hälfte sie nimmt, ist damit **nicht
belegt** — vermutlich eine der seriellen Gruppen, aber das wäre geraten.
Auch MAME kennt sie nicht. Wer eine K219 in die Finger bekommt: die
Hälfte steht auf der Platine, und die Porttafel wäre entsprechend zu
ergänzen.

### Welches Kabel an welchem Adapter

Die vier Adapter tragen dieselbe oder eine sehr ähnliche Elektronik;
**was man anschließen kann, entscheidet das Kabel.** Das RS-232-Handbuch
listet es auf:

| Adapter | vorgesehen für |
|---|---|
| K211 | Modem, Barcodeleser und Ähnliches |
| K212 | Drucker |
| K213 | Plotter |
| K215 | wie K211, für höhere Baudraten |
| K801 | Modem, Drucker und Plotter — das Kabel wird umgesteckt |

Der Unterschied liegt in der Kreuzung. Das **Modemkabel** ist gerade
durchverbunden, Ader für Ader (der Rechner ist DTE, das Modem DCE). Das
**Druckerkabel** ist ein Nullmodemkabel, denn ein Drucker ist selbst ein
DTE — und es tut auf den Steuerleitungen etwas, das man leicht übersieht
(Bild 8 und 9 des RS-232-Handbuchs, am 11.10.2026 Zeile für Zeile
nachgeprüft):

```
DM5 I/F                 PRINTER
TD   ──┐   ┌──────────> 2  TD      gekreuzt
RD   ──┘   └──────────> 3  RD
RTS  ──┐   ┌──────────> 4  RTS     gekreuzt
CTS  ──┘   └──────────> 5  CTS
DSR  ──┐                6  DSR ──┐
LGRD ──┼──────────────> 7  LGRD   │  im Stecker
CD   ──┼──────────────────────────┘  zusammengelegt
DTR  ──┘  im Stecker    20 DTR ───┘
          gebrückt
```

Also: **auf der Rechnerseite sind DSR und DTR im Stecker gebrückt**, und
das DSR des Druckers kommt gar nicht als DSR an — Drucker-DSR und
Drucker-DTR liegen zusammen auf der Rechnerleitung **CD**. Die
Bereitmeldung eines Druckers mit DTR-Handshake (so auch der Epson EX-800)
erscheint also auf CD, nicht auf DSR. Im Schaltbild der Platine (Bild 8)
sieht man dieselbe Brücke zwischen TBI-2 (DTR, rote Ader) und TBI-7
(DSR, violett), und TBI-11 (CD) geht auf Stecker-Pin 20.

Bei der K801 ist diese Wahl als **steckbarer Block** ausgeführt, auf der
Platine mit `PRINTER` und `MODEM` beschriftet.

#### Damit ist das Kabel messbar

Die Brücke DSR–DTR liegt auf der Rechnerseite, also lässt sie sich von
Software nachweisen: DTR im Befehlsregister abschalten, Status lesen, DTR
einschalten, Status wieder lesen. Folgt das DSR-Statusbit dem DTR-Bit,
steckt ein Druckerkabel. Beim Modemkabel kommt DSR von der Gegenstelle
und bleibt unberührt.

- **Nachweisbar ist nur die Brücke.** Ein Stecker ohne Brücke kann ein
  Modemkabel sein, ein unbeschaltetes Kabel oder gar keins. Das Ergebnis
  heißt darum „Druckerkabel“ oder „unbekannt“, nie „Modemkabel“.
- **Die Messung läuft genau einmal**, beim Suchen der Kanäle, bevor die
  Karte scharfgemacht wird. Danach wird DTR nie wieder angefasst: ein
  Modem an der Leitung legt beim Fallen von DTR auf.
- **Ein Gerät, das DSR selbst zieht, täuscht nichts vor** — es müsste DSR
  im selben Augenblick wie unser DTR schalten. Darum wird auf beide
  Zustände geprüft und nicht bloß auf den zweiten.
- **MAME bildet die Kabel nicht nach**: dort zieht jedes rs232-Gerät DSR
  fest, die Probe meldet also immer „unbekannt“. Im eigenen Prüfstand ist
  das Kabel seit v175 nachgebildet (`Modul(art, 'drucker')` und
  `Modul(art, 'modem')` in `dmvsim.py`).

Umgesetzt im MS-DOS-3.3-Port ab v175 (`DMV_AuxProb` in
`BIOS/dmvaux.inc`, Ergebnis je Kanal in `DMV_AuxKab`).

### Interrupts der seriellen Adapter

Das RS-232-Handbuch hat dazu einen eigenen Abschnitt („3.2 V.24
Interface wird interruptfähig K211/K212“), und der sagt etwas
Unerwartetes: um bei einem empfangenen Zeichen einen Interrupt
auszulösen, muss die Schaltung leicht geändert werden. Gezeigt wird eine
Leiterbahn, die aufgetrennt und über ein zusätzliches Gatter auf
**c31 (INT/)** gelegt wird.

Gemessen (DMVFRAGE, 1.11.2026, zwei Maschinen): an der K211 löst nur
**RxRDY** die Leitung a2 aus – ein Byte über die Rückschleife des 2651
schon, das Einschalten des Senders (TxRDY, TxEMT) nicht. Die K801 meldet
dagegen über TxRDY. Die folgende Lesart des Handbuchs ist damit für TxRDY
widerlegt:

Ab Werk führen RxRDY und TxRDY der K211/K212 also nur auf **P1-a2**, die
steckplatzabhängige IRQ-Leitung — das ist in MAME `out_irq`, und auf der
K235 landet sie je nach DIP-Schalter auf IRQ3, 4, 5 oder 7. Die Leitung
`busint` (c31, in MAME `out_int`, immer IRQ2) erreicht die Karte erst
nach dem Umbau.

Die K801 hat laut ihrem Schaltbild (017-0032712) **beide**: ein 74LS136
treibt `IRQ` nach P1-a2 **und** `INT` nach c31. In MAME zieht sie nur
`out_irq`; wer die K801 im Interruptbetrieb braucht, sollte das prüfen.

### Gerätenamen, serieller Treiber, DMVMODE

Hierher gehörten bis zum 16.11.2026 fünf Abschnitte, die nicht die
Hardware beschreiben, sondern was die DOS-Ports daraus machen:
Gerätenamen und Zuordnung von PRN/LPT und AUX/COM, der serielle Treiber
`dmvaux.inc`, die serielle Rückfallebene für PRN, die beiden eigenen
IOCTL-Unterfunktionen und DMVMODE statt MODE, dazu AUX und Drucker unter
CP/M-68K. Sie stehen jetzt in `dmv_os/docs/DMV-Serielle-Geraete.md`.

### Anschluss 13h, Systemstatus

Belegung aus dem System Technical Manual, Appendix A, Blatt 8: **F12,
ein 74LS244**, freigegeben von `SYSSTAT/`. Die Eingänge von D7 nach D0
sind `IDX`, `IRQ2`, `IRQ3`, `IRQ4`, `FLEXINT`, `FDCRDY`, `16 BITAV/`
und `MOTOR/` — Bit für Bit das, was `dmv.cpp` (`sys_status_r`) und
NCRs Gebrauch in `flxpimc.asm` und `dskdrv.asm` nahelegten:

| Bit | Bedeutung |
|---|---|
| 7 | Indexloch der Diskette (am Gerät nicht bestätigt) |
| 6 / 5 / 4 | IRQ 2 / IRQ 3 / IRQ 4 – die eigene Leitung (a2) von Platz 2 / 3 / 4, aktiv 1; gemessen mit DMVFRAGE, Platz 5/6 haben kein Bit |
| 3 | Interrupt des Diskettencontrollers (**live**, nicht gespeichert) |
| 2 | Laufwerk bereit |
| 1 | 16-Bit-Prozessor vorhanden (negiert) |
| 0 | Diskettenmotor läuft |

Polarität nach MAME (`sys_status_r`, `floppy.cpp`): Bit 2 ist **1, wenn
das Laufwerk bereit ist** (Motor dreht, Indexlöcher gezählt); Bit 0 ist
**1, wenn der Motor steht** – der Nachlauf (8253 Kanal 0, gestartet von
jedem Schreibzugriff auf 14h) ist abgelaufen –, und 0, solange er läuft.
Ein Treiber, der nach dem Einschalten auf Bit 2 = 0 wartet, hängt.

Eine frühere Notiz nannte Bit 2 „Transfer“ und Bit 3 „Seek complete“ —
beides falsch.

**Bit 2 ist die READY-Leitung des Kabels, also die des angewählten
Laufwerks.** Blatt 5 zeigt den Weg: `READY/` kommt auf **J110 Pin 34**
herein, mit 150 Ω (RR6) gegen +5 V, und wird vom **74LS240 D6** —
invertierend — zu `FDCRDY`. Dasselbe Signal geht an den RDY-Eingang des
8272 und an F12. Auf dem Shugart-Bus treibt diese Leitung das jeweils
angewählte Laufwerk; ein bestimmtes Laufwerk fragt man dagegen mit
SENSE DRIVE STATUS ab, ST3 Bit 5.

*Korrektur vom 8.11.2026:* Hier stand bis dahin „Bit 2 zeigt nur
Laufwerk A“ — das beschrieb nicht die Maschine, sondern einen Fehler in
`dmv.cpp`, wo `sys_status_r` unbesehen `m_floppy0` las. Behoben in
rfka01/mame (Zweige `master` und `homebrew`, 7.11.2026); die Anwahl
kommt jetzt über `us_wr_callback()` des 8272.

Beide Laufwerke hängen am selben Motorsignal, zählen ihre Indexlöcher
aber selbst; B: wird bis zu eine Umdrehung (200 ms) später bereit als
A:. Wer nach dem Anlauf nur auf Bit 2 wartet und dann B: anspricht, ist
zu früh — siehe `DMV_Wait` und `FD_WaitRdy` in `dmvbios.inc` ab v205.

**Bereit-Meldungen des µPD765:** Im Leerlauf fragt der Controller die
Laufwerke ab; wird eines bereit (oder nicht mehr), legt er einen eigenen
Interrupt mit **ST0 = C0h + Laufwerk** an (MAME `upd765.cpp`,
`run_drive_ready_polling`; so auch im Datenblatt, „Polling“). Kommt
diese Meldung während RECALIBRATE oder SEEK, holt SENSE INTERRUPT sie
**zuerst** ab – sie ist nicht das Ende der Bewegung. CP/M-68K bis v004
nahm sie dafür und las auf B: zu früh: beim ersten Anmelden „Disk select
error“, der zweite Versuch ging (MAME, 30.10.2026). Ab v005 wartet der
BIOS nach dem Anlauf 250 ms länger, überliest Meldungen mit
ST0 = C0h-Muster beim Warten auf SEEK/RECAL und fasst beim Anmelden
einmal nach.

### K806: die vollständige Schnittstelle

Aus NCRs Bedienungsanleitung „Maus-Adapter (K806-V001)“, Doc 017-0033170,
ergänzt am 11.10.2026 um die **Disassemblierung der Firmware** (8741A,
ROM 33378, CRC 2163737A). Das Modul hat einen eigenen Mikroprozessor und
schafft bis zu 4000 Positionen je Sekunde. Es benutzt die **ersten zwei**
Anschlüsse seiner IFSEL-Gruppe, auf der Vorgabe 2A also 30h (Port 1) und
31h (Port 2):

| | |
|---|---|
| `IN` Port 1 | Datenbyte vom Modul lesen |
| `OUT` Port 1 | Parameter an das Modul senden |
| `IN` Port 2 | Status-Byte lesen |
| `OUT` Port 2 | Befehl an das Modul senden |

Status-Byte: Bit 0 OBF (ein Datenbyte liegt bereit), Bit 1 IBF
(Eingangspuffer voll — vor jedem Schreiben abwarten), Bit 4 ROM-Fehler,
Bit 5 RAM-Fehler, Bit 6 INT (Interrupt steht an, **active high**;
Befehl 03 löscht es, ROM 070h).

**Bit 2 und Bit 3 sind nicht unbenutzt**, anders als die Anleitung sagt.
Beim UPI-41 kommen die unteren vier Statusbits aus der Hardware: Bit 2
ist F0, das die Firmware setzt, sobald sie ein Mausereignis verarbeitet
hat (ROM 180h), und am Ende jedes Befehls löscht (061h); Bit 3 ist F1 und
trägt das Adressbit 0 des letzten Schreibzugriffs — genau daran
unterscheidet die Firmware Befehl und Parameter (022h).

Befehle (hexadezimal, an Port 2):

| | |
|---|---|
| 00 | absolute Position lesen → X low, X high, Y low, Y high, Schalterbyte |
| 01 | Interrupt bei Bewegung anerkennen (schaltet 06 aus) |
| 02 | Interrupts aus |
| 03 | Interruptleitung und INT-Bit zurücksetzen |
| 04 | logische Position setzen (vier Parameter) |
| 05 | XMAX/YMAX setzen (vier Parameter) |
| 06 | Interrupt bei Schalterbetätigung (schaltet 01 aus) |
| 07 | beide Interruptquellen anerkennen |
| 08 | ROM prüfen |
| 09 | relative Position lesen (Parameter wie 00) |
| 0A | XMIN/YMIN setzen (vier Parameter) |

Schalterbyte: Bit 0 = S1 (links), Bit 1 = S2 (rechts), Bit 2 = S3
(Mitte); gesetzt heißt gedrückt. Vorgaben beim Einschalten: XMAX 640,
YMAX 400, XMIN 0, YMIN 0, Position 0/0, alle Interrupts aus (Tabelle im
ROM bei 31Dh). Absolute und relative Position liegen in **denselben**
Registern — wer beides braucht, führt die absolute Position selbst mit
und schreibt sie mit Befehl 04 zurück.

**Drei Eigenheiten der Firmware, die man beim Programmieren wissen
muss:**

1. **Ein Befehl mitten in einer laufenden Ausgabe bricht sie ab.** Die
   Ausgabe der fünf Positionsbytes prüft nach jedem Byte, ob inzwischen
   ein Befehl eingetroffen ist, rückt den Stapelzeiger von Hand zurecht
   und springt in die Befehlsauswertung (ROM 055h, 05Ch). Wer aus einem
   Interruptbehandler heraus Befehl 03 schickt, während die Hauptschleife
   die Position abholt, bekommt die restlichen Bytes nie. Die Abfrage muss
   gegen den Behandler gesperrt werden, und nach einem Abbruch muss der
   Ausgabepuffer leergelesen werden, sonst liest die nächste Abfrage um
   eine Stelle versetzt. Das ist die wahrscheinliche Erklärung für die
   unzuverlässigen Mausklicks unter GSX.
2. **Die Firmware erzeugt keine zweite Flanke.** Sie lässt eine schon
   gezogene Leitung unverändert (17Eh); nur Befehl 03 gibt sie frei. Am
   flankengesteuerten 8259 der DMV gibt es ohne Quittieren also genau
   **einen** Interrupt.
3. **Während ein Befehl abgearbeitet wird, pollt die Firmware P1 nicht**
   — Bewegungen in dieser Zeit gehen verloren. Dasselbe gilt für eine
   Encoderflanke, die zeitgleich mit einem Tastenwechsel auftritt (16Bh).

Wichtig für die Kartenfrage: die Anleitung nennt für den 16-Bit-Betrieb
zusätzliche Interrupt-Controller als unerlässlich — bietet aber **zwei**
Verfahren an, Interrupt *oder* Abfrage des INT-Bits im Status-Byte. Die
Maus ist auf einer K230/K231 also nicht verloren, sie muss gepollt
werden.

Jumper: J1 bis J5 wählen IFSEL 0 bis 4, J6 die A-Hälfte und J7 die
B-Hälfte (Vorgabe 2A = J3 + J6). J8/J9/J10 offen für Hawley Mark II und
Alps Encoder, geschlossen für Depraz; unterstützt ist auch die Logitech
LM-P-5.

## 7. Tastatur und Bildschirm

- **Festgelegt:** 8741-Tastatur, Landescode über `OUT 41h,1`; die
  deutsche Tastatur sendet ISO-646-Codes, die auf die DMV-Umlaute
  umgesetzt werden. Kein ALT, Ctrl-F20 ist Kaltstart der
  Tastaturhardware (Software tut nichts).
- **Festgelegt:** 80 × 25 Zeichen über den µPD7220, Konsole verhält sich
  wie ein ADM-3A (dazu NCR-ESC-Folgen und eine ANSI-Teilmenge).

## 8. Prüfaufbau in MAME

Referenz für beide Ports:

```
mame dmv -slot1 k208 -slot7a k235 -slot2a k012 -slot4 k803 -hard1 <platte.chd>
```

Laufwerke DD bzw. QD je nach Test. Für den Start ohne Festplatte
`-slot2a` weglassen. Für die Kette der 3282 statt `-slot2a k012` die
C3282 in einen der Steckplätze 2–6, Einheiten 0–2. Drucker und serielle
Karten (`k210`, `k211`, `k801`) in die übrigen Steckplätze.

Für die serielle Seite wird das Gerät am Unterslot `rs232` gewählt:

```
mame dmv -slot7a k235 -slot2 k806 -slot3 k803 \
         -slot4 k211 -slot4:k211:rs232 auto3a \
         -flop1 DMV_v174_360.IMG
```

- `auto3a` ist ein ADM-3A mit **Autobaud** — es lernt die Rate aus dem
  ersten Zeichen und spielt die gepufferten Zeichen nach. Das passt, weil
  unter DOS nie `AH=0` aufgerufen wird (MSAUX ruft nur 1, 2, 3) und die
  Schnittstelle damit auf dem steht, was die Modulerkennung hinterlässt:
  8N1, 9600 Baud.
- `ex800` ist der Epson EX-800, der seit dem 11.10.2026 parallel **und**
  seriell druckt — damit lässt sich die serielle Druckerseite an K212 und
  K801 prüfen, ohne Umweg über Socket und `-bitb`.
- `printer` und `rs_printer` schreiben nur in eine Datei und brauchen
  dafür eine Zuweisung im File Manager.
- Alle rs232-Geräte ziehen DSR, DCD und CTS aktiv — die DSR-Falle aus
  Abschnitt 6 greift dort also nicht.

#### Autobaud: wann `auto3a` einrastet

`auto3a` rastet auf dem **ersten** Verkehr ein und bleibt dort:
`m_locked` wird allein in `device_reset` gelöscht, ein Reset der Maschine
(F3) ist also die einzige Art, es neu lernen zu lassen. Wer mit DMVMODE
eine andere Rate einstellen will, muss das **vor** dem ersten Zeichen
tun:

```
DMVMODE COM1:1200,N,8,1
COPY AUTOEXEC.BAT AUX:
```

Das Einrasten erfolgt 250 ms nach der letzten Flanke, und der
aufgefangene Schwung wird nachgespielt — die erste Zeile geht nicht
verloren. Rahmen und Parität liest `auto3a` aus demselben Schwung, auch
`COM1:1200,E,7,1` ist damit ein gültiger Test.

Gerastet wird auf 110, 150, 300, 600, 1200, 2400, 4800, 9600, 19200,
38400, 57600 und 115200. Die Zwischenstufen des 2651 — **50, 75, 134,5,
1800, 2000, 3600 und 7200** — kennt das Terminal nicht und schnappt sie
auf einen Nachbarn; das ist dann das Terminal, nicht der Treiber.

MAMEs Teilertabelle stimmt im Übrigen Nibble für Nibble mit der des
Bausteins überein (`scn_pci.cpp`, `s_br_divisors_3` für 5,0688 MHz, von
SCN2651 **und** SCN2661C benutzt). Einzige Unsauberkeit ist 19200:
Teiler 16 ergibt rechnerisch 19800 Baud, 3 % zu schnell — `auto3a`
schnappt das auf 19200, es funktioniert also trotzdem.

#### Das Druckerkabel in MAME nachbilden

MAME bildet Kabel nicht nach. `null_modem` zieht DCD, DSR und CTS
**fest** (in `update_serial`, mit einem TODO-Vermerk, das konfigurierbar
zu machen) und gibt auf DTR nichts zurück — die Kabelprobe meldet dort
also „unbekannt“, und das ist richtig: ein Nullmodemkabel zu einem
Gegengerät ist kein DMV-Druckerkabel. Der `ex800` legt sein BUSY auf
**DSR und CTS** und zieht DCD dauerhaft; er druckt damit, zeigt aber
ebenfalls keine Brücke.

Nachbilden lässt es sich mit der **Patchbox** (`patchbox.cpp`, Option
`patch` in `default_rs232_devices`). Sie hängt sich zwischen Anschluss und
Gerät und wählt für jede Leitung die Quelle; zwei Einstellungen ergeben
das NCR-Druckerkabel:

| Einstellung | Wert | entspricht |
|---|---|---|
| `DSR Source (V.24 107)` | **DTR** | die Brücke im Stecker auf der Rechnerseite |
| `DCD Source (V.24 109)` | **DSR** | Drucker-DSR und -DTR liegen zusammen auf CD |

```
mame dmv -slot7a k235 -slot3 k803 \
         -slot4 k212 -slot4:k212:rs232 patch \
                     -slot4:k212:rs232:patch:dce ex800 \
         -flop1 DMV_v175_360.IMG
```

Die Quellen stehen unter **Tab → Machine Configuration** und werden in
`cfg/dmv.cfg` gesichert. Danach meldet DMVMODE „Drucker“, und die
Bereitmeldung des EX-800 kommt auf CD an — genau der Zweig, auf den der
Treiber mit nachgewiesenem Druckerkabel wartet. Zu beachten: die Probe
läuft **einmal** beim ersten Zugriff, ein Umstellen im laufenden Betrieb
wirkt erst nach einem Reset.

Wer nur die Probe selbst prüfen will, ohne Drucker: `loopback` brückt DTR
auf DSR und DCD (und RTS auf CTS, TxD auf RxD) und meldet damit
„Drucker“, nimmt aber keine Zeichen an.

**Die Tastatur muss umgehängt werden.** MAME verteilt einen Tastendruck
**nicht** an alle emulierten Tastaturen gleichzeitig — es ist immer nur
eine aktiv. Nach `CTTY AUX:` kommt also nichts im Terminal an, solange
die DMV-Tastatur die aktive ist. Umgestellt wird unter **Tab → Input
Settings → Keyboard Selection**; dort steht jede Tastatur mit ihrem
Gerätepfad und lässt sich einzeln auf Enabled oder Disabled setzen:

```
Generic Keyboard [root:slot2:k211:rs232:auto3a:keyboard]   Enabled
```

Also die DMV-Tastatur auf Disabled, die des Terminals auf Enabled.
Zurück führt `CTTY CON` im Terminal und dasselbe Menü in umgekehrter
Richtung. Die Tastatur des Terminals ist US-belegt (ANSI oder JIS, in der
Machine Configuration umstellbar): Y und Z sind vertauscht, und Umlaute
gibt es nicht.

Im Fork rfka01/mame steht die K801 ab Werk auf IFSEL 2B; die Hälfte
gehört nach NCRs Tafel eigentlich der K804, ist aber in jeder Maschine
ohne IEEE-488-Karte frei, und 3A und 3B wären gleichwertig. Vorher stand
sie auf 0A, im Konflikt mit der K210. Der MM58167 der K803 hält sein RAM
(Jahr, Monatsvermerk) als NVRAM über MAME-Neustarts.

## 9. Offene Entscheidungen im Überblick

Derzeit keine.

Erledigt am 12.10.2026: Schaltertafel der K801 am Gerät abgelesen und
die Schalterdekodierung damit bestätigt; Kabelkonverter sitzt im Gehäuse
vor TB1, die Probe misst also bei der K801 das Patchboard; `null_modem`
zeigt in MAME keine Brücke, mit der Patchbox lässt sich das Druckerkabel
aber nachbilden; Einrastverhalten von `auto3a` festgehalten.

Erledigt am 11.10.2026 (Abend): Kabelprobe (DSR folgt DTR heißt
Druckerkabel) und damit die Erkennung des Patchboards; PRN und LPT1
fallen ohne K210 auf eine serielle Karte zurück; zwei eigene
IOCTL-Unterfunktionen im Druckertreiber; DMVMODE.COM als Ersatz für
MODE.COM. Alles ab v175.

Erledigt am 11.10.2026: Porttafel und Adressdekodierung an den
Schaltbildern belegt (K210 017-0031554, K211/K212/K213 017-0031865, K801
017-0032712); K804 auf 2B und K215 auf 1A berichtigt; Spiegelungsprobe
auf IFSEL 0 und 1 beschränkt, Namenstabellen je Hälfte; serieller Treiber
`dmvaux.inc` für K211/K212/K213/K801 (ab v173); K806-Firmware
disassembliert; K213, K215 und K219 dokumentiert.

Erledigt am 8.10.2026 (Abend): K230 und K231 werden unterstützt (K235 nur
noch empfohlen), Kartenerkennung am Maskenregister des 8259, Uhrzeit ohne
Controller aus der K803; Diskettenwechsel über Anschluss 13h Bit 3 statt
über die Zeit; Schrittweite des WD1001 einmal selbst setzen;
K806-Schnittstelle vollständig belegt.

Erledigt am 8.10.2026: Mindestausbau 256 KB (K202) — **am 1.11.2026
zurückgenommen, siehe Abschnitt 3: 128 KB für MS-DOS, 192 KB für DR DOS,
256 KB nur noch als Empfehlung**; Laufwerkszahl und
-typ per Test; HD1–HD3 an einem Controller auf C0h; K012 und 3282
schließen sich aus; Alt-Platten nur über HDIMPORT; PRN = K210; bis zu
zwei serielle Schnittstellen (K211/K212/K801) automatisch erkannt; K803
Pflicht; K806 optional und automatisch erkannt. Gerätenamen und Zuordnung
von PRN/LPT und AUX/COM (A1, B1, C1, siehe Abschnitt 6); serieller
Drucker nur über AUX/COM1/COM2. Modulerkennung nach `ros_ifprobe` jetzt
in beiden Ports (MS-DOS 3.3 ab v169).
