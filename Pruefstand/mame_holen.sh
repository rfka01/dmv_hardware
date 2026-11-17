#!/bin/sh
# mame_holen.sh - ein lauffaehiges MAME mit dem DMV-Treiber bereitstellen.
#
#   sh Pruefstand/mame_holen.sh [--hochladen]
#
# Warum es das gibt: die Arbeitsumgebung einer Claude-Sitzung wird von
# Zeit zu Zeit ersetzt, und dann ist alles weg, was nicht in einem Repo
# liegt. Die QUELLE ueberlebt das (rfka01/mame auf GitHub), das
# UEBERSETZTE nicht - und ein Bau kostet auf zwei Kernen gut eine
# Stunde. Darum legt dieses Skript das fertige Programm als
# Release-Anhang am Fork ab und holt es beim naechsten Mal von dort.
#
# Reihenfolge:
#   1. Liegt schon ein Programm da, das zum gewuenschten Stand passt?
#      Dann ist nichts zu tun.
#   2. Gibt es dafuer einen Release-Anhang? Dann herunterladen.
#   3. Sonst bauen. Mit --hochladen wandert das Ergebnis gleich in den
#      Release, damit die naechste Sitzung es findet.
#
# Umgebungsvariablen:
#   MAME_DIR     Arbeitsbaum des Forks      (Vorgabe /home/claude/mame)
#   MAME_REPO    Fork auf GitHub            (Vorgabe rfka01/mame)
#   MAME_BRANCH  Zweig des Forks            (Vorgabe master)
#   MAME_TAG     Release fuer die Anhaenge  (Vorgabe dmv-build)
#   MAME_JOBS    Uebersetzungsjobs          (Vorgabe: Zahl der Kerne)
#   MAME_LOKAL=1 auch aus einem Stand bauen, den es am Fork nicht gibt
#
# WELCHER ZWEIG - das ist keine Kleinigkeit:
#
#   master           der DMV-Treiber und alles historisch Belegte
#   homebrew-vzekc   master PLUS Erfundenes:
#                      K0815  1 MB SRAM      (bus/dmv/k0815.cpp)
#                      K235+  eigene Firmware
#                      K238                  (bus/dmv/k238.cpp)
#
# Diese drei Module gibt es NUR in homebrew-vzekc. Wer CP/M-8000, die
# K0815 oder die K235+ prueft, braucht darum MAME_BRANCH=homebrew-vzekc.
# Mit master laeuft das Modul nicht - und MAME sagt das nicht deutlich:
# -slot2 k0815 wird mit einer Zeile im Protokoll stillschweigend
# verworfen, die Maschine laeuft mit falscher Bestueckung weiter, und
# gemessen wird am Ende etwas anderes als gedacht. Am 17.11.2026 hat das
# eine Stunde gekostet, weil erst der fertige Bau zeigte, dass das Modul
# fehlt. Darum prueft dieses Skript am Ende nach (siehe module_pruefen).
#
# Der frueher hier genannte Zweig "homebrew" existiert am Fork nicht
# mehr; MAME_BRANCH=homebrew laeuft darum beim Auschecken auf einen
# Fehler.
#
# Der Zweig steht im Anhangnamen, damit nicht beide Baue denselben Namen
# tragen.
#
# WONACH DER ANHANG BENANNT IST: nach der Baumkennung (dem Hash des
# Dateibaums), nicht nach dem Commit. Der Unterschied ist praktisch:
# rfka01 rebaset seinen Fork regelmaessig auf upstream, und dabei
# aendern sich ALLE Commit-Kennungen, auch wenn keine Zeile anders ist.
# Die Baumkennung haengt nur am Inhalt - ein umgeschriebener
# Commit-Text, eine andere Reihenfolge oder ein zweites Anlegen
# desselben Inhalts ergeben denselben Namen und keinen neuen Bau.
#
# Was sie NICHT erspart: ein Rebase auf einen neueren upstream. Dann ist
# der Baum wirklich anders - nicht nur der DMV-Treiber, sondern der Kern
# des Emulators, die Laufwerke, die Formate. Daraus muss neu gebaut
# werden, und das ist richtig so. Ein Anhang, der nur die DMV-Dateien
# vergleicht und den Rest fuer gleichgueltig erklaert, wuerde irgendwann
# ein veraltetes MAME ausliefern - und ein falscher Emulator kostet uns
# mehr als eine Stunde Bauzeit, weil er falsche Messungen liefert. Genau
# das haben wir beim Startbildschirm schon einmal bezahlt.
#
# ROMs sind NICHT Sache dieses Skripts. Sie gehoeren rfka01 und haben in
# einem oeffentlichen Release nichts verloren; sie liegen als Datei am
# claude.ai-Projekt und werden von dort nach $MAME_DIR/roms/ gelegt.
set -e

