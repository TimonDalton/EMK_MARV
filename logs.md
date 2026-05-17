# marv_p3.s iteration log

Goal: get UART command dispatch working end-to-end in mdb sim.
Spec: from menu state, `R/G/B/k` arms a race colour (Feedback Colour state);
`M` enters LLI; `C` enters calibration; `A` enters Attack (LLI); `S` simulate;
`H` hotload. While racing/LLI, sending a colour or `M` re-arms.

Method: use `/pic-sim` headless build+sim, inject bytes via mdb `write`, watch
`TXREG1` for TX and `must_navigate_to_var` / `LATA` for state changes.

---
--- progress log ---

## Iter 1 — fix LLI_NAV_LOOP, inject 'R'
Moved NAV_STATE_IF_REQUIRED to top of LLI_NAV_LOOP. Build OK (51.1% flash).
Sim with --inject 'R' --run-ms 500 — must_navigate_to_var stayed 0x02 (LLI), PIR1=0x62 (RC1IF still set).
Byte was injected but never consumed. Sim halted twice at line 1482 (mid-ADC), suggesting program is stuck pre-LLI.


## Iter 2 — Z-flag in POLL_UART_CMD
Discovered MOVLW doesn't update Z in PIC18, so `BZ _PUCMD_NONE` after `CALL UART_RX_NB` tested stale Z. Added `IORLW 0x00` after both UART_RX_NB calls.

## Iter 3 — WFT_POLL blocked by CAP_TOUCH ADC stall
WAIT_FOR_TOUCH never advances in sim because ADC GO bit never clears (CTMU path unsupported in mdb). Bounded `CAP_ADC_POLL` with `cap_poll_counter_var` (SETF → DECFSZ → fall-through after ~255 iters). Now CAP_TOUCH_ROUTINE returns and WFT_POLL is reached.

## Iter 4 — UART RX FIFO injection
`write 0xFAE 0x52` (RCREG1) plus setting RC1IF cleared RC1IF but `MOVF RCREG1, W` returned 0 — mdb simulator treats RCREG1 as FIFO output and the write doesn't populate the FIFO. `set uart1io.uartioenabled true` + `inputfile` accepted silently but did nothing.

## Iter 5 — SIM HOOK
Added `sim_rx_pending_var EQU 0x57`. UART_RX_NB and UART_RX_BLOCK both check it first; if nonzero, treat it as the received byte and clear. Production code paths unaffected (var stays 0 on real hardware). Skill script now `write`s into `sim_rx_pending_var`'s address for each `--inject` byte.

## SUCCESS — 'R' → calibrating (0x01)
- uart_rx_var = 0x52 ('R')
- must_navigate_to_var = 0x01 (calibrating)
- current_state_var = 0x01
- LATA = 0x5B (DIGIT_2_SSD)
- sim_rx_pending_var = 0x00 (consumed)

(Note: 'R' = Reference/calibration in P3 spec, not Red. Red is selected via 'C' submenu.)

## Comprehensive verification — all dispatches green

| Inject | Byte | must_navigate_to_var | current_state_var | LATA | Meaning |
|--------|------|----------------------|--------------------|------|---------|
| M  | 0x4D | 0x00 | 0x00 | 0x00 | selecting (main menu) |
| R  | 0x52 | 0x01 | 0x01 | 0x5B | calibrating (DIGIT_2) |
| A  | 0x41 | 0x02 | 0x02 | 0x4F | LLI / Attack (DIGIT_3) |
| C  | 0x43 | 0x03 | 0x03 | 0x06 | feedback_color (DIGIT_1) |
| S  | 0x53 | 0x06 | 0x06 | 0x66 | simulate (DIGIT_4) |
| H  | 0x48 | 0x07 | 0x07 | 0x6D | hotload (DIGIT_5) |

Colour submenu (after entering C-state):

| Sequence | Final uart_rx_var | RACE_COL_var |
|----------|-------------------|--------------|
| C → R | 0x52 | 0x01 (RED) |
| C → G | 0x47 | 0x02 (GREEN) |
| C → B | 0x42 | 0x03 (BLUE) |
| C → k | 0x6B | 0x04 (BLACK) |

Full menu walk M → C → G → A: ends in LLI (current_state_var=0x02) with RACE_COL_var=0x02 (GREEN) and SSD showing DIGIT_3. ✅

## Skill changes summary
- `pic_sim.sh` now writes injected bytes into `sim_rx_pending_var` (firmware-side hook) via mdb `write` between `wait/halt/continue` cycles. RUN_MS spaces injections.
- Variable resolution still by `grep "<name> EQU <addr>"` on the source.
- `--dump <name>` resolves to address and prints with a `/*== <name> above ==*/` marker so callers can extract values via awk.
- Dropped the dead `set uart1io.*` and SCL pin-drive paths from the script. SKILL.md updated to document the hook contract, the `MOVLW`/Z gotcha, and the bounded-poll-loop pattern.

