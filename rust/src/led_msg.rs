
#[derive(Debug, Clone, PartialEq)]
pub enum LedMessage {
    SetWhiteTemp(f32, f32, f32)
}