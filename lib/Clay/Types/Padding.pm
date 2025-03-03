package Clay::Types::Padding;
use 5.40.0;
use warnings;
use experimental qw(class);

class Clay::Types::Padding {
    field $left :param :reader = 0;
    field $right :param :reader = 0;
    field $top :param :reader = 0;
    field $bottom :param :reader = 0;
    
    method horizontal() {
        return $left + $right;
    }
    
    method vertical() {
        return $top + $bottom;
    }
}

1;