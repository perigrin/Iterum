package Clay::Types::ElementId;
use 5.40.0;
use warnings;
use experimental qw(class);

# Define the class directly in the target namespace
class Clay::Types::ElementId::ElementId {
    field $id :param;
    field $offset :param = 0;
    field $base_id :param = 0;
    field $string_id :param = '';
    
    method equals($other) {
        return $id eq $other->id;
    }
}

1;