use 5.40.0;
use warnings;
use experimental qw(class);

class Clay::Types::Point {
    field $x :param :reader = 0;
    field $y :param :reader = 0;

    method as_array() { return [$x, $y]; }
    method add($other) {
        return Clay::Types::Point->new(
            x => $x + $other->x,
            y => $y + $other->y
        );
    }
}

1;
