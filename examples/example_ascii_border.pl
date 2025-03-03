#!/usr/bin/env perl
use 5.40.0;
use warnings;
use utf8;
binmode(STDOUT, ":utf8");
use Term::ReadKey;
use Term::Screen;
use FindBin qw($Bin);
use lib "$Bin/../lib";

# Import Clay modules
use Clay;

# Create screen and context
my $screen = Term::Screen->new();
my $context = create_context($screen);

# Instructions
print "This example demonstrates ASCII border rendering.\n";
print "A white ASCII border will be rendered at position (5,5) with size 10x8.\n";
print "Press any key to continue...\n";
ReadMode 4;  # Turn off controls keys
ReadKey(0);  # Wait for a keypress
ReadMode 0;  # Reset terminal

# Clear screen first
$context->clear();

# Create border command with ASCII characters
my $border_cmd = {
    type => 'border',
    rect => Clay::Types::Rect->new(x => 5, y => 5, width => 10, height => 8),
    config => Clay::Types::BorderConfig->new(
        width_top => 1,
        width_right => 1,
        width_bottom => 1,
        width_left => 1,
        color => Clay::Types::Color->new(r => 255, g => 255, b => 255),
    ),
    use_ascii => 1, # Use ASCII characters instead of Unicode
};

# Render the border
$context->_render_border($border_cmd);

# Display instructions at the bottom of the screen
$context->buffer->put_string(20, 1, "ASCII border rendered. Press any key to exit...", {});
$context->buffer->refresh();

# Wait for key press to exit
ReadMode 4;  # Turn off controls keys
ReadKey(0);  # Wait for a keypress
ReadMode 0;  # Reset terminal