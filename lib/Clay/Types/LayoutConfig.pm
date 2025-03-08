package Clay::Types::LayoutConfig;

use 5.40.0;
use strict;
use warnings;
use experimental qw(class);
use Exporter;

our @ISA = qw(Exporter);

# Constants defined as package variables for export
our $SIZING_FIXED   = 'fixed';
our $SIZING_GROW    = 'grow';
our $SIZING_PERCENT = 'percent';
our $SIZING_FIT     = 'fit';

our $LEFT_TO_RIGHT = 'ltr';
our $RIGHT_TO_LEFT = 'rtl';
our $TOP_TO_BOTTOM = 'ttb';
our $BOTTOM_TO_TOP = 'btt';

our $ALIGN_LEFT   = 'left';
our $ALIGN_RIGHT  = 'right';
our $ALIGN_CENTER = 'center';
our $ALIGN_TOP    = 'top';
our $ALIGN_BOTTOM = 'bottom';

# Export the constants
our @EXPORT_OK = qw(
  $SIZING_FIXED $SIZING_GROW $SIZING_PERCENT $SIZING_FIT
  $LEFT_TO_RIGHT $RIGHT_TO_LEFT $TOP_TO_BOTTOM $BOTTOM_TO_TOP
  $ALIGN_LEFT $ALIGN_RIGHT $ALIGN_CENTER $ALIGN_TOP $ALIGN_BOTTOM
);

use Clay::Types::Padding;

# Define the class directly in the target namespace
class Clay::Types::LayoutConfig {
    field $sizing_width_type :param :reader  = $SIZING_FIT;
    field $sizing_width_value :param :reader = 0;
    field $sizing_width_min :param :reader   = 0;
    field $sizing_width_max :param :reader   = 1000;

    field $sizing_height_type :param :reader  = $SIZING_FIT;
    field $sizing_height_value :param :reader = 0;
    field $sizing_height_min :param :reader   = 0;
    field $sizing_height_max :param :reader   = 1000;

    field $padding :param :reader          = Clay::Types::Padding->new();
    field $child_gap :param :reader        = 0;
    field $alignment_x :param :reader      = $ALIGN_LEFT;
    field $alignment_y :param :reader      = $ALIGN_TOP;
    field $layout_direction :param :reader = $LEFT_TO_RIGHT;

    method is_horizontal() {
        return $layout_direction eq $LEFT_TO_RIGHT
          || $layout_direction eq $RIGHT_TO_LEFT;
    }

    method effective_width( $available_width, $content_width ) {
        if ( $sizing_width_type eq $SIZING_FIXED ) {
            return $sizing_width_value;
        }
        elsif ( $sizing_width_type eq $SIZING_PERCENT ) {
            return int( $available_width * $sizing_width_value );
        }
        elsif ( $sizing_width_type eq $SIZING_GROW ) {
            return $available_width;
        }
        else {    # $SIZING_FIT
            my $width = $content_width + $padding->horizontal();
            $width = $sizing_width_min if $width < $sizing_width_min;
            $width = $sizing_width_max if $width > $sizing_width_max;
            return $width;
        }
    }

    method effective_height( $available_height, $content_height ) {
        if ( $sizing_height_type eq $SIZING_FIXED ) {
            return $sizing_height_value;
        }
        elsif ( $sizing_height_type eq $SIZING_PERCENT ) {
            return int( $available_height * $sizing_height_value );
        }
        elsif ( $sizing_height_type eq $SIZING_GROW ) {
            return $available_height;
        }
        else {    # $SIZING_FIT
            my $height = $content_height + $padding->vertical();
            $height = $sizing_height_min if $height < $sizing_height_min;
            $height = $sizing_height_max if $height > $sizing_height_max;
            return $height;
        }
    }
}

1;
