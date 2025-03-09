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
        border_config => border_all(1, color(200, 200, 200)),
        children => [
            # Container for the first rectangle
            {
                id => 'red-container',
                layout_config => Clay::Types::LayoutConfig->new(
                    sizing_width_type => $SIZING_GROW,
                    sizing_height_type => $SIZING_FIXED,
                    sizing_height_value => 5,
                    padding => padding_all(1),
                ),
                border_config => border_all(1, color(255, 0, 0)), # Red border
                children => [
                    {
                        text => "Red Rectangle",
                        text_config => text_config(color_white(1)),
                    }
                ]
            },
            # Container for the second rectangle
            {
                id => 'green-container',
                layout_config => Clay::Types::LayoutConfig->new(
                    sizing_width_type => $SIZING_GROW,
                    sizing_height_type => $SIZING_FIXED,
                    sizing_height_value => 5,
                    padding => padding_all(1),
                ),
                border_config => border_all(1, color(0, 255, 0)), # Green border
                children => [
                    {
                        text => "Green Rectangle",
                        text_config => text_config(color_white(1)),
                    }
                ]
            },
            # Container for the third rectangle
            {
                id => 'blue-container',
                layout_config => Clay::Types::LayoutConfig->new(
                    sizing_width_type => $SIZING_GROW,
                    sizing_height_type => $SIZING_FIXED,
                    sizing_height_value => 5,
                    padding => padding_all(1),
                ),
                border_config => border_all(1, color(0, 0, 255)), # Blue border
                children => [
                    {
                        text => "Blue Rectangle",
                        text_config => text_config(color_white(1)),
                    }
                ]
            },
            {
                id => 'instructions',
                layout_config => Clay::Types::LayoutConfig->new(
                    sizing_width_type => $SIZING_FIT,
                    sizing_height_type => $SIZING_FIT,
                    padding => padding_all(1),
                ),
                text => 'Multiple rectangles rendered. Press any key to exit...',
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