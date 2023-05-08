
mod synth notes

build function that produces pixel color from inputs (frame, x, y)
- works well for fields, but not for drawing primitives

configuration:
- number of variables for each type
- array of primitives

primitive configuration:
- name/type
- list of inputs
 - name, type, and index of value
- list of outputs
 - name, type, and index of value
- list of fixed parameters where applicable

data types:
- float
- 2d position
- 3d u8 color (pending color correction?)

primitive types:
- constants of each type
- special variables (frame, x, y)
- basic math
- 2d transforms
- ramp/triangle/square wave
- random
- interpolate (float -> color)
 - fixed or variable color map?
- color operators (max/min/add/blend/overwrite, etc)
- color transforms (intensity+temperature, hsv, etc)

- 2d buffer lookup for drawing primitives
 - drawing primitive name
 - repeat pattern (take modulus of inputs?)
 - interpolation type
