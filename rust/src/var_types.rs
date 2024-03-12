use json::JsonValue;
use num_traits::clamp;
use std::ops::{Add, Mul};
use base64::prelude::*;

pub trait FromJson {
    fn from_obj(v: &JsonValue) -> Self;
}

impl FromJson for f32 {
    fn from_obj(v: &JsonValue) -> Self {
        v.as_f32().expect("Value must be a float")
    }
}

#[derive(Default, Debug, Copy, Clone, PartialEq)]
pub struct Position {
    pub x: f32,
    pub y: f32,
}

impl FromJson for Position {
    fn from_obj(v: &JsonValue) -> Self {
        let dict = match v {
            JsonValue::Object(ref x) => x,
            _ => panic!("Position is not an object"),
        };

        let x = dict
            .get("x")
            .expect("No x parameter in Position")
            .as_f32()
            .expect("Failed to interpret x parameter");
        let y = dict
            .get("y")
            .expect("No y parameter in Position")
            .as_f32()
            .expect("Failed to interpret y parameter");

        Position { x, y }
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

impl FromJson for Color {
    fn from_obj(v: &JsonValue) -> Self {
        let dict = match v {
            JsonValue::Object(ref x) => x,
            _ => panic!("Color is not an object"),
        };

        let r = dict
            .get("r")
            .expect("No r parameter in Color")
            .as_u8()
            .expect("Failed to interpret r parameter");
        let g = dict
            .get("g")
            .expect("No g parameter in Color")
            .as_u8()
            .expect("Failed to interpret g parameter");
        let b = dict
            .get("b")
            .expect("No b parameter in Color")
            .as_u8()
            .expect("Failed to interpret b parameter");

        Color { r, g, b }
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

#[derive(Default, Debug, Copy, Clone, PartialEq)]
pub struct RealColor {
    pub r: f32,
    pub g: f32,
    pub b: f32,
}

impl FromJson for RealColor {
    fn from_obj(v: &JsonValue) -> Self {
        let dict = match v {
            JsonValue::Object(ref x) => x,
            _ => panic!("RealColor is not an object"),
        };

        let r = dict
            .get("r")
            .expect("No r parameter in Color")
            .as_f32()
            .expect("Failed to interpret r parameter");
        let g = dict
            .get("g")
            .expect("No g parameter in Color")
            .as_f32()
            .expect("Failed to interpret g parameter");
        let b = dict
            .get("b")
            .expect("No b parameter in Color")
            .as_f32()
            .expect("Failed to interpret b parameter");

        Self { r, g, b }
    }
}

impl Add for RealColor {
    type Output = Self;

    fn add(self, other: Self) -> Self::Output {
        Self {
            r: clamp(self.r + other.r, 0.0, 1.0),
            g: clamp(self.g + other.g, 0.0, 1.0),
            b: clamp(self.b + other.b, 0.0, 1.0),
        }
    }
}

impl Mul<f32> for RealColor {
    type Output = Self;

    fn mul(self, other: f32) -> Self::Output {
        Self {
            r: clamp(other * self.r, 0.0, 1.0),
            g: clamp(other * self.g, 0.0, 1.0),
            b: clamp(other * self.b, 0.0, 1.0),
        }
    }
}

pub type Data = Vec<u8>;

impl FromJson for Data {
    fn from_obj(v: &JsonValue) -> Self {
        /*
         * The documentation for JsonValue seems to indicate that
         * as_str() will not return a value for anything but Short
         * and String.
         */
        let b64_str = match v.as_str() {
            Some(x) => x,
            _ => panic!("Data is not a string: '{:?}'", v),
        };
        BASE64_STANDARD.decode(b64_str).expect("Failed to decode base64")
    }
}