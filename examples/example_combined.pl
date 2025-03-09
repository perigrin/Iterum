#!/usr/bin/env perl
use 5.40.0;
use warnings;
use utf8;
use FindBin qw($Bin);
use lib "$Bin/../lib";

# Ensure UTF-8 output
binmode(STDOUT, ":utf8");

# Import Clay modules
use Clay;

# Create context
my $context = create_context();

my $root = create_root(
    $context,
    {
        id => 'root',
        layout_config => Clay::Types::LayoutConfig->new(
            sizing_width_type => $SIZING_GROW,
            sizing_height_type => $SIZING_GROW,
            layout_direction => $TOP_TO_BOTTOM,
            padding => padding_all(2),
            child_gap => 2,
            alignment_x => $ALIGN_CENTER,
            alignment_y => $ALIGN_CENTER
        ),
        background_color => color(30, 30, 30),
        children => [
            {
                id => 'container',
                layout_config => Clay::Types::LayoutConfig->new(
                    sizing_width_type => $SIZING_FIXED,
                    sizing_width_value => 20,
                    sizing_height_type => $SIZING_FIXED,
                    sizing_height_value => 10,
                    layout_direction => $TOP_TO_BOTTOM,
                    padding => padding_all(2),
                    child_gap => 2,
                ),
                background_color => color(60, 60, 60),
                border_config => border_all(1, color(255, 255, 255)),
                children => [
                    {
                        id => 'text1',
                        layout_config => Clay::Types::LayoutConfig->new(
                            sizing_width_type => $SIZING_FIT,
                            sizing_height_type => $SIZING_FIT,
                        ),
                        text => 'Hello, World!',
                        text_config => text_config(color_green(1)),
                    },
                    {
                        id => 'text2',
                        layout_config => Clay::Types::LayoutConfig->new(
                            sizing_width_type => $SIZING_FIT,
                            sizing_height_type => $SIZING_FIT,
                        ),
                        text => 'This text is inside a box',
                        text_config => text_config(color_yellow(1)),
                    },
                ],
            },
            {
                id => 'instructions',
                layout_config => Clay::Types::LayoutConfig->new(
                    sizing_width_type => $SIZING_FIT,
                    sizing_height_type => $SIZING_FIT,
                    padding => padding_all(1),
                ),
                text => 'Combined rendering. Press any key to exit...',
                text_config => text_config(color_white(1)),
            }
        ],
    }
);

while (1) {
    if ($context->layout()) {
        $context->render();
    }
    
    if ($context->key_pressed()) {
        # Exit on any key press
        last;
    }
    
    # Small delay to prevent excessive CPU usage
    select(undef, undef, undef, 0.05);
}

__END__