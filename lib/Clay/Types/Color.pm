package Clay::Types::Color;
use 5.40.0;
use warnings;
use experimental qw(class);

# Simplified Color class without complex color handling for now

class Clay::Types::Color {
    field $r :param :reader = 0;    # Red component (0-255)
    field $g :param :reader = 0;    # Green component (0-255)
    field $b :param :reader = 0;    # Blue component (0-255)
    field $a :param :reader = 255;  # Alpha (0-255, 255 is opaque)
    
    # Simple method to determine if this is a "visible" color
    method is_visible() {
        return $a > 0;  # Any non-zero alpha means visible
    }
    
    # Simple string representation for debugging
    method to_string() {
        return sprintf("rgba(%d,%d,%d,%d)", $r, $g, $b, $a);
    }
    
    # Basic color equality test
    method equals($other) {
        return 0 unless defined $other && ref($other) eq ref($self);
        return ($r == $other->r && 
                $g == $other->g && 
                $b == $other->b && 
                $a == $other->a);
    }
}

# Helper function to create a color
sub color($r, $g, $b, $a = 255) {
    return Clay::Types::Color->new(r => $r, g => $g, b => $b, a => $a);
}

# Predefined colors
sub color_black() { color(0, 0, 0) }
sub color_white() { color(255, 255, 255) }
sub color_red() { color(255, 0, 0) }
sub color_green() { color(0, 255, 0) }
sub color_blue() { color(0, 0, 255) }
sub color_yellow() { color(255, 255, 0) }

# Export color creation functions
use Exporter qw(import);
our @EXPORT = qw(
    color
    color_black
    color_white
    color_red
    color_green
    color_blue
    color_yellow
);

1;