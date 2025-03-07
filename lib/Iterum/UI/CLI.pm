use 5.40.0;
use utf8;
use experimental 'class';

# Main UI class for CLI interface
class Iterum::UI::CLI {

    use File::Spec;
    use Clay;
    use Clay::Context;
    use Clay::Types;
    use Clay::Builder;
    use Clay::UI;

    # Clay infrastructure
    field $context =
      Clay::Context->new();    # Clay context (creates its own buffer)
    field $commands = [];      # Current rendering commands
    field $ui_layout;          # Root UI layout element

    # Message system
    field $messages      = [];    # Array to store message history
    field $max_messages  = 20;    # Maximum number of messages to keep
    field $coalesce_time = 2;     # Time window for message coalescing (seconds)
    field $timestamp_display = 1;    # Whether to show timestamps

    # Initialization
    ADJUST {
        # Set up the initial UI layout
        $self->create_layout();

        # Clear screen
        $self->clear();
    }

    # Create the UI layout structure
    method create_layout() {

        # Use Clay's layout system to define UI regions
        $ui_layout = Clay::Builder::ElementBuilder->new(
            context => $context,
            config  => {
                id       => 'root',
                layout   => 'vertical',
                children => [
                    {
                        id     => 'header',
                        height => 1,
                        layout => 'horizontal',
                    },
                    {
                        id     => 'title',
                        height => 1,
                    },
                    {
                        id       => 'status_area',
                        layout   => 'horizontal',
                        height   => 4,
                        children => [
                            {
                                id    => 'player',
                                width => 0.5,        # 50% of parent width
                            },
                            {
                                id    => 'enemy',
                                width => 0.5,        # 50% of parent width
                            },
                        ],
                    },
                    {
                        id   => 'messages',
                        flex => 1,            # Take available space
                    },
                    {
                        id       => 'feedback_area',
                        layout   => 'horizontal',
                        height   => 5,
                        children => [
                            {
                                id    => 'combat_options',
                                width => 0.5,              # 50% of parent width
                            },
                            {
                                id    => 'ev_feedback',
                                width => 0.5,              # 50% of parent width
                            },
                        ],
                    },
                    {
                        id     => 'result',
                        height => 4,
                    },
                    {
                        id     => 'input',
                        height => 1,
                    },
                ],
            },
        );

        # Calculate layout based on current terminal size
        $ui_layout->calculate_layout();
    }

    # ========================
    # Input Handling Methods
    # ========================

    # Get a single keystroke (encapsulating buffer access)
    method read_key() {
        return $context->buffer->getch();
    }

    # Check if a key is pressed
    method key_pressed( $timeout = 0 ) {
        return $context->buffer->key_pressed($timeout);
    }

    # ========================
    # Color Handling Functions
    # ========================

    # Convert a color name to a Clay::Types::Color object
    method color( $name = 'white' ) {

        # Default color map for common names
        my %color_map = (
            'red'         => [ 255, 0,   0 ],
            'green'       => [ 0,   255, 0 ],
            'blue'        => [ 0,   0,   255 ],
            'yellow'      => [ 255, 255, 0 ],
            'cyan'        => [ 0,   255, 255 ],
            'bright_cyan' => [ 0,   255, 255 ],
            'magenta'     => [ 255, 0,   255 ],
            'white'       => [ 255, 255, 255 ],
            'black'       => [ 0,   0,   0 ],
            'gray'        => [ 128, 128, 128 ],
        );

        # Get RGB values for the color name, default to white if not found
        my $rgb = $color_map{ lc($name) } // [ 255, 255, 255 ];

        # Create and return a new Clay::Types::Color object
        return Clay::Types::Color->new(
            r => $rgb->[0],
            g => $rgb->[1],
            b => $rgb->[2]
        );
    }

    # ========================
    # Basic Drawing Functions
    # ========================

    # Clear the screen
    method clear() {
        $context->clear();
        $commands = [];
        return $self;
    }

    # Refresh/render the screen
    method refresh() {
        $context->commands($commands);
        $context->render();
        return $self;
    }

    # Add multiple commands to the context
    method add_commands(@new_commands) {
        push @$commands, @new_commands;
        return $self;
    }

    # Find an element by ID
    method find_element($id) {

       # Starting with the root layout, search for the element with the given ID
        my $find_by_id = sub {
            my ( $element, $target_id ) = @_;

            return $element if $element->{id} eq $target_id;

            if ( $element->{children} ) {
                for my $child ( @{ $element->{children} } ) {
                    my $found = $find_by_id->( $child, $target_id );
                    return $found if $found;
                }
            }

            return undef;
        };

        return $find_by_id->( $ui_layout, $id );
    }

