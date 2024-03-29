use std::cmp::min;
use std::sync::mpsc::Sender;
use std::sync::Arc;

use embedded_graphics::image::{Image, ImageRaw};
use embedded_graphics::Drawable;
use embedded_graphics::{draw_target::DrawTarget, pixelcolor::BinaryColor};
use fontdue::layout::{Layout, TextStyle};

use crate::gui::fonts::{FontKind, Fonts};
use crate::gui::reactivity::property::{ReactiveProperty, ReactivePropertyReceiver};
use crate::gui::{Control, Dimensions, GuiCommand, GuiError, Padding, Point};

pub struct Text<TDrawTarget: DrawTarget<Color = BinaryColor, Error = GuiError>> {
    text: String,
    font_size: usize,
    command_channel: Option<Sender<GuiCommand<TDrawTarget>>>,
    padding: Padding,
    font_kind: FontKind,

    text_property: Arc<ReactiveProperty<String>>,
    text_property_receiver: ReactivePropertyReceiver<String>,

    position: Option<Point>,
    dimensions: Option<Dimensions>,
}

impl<TDrawTarget: DrawTarget<Color = BinaryColor, Error = GuiError>> Text<TDrawTarget> {
    pub fn new(text: String, font_size: usize, font_kind: FontKind, padding: Padding) -> Self {
        let (text_property, text_property_receiver) = ReactiveProperty::new();

        Self {
            text,
            font_size,
            command_channel: None,
            padding,
            font_kind,
            text_property: Arc::new(text_property),
            text_property_receiver,
            position: None,
            dimensions: None,
        }
    }

    pub fn text(&self) -> Arc<ReactiveProperty<String>> {
        self.text_property.clone()
    }
}

struct RenderedText {
    pixels: Vec<(usize, usize)>,
    width: u32,
    height: u32,
}

fn render_text(text: &str, font_size: f32, font_kind: FontKind, fonts: &Fonts) -> RenderedText {
    let mut layout = Layout::new(fontdue::layout::CoordinateSystem::PositiveYDown);

    layout.append(
        fonts.all(),
        &TextStyle::new(text, font_size, fonts.index_of(font_kind)),
    );

    let mut pixels = vec![];
    for glyph in layout.glyphs() {
        let (metrics, data) = fonts.all()[glyph.font_index].rasterize_config(glyph.key);

        for (i, c) in data.iter().enumerate() {
            let pixel_x = (i % metrics.width) + glyph.x as usize;
            let pixel_y = (i / metrics.width) + glyph.y as usize;

            if *c > 0 {
                pixels.push((pixel_x, pixel_y));
            }
        }
    }

    let width = pixels.iter().map(|x| x.0).max().unwrap_or(0);
    let height = pixels.iter().map(|x| x.1).max().unwrap_or(0);

    RenderedText {
        pixels,
        width: width as u32,
        height: height as u32,
    }
}

impl<TDrawTarget: DrawTarget<Color = BinaryColor, Error = GuiError>> Control<TDrawTarget>
    for Text<TDrawTarget>
{
    fn render(
        &mut self,
        target: &mut TDrawTarget,
        dimensions: Dimensions,
        position: Point,
        fonts: &Fonts,
    ) {
        let dimensions = self.padding.adjust_dimensions(dimensions);
        let position = self.padding.adjust_position(position);

        let rendered_text = render_text(&self.text, self.font_size as f32, self.font_kind, fonts);
        let visible_width = min(rendered_text.width, dimensions.width());
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
        let centered_position = Point(
            position.0 + (dimensions.width() - visible_width) / 2,
            position.1 + (dimensions.height() - visible_height) / 2,
        );

        let image = Image::new(
            &image_raw,
            embedded_graphics::geometry::Point {
                x: centered_position.0 as i32,
                y: centered_position.1 as i32,
            },
        );

        image.draw(target).unwrap();

        self.position = Some(position);
        self.dimensions = Some(dimensions);
    }

    fn on_event(&mut self, event: crate::gui::Event) {
        match event {
            crate::gui::Event::Touch(_) => {}
            crate::gui::Event::Heartbeat => {
                let mut redraw = false;
                if let Some(text) = self.text_property_receiver.latest_value() {
                    if text != self.text {
                        self.text = text;
                        redraw = true;
                    }
                }

                if let (true, Some(tx)) = (redraw, &self.command_channel) {
                    tx.send(GuiCommand::Redraw).unwrap();
                }
            }
        };
    }

    fn compute_natural_dimensions(&mut self, fonts: &Fonts) -> crate::gui::Dimensions {
        let rendered_text = render_text(&self.text, self.font_size as f32, self.font_kind, fonts);

        Dimensions::new(
            rendered_text.width as u32 + self.padding.total_horizontal(),
            rendered_text.height as u32 + self.padding.total_vertical(),
        )
    }

    fn register_command_channel(
        &mut self,
        tx: std::sync::mpsc::Sender<crate::gui::GuiCommand<TDrawTarget>>,
    ) {
        self.command_channel = Some(tx);
    }
}
