package Clay;
use 5.40.0;
use warnings;
use experimental qw(class);

# Main Clay package that exports the needed functions

use Clay::Types;
use Clay::Element;
use Clay::Context;
use Clay::Builder;
use Clay::UI;
use Clay::Types::LayoutConfig qw(
  $SIZING_FIXED $SIZING_GROW $SIZING_PERCENT $SIZING_FIT
  $LEFT_TO_RIGHT $RIGHT_TO_LEFT $TOP_TO_BOTTOM $BOTTOM_TO_TOP
  $ALIGN_LEFT $ALIGN_RIGHT $ALIGN_CENTER $ALIGN_TOP $ALIGN_BOTTOM
);
use Clay::Types::TextConfig qw(
  $WRAP_WORDS $WRAP_NEWLINES $WRAP_NONE
  $ALIGN_LEFT $ALIGN_RIGHT $ALIGN_CENTER
);

use Exporter qw(import);

our @EXPORT = qw(
  create_context
  create_root
  sizing_fit
  sizing_grow
  sizing_fixed
  sizing_percent
  color
  color_black
  color_white
  color_red
  color_green
  color_blue
  color_yellow
  layout_horizontal
  layout_vertical
  border_all
  border_box
  padding_all
  text_config

  $SIZING_FIXED
  $SIZING_GROW
  $SIZING_PERCENT
  $SIZING_FIT
  $LEFT_TO_RIGHT
  $RIGHT_TO_LEFT
  $TOP_TO_BOTTOM
  $BOTTOM_TO_TOP
  $ALIGN_LEFT
  $ALIGN_RIGHT
  $ALIGN_CENTER

  $WRAP_WORDS
  $WRAP_NEWLINES
  $WRAP_NONE
);

1;