    # Get the bounds of an element
    method get_element_bounds($id) {
        my $element = $self->find_element($id);
        return undef unless $element;

        # Get the element's computed bounds
        return {
            x      => $element->{computed_x},
            y      => $element->{computed_y},
            width  => $element->{computed_width},
            height => $element->{computed_height},
        };
    }

    # Draw a box around an element
    method draw_box( $element_id, $style = 'single', $title = undef ) {
        my $bounds = $self->get_element_bounds($element_id);
        return $self unless $bounds;

        # Determine border width based on style
        my $border_width = ( $style eq 'double' ) ? 2 : 1;

        # Create border command
        my $box_command = {
            type => 'border',
            rect => Clay::Types::Rect->new(
                x      => $bounds->{x},
                y      => $bounds->{y},
                width  => $bounds->{width},
                height => $bounds->{height}
            ),
            config => Clay::Types::BorderConfig->new(
                width_top    => $border_width,
                width_right  => $border_width,
                width_bottom => $border_width,
                width_left   => $border_width,
                color        => $self->color('white'),
            ),
            z_index => 1,
        };

        # Add the box command
        push @$commands, $box_command;

        # Add title if provided
        if ( defined $title ) {

            # Ensure title fits within the box
            my $max_title_length = $bounds->{width} - 4;
            my $display_title =
              length($title) > $max_title_length
              ? substr( $title, 0, $max_title_length - 3 ) . "..."
              : $title;

            # Add title text
            push @$commands,
              {
                type     => 'text',
                position => Clay::Types::Point->new(
                    x => $bounds->{x} + 2,
                    y => $bounds->{y}
                ),
                text   => $display_title,
                config => Clay::Types::TextConfig->new(
                    color => $self->color('white'),
                    bold  => 1,
                ),
                z_index => 2,
              };
        }

        return $self;
    }

    # Add text to an element with offset
    method add_text_to_element( $element_id, $x_offset, $y_offset, $text,
        $color_name = 'white',
        $bold = 0 )
    {
        my $bounds = $self->get_element_bounds($element_id);
        return $self unless $bounds;

        push @$commands, {
            type     => 'text',
            position => Clay::Types::Point->new(
                x => $bounds->{x} + $x_offset,
                y => $bounds->{y} + $y_offset
            ),
            text   => $text,
            config => Clay::Types::TextConfig->new(
                color => $self->color($color_name),
                bold  => $bold,
                wrap => Clay::Types::WRAP_WORDS, # Let Clay handle text wrapping
                width => $bounds->{width} - $x_offset -
                  1,                             # Respect element boundaries
            ),
            z_index => 2,
        };

        return $self;
    }

    # Fill an element with a background color
    method fill_element( $element_id, $color_name = 'black' ) {
        my $bounds = $self->get_element_bounds($element_id);
        return $self unless $bounds;

        push @$commands,
          {
            type => 'rectangle',
            rect => Clay::Types::Rect->new(
                x      => $bounds->{x},
                y      => $bounds->{y},
                width  => $bounds->{width},
                height => $bounds->{height}
            ),
            color   => $self->color($color_name),
            z_index => 0,
          };

        return $self;
    }

    # Clear an element (fill with black background)
    method clear_element($element_id) {
        return $self->fill_element( $element_id, 'black' );
    }

    # =========================
    # Rendering Helper Methods
    # =========================

    # Render to an element using a callback
    method render_element( $element_id, $render_callback ) {
        my $bounds = $self->get_element_bounds($element_id);
        return $self unless $bounds;

        # Clear the element first
        $self->clear_element($element_id);

        # Create a context object to pass to the callback
        my $ctx = {
            element_id => $element_id,
            bounds     => $bounds,

            # Helper for adding text within this element
            add_text => sub {
                my ( $x_offset, $y_offset, $text, $color = 'white', $bold = 0 )
                  = @_;
                $self->add_text_to_element( $element_id, $x_offset, $y_offset,
                    $text, $color, $bold );
            },

            # Helper for drawing a box around this element
            draw_box => sub {
                my ( $style = 'single', $title = undef ) = @_;
                $self->draw_box( $element_id, $style, $title );
            },

            # Helper for adding any command
            add_command => sub {
                my ($command) = @_;
                push @$commands, $command;
            },
        };

        # Call the render callback with our context
        $render_callback->($ctx);

        return $self;
    }

    # ==============================
    # Higher-Level Display Methods
    # ==============================