MAME_DIR=${MAME_DIR:-/home/claude/mame}
MAME_REPO=${MAME_REPO:-rfka01/mame}
MAME_BRANCH=${MAME_BRANCH:-master}
MAME_TAG=${MAME_TAG:-dmv-build}
MAME_JOBS=${MAME_JOBS:-$(nproc 2>/dev/null || echo 2)}
MAME_LOKAL=${MAME_LOKAL:-0}
HOCHLADEN=0
[ "$1" = "--hochladen" ] && HOCHLADEN=1

# Das Teilziel: nur der DMV-Treiber, nicht die ganze MAME-Sammlung.
# Das spart beim Bau Stunden und beim Anhang hunderte Megabyte.
SUBTARGET=dmv
SOURCES=src/mame/ncr/dmv.cpp
PROG=dmv                                # so heisst das Ergebnis ("Linking dmv...")

sag() { echo "mame_holen: $*"; }

# ---------------------------------------------------------------------
#  Vollstaendigkeit der ROMs
# ---------------------------------------------------------------------
# ZWEI Archive werden gebraucht, nicht eines:
#
#   dmv.zip      die ROMs der Maschine selbst (21 Dateien)
#   upd7220.zip  das 256 Byte grosse Zeichen-ROM des GDC
#                (SHA1 e154b3106a80c9c98d9f2ee18efcd7f4b4aa7d49)
#
# Ohne das zweite startet MAME GAR NICHT ("Required files are missing"),
# obwohl die DMV es nicht braucht - sie zeichnet ihren Text ueber ihre
# eigenen Zeichengeneratoren M1-76161 und M3-76161, die im ersten
# Archiv liegen. Beide gehoeren rfka01 und liegen als Dateien am
# claude.ai-Projekt; das Skript holt sie NICHT und legt auch nichts an.
# Ein Platzhalter waere moeglich (MAME meldet dann nur WRONG CHECKSUMS
# und laeuft weiter), ist aber nichts, was ein Skript hinter dem Ruecken
# erfinden sollte.
roms_pruefen() {
    fehlt=
    for a in dmv.zip upd7220.zip; do
        [ -f "$1/$a" ] || fehlt="$fehlt $a"
    done
    [ -z "$fehlt" ] && return 0
    cat >&2 <<ENDE
mame_holen: in $1 fehlt:$fehlt
   Die ROM-Archive liegen als Dateien am claude.ai-Projekt und muessen
   von dort nach $1 gelegt werden. In ein Release gehoeren sie nicht.
ENDE
    return 1
}

# ---------------------------------------------------------------------
#  Firmware der K235+ unterschieben
# ---------------------------------------------------------------------
# Die Vorgabe-Firmware der K235+ heisst k235_fw24.bin und steckt NICHT
# in dmv.zip - das Archiv enthaelt nur NCRs
# DMV_int_8088_PIC_33473.bin fuer die alte K235. Fehlt die Datei,
# startet MAME GAR NICHT ("Required files are missing"), und das sieht
# nach einem kaputten Bau aus, obwohl nur eine Datei am falschen Ort
# liegt.
#
# Anders als die ROMs ist das kein Fremdgut: die Firmware liegt in
# diesem Repo, eine Ebene ueber dem Pruefstand. Sie wird deshalb hier
# in einen eigenen Suchpfad gelegt statt in roms/ - so bleibt dmv.zip
# unberuehrt, und MAME findet sie mit
#   -rompath "$MAME_DIR/meineroms;$MAME_DIR/roms"
firmware_bereitstellen() {
    _q="$(dirname "$0")/../K235FW/k235_fw24.bin"
    [ -f "$_q" ] || { sag "Hinweis: $_q fehlt - K235+ startet ohne sie nicht"; return 0; }
    _z="$MAME_DIR/meineroms/dmv_k235p"
    mkdir -p "$_z"
    cp -f "$_q" "$_z/k235_fw24.bin"
    sag "K235+-Firmware liegt in $_z (mit -rompath \"$MAME_DIR/meineroms;$MAME_DIR/roms\" aufrufen)"
}

