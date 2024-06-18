use std::thread::sleep;
use std::time::{Duration, Instant};

use tokio::sync::broadcast::Receiver;

use interpolation::Lerp;

use crate::display::LedRegs;
use crate::led_msg::LedMessage;

pub struct ColorPoint {
    val: f32,
    color: [f32; 3],
}

// Cold, cool, hot
const COLOR_MAP : [ColorPoint; 5]= [
    ColorPoint {val:    0.0, color: [1.0, 0.0, 0.0] },
    ColorPoint {val: 1900.0, color: [1.0, 0.0, 0.0] },
    ColorPoint {val: 3000.0, color: [0.0, 1.0, 0.0] },
    ColorPoint {val: 6500.0, color: [0.0, 0.0, 1.0] },
    ColorPoint {val: 9900.0, color: [0.0, 0.0, 1.0] },
];

pub async fn led_main(mut led_rx: Receiver<LedMessage>) {
    /* Regmap initialization */

    let regs = LedRegs::new();
    let mut cur_color : [f32; 3] = [0.0, 0.0, 0.0];

    // Blocking wait to receive new message
    while let Ok(msg) = led_rx.recv().await {
        match msg {
            LedMessage::SetWhiteTemp(temp, value, delay) => {
                // Find which pair of points this value falls between
                //print!("{x},{y} {p}\n");
                let i = COLOR_MAP.iter().position(|x| temp <= x.val).expect("{p} is outside of map limits") - 1;

                // Scale the independent variable
                //print!("Using index {i}, original value is {p}\n");
                let alpha: f32 = (temp - COLOR_MAP[i].val)/(COLOR_MAP[i+1].val - COLOR_MAP[i].val);
                // Perform the interpolation
                //print!("alpha = {alpha}\n");
                let new_color = COLOR_MAP[i].color.lerp(&COLOR_MAP[i+1].color, &alpha);
                //print!("new_color: {new_color:?}\n");
                let adj_value = value.powf(2.2);
                let adj_color = [
                    (new_color[0] * adj_value),
                    (new_color[1] * adj_value),
                    (new_color[2] * adj_value),
                ];
                //print!("adj_color: {adj_color:?}\n");
                // intensity

                let start = Instant::now();
                let duration = Duration::from_secs_f32(delay);

                while start.elapsed() < duration {
                    let alpha = start.elapsed().as_secs_f32()/duration.as_secs_f32();
                    let tmp_color = cur_color.lerp(&adj_color, &alpha);
                    regs.set_white_led_f32(
                        tmp_color[0].clamp(0.0, 1.0),
                        tmp_color[1].clamp(0.0, 1.0),
                        tmp_color[2].clamp(0.0, 1.0));
                    sleep(Duration::from_millis(10));
                }

                regs.set_white_led_f32(
                    adj_color[0].clamp(0.0, 1.0),
                    adj_color[1].clamp(0.0, 1.0),
                    adj_color[2].clamp(0.0, 1.0));
                cur_color = adj_color;
            },
        }
    }
}
