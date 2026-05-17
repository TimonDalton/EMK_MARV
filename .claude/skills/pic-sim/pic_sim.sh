#!/usr/bin/env bash
# pic_sim.sh — compile a PIC18 .s file with pic-as, simulate with mdb, optionally
# apply SCL stimulus, log watched SFRs/vars.
#
# Usage: see ../SKILL.md

set -euo pipefail

# ─── Toolchain paths ────────────────────────────────────────────────────────
PIC_AS="/Applications/microchip/xc8/v3.10/pic-as/bin/pic-as"
MDB="/Applications/microchip/mplabx/v6.20/mplab_platform/bin/mdb.sh"
DFP_BASE="/Applications/microchip/mplabx/v6.20/packs/Microchip/PIC18F-K_DFP"

# ─── Defaults ───────────────────────────────────────────────────────────────
DEVICE="PIC18F45K22"
RUN_MS=100
SOURCE=""
STIM=""
DFP=""
BUILD_ONLY=0
VERBOSE=0
WATCHES=()
BREAKS=()
INJECTS=()                  # ASCII chars or 0xNN bytes — see SIM HOOK below
TX_BURST=0                  # number of continue+print cycles to chain (multi-byte TX capture)
DUMP_SFRS=("LATA" "LATB" "LATC" "LATD" "PORTA" "PORTB" "PIR1" "TXSTA1" "RCSTA1")
HWTOOL="sim"                # mdb hwtool; sim by default. Real-HW examples: pkob4, pickit4, snap, icd4
FLASH=0                     # when 1, program real HW and free-run (skip sim hooks)

# ─── Arg parsing ────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --device)    DEVICE="$2"; shift 2 ;;
        --run-ms)    RUN_MS="$2"; shift 2 ;;
        --stim)      STIM="$2"; shift 2 ;;
        --watch)     WATCHES+=("$2"); shift 2 ;;
        --break)     BREAKS+=("$2"); shift 2 ;;
        --inject)    INJECTS+=("$2"); shift 2 ;;
        --tx-burst)  TX_BURST="$2"; shift 2 ;;
        --dfp)       DFP="$2"; shift 2 ;;
        --build-only) BUILD_ONLY=1; shift ;;
        --verbose|-v) VERBOSE=1; shift ;;
        --dump)      DUMP_SFRS+=("$2"); shift 2 ;;
        --hwtool)    HWTOOL="$2"; shift 2 ;;
        --flash)     FLASH=1; HWTOOL="${HWTOOL:-pkob4}"; shift ;;
        -h|--help)
            sed -n '1,30p' "$(dirname "$0")/SKILL.md"
            exit 0 ;;
        *)
            if [[ -z "$SOURCE" ]]; then SOURCE="$1"; else
                echo "unknown arg: $1" >&2; exit 2
            fi
            shift ;;
    esac
done

# If --flash given but no hwtool, default to pkob4 (Curiosity onboard programmer)
if (( FLASH )) && [[ "$HWTOOL" == "sim" ]]; then
    HWTOOL="pkob4"
fi

# ─── Source-file discovery ──────────────────────────────────────────────────
if [[ -z "$SOURCE" ]]; then
    SOURCE=$(ls *.s 2>/dev/null | head -1 || true)
    if [[ -z "$SOURCE" ]]; then
        echo "no .s file in cwd and none specified" >&2; exit 2
    fi
fi
[[ -f "$SOURCE" ]] || { echo "no such file: $SOURCE" >&2; exit 2; }
SOURCE_ABS="$(cd "$(dirname "$SOURCE")" && pwd)/$(basename "$SOURCE")"
SRC_BASE="$(basename "${SOURCE%.*}")"

