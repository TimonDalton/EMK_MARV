import json
import math
import os
import queue
import signal
import threading

import matplotlib.pyplot as plt
import matplotlib.animation as animation
from matplotlib.widgets import Button, TextBox
import serial

PORT    = '/dev/cu.usbserial-0001'
BAUD    = 9600
LABELS  = ['L_R','L_G','L_B','C_R','C_G','C_B','R_R','R_G','R_B']
HISTORY = 100

FLOORS     = ['red', 'green', 'blue', 'white', 'black']
MULTIPLIER = 3
SCALE_WB   = 1.375
RACE_COL   = 'red'

# Resistor recommendation target: ADC peak reading we want to aim for
TARGET_PEAK = 185

# E12 standard resistor series (one decade)
_E12 = [1.0, 1.2, 1.5, 1.8, 2.2, 2.7, 3.3, 3.9, 4.7, 5.6, 6.8, 8.2]

CONFIG_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'sensor_config.json')

# ── Helpers ───────────────────────────────────────────────────────────────────

def nearest_e12(value):
    """Round value to nearest E12 standard resistor, returned as a string."""
    if value <= 0:
        return '?'
    decade = 10 ** math.floor(math.log10(value))
    nearest = min(_E12, key=lambda x: abs(x - value / decade))
    result = nearest * decade
    if result >= 1e6:
        return f'{result / 1e6:.2g}M'
    if result >= 1e3:
        return f'{result / 1e3:.2g}k'
    return f'{result:.0f}'


def strobe_floor_avg(floor_name, strobe_offsets):
    """Average reading across L/C/R sensors for one strobe channel on one floor."""
    return sum(cal[floor_name][i] for i in strobe_offsets) / 3


# ── Serial ────────────────────────────────────────────────────────────────────
frame_queue  = queue.Queue(maxsize=10)
latest_frame = [128] * 9
data         = [[0] * HISTORY for _ in range(9)]
ser          = serial.Serial(PORT, BAUD, timeout=1)


def serial_reader():
    while True:
        if ser.read(1) == b'\xaa':
            raw = ser.read(9)
            if len(raw) == 9:
                try:
                    frame_queue.put_nowait(list(raw))
                except queue.Full:
                    pass


threading.Thread(target=serial_reader, daemon=True).start()

# ── Calibration ───────────────────────────────────────────────────────────────
cal = {f: None for f in FLOORS}

# ── Colour detection ──────────────────────────────────────────────────────────

def _sensor_delta(r, g, b, cal_r, cal_g, cal_b, floor):
    if floor == 'red':
        return abs(cal_r - r) * MULTIPLIER + abs(cal_g - g) + abs(cal_b - b)
    elif floor == 'green':
        return abs(cal_r - r) + abs(cal_g - g) * MULTIPLIER + abs(cal_b - b)
    elif floor == 'blue':
        return abs(cal_r - r) + abs(cal_g - g) + abs(cal_b - b) * MULTIPLIER
    else:
        return (abs(cal_r - r) + abs(cal_g - g) + abs(cal_b - b)) * SCALE_WB


def detect_sensor_colour(frame, offset):
    r, g, b = frame[offset], frame[offset + 1], frame[offset + 2]
    best, best_score = '???', float('inf')
    for floor in FLOORS:
        if cal[floor] is None:
            continue
        score = _sensor_delta(r, g, b,
                               cal[floor][offset],
                               cal[floor][offset + 1],
                               cal[floor][offset + 2],
                               floor)
        if score < best_score:
            best_score, best = score, floor
    return best


def calc_driving_state(l_col, c_col, r_col):
    if l_col == 'black' and c_col == 'black' and r_col == 'black':
        return 'STOP'
    bits = ((1 if l_col == RACE_COL else 0) << 2 |
            (1 if c_col == RACE_COL else 0) << 1 |
            (1 if r_col == RACE_COL else 0))
    if bits in (0b001, 0b011):
        return 'RIGHT'
    if bits == 0b010:
        return 'CENTRE'
    if bits in (0b100, 0b110):
        return 'LEFT'
    return 'LOST'


# ── Resistor state ────────────────────────────────────────────────────────────
# Two resistors per LED channel, pre-filled from the circuit diagram
resistor_vals = {
    'upper': {'red': 292.13,  'green': 284.07,  'blue': 279.15},
    'lower': {'red': 37916.47, 'green': 35415.11, 'blue': 33870.15},
}

