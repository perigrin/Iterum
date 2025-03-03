
use 5.40.0;
use warnings;
use experimental qw(class);
use Term::ANSIColor;
use Clay::Types::Color;
use Clay::Types::BorderConfig;
use Clay::Types::BorderRadius;
use Clay::Types::Size;
use Clay::Builder;

class Clay::Element {

    # Import the necessary constants
    use Clay::Types::LayoutConfig qw(
      $SIZING_FIXED $SIZING_GROW $SIZING_PERCENT $SIZING_FIT
      $LEFT_TO_RIGHT $RIGHT_TO_LEFT $TOP_TO_BOTTOM $BOTTOM_TO_TOP
      $ALIGN_LEFT $ALIGN_RIGHT $ALIGN_CENTER $ALIGN_TOP $ALIGN_BOTTOM
    );
    use Clay::Types::TextConfig qw(
      $WRAP_WORDS $WRAP_NEWLINES $WRAP_NONE
      $ALIGN_LEFT $ALIGN_RIGHT $ALIGN_CENTER
    );

    # Make these variables available to the class
    my $__LEFT_TO_RIGHT = $LEFT_TO_RIGHT;
    my $__TOP_TO_BOTTOM = $TOP_TO_BOTTOM;
    my $__WRAP_NONE     = $WRAP_NONE;
    my $__WRAP_NEWLINES = $WRAP_NEWLINES;
    my $__WRAP_WORDS    = $WRAP_WORDS;
    my $__ALIGN_CENTER  = $ALIGN_CENTER;
    my $__ALIGN_RIGHT   = $ALIGN_RIGHT;
    my $__ALIGN_BOTTOM  = $ALIGN_BOTTOM;

    # Define the element class
    state $i = 0;
    field $id :param :reader            = 'element-' . $i++;    # Element ID
    field $layout_config :param :reader = Clay::Types::LayoutConfig->new();
    field $children :param :reader      = [];    # Child elements
    field $text :param :reader          = '';    # Text content if text element
    field $text_config :param :reader =
      undef;    # Text configuration - optional with default
    field $background_color :param :reader = Clay::Types::Color->new();
    field $border_config :param :reader    = Clay::Types::BorderConfig->new();
    field $border_radius :param :reader    = Clay::Types::BorderRadius->new();
    field $image_data :param :reader =
      undef;    # Image data (not fully supported) - optional with default
    field $custom_data :param :reader =
      undef;    # Custom user data - optional with default
    field $user_data :param :reader =
      undef;    # User data passed to renderer - optional with default

    field $parent :reader;          # Parent element reference
    field $bounding_box;            # Calculated bounding box
    field $content_size;            # Calculated content size
    field $is_text_element = 0;     # Flag for text elements
    field $wrapped_lines   = [];    # For text wrapping
    method wrapped_lines( $lines = $wrapped_lines ) { $wrapped_lines = $lines; }

    ADJUST {
        # Set parent references for all children
        foreach my $child (@$children) {
            $child->set_parent($self);
        }

        # Mark as text element if text is provided
        $is_text_element = length($text) > 0;
        if ($is_text_element) {

            if ( !$text_config ) {
                $text_config = Clay::Types::TextConfig->new(
                    color => Clay::Types::Color->new(
                        r          => 255,
                        g          => 255,
                        b          => 255,
                        foreground => 1
                    )
                );
            }
            elsif ( !blessed($text_config) ) {
                $text_config = Clay::Types::TextConfig->new(%$text_config);
            }
        }
    }

    method add_child($child) {
        push @$children, $child;
        $child->set_parent($self);
        return $self;
    }

    method set_parent($new_parent) {
        $parent = $new_parent;
    }

    method get_content_size() {
        return $content_size || Clay::Types::Size->new();
    }

    method size($new_size = undef) {
        # If a new size is provided, set it
        if ($new_size) {
            # Ensure proper handling if passed a hashref instead of a Size object
            if (ref($new_size) eq 'HASH') {
                $content_size = Clay::Types::Size->new(%$new_size);
            } else {
                $content_size = $new_size;
            }
            return $self;
        }

        # Return the current size, or a new empty size if not set
        return $content_size || Clay::Types::Size->new();
    }

    method set_bounding_box($box) {
        $bounding_box = $box;
    }

