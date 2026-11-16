-- dmvtest.lua -- Pruefstand fuer die NCR DMV in MAME
--
-- Eingebunden wird die Datei mit dofile(), danach stehen bereit:
--
--   screen(name)   Bildschirminhalt (80x25) als Text in die Ausgabedatei
--   key("TEXT\n")  Tastatureingabe ueber natkeyboard
--   escdown()/escup()   Esc, das natkeyboard NICHT uebertraegt
--   plan{ {t,fn}, ... } Ablaufplan: fn wird bei Maschinenzeit t aufgerufen
--   say(text)      eigene Zeile in die Ausgabedatei
--
-- Ausgabedatei: $DMVOUT, Vorgabe /tmp/dmvtest.txt
--
-- Aufruf (Beispiel: Start von Platte am K012):
--
--   ./dmv dmv -slot1 k208 -slot2a k012 -slot7a k235p \
--        -hard1 DMV_HD_v221.chd \
--        -video none -sound none -nothrottle -seconds_to_run 90 \
--        -skip_gameinfo -autoboot_script mein_test.lua
--
-- DREI FALLSTRICKE, jeder hat eine halbe Stunde gekostet:
--
--  1. OHNE -seconds_to_run drosselt MAME auf Echtzeit, auch mit
--     -nothrottle und -video none. Mit der Angabe laeuft es hier rund
--     sechsmal so schnell. Die Zahl muss groesser sein als die letzte
--     Zeitmarke im Plan.
--  2. Der Rueckgabewert von emu.add_machine_frame_notifier MUSS in einer
--     globalen Variablen liegen. Sonst raeumt der Sammler ihn weg und der
--     Plan laeuft nie an - ohne Fehlermeldung.
--  3. Der Adressraum des GDC heisst "videoram", nicht "data", und die
--     Adresse ist der Zeichenindex, nicht der Byteversatz.
--
-- Code: Claude (Anthropic), Idee und Prompts: rfka01. Lizenz: MIT

mac = manager.machine
local gdc = mac.devices[":upd7220"]
vsp = gdc.spaces["videoram"]

OUT = io.open(os.getenv("DMVOUT") or "/tmp/dmvtest.txt", "w")
function say(s) OUT:write(s .. "\n") OUT:flush() end

-- Zeichen-RAM der DMV: ein Wort je Zeichen, Zeichen im unteren Byte.
-- Nicht druckbare Zeichen (Umlaute im DMV-Satz) werden zu '.'
function screen(name)
  say(string.format("---- %s  t=%.2f ----", name or "", mac.time:as_double()))
  for row = 0, 24 do
    local s = ""
    for col = 0, 79 do
      local c = vsp:read_u16(row * 80 + col) & 0xff
      if c < 32 or c > 126 then c = 46 end
      s = s .. string.char(c)
    end
    say(string.format("%2d|%s|", row, s))
  end
end

function key(s) mac.natkeyboard:post(s) end

-- Esc kommt ueber natkeyboard nicht an; direkt aufs ioport-Feld.
-- Im Plan zwei Marken dicht hintereinander: escdown(), 0,3 s spaeter escup().
function escdown() mac.ioport.ports[":keyboard:COL.1"].fields["Esc"]:set_value(1) end
function escup()   mac.ioport.ports[":keyboard:COL.1"].fields["Esc"]:set_value(0) end

-- plan{ {12.0, function() key("DIR\n") end}, {18.0, function() screen("DIR") end} }
-- Die Zeiten sind Maschinenzeit in Sekunden, aufsteigend.
function plan(list)
  local step = 0
  SUB = emu.add_machine_frame_notifier(function()   -- SUB global, siehe oben
    local t = mac.time:as_double()
    while step < #list and t >= list[step + 1][1] do
      step = step + 1
      local ok, err = pcall(list[step][2])
      if not ok then say("LUA-FEHLER: " .. tostring(err)) end
    end
  end)
end