# ── Figure ────────────────────────────────────────────────────────────────────
fig = plt.figure(figsize=(13, 11))
fig.patch.set_facecolor('#1a1a1a')

# Live plot
ax_plot = fig.add_axes([0.07, 0.51, 0.90, 0.46])
ax_plot.set_facecolor('#252525')
ax_plot.set_ylim(0, 255)
ax_plot.set_xlim(0, HISTORY)
ax_plot.tick_params(colors='#aaaaaa')
for sp in ax_plot.spines.values():
    sp.set_edgecolor('#555555')

PLOT_CLR = ['#ff4444', '#44dd44', '#4488ff',
            '#ff9999', '#99dd99', '#99bbff',
            '#ffcccc', '#ccffcc', '#ccddff']
lines = [ax_plot.plot([], [], color=PLOT_CLR[i], label=LABELS[i], linewidth=1)[0]
         for i in range(9)]
ax_plot.legend(loc='upper right', facecolor='#252525', labelcolor='#cccccc', fontsize=7)

# ── Calibration buttons ───────────────────────────────────────────────────────
BTN_CFG = [
    ('red',   'Cal Red',   '#992222', 'white'),
    ('green', 'Cal Green', '#226622', 'white'),
    ('blue',  'Cal Blue',  '#224488', 'white'),
    ('white', 'Cal White', '#cccccc', 'black'),
    ('black', 'Cal Black', '#444444', 'white'),
]
btn_objects = []
cal_dots    = []

for i, (floor, label, face, txtcol) in enumerate(BTN_CFG):
    ax_btn = fig.add_axes([0.07 + i * 0.178, 0.40, 0.155, 0.08])
    btn = Button(ax_btn, label, color=face, hovercolor=face)
    btn.label.set_color(txtcol)
    btn.label.set_fontsize(9)
    btn.label.set_fontweight('bold')
    btn_objects.append(btn)
    dot = fig.text(0.148 + i * 0.178, 0.385, '●',
                   color='#444444', fontsize=10, ha='center', va='center')
    cal_dots.append(dot)

DOT_CLR = ['#ff5555', '#55cc55', '#5599ff', '#dddddd', '#999999']


def make_cal_cb(floor, idx):
    def cb(event):
        cal[floor] = list(latest_frame)
        cal_dots[idx].set_color(DOT_CLR[idx])
        print(f"\n=== CAL {floor.upper()} ===")
        for lbl, val in zip(LABELS, cal[floor]):
            print(f"  {lbl}: {val}")
        fig.canvas.draw_idle()
    return cb


for i, (floor, *_) in enumerate(BTN_CFG):
    btn_objects[i].on_clicked(make_cal_cb(floor, i))

# ── Resistor input section ────────────────────────────────────────────────────
LED_KEYS  = ['red', 'green', 'blue']
LED_NAMES = ['Red LED', 'Green LED', 'Blue LED']

# Column x-positions and widths
COL_X = [0.07, 0.285, 0.50]
COL_W = 0.185

fig.text(0.07, 0.372, 'LED Resistors', color='#aaaaaa', fontsize=8.5,
         va='center', fontweight='bold')

# Column headers
for i, name in enumerate(LED_NAMES):
    fig.text(COL_X[i] + COL_W / 2, 0.363, name,
             color='#cccccc', fontsize=8, ha='center', va='center')

ROW_KEYS   = ['upper', 'lower']
ROW_LABELS = ['Upper / Base R (Ω)', 'Lower / Drive R (Ω)']
ROW_Y      = [0.305, 0.235]   # bottom edge of each TextBox row
ROW_H      = 0.052

tb_objects = {}   # (row_key, led_key) -> TextBox

for row_i, (row_key, row_label) in enumerate(zip(ROW_KEYS, ROW_LABELS)):
    # Row label above each row
    fig.text(0.07, ROW_Y[row_i] + ROW_H + 0.008, row_label,
             color='#888888', fontsize=7.5, va='bottom')

    for col_i, led_key in enumerate(LED_KEYS):
        ax_tb = fig.add_axes([COL_X[col_i], ROW_Y[row_i], COL_W, ROW_H])
        init = f'{resistor_vals[row_key][led_key]:.2f}'
        tb = TextBox(ax_tb, '', initial=init, color='#2a2a35', hovercolor='#3a3a50')

        def make_submit(rk, lk):
            def on_submit(text):
                try:
                    resistor_vals[rk][lk] = float(text)
                except ValueError:
                    pass
            return on_submit

        tb.on_submit(make_submit(row_key, led_key))
        tb_objects[(row_key, led_key)] = tb

