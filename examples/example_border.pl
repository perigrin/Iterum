#!/usr/bin/env perl
use 5.40.0;
use warnings;
use utf8;
use Term::ReadKey;
use Term::Screen;
use FindBin qw($Bin);
use lib "$Bin/../lib";

# Ensure UTF-8 output
binmode(STDOUT, ":utf8");

# Import Clay modules
use Clay;

# Create screen and context
my $screen = Term::Screen->new();
my $context = create_context($screen);

# Instructions
print "This example demonstrates border rendering.\n";
print "A white border will be rendered at position (5,5) with size 10x8.\n";
print "Press any key to continue...\n";
ReadMode 4;  # Turn off controls keys
ReadKey(0);  # Wait for a keypress
ReadMode 0;  # Reset terminal

# Clear screen first
$context->clear();

# Create border command
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
};

# Render the border
$context->_render_border($border_cmd);

# Display instructions at the bottom of the screen
$context->_render_text({
    type => 'text',
    position => Clay::Types::Point->new(x => 1, y => 20),
    text => 'Border rendered. Press any key to exit...',
    config => Clay::Types::TextConfig->new(
        color => Clay::Types::Color->new(r => 255, g => 255, b => 255),
    ),
});

# Wait for key press to exit
ReadMode 4;  # Turn off controls keys
ReadKey(0);  # Wait for a keypress
ReadMode 0;  # Reset terminal