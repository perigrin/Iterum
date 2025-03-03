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
print "This example demonstrates text rendering.\n";
print "The text 'Hello, World!' will be rendered at position (10,5).\n";
print "Press any key to continue...\n";
ReadMode 4;  # Turn off controls keys
ReadKey(0);  # Wait for a keypress
ReadMode 0;  # Reset terminal

# Clear screen first
$context->clear();

# Create text command
my $text_cmd = {
    type => 'text',
    position => Clay::Types::Point->new(x => 10, y => 5),
    text => 'Hello, World!',
    config => Clay::Types::TextConfig->new(
        color => Clay::Types::Color->new(r => 255, g => 255, b => 255),
    ),
};

# Render the text
$context->_render_text($text_cmd);

# Create another text with different color
my $text_cmd2 = {
    type => 'text',
    position => Clay::Types::Point->new(x => 10, y => 7),
    text => 'Green Text!',
    config => Clay::Types::TextConfig->new(
        color => Clay::Types::Color->new(r => 0, g => 255, b => 0),
    ),
};

# Render the second text
$context->_render_text($text_cmd2);

# Display instructions at the bottom of the screen
$context->_render_text({
    type => 'text',
    position => Clay::Types::Point->new(x => 1, y => 20),
    text => 'Text rendered. Press any key to exit...',
    config => Clay::Types::TextConfig->new(
        color => Clay::Types::Color->new(r => 255, g => 255, b => 255),
    ),
});

# Wait for key press to exit
ReadMode 4;  # Turn off controls keys
ReadKey(0);  # Wait for a keypress
ReadMode 0;  # Reset terminal