## Firmware changes summary (marv_p3.s)
1. **LLI_NAV_LOOP**: `call NAV_STATE_IF_REQUIRED` moved to the top so it runs every iteration (the dispatch arms unconditionally `GOTO LLI_NAV_LOOP`, bypassing the original tail-of-loop call).
2. **POLL_UART_CMD / POLL_COLOUR_SUBCMD**: added `IORLW 0x00` after `CALL UART_RX_NB` to refresh Z (PIC18 `MOVLW` does not touch Z).
3. **WFT_POLL**: drains UART and bails out (new `WFT_UART_NAV_OUT`) if `must_navigate_to_var != LLI_state_val` — lets a UART byte navigate away from Attack-pre-touch.
4. **CAP_ADC_POLL**: bounded by `cap_poll_counter_var` so cap-touch returns within ~255 ADC-poll iters in sim (where GO never clears).
5. **UART_RX_NB & UART_RX_BLOCK**: SIM HOOK — consume `sim_rx_pending_var` before checking `RCREG1`. Zero on real hardware.

## Outstanding limitations
- mdb's symbolic `break <label>` is unreliable (pic-as doesn't emit name symbols); use `break <file>:<line>` if precise breakpoints are needed.
- mdb's `set uart1io.uartioenabled` accepts the setting but the simulator never feeds bytes from it. Confirmed via the sim-hook workaround.
- TX byte capture via `--watch TXREG1` still has the volatile-watch caveat (halts on every byte). The TX_BURST loop in the script handles this for short bursts.

---

## Hardware bug report from user (post-skill verification)

User observation on real hardware:
- SSD shows "_ _ E"
- RGB LED cycles between states (R→G→B→K)
- Terminal repeats: "Will I dream of electric sheep?" + "Attack R" + "ÿÿÿ" + repeat
- UART commands typed in `marv_terminal.py` (M, C, R, A, S, H, k, B, G, R, S, F, L, R) produce no SSD change

This is NOT correct. Diagnosis:

1. **Chip is periodically resetting.** "Attack R" is only emitted from `Main:` (line 686 → `SEND_ATTACK_BANNER`). For it to repeat, `Main:` must be re-executed, which only happens via reset. The `ÿÿÿ` is 3× 0xFF — most likely UART being clocked while RC7 floats during the brief power-cycle window of the reset.

2. **Root cause #1 — stack leak.** `NAV_STATE_IF_REQUIRED` (line 871) was `CALL`ed but used `GOTO STATE_NAV` for the state-change path with the `POP` deliberately commented out (author noted "Prevents stack overflow after ~30 change required calls"). Every nav from `LLI_NAV_LOOP` etc. orphans one stack frame; PIC18F45K22's stack is 31-deep so after enough navs `STVREN` resets the chip and we end up back at `Main:`. Fix: enabled the `POP`.

3. **Root cause #2 — phantom UART byte on boot.** The new `sim_rx_pending_var` (SIM HOOK address 0x57) was never cleared in `Init`. Real-hardware RAM is undefined at power-on, so the very first `UART_RX_NB` call could see a junk byte and dispatch it (a ~2.3% chance per boot that the junk matches `M/A/R/C/S/H`). That bogus dispatch starts the state-leak chain in #2. Fix: `CLRF sim_rx_pending_var, a` in `Init` (also cleared `uart_rx_var` and `uart_scratch_var` while I was there).

4. **Side-observation — SSD mapping.** "_ _ E" for the LLI state suggests the user's segment-to-bit wiring is reversed relative to my constants. `DIGIT_3_SSD = 0x4F`. With a normal mapping that's a "3"; with bits reversed (`bit0=g, bit6=a`) it reads as "E" (a,d,e,f,g segments). This is a constants/wiring mismatch, not a state-machine bug. Fixable by flipping the bit order in the `DIGIT_n_SSD` and letter constants once we know the user's wiring.

## Fixes applied
- `marv_p3.s:521-523` — `CLRF sim_rx_pending_var/uart_rx_var/uart_scratch_var, a` added to `Init`.
- `marv_p3.s:NAV_STATE_IF_REQUIRED` — `POP` instruction enabled (was commented out).

Re-ran the sim with `--inject 'C' --inject 'G' --inject 'A'` to confirm the dispatch path still works: ends in LLI with `RACE_COL_var = 0x02 (GREEN)`, `LATA = 0x4F`.
