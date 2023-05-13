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
    f = r.split(" ")
    c = colour.Color(rgb=f)
    if last_color != c:
        last_color = c

        print(f"{c}")

        config = {
            "vars": {
                "float": [0, 0, 0, 128],
                "color": [{"r": 0, "g": 0, "b": 0}],
                "rcolor": [{"r": c.red, "g": c.green, "b": c.blue}],
                "position": []
            },
            "primitives": [
                {
                    "type": "dither",
                    "inputs": {
                        "scale": 3,
                        "i": 0,
                        "x": 1,
                        "y": 2
                    },
                    "outputs": {
                        "o": 0
                    }
                }
            ],
        }
        config_json = json.dumps(config)

        requests.post(url=FB_URI, data=config_json)

    time.sleep(0.2)
