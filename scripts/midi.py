#!/usr/bin/env python3

import mido
import pprint
import logging
import requests
import json

logging.basicConfig(level=logging.INFO)

session = requests.Session()

FB_URI = "http://beaglebone:3000/set_scalar"
NOTE_BASE = 36
CC_BASE = 36

cur_cc_base = CC_BASE
scale = 1.0
bipolar = False

def set_scalar(session, idx, value):
    if idx < 0:
        print(f"Bad scalar index {idx}")
        return

    print(f"set scalar {idx} = {value}")
    session.post(FB_URI, json.dumps({"index": idx, "value": value}))

def get_value(raw, scale, bipolar):
    if bipolar:
        # -scale to scale
        return scale * (msg.value - 64) / 64.0
    else:
        # 0 to scale
        return scale * (msg.value) / 127.0


with mido.open_input("LPD8 mk2 0") as port:
    for msg in port:
        match msg.type:
            case "note_on":
                # Set bank of scalars with buttons
                btn_id = msg.note - NOTE_BASE

                if btn_id < 4:
                    cur_cc_base = CC_BASE - (btn_id * 8)
                elif btn_id == 4:
                    bipolar = not bipolar
                    print(f"Bipolar: {bipolar}")
                elif btn_id == 5:
                    # Reset scale and base
                    print("Reset")
                    scale = 1.0
                    cur_cc_base = CC_BASE
                elif btn_id == 6:
                    # Halve scale
                    scale = scale / 2.0
                    print(f"Scale: {scale}")
                elif btn_id == 7:
                    # Double scale
                    scale = scale * 2.0
                    print(f"Scale: {scale}")

            case "control_change":
                idx = msg.control - cur_cc_base
                val = get_value(msg.value, scale, bipolar)
                set_scalar(session, idx, val)
            case _:
                # Ignore other messages
                pass