# Analyse + Save buttons (right of both resistor rows, spanning their combined height)
BTN_RIGHT_X  = 0.725
BTN_RIGHT_W  = 0.255
BOTH_ROWS_BOTTOM = ROW_Y[1]
BOTH_ROWS_TOP    = ROW_Y[0] + ROW_H
BOTH_HEIGHT      = BOTH_ROWS_TOP - BOTH_ROWS_BOTTOM   # ~0.122

ax_analyse = fig.add_axes([BTN_RIGHT_X, BOTH_ROWS_BOTTOM + BOTH_HEIGHT * 0.52,
                            BTN_RIGHT_W, BOTH_HEIGHT * 0.46])
btn_analyse = Button(ax_analyse, 'Analyse', color='#334466', hovercolor='#4a5f88')
btn_analyse.label.set_color('white')
btn_analyse.label.set_fontweight('bold')
btn_analyse.label.set_fontsize(9)

ax_save = fig.add_axes([BTN_RIGHT_X, BOTH_ROWS_BOTTOM,
                         BTN_RIGHT_W, BOTH_HEIGHT * 0.46])
btn_save = Button(ax_save, 'Save Config', color='#2d4a2d', hovercolor='#3d6a3d')
btn_save.label.set_color('white')
btn_save.label.set_fontweight('bold')
btn_save.label.set_fontsize(9)

# ── Recommendation display ────────────────────────────────────────────────────
ax_rec = fig.add_axes([0.07, 0.145, 0.90, 0.075])
ax_rec.set_facecolor('#1e2020')
ax_rec.axis('off')
for sp in ax_rec.spines.values():
    sp.set_edgecolor('#333333')

rec_header = ax_rec.text(0.005, 0.88, 'Calibrate floors then click Analyse',
                          color='#666666', fontsize=7.5, va='top', style='italic',
                          transform=ax_rec.transAxes)
rec_txts = [
    ax_rec.text(0.005, 0.62 - i * 0.30, '', color='#aaaaaa', fontsize=8,
                va='top', transform=ax_rec.transAxes)
    for i in range(3)
]

# Strobe channel indices in the 9-byte frame (L, C, R sensor readings for each strobe colour)
STROBE_OFFSETS = {
    'red':   (0, 3, 6),
    'green': (1, 4, 7),
    'blue':  (2, 5, 8),
}


def run_analyse(_):
    cal_floors = [f for f in FLOORS if cal[f] is not None]
    if len(cal_floors) < 2:
        rec_header.set_text('Need at least 2 calibrated floors to analyse.')
        for t in rec_txts:
            t.set_text('')
        fig.canvas.draw_idle()
        return

    rec_header.set_text('')

    for i, led_key in enumerate(LED_KEYS):
        offsets = STROBE_OFFSETS[led_key]
        avgs    = {f: strobe_floor_avg(f, offsets) for f in cal_floors}
        peak    = max(avgs.values())
        trough  = min(avgs.values())
        spread  = peak - trough

        r_lower = resistor_vals['lower'][led_key]
        r_upper = resistor_vals['upper'][led_key]

        # Brightness recommendation — scale lower R to hit TARGET_PEAK
        # I_LED ∝ 1/(R_upper + R_lower) ≈ 1/R_lower since R_lower >> R_upper
        if peak > 0:
            r_total_new = (r_upper + r_lower) * (peak / TARGET_PEAK)
            r_lower_new = max(r_total_new - r_upper, 100.0)
            r_rec = nearest_e12(r_lower_new)
        else:
            r_rec = '?'

        if peak > 230:
            bright_msg = f'Saturating (peak={peak:.0f}) → lower R ↑ to ~{r_rec}Ω'
            clr = '#ff7777'
        elif peak < 60:
            bright_msg = f'Too dim (peak={peak:.0f}) → lower R ↓ to ~{r_rec}Ω'
            clr = '#ff9944'
        else:
            bright_msg = f'Brightness OK (peak={peak:.0f}, target {TARGET_PEAK})'
            clr = '#88cc88'

        if spread < 50:
            disc_msg = f'Poor floor discrimination (spread={spread:.0f}) — recheck circuit'
            clr = '#ff7777'
        elif spread < 100:
            disc_msg = f'Moderate discrimination (spread={spread:.0f})'
        else:
            disc_msg = f'Good discrimination (spread={spread:.0f} ✓)'

        line = f'{led_key.capitalize()} strobe:  {bright_msg}  |  {disc_msg}'
        rec_txts[i].set_text(line)
        rec_txts[i].set_color(clr)

    fig.canvas.draw_idle()


