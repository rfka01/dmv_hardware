# Was sich an der DMV automatisch erkennen lässt – und was nicht

Stand: 27.10.2026. Grundlage: DMVDIAG 0.01–0.11, die NCR-Diagnose-
disketten (DIAGDSK, DIAG232), der Schaltplan der Hauptplatine (System
Technical Manual, Anhang A), MAMEs Kartenmodelle (`src/devices/bus/dmv`,
Fork rfka01/mame) und die Messungen auf zwei echten Maschinen.

Dieses Dokument entscheidet, was künftig der Startbildschirm und die
Betriebssysteme **selbst messen** und was aus einer **gespeicherten
Konfiguration** kommen muss.

## 1. Die Grundregel

**Auf dem Steckplatzbus der DMV beweist Lesen allein nichts.** Zwischen
lokalem Datenbus und BD0–BD7 sitzt ein 74LS245 ohne Pull-ups. Ein
leerer Steckplatz liefert den zuletzt getriebenen Wert – meist ein Byte
aus dem Befehlsstrom. Das war die Ursache der Scheinkarten (K210 und
K804 auf dem ersten Foto). MAME liefert dort FFh und hat den Fehler
verdeckt.

Eine Karte gilt daher erst als erkannt, wenn **ein Register sich
verhält wie das Register eines bestimmten Bausteins**: schreiben, mit
anderem Buswert dazwischen zurücklesen, alten Wert wiederherstellen.
Jeder Baustein braucht dafür sein eigenes Verfahren. Reines Lesen mit
wechselndem Buswert (DMVDIAG Seite 4) trennt „offen" von „belegt",
benennt aber nichts.

Zweite Regel: **Die Lage benennt keine Karte.** Mehrere Karten teilen
sich IFSEL-Hälften (K211, K215 und K216 liegen alle auf 70h), und
mehrere Karten sind frei einstellbar (K801, K803, K806).

## 2. Übersicht

**Stand:** H = auf echter Hardware belegt · M = in MAME geprüft ·
P = nur im Prüfstand/am Code · – = noch nichts.
**Eingriff:** L = nur lesen · S = schreibt und stellt wieder her ·
A = aktiv (Kopf bewegt sich, Prozessor startet, …).

### Sicher erkennbar

| Was | Verfahren | Eingriff | Stand |
|---|---|---|---|
| Firmware, Mono/Farbe | Kennung 0FF7h + CRC-32 des 8-KB-ROMs | L | H |
| Mono/Farbe unabhängig | Ebenenprobe GDC 3FF0h/7FF0h | S | M |
| 8088 oder V20 | PUSH imm8 und AAD 16 | L | H (beide Richtungen, PITTEST) |
| 8087 | FNINIT, FNSTSW/FNSTCW, (CW AND 103Fh) = 003Fh | L | H |
| K235 gegen K230/K231 | 8259-Rücklesung **und** CRC des Karten-ROMs | S | H (8259), M (CRC) |
| CPU-Takt | 1600 × AAM gegen 8253 Kanal 2 | L | M (5,00 MHz) |
| Speicherbänke, K200/K202/K208 | Muster je Bank, erst alle schreiben, dann lesen | S | P |
| Landescode der Tastatur | 8741-Befehl 01h | L | H |
| Spurzahl von A: | `FE08`/`FE09` des Z80-ROMs (READ ID auf phys. Zyl. 2 beim Start) | L | P (am ROM-Code) |
| K234 / K238 | Z80 über Warteplatz F111h, OUT DFh (wie NCRs CP/M-68K), zweisprachige Sonde, Rückgabe über FFFDFh | A | H (DMVDIAG 0.16, K234 auf beiden Maschinen: Sonde 36, Z80-Marke 5A) – braucht K235. Mit OUT D8h (DMVDIAG bis 0.15) lief die K234 in einem ersten, unsystematischen Test auf echter Hardware nicht an (Maschine A, 29.10.2026) |

### Erkennbar mit eigenem Bausteintest (noch zu bauen)

