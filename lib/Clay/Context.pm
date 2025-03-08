use 5.40.0;
use warnings;
use utf8;
use experimental qw(class);
use Clay::Types::Size;
use Clay::Types::Rect;
use Clay::Types::Point;
use Clay::Builder;
use Clay::Buffer;
use Clay::Logger;
use Carp;

# Import constants directly from their package
use Clay::Types::LayoutConfig;

# The main rendering and layout context
class Clay::Context {

    # Define the constants we need to avoid ref to the global variables
    use constant {
        SIZING_FIXED   => 'fixed',
        SIZING_GROW    => 'grow',
        SIZING_PERCENT => 'percent',
        SIZING_FIT     => 'fit',
        LEFT_TO_RIGHT  => 'ltr',
        RIGHT_TO_LEFT  => 'rtl',
        TOP_TO_BOTTOM  => 'ttb',
        BOTTOM_TO_TOP  => 'btt',
        ALIGN_LEFT     => 'left',
        ALIGN_RIGHT    => 'right',
        ALIGN_CENTER   => 'center',
        ALIGN_TOP      => 'top',
        ALIGN_BOTTOM   => 'bottom'
    };

    # Default to a new buffer if none provided
    field $buffer :param :reader = Clay::Buffer->new();
    field $element_tree :param = undef;

    # Default layout dimensions to buffer size if not provided
    field $layout_dimensions :param :reader = Clay::Types::Size->new(
        width  => $buffer->width,
        height => $buffer->height
    );

    field $pointer_position :param :reader = Clay::Types::Point->new();
    field $pointer_pressed :param :reader  = 0;     # Mouse button state
    field @commands                        = ();    # Render commands

    field $logger = Clay::Logger->instance();

    ADJUST {
      # Just clear the screen - everything else is handled in field initializers
        $buffer->clear();
    }

    # Layout compatibility method
    method layout() {
        $self->calculate_layout();
    }

    method root() {
        $element_tree //=
          Clay::Builder::ElementBuilder->new( context => $self );
    }

    method element_tree( $tree = $element_tree ) { $element_tree = $tree }

    # Find element at a specific position
    method get_element_at_position($position) {
        return $self->_find_element_at_position( $element_tree, $position );
    }

    # Helper method to find element at a position
    method _find_element_at_position( $element, $position ) {

        # Check if position is within this element
        my $box = $element->get_bounding_box();
        return undef unless $box->contains($position);

        # Check children first (depth-first, back to front)
        foreach my $child ( reverse $element->children->@* ) {
            my $hit = $self->_find_element_at_position( $child, $position );
            return $hit if $hit;
        }

        # Return this element if no children were hit
        return $element;
    }

    # Set pointer position and pressed state
    method set_pointer_position( $x, $y, $pressed = 0 ) {
        $pointer_position = Clay::Types::Point->new( x => $x, y => $y );
        $pointer_pressed  = $pressed;
    }

    method _check_dimensions() {
        return unless $buffer->resize();    # Check if buffer has been resized

        # Initial measurement pass to calculate widths
        if (   $buffer->width != $layout_dimensions->width
            || $buffer->height != $layout_dimensions->height )
        {
            $layout_dimensions = Clay::Types::Size->new(
                width  => $buffer->width,
                height => $buffer->height
            );
            $logger->log( sprintf "Updated layout dimensions: %d x %d",
                $buffer->width, $buffer->height );
            return 1;
        }
        $logger->log( sprintf 'Layout dimensions unchanged: %d x %d',
            $buffer->width, $buffer->height );
        return 0;
    }

    # Implementation of the 7-phase layout algorithm
    # Calculate layout for the element tree
    method calculate_layout() {
        return unless $element_tree;

        if ( !$self->_check_dimensions() && @commands ) {
            $logger->log( 'Layout calculation skipped (no changes): '
                  . scalar @commands );
            return;
        }

        # Phase 1: Fit Sizing Widths
        # Initial measurement pass focusing on widths
        $self->_measure_widths_phase();

        # Phase 2: Grow & Shrink Sizing Widths
        # Adjust elements with grow/shrink sizing
        $self->_grow_shrink_widths_phase();

        # Phase 3: Wrap Text
        # Handle text wrapping based on the widths established
        $self->_wrap_text_phase();

        # Phase 4: Fit Sizing Heights
        # Re-calculate heights after text wrapping
        $self->_measure_heights_phase();

        # Phase 5: Grow & Shrink Sizing Heights
        # Adjust elements with grow/shrink height sizing
        $self->_grow_shrink_heights_phase();

        # Phase 6: Positions
        # Final positioning pass
        $self->_position_phase();

        # Phase 7: Draw Commands
        # Generate render commands for all elements
        # Sort by z-index
        @commands = sort { $a->{z_index} <=> $b->{z_index} }
          $element_tree->generate_render_commands();
    }

