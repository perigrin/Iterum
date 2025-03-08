use 5.40.0;
use warnings;
use utf8;
use experimental qw(class);
use Term::Screen;

# Ensure UTF-8 output
binmode( STDOUT, ":utf8" );

class Clay::Buffer {
    use Text::Wrap qw(wrap);
    use List::Util qw(maxstr);

    field $screen :reader :param = Term::Screen->new();    # Term::Screen object
    field $x :reader             = 0;                      # Cursor X position
    field $y :reader             = 0;                      # Cursor Y position

    field $logger = Clay::Logger->instance();

    method resize() {
        my $rows = $screen->rows;
        my $cols = $screen->cols;
        $screen->resize();
        return $screen->rows != $rows || $screen->cols != $cols;
    }
    method width()  { return $screen->cols; }
    method height() { return $screen->rows; }

    # Strip ANSI escape sequences from a string
    method _strip_ansi_escapes($str) {
        return '' unless defined $str;

        # Remove ANSI escape sequences
        $str =~ s/\e\[[\d;]*[a-zA-Z]//g;    # CSI sequences
        $str =~ s/\e[^[]//g;                # Other escape sequences

        # Replace control chars with spaces, but keep newlines
        $str =~ s/[\x00-\x08\x0B-\x1F\x7F-\x9F]/ /g;

        return $str;
    }

    # Sanitize input method
    method _sanitize_input($str) {
        return '' unless defined $str;
        return $self->_strip_ansi_escapes($str);
    }

    # Current cursor position accessors
    method cx() { return $x; }
    method cy() { return $y; }

    method inside_bounds( $row, $col ) {
        0 <= $row < $self->height && 0 <= $col < $self->width;
    }

    # Set cursor position with proper boundary checking
    method at( $row, $col ) {
        if ( $self->inside_bounds( $row, $col ) ) {

            # Update our internal tracking
            $x = $col;
            $y = $row;

            # Position the cursor using Term::Screen's at() method
            $screen->at( $row, $col );
        }

        return $self;
    }

    # Put a single character at a specific position
    method put_char( $row, $col, $char ) {
        if ( $self->inside_bounds( $row, $col ) ) {

            # Sanitize input
            my $sanitized_char = $self->_sanitize_input($char);

         # Get the first character only - if empty after sanitization, use space
            my $single_char = '';
            $single_char = substr( $sanitized_char, 0, 1 )
              if length($sanitized_char);
            $single_char = ' ' if $single_char eq '';

            # Explicitly position the cursor first
            $self->at( $row, $col );

            # Output the character
            $screen->puts($single_char);

            # Update internal cursor position
            $x = $col + 1;
            $y = $row;
        }

        return $self;
    }

    # Put a string at a specific position with proper boundary checking
    method put_string( $row, $col, $string ) {

        $logger->log("put_string($row, $col, $string)");

        # Ensure we're within bounds
        return unless $self->inside_bounds( $row, $col );

        # Sanitize input
        my $sanitized_string = $self->_sanitize_input($string);

        # If string is empty after sanitization, use a space
        $sanitized_string = ' ' if $sanitized_string eq '';

        # Position cursor first with our method
        $self->at( $row, $col );

        # Output the string
        $screen->puts($string);

        # Update cursor position
        $x = $col + length($string);
        $x = $self->width - 1 if $x >= $self->width;
        $y = $row;

        return $self;
    }

    # Draw an ASCII border
    method draw_ascii_border( $row, $col, $width, $height ) {

        # Use simple ASCII chars for borders
        $self->put_char( $row, $col, '+' );
        $self->draw_hline( $row, $col + 1, $width - 2, '-' );
        $self->put_char( $row, $col + $width - 1, '+' );

        for ( my $i = 1 ; $i < $height - 1 ; $i++ ) {
            $self->put_char( $row + $i, $col,              '|' );
            $self->put_char( $row + $i, $col + $width - 1, '|' );
        }

        $self->put_char( $row + $height - 1, $col, '+' );
        $self->draw_hline( $row + $height - 1, $col + 1, $width - 2, '-' );
        $self->put_char( $row + $height - 1, $col + $width - 1, '+' );

        return $self;
    }

    # Fill a rectangle with a specific character
    method fill( $row, $col, $fill_width, $fill_height, $char ) {

        # Validate parameters
        return $self if $fill_width <= 0 || $fill_height <= 0;

        # Validate row and column
        return $self unless $self->inside_bounds( $row, $col );

        # Sanitize fill character
        my $sanitized_char = $self->_sanitize_input($char);
        my $char_to_use    = '';
        $char_to_use = substr( $sanitized_char, 0, 1 )
          if length($sanitized_char);
        $char_to_use = ' ' if $char_to_use eq '';

        # Fill the rectangle
        for my $y_offset ( 0 .. $fill_height - 1 ) {
            my $current_row = $row + $y_offset;
            last if $current_row >= $self->height;

            # Ensure we don't go past screen width
            my $actual_width = $fill_width;
            $actual_width = $self->width - $col
              if $col + $fill_width > $self->width;

            # Position cursor at the start of each row
            $self->at( $current_row, $col );

            # Create a fill string and output it directly
            my $fill_string = $char_to_use x $actual_width;
            $screen->puts($fill_string);
        }

        # Update final cursor position
        $x = $col;
        $y = $row + $fill_height - 1;
        $y = $self->height - 1 if $y >= $self->height;

        return $self;
    }

    # Draw a horizontal line
    method draw_hline( $row, $col, $length, $char ) {

        # Validate length
        return $self if $length <= 0;

        # Use the fill method for simplicity and consistency
        $self->fill( $row, $col, $length, 1, $char );

        # Update cursor position
        $x = $col + $length;
        $x = $self->width - 1 if $x >= $self->width;
        $y = $row;

        return $self;
    }

    # Draw a vertical line with proper cursor positioning
    method draw_vline( $row, $col, $length, $char ) {

        # Validate length
        return $self if $length <= 0;

        # Sanitize input
        my $sanitized_char = $self->_sanitize_input($char);

        # Use a pipe as default if char is empty after sanitization
        my $char_to_use = '';
        $char_to_use = substr( $sanitized_char, 0, 1 )
          if length($sanitized_char);
        $char_to_use = '|' if $char_to_use eq '';

        # Draw the line
        for my $y_offset ( 0 .. $length - 1 ) {
            my $current_row = $row + $y_offset;
            last if $current_row >= $self->height;

            # Use put_char to place each character of the line
            $self->put_char( $current_row, $col, $char_to_use );
        }

        return $self;
    }

    # Draw a box with specified style
    method draw_box( $row, $col, $width, $height, $style = 'single' ) {

        # Validate width and height
        return $self if $width <= 2 || $height <= 2;

        # Define box drawing characters based on style
        my %styles = (
            'single' => {
                top_left     => '┏',
                top_right    => '┓',
                bottom_left  => '┗',
                bottom_right => '┛',
                horizontal   => '━',
                vertical     => '┃'
            },
            'double' => {
                top_left     => '╔',
                top_right    => '╗',
                bottom_left  => '╚',
                bottom_right => '╝',
                horizontal   => '═',
                vertical     => '║'
            },
            'ascii' => {
                top_left     => '+',
                top_right    => '+',
                bottom_left  => '+',
                bottom_right => '+',
                horizontal   => '-',
                vertical     => '|'
            }
        );

        # Default to ASCII if style not found
        my $box_chars = $styles{$style} // $styles{ascii};

        # Draw top horizontal line
        $self->put_char( $row, $col, $box_chars->{top_left} );
        $self->draw_hline( $row, $col + 1, $width - 2,
            $box_chars->{horizontal} );
        $self->put_char( $row, $col + $width - 1, $box_chars->{top_right} );

        # Draw vertical lines
        for my $y_offset ( 1 .. $height - 2 ) {
            $self->put_char( $row + $y_offset, $col, $box_chars->{vertical} );
            $self->put_char(
                $row + $y_offset,
                $col + $width - 1,
                $box_chars->{vertical}
            );
        }

        # Draw bottom horizontal line
        $self->put_char( $row + $height - 1, $col, $box_chars->{bottom_left} );
        $self->draw_hline( $row + $height - 1,
            $col + 1, $width - 2, $box_chars->{horizontal} );
        $self->put_char(
            $row + $height - 1,
            $col + $width - 1,
            $box_chars->{bottom_right}
        );

        return $self;
    }

    # Clear screen with proper cursor reset
    method clear() {
        $screen->clrscr();

        # Reset cursor position
        $x = 0;
        $y = 0;

        return $self;
    }

    # Add compatibility for clrscr() calls
    method clrscr() {
        return $self->clear();
    }

    # Get character from keyboard
    method getch() {
        return Clay::Types::Event->new(
            type => 'key',
            key  => $screen->getch(),
        );
    }

    # Check if key is pressed
    method key_pressed( $seconds = 0 ) {
        return $screen->key_pressed($seconds);
    }

    method get_key() {
        return $screen->getch();
    }

    # Refresh screen - position cursor correctly
    method refresh() {
        $screen->at( $y, $x );
        return $self;
    }

    # Proper colored_puts implementation using ansi colors
    method colored_puts( $text, $color = undef ) {

        # Sanitize the input text
        my $sanitized_text = $self->_sanitize_input($text);

        # Position cursor
        $screen->at( $y, $x );

        # Apply color if specified and supported
        if ( defined $color && ref $color && $color->can('to_ansi') ) {
            my $ansi_color = $color->to_ansi();
            $screen->puts( $ansi_color . $sanitized_text . "\e[0m" );
        }
        else {
            # Output without color
            $screen->puts($sanitized_text);
        }

        # Update cursor position
        $x += length($sanitized_text);
        $x = $self->width - 1 if $x >= $self->width;

        return 1;
    }

    # Methods for rendering the Clay layout commands

    # Draw a rectangle
    method draw_rect( $x, $y, $width, $height, $color ) {

        # Fill the rectangle with spaces to create the background
        $self->fill( $y, $x, $width, $height, ' ' );

        return $self;
    }

    # Draw a border
    method draw_border( $x, $y, $width, $height, $style ) {
        warn "Drawing border: $x, $y, $width, $height";

        # Use the box drawing method with the appropriate style
        $self->draw_box( $y, $x, $width, $height, $style );

        return $self;
    }

    # Draw text
    method draw_text( $x, $y, $text ) {
        $logger->log("draw_text($x, $y, $text)");

        # Position and output the text
        $self->put_string( $y, $x, $text );

        return $self;
    }

    # Render the screen
    method render() {

        # Just refresh to ensure cursor is positioned correctly
        $self->refresh();

        return $self;
    }

    END {
        # Restore terminal settings
        warn "Restoring terminal settings";
        system( 'tput', 'reset' );
        exec('stty sane');
    }
}

1;
