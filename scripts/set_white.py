#!/usr/bin/env python3

import argparse
import logging
import requests
import json

logging.basicConfig(level=logging.INFO)

session = requests.Session()

LED_URI = "http://beaglebone:3000/set_white_led"

parser = argparse.ArgumentParser(prog="set_white.py", description="Directly set white LED values")

parser.add_argument("-t", "--temp", type=int, default=4700)
parser.add_argument("-v", "--value", type=float, default=0.5)
parser.add_argument("-d", "--delay", type=float, default=0.5)

args = parser.parse_args()

# Set color
session.post(LED_URI, json.dumps({
    "temp": args.temp,
    "value": args.value,
    "delay": args.delay}))
