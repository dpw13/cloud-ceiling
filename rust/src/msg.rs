use crate::var_types;
use json;

#[derive(Default, Debug, Copy, Clone, PartialEq)]
pub struct VarMsg<T> {
    pub index: usize,
    pub value: T,
}

#[derive(Debug, Clone, PartialEq)]
pub enum Message {
    Config(json::object::Object),

    SetScalar(VarMsg<f32>),
    SetPosition(VarMsg<var_types::Position>),
    SetColor(VarMsg<var_types::Color>),
    SetRColor(VarMsg<var_types::RealColor>),
    SetData(VarMsg<Vec<u8>>),
}
