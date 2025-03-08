use 5.40.0;
use warnings;
use utf8;
use experimental qw(class);

class Clay::Logger {

    sub instance($) {
        state $instance = __PACKAGE__->new();
        return $instance;
    }

    field $filename :param = 'err.log';
    ADJUST {
        close STDERR;
        open STDERR, '>', $filename or die $!;
    }

    method log($message) {
        say STDERR $message;
    }
}
