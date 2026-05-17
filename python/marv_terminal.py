"""MARV serial terminal — Mac counterpart to marv_interface.s.

Tkinter GUI with a scrolling terminal view and quick-select buttons for the
P3.2.2.2 command menu. Buttons send single-char commands; the entry box at the
bottom is for typing free text (mainly the H-mode hotload slogan).
"""

import queue
import signal
import sys
import threading
import tkinter as tk
from tkinter import scrolledtext, ttk

import serial
import serial.tools.list_ports

# ── Config ────────────────────────────────────────────────────────────────────
PORT         = '/dev/cu.usbserial-0001'
BAUD         = 9600
CR           = b'\r'
POLL_MS      = 30           # GUI poll interval for incoming serial bytes
HISTORY_MAX  = 50_000       # terminal char limit before trimming

# ── Serial ────────────────────────────────────────────────────────────────────
rx_queue: queue.Queue = queue.Queue()
ser: serial.Serial | None = None


def open_serial(port: str = PORT, baud: int = BAUD) -> serial.Serial | None:
    try:
        return serial.Serial(port, baud, timeout=0.1)
    except serial.SerialException as exc:
        print(f"[!] Could not open {port}: {exc}", file=sys.stderr)
        return None


def serial_reader():
    """Background thread: read bytes from MARV, push to rx_queue."""
    while True:
        if ser is None or not ser.is_open:
            return
        try:
            data = ser.read(256)
        except serial.SerialException:
            return
        if data:
            rx_queue.put(data)


def send_bytes(data: bytes):
    if ser is None or not ser.is_open:
        return
    try:
        ser.write(data)
    except serial.SerialException as exc:
        print(f"[!] Write failed: {exc}", file=sys.stderr)


def send_cmd(ch: str):
    """Send a single-char command followed by CR (Enter)."""
    send_bytes(ch.encode('latin-1') + CR)
    append_terminal(f"> {ch}\n", tag='local')


def send_line(text: str):
    """Send arbitrary text followed by CR."""
    send_bytes(text.encode('latin-1') + CR)
    append_terminal(f"> {text}\n", tag='local')


# ── GUI ───────────────────────────────────────────────────────────────────────
root = tk.Tk()
root.title(f"MARV Terminal — {PORT} @ {BAUD}")
root.configure(bg='#1a1a1a')
root.geometry('820x620')

# ── Terminal display ──────────────────────────────────────────────────────────
term_frame = tk.Frame(root, bg='#1a1a1a')
term_frame.pack(fill='both', expand=True, padx=8, pady=(8, 4))

terminal = scrolledtext.ScrolledText(
    term_frame, bg='#1e1e1e', fg='#dddddd', insertbackground='#dddddd',
    font=('Menlo', 11), wrap='word', height=18, relief='flat',
)
terminal.pack(fill='both', expand=True)
terminal.tag_config('local', foreground='#66ccff')     # echoed local sends
terminal.tag_config('rx',    foreground='#dddddd')     # MARV → terminal
terminal.tag_config('sys',   foreground='#888888', font=('Menlo', 10, 'italic'))
terminal.config(state='disabled')


def append_terminal(text: str, tag: str = 'rx'):
    terminal.config(state='normal')
    terminal.insert('end', text, tag)
    # Trim if it gets too long
    if int(terminal.index('end-1c').split('.')[0]) > 2000:
        terminal.delete('1.0', f'{HISTORY_MAX // 80}.0')
    terminal.see('end')
    terminal.config(state='disabled')


def clear_terminal():
    terminal.config(state='normal')
    terminal.delete('1.0', 'end')
    terminal.config(state='disabled')


# ── Quick-select buttons ──────────────────────────────────────────────────────
btn_frame = tk.Frame(root, bg='#1a1a1a')
btn_frame.pack(fill='x', padx=8, pady=4)


def make_btn(parent, label, command, color='#2d3a4a'):
    b = tk.Button(
        parent, text=label, command=command,
        bg=color, fg='black', activebackground='#4a5f88',
        activeforeground='black', font=('Helvetica', 11, 'bold'),
        relief='flat', padx=10, pady=6, borderwidth=0,
    )
    return b


# Main menu row: M (CYOC), C, R, A, S, H
main_row = tk.LabelFrame(btn_frame, text='Main menu', bg='#1a1a1a', fg='#aaaaaa',
                         font=('Helvetica', 9), bd=1, relief='flat')
main_row.pack(fill='x', pady=(0, 4))

MAIN_BUTTONS = [
    ('M  (CYOC)',  'M', '#553355'),
    ('C  Colour',  'C', '#334466'),
    ('R  Reference', 'R', '#334466'),
    ('A  Attack',  'A', '#664433'),
    ('S  Simulate', 'S', '#334466'),
    ('H  Hotload', 'H', '#334466'),
]
for label, ch, col in MAIN_BUTTONS:
    make_btn(main_row, label, lambda c=ch: send_cmd(c), color=col).pack(
        side='left', padx=3, pady=4, fill='x', expand=True)