    # Phase 1: Fit Sizing Widths
    method _measure_widths_phase() {
        return unless $element_tree;

        return $element_tree->measure( $layout_dimensions->width,
            $layout_dimensions->height );
    }

    # Phase 2: Grow & Shrink Sizing Widths
    method _grow_shrink_widths_phase() {
        return unless $element_tree;
        $self->_adjust_element_widths($element_tree);
    }

    method _adjust_element_widths($element) {

        # Skip leaf nodes and nodes with no children
        return unless $element && $element->children && @{ $element->children };

        my $layout_config = $element->layout_config;
        my $children      = $element->children;

        # Log element we're processing
        $logger->log( "Adjusting widths for element: " . $element->id );

        # First recursively handle children from bottom up
        foreach my $child (@$children) {
            $self->_adjust_element_widths($child);
        }

        # Get layout direction
        my $is_horizontal = $layout_config->layout_direction eq LEFT_TO_RIGHT
          || $layout_config->layout_direction eq RIGHT_TO_LEFT;

        # Skip if this isn't a horizontal layout
        return unless $is_horizontal;

        # Calculate available width
        my $content_size = $element->get_content_size();
        my $available_width =
          $content_size->width - $layout_config->padding->horizontal();

        $logger->log( "Element "
              . $element->id
              . " available width: "
              . $available_width );

        # Calculate total fixed width and count growable children
        my $total_fixed_width = 0;
        my $growable_count    = 0;

        foreach my $child (@$children) {
            my $child_config = $child->layout_config;
            my $child_size   = $child->get_content_size();

            if ( $child_config->sizing_width_type eq SIZING_FIXED ) {

                # For fixed elements, use their fixed width value
                $total_fixed_width += $child_config->sizing_width_value;

                # CRITICAL FIX: Ensure child size reflects the fixed width
                $child->size(
                    Clay::Types::Size->new(
                        width  => $child_config->sizing_width_value,
                        height => $child_size->height
                    )
                );

                $logger->log( "Fixed-width child "
                      . $child->id . ": "
                      . $child_config->sizing_width_value );
            }
            elsif ( $child_config->sizing_width_type eq SIZING_GROW ) {
                $growable_count++;
            }
            else {
                # For other types (FIT, PERCENT), use their measured width
                $total_fixed_width += $child_size->width;
            }
        }

        # Add gaps between children
        my $gaps = 0;
        if ( @$children > 1 ) {
            $gaps = $layout_config->child_gap * ( @$children - 1 );
        }
        $total_fixed_width += $gaps;

        $logger->log(
            "Total fixed width: " . $total_fixed_width . ", Gaps: " . $gaps );

        # Calculate remaining width for growable children
        my $remaining_width = $available_width - $total_fixed_width;
        $remaining_width = 0
          if $remaining_width < 0; # CRITICAL FIX: Don't allocate negative space
        $logger->log(
            "Remaining width for growable children: " . $remaining_width );

        # Handle growable children if we have any
        if ( $growable_count > 0 && $remaining_width > 0 ) {
            my $width_per_growable = int( $remaining_width / $growable_count );
            $logger->log( "Width per growable child: " . $width_per_growable );

            foreach my $child (@$children) {
                my $child_config = $child->layout_config;
                my $child_size   = $child->get_content_size();

                if ( $child_config->sizing_width_type eq SIZING_GROW ) {

                # Assign equal portion of remaining width to each growable child
                    $child->size(
                        Clay::Types::Size->new(
                            width  => $width_per_growable,
                            height => $child_size->height
                        )
                    );

                    $logger->log( "Growable child "
                          . $child->id
                          . " assigned width: "
                          . $width_per_growable );
                }
            }
        }
        elsif ( $growable_count > 0 ) {

            # No space left for growable children, set them to minimum width
            foreach my $child (@$children) {
                my $child_config = $child->layout_config;
                my $child_size   = $child->get_content_size();

                if ( $child_config->sizing_width_type eq SIZING_GROW ) {
                    my $min_width = $child_config->sizing_width_min || 1;

                    $child->size(
                        Clay::Types::Size->new(
                            width  => $min_width,
                            height => $child_size->height
                        )
                    );

                    $logger->log( "No space for growable child "
                          . $child->id
                          . ", set to min width: "
                          . $min_width );
                }
            }
        }
    }