| Karte | Baustein | Lage | Verfahren | Eingriff | Stand |
|---|---|---|---|---|---|
| K211/K212/K213 | SCN2651 | nur IFSEL 0 oder 1, A und B gespiegelt | Befehlsregister: x3 lesen, 23h und 03h über x7 schreiben, über x3 zurück, alten Wert zurück (NCRs Verfahren, RS232D6.ASM); xB antwortet gleich = gespiegelt (DMVDIAG 0.11, Taste S) | S (DTR/RTS zucken kurz) | H (DMVDIAG 0.16, beide Maschinen) |
| K801 | SCN2661 | jede Hälfte (Schalter) | wie 2651, aber nur eine Hälfte antwortet (die K801 vergleicht BA3) | S | H (DMVDIAG 0.16, 2B) |
| K210 | 8255 | nur IFSEL 0, viermal gespiegelt | **x3 ist beim 8255 nicht lesbar** (schwebt!). Steuerwort AAh wie NCRs Treiber, PC0–PC2 wie vorher, dann INTE A (PC6) setzen/löschen; Statusbit 6 von Port C folgt. Port A nie schreiben (Zeichen an den Drucker) | S (INIT-Puls möglich) | H (DMVDIAG 0.16) |
| K806 | 8741 (UPI-41) | jede Hälfte (J1–J7) | Statusbit 3 (F1) zeigt Adressbit 0 des letzten Schreibens – Hardware des UPI; dann Befehl 00h → genau fünf Datenbytes | S | H (MOUSETST) |
| K803 | MM58167 | jede Hälfte (Schalter), Vorgabe 4B | Register nur über **x4–x7** (Latch auf x0); ein RAM-Register beschreiben und zurücklesen; Sekunden laufen | S | H (PITTEST liest CEh) |
| K216 | Z8530 SCC | Vorgabe 70h–73h, vier Anschlüsse je Viertel (Abschnitt 5) | WR12/RR12 (Zeitkonstante) schreiben und lesen, wie NCRs V1K216 (55h/AAh) | S | – (keine Hardware) |
| K804 | µPD7210 | Vorgabe 2B | acht lesbare Register; ADR0 schreiben, zurücklesen | S | – |
| K215 | 8741 (UPI-41), 2651, 2 KB RAM | Vorgabe 70h (V1K215: 70 78 30 38 B0 B8 C8) | Ruhestatus x1 = 00h (08h mit F1); Befehl 0Bh (Echo) an x1, Byte an x0, Antwort an x0 (Abschnitt 6) | S | H (Maschine A, 1A, 55/AA; Befehlssatz zusätzlich durch ASCOM-Treiber belegt, siehe DMV-Module-und-Anschluesse.md) |
| Plattencontroller K012/C3282 | WD1001-Art | 4A, C0h–C7h | C2h/C3h schreiben und zurücklesen | S | P |
| Platteneinheiten 0–2 | | | SDH je Einheit, **mit Warten** auf BUSY=0, READY | L | P |
| Plattengeometrie | | | DMVGEOM1 lesen (ein Sektor) – Angabe, keine Messung | L | M |
| K233 | Kippstufe auf 7Eh/7Fh | 1B | Muster bei C000h, kippen, prüfen, zurückkippen; neben K211: deren x3 lesen und auf 7Fh zurückschreiben (DMVDIAG 0.10, Seite 3, Taste K; Abschnitt 4) | S | M (keine Hardware) |
| Tastatur Synth-Firmware | 8741 | – | Status AND C4h = C0h, dann Befehl 05h + Unterbefehl, Antwort mit Zeitgrenze (DMVRACE) | S | M/upi41 |

### Nur bedingt oder gar nicht erkennbar

