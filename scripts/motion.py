import serial

ACK = 0x06
NACK = 0x15

def check_response(ser: serial.Serial):
    rsp = ser.read(1)
    if rsp[0] == NACK:
        raise ValueError("Received NACK")
    elif rsp[0] != ACK:
        raise SystemError(f"Unexpected response: {rsp[0]}")

def motion_write(ser: serial.Serial, cmd: bytes, value: bytes) -> None:
    ser.write(cmd)
    rsp = ser.read(1) # previous value
    print(f"Replacing previous value of {rsp[0]} with {value[0]}")
    ser.write(value)
    check_response(ser)

def motion_read(ser: serial.Serial, cmd: bytes) -> int:
    ser.write(cmd)
    rsp = ser.read(1)
    return rsp[0]

def motion_confirm(ser: serial.Serial, cmd: bytes) -> None:
    ser.write(cmd)
    check_response(ser)
    ser.write("1234".encode())
    check_response(ser)
