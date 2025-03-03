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
print "This example demonstrates multiple rectangles with different colors.\n";
print "Press any key to continue...\n";
ReadMode 4;  # Turn off controls keys
ReadKey(0);  # Wait for a keypress
ReadMode 0;  # Reset terminal

# Clear screen first
$context->clear();

# Create commands array with z-index ordering (explicitly use commands)
my $commands = [
    # Red rectangle
    {
        type => 'rectangle',
        rect => Clay::Types::Rect->new(x => 5, y => 5, width => 10, height => 5),
        color => Clay::Types::Color->new(r => 255, g => 0, b => 0),
        z_index => 0,
    },
    # Green rectangle
    {
        type => 'rectangle',
        rect => Clay::Types::Rect->new(x => 10, y => 7, width => 10, height => 5),
        color => Clay::Types::Color->new(r => 0, g => 255, b => 0),
        z_index => 1,
    },
    # Blue rectangle
    {
        type => 'rectangle',
        rect => Clay::Types::Rect->new(x => 15, y => 9, width => 10, height => 5),
        color => Clay::Types::Color->new(r => 0, g => 0, b => 255),
        z_index => 2,
    },
    # Instructions
    {
        type => 'text',
        position => Clay::Types::Point->new(x => 1, y => 20),
        text => 'Multiple rectangles rendered. Press any key to exit...',
        config => Clay::Types::TextConfig->new(
            color => Clay::Types::Color->new(r => 255, g => 255, b => 255),
        ),
        z_index => 3,
    },
];

# Set commands and render
$context->commands($commands);
$context->render();

# Wait for key press to exit
ReadMode 4;  # Turn off controls keys
ReadKey(0);  # Wait for a keypress
ReadMode 0;  # Reset terminal