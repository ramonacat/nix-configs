use std::collections::BTreeMap;
use std::sync::mpsc::{channel, Receiver, Sender};

use embedded_graphics::{draw_target::DrawTarget, pixelcolor::BinaryColor};

use crate::gui::fonts::{FontKind, Fonts};
use crate::gui::geometry::Rectangle;
use crate::gui::layouts::stack::render_stack;
use crate::gui::{
    Control, Dimensions, Event, GuiCommand, GuiError, Orientation, Padding, Point,
    StackUnitDimension,
};

use super::button::Button;
use super::stack_panel::StackPanel;
use super::text::Text;

enum ScrollRequest {
    Up,
    Down,
}

pub struct ItemScroller<TDrawTarget: DrawTarget<Color = BinaryColor, Error = GuiError>> {
    children: Vec<Box<dyn Control<TDrawTarget>>>,
    show_items: usize,
    buttons_stack_panel: StackPanel<TDrawTarget>,
    buttons_stack_panel_bounding_box: Option<Rectangle>,
    scroll_index: usize,
    scroll_rx: Receiver<ScrollRequest>,
    command_channel: Option<Sender<GuiCommand<TDrawTarget>>>,
    bounding_box: Option<Rectangle>,
    children_bounding_boxes: Option<BTreeMap<usize, Rectangle>>,
}
impl<TDrawTarget: DrawTarget<Color = BinaryColor, Error = GuiError> + 'static>
    ItemScroller<TDrawTarget>
{
    pub(crate) fn new(children: Vec<Box<dyn Control<TDrawTarget>>>, show_items: usize) -> Self {
        let (scroll_tx, scroll_rx) = channel();

        let scroll_tx_ = scroll_tx.clone();

        let buttons_stack_panel: StackPanel<TDrawTarget> = StackPanel::new(
            vec![
                Box::new(Button::<TDrawTarget>::new(
                    Box::new(Text::new(
                        "⬆".to_string(),
                        20,
                        FontKind::Emoji,
                        Padding::zero(),
                    )),
                    Padding {
                        top: 5,
                        bottom: 5,
                        left: 0,
                        right: 0,
                    },
                    Box::new(move |_| {
                        scroll_tx.send(ScrollRequest::Up).unwrap();
                    }),
                )),
                Box::new(Button::<TDrawTarget>::new(
                    Box::new(Text::new(
                        "⬇".to_string(),
                        20,
                        FontKind::Emoji,
                        Padding::zero(),
                    )),
                    Padding {
                        top: 5,
                        bottom: 5,
                        left: 0,
                        right: 0,
                    },
                    Box::new(move |_| {
                        scroll_tx_.send(ScrollRequest::Down).unwrap();
                    }),
                )),
            ],
            Orientation::Vertical,
            vec![StackUnitDimension::Stretch, StackUnitDimension::Stretch],
        );

        Self {
            children,
            show_items,
            buttons_stack_panel,
            buttons_stack_panel_bounding_box: None,
            scroll_index: 0,
            command_channel: None,
            scroll_rx,
            bounding_box: None,
            children_bounding_boxes: None,
        }
    }
}

impl<TDrawTarget: DrawTarget<Color = BinaryColor, Error = GuiError> + 'static> Control<TDrawTarget>
    for ItemScroller<TDrawTarget>
{
    fn render(
        &mut self,
        target: &mut TDrawTarget,
        dimensions: Dimensions,
        position: Point,
        fonts: &Fonts,
    ) {
        let buttons_dimensions = Dimensions::new(30, dimensions.height());

        let buttons_position = Point(position.0 + (dimensions.width() - 30), position.1);

        self.buttons_stack_panel
            .render(target, buttons_dimensions, buttons_position, fonts);
        self.buttons_stack_panel_bounding_box =
            Some(Rectangle::new(buttons_position, buttons_dimensions));

        let children_bounding_boxes = render_stack(
            target,
            self.children
                .iter_mut()
                .skip(self.scroll_index)
                .take(self.show_items),
            Dimensions::new(dimensions.width() - 30, dimensions.height()),
            position,
            Orientation::Vertical,
            &[], // TODO stretch all the children
            fonts,
        );
        self.children_bounding_boxes = Some(children_bounding_boxes);

        self.bounding_box = Some(Rectangle::new(position, dimensions));
    }

    fn on_event(&mut self, event: Event) {
        match event {
            Event::Touch(position) => {
                if let Some(buttons_bounding_box) = &self.buttons_stack_panel_bounding_box {
                    if buttons_bounding_box.contains(position) {
                        self.buttons_stack_panel.on_event(event);
                    }
                }

                if let Some(children_bounding_boxes) = &self.children_bounding_boxes {
                    for (control_offset, bounding_box) in children_bounding_boxes {
                        if bounding_box.contains(position) {
                            self.children[self.scroll_index + control_offset].on_event(event);
                        }
                    }
                }

                let mut needs_contents_redraw = false;

                while let Ok(request) = self.scroll_rx.try_recv() {
                    match request {
                        ScrollRequest::Up => {
                            if self.scroll_index > 0 {
                                self.scroll_index -= 1;
                                needs_contents_redraw = true;
                            }
                        }
                        ScrollRequest::Down => {
                            if self.scroll_index < self.children.len() {
                                self.scroll_index += 1;
                                needs_contents_redraw = true;
                            }
                        }
                    }
                }

                if needs_contents_redraw {
                    if let Some(tx) = &self.command_channel {
                        tx.send(GuiCommand::Redraw).unwrap();
                    }
                }
            }
            Event::Heartbeat => {
                self.buttons_stack_panel.on_event(event);
                for c in self.children.iter_mut() {
                    c.on_event(event);
                }
            }
        };
    }

    fn compute_natural_dimensions(&mut self, _fonts: &Fonts) -> Dimensions {
        Dimensions::new(30, 30)
    }

    fn register_command_channel(
        &mut self,
        tx: std::sync::mpsc::Sender<crate::gui::GuiCommand<TDrawTarget>>,
    ) {
        self.command_channel = Some(tx.clone());
        self.buttons_stack_panel
            .register_command_channel(tx.clone());
        for child in self.children.iter_mut() {
            child.register_command_channel(tx.clone());
        }
    }
}
