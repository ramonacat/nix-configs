use std::{
    thread::sleep,
    time::{Duration, SystemTime},
};

use embedded_graphics::{
    draw_target::DrawTarget,
    geometry::{OriginDimensions, Point, Size},
    pixelcolor::BinaryColor,
    Pixel,
};
use rppal::{
    gpio::{InputPin, Level, OutputPin},
    spi::Spi,
};

use crate::gui::GuiError;

const EPAPER_WIDTH: u32 = 122;
const EPAPER_HEIGHT: u32 = 250;

const LUT_PARTIAL: [u8; 159] = [
    0x0, 0x40, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x80, 0x80, 0x0, 0x0, 0x0, 0x0,
    0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x40, 0x40, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,
    0x0, 0x80, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,
    0x0, 0x0, 0x0, 0x0, 0x0, 0x10, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x1, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,
    0x1, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,
    0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,
    0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,
    0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x22, 0x22, 0x22, 0x22, 0x22,
    0x22, 0x0, 0x0, 0x0, 0x22, 0x17, 0x41, 0x00, 0x32, 0x36,
];

const LUT_FULL: [u8; 159] = [
    0x80, 0x4A, 0x40, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x40, 0x4A, 0x80, 0x0, 0x0, 0x0,
    0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x80, 0x4A, 0x40, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,
    0x40, 0x4A, 0x80, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,
    0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0xF, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0xF, 0x0, 0x0, 0xF, 0x0, 0x0,
    0x2, 0xF, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x1, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,
    0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,
    0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,
    0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x22, 0x22, 0x22, 0x22,
    0x22, 0x22, 0x0, 0x0, 0x0, 0x22, 0x17, 0x41, 0x0, 0x32, 0x36,
];

pub struct EPaper {
    reset_pin: OutputPin,
    data_command_pin: OutputPin,
    chip_select_pin: OutputPin,
    busy_pin: InputPin,
    spi: Spi,
    write_count: usize,
    changed_pixel_count: usize,
    last_full_update: SystemTime,
}

impl EPaper {
    pub fn new(
        reset_pin: OutputPin,
        data_command_pin: OutputPin,
        chip_select_pin: OutputPin,
        busy_pin: InputPin,
        spi: Spi,
    ) -> Self {
        Self {
            reset_pin,
            data_command_pin,
            chip_select_pin,
            busy_pin,
            spi,
            write_count: 0,
            changed_pixel_count: 0,
            last_full_update: SystemTime::UNIX_EPOCH,
        }
    }

    fn hardware_reset(&mut self) {
        self.reset_pin.set_high();
        std::thread::sleep(Duration::from_millis(20));
        self.reset_pin.set_low();
        sleep(Duration::from_millis(2));
        self.reset_pin.set_high();
        std::thread::sleep(Duration::from_millis(20));
    }

    fn send_command(&mut self, data: &[u8]) {
        self.data_command_pin.set_low();
        self.chip_select_pin.set_low();
        for b in data {
            self.spi.write(&[*b]).unwrap();
        }
        self.chip_select_pin.set_high();
    }

    fn send_data(&mut self, data: &[u8]) {
        self.data_command_pin.set_high();
        self.chip_select_pin.set_low();
        for b in data {
            self.spi.write(&[*b]).unwrap();
        }
        self.chip_select_pin.set_high();
    }

    fn wait_while_busy(&mut self) {
        while self.busy_pin.read() == Level::High {
            sleep(Duration::from_millis(10));
        }
    }

    fn turn_on_for_full_update(&mut self) {
        self.send_command(&[0x22]);
        self.send_data(&[0xc7]);
        self.send_command(&[0x20]);
    }

    fn turn_on_for_partial_update(&mut self) {
        self.send_command(&[0x22]);
        self.send_data(&[0x0c]);
        self.send_command(&[0x20]);
    }

    fn set_display_window(&mut self, (x_start, y_start): (u32, u32), (x_end, y_end): (u32, u32)) {
        self.send_command(&[0x44]); // SET_RAM_X_ADDRESS_START_END_POSITION
        self.send_data(&[(x_start >> 3 & 0xFF) as u8]);
        self.send_data(&[(x_end >> 3 & 0xFF) as u8]);

        self.send_command(&[0x45]);

        self.send_data(&[(y_start & 0xFF) as u8]);
        self.send_data(&[(y_start >> 8 & 0xFF) as u8]);

        self.send_data(&[(y_end & 0xFF) as u8]);
        self.send_data(&[(y_end >> 8 & 0xFF) as u8]);
    }

