use std::cell::{RefMut};

pub trait Renderable {
    fn render(&mut self, frame: i32, fb: &mut RefMut<[u8]>);
}