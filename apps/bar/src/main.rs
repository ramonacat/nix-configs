use std::{
    process::{Command, Stdio},
    time::Duration,
};

use regex::Regex;
use serde::Serialize;
use upower_dbus::UPowerProxy;

// https://i3wm.org/docs/i3bar-protocol.html
#[derive(Debug, Serialize)]
struct Block {
    full_text: String,
}

fn get_pa_volume() -> f64 {
    let cmd = Command::new("pactl")
        .args(["get-sink-volume", "@DEFAULT_SINK@"])
        .stdout(Stdio::piped())
        .spawn()
        .unwrap()
        .wait_with_output()
        .unwrap();

    let regex = Regex::new(r"(\d+)%").unwrap();
    let output = String::from_utf8_lossy(&cmd.stdout);

    if let Some(x) = regex.captures_iter(&output).next() {
        let (_, [val]) = x.extract();

        return val.parse::<f64>().unwrap() / 100.0f64;
    }

    0.0f64
}

fn get_pa_mute() -> bool {
    let cmd = Command::new("pactl")
        .args(["get-sink-mute", "@DEFAULT_SINK@"])
        .stdout(Stdio::piped())
        .spawn()
        .unwrap()
        .wait_with_output()
        .unwrap();

    let regex = Regex::new(r"Mute: (yes|no)").unwrap();
    let output = String::from_utf8_lossy(&cmd.stdout);

    if let Some(x) = regex.captures_iter(&output).next() {
        let (_, [val]) = x.extract();

        return val == "yes";
    }

    false
}

struct BatteryState {
    is_on_battery: bool,
    percent: f64
}

async fn get_battery_state(upower: Option<&UPowerProxy<'_>>) -> Option<BatteryState> {
    match upower {
        Some(ref x) => {
            let Ok(is_on_battery) = x.on_battery().await else { 
                return None; 
            };

            let Ok(display_device) = x.get_display_device().await else {
                return None;
            };

            let Ok(percent) = display_device.percentage().await else {
                return None;
            };

            Some(BatteryState{
                is_on_battery,
                percent
            } )
        }
        None => None
    }
}

#[tokio::main]
async fn main() {
    let connection = zbus::Connection::system().await.unwrap();
    let upower = UPowerProxy::new(&connection).await.ok();

    println!("{}", "{\"version\": 1, \"click_events\": false}");
    println!("[");

    loop {
        let battery_state = get_battery_state(upower.as_ref()).await;
        let volume = get_pa_volume();
        let mute_emoji = if get_pa_mute() { "🔇" } else { "🔊" };
        let now = chrono::Local::now();

        let mut loadavg = [0.0f64; 2];
        unsafe {
            libc::getloadavg(loadavg.as_mut_ptr(), 2);
        }

        let mut blocks = vec![];
        if let Some(battery_state) = battery_state {
            let battery_emoji = if battery_state.is_on_battery { "🔋" } else { "🔌" };
            blocks.push(Block {
                full_text: format!("{} {:.0}%", battery_emoji, battery_state.percent)
            })
        }

        blocks.push(Block {
            full_text: format!("{} {:.0}%", mute_emoji, volume * 100.0f64)
        });
        blocks.push( Block {
            full_text: format!("🏋 {:.2} {:.2}", loadavg[0], loadavg[1])
        });
        blocks.push(Block {
            full_text: now.format("🕛 %Y-%m-%d %H:%M").to_string()
        });

        println!(
            "{},",
            serde_json::to_string(&blocks)
            .unwrap()
        );

        tokio::time::sleep(Duration::from_millis(500)).await;
    }
}