    fn set_cursor(&mut self, (x, y): (u32, u32)) {
        self.send_command(&[0x4E]); // SET_RAM_X_ADDRESS_COUNTER
        self.send_data(&[(x & 0xFF) as u8]);

        self.send_command(&[0x4F]);
        self.send_data(&[(y & 0xFF) as u8]);
        self.send_data(&[(y >> 8 & 0xFF) as u8]);
    }

    fn initialize_for_full_update(&mut self) {
        self.hardware_reset();

        self.wait_while_busy();
        self.send_command(&[0x12]); // SWRESET
        self.wait_while_busy();

        self.send_command(&[0x01]); // Driver output control
        self.send_data(&[0xf9]);
        self.send_data(&[0x00]);
        self.send_data(&[0x00]);

        self.send_command(&[0x11]); // Data entry mode
        self.send_data(&[0x03]);

        self.set_display_window((0, 0), (EPAPER_WIDTH - 1, EPAPER_HEIGHT - 1));
        self.set_cursor((0, 0));

        self.send_command(&[0x3c]); // Border waveform
        self.send_data(&[0x05]);

        self.send_command(&[0x21]); // display update control
        self.send_data(&[0x00]);
        self.send_data(&[0x80]);

        self.send_command(&[0x18]); // display update control
        self.send_data(&[0x80]);

        self.set_lut(&LUT_FULL);
    }

    fn initialize_for_partial_update(&mut self) {
        self.reset_pin.set_low();
        sleep(Duration::from_millis(1));
        self.reset_pin.set_high();

        self.set_lut(&LUT_PARTIAL);

        self.send_command(&[0x37]);
        self.send_data(&[0x00]);
        self.send_data(&[0x00]);
        self.send_data(&[0x00]);
        self.send_data(&[0x00]);
        self.send_data(&[0x00]);
        self.send_data(&[0x40]);
        self.send_data(&[0x00]);
        self.send_data(&[0x00]);
        self.send_data(&[0x00]);
        self.send_data(&[0x00]);

        self.send_command(&[0x3c]); // Border waveform
        self.send_data(&[0x80]);

        self.send_command(&[0x22]);
        self.send_data(&[0xc0]);
        self.send_command(&[0x20]);

        self.wait_while_busy();
    }

    fn set_lut(&mut self, lut: &[u8]) {
        self.send_command(&[0x32]);
        self.send_data(&lut[0..153]);

        self.send_command(&[0x3f]);
        self.send_data(&[lut[153]]);

        self.send_command(&[0x03]);
        self.send_data(&[lut[154]]);

        self.send_command(&[0x04]);
        self.send_data(&[lut[155]]);
        self.send_data(&[lut[156]]);
        self.send_data(&[lut[157]]);

        self.send_command(&[0x2c]);
        self.send_data(&[lut[158]]);
    }

    fn turn_off(&mut self) {
        self.send_command(&[0x10]); // enter deep sleep
        self.send_data(&[0x01]);

        sleep(Duration::from_millis(2000));

        self.reset_pin.set_low();
        self.data_command_pin.set_low();
        self.chip_select_pin.set_low();
    }

    // FIXME validate dimensions
    pub fn write_image(&mut self, image: &[u8], changed_pixel_count: usize) {
        self.write_count += 1;
        self.changed_pixel_count += changed_pixel_count;

        // These numbers are chosen by vibes, could be wrong but who knows.
        let partial = self.write_count < 100
            && self.changed_pixel_count < 250000
            && SystemTime::now()
                .duration_since(self.last_full_update)
                .unwrap_or(Duration::MAX)
                .as_secs()
                < 3600;

        if !partial {
            println!(
                "{} {} {:?}",
                self.write_count, self.changed_pixel_count, self.last_full_update
            );
            self.last_full_update = SystemTime::now();
            self.write_count = 0;
            self.changed_pixel_count = 0;

            self.initialize_for_full_update();
        }

        self.send_command(&[0x24]);
        self.send_data(image);

        if !partial {
            self.send_command(&[0x26]);
            self.send_data(image);
        }

        if !partial {
            self.turn_on_for_full_update();
        } else {
            self.turn_on_for_partial_update();
        }
        self.wait_while_busy();

        if !partial {
            self.initialize_for_partial_update();
        }
    }
}