    # Phase 3: Wrap Text
    method _wrap_text_phase() {
        return unless $element_tree;

     # Process the entire element tree to find text elements and wrap their text
        $self->_wrap_text_recursive($element_tree);
    }

    # Helper method to recursively wrap text for all text elements
    method _wrap_text_recursive($element) {

        # If this is a text element, wrap its text now that widths are finalized
        if ( $element->is_text_element ) {
            my $box    = $element->get_bounding_box();
            my $config = $element->layout_config;

            # Calculate available width for text, accounting for padding
            my $available_width =
                $box
              ? $box->width - $config->padding->horizontal()
              : $element->get_content_size()->width -
              $config->padding->horizontal();

            # Ensure we have at least 1 character of width
            $available_width = 1 if $available_width < 1;

            # Use the buffer to measure and wrap the text
            $element->measure_text($available_width);
        }

        # Recursively process children
        foreach my $child ( $element->children->@* ) {
            $self->_wrap_text_recursive($child);
        }
    }

    # Phase 4: Fit Sizing Heights
    method _measure_heights_phase() {
        return unless $element_tree;

        # Process the element tree bottom-up to recalculate heights
        $self->_measure_heights_recursive($element_tree);
    }

# Helper method to recursively measure heights based on wrapped text and child layout
    method _measure_heights_recursive($element) {
        my $layout_config = $element->layout_config;
        my $children      = $element->children;

        # Process children first (bottom-up approach)
        foreach my $child (@$children) {
            $self->_measure_heights_recursive($child);
        }

        # Check if this is a text container (has text children)
        my $has_text_children = 0;
        my $text_height       = 0;
        foreach my $child (@$children) {
            if ( $child->is_text_element ) {
                $has_text_children = 1;

                # Add height for each text element (minimum 1 line)
                $text_height += 1;
            }
        }

        # Add gaps between text elements
        if ( $has_text_children && @$children > 1 ) {
            $text_height += $layout_config->child_gap * ( @$children - 1 );
        }

        # Get layout direction
        my $is_horizontal = $layout_config->layout_direction eq LEFT_TO_RIGHT
          || $layout_config->layout_direction eq RIGHT_TO_LEFT;

        # Calculate content height based on children
        my $content_size   = $element->get_content_size();
        my $content_height = 0;

        if ($is_horizontal) {

            # Horizontal layout: use maximum height of children
            foreach my $child (@$children) {
                my $child_size = $child->get_content_size();
                $content_height = $child_size->height
                  if $child_size->height > $content_height;
            }
        }
        else {
            # Vertical layout: sum heights of children plus gaps
            foreach my $child (@$children) {
                my $child_size = $child->get_content_size();
                $content_height += $child_size->height;
            }

            # Add gaps between children
            if ( @$children > 1 ) {
                $content_height +=
                  $layout_config->child_gap * ( @$children - 1 );
            }
        }

        # CRITICAL FIX: Ensure text containers have adequate height
        if ( $has_text_children && $content_height < $text_height ) {
            $content_height = $text_height;
            $logger->log("Adjusted text container height to: $text_height");
        }

        # Account for fixed height if specified
        if ( $layout_config->sizing_height_type eq SIZING_FIXED ) {
            $content_height = $layout_config->sizing_height_value;
        }

        # Account for percentage height if specified
        elsif ( $layout_config->sizing_height_type eq SIZING_PERCENT ) {
            my $parent = $element->parent;
            my $parent_height =
                $parent
              ? $parent->get_content_size()->height
              : $layout_dimensions->height;

            # CRITICAL FIX: Ensure percentage is interpreted correctly
            my $percent = $layout_config->sizing_height_value;

     # If percentage is given as a decimal (0.5 for 50%), convert to 0-100 scale
            $percent = $percent * 100 if $percent < 1;

            $content_height = int( ( $percent / 100 ) * $parent_height );
            $logger->log(
"Percentage height ($percent%) calculated: $content_height from parent: $parent_height"
            );
        }

  # CRITICAL FIX: Ensure minimum height accounts for padding and minimum content
        my $total_padding = $layout_config->padding->vertical();
        my $min_content_height =
          $has_text_children ? scalar(@$children) + $total_padding : 1;
        my $min_height = $total_padding + $min_content_height;

        if ( $content_height < $min_height ) {
            $content_height = $min_height;
            $logger->log(
                "Enforcing minimum height: $content_height for element "
                  . $element->id );
        }

        # Update the element's content size with the new height
        $element->size(
            Clay::Types::Size->new(
                width  => $content_size->width,
                height => $content_height
            )
        );

        $logger->log(
            "Set element " . $element->id . " height to: " . $content_height );
    }

