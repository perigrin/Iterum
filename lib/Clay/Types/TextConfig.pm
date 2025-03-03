package Clay::Types::TextConfig;

use 5.40.0;
use strict;
use warnings;
use experimental qw(class);
use Exporter;

our @ISA = qw(Exporter);

# Constants defined as package variables for export
our $WRAP_WORDS = 'words';
our $WRAP_NEWLINES = 'newlines';
our $WRAP_NONE = 'none';

our $ALIGN_LEFT = 'left';
our $ALIGN_RIGHT = 'right';
our $ALIGN_CENTER = 'center';

# Export the constants
our @EXPORT_OK = qw(
    $WRAP_WORDS $WRAP_NEWLINES $WRAP_NONE
    $ALIGN_LEFT $ALIGN_RIGHT $ALIGN_CENTER
);

# TextConfig class - simplified namespace
class Clay::Types::TextConfig {
    field $color :param :reader;
    field $font_id :param :reader = 0;
    field $font_size :param :reader = 12;
    field $letter_spacing :param :reader = 0;
    field $line_height :param :reader = 0;
    field $wrap_mode :param :reader = $WRAP_WORDS;
    field $text_alignment :param :reader = $ALIGN_LEFT;
}

1;