# Colour submenu row: R, G, B, k
col_row = tk.LabelFrame(btn_frame, text='Colour select (after C)',
                        bg='#1a1a1a', fg='#aaaaaa', font=('Helvetica', 9),
                        bd=1, relief='flat')
col_row.pack(fill='x', pady=(0, 4))

COLOUR_BUTTONS = [
    ('R  Red',   'R', '#992222'),
    ('G  Green', 'G', '#226622'),
    ('B  Blue',  'B', '#224488'),
    ('k  Black', 'k', '#444444'),
]
for label, ch, col in COLOUR_BUTTONS:
    make_btn(col_row, label, lambda c=ch: send_cmd(c), color=col).pack(
        side='left', padx=3, pady=4, fill='x', expand=True)

# Simulate submenu row: S, F, L, R
sim_row = tk.LabelFrame(btn_frame, text='Simulate (after S)',
                        bg='#1a1a1a', fg='#aaaaaa', font=('Helvetica', 9),
                        bd=1, relief='flat')
sim_row.pack(fill='x', pady=(0, 4))

SIM_BUTTONS = [
    ('S  Sensors', 'S', '#444466'),
    ('F  Forward', 'F', '#226622'),
    ('L  Left',    'L', '#664422'),
    ('R  Right',   'R', '#664422'),
]
for label, ch, col in SIM_BUTTONS:
    make_btn(sim_row, label, lambda c=ch: send_cmd(c), color=col).pack(
        side='left', padx=3, pady=4, fill='x', expand=True)

# ── Free-text entry ───────────────────────────────────────────────────────────
entry_frame = tk.Frame(root, bg='#1a1a1a')
entry_frame.pack(fill='x', padx=8, pady=(4, 8))

tk.Label(entry_frame, text='Send text:', bg='#1a1a1a', fg='#aaaaaa',
         font=('Helvetica', 10)).pack(side='left', padx=(0, 6))

entry_var = tk.StringVar()
entry = tk.Entry(entry_frame, textvariable=entry_var, bg='#2a2a35', fg='white',
                 insertbackground='white', font=('Menlo', 11), relief='flat')
entry.pack(side='left', fill='x', expand=True, padx=(0, 6), ipady=4)


def on_send():
    text = entry_var.get()
    if not text:
        return
    send_line(text)
    entry_var.set('')


entry.bind('<Return>', lambda _e: on_send())
make_btn(entry_frame, 'Send', on_send, color='#2d4a2d').pack(side='left', padx=(0, 6))
make_btn(entry_frame, 'Clear', clear_terminal, color='#4a2d2d').pack(side='left')

# ── Status bar ────────────────────────────────────────────────────────────────
status_var = tk.StringVar(value=f'Connecting to {PORT}…')
status = tk.Label(root, textvariable=status_var, bg='#252525', fg='#aaaaaa',
                  font=('Helvetica', 9), anchor='w', padx=10, pady=3)
status.pack(fill='x', side='bottom')


# ── Polling loop: drain rx_queue into terminal ────────────────────────────────
def poll_rx():
    drained = False
    while True:
        try:
            chunk = rx_queue.get_nowait()
        except queue.Empty:
            break
        drained = True
        try:
            text = chunk.decode('utf-8')
        except UnicodeDecodeError:
            text = chunk.decode('latin-1', errors='replace')
        append_terminal(text, tag='rx')
    if drained and ser is not None and ser.is_open:
        status_var.set(f'Connected — {PORT} @ {BAUD}')
    root.after(POLL_MS, poll_rx)


# ── Startup ───────────────────────────────────────────────────────────────────
def list_serial_hint():
    ports = [p.device for p in serial.tools.list_ports.comports()]
    if ports:
        return 'Available ports: ' + ', '.join(ports)
    return 'No serial ports detected.'


def on_close():
    if ser is not None and ser.is_open:
        try:
            ser.close()
        except Exception:
            pass
    root.destroy()


root.protocol('WM_DELETE_WINDOW', on_close)
signal.signal(signal.SIGINT, lambda *_: on_close())

ser = open_serial()
if ser is None:
    append_terminal(f'[!] Could not open {PORT}.\n    {list_serial_hint()}\n', tag='sys')
    status_var.set(f'NOT CONNECTED — {PORT}')
else:
    append_terminal(f'[Connected to {PORT} @ {BAUD}]\n', tag='sys')
    status_var.set(f'Connected — {PORT} @ {BAUD}')
    threading.Thread(target=serial_reader, daemon=True).start()

entry.focus_set()
root.after(POLL_MS, poll_rx)
root.mainloop()
