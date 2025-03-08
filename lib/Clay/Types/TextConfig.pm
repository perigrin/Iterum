package Clay::Types::TextConfig;

use 5.40.0;
use strict;
use warnings;
use experimental qw(class);
use Exporter;

our @ISA = qw(Exporter);

# Constants defined as package variables for export
our $WRAP_WORDS    = 'words';
our $WRAP_NEWLINES = 'newlines';
our $WRAP_NONE     = 'none';

our $ALIGN_LEFT   = 'left';
our $ALIGN_RIGHT  = 'right';
our $ALIGN_CENTER = 'center';

our $LEFT_TO_RIGHT = 'ltr';
our $RIGHT_TO_LEFT = 'rtl';
our $TOP_TO_BOTTOM = 'ttb';
our $BOTTOM_TO_TOP = 'btt';

# Export the constants
our @EXPORT_OK = qw(
  $WRAP_WORDS $WRAP_NEWLINES $WRAP_NONE
  $ALIGN_LEFT $ALIGN_RIGHT $ALIGN_CENTER
);

# TextConfig class - simplified namespace
class Clay::Types::TextConfig {
    use Text::Wrap qw(wrap);

    field $color :param :reader          = Clay::Types::Color::color_black();
    field $font_id :param :reader        = 0;
    field $font_size :param :reader      = 12;
    field $letter_spacing :param :reader = 0;
    field $line_height :param :reader    = undef;
    field $wrap_mode :param :reader      = $WRAP_WORDS;
    field $text_alignment :param :reader = $ALIGN_LEFT;
    field $orientation :param :reader    = $LEFT_TO_RIGHT;

    method wrap_text( $text //= '', $max_line_width = 1 ) {

        # if text is too short, don't wrap
        if ( length($text) <= $max_line_width ) {
            return $text;
        }

        # if wrap mode is none, don't wrap
        if ( $self->wrap_mode eq $WRAP_NONE ) {
            return $text;
        }

        # if wrap mode is newlines, split
        if ( $self->wrap_mode eq $WRAP_NEWLINES ) {
            return split /\n/, $text;
        }

        if ( $self->wrap_mode eq $WRAP_WORDS ) {
            local $Text::Wrap::columns = $max_line_width;
            local $Text::Wrap::huge    = 'overflow';
            return split /\n/, wrap( '', '', $text );
        }
    }
}

1;