    # Display a header
    method display_header($text) {
        $self->render_element(
            'header',
            sub {
                my $ctx = shift;

                # Create header text with fill
                my $header_text = "=== $text ";
                my $remaining   = $ctx->{bounds}{width} - length($header_text);
                $header_text .= "=" x $remaining if $remaining > 0;

                # Display header
                $ctx->add_text( 0, 0, $header_text, 'white', 1 );
            }
        );

        return $self;
    }

    # Display a title
    method display_title($title) {
        $self->render_element(
            'title',
            sub {
                my $ctx = shift;

                # Calculate centering
                my $padding =
                  int( ( $ctx->{bounds}{width} - length($title) ) / 2 );
                $padding = 0 if $padding < 0;

                # Display centered title
                $ctx->add_text( $padding, 0, $title, 'white', 1 );
            }
        );

        return $self;
    }

    # Display player stats
    method display_player($player) {
        return $self unless $player && ref $player eq 'HASH';

        $self->render_element(
            'player',
            sub {
                my $ctx = shift;

                # Display player name
                $ctx->add_text( 0, 0, "Player: " . $player->{name}, 'white',
                    1 );

                # Calculate HP percentage for color
                my $hp_percent =
                  $player->{health}{current_hp} / $player->{health}{max_hp};
                my $hp_color =
                  $hp_percent > 0.7
                  ? 'green'
                  : ( $hp_percent > 0.3 ? 'yellow' : 'red' );

                # Display HP
                $ctx->add_text( 2, 0, "HP: " );
                $ctx->add_text(
                    6,
                    0,
                    $player->{health}{current_hp} . "/"
                      . $player->{health}{max_hp},
                    $hp_color
                );

                # Display attack and defense stats
                $ctx->add_text( 2, 1,
                        "ATK: "
                      . $player->{stats}{attack}
                      . " DEF: "
                      . $player->{stats}{defense} );
            }
        );

        return $self;
    }

    # Display enemy stats
    method display_enemy($enemy) {
        return $self unless $enemy && ref $enemy eq 'HASH';

        $self->render_element(
            'enemy',
            sub {
                my $ctx = shift;

                # Display enemy name
                $ctx->add_text( 0, 0, "Enemy: " . $enemy->{name}, 'white', 1 );

                # Calculate HP percentage for color
                my $hp_percent =
                  $enemy->{health}{current_hp} / $enemy->{health}{max_hp};
                my $hp_color =
                  $hp_percent > 0.7
                  ? 'green'
                  : ( $hp_percent > 0.3 ? 'yellow' : 'red' );

                # Display HP
                $ctx->add_text( 2, 0, "HP: " );
                $ctx->add_text(
                    6,
                    0,
                    $enemy->{health}{current_hp} . "/"
                      . $enemy->{health}{max_hp},
                    $hp_color
                );

                # Display attack and defense stats
                $ctx->add_text( 2, 1,
                        "ATK: "
                      . $enemy->{stats}{attack}
                      . " DEF: "
                      . $enemy->{stats}{defense} );
            }
        );

        return $self;
    }

    # Display combat status (player and enemy)
    method display_status( $player, $enemy ) {

        # Clear the screen
        $self->clear();

        # Display header
        $self->display_header("ITERUM - COMBAT");

        # Display player and enemy stats
        $self->display_player($player);
        $self->display_enemy($enemy);

        # Display message history
        $self->display_message_history();

        # Refresh the screen
        $self->refresh();

        return $self;
    }

    # ======================
    # Message System Methods
    # ======================

    # Add a message to the history
    method add_message( $content, $type = 'info', $color = 'white' ) {

        # Create message object with timestamp
        my $timestamp = time();
        my $message   = {
            content   => $content,
            type      => $type,
            color     => $color,
            timestamp => $timestamp,
            count     => 1,
        };

        # Check for coalescing
        if (   @$messages
            && $messages->[-1]{type} eq $type
            && $timestamp - $messages->[-1]{timestamp} < $coalesce_time
            && $messages->[-1]{content} eq $content )
        {
            # Same message in coalesce window - update count
            $messages->[-1]{count}++;
            $messages->[-1]{timestamp} = $timestamp;
        }
        else {
            # New message - add to array
            push @$messages, $message;

            # Keep array size limited
            shift @$messages if scalar(@$messages) > $max_messages;
        }

        # Display updated message history
        $self->display_message_history();

        return $self;
    }

    # Helper methods for different message types
    method add_combat_message( $message, $color = 'white' ) {
        $self->add_message( $message, 'combat', $color );
    }

    method add_ev_message( $message, $color = 'white' ) {
        $self->add_message( $message, 'ev', $color );
    }

    method add_system_message( $message, $color = 'white' ) {
        $self->add_message( $message, 'system', $color );
    }

