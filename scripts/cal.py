#!/usr/bin/env python3

import requests
import json
import time

DISPLAYCAL_URI = "http://localhost:8080/ajax/messages"
FB_URI = "http://beaglebone:3000/set_config"

last_color = None

while True:
    r = requests.get(DISPLAYCAL_URI)
    c = list(map(lambda x: float(x), r.text.split(" ")))
    if last_color is None or last_color != c:
        last_color = c

        print(f"{c}")

        config = {
            "vars": {
                "float": [0, 0, 0, 96],
                "color": [{"r": 0, "g": 0, "b": 0}],
                "rcolor": [{"r": c[0], "g": c[1], "b": c[2]}],
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
