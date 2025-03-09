use 5.40.0;
use warnings;
use experimental qw(class);

use Clay::Types::Color;
use Clay::Types::BorderConfig;
use Clay::Types::BorderRadius;
use Clay::Types::Size;
use Clay::Logger;

class Clay::Element {
    use Carp       qw(croak);
    use List::Util qw(maxstr);

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

    # Define the element class
    state $i = 0;
    field $id :param :reader            = 'element-' . $i++;    # Element ID
    field $layout_config :param :reader = Clay::Types::LayoutConfig->new();
    field $children :param :reader      = [];     # Child elements
    field $text :param :reader          = undef;  # Text content if text element
    field $text_config :param :reader      = Clay::Types::TextConfig->new();
    field $background_color :param :reader = Clay::Types::Color->new();
    field $border_config :param :reader    = Clay::Types::BorderConfig->new();
    field $border_radius :param :reader    = Clay::Types::BorderRadius->new();
    field $image_data :param :reader       = undef;
    field $custom_data :param :reader      = undef;
    field $user_data :param :reader        = undef;

    field $parent :reader;                        # Parent element reference
    field $bounding_box = Clay::Types::Rect->new();    # Calculated bounding box
    field $content_size = Clay::Types::Size->new();
    field $is_text_element :reader = defined $text;

    field $logger = Clay::Logger->instance();

    ADJUST {
        # Set parent references for all children
        foreach my $child (@$children) {
            unless ( $child isa __PACKAGE__ ) {
                $child = Clay::Element->new(%$child);
            }
            $child->set_parent($self);
        }

        # Mark as text element if text is provided
        if ( !blessed($text_config) && ref($text_config) eq 'HASH' ) {
            $text_config = Clay::Types::TextConfig->new(%$text_config);
        }
    }

    method add_child($child) {
        unless ( $child isa __PACKAGE__ ) {
            $child = Clay::Element->new(%$child);
        }
        push @$children, $child;
        $child->set_parent($self);
        return $self;
    }

    method set_parent($new_parent) {
        $parent = $new_parent;
    }

    # DEPRECATED use $element->size instead
    method get_content_size() {
        return $content_size;
    }

    method size( $new_size = undef ) {

        # If a new size is provided, set it
        if ($new_size) {

           # Ensure proper handling if passed a hashref instead of a Size object
            if ( ref($new_size) eq 'HASH' ) {
                $content_size = Clay::Types::Size->new(%$new_size);
            }
            else {
                $content_size = $new_size;
            }
        }

        # Return the current size, or a new empty size if not set
        return $content_size;
    }

    method set_bounding_box($box) {
        $bounding_box = $box;
    }

    method get_bounding_box( $box = undef ) {
        if ( ref($box) eq 'HASH' ) {
            $box = Clay::Types::Rect->new(%$box);
        }
        if ($box) {
            $bounding_box = $box;
        }
        return $bounding_box;
    }

    # Measure with buffer - used by the 7-phase layout algorithm
    method measure( $available_width, $available_height ) {
        my $content_width  = 0;
        my $content_height = 0;

        # Layout children based on direction
        if ( $layout_config->is_horizontal ) {    # Horizontal layout
            foreach my $child (@$children) {
                my $child_size = $child->measure(
                    $available_width - $layout_config->padding->horizontal(),
                    $available_height - $layout_config->padding->vertical(),
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
        else {    # Vertical layout
            foreach my $child (@$children) {
                my $child_size =
                  $child->is_text_element
                  ? $child->measure_text(
                    $available_width - $layout_config->padding->horizontal(), )
                  : $child->measure(
                    $available_width - $layout_config->padding->horizontal(),
                    $available_height - $layout_config->padding->vertical(),
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

        # Store the content size for later use by the layout phases
        $content_size = Clay::Types::Size->new(
            width  => $content_width,
            height => $content_height
        );

        return Clay::Types::Size->new( width => $width, height => $height );
    }

    # Fixed measure_text method with improved text width handling
    method measure_text($available_width) {

        # Calculate padding-adjusted width
        my $max_line_width =
          $available_width - $layout_config->padding->horizontal();
        $max_line_width = $layout_config->sizing_width_min
          if $max_line_width < $layout_config->sizing_width_min;

        my @wrapped_lines = $text_config->wrap_text( $text, $max_line_width );

        # Apply line_height if specified
        my $height = scalar(@wrapped_lines);
        if ( $text_config->line_height ) {
            $height *= $text_config->line_height;
        }

        # CRITICAL FIX: Ensure we have a reasonable text width based on content
        my $padding        = $layout_config->padding;
        my $min_line_width = $layout_config->sizing_width_min;
        my $width          = length maxstr @wrapped_lines;
        if ( $width < $min_line_width ) {
            $width = $min_line_width - $padding->horizontal();
        }

        my $min_height = $layout_config->sizing_height_min;
        if ( $height < $min_height ) {
            $height = $min_height - $padding->vertical();
        }

        return Clay::Types::Size->new(
            width  => $width,
            height => $height
        );
    }

    method generate_render_commands( $parent_z_index = 0 ) {
        my @commands;

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

            # CRITICAL FIX: Skip borders that are too small
            if ( $bounding_box->width > 1 && $bounding_box->height > 1 ) {
                push @commands,
                  {
                    type    => 'border',
                    rect    => $bounding_box,
                    config  => $border_config,
                    radius  => $border_radius,
                    z_index => $parent_z_index + 1
                  };
            }
        }

        # Add text command if text element
        if ($is_text_element) {

            my @wrapped_lines = $text_config->wrap_text( $text,
                $bounding_box->width - $layout_config->padding->horizontal() );

            # Calculate the total height of text content
            my $text_height = scalar(@wrapped_lines);

            # Apply line_height if specified
            if ( $text_config->line_height ) {
                $text_height *= $text_config->line_height;
            }

            # Calculate the starting y position based on vertical alignment
            my $start_y = $bounding_box->y - $layout_config->padding->top;

            # Apply vertical alignment
            my $available_height =
              $bounding_box->height - $layout_config->padding->vertical();

            if ( $layout_config->alignment_y eq $ALIGN_CENTER ) {
                $start_y += int( ( $available_height - $text_height ) / 2 );
            }
            elsif ( $layout_config->alignment_y eq $ALIGN_BOTTOM ) {
                $start_y += $available_height - $text_height;
            }

            my $i = 0;

            # Generate commands for each line of text
            for my $line (@wrapped_lines) {
                my $line_y = $start_y + $text_height * $i++;
                my $line_x = $bounding_box->x + $layout_config->padding->left;

                # Available width for text needs to account for padding
                my $available_width =
                  $bounding_box->width - $layout_config->padding->horizontal();

                # Apply horizontal text alignment
                if ( $text_config->text_alignment eq $ALIGN_CENTER ) {
                    $line_x += int( ( $available_width - length($line) ) / 2 );
                }
                elsif ( $text_config->text_alignment eq $ALIGN_RIGHT ) {
                    $line_x += $available_width - length($line);
                }

                # CRITICAL FIX: Ensure z-index is high enough to be on top
                push @commands, {
                    type     => 'text',
                    position => Clay::Types::Point->new(
                        x => $line_x,
                        y => $line_y
                    ),
                    text    => $line,
                    config  => $text_config,
                    z_index => $parent_z_index + 1    # Higher z-index for text
                };
            }
        }

        # Generate commands for children with incremented z-index
        push @commands,
          map { $_->generate_render_commands( $parent_z_index + 2 ) }
          @$children;

        return @commands;
    }
}

1;
