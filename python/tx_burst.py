import serial, time

PORT = '/dev/cu.usbserial-0001'
BAUD = 9600

ser = serial.Serial(PORT, BAUD, timeout=1, rtscts=False, dsrdtr=False)
ser.dtr = False

print(f"Sending 200 bytes to {PORT} — watch the TX LED...")
while(True):
    ser.write(b'U')
    time.sleep(0.001)

ser.close()
print("Done.")