# ---------------------------------------------------------------------
#  Hat der Bau die erfundenen Module wirklich?
# ---------------------------------------------------------------------
# Siehe Kopf: ein Bau aus dem falschen Zweig verwirft -slot2 k0815
# stillschweigend. Diese Probe kostet eine Sekunde und erspart im
# Zweifel eine Stunde.
module_pruefen() {
    [ -x "$MAME_DIR/$PROG" ] || return 0
    _soll=""
    case "$MAME_BRANCH" in
        homebrew*) _soll="k0815 k235p k238" ;;
        *)         return 0 ;;
    esac
    _slots=$("$MAME_DIR/$PROG" dmv -listslots 2>/dev/null) || return 0
    for _m in $_soll; do
        printf '%s' "$_slots" | grep -q "[^a-z0-9]$_m[^a-z0-9]" || {
            sag "ACHTUNG: $_m fehlt in diesem Bau - ist das wirklich $MAME_BRANCH?"
        }
    done
}

# ---------------------------------------------------------------------
#  1. Welcher Stand ist gemeint?
# ---------------------------------------------------------------------
if [ ! -d "$MAME_DIR/.git" ]; then
    sag "kein Fork unter $MAME_DIR - wird geklont (das dauert, 1,2 GB)"
    git clone --depth 50 -b "$MAME_BRANCH" \
        "https://github.com/$MAME_REPO" "$MAME_DIR"
fi

