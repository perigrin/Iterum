use 5.40.0;
use warnings;
use experimental qw(class);

# Define the class directly in the target namespace
class Clay::Types::Event {
    field $type :param :reader;
    field $key :param :reader     = '';
    field $mouse_x :param :reader = 0;
    field $mouse_y :param :reader = 0;

    sub key_event($key) {
        return Clay::Types::Event->new( type => 'key', key => $key );
    }
}

1;
