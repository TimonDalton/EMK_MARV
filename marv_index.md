# marv.s Reference Index

Searchable map + mechanism reference for `marv.s` (2208 lines). Pair with `p3_components/framework.s` when extracting sections for prac 3.

**Reading order:** if you're new, read [How it works](#how-it-works) first. If you know the system and just need a line-range lookup, jump to [File layout](#file-layout).

---

## ⚠ Known conflict to resolve at integration

**`marv.s` uses RC3 as right-motor reverse (IN4, line 594)** but the proven prac 3 I2C code uses **RC3 as SCL**. Same physical pin, two purposes.

| Option | Cost |
|---|---|
| Rewire motor IN4 to an unused pin (e.g. RD3) and update marv.s init | breadboard rework + ~2-line code edit |
| Switch I2C to MSSP2 on RD0/RD1 | conflicts with strobe LEDs (PORTD<0:2>); requires moving strobe LEDs too |
| Time-multiplex: disable MSSP1 during LLI race, enable during EEPROM access | complex state-management; error-prone |

Recommendation: **rewire motor IN4** (option 1).

---

## How it works

The eight mechanisms below describe execution flow — what triggers what, what state machines look like in motion, and the non-obvious details you'd miss from a code skim.

### 1. Interrupt system

PIC18F45K22 has a fixed interrupt vector at `0x08` (high-priority) and `0x18` (low-priority). marv.s uses **only high-priority** (no IPEN bit set in RCON), so all interrupts route to `0x08`. Reset jumps to `Init` at `0x00` (line 305), then `ORG 0x08` placement sends interrupts to the `ISR` label (lines 308-310).

The ISR (lines 311-326) **polls flags in software** — there's no hardware dispatch:
1. `BTFSC INTCON, 1` → `CALL INT0_HANDLER` if INT0IF set (line 317-318)
2. `BTFSC INTCON3, 0` → `CALL INT1_HANDLER` if INT1IF set (line 321-322)
3. `CALL CLEAR_ISR` clears both flags atomically (line 324, handler at 328-331)
4. `RETFIE 1` (line 326) — restores W/STATUS/BSR from shadow registers and re-enables global interrupts

**Why clear flags after handlers, not inside them?** Avoids a race where a second press during handler execution gets lost. Both flags are zeroed in one block at the end.

**Init enables it** (lines 462-476): set edge to rising via `INTCON2`, clear flags, set `INT0IE` and `INT1IE`, then `GIE`. Order matters — clear flags BEFORE enabling, or you'll take a spurious interrupt on startup.

### 2. Button → ISR flow

**Electrical:** buttons are active-high (rise when pressed → falls when released), with rising-edge interrupts (`INTEDG0/1 = 1`, lines 464-465). So the ISR actually fires on press. The wait-for-release logic at line 371-372 (`BTFSC PORTB,1` loop) blocks INT1_HANDLER until the user lifts off — debounce + ensures we only act once per press.

**Buttons are wired:**
- RB0 = yellow button → INT0
- RB1 = red button → INT1

**INT0_HANDLER (yellow, lines 333-365) — state-dependent dispatch:**

Reads `current_state_var`, branches by `XORLW`+`BZ` chain:
- In `selecting_state_val` → set `next_displayed_state_click_var,0` (line 354). Polled by `STATE_SELECT_INPUT` to advance to next candidate state in the cycle.
- In `calibrating_state_val` → set `cal_read_pressed_var,0` (line 358). Polled by `WAIT_FOR_LEFT_BUTTON_PRESS_CAL_STATE` to step through cal stages.
- In `LLI_state_val` → set `LLI_start_pressed_var,0` (line 362). Released-from-touch-wait signal.
- Default → `CALL do_reg_dump` (debug) and return.

So the same physical button has 3+ different software meanings depending on state — handler dispatches by state, sets a flag, returns. State code polls the flag.

**INT1_HANDLER (red, lines 366-402) — navigation:**

