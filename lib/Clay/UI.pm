package Clay::UI;
use 5.40.0;
use Clay::Util;
use Clay::Context;
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
);

# Make these variables available to the subs
my $__SIZING_FIXED   = $SIZING_FIXED;
my $__SIZING_GROW    = $SIZING_GROW;
my $__SIZING_PERCENT = $SIZING_PERCENT;
my $__SIZING_FIT     = $SIZING_FIT;
my $__LEFT_TO_RIGHT  = $LEFT_TO_RIGHT;
my $__TOP_TO_BOTTOM  = $TOP_TO_BOTTOM;
my $__WRAP_WORDS     = $WRAP_WORDS;
my $__ALIGN_LEFT     = $ALIGN_LEFT;

# Exports the main UI functions

# Create a new context
sub create_context( $screen = Term::Screen->new ) {

    # Create a context with screen dimensions
    my $width  = $screen->cols;
    my $height = $screen->rows;

    # Create a buffer with the screen
    my $buffer = Clay::Buffer->new( screen => $screen );

    # Create layout dimensions as a separate object
    my $layout_dimensions =
      Clay::Types::Size->new( width => $width, height => $height );

    # Then create context with buffer and layout dimensions
    # Don't pass the screen parameter directly to Context constructor
    return Clay::Context->new(
        buffer            => $buffer,
        layout_dimensions => $layout_dimensions
    );
}

# Create a root element
sub create_root( $context, $config = { id => 'root' } ) {
    $config->{id} //= 'root';
    my $root_builder = Clay::Builder::ElementBuilder->new(
        context => $context,
        config  => $config
    );

    # Set as the root of the context
    $context->element_tree( $root_builder->element );

    return $root_builder;
}

# Layout helper functions
sub sizing_fit( $min = 0, $max = 1000 ) {
    return {
        sizing_width_type => $__SIZING_FIT,
        sizing_width_min  => $min,
        sizing_width_max  => $max
    };
}

sub sizing_grow( $min = 0, $max = 1000 ) {
    return {
        sizing_width_type => $__SIZING_GROW,
        sizing_width_min  => $min,
        sizing_width_max  => $max
    };
}

sub sizing_fixed($value) {
    return {
        sizing_width_type  => $__SIZING_FIXED,
        sizing_width_value => $value
    };
}

sub sizing_percent($percent) {
    return {
        sizing_width_type  => $__SIZING_PERCENT,
        sizing_width_value => $percent
    };
}

# Color helpers
sub color( $r, $g, $b, $a = 255, $foreground = 0 ) {
    return Clay::Types::Color->new(
        r          => $r,
        g          => $g,
        b          => $b,
        a          => $a,
        foreground => $foreground
    );
}

# Common colors
sub color_black( $foreground = 0 ) {
    return color( 0, 0, 0, 255, $foreground );
}

sub color_white( $foreground = 0 ) {
    return color( 255, 255, 255, 255, $foreground );
}

sub color_red( $foreground = 0 ) {
    return color( 255, 0, 0, 255, $foreground );
}

sub color_green( $foreground = 0 ) {
    return color( 0, 255, 0, 255, $foreground );
}

sub color_blue( $foreground = 0 ) {
    return color( 0, 0, 255, 255, $foreground );
}

sub color_yellow( $foreground = 0 ) {
    return color( 255, 255, 0, 255, $foreground );
}

# Layout helpers
sub layout_horizontal( $config = {} ) {
    return Clay::Util::with_defaults(
        $config,
        {
            layout_direction => $__LEFT_TO_RIGHT
        }
    );
}

sub layout_vertical( $config = {} ) {
    return Clay::Util::with_defaults(
        $config,
        {
            layout_direction => $__TOP_TO_BOTTOM
        }
    );
}

# Border helpers
sub border_all( $width, $color ) {
    return Clay::Types::BorderConfig->new(
        color        => $color,
        width_left   => $width,
        width_right  => $width,
        width_top    => $width,
        width_bottom => $width
    );
}

sub border_box($color) {
    return border_all( 1, $color );
}

# Padding helpers
sub padding_all($padding) {
    return Clay::Types::Padding->new(
        left   => $padding,
        right  => $padding,
        top    => $padding,
        bottom => $padding
    );
}

# Text config helpers
sub text_config( $color, $config = {} ) {
    return Clay::Util::with_defaults(
        $config,
        {
            color          => $color,
            wrap_mode      => $__WRAP_WORDS,
            text_alignment => $__ALIGN_LEFT
        }
    );
}

1;