    method add_error_message($message) {
        $self->add_message( $message, 'error', 'red' );
    }

    # Display message history using Clay's text wrapping
    method display_message_history() {
        $self->render_element(
            'messages',
            sub {
                my $ctx = shift;

                # Draw a box around the messages
                $ctx->draw_box( 'double',
                    "Messages (" . scalar(@$messages) . ")" );

                # Calculate available display space
                my $display_height =
                  $ctx->{bounds}{height} - 2;    # Account for borders
                my $msg_idx = scalar(@$messages) - 1;

                # Display messages from newest to oldest
                my $y_offset   = $display_height - 1;    # Start from bottom
                my $msgs_shown = 0;

                while ( $msg_idx >= 0 && $y_offset >= 1 ) {
                    my $msg = $messages->[$msg_idx];

                    # Format prefix based on message type
                    my $prefix = '';
                    my $color  = $msg->{color} || 'white';

                    if ( $msg->{type} eq 'combat' ) {
                        $prefix = "[Combat] ";
                    }
                    elsif ( $msg->{type} eq 'ev' ) {
                        $prefix = "[EV] ";
                    }
                    elsif ( $msg->{type} eq 'system' ) {
                        $prefix = "[System] ";
                    }
                    elsif ( $msg->{type} eq 'error' ) {
                        $prefix = "[Error] ";
                        $color  = 'red' unless $color ne 'white';
                    }

                    # Add count if more than 1
                    my $count_suffix =
                      $msg->{count} > 1 ? " (x$msg->{count})" : "";

                    # Format timestamp if enabled
                    my $time_prefix = "";
                    if ($timestamp_display) {
                        my $elapsed = time() - $msg->{timestamp};
                        if ( $elapsed < 60 ) {
                            $time_prefix = "[$elapsed" . "s] ";
                        }
                        else {
                            my $min = int( $elapsed / 60 );
                            $time_prefix = "[$min" . "m] ";
                        }
                    }

                    # Combine all parts
                    my $full_msg =
                      $time_prefix . $prefix . $msg->{content} . $count_suffix;

                    # Let Clay handle text wrapping
                    # Add with proper configuration for wrapping
                    push @$commands, {
                        type     => 'text',
                        position => Clay::Types::Point->new(
                            x => $ctx->{bounds}{x} + 2,
                            y => $ctx->{bounds}{y} + $y_offset
                        ),
                        text   => $full_msg,
                        config => Clay::Types::TextConfig->new(
                            color => $self->color($color),
                            wrap  => Clay::Types::WRAP_WORDS,
                            width => $ctx->{bounds}{width} -
                              4,    # Account for borders and padding
                        ),
                        z_index => 2,
                    };

        # Approximate space taken by this message (for positioning next message)
        # In a real implementation, Clay would track this for us
                    my $approx_lines =
                      int( length($full_msg) / ( $ctx->{bounds}{width} - 4 ) )
                      + 1;
                    $y_offset -= $approx_lines;

                    $msg_idx--;
                    $msgs_shown++;

                    # Stop if we've run out of vertical space
                    last if $y_offset < 1;
                }
            }
        );

        $self->refresh();
        return $self;
    }

    # Clear all messages
    method clear_messages() {
        $messages = [];
        $self->display_message_history();
        return $self;
    }

    # ===========================
    # Combat and Input Functions
    # ===========================

    # Display combat options
    method display_combat_options($options) {
        $self->render_element(
            'combat_options',
            sub {
                my $ctx = shift;

                # Display combat options title
                $ctx->add_text( 0, 0, "Combat Options:", 'white', 1 );

                # Display each option with its number
                for my $i ( 0 .. $#$options ) {
                    $ctx->add_text( 2, $i + 1,
                        ( $i + 1 ) . ". " . $options->[$i] );
                }
            }
        );

        $self->refresh();
        return $self;
    }

    # Get combat action from player
    method get_combat_action() {
        my @options = ( 'attack', 'defend', 'help', 'quit' );

        # Display options
        $self->display_combat_options( \@options );

        # Add the input prompt at the bottom
        $self->render_element(
            'input',
            sub {
                my $ctx = shift;
                $ctx->add_text( 0, 0, "Enter your choice (or first letter): " );
            }
        );

        $self->refresh();

        # Get player input using our encapsulated method
        my $input = $self->read_key();

        # Handle first letter shortcuts
        if ( $input =~ /^[adqh]$/i ) {
            if ( $input =~ /^a$/i ) {
                return 'attack';
            }
            if ( $input =~ /^d$/i ) {
                return 'defend';
            }
            if ( $input =~ /^q$/i ) {
                return 'quit';
            }
            if ( $input =~ /^h$/i ) {
                return 'help';
            }
        }

        # Handle numeric choice
        if ( $input =~ /^[1-4]$/ ) {
            return $options[ $input - 1 ];
        }

        # Invalid input, return default
        return 'attack';
    }