Always first waits for release (371-372). Then:
- If currently in SELECTING state (376-385) → user just chose the displayed candidate. Copy `display_select_state_var` → `must_navigate_to_var`, copy `current_state_symbol_var` → `SSD_OUT_var`. Done. Selection confirmed.
- If currently in FEEDBACK_COLOUR state (389-396) → lock the sensed colour: copy `sensor_C_read_colour_enum_var` → `RACE_COL_var`, set `must_navigate_to_var = LLI_state_val`. Effectively: "I've seen the race-colour, go race."
- Otherwise (398-401) → set `must_navigate_to_var = selecting_state_val`. Universal "back to menu" button.

### 3. State machine cycle

Five players. Watch how they pass control:

**`Main` (line 631):** does nothing but `GOTO STATE_SELECT_LOOP`.

**`STATE_SELECT_LOOP` (641-679):** force `current_state_var = 0` (selecting), then for each candidate state (cal, feedback, LLI, osc-delay) sets up display vars (`display_select_state_var`, `current_state_symbol_var`) and calls `STATE_SELECT_INPUT`. After cycling all four, `GOTO STATE_SELECT_LOOP` repeats. So in steady state the loop is constantly flashing through 4 options, ~1 cycle every few seconds.

**`STATE_SELECT_INPUT` (682-731):** for one candidate, runs a nested delay (`delay1` outer, `delay2` inner) that toggles `temp_var2` to **flash the SSD digit on/off at 50% duty cycle**. Each inner iteration polls two things:
- `next_displayed_state_click_var,0` set? (line 699) → user pressed yellow. RETURN, which falls back into `STATE_SELECT_LOOP` to advance to the next candidate.
- `CALL NAV_STATE_IF_REQUIRED` (line 703) → user pressed red, ISR wrote `must_navigate_to_var`. Detected here → state transitions immediately.

**`NAV_STATE_IF_REQUIRED` (787-803):** the polled gate.
- If `must_navigate_to_var == current_state_var` → just return (no change needed)
- Else → update `current_state_var` and `GOTO STATE_NAV`

Crucially, this is called from inside long-running states (`CAL_STATE`, `LLI_STATE`, `STATE_SELECT_INPUT`) so ISR-driven state changes don't have to wait for the state to finish.

**`STATE_NAV` (749-783):** dispatch. XORLW-BZ chain over known state values → `GOTO` the matching state label (`CAL_STATE`, `LLI_STATE`, `FEEDBACK_COLOUR_STATE`, `OSC_DELAY_STATE`). If no match → fall through to `GOTO STATE_SELECT_LOOP`.

**Why states `GOTO` (not `CALL`) and reach STATE_NAV via `GOTO`:** avoids stack growth. ISR sets must_navigate; poll detects it; jump (not call) to STATE_NAV; jump to new state. Returning to a previous state would imply a back-stack, which marv doesn't use. Comment at line 799 in the original: `POP ;;Prevents stack overflow after ~30 change required calls` (currently commented out — relies on GOTO instead).

### 4. PWM motor control

**Timer2 + CCP1/CCP2 generate two PWM channels.** Both share Timer2 as the time base; CCP1 outputs on RC2, CCP2 outputs on RC1.

**Period setup** (Init, lines 586-615):
- `PR2 = 19` (line 588) → Timer2 reloads every 20 counts
- Prescaler default = 1 (T2CON cleared at line 597; `BSF T2CON, 2` at line 607 enables Timer2 but leaves prescaler at 1:1)
- PWM period = `(PR2 + 1) × 4 × Tosc × prescale` = 20 × 4 × (1/4MHz) × 1 = **20 µs → 50 kHz**

> Note: the explore agent's earlier draft questioned this, but with PIC18 PWM the divider is ×4×prescale, not just ×prescale. 50 kHz is correct here.

**Duty cycle:** `CCPR1L` controls right motor duty (RC2 output), `CCPR2L` controls left motor duty (RC1 output). 10-bit duty: top 8 bits in CCPRxL, bottom 2 bits in CCPxCON<5:4>. marv.s only uses the top 8 bits — duty range is 0 (always low) to PR2 (~100%).

**Direction pins** are held low by default (lines 595-596): `LATC.0 = 0` (left IN2), `LATC.3 = 0` (right IN4). The TC1508A H-bridge interprets `IN1 high + IN2 low` = forward, so motors drive forward when CCP1/CCP2 produce duty > 0.

