---
name: pic-sim
description: "Compile a PIC18 assembly file with pic-as, simulate it with MPLAB X's mdb, inject UART RX bytes via a firmware sim hook, and dump SFRs/vars."
trigger: /pic-sim
---

# /pic-sim

Headless PIC assembly + simulation harness for the MARV project. Wraps `pic-as` (XC8) and `mdb` (MPLAB X) so firmware changes can be validated without IDE clicks.

## Usage

```
/pic-sim                                       # build + sim the .s file in cwd (auto-pick if only one)
/pic-sim marv_p3.s                             # build + 100 ms sim, dump LATA/LATB/SFRs at end
/pic-sim marv_p3.s --run-ms 1500               # longer run
/pic-sim marv_p3.s --inject 'R'                # inject one UART RX byte (see SIM HOOK)
/pic-sim marv_p3.s --inject 'C' --inject 'R'   # inject sequentially, RUN_MS spacing between
/pic-sim marv_p3.s --watch TXREG1              # halt + log on every write to TXREG1 (UART TX)
/pic-sim marv_p3.s --watch LATA                # SSD writes
/pic-sim marv_p3.s --break Main                # halt on label entry
/pic-sim marv_p3.s --dump must_navigate_to_var # print var at end (resolves EQU addresses)
/pic-sim marv_p3.s --stim test.scl             # apply SCL stimulus during the run
/pic-sim marv_p3.s --device PIC18F26K22        # override device (default PIC18F45K22)
/pic-sim --build-only marv_p3.s                # compile, no sim

# Real hardware (requires programmer connected over USB):
/pic-sim marv_p3.s --flash                     # build + program via pkob4, free-run
/pic-sim marv_p3.s --flash --hwtool pickit4    # use a different programmer
```

`--flash` switches the mdb backend from `sim` to a real programmer. The default `--hwtool` is `pkob4` (Curiosity onboard PICkit-On-Board 4). Other supported strings include `pickit3`, `pickit4`, `pickit5`, `snap`, `icd3`, `icd4`, `icd5`. After programming, mdb sends `run` and disconnects — the chip free-runs and you observe its UART on `marv_terminal.py` (or whatever serial terminal). `--watch`, `--break`, `--inject`, `--dump`, `--stim` are sim-only and silently skipped when `--flash` is set.

## Implementation

The skill is a single bash script: `pic_sim.sh`. Invoke it directly — it accepts the same flags listed above.

Toolchain paths (Mac, MPLAB X 6.20 + XC8 3.10):

- Assembler: `/Applications/microchip/xc8/v3.10/pic-as/bin/pic-as`
- DFP:       `/Applications/microchip/mplabx/v6.20/packs/Microchip/PIC18F-K_DFP/<ver>/xc8`
- Debugger:  `/Applications/microchip/mplabx/v6.20/mplab_platform/bin/mdb.sh`

If these move, update the constants at the top of `pic_sim.sh`.

## How the pieces fit

### Build

`pic-as` for pure-asm projects. `-xassembler-with-cpp` enables `#include`. Output: `build/<base>.elf` (with debug info) plus `.map`, `.sym`, `.cmf`.

```sh
pic-as -mcpu=18F45K22 -mdfp=$DFP/xc8 -xassembler-with-cpp \
       -Wl,-Map=build/marv_p3.map -o build/marv_p3.elf marv_p3.s
```

### Simulate

`mdb` runs from stdin. The wrapper writes a command file with device select, sim attach, program load, watches/breaks, optional `stim <file>`, then `run` followed by inject cycles and a final halt+dump.

```text
device PIC18F45K22
hwtool sim
program build/marv_p3.elf
watch *0x53 W              # optional, repeats per --watch (resolved from EQU)
break Main                 # optional, repeats per --break
run
wait 1500                  # let firmware run
halt
write *0x57 0x52           # SIM HOOK: drop 'R' into sim_rx_pending_var
continue                   # firmware picks it up at next UART poll
wait 1500
halt
print /x *0x08             # must_navigate_to_var
echo == must_navigate_to_var above ==
quit
```

**Variable resolution:** pic-as EQU labels are pure constants — never appear in the ELF symbol table. The script greps the `.s` source for `<name> EQU <addr>` lines and emits `print /x *0xADDR` instead of by name. Subroutine labels work normally with `break <label>` (but pic-as does not export labels to mdb either, so a `break` on an internal label often silently no-ops — use `break <file>:<line>` for reliability).

### SIM HOOK — UART RX injection

The MPLAB X simulator treats `RCREG1` as a read-only FIFO output: writing to address `0xFAE` has no effect on what `MOVF RCREG1, W` returns, and the documented `set uart1io.uartioenabled true` / `inputfile` mechanism is silently accepted but never feeds bytes.

Workaround: a 1-byte firmware variable `sim_rx_pending_var` that `UART_RX_NB` and `UART_RX_BLOCK` check **before** `RCREG1`. The skill uses mdb's `write` to drop a byte into that variable; the next time the firmware polls, it sees the byte.

**Firmware contract** (already in `marv_p3.s` — copy into any `.s` you want to drive via `--inject`):

