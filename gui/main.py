#!/usr/bin/env python3

import json
import logging
import requests

from nicegui import ui
from nicegui.events import ValueChangeEventArguments

logging.basicConfig(level=logging.INFO)

LED_URI = "http://beaglebone:3000/set_white_led"

class WhiteLeds:
    def __init__(self, session):
        self.session = session
        self.temperature = 5100.0
        self.value = 0.0
        self.delay = 0.0

    def update(self):
        # TODO: Clear existing timer, set timer for (delay) and schedule update
        # Set color
        val = json.dumps({
            "temp": self.temperature,
            "value": self.value,
            "delay": self.delay})
        res = self.session.post(LED_URI, val)
        logging.info(f"Updated white: {res}: {val}")

    def blank(self):
        self.value = 0
        self.update()

class DataModel:
    def __init__(self):
        self.session = requests.Session()
        self.white = WhiteLeds(self.session)

model = DataModel()

def show(event: ValueChangeEventArguments):
    name = type(event.sender).__name__
    ui.notify(f'{name}: {event.value}')

ui.label("White Control")
with ui.row():
    ui.button('Blank', on_click=model.white.blank)
with ui.row(wrap=False).classes('w-80'):
    ui.slider(min=2000, max=7000, step=50).bind_value(model.white, 'temperature').on_value_change(model.white.update)
    ui.label().bind_text_from(model.white, 'temperature')
with ui.row(wrap=False).classes('w-80'):
    ui.slider(min=0.0, max=1.0, step=0.05).bind_value(model.white, 'value').on_value_change(model.white.update)
    ui.label().bind_text_from(model.white, 'value')

ui.run(title='Ceiling Control')