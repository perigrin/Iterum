package Clay::Types::Color;
use 5.40.0;
use warnings;
use experimental qw(class);
use Term::ANSIColor;

class Clay::Types::Color {
    field $r :param :reader = 0;
    field $g :param :reader = 0;
    field $b :param :reader = 0;
    field $a :param :reader = 255;  # Alpha not fully supported in terminals
    field $foreground :param :reader = 0; # true if this is a foreground color

    method ansi_code() {
        my $intensity = $a > 128 ? 'bright_' : '';
        # Convert RGB to nearest terminal color
        # This is very simplified; real color handling would need to map to actual terminal colors
        my $color = 'black';
        if ($r > 192 && $g > 192 && $b > 192) {
            $color = 'white';
        } elsif ($r > 192 && $g < 64 && $b < 64) {
            $color = 'red';
        } elsif ($r < 64 && $g > 192 && $b < 64) {
            $color = 'green';
        } elsif ($r < 64 && $g < 64 && $b > 192) {
            $color = 'blue';
        } elsif ($r > 192 && $g > 192 && $b < 64) {
            $color = 'yellow';
        } elsif ($r > 192 && $g < 64 && $b > 192) {
            $color = 'magenta';
        } elsif ($r < 64 && $g > 192 && $b > 192) {
            $color = 'cyan';
        }
        
        return $intensity . ($foreground ? $color : "on_$color");
    }
}

1;