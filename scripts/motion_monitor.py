#!/usr/bin/env python3

import argparse
import logging
import requests
import json
import serial
import time

import motion

logging.basicConfig(level=logging.INFO)

parser = argparse.ArgumentParser(prog="motion_config.py", description="Configure Zilog motion detector over serial")

parser.add_argument("-p", "--port", default="/dev/ttyS1")
parser.add_argument("--gpio", type=int, default=98)
parser.add_argument("-t", "--temp", type=int, default=4500)
parser.add_argument("-b", "--brightness", type=float, default=0.4)
parser.add_argument("-s", "--sensitivity", type=int, default=10)
parser.add_argument("-r", "--range", type=int, default=1)

args = parser.parse_args()

# Configure motion sensor
with serial.Serial(args.port, 9600, 8, "N", 1) as ser:
    # See http://www.zilog.com/docs/ps0305.pdf
    motion.motion_write(ser, b"C", b"M")
    motion.motion_write(ser, b"S", args.sensitivity.to_bytes(1))
    motion.motion_write(ser, b"R", args.range.to_bytes(1))

session = requests.Session()

LED_URI = "http://beaglebone:3000/set_white_led"
MD_GPIO = 98
# TODO: change color based on time of day?
COLOR_TEMP = 4500
BRIGHTNESS = 0.3

start_val = 0

with open(f"/sys/class/gpio/gpio{args.gpio}/value") as mdf:
    while True:
        mdf.seek(0)
        val = int(mdf.read().strip())
        if val != start_val:
            print(f"MD {val}")
            start_val = val
            # Set color
            session.post(LED_URI, json.dumps({
                "temp": float(args.temp),
                "value": float(args.brightness * (1 - val)),
                "delay": 0.5}))
            time.sleep(0.5)
        else:
            time.sleep(0.1)
