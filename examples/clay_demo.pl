#!/usr/bin/env perl
use 5.40.0;
use warnings;
use utf8;
use Term::ReadKey;
use FindBin qw($Bin);
use lib "$Bin/../lib";

# Ensure UTF-8 output
binmode( STDOUT, ":utf8" );

# Import Clay modules and constants
use Clay;

# Initialize by creating a context
my $context = create_context();

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
        border_config    => border_box( color( 200, 200, 200 ) ),
        children         => [
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
                border_config    => border_all( 1, color( 100, 100, 100 ) ),
                children         => [
                    {
                        text        => "Clay Demo",
                        text_config => text_config(
                            color_white(1),
                            {
                                font_size => 16
                            }
                        )
                    }
                ]
            },
            {
                id            => 'content',
                layout_config => Clay::Types::LayoutConfig->new(
                    sizing_width_type  => $SIZING_GROW,
                    sizing_height_type => $SIZING_GROW,
                    layout_direction   => $TOP_TO_BOTTOM,
                    padding            => padding_all(2),
                    child_gap          => 1
                ),
                background_color => color( 40, 40, 40 ),
                children         => [
                    {

                        text => "This is a Clay-inspired UI system for Perl",
                        text_config => text_config( color_white(1) )
                    },
                    {
                        text        => "It supports:",
                        text_config => text_config( color_yellow(1) )
                    },
                    {
                        layout_config => Clay::Types::LayoutConfig->new(
                            sizing_width_type  => $SIZING_GROW,
                            sizing_height_type => $SIZING_FIT,
                            layout_direction   => $TOP_TO_BOTTOM,
                            padding            => padding_all(2),
                            child_gap          => 0
                        ),
                        children => [
                            map {
                                {
                                    text        => "• $_",
                                    text_config => text_config( color_green(1) )
                                }
                            } (
                                "Nested layouts",
                                "Flexible sizing",
                                "Text wrapping",
                                "Borders",
                                "Colors",
                                "Event handling"
                            )
                        ]
                    },
                    {
                        id            => 'buttons',
                        layout_config => Clay::Types::LayoutConfig->new(
                            sizing_width_type   => $SIZING_GROW,
                            sizing_height_type  => $SIZING_FIXED,
                            sizing_height_value => 3,
                            layout_direction    => $LEFT_TO_RIGHT,
                            padding             => padding_all(0),
                            child_gap           => 4,
                            alignment_x         => $ALIGN_CENTER,
                        ),
                        border_config => border_box( color( 200, 200, 200 ) ),
                        children      => [
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
                                border_config    =>
                                  border_all( 1, color( 100, 100, 200 ) ),
                                children => [
                                    {
                                        text        => "Button 1",
                                        text_config =>
                                          text_config( color_white(1) )
                                    }
                                ]
                            },
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
                                border_config    =>
                                  border_all( 1, color( 200, 100, 100 ) ),
                                children => [
                                    {
                                        text        => "Button 2",
                                        text_config =>
                                          text_config( color_white(1) )
                                    }
                                ]
                            }
                        ],
                    },
                ],
            },
            {
                id            => 'footer',
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
                border_config    => border_all( 1, color( 100, 100, 100 ) ),
                children         => [
                    {
                        text        => "Press 'q' to quit",
                        text_config => text_config( color_white(1) )
                    }
                ]
            }
        ],
    }
);

# Layout and render
$context->layout();
$context->render();

while (1) {
    next unless $context->key_pressed();
    $context->handle_event( $context->get_key() );
    $context->render();
}
__END__
