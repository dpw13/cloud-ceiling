use crate::var_types::*;
use json::JsonValue;

pub struct RenderState {
    scalars: Vec<f32>,
    positions: Vec<Position>,
    colors: Vec<Color>,
    rcolors: Vec<RealColor>,
    data: Vec<Data>,
}

pub trait RenderBlock {
    fn execute(&mut self, state: &mut RenderState);
}

impl RenderState {
    pub fn new() -> Self {
        // At least 3 scalars for time, x, and y
        let scalars = Vec::<f32>::with_capacity(3);
        let positions = Vec::<Position>::with_capacity(0);
        // At least 1 color for output
        let colors = Vec::<Color>::with_capacity(1);
        let rcolors = Vec::<RealColor>::with_capacity(0);
        let data = Vec::<Vec<u8>>::with_capacity(0);

        RenderState {
            scalars,
            positions,
            colors,
            rcolors,
            data,
        }
    }

    pub fn set_scalar(&mut self, idx: usize, val: f32) {
        if idx < self.scalars.len() {
            self.scalars[idx] = val;
        }
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

    pub fn set_rcolor(&mut self, idx: usize, val: RealColor) {
        self.rcolors[idx] = val;
    }

    pub fn get_rcolor(&self, idx: usize) -> &RealColor {
        &self.rcolors[idx]
    }

    pub fn set_data(&mut self, idx: usize, val: Vec<u8>) {
        self.data[idx] = val;
    }

    pub fn get_data(&self, idx: usize) -> &Vec<u8> {
        &self.data[idx]
    }

    pub fn debug(&self) {
        print!("Scalars: {:?}\n", self.scalars);
        print!("Positions: {:?}\n", self.positions);
        print!("Colors: {:?}\n", self.colors);
        print!("RealColors: {:?}\n", self.rcolors);
        print!("Data: {:?}\n", self.data);
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
            self.scalars
                .push(o.as_f32().expect("Failed to interpret scalar value"));
        }

        let list = match dict
            .get("position")
            .expect("Missing 'position' initialization")
        {
            JsonValue::Array(x) => x,
            _ => panic!("Initialization for positions is not a list"),
        };
        self.positions.clear();
        for o in list {
            self.positions.push(Position::from_obj(o));
        }

        let list = match dict
            .get("color")
            .expect("Missing 'color' initialization")
        {
            JsonValue::Array(x) => x,
            _ => panic!("Initialization for colors is not a list"),
        };
        self.colors.clear();
        for o in list {
            self.colors.push(Color::from_obj(o));
        }

        let list = match dict
            .get("rcolor")
            .expect("Missing 'rcolor' initialization")
        {
            JsonValue::Array(x) => x,
            _ => panic!("Initialization for rcolors is not a list"),
        };
        self.rcolors.clear();
        for o in list {
            self.rcolors.push(RealColor::from_obj(o));
        }

        let list = match dict
            .get("data")
            .expect("Missing 'data' initialization")
        {
            JsonValue::Array(x) => x,
            _ => panic!("Initialization for data is not a list"),
        };
        self.data.clear();
        for o in list {
            self.data.push(Data::from_obj(o));
        }
    }
}
