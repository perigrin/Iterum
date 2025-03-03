package Clay::Types::Rect;
use 5.40.0;
use warnings;
use experimental qw(class);

class Clay::Types::Rect {
    field $x :param :reader = 0;
    field $y :param :reader = 0;
    field $width :param :reader = 0;
    field $height :param :reader = 0;

    method contains($point) {
        return $point->x >= $x && 
               $point->x < $x + $width && 
               $point->y >= $y && 
               $point->y < $y + $height;
    }

    method position() {
        return Clay::Types::Point->new(x => $x, y => $y);
    }

    method size() {
        return Clay::Types::Size->new(width => $width, height => $height);
    }
}

1;