def save_config(_):
    config = {
        'resistors': resistor_vals,
        'calibration': {f: cal[f] for f in FLOORS if cal[f] is not None},
    }
    with open(CONFIG_FILE, 'w') as fp:
        json.dump(config, fp, indent=2)
    rec_header.set_text(f'Saved → {os.path.basename(CONFIG_FILE)}')
    print(f"\n{'='*40}\nFULL CALIBRATION DUMP\n{'='*40}")
    for floor in FLOORS:
        if cal[floor] is not None:
            print(f"  {floor.upper()}: {dict(zip(LABELS, cal[floor]))}")
    print('='*40)
    fig.canvas.draw_idle()


# Load saved config if it exists
if os.path.exists(CONFIG_FILE):
    try:
        with open(CONFIG_FILE) as fp:
            _saved = json.load(fp)
        resistor_vals.update(_saved.get('resistors', {}))
        for f, v in _saved.get('calibration', {}).items():
            if f in cal:
                cal[f] = v
                idx = list(BTN_CFG).index(next(x for x in BTN_CFG if x[0] == f))
                cal_dots[idx].set_color(DOT_CLR[idx])
        # Refresh TextBox display values
        for (rk, lk), tb in tb_objects.items():
            tb.set_val(f'{resistor_vals[rk][lk]:.2f}')
    except Exception:
        pass

btn_analyse.on_clicked(run_analyse)
btn_save.on_clicked(save_config)

# ── Status bar ────────────────────────────────────────────────────────────────
ax_status = fig.add_axes([0.07, 0.035, 0.90, 0.095])
ax_status.set_facecolor('#252525')
ax_status.axis('off')

SENSOR_X = [0.15, 0.42, 0.68]
sensor_txts = []
for x, lbl in zip(SENSOR_X, ['L', 'C', 'R']):
    ax_status.text(x, 0.82, lbl, color='#888888', fontsize=9,
                   ha='center', va='center', transform=ax_status.transAxes)
    t = ax_status.text(x, 0.32, '---', color='#888888', fontsize=13,
                       ha='center', va='center', fontweight='bold',
                       transform=ax_status.transAxes)
    sensor_txts.append(t)

drive_txt = ax_status.text(0.88, 0.5, 'Drive: ---', color='#ffff44',
                            fontsize=12, ha='center', va='center',
                            fontweight='bold', transform=ax_status.transAxes)

COLOUR_CLR = {'red': '#ff5555', 'green': '#55dd55', 'blue': '#6699ff',
              'white': '#ffffff', 'black': '#999999', '???': '#666666'}
DRIVE_CLR  = {'CENTRE': '#55dd55', 'LEFT': '#ffaa33', 'RIGHT': '#ffaa33',
              'STOP': '#ff4444', 'LOST': '#ff44ff'}

# ── Animation ─────────────────────────────────────────────────────────────────

def update(_):
    global latest_frame
    try:
        frame = frame_queue.get_nowait()
        latest_frame = frame

        for i, val in enumerate(frame):
            data[i].append(val)
            data[i] = data[i][-HISTORY:]
            lines[i].set_data(range(len(data[i])), data[i])

        if any(cal[f] is not None for f in FLOORS):
            colours = [detect_sensor_colour(frame, off) for off in (0, 3, 6)]
            state   = calc_driving_state(*colours)
            for txt, col in zip(sensor_txts, colours):
                txt.set_text(col.capitalize())
                txt.set_color(COLOUR_CLR.get(col, '#888888'))
            drive_txt.set_text(f'Drive: {state}')
            drive_txt.set_color(DRIVE_CLR.get(state, '#ffff44'))

    except queue.Empty:
        pass
    return lines


signal.signal(signal.SIGINT, lambda *_: plt.close('all'))
ani = animation.FuncAnimation(fig, update, interval=50, blit=False)
plt.show()
ser.close()
