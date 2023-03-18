use std::cell::{RefMut};

pub trait Renderable {
    fn render(&mut self, frame: u32, fb: &mut RefMut<[u8]>);
}