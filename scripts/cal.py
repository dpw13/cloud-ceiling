#!/usr/bin/env python3

import requests
import colour
import json
import time

DISPLAYCAL_URI = "http://192.168.1.139:8080/ajax/messages"
FB_URI = "http://beaglebone:3000/set_config"

last_color = colour.Color("grey")

while True:
    r = requests.get(DISPLAYCAL_URI, data=last_color.hex_l)
    c = colour.Color(r.text)
    if last_color != c:
        print(f"{c}")
        last_color = c

        config = {
            "vars": {
                "float": [0, 0, 0, 0],
                "color": [{"r": round(32*c.red), "g": round(32*c.green), "b": round(32*c.blue)}],
                "position": []
            },
            "primitives": [],
        }
        config_json = json.dumps(config)

        requests.post(url=FB_URI, data=config_json)

    time.sleep(0.2)
