# Was die DMV ist und wie sie sich verhält

Gemessenes und aus Schaltbildern Belegtes über die NCR Decision Mate V.
Diese Dokumente gelten für jeden, der an der Maschine arbeitet – Firmware,
Betriebssysteme, Anwendungen –, und gehören deshalb hierher und nicht in
eins der Softwarerepos.

| Dokument | Inhalt |
|---|---|
| [DMV-Hardware-Boot-und-Bildschirm.md](DMV-Hardware-Boot-und-Bildschirm.md) | Vektortabelle, Zeitbasis 8259/8253, Boot-Übergabe Z80→8088, Firmware-Postfach, Tastatur (8741), GDC µPD7220, Mono und Farbe, Zeitverhalten des WD1001 |
| [DMV-Module-und-Anschluesse.md](DMV-Module-und-Anschluesse.md) | Prozessorkarten (K230/K231/K234/K235/K238), Speicher und die 512-KB-Grenze des DMA, Laufwerke, Plattencontroller, der Dekoder auf der Hauptplatine, Porttafel, serielle Adapter und ihre Kabel, Anschluss 13h, K806-Maus, Prüfaufbau in MAME |
| [DMV-Erkennung.md](DMV-Erkennung.md) | Was sich zur Laufzeit erkennen lässt und was nicht – je Karte, Baustein und Verfahren, mit dem Stand der Belege |
| [messungen/](messungen/) | Rohdaten: Tastencodes beider Maschinen, Abzüge der Scanreihen |

Nebenan liegt [`../Pruefstand/`](../Pruefstand/): die MAME-Aufrufe,
der Prüfstand und die Werkzeuge für Festplattenabbildungen.

**Eine Änderung an der Hardwarebeschreibung gehört in denselben Commit
wie der Befund.** Wer in einem anderen Repo etwas misst, trägt es hier
ein und nennt den kurzen Hash dieses Commits drüben im Commit-Text.
Sonst stehen die Fakten in einer Sitzung und sind in der nächsten weg.

## Was anderswo steht

- `dmv_os/docs/DMV-Schnittstellen.md` – was die Betriebssysteme den
  gemeinsamen Werkzeugen liefern (IOCTL, INT 13h, BIOS-Funktionen)
- `dmv_os/docs/DMV-Datentraeger.md` – Diskettenformate, Boot-Kette,
  Signaturen, Partitionierung
- `dmv_os/docs/DMV-Bootmanager.md`, `dmv_os/docs/DMV-Startbildschirm.md`,
  `dmv_os/docs/DMV-Serielle-Geraete.md` – Entwürfe und Festlegungen der DOS-Ports
- `dmv_os/hw/dmvhw.def` – die Konstanten in Maschinenform; sie werden
  aus dem DOS-Bau erzeugt und bleiben vorerst dort
