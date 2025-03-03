#!/usr/bin/env perl
use 5.40.0;
use warnings;
use utf8;
use Term::ReadKey;
use FindBin qw($Bin);
use lib "$Bin/../lib";

# Ensure UTF-8 output
binmode(STDOUT, ":utf8");

# Import Clay modules and constants
use Clay;

# Initialize by creating a context
my $context = create_context( Term::Screen->new() );

# Build the UI element tree
my $root = create_root(
    $context,
    {
        layout_config => Clay::Types::LayoutConfig->new(
            sizing_width_type  => $SIZING_GROW,
            sizing_height_type => $SIZING_GROW,
            layout_direction   => $TOP_TO_BOTTOM,
            padding            => padding_all(1)
        ),
        background_color => color( 30, 30, 30 ),
        border_config    => border_box( color( 200, 200, 200 ) )
    }
);

# Add header
my $header = $root->child(
    {
        id            => 'header',
        layout_config => Clay::Types::LayoutConfig->new(
            sizing_width_type   => $SIZING_GROW,
            sizing_height_type  => $SIZING_FIXED,
            sizing_height_value => 3,
            layout_direction    => $LEFT_TO_RIGHT,
            padding             => padding_all(1),
            alignment_y         => $ALIGN_CENTER
        ),
        background_color => color( 60, 60, 60 ),
        border_config    => border_all( 1, color( 100, 100, 100 ) )
    }
);

# Add header text
$header->text(
    "Clay UI for Perl",
    {
        text_config => text_config(
            color_white(1),
            {
                font_size => 16
            }
        )
    }
);

# Add main content
my $content = $root->child(
    {
        layout_config => Clay::Types::LayoutConfig->new(
            sizing_width_type  => $SIZING_GROW,
            sizing_height_type => $SIZING_GROW,
            layout_direction   => $TOP_TO_BOTTOM,
            padding            => padding_all(2),
            child_gap          => 1
        ),
        background_color => color( 40, 40, 40 )
    }
);

# Add some content items
$content->text(
    "This is a Clay-inspired UI system for Perl",
    {
        text_config => text_config( color_white(1) )
    }
);

$content->text(
    "It supports:",
    {
        text_config => text_config( color_yellow(1) )
    }
);

# Add a list of features
my $features = $content->child(
    {
        layout_config => Clay::Types::LayoutConfig->new(
            sizing_width_type  => $SIZING_GROW,
            sizing_height_type => $SIZING_FIT,
            layout_direction   => $TOP_TO_BOTTOM,
            padding            => padding_all(2),
            child_gap          => 0
        )
    }
);

foreach my $feature (
    "Nested layouts",
    "Flexible sizing",
    "Text wrapping",
    "Borders",
    "Colors",
    "Event handling"
  )
{
    $features->text(
        "• $feature",
        {
            text_config => text_config( color_green(1) )
        }
    );
}

# Add buttons row
my $buttons = $content->child(
    {
        layout_config => Clay::Types::LayoutConfig->new(
            sizing_width_type   => $SIZING_GROW,
            sizing_height_type  => $SIZING_FIXED,
            sizing_height_value => 3,
            layout_direction    => $LEFT_TO_RIGHT,
            padding             => padding_all(0),
            child_gap           => 4,
            alignment_x         => $ALIGN_CENTER
        )
    }
);

# Add button 1
my $button1 = $buttons->child(
    {
        layout_config => Clay::Types::LayoutConfig->new(
            sizing_width_type   => $SIZING_FIXED,
            sizing_width_value  => 14,
            sizing_height_type  => $SIZING_FIXED,
            sizing_height_value => 3,
            padding             => padding_all(1),
            alignment_x         => $ALIGN_CENTER,
            alignment_y         => $ALIGN_CENTER
        ),
        background_color => color( 70, 70, 200 ),
        border_config    => border_all( 1, color( 100, 100, 200 ) )
    }
);

$button1->text(
    "Button 1",
    {
        text_config => text_config( color_white(1) )
    }
);

# Add button 2
my $button2 = $buttons->child(
    {
        layout_config => Clay::Types::LayoutConfig->new(
            sizing_width_type   => $SIZING_FIXED,
            sizing_width_value  => 14,
            sizing_height_type  => $SIZING_FIXED,
            sizing_height_value => 3,
            padding             => padding_all(1),
            alignment_x         => $ALIGN_CENTER,
            alignment_y         => $ALIGN_CENTER
        ),
        background_color => color( 200, 70, 70 ),
        border_config    => border_all( 1, color( 200, 100, 100 ) )
    }
);

$button2->text(
    "Button 2",
    {
        text_config => text_config( color_white(1) )
    }
);

# Add footer
my $footer = $root->child(
    {
        layout_config => Clay::Types::LayoutConfig->new(
            sizing_width_type   => $SIZING_GROW,
            sizing_height_type  => $SIZING_FIXED,
            sizing_height_value => 3,
            layout_direction    => $LEFT_TO_RIGHT,
            padding             => padding_all(1),
            alignment_y         => $ALIGN_CENTER,
            alignment_x         => $ALIGN_CENTER
        ),
        background_color => color( 60, 60, 60 ),
        border_config    => border_all( 1, color( 100, 100, 100 ) )
    }
);

$footer->text(
    "Press 'q' to quit",
    {
        text_config => text_config( color_white(1) )
    }
);

# Layout and render
$context->layout();
$context->render();

use Clay::Types::Event;

# Simple event loop
ReadMode 4;    # Turn off controls keys

my $running = 1;
while ($running) {
    if ( defined( my $key = ReadKey(-1) ) ) {
        if ( $key eq 'q' ) {
            $running = 0;
        }

        # Create an event and handle it
        my $event = Clay::Types::Event->new(
            type => 'key',
            key  => $key
        );

        $context->handle_event($event);

        # Re-render if needed based on events
        $context->render();
    }

    # Sleep to avoid using 100% CPU
    select( undef, undef, undef, 0.03 );
}

ReadMode 0;    # Reset terminal
print "\n";