    # Phase 5: Grow & Shrink Sizing Heights
    method _grow_shrink_heights_phase() {
        return unless $element_tree;

        # Apply grow/shrink adjustments to heights
        $self->_adjust_element_heights($element_tree);
    }

    # Helper method to adjust element heights based on grow/shrink rules
    method _adjust_element_heights($element) {

        # Skip leaf nodes and nodes with no children
        return unless $element && $element->children && @{ $element->children };

        my $layout_config = $element->layout_config;
        my $children      = $element->children;

        # Process children first (bottom-up)
        foreach my $child (@$children) {
            $self->_adjust_element_heights($child);
        }

        # Get layout direction
        my $is_vertical = $layout_config->layout_direction eq TOP_TO_BOTTOM
          || $layout_config->layout_direction eq BOTTOM_TO_TOP;

        # Skip if this isn't a vertical layout
        return unless $is_vertical;

        # Calculate available height and currently used height
        my $content_size = $element->get_content_size();
        my $available_height =
          $content_size->height - $layout_config->padding->vertical();

 # Calculate total height used by children and find growable/shrinkable children
        my $total_used_height = 0;
        my @growable_children;
        my @shrinkable_children;

        foreach my $child (@$children) {
            my $child_size   = $child->get_content_size();
            my $child_config = $child->layout_config;

            $total_used_height += $child_size->height;

            # Track growable children
            if ( $child_config->sizing_height_type eq SIZING_GROW ) {
                push @growable_children, $child;
            }

            # All children with non-fixed height are potentially shrinkable
            if ( $child_config->sizing_height_type ne SIZING_FIXED ) {
                push @shrinkable_children, $child;
            }
        }

        # Add gaps between children to total height
        if ( @$children > 1 ) {
            $total_used_height +=
              $layout_config->child_gap * ( @$children - 1 );
        }

        # Calculate remaining space
        my $remaining_height = $available_height - $total_used_height;

        # Handle growth if we have extra space and growable children
        if ( $remaining_height > 0 && @growable_children ) {

            # Distribute extra height among growable children
            my $height_per_child =
              $remaining_height / scalar(@growable_children);

            foreach my $child (@growable_children) {
                my $child_size = $child->get_content_size();
                my $new_height = $child_size->height + $height_per_child;

                # Apply max height constraint if applicable
                my $max_height = $child->layout_config->sizing_height_max;
                if ( $max_height > 0 && $new_height > $max_height ) {
                    $new_height = $max_height;
                }

                # Update the child's size
                $child->size(
                    Clay::Types::Size->new(
                        width  => $child_size->width,
                        height => $new_height
                    )
                );
            }
        }

        # Handle shrinking if we need to reduce height
        elsif ( $remaining_height < 0 && @shrinkable_children ) {

            # Simple approach: shrink all shrinkable children proportionally
            my $shrink_ratio = abs($remaining_height) / $total_used_height;

            foreach my $child (@shrinkable_children) {
                my $child_size = $child->get_content_size();
                my $min_height = $child->layout_config->sizing_height_min || 1;

                # Calculate new height with shrink ratio
                my $new_height = $child_size->height * ( 1 - $shrink_ratio );
                $new_height = $min_height if $new_height < $min_height;

                # Update the child's size
                $child->size(
                    Clay::Types::Size->new(
                        width  => $child_size->width,
                        height => $new_height
                    )
                );
            }
        }
    }