# Liegt hier ueberhaupt der Zweig, der gemeint ist?
HIER_ZWEIG=$(git -C "$MAME_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null)
if [ "$HIER_ZWEIG" != "$MAME_BRANCH" ]; then
    sag "ausgecheckt ist '$HIER_ZWEIG', gemeint ist '$MAME_BRANCH'"
    # Geklont wird flach und nur mit einem Zweig; ein anderer ist also
    # noch nicht da und muss erst geholt werden.
    git -C "$MAME_DIR" fetch -q --depth 60 origin "$MAME_BRANCH" 2>/dev/null || true
    git -C "$MAME_DIR" checkout -q "$MAME_BRANCH" 2>/dev/null ||
    git -C "$MAME_DIR" checkout -q -t "origin/$MAME_BRANCH" 2>/dev/null ||
    git -C "$MAME_DIR" checkout -q -B "$MAME_BRANCH" FETCH_HEAD 2>/dev/null || {
        echo "mame_holen: Zweig $MAME_BRANCH laesst sich nicht auschecken." >&2
        echo "   Gibt es ihn am Fork? 'git ls-remote --heads origin' zeigt es." >&2
        echo "   Den frueheren Zweig 'homebrew' gibt es nicht mehr, er heisst" >&2
        echo "   jetzt 'homebrew-vzekc'." >&2
        exit 2
    }
fi

# Einen Zweig ohne Upstream-Verweis haelt der Commit-Hook fuer eine
# Reihe ungepushter Commits, obwohl alles am Fork liegt. Das passiert
# bei 'checkout -B ... FETCH_HEAD' und kostet jedes Mal eine Rueckfrage.
git -C "$MAME_DIR" rev-parse --abbrev-ref '@{upstream}' >/dev/null 2>&1 ||
    git -C "$MAME_DIR" branch -q --set-upstream-to="origin/$MAME_BRANCH" 2>/dev/null ||
    true

# Stimmt der Stand mit dem Fork ueberein?
#
# Das ist keine Bequemlichkeit. Am 1.11.2026 stand in einem Klon ein
# master, den es am Fork nicht mehr gab: rfka01 hatte seither selbst auf
# upstream rebaset und 22 Commits nachgelegt. Der Klon war eine Waise.
# Ein Bau daraus haette ein MAME ergeben, dessen Stand niemand mehr
# nachvollziehen kann, und ein Rebase von dort aus haette die 22
# Commits geloescht. Darum wird hier angehalten statt geraten.
if git -C "$MAME_DIR" fetch -q origin "$MAME_BRANCH" 2>/dev/null; then
    FERN=$(git -C "$MAME_DIR" rev-parse FETCH_HEAD)
    HIER=$(git -C "$MAME_DIR" rev-parse HEAD)
    if [ "$FERN" != "$HIER" ]; then
        if git -C "$MAME_DIR" merge-base --is-ancestor "$HIER" "$FERN"; then
            sag "origin/$MAME_BRANCH ist weiter - wird nachgezogen"
            git -C "$MAME_DIR" merge --ff-only -q "$FERN" || {
                echo "mame_holen: Nachziehen geht nicht, der Arbeitsbaum ist nicht sauber." >&2
                exit 2
            }
        elif [ "$MAME_LOKAL" = 1 ]; then
            sag "ACHTUNG: dieser Stand liegt nicht in origin/$MAME_BRANCH."
            sag "          MAME_LOKAL=1 ist gesetzt, es wird trotzdem gebaut."
        else
            cat >&2 <<ENDE
mame_holen: der Stand in $MAME_DIR liegt NICHT in origin/$MAME_BRANCH.

   hier:   $(git -C "$MAME_DIR" rev-parse --short=12 HEAD)
   Fork:   $(git -C "$MAME_DIR" rev-parse --short=12 FETCH_HEAD)

   Der Zweig wurde am Fork umgeschrieben (Rebase) oder hier liegen
   eigene Commits. Daraus zu bauen hiesse, einen Stand zu pruefen, den
   es nirgends gibt. Entweder nachziehen:

      git -C $MAME_DIR fetch origin
      git -C $MAME_DIR reset --hard origin/$MAME_BRANCH

   oder, wenn der hiesige Stand gemeint ist, MAME_LOKAL=1 setzen.
ENDE
            exit 2
        fi
    fi
fi

# Benannt wird nach dem INHALT (Baumkennung), nicht nach dem Commit -
# die Begruendung steht im Kopf dieser Datei.
BAUM=$(git -C "$MAME_DIR" rev-parse --short=12 "HEAD^{tree}")
ZWEIG=$(printf '%s' "$MAME_BRANCH" | tr -c 'a-zA-Z0-9._-' '-')
ANHANG="$PROG-$ZWEIG-$BAUM-linux-x86_64.xz"
STAND="$ZWEIG $BAUM"
sag "Zweig $MAME_BRANCH, Baum $BAUM, gesuchter Anhang $ANHANG"

roms_pruefen "$MAME_DIR/roms" || true   # nur melden, der Bau geht trotzdem
firmware_bereitstellen

# ---------------------------------------------------------------------
#  2. und 3.: was schon da ist, und was aus dem Release zu holen waere
# ---------------------------------------------------------------------
# Geholt wird in ZWEI Stufen:
#
#   a) ein Anhang mit genau dieser Baumkennung,
#   b) sonst ein Anhang, dessen Stand sich vom jetzigen NUR ausserhalb
#      der DMV-massgeblichen Pfade unterscheidet.
#
# Stufe b ist nicht Bequemlichkeit, sondern noetig: rfka01 arbeitet fast
# taeglich an Druckern, und deren Code haengt mit im Programm, weil die
# K210 einen Centronics-Anschluss hat. Ohne Stufe b entwertet jeder
# Druckercommit den Anhang - am 1.11.2026 waren es acht geaenderte
# Zeilen in bmc_bx80.cpp, und sie haetten eine Stunde Bauzeit gekostet.
#
# Geraten wird dabei NICHT. Der Unterschied wird gemessen (git diff
# gegen die Liste in mame_dmv_pfade.txt) und in der Ausgabe genannt,
# damit spaeter niemand raetselt, womit gemessen wurde. Fehlt die Liste,
# faellt Stufe b weg und es wird gebaut - im Zweifel lieber bauen.

PFADLISTE=${PFADLISTE:-$(dirname "$0")/mame_dmv_pfade.txt}

pfade_lesen() {
    [ -f "$PFADLISTE" ] || return 1
    sed -e 's/#.*//' -e 's/[[:space:]]*$//' "$PFADLISTE" | grep -v '^[[:space:]]*$'
}

# Zu einer abgekuerzten Baumkennung den Commit in der Geschichte suchen.
commit_zum_baum() {
    git -C "$MAME_DIR" log --format='%H %T' -n 800 HEAD 2>/dev/null |
        awk -v t="$1" 'substr($2,1,length(t))==t {print $1; exit}'
}

# Beruehrt der Unterschied zwischen $1 und HEAD eine massgebliche Datei?
beruehrt_die_dmv() {
    _pf=$(pfade_lesen) || return 0      # keine Liste -> im Zweifel ja
    [ -n "$_pf" ] || return 0
    # git diff --quiet: 0 = gleich, 1 = verschieden
    git -C "$MAME_DIR" diff --quiet "$1" HEAD -- $_pf 2>/dev/null && return 1
    return 0
}

# $1 = Asset-Id, $2 = Anzeigename. Entpackt NACH $PROG, nicht nach dem
# Anhangnamen - sonst hiesse das Ergebnis dmv-master-...-linux-x86_64
# und waere nicht das, was gesucht wird.
anhang_laden() {
    _tmp="$MAME_DIR/.$PROG.xz.teil"
    gh api -H "Accept: application/octet-stream" \
       "repos/$MAME_REPO/releases/assets/$1" > "$_tmp" 2>/dev/null || {
        rm -f "$_tmp"; return 1; }
    xz -dc "$_tmp" > "$MAME_DIR/$PROG" || { rm -f "$_tmp"; return 1; }
    rm -f "$_tmp"
    chmod +x "$MAME_DIR/$PROG"
    return 0
}

hole_vom_release() {
    command -v gh >/dev/null || return 1
    JSON=$(gh api "repos/$MAME_REPO/releases/tags/$MAME_TAG" 2>/dev/null) ||
        return 1
    LISTE="$MAME_DIR/.anhaenge.teil"
    printf '%s' "$JSON" | python3 -I -c '
import json,sys
try: r=json.load(sys.stdin)
except Exception: sys.exit(1)
for a in r.get("assets",[]):
    if a.get("state")=="uploaded":
        print(a["id"], a["name"])
' > "$LISTE" 2>/dev/null || { rm -f "$LISTE"; return 1; }

    # --- a) genau passend -------------------------------------------
    ID=$(awk -v n="$ANHANG" '$2==n {print $1; exit}' "$LISTE")
    if [ -n "$ID" ]; then
        sag "Anhang passt genau (id $ID), wird geladen"
        if anhang_laden "$ID" "$ANHANG"; then
            rm -f "$LISTE"
            echo "$STAND" > "$MAME_DIR/.dmv_stand"
            sag "aus dem Release geholt - kein Bau noetig"
            return 0
        fi
        sag "Laden fehlgeschlagen"
        rm -f "$LISTE"; return 1
    fi

    # --- b) gleichwertig --------------------------------------------
    pfade_lesen >/dev/null 2>&1 || {
        sag "keine Pfadliste ($PFADLISTE) - es wird gebaut"
        rm -f "$LISTE"; return 1
    }
    ZW_RE=$(printf '%s' "$ZWEIG" | sed 's/[.[\*^$\/]/\\&/g')
    while read -r AID ANAME; do
        [ -n "$AID" ] || continue
        ABAUM=$(printf '%s' "$ANAME" |
            sed -n "s/^$PROG-$ZW_RE-\\(.*\\)-linux-x86_64\\.xz\$/\\1/p")
        [ -n "$ABAUM" ] || continue
        ACOMMIT=$(commit_zum_baum "$ABAUM")
        [ -n "$ACOMMIT" ] || continue       # Stand nicht in der Geschichte
        if beruehrt_die_dmv "$ACOMMIT"; then
            continue
        fi
        KURZ=$(git -C "$MAME_DIR" rev-parse --short=12 "$ACOMMIT")
        ANZ=$(git -C "$MAME_DIR" rev-list --count "$ACOMMIT..HEAD" 2>/dev/null)
        sag "kein Anhang fuer $BAUM, aber $ANAME ist gleichwertig:"
        sag "  gebaut aus $KURZ, seither $ANZ Commit(e), KEINER davon in"
        sag "  einer Datei aus $(basename "$PFADLISTE"):"
        git -C "$MAME_DIR" log --format='    %h %s' "$ACOMMIT..HEAD" |
            head -8
        if anhang_laden "$AID" "$ANAME"; then
            rm -f "$LISTE"
            # Vermerkt wird der Stand, aus dem WIRKLICH gebaut wurde.
            # Sonst hielte der naechste Lauf den Bau faelschlich fuer
            # den jetzigen Baum und merkte eine spaetere Abweichung
            # nicht mehr.
            echo "$ZWEIG $ABAUM" > "$MAME_DIR/.dmv_stand"
            sag "aus dem Release geholt - fuer die DMV gleichwertig"
            return 0
        fi
        sag "Laden fehlgeschlagen"
    done < "$LISTE"
    rm -f "$LISTE"
    return 1
}

# --- liegt schon ein brauchbarer Bau da? -----------------------------
# Brauchbar heisst: entweder genau dieser Baum, oder ein Baum, dessen
# Stand sich nur ausserhalb der massgeblichen Pfade unterscheidet -
# derselbe Massstab wie beim Holen. Ohne das wuerde ein Druckercommit
# den vorhandenen Bau entwerten und den Anhang gleich noch einmal aus
# dem Netz holen.
if [ -x "$MAME_DIR/$PROG" ] && [ -f "$MAME_DIR/.dmv_stand" ]; then
    DA_STAND=$(cat "$MAME_DIR/.dmv_stand")
    DA_ZWEIG=${DA_STAND%% *}
    DA_BAUM=${DA_STAND##* }
    if [ "$DA_STAND" = "$STAND" ]; then
        sag "$MAME_DIR/$PROG ist schon da und passt zu $STAND - nichts zu bauen"
        module_pruefen
        [ "$HOCHLADEN" = 1 ] || exit 0
        SCHON_DA=1
    elif [ "$DA_ZWEIG" = "$ZWEIG" ] && [ -n "$DA_BAUM" ]; then
        DA_COMMIT=$(commit_zum_baum "$DA_BAUM")
        if [ -n "$DA_COMMIT" ] && ! beruehrt_die_dmv "$DA_COMMIT"; then
            sag "$MAME_DIR/$PROG ist aus $DA_BAUM - fuer die DMV gleichwertig"
            sag "  (Unterschied zu $BAUM beruehrt keine Datei aus $(basename "$PFADLISTE"))"
            module_pruefen
            [ "$HOCHLADEN" = 1 ] || exit 0
            SCHON_DA=1
            # Abgelegt wird unter dem Stand, aus dem wirklich gebaut
            # wurde - nicht unter dem jetzigen. Alles andere waere eine
            # Falschaussage im Dateinamen.
            BAU_BAUM=$DA_BAUM
        fi
    fi
fi

if [ "${SCHON_DA:-0}" != 1 ]; then
    if hole_vom_release; then
        module_pruefen
        exit 0
    fi
    sag "kein passender Anhang - es wird gebaut"
fi

# ---------------------------------------------------------------------
#  4. Bauen
# ---------------------------------------------------------------------
if [ "${SCHON_DA:-0}" = 1 ]; then
    :   # liegt schon vor, nur noch packen
else
# Voraussetzungen. SDL2 fehlt in frischen Containern regelmaessig.
if ! pkg-config --exists sdl2 2>/dev/null; then
    sag "SDL2 fehlt - wird nachinstalliert"
    apt-get update -q >/dev/null 2>&1 || true
    apt-get install -y -q libsdl2-dev libsdl2-ttf-dev libfontconfig1-dev \
        >/dev/null 2>&1 || {
        echo "mame_holen: SDL2 laesst sich nicht installieren." >&2
        exit 2
    }
fi

# Auslagerungsspeicher. Am 17.11.2026 hat der OOM-Killer auf zwei Kernen
# mit 7 GB den Uebersetzer bei luaengine.cpp erschlagen - diese eine
# Datei braucht mehrere Gigabyte, und neben einer zweiten schweren reicht
# es nicht. Der Abbruch sieht nach einem Uebersetzungsfehler aus:
#
#   g++: fatal error: Killed signal terminated program cc1plus
#   make[1]: *** [frontend.make:...: ../../../../linux_gcc/obj/.../luaengine.o] Error 1
#
# Er ist aber keiner. Mit Auslagerung laeuft es durch. Ein frischer
# Behaelter hat keine, und ein Neustart nimmt sie wieder weg.
if [ "$(awk '/^SwapTotal:/{print $2}' /proc/meminfo 2>/dev/null || echo 0)" -lt 1048576 ]; then
    if [ ! -f /swapfile ] && fallocate -l 6G /swapfile 2>/dev/null; then
        chmod 600 /swapfile
        if mkswap -q /swapfile >/dev/null 2>&1 && swapon /swapfile 2>/dev/null; then
            sag "6 GB Auslagerungsspeicher angelegt (gegen den OOM-Killer)"
        else
            rm -f /swapfile
            sag "Auslagerung laesst sich nicht einschalten - bei Abbruch mit"
            sag "  'Killed signal terminated program cc1plus' MAME_JOBS=1 setzen"
        fi
    elif [ -f /swapfile ]; then
        swapon /swapfile 2>/dev/null && sag "vorhandene Auslagerung eingeschaltet" || true
    fi
fi

cd "$MAME_DIR"
sag "make SUBTARGET=$SUBTARGET SOURCES=$SOURCES -j$MAME_JOBS (dauert)"
# Beim ersten Lauf nicht abbrechen: faellt eine einzelne Datei aus (OOM,
# siehe oben), holt der zweite Lauf genau sie nach - alles Uebersetzte
# bleibt ja liegen. Erst wenn danach kein Programm da ist, ist Schluss.
make SUBTARGET="$SUBTARGET" SOURCES="$SOURCES" NOWERROR=1 REGENIE=1 \
     USE_QTDEBUG=0 \
     -j"$MAME_JOBS" || sag "erster Lauf abgebrochen - zweiter Versuch mit -j1"

if [ ! -x "$MAME_DIR/$PROG" ]; then
    make SUBTARGET="$SUBTARGET" SOURCES="$SOURCES" NOWERROR=1 REGENIE=1 \
         USE_QTDEBUG=0 \
         -j1
fi

[ -x "$MAME_DIR/$PROG" ] || {
    echo "mame_holen: $PROG ist nicht entstanden." >&2
    exit 1
}
strip "$MAME_DIR/$PROG" 2>/dev/null || true
echo "$STAND" > "$MAME_DIR/.dmv_stand"
sag "gebaut: $MAME_DIR/$PROG ($(wc -c < "$MAME_DIR/$PROG") Byte)"
module_pruefen
fi

# ---------------------------------------------------------------------
#  5. Den Bau zum Ablegen bereitstellen
# ---------------------------------------------------------------------
# WICHTIG, am 1.11.2026 ausprobiert: eine Claude-Sitzung darf Releases
# WEDER ANLEGEN NOCH BESCHREIBEN - GitHub antwortet
#
#   403 "Creating, editing, or deleting releases is not permitted
#        for this session type."
#
# und zwar unabhaengig von den Rechten am Repo (dort stehen admin und
# push auf true). LESEN ist dagegen erlaubt, der Weg oben funktioniert
# also. Den Anhang muss darum rfka01 selbst einmal anlegen; danach holt
# ihn jede weitere Sitzung von dort.
#
# --hochladen packt deshalb nur und sagt, was zu tun ist.
if [ "$HOCHLADEN" = 1 ]; then
    # Der Name nennt den Stand, aus dem das Programm WIRKLICH stammt.
    ABLAGE="$PROG-$ZWEIG-${BAU_BAUM:-$BAUM}-linux-x86_64.xz"
    sag "wird gepackt als $ABLAGE"
    xz -T0 -3 -k -f "$MAME_DIR/$PROG"
    mv "$MAME_DIR/$PROG.xz" "$MAME_DIR/$ABLAGE"
    cat <<ENDE

Fertig gepackt: $MAME_DIR/$ABLAGE
   ($(wc -c < "$MAME_DIR/$ABLAGE") Byte)

Hochladen kann diese Sitzung nicht (siehe Kopf dieses Abschnitts).
Zu tun, EINMAL von Hand:

   1. Auf https://github.com/$MAME_REPO/releases einen Release mit dem
      Tag  $MAME_TAG  anlegen.
   2. Die Datei oben als Anhang hinzufuegen - unter genau diesem Namen,
      sonst findet das Skript sie nicht.

Danach holt jede weitere Sitzung sie selbst, und es wird nicht mehr
gebaut, solange der Fork-Stand derselbe ist.
ENDE
fi
exit 0
