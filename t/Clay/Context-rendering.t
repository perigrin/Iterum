#!/usr/bin/env perl
use 5.40.0;
use warnings;
use utf8;
binmode(STDOUT, ":utf8");
use Test::More;
use Test::Deep;
use FindBin;
use lib "$FindBin::Bin/../../lib";

# Import the modules we need to test
use Clay::Context;
use Clay::Types::LayoutConfig;
use Clay::Types::Point;
use Clay::Types::Size;
use Clay::Types::Rect;
use Clay::Types::BorderConfig;
use Clay::Types::TextConfig;
use Clay::Types::Color;
use Clay::Buffer;
use Test::Term::Screen;

# Main test plan
plan tests => 4;

# Helper function to create a test context
sub create_test_context {
    my $screen = Test::Term::Screen->new(rows => 24, cols => 80);
    my $buffer = Clay::Buffer->new(screen => $screen);
    
    # No need to pass layout_dimensions as it's now derived from buffer automatically
    return Clay::Context->new(buffer => $buffer);
}

# Test rendering a rectangle
subtest 'Rectangle Rendering' => sub {
    plan tests => 5;
    
    my $context = create_test_context();
    my $buffer = $context->buffer;
    
    # Create a mock fill command to test buffer interaction
    my ($fill_row, $fill_col, $fill_width, $fill_height) = (0, 0, 0, 0);
    {
        no warnings 'redefine';
        my $original_fill = \&Clay::Buffer::fill;
        local *Clay::Buffer::fill = sub {
            my ($self, $row, $col, $width, $height) = @_;
            $fill_row = $row;
            $fill_col = $col;
            $fill_width = $width;
            $fill_height = $height;
            $original_fill->(@_);
        };
        
        # Create rectangle command
        my $rect_cmd = {
            type => 'rectangle',
            rect => Clay::Types::Rect->new(x => 5, y => 5, width => 10, height => 8),
            color => Clay::Types::Color->new(r => 255, g => 255, b => 255),
        };
        
        # Render the rectangle
        $context->_render_rectangle($rect_cmd);
        
        # Check that fill was called with correct parameters
        is($fill_row, 5, 'Rectangle fill row correct');
        is($fill_col, 5, 'Rectangle fill column correct');
        is($fill_width, 10, 'Rectangle fill width correct');
        is($fill_height, 8, 'Rectangle fill height correct');
    }
    
    # Test with invalid dimensions
    {
        no warnings 'redefine';
        my $original_fill = \&Clay::Buffer::fill;
        my $fill_called = 0;
        local *Clay::Buffer::fill = sub { $fill_called = 1; };
        
        # Create invalid rectangle command with negative width
        my $rect_cmd = {
            type => 'rectangle',
            rect => Clay::Types::Rect->new(x => 5, y => 5, width => -10, height => 8),
            color => Clay::Types::Color->new(r => 255, g => 255, b => 255),
        };
        
        # Render the rectangle - should not call fill
        $context->_render_rectangle($rect_cmd);
        is($fill_called, 0, 'fill not called with negative width');
    }
};

