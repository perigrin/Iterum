#!/usr/bin/env perl
use 5.40.0;
use warnings;
use utf8;
binmode(STDOUT, ":utf8");
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../../lib";

# Import the modules we need to test
use Clay::Buffer;
use Test::Term::Screen;
use Clay::Types::Size;
use Clay::Types::Color;
use Clay::Types::Point;

# Test plan
plan tests => 9;

# Test the validation in fill method
subtest 'fill method validation' => sub {
    plan tests => 5;
    
    # Create a test screen and buffer
    my $screen = Test::Term::Screen->new(rows => 24, cols => 80);
    my $buffer = Clay::Buffer->new(screen => $screen);
    
    # Enable debug mode to capture warnings
    $buffer->set_debug_mode(1);
    
    # Test with negative width
    {
        local $SIG{__WARN__} = sub { like $_[0], qr/Invalid fill dimensions/, 'Warning about negative width'; };
        $buffer->fill(5, 5, -10, 5, 'X');
    }
    
    # Test with zero width
    {
        local $SIG{__WARN__} = sub { like $_[0], qr/Invalid fill dimensions/, 'Warning about zero width'; };
        $buffer->fill(5, 5, 0, 5, 'X');
    }
    
    # Test with negative height
    {
        local $SIG{__WARN__} = sub { like $_[0], qr/Invalid fill dimensions/, 'Warning about negative height'; };
        $buffer->fill(5, 5, 5, -2, 'X');
    }
    
    # Test with out of bounds position
    {
        local $SIG{__WARN__} = sub { like $_[0], qr/Fill position out of bounds/, 'Warning about out of bounds position'; };
        $buffer->fill(-1, 5, 5, 5, 'X');
    }
    
    # Test valid parameters - should not warn
    {
        my $warned = 0;
        local $SIG{__WARN__} = sub { $warned = 1; };
        $buffer->fill(5, 5, 5, 5, 'X');
        is($warned, 0, 'No warnings with valid parameters');
    }
};

# Test the validation in draw_hline method
subtest 'draw_hline method validation' => sub {
    plan tests => 2;
    
    # Create a test screen and buffer
    my $screen = Test::Term::Screen->new(rows => 24, cols => 80);
    my $buffer = Clay::Buffer->new(screen => $screen);
    
    # Enable debug mode
    $buffer->set_debug_mode(1);
    
    # Test with negative length - should not reach the fill method
    my $fill_called = 0;
    {
        # Override the fill method temporarily to check if it gets called
        no warnings 'redefine';
        my $original_fill = \&Clay::Buffer::fill;
        local *Clay::Buffer::fill = sub { $fill_called = 1; };
        
        $buffer->draw_hline(5, 5, -10, 'X');
        is($fill_called, 0, 'fill not called with negative length');
    }
    
    # Test with valid length - should call fill
    $fill_called = 0;
    {
        # Override the fill method temporarily to check if it gets called
        no warnings 'redefine';
        my $original_fill = \&Clay::Buffer::fill;
        local *Clay::Buffer::fill = sub { $fill_called = 1; };
        
        $buffer->draw_hline(5, 5, 10, 'X');
        is($fill_called, 1, 'fill called with valid length');
    }
};

# Test the validation in draw_vline method
subtest 'draw_vline method validation' => sub {
    plan tests => 3;
    
    # Create a test screen and buffer
    my $screen = Test::Term::Screen->new(rows => 24, cols => 80);
    my $buffer = Clay::Buffer->new(screen => $screen);
    
    # Enable debug mode
    $buffer->set_debug_mode(1);
    
    # Test with negative length
    my $put_char_called = 0;
    {
        # Override the put_char method temporarily to check if it gets called
        no warnings 'redefine';
        my $original_put_char = \&Clay::Buffer::put_char;
        local *Clay::Buffer::put_char = sub { $put_char_called = 1; };
        
        $buffer->draw_vline(5, 5, -10, 'X');
        is($put_char_called, 0, 'put_char not called with negative length');
    }
    
    # Test with zero length
    $put_char_called = 0;
    {
        # Override the put_char method temporarily to check if it gets called
        no warnings 'redefine';
        my $original_put_char = \&Clay::Buffer::put_char;
        local *Clay::Buffer::put_char = sub { $put_char_called = 1; };
        
        $buffer->draw_vline(5, 5, 0, 'X');
        is($put_char_called, 0, 'put_char not called with zero length');
    }
    
    # Test with valid length
    $put_char_called = 0;
    {
        # Override the put_char method temporarily to check if it gets called
        no warnings 'redefine';
        my $original_put_char = \&Clay::Buffer::put_char;
        local *Clay::Buffer::put_char = sub { $put_char_called = 1; };
        
        $buffer->draw_vline(5, 5, 3, 'X');
        is($put_char_called, 1, 'put_char called with valid length');
    }
};

# Test the validation in draw_box method
subtest 'draw_box method validation' => sub {
    plan tests => 3;
    
    # Create a test screen and buffer
    my $screen = Test::Term::Screen->new(rows => 24, cols => 80);
    my $buffer = Clay::Buffer->new(screen => $screen);
    
    # Enable debug mode
    $buffer->set_debug_mode(1);
    
    # Test with small width
    {
        local $SIG{__WARN__} = sub { like $_[0], qr/Box dimensions too small/, 'Warning about small width'; };
        $buffer->draw_box(5, 5, 2, 5, 'single');
    }
    
    # Test with small height
    {
        local $SIG{__WARN__} = sub { like $_[0], qr/Box dimensions too small/, 'Warning about small height'; };
        $buffer->draw_box(5, 5, 5, 2, 'single');
    }
    
    # Test with valid dimensions - should not warn
    {
        my $warned = 0;
        local $SIG{__WARN__} = sub { $warned = 1; };
        $buffer->draw_box(5, 5, 5, 5, 'single');
        is($warned, 0, 'No warnings with valid dimensions');
    }
};

