pub trait Renderable {
    fn render(&mut self, frame: i32, fb: &mut [u8]);
}