# Test rendering a border
subtest 'Border Rendering' => sub {
    plan tests => 9;
    
    my $context = create_test_context();
    my $buffer = $context->buffer;
    my $screen = $buffer->screen;
    
    # Variables to count method calls
    my $h_line_top_called = 0;
    my $h_line_bottom_called = 0;
    my $tl_corner_seen = 0;
    my $tr_corner_seen = 0;
    my $bl_corner_seen = 0;
    my $br_corner_seen = 0;
    
    # Mock the buffer methods for this test
    {
        no warnings 'redefine';
        
        # Track put_char for corners
        local *Clay::Buffer::put_char = sub {
            my ($self, $row, $col, $char) = @_;
            
            # Check for corners
            if ($row == 5 && $col == 5 && $char eq '┌') {
                $tl_corner_seen = 1;
                pass('Top left corner character correct');
            }
            elsif ($row == 5 && $col == 14 && $char eq '┐') {
                $tr_corner_seen = 1;
                pass('Top right corner character correct');
            }
            elsif ($row == 12 && $col == 5 && $char eq '└') {
                $bl_corner_seen = 1;
                pass('Bottom left corner character correct');
            }
            elsif ($row == 12 && $col == 14 && $char eq '┘') {
                $br_corner_seen = 1;
                pass('Bottom right corner character correct');
            }
        };
        
        # Track draw_hline calls
        local *Clay::Buffer::draw_hline = sub {
            my ($self, $row, $col, $width) = @_;
            
            if ($row == 5) {
                $h_line_top_called = 1;
                is($width, 8, 'Top horizontal line width correct');
            }
            elsif ($row == 12) {
                $h_line_bottom_called = 1;
                is($width, 8, 'Bottom horizontal line width correct');
            }
        };
        
        # Create border command
        my $config = Clay::Types::BorderConfig->new(
            width_top => 1,
            width_right => 1,
            width_bottom => 1,
            width_left => 1,
            color => Clay::Types::Color->new(r => 255, g => 255, b => 255),
        );
        
        my $border_cmd = {
            type => 'border',
            rect => Clay::Types::Rect->new(x => 5, y => 5, width => 10, height => 8),
            config => $config,
        };
        
        # Render the border
        $context->_render_border($border_cmd);
        
        # Verify all corners were drawn
        is($tl_corner_seen + $tr_corner_seen + $bl_corner_seen + $br_corner_seen, 4, 'All corners were drawn');
        
        # Test small width border
        my $put_char_small_called = 0;
        local *Clay::Buffer::put_char = sub { $put_char_small_called = 1; };
        
        my $small_border_cmd = {
            type => 'border',
            rect => Clay::Types::Rect->new(x => 5, y => 5, width => 2, height => 8),
            config => Clay::Types::BorderConfig->new(
                width_top => 1, 
                width_right => 1, 
                width_bottom => 1, 
                width_left => 1,
                color => Clay::Types::Color->new(r => 255, g => 255, b => 255),
            ),
        };
        
        $context->_render_border($small_border_cmd);
        is($put_char_small_called, 0, 'put_char not called with small width');
        
        # Add one more assertion to meet our plan of 9 tests
        ok(($h_line_top_called && $h_line_bottom_called), 'Horizontal lines were drawn for top and bottom');
    }
};

# Test rendering text
subtest 'Text Rendering' => sub {
    plan tests => 3;
    
    my $context = create_test_context();
    my $buffer = $context->buffer;
    
    # Check that put_string is called properly
    my ($put_row, $put_col, $put_text) = (0, 0, '');
    {
        no warnings 'redefine';
        local *Clay::Buffer::put_string = sub {
            my ($self, $row, $col, $text) = @_;
            $put_row = $row;
            $put_col = $col;
            $put_text = $text;
        };
        
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
        
        # Check that put_string was called with correct parameters
        is($put_row, 5, 'Text row position correct');
        is($put_col, 10, 'Text column position correct');
        is($put_text, 'Hello, World!', 'Text content correct');
    }
};

# Test rendering multiple elements together
subtest 'Complete Rendering' => sub {
    plan tests => 3;
    
    my $context = create_test_context();
    
    # Track render command execution
    my ($rectangle_calls, $border_calls, $text_calls) = (0, 0, 0);
    {
        no warnings 'redefine';
        local *Clay::Context::_render_rectangle = sub { $rectangle_calls++; };
        local *Clay::Context::_render_border = sub { $border_calls++; };
        local *Clay::Context::_render_text = sub { $text_calls++; };
        
        # Create array of commands for context
        my $commands = [
            {
                type => 'rectangle',
                rect => Clay::Types::Rect->new(x => 5, y => 5, width => 10, height => 8),
                color => Clay::Types::Color->new(r => 255, g => 255, b => 255),
                z_index => 0,
            },
            {
                type => 'border',
                rect => Clay::Types::Rect->new(x => 5, y => 5, width => 10, height => 8),
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
                position => Clay::Types::Point->new(x => 10, y => 5),
                text => 'Hello, World!',
                config => Clay::Types::TextConfig->new(
                    color => Clay::Types::Color->new(r => 255, g => 255, b => 255),
                ),
                z_index => 2,
            },
        ];
        
        # Set commands directly 
        $context->commands($commands);
        
        # Render all commands
        $context->render();
        
        # Check that each render method was called once
        is($rectangle_calls, 1, 'Rectangle render method called');
        is($border_calls, 1, 'Border render method called');
        is($text_calls, 1, 'Text render method called');
    }
};

done_testing();