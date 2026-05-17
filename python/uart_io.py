#!/usr/bin/env python3
"""Headless UART send/receive against the MARV CP2102.

Usage examples:
    uart_io.py --read 2                              # listen for 2 s, print bytes received
    uart_io.py --send 'PicAchu' --cr --read 2        # send "PicAchu\\r", then listen 2 s
    uart_io.py --send-hex 50 69 63 0d --read 1       # send 4 raw bytes, listen 1 s
    uart_io.py --interact                            # crude REPL: type, Enter sends CR + listens
    uart_io.py --port /dev/tty.usbserial-0001 ...    # override default port

Output:
    Each received chunk is printed as:    rx: <repr-text>   (<hex bytes>)
    Sent bytes are printed as:            tx: <repr-text>   (<hex bytes>)
"""

import argparse
import sys
import time
from typing import Iterable

import serial


DEFAULT_PORT = "/dev/cu.usbserial-0001"
DEFAULT_BAUD = 9600


def to_hex(b: bytes) -> str:
    return " ".join(f"{x:02x}" for x in b)


def to_repr(b: bytes) -> str:
    # Show printable ASCII as-is; replace control chars with \xNN
    return "".join(chr(x) if 32 <= x < 127 else f"\\x{x:02x}" for x in b)


def open_port(port: str, baud: int) -> serial.Serial:
    return serial.Serial(port, baud, timeout=0.05)


def listen(ser: serial.Serial, seconds: float) -> bytes:
    """Read for `seconds` wall-clock; print chunks as they arrive."""
    deadline = time.time() + seconds
    collected = bytearray()
    while time.time() < deadline:
        chunk = ser.read(256)
        if chunk:
            collected.extend(chunk)
            print(f"rx: {to_repr(chunk)!s:<40}  ({to_hex(chunk)})", flush=True)
    return bytes(collected)


def send(ser: serial.Serial, data: bytes) -> None:
    ser.write(data)
    ser.flush()
    print(f"tx: {to_repr(data)!s:<40}  ({to_hex(data)})", flush=True)


def parse_hex_bytes(tokens: Iterable[str]) -> bytes:
    out = bytearray()
    for t in tokens:
        t = t.lower().lstrip("0x")
        if not t:
            continue
        out.append(int(t, 16))
    return bytes(out)


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--port", default=DEFAULT_PORT)
    p.add_argument("--baud", type=int, default=DEFAULT_BAUD)
    p.add_argument("--send", help="ASCII string to transmit")
    p.add_argument("--send-hex", nargs="+", metavar="BYTE",
                   help="Raw bytes to transmit (hex, e.g. 50 69 0d)")
    p.add_argument("--cr", action="store_true",
                   help="Append \\r (0x0D) to --send payload")
    p.add_argument("--lf", action="store_true",
                   help="Append \\n (0x0A) to --send payload")
    p.add_argument("--read", type=float, default=0.0, metavar="SECONDS",
                   help="Listen for this many seconds after sending")
    p.add_argument("--interact", action="store_true",
                   help="REPL: each typed line is sent + 1 s listen")
    args = p.parse_args()

    try:
        ser = open_port(args.port, args.baud)
    except serial.SerialException as e:
        print(f"!! could not open {args.port} @ {args.baud}: {e}", file=sys.stderr)
        return 2

    print(f"[uart] {args.port} @ {args.baud} 8N1", flush=True)

    if args.interact:
        print("[uart] interactive: type a line + Enter to send (CR appended). Ctrl-C to quit.")
        try:
            while True:
                line = input("> ")
                send(ser, line.encode("latin-1") + b"\r")
                listen(ser, 1.0)
        except (EOFError, KeyboardInterrupt):
            print()
        return 0

    if args.send is not None:
        payload = args.send.encode("latin-1")
        if args.cr:
            payload += b"\r"
        if args.lf:
            payload += b"\n"
        send(ser, payload)

    if args.send_hex:
        send(ser, parse_hex_bytes(args.send_hex))

    if args.read > 0:
        listen(ser, args.read)

    return 0


if __name__ == "__main__":
    sys.exit(main())