**Reverse path** in `set_motor_left/right` (1190-1216): if `motor_dir_*_var,0` is set, the handler drives the direction pin high (LATC.0 or LATC.3) **and sets CCPRxL = PWM_SPEED_STOP_val (0)** — because the H-bridge needs only one of IN1/IN2 high at a time. Forward = IN1 PWM, IN2 low. Reverse = IN1 low, IN2 high. (Actually the H-bridge would need reverse PWM on IN2 for variable reverse speed, but marv only does "reverse on/off" — adequate for line-following recovery.)

### 5. Sensor read pipeline

End-to-end colour classification: strobe each colour → read 3 ADC channels under each strobe → compute per-surface delta sums → pick smallest.

**Strobe LEDs** (PORTD<0:2>, controlled at 2030-2058):
- `set_strobe_leds_red` → PORTD = ...001
- `set_strobe_leds_green` → PORTD = ...010
- `set_strobe_leds_blue` → PORTD = ...100
- `set_strobe_leds_white` → PORTD = ...111
- `set_strobe_leds_off` → PORTD = ...000

**`strobe_and_save_sensor_readings` (1953-1971):** sequentially calls red → green → blue, after each calling `read_and_save_sensor_array_perception` (1991-2006) and copying the L/C/R readings into the strobe-specific vars (e.g. red strobe stores to `sensor_L_strobe_R_reading_var`, `sensor_C_strobe_R_reading_var`, `sensor_R_strobe_R_reading_var`). Total: 3 strobes × 3 sensors = 9 readings.

**`read_and_save_sensor_array_perception` (1991-2006):** for each sensor, load the appropriate `ADC_AN5/6/7` constant into ADCON0 (select channel + GO bit pattern), call `read_wreg_selected_adc_to_wreg`, store ADRESH into `sensor_L/C/R_reading_var`.

**`read_wreg_selected_adc_to_wreg` (2008-2026):** writes W → ADCON0, waits 8 NOPs for the S&H capacitor to charge, sets GO bit, polls until GO clears, returns ADRESH in W. Left-justified result (ADCON2 bit 7 = 1 at line 442) — top 8 bits in ADRESH.

**Colour classification (1686-1857):**
- `calculate_diff_sums` (1726-1857) — for each floor surface (R/G/B/W/k) compute the per-colour delta: `|red_strobe_reading - red_cal_for_this_surface|`, sum the three strobe-colour deltas, store in `red_floor_sum_delta_var` / `green_floor_sum_delta_var` / etc. Larger delta = worse match. The calibration data lives in the banked RAM region 0x60-0x8C — 5 surfaces × 3 sensors × 3 strobe colours = 45 cal values.
- `calc_lowest_diff_sum_colour_index_to_wreg` (1686-1724) — start with red as best, then for each successive surface, `CPFSLT` against current minimum, update if smaller. Return the winning enum in W. Written into `sensor_C_read_colour_enum_var` for the centre sensor (etc).

**Final classification** in `POLL_SENSORS_FOR_NEWEST_DRIVING_STATE_AND_UPDATE_STATE` (1457-1461): wraps everything, then converts the per-sensor colours into a 3-bit "perception bits" pattern and dispatches to a driving state.

### 6. CAL_STATE flow

User-facing sequence (lines 808-857):

1. SSD shows 'C'. Cycle the RGB feedback LED red→green→blue→black (`FLASH_RGB_DISP_DELAYED`).
2. **Red calibration:** set feedback LED red, wait for yellow button via `WAIT_FOR_LEFT_BUTTON_PRESS_CAL_STATE`, then `STROBE_SAVE_CAL_RED_FLOOR` (strobes RGB sensors, copies readings into the 9 `CAL_L/C/R_R/G/B_ON_RED_var` banked cells), blink white feedback twice.
3. Same for green, blue, white.
4. **Black calibration:** same as above but with SSD dot illuminated (`set_disp_SSD_dot`) to indicate the all-important black step.
5. After all 5 surfaces calibrated → `must_navigate_to_var = feedback_color_state_val`, call NAV.

