"""
loopback_test.py  --  Send a string over UART and check the echo.

Protocol:
  1. PIC sends '!' every ~0.8 s until it receives any byte.
  2. Python sends '\xFF' when it sees '!'.
  3. PIC replies 'Y' (RX confirmed working), then enters echo mode.
  4. Python sends TEST string and checks the echo.

Edit CONFIG below to match the .s file settings, then run:
    python3 loopback_test.py
"""

import time
import serial

# ── CONFIG ────────────────────────────────────────────────────────────────────
PORT     = '/dev/cu.usbserial-0001'
BAUD     = 9600       # match SPBRG1 option in loopback_test.s
TIMEOUT  = 2.0        # seconds to wait for echo
TEST     = b'HELLO'   # string to send and expect back
# ─────────────────────────────────────────────────────────────────────────────

TRIGGER_WAIT = 30.0   # seconds to wait for '!' before giving up
SYNC_TIMEOUT = 1.5    # seconds to wait for 'Y' after sending sync byte


def open_port(baud=BAUD):
    ser = serial.Serial(PORT, baud, timeout=0.1,
                        rtscts=False, dsrdtr=False)
    ser.dtr = False
    return ser


def handshake(ser):
    """Wait for '!', reply with sync byte, confirm PIC RX with 'Y'."""
    print(f"  Waiting for PIC '!' (boot the board now, timeout={TRIGGER_WAIT}s)...")
    deadline = time.time() + TRIGGER_WAIT
    while time.time() < deadline:
        b = ser.read(1)
        if not b:
            continue
        print(f"  rx: 0x{b[0]:02X} '{chr(b[0]) if 32 <= b[0] < 127 else '?'}'")
        if b != b'!':
            continue
        print("  '!' received — sending sync byte...")
        ser.write(b'\xFF')
        # Wait for PIC to confirm it saw our byte
        t_end = time.time() + SYNC_TIMEOUT
        while time.time() < t_end:
            r = ser.read(1)
            if not r:
                continue
            print(f"  rx: 0x{r[0]:02X} '{chr(r[0]) if 32 <= r[0] < 127 else '?'}'")
            if r == b'Y':
                print("  'Y' received — PIC RX confirmed. Entering echo test.")
                ser.reset_input_buffer()
                return True
        # No 'Y' within timeout — PIC will send '!' again; keep looping
        print("  No 'Y' within timeout — waiting for next '!'...")
    print(f"  TIMEOUT: no '!' received within {TRIGGER_WAIT}s.")
    print("  If the board is running, check the dongle-to-PIC TX wiring.")
    return False


def send_recv(ser, data):
    ser.timeout = TIMEOUT
    ser.write(data)
    buf = b''
    deadline = time.time() + TIMEOUT
    while len(buf) < len(data) and time.time() < deadline:
        buf += ser.read(len(data) - len(buf))
    return buf


def hex_str(b):
    return ' '.join(f'{x:02X}' for x in b)


def analyse(sent, received):
    print(f"  sent     : {hex_str(sent)}  ({sent!r})")
    print(f"  received : {hex_str(received)}  ({received!r})" if received
          else "  received : <nothing>")

    if not received:
        print("  >> FAIL: no echo at all.")
        print("     Likely causes:")
        print("       - wrong baud rate")
        print("       - RXDTP wrong (RX not detecting bytes)")
        print("       - wiring: dongle TX not reaching RC7")
        return

    if received == sent:
        print("  >> PASS: perfect echo.")
        return

    if len(received) != len(sent):
        print(f"  >> FAIL: length mismatch (sent {len(sent)}, got {len(received)}).")
        print("     Likely a baud rate mismatch causing framing errors.")
        return

    inverted = bytes(b ^ 0xFF for b in sent)
    if received == inverted:
        print("  >> INFO: received bytes are the bitwise inverse of sent bytes.")
        print("     TXCKP is wrong (BSF BAUDCON1,4 instead of BCF, or vice versa).")
        print("     Flip CONFIG OPTION 2 in loopback_test.s.")
        return

    mismatches = [(i, sent[i], received[i]) for i in range(len(sent)) if sent[i] != received[i]]
    print(f"  >> PARTIAL: {len(mismatches)}/{len(sent)} bytes differ:")
    for i, s, r in mismatches:
        print(f"     [{i}] sent 0x{s:02X} '{chr(s) if 32<=s<127 else '?'}'"
              f"  got 0x{r:02X} '{chr(r) if 32<=r<127 else '?'}'")


def run_test(label, baud=BAUD):
    print(f"\n{'='*60}")
    print(f"Test: {label}  (port={PORT}, baud={baud})")
    print(f"{'='*60}")
    try:
        ser = open_port(baud)
    except serial.SerialException as e:
        print(f"  [ERROR] Could not open port: {e}")
        return
    if not handshake(ser):
        ser.close()
        return
    rx = send_recv(ser, TEST)
    analyse(TEST, rx)
    ser.close()


if __name__ == '__main__':
    # ── Run the active test ────────────────────────────────────────────────────
    # Comment/uncomment lines here to match what you have set in loopback_test.s

    run_test("9600 baud",  baud=9600)   # Option A (default)
#   run_test("19200 baud", baud=19200)  # Option B
#   run_test("4800 baud",  baud=4800)   # Option C
