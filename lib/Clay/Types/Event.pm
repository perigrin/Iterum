use 5.40.0;
use warnings;
use experimental qw(class);

# Define the class directly in the target namespace
class Clay::Types::Event {
    field $type :param :reader;
    field $key :param     = '';
    field $mouse_x :param = 0;
    field $mouse_y :param = 0;
}

1;
