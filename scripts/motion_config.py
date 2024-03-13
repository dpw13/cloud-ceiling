#!/usr/bin/env python

import argparse
import logging
import serial
import string

import motion

logging.basicConfig(level=logging.INFO)

parser = argparse.ArgumentParser(prog="motion_config.py", description="Configure Zilog motion detector over serial")

parser.add_argument("-p", "--port", default="/dev/ttyS1")
parser.add_argument("-r", "--read")
parser.add_argument("-w", "--write", nargs=2)
parser.add_argument("-c", "--confirm")

args = parser.parse_args()

ser = serial.Serial(args.port, 9600, 8, "N", 1)

if getattr(args, "write"):
    try:
        value = int(args.write[1]).to_bytes(1)
    except ValueError:
        value = args.write[1].encode()
    motion.motion_write(ser, args.write[0].encode(), value)

if getattr(args, "read"):
    rsp = motion.motion_read(ser, args.read.encode())
    c = chr(rsp)
    if c in string.ascii_uppercase:
        print(f"Response: {rsp} ({chr(rsp)})")
    else:
        print(f"Response: {rsp}")

if getattr(args, "confirm"):
    motion.motion_confirm(ser, args.confirm.encode())

print("Success")
