use 5.40.0;
use warnings;
use experimental qw(class);

class Clay::Types::Size {
    field $width :param :reader = 0;
    field $height :param :reader = 0;

    method as_array() { return [$width, $height]; }
}

1;
