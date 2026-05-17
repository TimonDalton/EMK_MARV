"""Toggle the dongle's TX pin (→ PIC RX) HIGH/LOW every 2 s.

Idle (break off) = HIGH, break on = LOW.
Probe the dongle's TX wire with a multimeter to confirm it toggles.
"""

import time
import serial

PORT = '/dev/cu.usbserial-0001'
BAUD = 9600

ser = serial.Serial(PORT, BAUD, timeout=1, rtscts=False, dsrdtr=False)
ser.dtr = False

print(f"Opened {PORT}. Toggling TX pin every 2 s. Ctrl-C to stop.\n")

try:
    state = False
    while True:
        ser.break_condition = state
        print(f"TX = {'LOW (break)' if state else 'HIGH (idle)'}")
        state = not state
        time.sleep(2)
except KeyboardInterrupt:
    pass
finally:
    ser.break_condition = False
    ser.close()
    print("Done.")
