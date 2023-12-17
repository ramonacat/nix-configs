use std::fmt::Debug;
use std::sync::mpsc::Sender;
use std::{cmp::min, error::Error};

use embedded_graphics::geometry::Point;
use embedded_graphics::image::{Image, ImageRaw};
use embedded_graphics::Drawable;
use embedded_graphics::{draw_target::DrawTarget, pixelcolor::BinaryColor};
use fontdue::{
    layout::{Layout, TextStyle},
    Font,
};

use crate::gui::{BoundingBox, Dimensions, Position, Control, GuiCommand};

pub struct Text {
    text: String,
    font_size: usize,
    command_channel: Option<Sender<GuiCommand>>,
}

impl Text {
    pub fn new(text: String, font_size: usize) -> Self {
        Self {
            text,
            font_size,
            command_channel: None,
        }
    }
}

struct RenderedText {
    pixels: Vec<(usize, usize)>,
    width: u32,
    height: u32,
}

fn render_text(text: &str, font_size: f32, font_index: usize, fonts: &[Font]) -> RenderedText {
    let mut layout = Layout::new(fontdue::layout::CoordinateSystem::PositiveYDown);

    layout.append(fonts, &TextStyle::new(&text, font_size, font_index));

    let mut pixels = vec![];
    for glyph in layout.glyphs() {
        let (metrics, data) = fonts[glyph.font_index].rasterize_config(glyph.key);

        for (i, c) in data.iter().enumerate() {
            let pixel_x = (i % metrics.width) + glyph.x as usize;
            let pixel_y = (i / metrics.width) + glyph.y as usize;

            if *c > 0 {
                pixels.push((pixel_x, pixel_y));
            }
        }
    }

    let width = pixels.iter().map(|x| x.0).max().unwrap();
    let height = pixels.iter().map(|x| x.1).max().unwrap();

    return RenderedText {
        pixels,
        width: width as u32,
        height: height as u32,
    };
}

impl<TDrawTarget: DrawTarget<Color = BinaryColor, Error = TError>, TError: Error + Debug>
    Control<TDrawTarget, TError> for Text
{
    fn render(
        &mut self,
        target: &mut TDrawTarget,
        dimensions: Dimensions,
        position: Position,
        fonts: &[Font],
    ) -> BoundingBox {
        let rendered_text = render_text(&self.text, self.font_size as f32, 0, fonts);
        let visible_width = min(rendered_text.width, dimensions.width);
        let visible_height = rendered_text.height;

        let rounded_width_in_bytes = (visible_width + 7) / 8;

        let mut bytes = vec![0u8; ((1 + rounded_width_in_bytes) * visible_height) as usize];

        for (x, y) in rendered_text.pixels.iter() {
            if *x >= visible_width as usize || *y >= visible_height as usize {
                continue;
            }

            let pixel_index = (y * rounded_width_in_bytes as usize * 8) + x;
            bytes[pixel_index / 8] |= 1 << (7 - (pixel_index % 8));
        }

        let image_raw = ImageRaw::<BinaryColor>::new(&bytes, 8 * rounded_width_in_bytes as u32);
        let centered_position = Position(
            position.0 + (dimensions.width - visible_width) / 2,
            position.1 + (dimensions.height - visible_height) / 2,
        );

        let image = Image::new(
            &image_raw,
            Point {
                x: centered_position.0 as i32,
                y: centered_position.1 as i32,
            },
        );

        image.draw(target).unwrap();

        BoundingBox {
            position: centered_position,
            dimensions: Dimensions {
                width: dimensions.width,
                height: dimensions.height,
            },
        }
    }

    fn on_touch(&mut self, _position: Position) {}

    fn compute_dimensions(&mut self, fonts: &[Font]) -> crate::gui::Dimensions {
        let rendered_text = render_text(&self.text, self.font_size as f32, 0, fonts);

        Dimensions {
            width: rendered_text.width as u32,
            height: rendered_text.height as u32,
        }
    }

    fn register_command_channel(&mut self, tx: std::sync::mpsc::Sender<crate::gui::GuiCommand>) {
        self.command_channel = Some(tx);
    }
}