    # Display combat result
    method display_result($result) {
        $self->render_element(
            'result',
            sub {
                my $ctx = shift;

                # Draw box around result
                $ctx->draw_box( 'single', "ACTION RESULT" );

                # Display action
                $ctx->add_text( 2, 1, "Action: " . $result->{action} );

                # Display success or failure
                if ( $result->{success} ) {
                    $ctx->add_text( 2, 2,
                        "Success! Damage dealt: " . $result->{damage},
                        'green' );
                }
                else {
                    $ctx->add_text( 2, 2, "Failed!", 'red' );
                }

                # Display EV score with color based on value
                my $ev_score = $result->{ev_score};
                my $ev_color =
                  $ev_score > 0.7
                  ? 'green'
                  : ( $ev_score > 0.3 ? 'yellow' : 'red' );
                $ctx->add_text( 2, 3, "EV Score: " . $ev_score, $ev_color );
            }
        );

        # Also update the message history
        $self->add_system_message("Result:");
        my $message = "Action: " . $result->{action};

        if ( $result->{success} ) {
            $message .= " - Success! Damage dealt: " . $result->{damage};
            $self->add_combat_message( $message, 'green' );
        }
        else {
            $message .= " - Failed!";
            $self->add_combat_message( $message, 'red' );
        }

        $self->add_ev_message(
            "EV Score: " . $result->{ev_score},
            $result->{ev_score} > 0.7
            ? 'green'
            : ( $result->{ev_score} > 0.3 ? 'yellow' : 'red' )
        );

        $self->refresh();
        return $self;
    }

    # Display EV feedback
    method display_ev_feedback($feedback) {
        $self->render_element(
            'ev_feedback',
            sub {
                my $ctx = shift;

                # Draw box
                $ctx->draw_box( 'single', "AI COACH FEEDBACK" );

                # Add each feedback item
                for my $i ( 0 .. $#$feedback ) {

                    # Don't exceed available space
                    last if $i + 2 >= $ctx->{bounds}{height};

                    $ctx->add_text( 2, $i + 1, "* " . $feedback->[$i], 'cyan' );
                }
            }
        );

        # Also add each feedback item as a separate message
        for my $comment (@$feedback) {
            $self->add_ev_message( $comment, 'cyan' );
        }

        $self->refresh();
        return $self;
    }

    # Get generic input from the user
    method get_input( $options = undef ) {

        # Clear input element
        $self->clear_element('input');

        if ( defined $options ) {

            # Options mode - display prompt
            $self->render_element(
                'input',
                sub {
                    my $ctx = shift;
                    $ctx->add_text( 0, 0,
                        "Enter your choice (1-" . scalar(@$options) . "): " );
                }
            );

            $self->refresh();

            my $input;
            my $valid = 0;

            while ( !$valid ) {
                $input = $self->read_key();

                # Handle special keys
                if ( $input eq 'q' || $input eq 'Q' ) {
                    die "User quit the game";
                }

                # Clear error message space
                $self->render_element(
                    'input',
                    sub {
                        my $ctx = shift;
                        $ctx->add_text( 0, 0,
                                "Enter your choice (1-"
                              . scalar(@$options) . "): "
                              . $input );
                    }
                );

                # Validate input
                if ( $input !~ /^\d+$/ ) {
                    $self->add_text_to_element( 'input', 0, 1,
                        "Invalid input. Please enter a number.",
                        'red', 1 );
                    $self->refresh();
                    next;
                }

                my $index = $input - 1;
                if ( $index < 0 || $index > $#$options ) {
                    $self->add_text_to_element(
                        'input',
                        0,
                        1,
                        "Invalid choice. Please choose 1-"
                          . scalar(@$options) . ".",
                        'red',
                        1
                    );
                    $self->refresh();
                    next;
                }

                $valid = 1;
                return $options->[$index];
            }
        }
        else {
            # Any key press mode - just wait for any key
            $self->refresh();
            return $self->read_key();
        }
    }

    # Prompt user to continue
    method prompt_continue() {
        $self->render_element(
            'input',
            sub {
                my $ctx = shift;
                $ctx->add_text( 0, 0, "Press any key to continue..." );
            }
        );

        $self->refresh();
        $self->read_key();
        return $self;
    }

    # Clean up and reset terminal
    method cleanup() {
        $self->clear();
        $self->refresh();
        return $self;
    }
}

1;
