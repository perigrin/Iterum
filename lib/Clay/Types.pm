package Clay::Types;
use 5.40.0;
use warnings;
use experimental qw(class);
use Term::ANSIColor;

# Load all the individual type modules
use Clay::Types::Point;
use Clay::Types::Size;
use Clay::Types::Rect;
use Clay::Types::Color;
use Clay::Types::BorderRadius;
use Clay::Types::Padding;
use Clay::Types::ElementId;
use Clay::Types::LayoutConfig;
use Clay::Types::BorderConfig;
use Clay::Types::TextConfig;
use Clay::Types::Event;

1;