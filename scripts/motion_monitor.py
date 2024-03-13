#!/usr/bin/env python3

import logging
import requests
import json
import sys
import time

logging.basicConfig(level=logging.INFO)

session = requests.Session()

LED_URI = "http://beaglebone:3000/set_white_led"
MD_GPIO = 98
# TODO: change color based on time of day?
COLOR_TEMP = 4500
BRIGHTNESS = 0.3

start_val = 0

with open(f"/sys/class/gpio/gpio{MD_GPIO}/value") as mdf:
    while True:
        mdf.seek(0)
        val = int(mdf.read().strip())
        print(f"Value {val}")
        if val != start_val:
            start_val = val
            # Set color
            session.post(LED_URI, json.dumps({
                "temp": float(COLOR_TEMP),
                "value": float(BRIGHTNESS * (1 - val)),
                "delay": 0.5}))

        time.sleep(0.5)