```asm
sim_rx_pending_var  EQU 0x57            ; pick any free RAM slot

UART_RX_NB:
    MOVF    sim_rx_pending_var, W, a
    BZ      _URNB_HW
    MOVWF   uart_rx_var, a
    CLRF    sim_rx_pending_var, a
    MOVLW   0x01
    RETURN
_URNB_HW:
    BTFSS   PIR1, 5, a
    BRA     _URNB_NONE
    MOVF    RCREG1, W, a
    MOVWF   uart_rx_var, a
    MOVLW   0x01
    RETURN
_URNB_NONE:
    MOVLW   0x00
    RETURN
```

`UART_RX_BLOCK` gets the same hook. Cost on real hardware: 2 extra instructions per poll, no behavior change (`sim_rx_pending_var` is always zero outside of sim).

**Z flag gotcha** (worth knowing): `MOVLW` does *not* update the Z flag on PIC18. If a caller wants to `BZ` on a zero/non-zero return from `UART_RX_NB`, insert `IORLW 0x00` to refresh Z based on W:

```asm
POLL_UART_CMD:
    CALL    UART_RX_NB
    IORLW   0x00
    BZ      _PUCMD_NONE
    CALL    DISPATCH_UART_BYTE
_PUCMD_NONE:
    RETURN
```

### Cap-touch / blocking-loop gotcha

mdb's simulator does NOT advance the CTMU correctly. ADC GO bit never clears on CTMU samples, so a tight `BTFSC ADCON0, 1 / BRA back` loop spins forever. Solution: bound any peripheral-poll loop with a counter:

```asm
    BSF     ADCON0, 1, a
    SETF    cap_poll_counter_var, a     ; ~255 iters
CAP_ADC_POLL:
    BTFSS   ADCON0, 1, a
    BRA     CAP_ADC_DONE
    DECFSZ  cap_poll_counter_var, f, a
    BRA     CAP_ADC_POLL
CAP_ADC_DONE:
```

Real ADC completes in ~10 cycles; the cap is a no-op on hardware.

### Stimulus

`--stim <file>` is wired up but the simulator's SCL parser uses a VHDL-flavoured grammar that is sparsely documented. Pin drive and register injection from SCL did **not** work reliably for UART RX in testing — use `--inject` (sim hook) instead.

## Watch / break patterns

| Want to see | Use |
|---|---|
| Every UART TX byte | `--watch TXREG1` (auto-enables TX burst capture) |
| Every SSD pattern written | `--watch LATA` |
| Every state-transition request | `--watch must_navigate_to_var` |
| Race colour changes | `--watch RACE_COL_var` |
| Final var values only | `--dump must_navigate_to_var` (no halt during run) |
| ISR entry | `--break ISR` |
| Specific dispatch arm | `--break _PUC_ATK`, `--break _PUC_REF`, etc. |

A `--watch` halts the sim on every write to that address — fine for low-frequency vars, but volatile vars (e.g. `must_navigate_to_var` is written during init) will cut the run short. For end-of-run snapshots prefer `--dump`.

## Output format

```
[build] /Users/.../marv_p3.s
[build] OK
[build]   Program space        used  4160h ( 16736) of  8000h bytes   ( 51.1%)
[sim]   PIC18F45K22, sim, run 1500ms
[sim]   Programming target...
[sim]   Program succeeded.
[sim]   Running
[sim]   W0223-ADC: ... (×10732)         # repeated warnings collapsed
[sim]   Simulator halted
[sim]   LATA=5b
[sim]   /*== LATA above ==*/
[sim]   0x08=
[sim]   0x01
[sim]   /*== must_navigate_to_var above ==*/
[sim]   0x53=
[sim]   0x52
[sim]   /*== uart_rx_var above ==*/
```

The `/*== <name> above ==*/` markers come from the script — they let you correlate a hex dump back to its source name when piping into `awk` (the line above each marker is the value).

Example extraction:

```bash
out=$(.claude/skills/pic-sim/pic_sim.sh marv_p3.s --inject 'R' \
        --dump must_navigate_to_var --dump uart_rx_var)
echo "$out" | awk '
  /must_navigate_to_var above/ { print "mn =", prev }
  /uart_rx_var above/          { print "rx =", prev }
  { prev = $0 }'
```

## Caveats

- mdb's simulator does NOT model the CTMU. Cap-touch reads 0 forever. Bound the ADC poll (see above) and rely on UART-driven nav.
- `set uart1io.uartioenabled true` and `set uart1io.inputfile <f>` are silently ignored — use the SIM HOOK.
- `break <label>` for inline labels (not function-entry labels) typically does nothing — pic-as does not emit name symbols. Use `break <file>:<line>` or watch on an EQU address instead.
- `--watch` halts on every write; volatile vars written during init will cut the run short. Use `--dump` for end-of-run reads.
- `W9602-COMP:DAC Voltage Source` warnings are cosmetic.
- `pic-as` complains about "RAM access bit operand not specified" for `MOVFF` etc. — harmless, suppressed unless `--verbose`.
- If `(2104) no device-support files found`, the DFP path is wrong. The script searches `PIC18F-K_DFP/*/xc8` and picks the highest version; override with `--dfp <path>`.

## File map

```
.claude/skills/pic-sim/
├── SKILL.md                        # this file
├── pic_sim.sh                      # the orchestration script
└── templates/
    ├── uart_inject.scl             # legacy SCL — NOT working, kept for reference
    └── uart_pin_drive.scl          # legacy SCL pin-drive — NOT working, kept for reference
```
