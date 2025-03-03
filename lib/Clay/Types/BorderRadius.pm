package Clay::Types::BorderRadius;
use 5.40.0;
use warnings;
use experimental qw(class);

class Clay::Types::BorderRadius {
    field $top_left :param :reader = 0;
    field $top_right :param :reader = 0;
    field $bottom_left :param :reader = 0;
    field $bottom_right :param :reader = 0;
    
    method has_radius() {
        return $top_left || $top_right || $bottom_left || $bottom_right;
    }
}

1;