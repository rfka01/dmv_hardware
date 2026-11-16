# DMV Hardware

Firmware, hardware knowledge and the test bench for the **NCR Decision Mate V** (DMV) · Firmware, Hardwarewissen und Prüfstand für die **NCR Decision Mate V**

The machine itself, not the software that runs on it: new firmware for its controllers, the utility that configures it, and what everyone working on the DMV needs in order to test. Operating systems are in [dmv_os](https://github.com/rfka01/dmv_os), applications and demos in [dmv_soft](https://github.com/rfka01/dmv_soft), [dmv_games](https://github.com/rfka01/dmv_games) and [dmv_goodies](https://github.com/rfka01/dmv_goodies). · Die Maschine selbst, nicht die Software darauf: neue Firmware für ihre Controller, das Werkzeug zum Einstellen, und was jeder braucht, der an der DMV arbeitet und prüft. Betriebssysteme stehen in dmv_os, Anwendungen und Demos in dmv_soft, dmv_games und dmv_goodies.

| | |
|---|---|
| [`EXTKB/`](EXTKB/) | Extended firmware for the keyboard controller on the motherboard: key click on/off/faint tick, tick instead of the power-on beep while a key is held, three-voice synthesizer with noise, race benchmark – tested in MAME, not yet on real hardware · Erweiterte Firmware für den Tastaturcontroller auf dem Motherboard: Tastaturton an/aus/leiser Knack, Knack statt Einschaltpiep bei gehaltener Taste, dreistimmiger Synthesizer mit Rauschen, Rennwerk – in MAME getestet, auf echter Hardware noch nicht |
| [`K235FW/`](K235FW/) | Firmware 2.4 for the K235 and K235+ 16-bit modules: faster memory test up to 1 MB (K0815), monitor without password, terminal operation via K211 – tested in MAME, not yet on real hardware · Firmware 2.4 für die 16-Bit-Module K235 und K235+: schnellerer Speichertest bis 1 MB (K0815), Monitor ohne Passwort, Terminalbedienung über K211 – in MAME getestet, auf echter Hardware noch nicht |
| [`Keyclick/`](Keyclick/) | Utility KEYCLICK ON/OFF/LOW for DOS, CP/M-80, CP/M-86 and CP/M-68K – the tool that configures EXTKB, which is why it lives next to it · Utility KEYCLICK ON/OFF/LOW für DOS, CP/M-80, CP/M-86 und CP/M-68K – das Einstellwerkzeug für EXTKB, deshalb liegt es daneben |
| [`Pruefstand/`](Pruefstand/) | Test bench for MAME: command lines per configuration, a Lua harness that dumps the screen as text and types to a schedule, tools for hard disk images – and the pitfalls that cost everyone half an hour · Prüfstand für MAME: Aufrufe je Ausbaustufe, Lua-Prüfstand mit Bildschirmabzug als Text und Zeitplan, Werkzeuge für Festplattenabbildungen – und die Fallen, die jeden eine halbe Stunde kosten |

Software that uses this firmware · Software, die diese Firmware benutzt:
[SYNDEMO](https://github.com/rfka01/dmv_soft/tree/main/SYNDEMO) (synthesizer demo and programming interface · Synthesizer-Demo und Programmierschnittstelle) and · und
[DMVTRAK](https://github.com/rfka01/dmv_soft/tree/main/DMVTRAK) (MOD player and tracker · MOD-Player und Tracker), both in `dmv_soft`.

Hardware facts – ports, ROM behaviour, timing, keyboard codes, GDC – are documented in [dmv_os/docs](https://github.com/rfka01/dmv_os/tree/main/docs) for now. · Hardwarefakten – Anschlüsse, ROM-Abläufe, Zeitverhalten, Tastaturcodes, GDC – stehen bis auf weiteres in dmv_os/docs.

This repository was called `dmv_firmware` until November 2026; the history goes back to it. · Dieses Repo hieß bis November 2026 `dmv_firmware`; die Historie reicht dorthin zurück.

## License · Lizenz

MIT License, see [LICENSE](LICENSE).

---

Code: Claude (Anthropic) · Prompts: rfka01