**`WAIT_FOR_LEFT_BUTTON_PRESS_CAL_STATE` (859-868):** polls `cal_read_pressed_var,0` (set by INT0 handler in CAL state), then waits for `PORTB,0 = 0` (release), clears the flag. Classic press-then-release-then-clear sync pattern.

### 7. LLI_STATE flow

Race loop (lines 1052-1222):

**Setup (1054-1062):** SSD shows 'L'. Display RACE_COL_var colour on feedback LED. Block waiting for cap touch via `WAIT_FOR_LLI_TOUCH_START`.

**Main loop `LLI_NAV_LOOP` (1065-1092):**
1. `POLL_SENSORS_FOR_NEWEST_DRIVING_STATE_AND_UPDATE_STATE` (1066) — full sensor read + classification, writes `DRIVING_STATE_var`.
2. Dispatch on `DRIVING_STATE_var` via XORLW-BZ chain → jump to `set_LLI_left/centre/right/lost/stop`.

**Per-state motor dispatch (1108-1163):** each writes SSD digit, sets `motor_power_left_var`/`motor_power_right_var`, calls `set_motor_left`+`set_motor_right`, **`GOTO` back to LLI_NAV_LOOP** (no `RETURN` — keeps stack clean across infinite loop iterations).

**All-black stop condition (1085-1090, 1165-1170):** when classification returns STOP (all sensors black), `black_confirm_count_var` increments. Once it hits `0x20` (32 consecutive black reads), jump to `set_LLI_stop` → motors to 0. Then wait for red button press at PORTB<1>, fall through to `must_navigate_to_var = selecting_state_val`. Recent commit `d1f06c9` introduced this consecutive-count requirement to avoid spurious stops from a single noisy black reading.

**`RACE_COL_var` consumption:** picked up at LLI entry (line 1062) to set the feedback LED; the classification logic in `calc_perceived_colour_*` already uses the per-surface cal data so colour choice is implicit in the calibration values rather than a runtime check.

### 8. Capacitive touch (CTMU)

The PIC18F45K22 has a **Charge Time Measurement Unit** — a constant-current source on a selected ADC pin. We measure touch by:
1. Discharging the pin (drive low briefly)
2. Floating it
3. Letting CTMU current charge it for a fixed time
4. ADC-reading the resulting voltage

A bare pin has small capacitance → charges fast → ADC reading ~0x17.
A finger touching it adds parasitic capacitance → charges slower in the same window → ADC reading drops to ~0x10.

**`CAP_TOUCH_ROUTINE` (1363-1411)** sets up & samples:
- Line 1366-1369: drive RB2 low (discharge to known state), clear ANSELB bit (digital)
- Line 1374: TRIS RB2 to input (float)
- Line 1380-1384: ADCON0 → AN8 (which is RB2)
- Line 1388: enable CTMU current source (~0.55 µA at 5V)
- Line 1390-1393: set CTMU charge mode
- Line 1399: trigger ADC GO bit
- Line 1402: poll until conversion done, read ADRESH

**`WAIT_FOR_TOUCH` (1258-1356)** uses this with debouncing:
- Init: take 4 baseline readings, average → `touch_baseline_var` (1259-1276)
- Each poll cycle (`WFT_POLL` line 1280): take 16 ADC samples, average to filter noise (`touch_sample1/2/3_var` accumulator, lines 1282-1301)
- Compute `delta = baseline - current_reading` (1304-1306) — positive when touched (reading dropped)
- If delta > `WFT_THRESH` constant, increment `touch_count_var`; if count >= `WFT_DEBOUNCE`, confirm touch and return (1309-1320)
- If reading drifted HIGHER than baseline (no-touch drift), increment baseline to track (1332-1350)
- `touch_timer_var` increments each cycle; on timeout, give up (1352-1356)

The whole thing handles slow environmental drift (humidity, hand proximity changing baseline) while still detecting real touches by their characteristic sharp drop.

---

## File layout