    method get_bounding_box() {
        return $bounding_box || Clay::Types::Rect->new();
    }

    method measure( $available_width, $available_height ) {
        if ($is_text_element) {
            return $self->measure_text($available_width);
        }

        my $content_width  = 0;
        my $content_height = 0;

        # Layout children based on direction
        if ( $layout_config->layout_direction eq $__LEFT_TO_RIGHT ) {

            # Horizontal layout
            foreach my $child (@$children) {
                my $child_size = $child->measure(
                    $available_width - $layout_config->padding->horizontal(),
                    $available_height - $layout_config->padding->vertical()
                );
                $content_width += $child_size->width;
                $content_height = $child_size->height
                  if $child_size->height > $content_height;
            }

            # Add gaps between children
            $content_width +=
              $layout_config->child_gap * ( scalar(@$children) - 1 )
              if @$children > 1;
        }
        else {    # $TOP_TO_BOTTOM
                  # Vertical layout
            foreach my $child (@$children) {
                my $child_size = $child->measure(
                    $available_width - $layout_config->padding->horizontal(),
                    $available_height - $layout_config->padding->vertical()
                );
                $content_height += $child_size->height;
                $content_width = $child_size->width
                  if $child_size->width > $content_width;
            }

            # Add gaps between children
            $content_height +=
              $layout_config->child_gap * ( scalar(@$children) - 1 )
              if @$children > 1;
        }

        # Calculate final dimensions
        my $width =
          $layout_config->effective_width( $available_width, $content_width );
        my $height = $layout_config->effective_height( $available_height,
            $content_height );

        $content_size = Clay::Types::Size->new(
            width  => $content_width,
            height => $content_height
        );

        return Clay::Types::Size->new( width => $width, height => $height );
    }

    method measure_text($available_width) {
        $wrapped_lines = [];

        # Simple text wrapping
        Carp::confess "not a text element" . Data::Dumper::Dumper($text_config)
          unless blessed($text_config);
        if ( $text_config->wrap_mode eq $__WRAP_NONE ) {
            push @$wrapped_lines, $text;
            return Clay::Types::Size->new(
                width  => length($text),
                height => 1
            );
        }

        my $max_line_width =
          $available_width - $layout_config->padding->horizontal();
        my $height = 0;
        my $width  = 0;

        if ( $text_config->wrap_mode eq $__WRAP_NEWLINES ) {

            # Split only on newlines
            my @lines = split /\n/, $text;
            foreach my $line (@lines) {
                push @$wrapped_lines, $line;
                $width = length($line) if length($line) > $width;
            }
            $height = scalar(@lines);
        }
        else {    # $WRAP_WORDS
                  # Split on words and wrap
            my @words        = split /\s+/, $text;
            my $current_line = '';

            foreach my $word (@words) {

                # If adding this word would exceed width, start a new line
                if (
                    length($current_line) + length($word) + 1 > $max_line_width
                    && length($current_line) > 0 )
                {
                    push @$wrapped_lines, $current_line;
                    $width = length($current_line)
                      if length($current_line) > $width;
                    $current_line = $word;
                }
                else {
                    $current_line .=
                      ( length($current_line) > 0 ? ' ' : '' ) . $word;
                }
            }

            # Add the last line
            if ( length($current_line) > 0 ) {
                push @$wrapped_lines, $current_line;
                $width = length($current_line)
                  if length($current_line) > $width;
            }

            $height = scalar(@$wrapped_lines);
        }

        # Use line_height if specified
        $height =
          $text_config->line_height > 0 ? $text_config->line_height : $height;

        return Clay::Types::Size->new( width => $width, height => $height );
    }

