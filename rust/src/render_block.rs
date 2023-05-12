use json::JsonValue;
use std::ops::{Mul, Add};
use num_traits::clamp;

pub struct RenderState {
    scalars: Vec<f32>,
    positions: Vec<Position>,
    colors: Vec<Color>,
}

pub trait RenderBlock {
    fn execute(&mut self, state: &mut RenderState);
}

#[derive(Default, Debug, Copy, Clone, PartialEq)]
pub struct Position {
    pub x: f32,
    pub y: f32,
}

impl Position {
    pub fn from_obj(v: &JsonValue) -> Position {
        let dict = match v {
            JsonValue::Object(ref x) => x,
            _ => panic!("Position is not an object"),
        };

        let x = dict.get("x").expect("No x parameter in Position").as_f32().expect("Failed to interpret x parameter");
        let y = dict.get("y").expect("No y parameter in Position").as_f32().expect("Failed to interpret y parameter");

        Position {x, y}
    }
}

impl Add for Position {
    type Output = Self;

    fn add(self, other: Self) -> Self::Output {
        Self {
            x: self.x + other.x,
            y: self.y + other.y,
        }
    }
}

// Can't get this generic to work.
//impl<T: Mul<f32,Output = f32>> Mul<T> for Position where f32: Mul<T> {
impl Mul<f32> for Position {
    type Output = Self;

    fn mul(self, other: f32) -> Self::Output {
        Self {
            x: self.x * other,
            y: self.y * other,
        }
    }
}

#[derive(Default, Debug, Copy, Clone, PartialEq)]
pub struct Color {
    pub r: u8,
    pub g: u8,
    pub b: u8,
}

impl Color {
    pub fn from_obj(v: &JsonValue) -> Color {
        let dict = match v {
            JsonValue::Object(ref x) => x,
            _ => panic!("Position is not an object"),
        };

        let r = dict.get("r").expect("No r parameter in Color").as_u8().expect("Failed to interpret r parameter");
        let g = dict.get("g").expect("No g parameter in Color").as_u8().expect("Failed to interpret g parameter");
        let b = dict.get("b").expect("No b parameter in Color").as_u8().expect("Failed to interpret b parameter");

        Color {r, g, b}
    }
}

impl Add for Color {
    type Output = Self;

    fn add(self, other: Self) -> Self::Output {
        Self {
            r: self.r.saturating_add(other.r),
            g: self.g.saturating_add(other.g),
            b: self.b.saturating_add(other.b),
        }
    }
}

impl Mul<f32> for Color {
    type Output = Self;

    fn mul(self, other: f32) -> Self::Output {
        // Cast our color to an f32, do the multiplication, round, clamp
        // to valid range, then convert back to u8.
        Self {
            r: clamp((other * f32::from(self.r)).round(), 0.0, 255.0) as u8,
            g: clamp((other * f32::from(self.g)).round(), 0.0, 255.0) as u8,
            b: clamp((other * f32::from(self.b)).round(), 0.0, 255.0) as u8,
        }
    }
}

impl Mul<i32> for Color {
    type Output = Self;

    fn mul(self, other: i32) -> Self::Output {
        // Cast our color to an i32, do the multiplication, clamp
        // to valid range, then convert back to u8.
        Self {
            r: clamp(other * i32::from(self.r), 0, 255) as u8,
            g: clamp(other * i32::from(self.g), 0, 255) as u8,
            b: clamp(other * i32::from(self.b), 0, 255) as u8,
        }
    }
}

impl RenderState {
    pub fn new() -> Self {
        // At least 3 scalars for time, x, and y
        let scalars = Vec::<f32>::with_capacity(3);
        let positions = Vec::<Position>::with_capacity(0);
        // At least 1 color for output
        let colors = Vec::<Color>::with_capacity(1);

        RenderState {scalars, positions, colors}
    }

    pub fn set_scalar(&mut self, idx: usize, val: f32) {
        self.scalars[idx] = val;
    }

    pub fn get_scalar(&self, idx: usize) -> f32 {
        self.scalars[idx]
    }

    pub fn set_position(&mut self, idx: usize, val: Position) {
        self.positions[idx] = val;
    }

    pub fn get_position(&self, idx: usize) -> &Position {
        &self.positions[idx]
    }

    pub fn set_color(&mut self, idx: usize, val: Color) {
        self.colors[idx] = val;
    }

    pub fn get_color(&self, idx: usize) -> &Color {
        &self.colors[idx]
    }

    pub fn from_obj(&mut self, v: &JsonValue) {
        let dict = match v {
            JsonValue::Object(x) => x,
            _ => panic!("Position is not an object"),
        };

        let list = match dict.get("float").expect("Missing 'float' initialization") {
            JsonValue::Array(x) => x,
            _ => panic!("Initialization for scalars is not a list"),
        };
        self.scalars.clear();
        for o in list {
            self.scalars.push(o.as_f32().expect("Failed to interpret scalar value"));
        }

        let list = match dict.get("position").expect("Missing 'positions' initialization") {
            JsonValue::Array(x) => x,
            _ => panic!("Initialization for positions is not a list"),
        };
        self.positions.clear();
        for o in list {
            self.positions.push(Position::from_obj(o));
        }

        let list = match dict.get("color").expect("Missing 'colors' initialization") {
            JsonValue::Array(x) => x,
            _ => panic!("Initialization for colors is not a list"),
        };
        self.colors.clear();
        for o in list {
            self.colors.push(Color::from_obj(o));
        }
    }
}
