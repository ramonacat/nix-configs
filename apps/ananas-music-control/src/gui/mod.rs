use std::{
    error::Error,
    fmt::Debug,
    sync::mpsc::{Receiver, Sender},
    time::Duration,
};

use embedded_graphics::{
    draw_target::DrawTarget,
    pixelcolor::BinaryColor,
    primitives::{PrimitiveStyleBuilder, Rectangle, StyledDrawable},
};
use fontdue::Font;

use crate::epaper::FlushableDrawTarget;

use self::geometry::{Dimensions, Point};

pub mod controls;
pub mod geometry;
mod layouts;

pub struct Padding {
    top: u32,
    bottom: u32,
    left: u32,
    right: u32,
}

impl Padding {
    pub fn new(top: u32, bottom: u32, left: u32, right: u32) -> Self {
        Self {
            top,
            bottom,
            left,
            right,
        }
    }
}

pub struct Gui<TDrawTarget: DrawTarget<Color = BinaryColor, Error = TError>, TError: Error + Debug>
{
    fonts: Vec<Font>,
    draw_target: TDrawTarget,
    root_control: Box<dyn Control<TDrawTarget, TError>>,
    events_rx: Receiver<Event>,
}

impl<
        TDrawTarget: DrawTarget<Color = BinaryColor, Error = TError> + FlushableDrawTarget,
        TError: Error + Debug,
    > Gui<TDrawTarget, TError>
{
    pub fn new(
        fonts: Vec<Font>,
        draw_target: TDrawTarget,
        root_control: Box<dyn Control<TDrawTarget, TError>>,
        events_rx: Receiver<Event>,
    ) -> Self {
        Gui {
            fonts,
            draw_target,
            root_control,
            events_rx,
        }
    }

    fn handle_event(&mut self, event: Event) {
        match event {
            Event::Touch(position) => {
                self.root_control.on_touch(position);
            }
        }
    }

    fn render(&mut self) {
        self.clear_screen();

        let top_left = self.draw_target.bounding_box().top_left;
        let size = self.draw_target.bounding_box().size;

        self.root_control.render(
            &mut self.draw_target,
            Dimensions::new(size.width, size.height),
            Point(top_left.x as u32, top_left.y as u32),
            &self.fonts,
        );

        self.draw_target.flush();
    }

    fn clear_screen(&mut self) {
        let rectangle = Rectangle::new(
            embedded_graphics::geometry::Point::new(0, 0),
            self.draw_target.bounding_box().size,
        );
        let style = PrimitiveStyleBuilder::new()
            .fill_color(BinaryColor::Off)
            .build();

        rectangle
            .draw_styled(&style, &mut self.draw_target)
            .unwrap();
    }

    pub fn run(mut self) {
        let (command_tx, command_rx) = std::sync::mpsc::channel();

        self.root_control
            .register_command_channel(command_tx.clone());
        self.render();

        loop {
            if let Ok(event) = self.events_rx.recv_timeout(Duration::from_millis(50)) {
                self.handle_event(event);
            } else {
                continue;
            }

            while let Ok(event) = self.events_rx.try_recv() {
                self.handle_event(event);
            }

            let mut redraw = false;
            while let Ok(command) = command_rx.try_recv() {
                // TODO: Coalesce the events and do a partial redraw!

                match command {
                    GuiCommand::Redraw(_, _) => redraw = true,
                    GuiCommand::ReplaceRoot(mut new_root) => {
                        new_root.register_command_channel(command_tx.clone());
                        self.root_control = new_root;
                        redraw = true;
                    }
                }
            }

            if redraw {
                self.render();
            }

            // todo sleep here?
        }
    }
}

pub enum Event {
    Touch(Point),
}

pub enum GuiCommand<TDrawTarget: DrawTarget, TError: Error + Debug> {
    Redraw(Point, Dimensions),
    ReplaceRoot(Box<dyn Control<TDrawTarget, TError>>),
}

pub trait Control<
    TDrawTarget: DrawTarget<Color = BinaryColor, Error = TError>,
    TError: Error + Debug,
>
{
    fn register_command_channel(&mut self, tx: Sender<GuiCommand<TDrawTarget, TError>>);
    fn compute_dimensions(&mut self, fonts: &[Font]) -> Dimensions;

    fn render(
        &mut self,
        target: &mut TDrawTarget,
        dimensions: Dimensions,
        position: Point,
        fonts: &[Font],
    );
    fn on_touch(&mut self, position: Point);
}