| Section | Lines | What it does |
|---|---|---|
| Config bits | 1-11 | `PROCESSOR 18F45K22`, CONFIG, includes |
| Port mapping consts | 16-23 | SSD_PORT=PORTA, DISP_LED_PORT=PORTB<5:7>, STROBE_LED_PORT=PORTD<0:2>; buttons PORTB<0:1>, sensors PORTE<0:2>, motors PORTC<0:3> |
| Vars — access bank | 25-136 | 0x00-0x5F EQUs |
| Vars — banked-only | 138-200 | 0x60-0x8C calibration (per-sensor × per-surface RGB) |
| State / colour / SSD constants | 200-302 | See [Constants](#constants) |
| Reset vector + ISR entry | 303-326 | `GOTO Init`, `ORG 0x08`, `GOTO ISR` |
| INT0_HANDLER (yellow) | 333-365 | State-aware: sets press flags |
| INT1_HANDLER (red) | 366-402 | Navigation trigger via `must_navigate_to_var` |
| Init / Setup | 404-624 | Oscillator (4 MHz), ports, ADC, PWM, INT0/1, cal defaults |
| Main entry | 631-633 | `GOTO STATE_SELECT_LOOP` |
| STATE_SELECT_LOOP | 641-679 | Cycles cal → feedback → LLI → osc-delay candidates |
| STATE_SELECT_INPUT | 682-731 | Flash SSD digit, poll for press, call NAV_STATE_IF_REQUIRED |
| STATE_NAV | 749-783 | Dispatch on `current_state_var` via XORLW-BZ chain |
| NAV_STATE_IF_REQUIRED | 787-803 | Polled — jumps to STATE_NAV if must_navigate differs |
| CAL_STATE | 808-958 | Full RGB calibration sequence per surface |
| FEEDBACK_COLOUR_STATE | 955-1052 | Read centre sensor, classify, lock via INT1 |
| LLI_STATE | 1052-1222 | Race loop |
| `set_motor_left` / `set_motor_right` | 1190-1216 | Write CCPR2L / CCPR1L, or reverse via direction pin |
| Cap touch — `MAIN_CAP_ROUTINE` | 1226-1248 | Double-sample touch on RB2 |
| Cap touch — `WAIT_FOR_TOUCH` | 1258-1356 | Baseline cal + 16-sample average + debounce |
| Cap touch — `CAP_TOUCH_ROUTINE` | 1363-1411 | CTMU discharge → charge → ADC |
| `_TOUCH_1MS_DELAY` / `_TOUCH_1S_DELAY` | 1416-1448 | ~1 ms / ~100 ms (named "1S" misleadingly) |
| `LLI_SELECT_COLOUR` | 1451-1455 | Stub — unimplemented |
| `POLL_SENSORS_FOR_NEWEST_DRIVING_STATE` | 1457-1461 | Sensor read → classification → DRIVING_STATE_var |
| `OSC_DELAY_STATE` | 1574-1614 | Idle/delay state |
| `TIMEOUT_333ms` / `TIMEOUT_167ms` | 1586-1611 | Named delays |
| `TIMEOUT_LED_WAIT_LED_GET_HIGH` | 1614-1635 | ~20 µs strobe LED rise time |
| `poll_sensors_for_average_detected_colour` | 1642-1648 | Wrapper (pass-through currently) |
| `poll_sensors_for_detected_colour` | 1650-1655 | RGB strobe, save 3 readings per sensor |
| `calc_perceived_colour_L/C/R` | 1664-1684 | Best-match floor colour per sensor |
| `calc_lowest_diff_sum_colour_index_to_wreg` | 1686-1724 | Find lowest delta-sum surface |
| `calculate_diff_sums` | 1726-1857 | Weighted colour deltas for all 5 surfaces |
| `abs_val_subtraction_in_wreg` | 1861-1867 | |x - W| in W |
| `set_current_strobe_to_L/C/R` | 1869-1885 | Copy strobe readings → working vars |
| `set_current_sensor_cal_to_L/C/R` | 1887-1951 | Copy cal data per sensor → working vars |
| `strobe_and_save_sensor_readings` | 1953-1971 | RGB strobe + read all 3 sensors → strobe arrays |
| `save_sensor_reading_to_strobe_R/G/B` | 1973-1989 | Sensor reads → strobe_*_var |
| `read_and_save_sensor_array_perception` | 1991-2006 | ADC L/C/R (AN5/6/7) |
| `read_wreg_selected_adc_to_wreg` | 2008-2026 | ADCON0 = W, NOPs, GO, poll, return ADRESH |
| `set_strobe_leds_R/G/B/W/off` | 2030-2058 | PORTD<0:2> control |
| `FLASH_SSD` | 2062-2073 | Flash 7-seg twice (333 ms each) |
| `SET_SSD` | 2076-2078 | Copy SSD_OUT_var → SSD_PORT |
| `do_reg_dump` | 2081-2087 | Show 'r' on SSD (debug) |
| `BLINK_WHITE_DISP_TWICE_DELAYED` | 2090-2099 | RGB white blink ×2 |
| `FLASH_RGB_DISP_DELAYED` | 2101-2110 | RGB cycle red→green→blue→black |
| `set_disp_rgb_R/G/B/W/k` | 2112-2140 | PORTB<5:7> set |
| `set_disp_SSD_dot` / `clear_disp_SSD_dot` | 2142-2147 | SSD dot (bit 7) control |
| `display_error` | 2149-2157 | Error-flag stub |
| `MUL1375_WREG` | 2163-2200 | x × 1.375, capped at 255 |

---

## Constants

### State values (lines 227-232)
| Name | Value | Meaning |
|---|---|---|
| `selecting_state_val` | 0x0 | Menu / state-cycle |
| `calibrating_state_val` | 0x1 | CAL_STATE entry |
| `LLI_state_val` | 0x2 | LLI_STATE entry (race) |
| `feedback_color_state_val` | 0x3 | FEEDBACK_COLOUR_STATE entry |
| `osc_delay_state_val` | 0x5 | OSC_DELAY_STATE entry |

> Prac 3 adds menu states 0x10-0x15 (chosen to not collide) — see `framework.s` SECTION 04.

### Colour values (lines 237-242)
| Name | Value |
|---|---|
| `RED_COLOUR_STATE_val` | 0x1 |
| `GREEN_COLOUR_STATE_val` | 0x2 |
| `BLUE_COLOUR_STATE_val` | 0x3 |
| `BLACK_COLOUR_STATE_val` | 0x4 |
| `WHITE_COLOUR_STATE_val` | 0x5 |

### Driving / PWM values (lines 285-293)
| Name | Value |
|---|---|
| `LEFT_DRIVING_STATE_val` | 0x0 |
| `CENTRE_DRIVING_STATE_val` | 0x1 |
| `RIGHT_DRIVING_STATE_val` | 0x2 |
| `STOP_DRIVING_STATE_val` | 0x3 |
| `LOST_DRIVING_STATE_val` | 0x4 |
| `PWM_SPEED_FULL_LEFT_val` | 16 |
| `PWM_SPEED_FULL_RIGHT_val` | 15 |
| `PWM_SPEED_STOP_val` | 0 |

---

## Variable write-locations

Use this when figuring out who controls what.

| Variable | Written by (line refs) |
|---|---|
| `must_navigate_to_var` | INT1_HANDLER (395, 400), CAL_STATE exit (852), LLI_STATE exit (~1104), Init (480) |
| `current_state_var` | STATE_SELECT_INPUT (739), NAV_STATE_IF_REQUIRED (751, 798) |
| `RACE_COL_var` | Init default RED (618), INT1_HANDLER feedback path (393) |
| `DRIVING_STATE_var` | Init LOST (622), set_driving_state_from_saved_sensor_colour_perception_array (~1504-1521), LLI_STATE motor dispatch (1110, 1124, 1138, 1152, 1175) |
| `SSD_OUT_var` | STATE_SELECT_INPUT (740), state entry blocks (via `current_state_symbol_var`) |
| `DISP_LED_OUT_VAR` | declared but currently bypassed — RGB writes go direct to PORTB<5:7> |
| `sensor_C_read_colour_enum_var` | calc_perceived_colour_C (1676); read by FEEDBACK_COLOUR_STATE (973-989) |
| `cal_read_pressed_var` | INT0_CAL_PRESSED (358) sets; CAL_STATE wait-release clears (866) |
| `LLI_start_pressed_var` | INT0_LLI_PRESSED (362) sets; LLI_STATE entry clears (~1107) |
| `next_displayed_state_click_var` | INT0_SELECTING_STATE_PRESS (354) sets; STATE_SELECT_INPUT clears (684) |
| `black_confirm_count_var` | LLI_STATE STOP path (1086) increments; reset on non-black classification |
| `motor_power_left_var` / `motor_power_right_var` | Init (608-609), each LLI per-state handler |

---

## Port usage summary

| Port | Bits | Purpose |
|---|---|---|
| PORTA | all | 7-seg display (SSD) |
| PORTB | <0> | Yellow button (INT0) |
| PORTB | <1> | Red button (INT1) |
| PORTB | <2> | Cap touch input (AN8) — CTMU sampling |
| PORTB | <5:7> | RGB feedback LED |
| PORTC | <0> | Left motor IN2 (reverse, digital) |
| PORTC | <1> | Left motor IN1 (PWM via CCP2) |
| PORTC | <2> | Right motor IN3 (PWM via CCP1) |
| PORTC | <3> | Right motor IN4 (reverse, digital) ← **conflicts with prac 3 I2C SCL** |
| PORTC | <4> | UNUSED in marv.s — will be I2C SDA in prac 3 |
| PORTC | <5> | UNUSED |
| PORTC | <6> | UNUSED in marv.s — will be UART TX in prac 3 |
| PORTC | <7> | UNUSED in marv.s — will be UART RX in prac 3 |
| PORTD | <0:2> | Strobe LEDs (R/G/B for sensor read) |
| PORTD | <3:7> | UNUSED |
| PORTE | <0:2> | Sensors L/C/R (AN5/AN6/AN7, analog input) |

---

## Quick "where do I find ___?"

- **How does the red button trigger a state change?** → INT1_HANDLER (366-402), specifically lines 380 (general fallback to selecting), 395 (FEEDBACK→LLI lock-and-go)
- **How is a colour locked in after sensor read?** → INT1_HANDLER lines 389-396: `sensor_C_read_colour_enum_var` → `RACE_COL_var`, must_navigate=LLI
- **Where's PWM duty cycle set?** → set_motor_left/right (1190-1216) writing CCPR2L / CCPR1L
- **Where's PWM frequency set?** → Init line 588: `PR2 = 19` → 50 kHz at 4 MHz Fosc, prescale 1
- **How is RGB calibration data laid out?** → CAL_*_var EQUs banked region 0x60-0x8C; surface × sensor × strobe-colour
- **How is the SSD updated?** → `SSD_OUT_var` → `SET_SSD` (2076) → PORTA write
- **Where's the strobe sequence for sensor read?** → strobe_and_save_sensor_readings (1953-1971), sets PORTD<0:2> and reads all 3 sensors per colour
- **How is cap touch baseline managed?** → WAIT_FOR_TOUCH (1258-1356) — 4 init samples, then drift-tracking via baseline increment on no-touch
- **Why use GOTO between states instead of CALL?** → Avoid stack growth across infinite nav cycles; comment on line 799 references this

---

## Notes for prac 3 integration

- Re-use marv.s init for oscillator, PORTA-E config (lines 406-624). **Append** UART init + I2C init + RC1IE enable at end of Init block.
- The `STATE_SELECT_LOOP` button-cycle pattern (641-679) becomes optional in prac 3 — main nav is via UART, but the button parallel is required for the colour state per P3.2.3.
- ISR additions (SECTION 06 of framework): add UART RX branch **at top** — check RC1IF, call new UART_RX_HANDLER, then fall through to existing INT0/INT1 logic.
- `RACE_COL_var` is the integration point for colour-select: both UART chars and button menu paths write to it, then ATTACK_STATE / LLI_STATE consume it.
- **Don't forget PEIE** (INTCON bit 6) — peripheral interrupts (UART RX is one) only route through the ISR when PEIE is enabled, separate from GIE.