    # Phase 6: Positions
    method _position_phase() {
        return unless $element_tree;

        # Calculate positions for the entire element tree starting from the root
        $self->_layout_element( $element_tree, 0, 0, $layout_dimensions->width,
            $layout_dimensions->height );
    }

    # Helper method to recursively calculate positions for all elements
    method _layout_element( $element, $x, $y, $width, $height ) {
        $logger->log( "Layout element - ID: "
              . $element->id
              . ", X: $x, Y: $y, Width: $width, Height: $height" );

        # Set this element's bounding box
        $element->set_bounding_box(
            Clay::Types::Rect->new(
                x      => $x,
                y      => $y,
                width  => $width,
                height => $height
            )
        );

        # Skip layout for text elements or elements with no children
        if ( !$element->children || @{ $element->children } == 0 ) {
            return;
        }

        my $layout_config = $element->layout_config;
        my $children      = $element->children;

        # Calculate inner area considering padding
        my $content_x      = $x + $layout_config->padding->left;
        my $content_y      = $y + $layout_config->padding->top;
        my $content_width  = $width - $layout_config->padding->horizontal();
        my $content_height = $height - $layout_config->padding->vertical();

        $logger->log(
"Content area - X: $content_x, Y: $content_y, Width: $content_width, Height: $content_height"
        );

        # Get layout direction
        my $direction = $layout_config->layout_direction;
        my $is_horizontal =
          $direction eq LEFT_TO_RIGHT || $direction eq RIGHT_TO_LEFT;
        my $is_rtl = $direction eq RIGHT_TO_LEFT;
        my $is_btt = $direction eq BOTTOM_TO_TOP;

        # For RTL or BTT layouts, we need to reverse the positioning
        my @sorted_children = $element->children->@*;
        if ( $is_rtl || $is_btt ) {
            @sorted_children = reverse @sorted_children;
        }

        # Position elements based on layout direction
        if ($is_horizontal) {
            $logger->log( "Laying out horizontal element: " . $element->id );

          # Calculate total requested width and prepare for horizontal alignment
            my $total_child_width = 0;
            foreach my $child (@sorted_children) {
                my $child_size  = $child->get_content_size();
                my $child_width = $child_size->width;

                # Ensure valid width
                if ( $child_width <= 0 ) {
                    if ( $child->layout_config->sizing_width_type eq
                        SIZING_FIXED )
                    {
                        $child_width =
                          $child->layout_config->sizing_width_value || 1;
                    }
                    elsif ( $child->is_text_element ) {

                        # For text elements, estimate width based on text length
                        $child_width = length( $child->text ) || 10;
                    }
                    else {
                        $child_width = 1;
                    }
                }

                $total_child_width += $child_width;
            }

            # Add gaps
            my $gaps = 0;
            if ( @sorted_children > 1 ) {
                $gaps = $layout_config->child_gap * ( @sorted_children - 1 );
            }
            $total_child_width += $gaps;

            $logger->log(
"Total child width: $total_child_width, Content width: $content_width"
            );

            # Calculate scale factor if we need to shrink elements
            my $scale_factor = 1.0;
            if ( $total_child_width > $content_width ) {
                $scale_factor = $content_width / $total_child_width;
                $logger->log("Scaling elements by factor: $scale_factor");
            }

        # CRITICAL FIX: Apply parent's horizontal alignment to position children
            my $start_x = $content_x;    # Default left alignment

            if ( $layout_config->alignment_x eq ALIGN_CENTER ) {

                # Center alignment - calculate remaining space and divide by 2
                my $scaled_width    = $total_child_width * $scale_factor;
                my $remaining_space = $content_width - $scaled_width;
                if ( $remaining_space > 0 ) {
                    $start_x = $content_x + int( $remaining_space / 2 );
                    $logger->log(
                        "Centering children, start_x adjusted to: $start_x");
                }
            }
            elsif ( $layout_config->alignment_x eq ALIGN_RIGHT ) {

                # Right alignment - position at the right edge minus total width
                my $scaled_width = $total_child_width * $scale_factor;
                if ( $scaled_width < $content_width ) {
                    $start_x = $content_x + ( $content_width - $scaled_width );
                    $logger->log(
                        "Right-aligning children, start_x adjusted to: $start_x"
                    );
                }
            }

            # Start positioning from the calculated starting position
            my $current_x = $start_x;

            foreach my $child (@sorted_children) {
                my $child_size = $child->get_content_size();

                # Calculate scaled width
                my $child_width = $child_size->width;
                if ( $child_width <= 0 ) {
                    if ( $child->layout_config->sizing_width_type eq
                        SIZING_FIXED )
                    {
                        $child_width =
                          $child->layout_config->sizing_width_value || 1;
                    }
                    elsif ( $child->is_text_element ) {

                        # For text elements, use a reasonable width
                        $child_width = length( $child->text ) || 10;
                    }
                    else {
                        $child_width = 1;
                    }
                }

                # Apply scaling
                my $scaled_width = int( $child_width * $scale_factor );
                if ( $scaled_width < 1 ) {
                    $scaled_width = 1;
                }

                $logger->log( "Child "
                      . $child->id
                      . " width: $child_width scaled to: $scaled_width" );

                # Apply vertical alignment
                my $child_y = $content_y;

                # CRITICAL FIX: Set proper height for SIZING_GROW elements
                my $child_height = $child_size->height;
                if ( $child->layout_config->sizing_height_type eq SIZING_GROW )
                {
                    $child_height = $content_height;
                    $logger->log( "Setting growing height for "
                          . $child->id
                          . " to: $child_height" );
                }

                if ( $child_height <= 0 ) {
                    $child_height = 1;
                }

                if ( $layout_config->alignment_y eq ALIGN_CENTER ) {
                    $child_y += int( ( $content_height - $child_height ) / 2 );
                }
                elsif ( $layout_config->alignment_y eq ALIGN_BOTTOM ) {
                    $child_y += $content_height - $child_height;
                }

                # Position this child and process its children
                $self->_layout_element( $child, $current_x, $child_y,
                    $scaled_width, $child_height );

                # Move to next position
                $current_x += $scaled_width + $layout_config->child_gap;
            }
        }
        else {
            $logger->log( "Laying out vertical element: " . $element->id );

            # Calculate total requested height and total width for alignment
            my $total_child_height = 0;
            my $max_child_width    = 0;
            foreach my $child (@sorted_children) {
                my $child_size   = $child->get_content_size();
                my $child_height = $child_size->height;

                # Ensure valid height
                if ( $child_height <= 0 ) {
                    if ( $child->layout_config->sizing_height_type eq
                        SIZING_FIXED )
                    {
                        $child_height =
                          $child->layout_config->sizing_height_value || 1;
                    }
                    else {
                        $child_height = 1;
                    }
                }

                $total_child_height += $child_height;

                # Track maximum child width for horizontal alignment
                my $child_width = $child_size->width;
                if ( $child->is_text_element ) {

         # CRITICAL FIX: For text elements, width should be based on text length
                    $child_width = length( $child->text );
                    $child_width = $child_width < 10 ? 10 : $child_width;
                }

                if ( $child_width > $max_child_width ) {
                    $max_child_width = $child_width;
                }
            }

            # Add gaps between children
            my $gaps = 0;
            if ( @sorted_children > 1 ) {
                $gaps = $layout_config->child_gap * ( @sorted_children - 1 );
            }
            $total_child_height += $gaps;

            $logger->log(
"Total child height: $total_child_height, Content height: $content_height"
            );

            # Calculate scale factor if we need to shrink elements
            my $scale_factor = 1.0;
            if ( $total_child_height > $content_height ) {
                $scale_factor = $content_height / $total_child_height;
                $logger->log("Scaling elements by factor: $scale_factor");
            }

            # Start positioning
            my $current_y = $content_y;

            foreach my $child (@sorted_children) {
                my $child_size = $child->get_content_size();

                # Calculate scaled height
                my $child_height = $child_size->height;
                if ( $child_height <= 0 ) {
                    if ( $child->layout_config->sizing_height_type eq
                        SIZING_FIXED )
                    {
                        $child_height =
                          $child->layout_config->sizing_height_value || 1;
                    }
                    else {
                        $child_height = 1;
                    }
                }

                # Apply scaling to height
                my $scaled_height = int( $child_height * $scale_factor );
                if ( $scaled_height < 1 ) {
                    $scaled_height = 1;
                }

                # Calculate child width
                my $child_width = $child_size->width;

                # CRITICAL FIX: Special handling for text elements
                if ( $child->is_text_element ) {

                    # For text elements, use the full container width
                    $child_width = $content_width;

                    # Update the child's size to ensure proper dimensions
                    $child->size(
                        Clay::Types::Size->new(
                            width  => $child_width,
                            height => $child_size->height
                        )
                    );

                    $logger->log( "Setting text element "
                          . $child->id
                          . " width to: $child_width" );
                }
                elsif (
                    $child->layout_config->sizing_width_type eq SIZING_GROW )
                {
                    $child_width = $content_width;
                    $logger->log( "Setting growing width for "
                          . $child->id
                          . " to: $child_width" );
                }

                if ( $child_width <= 0 ) {
                    $child_width = 1;
                }

                # Apply horizontal alignment
                my $child_x = $content_x;
                if ( $layout_config->alignment_x eq ALIGN_CENTER ) {
                    $child_x += int( ( $content_width - $child_width ) / 2 );
                    $logger->log( "Centering child "
                          . $child->id
                          . ", child_x: $child_x" );
                }
                elsif ( $layout_config->alignment_x eq ALIGN_RIGHT ) {
                    $child_x += $content_width - $child_width;
                    $logger->log( "Right-aligning child "
                          . $child->id
                          . ", child_x: $child_x" );
                }

                # Position this child and process its children
                $self->_layout_element( $child, $child_x, $current_y,
                    $child_width, $scaled_height );

                # Move to next position
                $current_y += $scaled_height + $layout_config->child_gap;
            }
        }
    }

