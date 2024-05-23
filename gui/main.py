#!/usr/bin/env python3

import base64
import json
import logging
import re
import requests
import typing

from nicegui import ui
from nicegui.events import ValueChangeEventArguments, ColorPickEventArguments

logging.basicConfig(level=logging.INFO)

class WhiteLeds:
    LED_URI = "http://beaglebone:3000/set_white_led"

    def __init__(self, session):
        self.session = session
        self.temperature = 4200.0
        self.value = 0.0
        self.delay = 0.0

    def update(self):
        # TODO: Clear existing timer, set timer for (delay) and schedule update
        # Set color
        val = json.dumps({
            "temp": self.temperature,
            "value": self.value,
            "delay": self.delay})
        res = self.session.post(self.LED_URI, val)
        logging.info(f"Updated white: {res}: {val}")

    def set_value(self, value: float):
        self.value = value
        self.update()


class ImageMatrix:
    DATA_URI = "http://beaglebone:3000/set_data"
    LED_COUNT = 118
    STRING_COUNT = 46

    def __init__(self, session):
        self.session = session
        self.data = bytearray([0, 0, 0] * self.LED_COUNT * self.STRING_COUNT)

    def set_solid(self, color: typing.Iterable[int]):
        self.data = bytearray(color * self.LED_COUNT * self.STRING_COUNT)
        self.update()

    def set_solid_evt(self, evt: ColorPickEventArguments):
        if m := re.match('^#([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})', evt.color):
            color_list = [0]*3
            for i in range(0, 3):
                color_list[i] = int(m.group(i+1), 16)
            self.set_solid(color_list)
        else:
            logging.error(f"Could not parse color: {evt.color}")

    def update(self):
        print(f"First pixel is '{list(self.data[0:3])}'")
        obj = json.dumps({
            "index": 0,
            "value": base64.b64encode(self.data).decode()
        })
        res = self.session.post(self.DATA_URI, obj)
        logging.info(f"Updated image: {res}")


class DataModel:
    def __init__(self):
        self.session = requests.Session()
        self.white = WhiteLeds(self.session)
        self.image = ImageMatrix(self.session)

model = DataModel()

def show(event: ValueChangeEventArguments):
    name = type(event.sender).__name__
    ui.notify(f'{name}: {event.value}')

ui.dark_mode().enable()
with ui.card().classes('w-96'):
    ui.label("White Control")

    with ui.row():
        ui.button('Off', on_click=lambda: model.white.set_value(0.0))
        ui.button('On', on_click=lambda: model.white.set_value(0.6))

    with ui.grid(columns='auto 1fr auto').classes('w-80'):
        ui.label("Temp")
        ui.slider(min=2000, max=7000, step=50).bind_value(model.white, 'temperature').on_value_change(model.white.update)
        ui.label().bind_text_from(model.white, 'temperature')

        ui.label("Value")
        ui.slider(min=0.0, max=1.0, step=0.05).bind_value(model.white, 'value').on_value_change(model.white.update)
        ui.label().bind_text_from(model.white, 'value')

with ui.card().classes('w-96'):
    ui.label("LED Control")
    with ui.row():
        ui.button('Off', on_click=lambda: model.image.set_solid([0, 0, 0]))
        with ui.button(icon='colorize') as button:
            ui.color_picker(on_pick=lambda e: model.image.set_solid_evt(e))

ui.run(title='Ceiling Control')