    method layout( $x, $y, $width, $height ) {

        # Set this element's bounding box
        $self->set_bounding_box(
            Clay::Types::Rect->new(
                x      => $x,
                y      => $y,
                width  => $width,
                height => $height
            )
        );

        if ( $is_text_element || scalar(@$children) == 0 ) {
            return;
        }

        # Layout children based on direction
        my $child_x = $x + $layout_config->padding->left;
        my $child_y = $y + $layout_config->padding->top;

        my $inner_width  = $width - $layout_config->padding->horizontal();
        my $inner_height = $height - $layout_config->padding->vertical();

        my $content_width  = $content_size->width;
        my $content_height = $content_size->height;

        # Apply alignment for extra space
        my $extra_x = 0;
        my $extra_y = 0;

        if ( $inner_width > $content_width ) {
            if ( $layout_config->alignment_x eq $__ALIGN_CENTER ) {
                $extra_x = ( $inner_width - $content_width ) / 2;
            }
            elsif ( $layout_config->alignment_x eq $__ALIGN_RIGHT ) {
                $extra_x = $inner_width - $content_width;
            }
        }

        if ( $inner_height > $content_height ) {
            if ( $layout_config->alignment_y eq $__ALIGN_CENTER ) {
                $extra_y = ( $inner_height - $content_height ) / 2;
            }
            elsif ( $layout_config->alignment_y eq $__ALIGN_BOTTOM ) {
                $extra_y = $inner_height - $content_height;
            }
        }

        $child_x += $extra_x;
        $child_y += $extra_y;

        if ( $layout_config->layout_direction eq $__LEFT_TO_RIGHT ) {

            # Horizontal layout
            foreach my $child (@$children) {
                my $child_size   = $child->get_content_size();
                my $child_width  = $child->get_bounding_box()->width;
                my $child_height = $child->get_bounding_box()->height;

                # Align vertically
                my $y_pos = $child_y;
                if ( $layout_config->alignment_y eq $__ALIGN_CENTER ) {
                    $y_pos = $child_y + ( $inner_height - $child_height ) / 2;
                }
                elsif ( $layout_config->alignment_y eq $__ALIGN_BOTTOM ) {
                    $y_pos = $child_y + $inner_height - $child_height;
                }

                $child->layout( $child_x, $y_pos, $child_width, $child_height );
                $child_x += $child_width + $layout_config->child_gap;
            }
        }
        else {    # $TOP_TO_BOTTOM
                  # Vertical layout
            foreach my $child (@$children) {
                my $child_size   = $child->get_content_size();
                my $child_width  = $child->get_bounding_box()->width;
                my $child_height = $child->get_bounding_box()->height;

                # Align horizontally
                my $x_pos = $child_x;
                if ( $layout_config->alignment_x eq $__ALIGN_CENTER ) {
                    $x_pos = $child_x + ( $inner_width - $child_width ) / 2;
                }
                elsif ( $layout_config->alignment_x eq $__ALIGN_RIGHT ) {
                    $x_pos = $child_x + $inner_width - $child_width;
                }

                $child->layout( $x_pos, $child_y, $child_width, $child_height );
                $child_y += $child_height + $layout_config->child_gap;
            }
        }
    }

    method generate_render_commands( $parent_z_index = 0 ) {
        my @commands;

        # Skip if element is off-screen
        # We'd add culling here for performance

        # Add rectangle command if has background color
        if ( $background_color && $background_color->a > 0 ) {
            push @commands,
              {
                type    => 'rectangle',
                rect    => $bounding_box,
                color   => $background_color,
                radius  => $border_radius,
                z_index => $parent_z_index
              };
        }

        # Add border command if has border
        if ( $border_config && $border_config->has_border() ) {
            push @commands,
              {
                type    => 'border',
                rect    => $bounding_box,
                config  => $border_config,
                radius  => $border_radius,
                z_index => $parent_z_index
              };
        }

        # Add text command if text element
        if ($is_text_element) {
            for ( my $i = 0 ; $i < scalar(@$wrapped_lines) ; $i++ ) {
                my $line_y = $bounding_box->y + $i;
                my $line   = $wrapped_lines->[$i];
                my $line_x = $bounding_box->x;

                # Apply text alignment
                if ( $text_config->text_alignment eq $__ALIGN_CENTER ) {
                    $line_x = $bounding_box->x +
                      int( ( $bounding_box->width - length($line) ) / 2 );
                }
                elsif ( $text_config->text_alignment eq $__ALIGN_RIGHT ) {
                    $line_x =
                      $bounding_box->x + $bounding_box->width - length($line);
                }

                push @commands,
                  {
                    type     => 'text',
                    position =>
                      Clay::Types::Point->new( x => $line_x, y => $line_y ),
                    text    => $line,
                    config  => $text_config,
                    z_index => $parent_z_index + 1
                  };
            }
        }

        # Generate commands for children
        foreach my $child (@$children) {
            push @commands,
              @{ $child->generate_render_commands($parent_z_index) };
        }

        return \@commands;
    }
}

1;