impl Drop for EPaper {
    fn drop(&mut self) {
        self.turn_off();
    }
}

pub trait FlushableDrawTarget {
    fn flush(&mut self);
}

pub struct BufferedDrawTarget {
    epaper: EPaper,
    buffer: Vec<u8>,
    changed_pixel_count: usize,
}

impl BufferedDrawTarget {
    pub fn new(epaper: EPaper) -> Self {
        let row_width_bytes = EPAPER_WIDTH / 8 + if EPAPER_WIDTH % 8 == 0 { 0 } else { 1 };

        Self {
            epaper,
            buffer: vec![0xFF; (row_width_bytes * EPAPER_HEIGHT) as usize],
            changed_pixel_count: 0,
        }
    }
}

impl FlushableDrawTarget for BufferedDrawTarget {
    fn flush(&mut self) {
        self.epaper
            .write_image(&self.buffer, self.changed_pixel_count);
        self.changed_pixel_count = 0;
    }
}

impl DrawTarget for BufferedDrawTarget {
    type Color = BinaryColor;

    // fixme: make this a real error type, instead of panicking
    type Error = GuiError;

    fn draw_iter<I>(&mut self, pixels: I) -> Result<(), Self::Error>
    where
        I: IntoIterator<Item = embedded_graphics::prelude::Pixel<Self::Color>>,
    {
        let row_width_bytes = EPAPER_WIDTH / 8 + if EPAPER_WIDTH % 8 == 0 { 0 } else { 1 };

        for pixel in pixels.into_iter() {
            let pixel_x_byte_index = pixel.0.x / 8;
            let pixel_x_bit_index = 7 - (pixel.0.x % 8);

            let pixel_index = (pixel_x_byte_index + pixel.0.y * row_width_bytes as i32) as usize;
            if pixel_index >= self.buffer.len() {
                // The documentation for embedded_graphics requires us to ignore requests to draw pixels outside of the screen
                continue;
            }

            let previous_state = self.buffer[pixel_index];

            if pixel.1 == BinaryColor::Off {
                self.buffer[pixel_index] |= 1 << pixel_x_bit_index;
            } else {
                self.buffer[pixel_index] &= !(1 << pixel_x_bit_index);
            }

            if previous_state != self.buffer[pixel_index] {
                self.changed_pixel_count += 1;
            }
        }

        Ok(())
    }
}

impl OriginDimensions for BufferedDrawTarget {
    fn size(&self) -> embedded_graphics::prelude::Size {
        Size::new(EPAPER_WIDTH, EPAPER_HEIGHT)
    }
}

pub struct RotatedDrawTarget<T: DrawTarget + OriginDimensions + FlushableDrawTarget> {
    inner: T,
}

impl<T: DrawTarget + OriginDimensions + FlushableDrawTarget> RotatedDrawTarget<T> {
    pub fn new(inner: T) -> Self {
        Self { inner }
    }
}

impl<T: DrawTarget<Error = GuiError> + OriginDimensions + FlushableDrawTarget> DrawTarget
    for RotatedDrawTarget<T>
{
    type Color = T::Color;
    type Error = GuiError;

    fn draw_iter<I>(&mut self, pixels: I) -> Result<(), Self::Error>
    where
        I: IntoIterator<Item = embedded_graphics::prelude::Pixel<Self::Color>>,
    {
        let inner_size = self.inner.size();

        self.inner.draw_iter(pixels.into_iter().map(|x| {
            Pixel(
                Point {
                    x: (inner_size.width - x.0.y as u32) as i32,
                    y: x.0.x,
                },
                x.1,
            )
        }))
    }
}

impl<T: DrawTarget + OriginDimensions + FlushableDrawTarget> OriginDimensions
    for RotatedDrawTarget<T>
{
    fn size(&self) -> Size {
        let original_size = self.inner.size();

        Size {
            width: original_size.height,
            height: original_size.width,
        }
    }
}

impl<T: DrawTarget + OriginDimensions + FlushableDrawTarget> FlushableDrawTarget
    for RotatedDrawTarget<T>
{
    fn flush(&mut self) {
        self.inner.flush()
    }
}
