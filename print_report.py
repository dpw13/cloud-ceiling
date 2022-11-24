#!/usr/bin/env python3

import json
import sys
import pprint

with open(sys.argv[1]) as rptf:
	rpt = json.load(rptf)

print("Clock Report")
print("-"*25)
for clk, data in rpt['fmax'].items():
	print(f"{clk}: {data['constraint']:.2f} MHz required, {data['achieved']:.2f} MHz achievable")
print()

print("Utilization Report")
print("-"*25)
for cell, data in rpt['utilization'].items():
	pct = 100*data['used']/data['available']
	print(f"{cell}: {data['used']}/{data['available']} ({pct:.2f}%)")