| Was | Warum | Ausweg |
|---|---|---|
| **Spurzahl ohne Diskette** | RDY des 8272 hängt am READY des Laufwerks: ohne Diskette kein Schritt (Schaltplan; MAME ebenso) | A: aus `FE08`; B: mit eingelegter Diskette (DMVDIAG Taste B) oder Konfiguration |
| **Zahl der Laufwerke ohne Diskette** | Der 8272 kennt keine Anwesenheit; READY braucht eine Diskette. ST3 Spur 0 ist nur ein Hinweis (Kopf steht meist auf 0, ohne Laufwerk ist die Leitung hochgezogen) | Konfiguration – so hat es NCR gemacht (CONFIG: „Number of Flex Disks") |
| K230 gegen K231 | elektrisch gleich, gleiches ROM | „K230/K231" |
| K212 gegen K213 | gleiche Platine, nur das Kabel unterscheidet; nachweisbar ist nur die Druckerkabel-Brücke (DSR folgt DTR) | „K212/K213" bzw. „2651 auf IFSEL 0" |
| K211 gegen K215/K216 auf 70h | nur über den Baustein (2651 / UPI / SCC) trennbar | Bausteintest |
| K223, K219 | keine Hardware, keine Registerbeschreibung (K223: Anschlüsse 30h, 31h, 39h, 3Ah, 3Bh aus V1K223) | vorerst „unbekannt" |
| K600 | Register unbekannt; belegt IFSEL 2 und 3, DMA-Kanal 1, INT/ | nach den Platinenfotos |
| K234 bei K230/K231 | die K230/K231 nimmt D8h als D0h | Probe sperren, „unbekannt" |
| **MAME: 40-Spur-Diskette im QD-Laufwerk** | MAMEs upd765-Formate legen Spur n auf Schritt n, auch im 84-Schritt-Laufwerk. Echte Hardware braucht dort Doppelschritt; in MAME liest READ ID auf Schritt 2 die Kennung C=2 (DMVDIAG 0.08 meldete darum „40-Spur-Werk"), und FE08 bleibt 0 | Vorschlag für den Fork: `dmv_dsk` verteilt 40-Spur-Abbilder im QD-Laufwerk auf die geraden Schritte |
| Laufwerk A: von einer 80-Spur-Startdiskette | FE08 ist dann 0 trotz 80-Spur-Werk; FE09 = 3 (QD) verrät es | Regel: FE09 = 3 → 80 Spuren |

## 3. Was daraus folgt

1. **Die Erkennung wird ein gemeinsames Modul** (in rfka01/dmv_goodies, `dmvdiag/`), das
   je Baustein den Test oben ausführt und Rohwert plus Urteil ablegt.
   DMVDIAG zeigt es, die Startbildschirme der Systeme rufen es auf.
2. **Beim Systemstart nur, was nichts bewegt und nichts startet:**
   ROM, CPU, 8087, Karte, Mono/Farbe, Bänke, Tastatur, A: aus FE08,
   Bausteintests an den IFSEL-Hälften, Plattencontroller und -einheiten.
   Nicht beim Start: K234/K238-Probe, Laufwerksschritte, K233.
3. **Was nicht messbar ist, kommt aus einer Konfiguration**: Zahl der
   Diskettenlaufwerke und Spurzahl von B:, Kartenname bei mehrdeutiger
   Lage (K212/K213), K223/K219/K600 bis zu einer Registerbeschreibung.
   Die Konfiguration schreibt ein Werkzeug (Messung, wo sie geht, dazu
   Fragen an den Benutzer), nicht der Startvorgang.
4. **Jeder Bausteintest wird zuerst in DMVDIAG mit Rohwerten gebaut** und
   auf beiden Maschinen mit bekannter Bestückung fotografiert, bevor er
   in die Systeme wandert.

## 4. K233 im Einzelnen

Quellen: Schaltbild der K233 und der Hauptplatine, NCRs Testprogramm
V1K233 (DIAGDSK), MAMEs `k233.cpp`.

- **Umschalten:** eine Kippstufe, getaktet von Schreibzugriffen auf
  **7Eh und 7Fh** (PAL-Term „WR7EH/+WR7FH/"); V1K233 schaltet nur mit
  `OUT 7Fh`. Nach RESET aus. MAME kippt bei **jedem** Schreiben auf
  70h–7Fh – damit schaltet in MAME jeder Zugriff auf eine K211 die K233
  mit um.
- **Schreiben:** Die Karte zieht TRAMD/. Auf der Hauptplatine sperrt das
  nur die Ausgabe des RAM (über B12/F2 an OE/ des Ausgaberegisters F4),
  nicht das Schreibsignal des DRAM. Eingeschaltet geht jedes Schreiben
  also **in Karte und Hauptplatine**. Dazu passt, dass V1K233 C000h–FFFFh
  vorher nach 8000h rettet und danach zurückkopiert. MAME schreibt nur in
  die Karte.
- **Fenster:** C000h–FFFFh. In MAME für den Z80 in jeder Bank (wie V1K233
  es prüft, Bänke 0–3), für den 8088 nur in `0000:C000`–`0000:FFFF`. Die
  PAL der Karte sieht BA16–BA19; ob das Fenster für den 8088 auch in
  `n:C000` erscheint, ist offen.
- **Erkennung (DMVDIAG 0.10):** `[C000]` retten, kippen, 5Ah schreiben,
  kippen, A5h schreiben und lesen („aus"), kippen und lesen („ein"),
  3Ch schreiben, kippen und lesen („durch"), `[C000]` zurück. Karte da,
  wenn „aus" = A5h und „ein" = 5Ah. „durch" = 3Ch heißt: Schreiben geht
  auch in die Hauptplatine; A5h heißt: nur in die Karte. Ohne Karte
  zeigen alle drei den zuletzt geschriebenen Wert. Gekippt wird mit
  `OUT 7Fh`; damit eine K211 dort nichts Neues bekommt, schreibt die
  Probe genau den Wert zurück, den 7Bh liest (Befehlsregister des 2651).
  Während die Karte an ist: CLI, kein Firmwareaufruf (Postfach und
  Firmwarevariablen liegen unter dem Fenster).
- **Automatisch (DMVINFO ab 1.03, 6.11.2026):** nur, wenn auf 7Fh nichts
  Fremdes hört – IFSEL 1B frei (die K233 selbst antwortet beim Lesen
  nicht), oder ein 2651/2661 dort (K211-Gruppe auf IFSEL 1, K801 auf
  1B) mit dem Rückschreiben über 7Bh. Eine 8741-Karte (K215, K806) oder
  Unbekanntes auf 1B: „nicht prüfbar“. In MAME getestet, auf echter
  Hardware unbestätigt.
- **Steckplatz:** Die K233 schließt keine Platzleitung an, ihr Platz
  meldet mit der K235 also dauernd (wie ein leerer). Am besten auf den
  Platz, dessen Leitung nirgends hinführt: bei S1 = Platz 5 ist das
  Platz 6, bei S1 = Platz 6 Platz 5. Der Konfigurator schlägt das so vor.
- **MAME-Fork:** seit 27.10.2026 (master und homebrew) kippt die Karte
  nur auf 7Eh/7Fh, und beim Schreiben schreibt die Hauptplatine mit.
  Das Fenster für den 8088 ist unverändert (nur `0:C000`).

## 5. K216 im Einzelnen

Quelle: NCR System Information HW1 9.1–9.4 (06.11.84), Schaltbild
017-0033564 Rev. B.

- **Baustein:** Z8530 SCC, zwei Kanäle. Takt PCLK vom Bus (A15); Quarz
  und Teiler auf der Karte sind „nicht bestückt".
- **Lage:** ein 25LS2521 vergleicht BA2/BA3 mit S1-1/S1-2, die IFSEL-
  Leitung wählt S1-4 bis S1-8. Die Karte belegt also **vier Anschlüsse**
  in einem Viertel einer IFSEL-Gruppe (Tabelle 0A1 = 60h–63h … 4B2 =
  CCh–CFh; 1A1 = 70h–73h). Andere Karten im übrigen Teil der Gruppe sind
  damit möglich.
- **Register:** BA0 → C/D̄ (über 74LS08), BA1 → A/B̄ (über 74LS04):
  x0 = Kanal A Steuerung, x1 = Kanal A Daten, x2 = Kanal B Steuerung,
  x3 = Kanal B Daten (aus dem Schaltbild abgeleitet, nicht gemessen).
- **Interrupt:** INT des SCC über Transistor V7 auf INT/ (C31), INTACK/
  vom Bus (A12), IEI fest auf +5 V.
- **MP/M-Betrieb** (Brücken MPM/MPM/ und S1-3 bei V001, S2-1…3 bei
  V002): Laut Schaltbild verbindet die Brücke MPM den Ausgang des
  Treibers für TRxCB (Kanal 2, TRXCS2) mit dem Eingang TRxCA (Kanal 1,
  statt TRXCR1); MPM/ trennt TRXCS2 vom Stecker. Kanal B liefert dann
  einen Takt an Kanal A – vermutlich der Zeittakt für MP/M. Wozu S1-3
  dient, ist im Schaltbild nicht zu erkennen. Dass MP/M die K216 als
  Zeitgeber und die K233 als gemeinsamen Speicher nimmt, ist eine
  Vermutung.
- **Erkennung:** WR12/RR12 schreiben und lesen (wie NCRs V1K216) an x0
  bzw. x2; MAME hat keine K216.

## 6. K215 im Einzelnen

Quellen: NCRs Testprogramm V1K215 (DIAGDSK, Version 001), Fotos der Platine von rfka01
(27.10.2026) und die Seiten A-1-90/A-1-91 der Hardware Reference.
Das ROM des 8741 ist noch nicht ausgelesen.

- **Platine:** Bestückung 017-0032782 D, Schaltbild 017-0032792 B,
  FCC-ID CTD7YSNCR3273K215. Intel D8741A mit NCR-Firmware 32905,
  USART SCN26x1 (Aufdruck teils verdeckt; die Registerwerte in V1K215
  passen zum 2651), HM6116 (2 KB statisches RAM), Quarzoszillator
  5,0688 MHz, 74LS244/LS05/LS32/LS175/LS377/LS02, SN75188 und ein
  Empfänger (vermutlich 75189), ICL7660 für die negative Spannung.
- **Busstecker (A-1-90):** BD0–BD7, IOR/, IOW/, RESET/, **BA0 und
  BA3**, IFSEL0/–IFSEL4/, PERC/, AUTO/, IDSEL/ – **kein INT/**: die
  Karte unterbricht nicht.
- **Lage (A-1-91):** Steckbrücken J1 wählen IFSEL und Hälfte; die Karte
  belegt acht Anschlüsse (z. B. 70h–77h). Da nur BA0 ankommt, liegt das
  Datenregister des 8741 auf allen geraden, Befehl/Status auf allen
  ungeraden Anschlüssen der Hälfte.
- **Anschlüsse:** Daten an x0, Befehl (schreiben) und Status (lesen) an
  x1. V1K215 bietet 70h (Vorgabe), 78h, 30h, 38h, B0h, B8h und C8h an;
  60h/68h sind „für den Drucker“, C0h „für die Platte“ reserviert.
- **Status** wie bei jedem UPI-41: Bit 0 = Ausgabepuffer voll (Antwort
  an x0 abholen), Bit 1 = Eingabepuffer voll (warten), Bit 3 = F1 (A0
  des letzten Schreibens). Eine ruhende Karte liest 00h; V1K215 sucht
  sie so auf der Vorgabeadresse. DMVDIAG nimmt 00h oder 08h.
- **Befehle** (alle, die V1K215 benutzt):

  | Befehl | Bedeutung |
  |---|---|
  | 00h + Byte | Befehlsregister des 2651 |
  | 01h + Byte | Moderegister (MR1, dann MR2) |
  | 03h | Status des 2651; Bit 1 = Empfangspuffer nicht leer |
  | 07h + Byte | SYN1/SYN2 (Synchronbetrieb, V1K215: 32h) |
  | 08h | ein Zeichen aus dem Empfangspuffer |
  | 09h + Byte | ein Zeichen senden |
  | 0Bh + Byte | Echo (Bustest von V1K215 mit 55h und AAh) |
  | 10h | Selbsttest: 0 = gut, 1 = USART, 2 = 2-KB-Puffer, sonst Prozessor |

- **USART:** Die Registerwerte (Befehl 27h/32h/A3h/A7h, Modus
  6Eh/35h und 6Eh/3Fh, synchron 0Ch/3Ah) sind die eines 2651.
- **Puffer:** Der Puffertest von V1K215 schickt 0800h Bytes über den
  Rückschleifstecker und liest sie danach zurück.
- **MAME-Fork:** `bus/dmv/k215.cpp` bildet genau diese Befehle nach
  (HLE bis zum Auslesen des 8741; SCN2651 mit 5,0688 MHz,
  2-KB-Empfangspuffer, IFSEL-Schalter, Vorgabe 1A, acht Anschlüsse mit
  Spiegelung über BA0, F1 im Status). Weitere Befehle echter Software fehlen. In MAME
  getestet: V1K215 mit Rückschleifstecker (RS-232-Option `loopback`)
  meldet alle neun Tests „OK“.
- **MAME, K233:** NCRs V1K233 meldet mit der berichtigten K233 alle
  Tests „OK“; DMVDIAG zeigt „Schreiben geht auch in die Hauptplatine“.

## 7. Offene Messungen, die die Tabelle bestätigen oder kippen

- DMVDIAG 0.08 Taste T: kommt ohne Diskette wirklich „nicht bereit"?
- Anschluss 13h Bit 7: IRQ0 (Schaltplan) oder Indexloch (`hw/dmvhw.def`)?
- Tastaturstatus Bit 7 bleibt nach 01h stehen (in MAME gesehen) – auch
  auf echter Hardware?
- Spurzahl von A: aus FE08 gegen die Aufschrift der Laufwerke.
- Steckplatzbelegung beider Maschinen, Karte für Karte, mit Jumpern.