# Test cursor position validation
subtest 'at method validation' => sub {
    plan tests => 2;
    
    # Create a test screen and buffer
    my $screen = Test::Term::Screen->new(rows => 24, cols => 80);
    my $buffer = Clay::Buffer->new(screen => $screen);
    
    # Enable debug mode
    $buffer->set_debug_mode(1);
    
    # Test with out of bounds position
    {
        local $SIG{__WARN__} = sub { like $_[0], qr/Cursor position out of bounds/, 'Warning about out of bounds position'; };
        $buffer->at(100, 5);
    }
    
    # Test with valid position - should not warn
    {
        my $warned = 0;
        local $SIG{__WARN__} = sub { $warned = 1; };
        $buffer->at(5, 5);
        is($warned, 0, 'No warnings with valid position');
    }
};

# Test internal cursor tracking
subtest 'cursor tracking' => sub {
    plan tests => 4;
    
    # Create a test screen and buffer
    my $screen = Test::Term::Screen->new(rows => 24, cols => 80);
    my $buffer = Clay::Buffer->new(screen => $screen);
    
    # Test cursor position after at
    $buffer->at(5, 10);
    is($buffer->cx, 10, 'Cursor x position correctly updated');
    is($buffer->cy, 5, 'Cursor y position correctly updated');
    
    # Test cursor position after put_string
    $buffer->put_string(10, 15, "Test");
    is($buffer->cx, 19, 'Cursor x position correctly updated after put_string');
    is($buffer->cy, 10, 'Cursor y position correctly updated after put_string');
};

# Test put_string validation
subtest 'put_string method validation' => sub {
    plan tests => 2;
    
    # Create a test screen and buffer
    my $screen = Test::Term::Screen->new(rows => 24, cols => 80);
    my $buffer = Clay::Buffer->new(screen => $screen);
    
    # Test that long strings are truncated at screen edge
    my $long_string = "X" x 100;  # Way longer than screen width
    $buffer->put_string(5, 5, $long_string);
    
    # String should be truncated to fit screen width from column 5
    my $expected_length = 80 - 5;  # Screen width minus starting column
    is($buffer->cx, 5 + $expected_length - 1, 'Cursor x position indicates string was truncated');
    
    # Test out of bounds position
    my $original_cx = $buffer->cx;
    my $original_cy = $buffer->cy;
    $buffer->put_string(100, 5, "Test");
    
    # Cursor position should not change if operation is skipped
    is($buffer->cx, $original_cx, 'Cursor position unchanged after invalid operation');
};

# Test put_char validation
subtest 'put_char method validation' => sub {
    plan tests => 1;
    
    # Create a test screen and buffer
    my $screen = Test::Term::Screen->new(rows => 24, cols => 80);
    my $buffer = Clay::Buffer->new(screen => $screen);
    
    # Test that multi-character strings are truncated to single character
    $buffer->at(5, 5);
    $buffer->put_char(5, 5, "ABC");
    
    # Cursor should only move one position since only one character should be output
    is($buffer->cx, 6, 'Cursor moved by one position after put_char');
};

# Add tests for Context border rendering
subtest 'Context border rendering' => sub {
    plan tests => 3;
    
    use Clay::Context;
    use Clay::Types::Rect;
    use Clay::Types::BorderConfig;
    
    # Create a test buffer and context
    my $screen = Test::Term::Screen->new(rows => 24, cols => 80);
    my $buffer = Clay::Buffer->new(screen => $screen);
    # No need to pass layout_dimensions as it's now derived from buffer automatically
    my $context = Clay::Context->new(buffer => $buffer);
    
    # Override the buffer's draw_hline method to check if it gets called with correct params
    my ($hline_row, $hline_col, $hline_width);
    {
        no warnings 'redefine';
        my $original_draw_hline = \&Clay::Buffer::draw_hline;
        local *Clay::Buffer::draw_hline = sub {
            my ($self, $row, $col, $width) = @_;
            $hline_row = $row;
            $hline_col = $col;
            $hline_width = $width;
            $original_draw_hline->(@_);
        };
        
        # Test with negative dimensions - should not call draw_hline
        $hline_width = undef;
        $context->_render_border({
            rect => Clay::Types::Rect->new(x => 5, y => 5, width => -5, height => 10),
            config => Clay::Types::BorderConfig->new(
                width_top => 1, width_bottom => 1, width_left => 1, width_right => 1,
                color => Clay::Types::Color->new(r => 255, g => 255, b => 255)
            ),
        });
        is($hline_width, undef, 'draw_hline not called with negative width');
        
        # Test with width = 2 (too small) - should not draw horizontal lines
        $hline_width = undef;
        $context->_render_border({
            rect => Clay::Types::Rect->new(x => 5, y => 5, width => 2, height => 10),
            config => Clay::Types::BorderConfig->new(
                width_top => 1, width_bottom => 1, width_left => 1, width_right => 1,
                color => Clay::Types::Color->new(r => 255, g => 255, b => 255)
            ),
        });
        is($hline_width, undef, 'draw_hline not called with width=2');
        
        # Test with valid dimensions - should call draw_hline with width-2
        $context->_render_border({
            rect => Clay::Types::Rect->new(x => 5, y => 5, width => 10, height => 10),
            config => Clay::Types::BorderConfig->new(
                width_top => 1, width_bottom => 1, width_left => 1, width_right => 1,
                color => Clay::Types::Color->new(r => 255, g => 255, b => 255)
            ),
        });
        is($hline_width, 8, 'draw_hline called with width-2 for horizontal lines');
    }
};

done_testing();