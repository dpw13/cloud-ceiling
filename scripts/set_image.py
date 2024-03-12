#!/usr/bin/env python3

import logging
import requests
import json
import base64

from PIL import Image

logging.basicConfig(level=logging.INFO)

session = requests.Session()

SCALAR_URI = "http://beaglebone:3000/set_scalar"
DATA_URI = "http://beaglebone:3000/set_data"

IMG_FILE = "/home/dwagner/mario.png"

data = bytearray()
with Image.open(IMG_FILE) as im:
    size = im.size
    bands = im.getbands()
    print(f"Bands: {bands} Size: {size}")
    
    for p in im.getdata():
        pp = [round(x * 0.1) for x in p] 
        d = dict(zip(bands, pp))
        data.extend([d['R'], d['G'], d['B']])
        #print(f"Color: {d}")
    
for y in range(0, size[1]-1):
    print()
    for x in range(0, size[0]):
        i = 3*(x + y*size[0])
        try:
            val = data[i] > 0
        except:
            val = 0
        print(f"{val:01}", end="")
print()

print(f"Got {len(data)} bytes\n")
obj = json.dumps({
    "index": 0,
    "value": base64.b64encode(data).decode()
})
#print(f"Request:\n{obj}")

# Set size
session.post(SCALAR_URI, json.dumps({"index": 4, "value": size[0]}))
session.post(SCALAR_URI, json.dumps({"index": 5, "value": size[1]}))
session.post(SCALAR_URI, json.dumps({"index": 13, "value": 1})) # mode
# Set image data
session.post(DATA_URI, obj)
