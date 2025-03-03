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
print "This example demonstrates combined rendering of multiple primitives.\n";
print "A gray rectangle, white border, and green text will be rendered together.\n";
print "Press any key to continue...\n";
ReadMode 4;  # Turn off controls keys
ReadKey(0);  # Wait for a keypress
ReadMode 0;  # Reset terminal

# Clear screen first
$context->clear();

# Create commands array with z-index ordering
my $commands = [
    {
        type => 'rectangle',
        rect => Clay::Types::Rect->new(x => 5, y => 5, width => 20, height => 10),
        color => Clay::Types::Color->new(r => 60, g => 60, b => 60),
        z_index => 0,
    },
    {
        type => 'border',
        rect => Clay::Types::Rect->new(x => 5, y => 5, width => 20, height => 10),
        config => Clay::Types::BorderConfig->new(
            width_top => 1,
            width_right => 1,
            width_bottom => 1,
            width_left => 1,
            color => Clay::Types::Color->new(r => 255, g => 255, b => 255),
        ),
        z_index => 1,
    },
    {
        type => 'text',
        position => Clay::Types::Point->new(x => 7, y => 7),
        text => 'Hello, World!',
        config => Clay::Types::TextConfig->new(
            color => Clay::Types::Color->new(r => 0, g => 255, b => 0),
        ),
        z_index => 2,
    },
    {
        type => 'text',
        position => Clay::Types::Point->new(x => 7, y => 9),
        text => 'This text is inside a box',
        config => Clay::Types::TextConfig->new(
            color => Clay::Types::Color->new(r => 255, g => 255, b => 0),
        ),
        z_index => 2,
    },
    {
        type => 'text',
        position => Clay::Types::Point->new(x => 1, y => 20),
        text => 'Combined rendering. Press any key to exit...',
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