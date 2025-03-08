package Clay::Types::BorderConfig;
use 5.40.0;
use warnings;
use experimental qw(class);

class Clay::Types::BorderConfig {
    field $color :param :reader                  = Clay::Types::Color->new();
    field $width_left :param :reader             = 0;
    field $width_right :param :reader            = 0;
    field $width_top :param :reader              = 0;
    field $width_bottom :param :reader           = 0;
    field $width_between_children :param :reader = 0;
    field $style :param :reader                  = 'single';

    method has_border() {
        return $width_left || $width_right || $width_top || $width_bottom;
    }
}

1;
