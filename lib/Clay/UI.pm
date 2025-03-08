package Clay::UI;
use 5.40.0;
use Clay::Util;
use Clay::Context;
use Clay::Builder;
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

# Create a new context with proper buffer
sub create_context( $args = {} ) {

    # Create a buffer with the screen
    my $buffer = $args->{buffer} // Clay::Buffer->new(%$args);

    # Create layout dimensions as a separate object
    my $layout_dimensions = Clay::Types::Size->new(
        width  => $buffer->width,
        height => $buffer->height
    );

    # Create context with buffer and layout dimensions
    my $context = Clay::Context->new(
        buffer            => $buffer,
        layout_dimensions => $layout_dimensions
    );

    return $context;
}

sub create_element( $context, $config = {} ) {

    # Process children if any
    if ( exists $config->{children} && ref $config->{children} eq 'ARRAY' ) {
        for my $i ( 0 .. $#{ $config->{children} } ) {
            my $child_conf = $config->{children}[$i];
            $config->{children}[$i] =
              create_element( $context, $child_conf )->element;
        }
    }

    return Clay::Builder::ElementBuilder->new(
        context => $context,
        config  => $config
    );
}

# Create a root element
sub create_root( $context, $builder = undef ) {
    unless ( $builder && $builder isa Clay::Builder::ElementBuilder ) {
        $builder = create_element( $context, $builder );
    }

    # Set as the root of the context
    $context->element_tree( $builder->element );

    return $builder;
}

# Layout helper functions
sub sizing_fit( $min = 0, $max = 1000 ) {
    return {
        sizing_width_type => $SIZING_FIT,
        sizing_width_min  => $min,
        sizing_width_max  => $max
    };
}

sub sizing_grow( $min = 0, $max = 1000 ) {
    return {
        sizing_width_type => $SIZING_GROW,
        sizing_width_min  => $min,
        sizing_width_max  => $max
    };
}

sub sizing_fixed($value) {
    return {
        sizing_width_type  => $SIZING_FIXED,
        sizing_width_value => $value
    };
}

sub sizing_percent($percent) {
    return {
        sizing_width_type  => $SIZING_PERCENT,
        sizing_width_value => $percent
    };
}

# Color helpers
sub color( $r, $g, $b, $a = 255 ) {
    return Clay::Types::Color->new(
        r => $r,
        g => $g,
        b => $b,
        a => $a,
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
            layout_direction => $LEFT_TO_RIGHT
        }
    );
}

sub layout_vertical( $config = {} ) {
    return Clay::Util::with_defaults(
        $config,
        {
            layout_direction => $TOP_TO_BOTTOM
        }
    );
}

sub border( $left, $right, $top, $bottom, $color, $style = 'single' ) {
    return Clay::Types::BorderConfig->new(
        color        => $color,
        width_left   => $left,
        width_right  => $right,
        width_top    => $top,
        width_bottom => $bottom,
        style        => $style
    );
}

# Border helpers
sub border_all( $width, $color, $style = 'single' ) {
    return border( $width, $width, $width, $width, $color, $style );
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
            wrap_mode      => $WRAP_WORDS,
            text_alignment => $ALIGN_LEFT
        }
    );
}

1;
