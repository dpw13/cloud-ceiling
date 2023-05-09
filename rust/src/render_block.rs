pub struct RenderState {
    scalars: Vec<f32>,
    positions: Vec<Position>,
    colors: Vec<Color>,
}

pub trait RenderBlock {
    fn execute(&mut self, state: &mut RenderState);
}

#[derive(Default, Clone)]
pub struct Position {
    pub x: f32,
    pub y: f32,
}

impl Position {
    pub fn from_obj(&mut self, v: &json::JsonValue) {
        let dict = match v {
            json::JsonValue::Object(ref x) => x,
            _ => panic!("Position is not an object"),
        };

        self.x = dict.get("x").expect("No x parameter in Position").as_f32().expect("Failed to interpret x parameter");
        self.y = dict.get("y").expect("No y parameter in Position").as_f32().expect("Failed to interpret y parameter");
    }
}

#[derive(Default, Clone)]
pub struct Color {
    pub r: u8,
    pub g: u8,
    pub b: u8,
}

impl Color {
    pub fn from_obj(&mut self, v: &json::JsonValue) {
        let dict = match v {
            json::JsonValue::Object(ref x) => x,
            _ => panic!("Position is not an object"),
        };

        self.r = dict.get("r").expect("No r parameter in Color").as_u8().expect("Failed to interpret r parameter");
        self.g = dict.get("g").expect("No g parameter in Color").as_u8().expect("Failed to interpret g parameter");
        self.b = dict.get("b").expect("No b parameter in Color").as_u8().expect("Failed to interpret b parameter");
    }
}

impl RenderState {
    pub fn new() -> Self {
        let scalars = Vec::<f32>::with_capacity(0);
        let positions = Vec::<Position>::with_capacity(0);
        let colors = Vec::<Color>::with_capacity(0);

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

    pub fn from_obj(&mut self, v: &json::JsonValue) {
        let dict = match v {
            json::JsonValue::Object(x) => x,
            _ => panic!("Position is not an object"),
        };

        let val = dict.get("float").expect("Missing 'float' initialization");
        let list = match val {
            json::JsonValue::Array(x) => x,
            _ => panic!("Initialization for scalars is not a list"),
        };
        self.scalars.resize(list.len(), 0.0);
        for (i, o) in list.iter().enumerate() {
            self.scalars[i] = o.as_f32().expect("Failed to interpret scalar value");
        }

        let val = dict.get("positions").expect("Missing 'positions' initialization");
        let list = match val {
            json::JsonValue::Array(x) => x,
            _ => panic!("Initialization for positions is not a list"),
        };
        self.positions.resize(list.len(), Default::default());
        for (i, o) in list.iter().enumerate() {
            self.positions[i].from_obj(o);
        }

        let val = dict.get("colors").expect("Missing 'colors' initialization");
        let list = match val {
            json::JsonValue::Array(x) => x,
            _ => panic!("Initialization for colors is not a list"),
        };
        self.colors.resize(list.len(), Default::default());
        for (i, o) in list.iter().enumerate() {
            self.colors[i].from_obj(o);
        }
    }
}
