use crate::var_types;
use json;

#[derive(Default, Debug, Copy, Clone, PartialEq)]
pub struct VarMsg<T> {
    pub index: usize,
    pub value: T,
}

#[derive(Debug, Clone, PartialEq)]
pub enum ModularMessage {
    Config(json::object::Object),

    SetScalar(VarMsg<f32>),
    SetPosition(VarMsg<var_types::Position>),
    SetColor(VarMsg<var_types::Color>),
    SetRColor(VarMsg<var_types::RealColor>),
    SetData(VarMsg<var_types::Data>),
}

/*
 * I tried to use the into_variant crate to help with the
 * duplication below, but something about the parameterized type
 * used as the variant's value caused problems. Instead the code
 * below works but will need to be updated any time a new variant
 * of Message is added.
 */
pub trait Settable {
    fn into_message(index: usize, value: Self) -> ModularMessage;
}

impl Settable for f32 {
    fn into_message(index: usize, value: Self) -> ModularMessage {
        ModularMessage::SetScalar(VarMsg::<Self> {index, value})
    }
}

impl Settable for var_types::Position {
    fn into_message(index: usize, value: Self) -> ModularMessage {
        ModularMessage::SetPosition(VarMsg::<Self> {index, value})
    }
}

impl Settable for var_types::Color {
    fn into_message(index: usize, value: Self) -> ModularMessage {
        ModularMessage::SetColor(VarMsg::<Self> {index, value})
    }
}

impl Settable for var_types::RealColor {
    fn into_message(index: usize, value: Self) -> ModularMessage {
        ModularMessage::SetRColor(VarMsg::<Self> {index, value})
    }
}

impl Settable for var_types::Data {
    fn into_message(index: usize, value: Self) -> ModularMessage {
        ModularMessage::SetData(VarMsg::<Self> {index, value})
    }
}
