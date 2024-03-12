#!/usr/bin/env python3

import logging
import requests
import json
import sys

logging.basicConfig(level=logging.INFO)

session = requests.Session()

LED_URI = "http://beaglebone:3000/set_white_led"

# Set color
session.post(LED_URI, json.dumps({
    "temp": float(sys.argv[1]),
    "value": float(sys.argv[2]),
    "delay": 2.0}))
