#!/usr/bin/env perl
use 5.40.0;
use warnings;
use utf8;
use FindBin qw($Bin);
use lib "$Bin/../lib";

# Ensure UTF-8 output
binmode( STDOUT, ":utf8" );

# Import Clay modules
use Clay;

# Create screen and context
my $context = create_context();

my $root = create_root(
    $context,
    {
        id            => 'root',
        layout_config => Clay::Types::LayoutConfig->new(
            sizing_width_type  => $SIZING_GROW,
            sizing_height_type => $SIZING_GROW,
            padding            => padding_all(2),
            alignment_x        => $ALIGN_CENTER,
            alignment_y        => $ALIGN_CENTER
        ),
        border_config => border_all( 2, color( 200, 200, 200 ), 'double' ),
        children      => [
            {
                id            => 'text-box',
                layout_config => Clay::Types::LayoutConfig->new(

                    sizing_width_type => $SIZING_FIT,
                    layout_direction  => $TOP_TO_BOTTOM,
                    child_gap         => 1,
                    alignment_x       => $ALIGN_CENTER,
                    alignment_y       => $ALIGN_CENTER,
                ),
                children => [
                    {
                        text =>
'This example demonstrates combined rendering of multiple primitives.',

                    },
                    {
                        text =>
'A gray rectangle, white border, and green text will be rendered together.',
                    },
                    {
                        text => 'Press any key to continue...',
                    },
                ]
            }
        ],
    }
);

while (1) {

    # Layout will now automatically check for dimension changes
    if ( $context->layout() ) {
        $context->render();
    }

    if ( $context->key_pressed() ) {
        $context->handle_event( $context->get_key() );
    }

    # Small delay to prevent excessive CPU usage
    select( undef, undef, undef, 0.05 );
}
__END__