    # Clear the screen
    method clear() {
        $buffer->clear();
        @commands = ();
    }

    # Render the current commands to the buffer
    method render() {

        # Skip if there are no commands or no buffer
        return unless $buffer && @commands;

        # Process each render command
        $self->_process_render_command($_) for @commands;

        # Actually display the buffer (might flush to the screen)
        $buffer->render();    # NOOP becasue buffer isn't a double buffer
    }

    # Process a single render command
    method _process_render_command($cmd) {
        return unless $cmd && $cmd->{type};

        if ( $cmd->{type} eq 'rectangle' ) {

            # Draw a rectangle
            $buffer->draw_rect(
                $cmd->{rect}->x,     $cmd->{rect}->y,
                $cmd->{rect}->width, $cmd->{rect}->height,
                $cmd->{color}
            );
        }
        elsif ( $cmd->{type} eq 'border' ) {
            $logger->log(
                sprintf "Drawing border: x: %d, y: %d, W: %d, H: %d, style: %s",
                $cmd->{rect}->x,     $cmd->{rect}->y,
                $cmd->{rect}->width, $cmd->{rect}->height,
                $cmd->{config}->style
            );

            # Draw a border
            $buffer->draw_border(
                $cmd->{rect}->x,     $cmd->{rect}->y,
                $cmd->{rect}->width, $cmd->{rect}->height,
                $cmd->{config}->style
            );
        }
        elsif ( $cmd->{type} eq 'text' ) {
            $logger->log(
                sprintf "Drawing text: x: %d, y: %d, text: %s",
                $cmd->{position}->x,
                $cmd->{position}->y,
                $cmd->{text}
            );

            # Draw text
            $buffer->draw_text(
                $cmd->{position}->x,
                $cmd->{position}->y,
                $cmd->{text}
            );
        }

        # Additional command types can be added here
    }

    method key_pressed( $seconds = 0 ) {
        return $buffer->key_pressed($seconds);
    }

    method get_key() {
        return Clay::Types::Event::key_event( $buffer->get_key() );
    }

    method handle_event($event) {
        if ( $event->type eq 'key' ) {
            if ( $event->key eq 'q' ) {
                exit(0);
            }
        }
    }
}

1;