# ─── DFP discovery ──────────────────────────────────────────────────────────
if [[ -z "$DFP" ]]; then
    DFP=$(ls -d "$DFP_BASE"/*/xc8 2>/dev/null | sort -V | tail -1)
    if [[ -z "$DFP" ]]; then
        echo "no DFP found under $DFP_BASE — install MPLAB X PIC18F-K pack" >&2
        exit 3
    fi
fi
[[ -d "$DFP" ]] || { echo "DFP not a directory: $DFP" >&2; exit 3; }

# ─── Build ──────────────────────────────────────────────────────────────────
BUILD_DIR="$(pwd)/build"
mkdir -p "$BUILD_DIR"
ELF="$BUILD_DIR/${SRC_BASE}.elf"
LST="$BUILD_DIR/${SRC_BASE}.lst"
BUILD_LOG="$BUILD_DIR/${SRC_BASE}.build.log"

echo "[build] $SOURCE_ABS"
if "$PIC_AS" -mcpu="${DEVICE#PIC}" -mdfp="$DFP" -xassembler-with-cpp \
             -Wl,-Map="$BUILD_DIR/${SRC_BASE}.map" \
             -o "$ELF" "$SOURCE_ABS" \
             > "$BUILD_LOG" 2>&1; then
    SUMMARY=$(grep -E 'Program space|Data space|Configuration' "$BUILD_LOG" | sed 's/^[[:space:]]*//')
    echo "[build] OK"
    while IFS= read -r line; do echo "[build]   $line"; done <<< "$SUMMARY"
    if (( VERBOSE )); then cat "$BUILD_LOG"; fi
else
    echo "[build] FAILED — see $BUILD_LOG"
    tail -40 "$BUILD_LOG"
    exit 4
fi

(( BUILD_ONLY )) && exit 0

# ─── Variable address resolution (Bash 3.2 compatible — no assoc arrays) ────
# pic-as EQU labels are assembled as immediate constants — they don't appear in
# any ELF/.sym symbol table mdb can see. Instead, grep the .s source for lines
# like "must_navigate_to_var EQU 0x08" and emit the literal address.
resolve_var() {
    local name="$1"
    local addr=""
    addr=$(grep -iE "^[[:space:]]*${name}[[:space:]]+EQU[[:space:]]+" "$SOURCE_ABS" 2>/dev/null \
           | head -1 | awk '{print $3}')
    if [[ -n "$addr" ]]; then
        [[ "$addr" =~ ^0[xX] ]] || addr="0x$addr"
        echo "*$addr"
    else
        echo "$name"  # could be a real SFR name (LATA, TXREG1, etc.) — mdb resolves those
    fi
}

# ─── Simulate ───────────────────────────────────────────────────────────────
SIM_SCRIPT="$BUILD_DIR/${SRC_BASE}.mdb"
SIM_LOG="$BUILD_DIR/${SRC_BASE}.sim.log"

# If TX_BURST left at 0 but the user is watching TXREG1, default to 60 cycles so
# the full boot greeting (~50 bytes) is captured instead of just the first byte.
if (( TX_BURST == 0 )); then
    for w in ${WATCHES[@]+"${WATCHES[@]}"}; do
        if [[ "$w" == "TXREG1" || "$w" == "0xFAD" ]]; then TX_BURST=60; break; fi
    done
fi

# Translate inject items ('A' / 'M' / 0x41) into a decimal byte value 0–255.
inject_byte_dec() {
    local x="$1"
    if [[ "$x" =~ ^0[xX][0-9a-fA-F]+$ ]]; then
        printf '%d' "$x"
    elif [[ ${#x} -eq 1 ]]; then
        printf '%d' "'$x"
    else
        echo 0
    fi
}

if (( FLASH )); then
    # ─── Hardware flash mode ───────────────────────────────────────────────
    # Minimal mdb script: select tool, program, run, quit. The chip then
    # runs free; capture its UART output with marv_terminal.py or similar.
    # Watches / injects / dumps are sim-only and silently skipped here.
    {
        echo "device $DEVICE"
        echo "hwtool $HWTOOL"
        # Pre-answer yes/no prompts that may appear during program or run.
        echo "yes"
        echo "program $ELF"
        echo "yes"
        echo "run"
        echo "yes"
        echo "quit"
    } > "$SIM_SCRIPT"
    echo "[flash] $DEVICE via $HWTOOL"
    if [[ ${#WATCHES[@]+x} && ${#WATCHES[@]} -gt 0 ]] \
       || [[ ${#BREAKS[@]+x} && ${#BREAKS[@]} -gt 0 ]] \
       || [[ ${#INJECTS[@]+x} && ${#INJECTS[@]} -gt 0 ]]; then
        echo "[flash] note: --watch/--break/--inject are sim-only, ignored in --flash mode" >&2
    fi
else
    # ─── Simulator mode (default) ──────────────────────────────────────────
    {
        echo "device $DEVICE"
        echo "hwtool sim"
        echo "program $ELF"
        for w in ${WATCHES[@]+"${WATCHES[@]}"}; do
            resolved=$(resolve_var "$w")
            echo "watch ${resolved#\*} W"
        done
        for b in ${BREAKS[@]+"${BREAKS[@]}"}; do
            echo "break $b"
        done
        if [[ -n "$STIM" ]]; then
            STIM_ABS="$(cd "$(dirname "$STIM")" && pwd)/$(basename "$STIM")"
            echo "stim $STIM_ABS"
        fi
        echo "run"

        # RX injection via sim hook: each --inject byte is dropped into
        # sim_rx_pending_var. The firmware's UART_RX_NB / UART_RX_BLOCK check that
        # variable before RCREG1, so it sees the byte as if it had arrived over UART.
        SIM_RX_ADDR=""
        if [[ ${#INJECTS[@]} -gt 0 ]]; then
            srx=$(resolve_var "sim_rx_pending_var")
            SIM_RX_ADDR="${srx#\*}"
            for b in ${INJECTS[@]+"${INJECTS[@]}"}; do
                v=$(inject_byte_dec "$b")
                hex=$(printf '0x%02X' "$v")
                echo "wait $RUN_MS"
                echo "halt"
                echo "write $SIM_RX_ADDR $hex"
                echo "continue"
            done
        fi

        if (( TX_BURST > 0 )); then
            for ((i=0; i<TX_BURST; i++)); do
                echo "wait $RUN_MS"
                echo "print /x TXREG1"
                echo "continue"
            done
        fi

        echo "wait $RUN_MS"
        echo "halt"
        for sfr in "${DUMP_SFRS[@]}"; do
            resolved=$(resolve_var "$sfr")
            echo "print /x ${resolved#\*}"
            echo "echo == ${sfr} above =="
        done
        for w in ${WATCHES[@]+"${WATCHES[@]}"}; do
            resolved=$(resolve_var "$w")
            echo "print /x ${resolved#\*}"
            echo "echo == ${w} above =="
        done
        echo "quit"
    } > "$SIM_SCRIPT"

    echo "[sim]   $DEVICE, sim, run ${RUN_MS}ms"
    [[ ${#WATCHES[@]+x} && ${#WATCHES[@]} -gt 0 ]] && echo "[sim]   watches: ${WATCHES[*]}"
    [[ ${#BREAKS[@]+x}  && ${#BREAKS[@]}  -gt 0 ]] && echo "[sim]   breaks:  ${BREAKS[*]}"
    [[ -n "$STIM" ]] && echo "[sim]   stim:    $STIM"
fi

# Run mdb so a SIGTERM/parent timeout kills the whole tree (mdb.sh + java
# child). Otherwise the JVM survives, keeps the PKOB4 USB endpoint claimed,
# and bricks the programmer until power cycle.
cleanup_mdb() {
    [[ -n "${MDB_PID:-}" ]] && pkill -9 -P "$MDB_PID" 2>/dev/null || true
    pkill -9 -f mdb.jar 2>/dev/null || true
}
trap cleanup_mdb EXIT INT TERM
"$MDB" < "$SIM_SCRIPT" > "$SIM_LOG" 2>&1 &
MDB_PID=$!
wait "$MDB_PID" || true
trap - EXIT INT TERM

# ─── Distil mdb output ──────────────────────────────────────────────────────
# Filter the JVM noise and JLine warnings, surface the actual mdb output.
# Collapse repeated peripheral warnings into a single line so the print
# results stay readable.
grep -v -E 'jline|EndOfFile|^Exception|^\sat |^WARNING|INFO|NativeLoader|USBAccess|nbPrefs|getPreferencesProvider|libUSB|libusb|MPLABComm|^[[:space:]]*$|^May |^Resetting' \
    "$SIM_LOG" \
    | sed 's/^>//' \
    | grep -v '^[[:space:]]*$' \
    | awk '
        # collapse runs of identical lines (e.g. ADC warnings) — print first + a (×N) count when N>1
        {
            if ($0 == prev) { count++ }
            else {
                if (count > 1) print prev "  (×" count ")"
                else if (NR > 1) print prev
                prev = $0; count = 1
            }
        }
        END { if (count > 1) print prev "  (×" count ")"; else print prev }
    ' \
    | while IFS= read -r line; do
          if (( FLASH )); then echo "[flash] $line"; else echo "[sim]   $line"; fi
      done

if (( FLASH )); then echo "[flash] log: $SIM_LOG"; else echo "[sim]   log: $SIM_LOG"; fi
