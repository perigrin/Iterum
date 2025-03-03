package Clay::Util;
use 5.40.0;
use warnings;

# Helper functions for the Clay-like system

sub array_range_check($index, $length) {
    return $index >= 0 && $index < $length;
}

# Simplifies creating hashes with default fields
sub with_defaults($hash, $defaults) {
    return { %$defaults, %$hash };
}

1;