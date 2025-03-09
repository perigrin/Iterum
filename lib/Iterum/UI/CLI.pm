use 5.40.0;
use utf8;
use experimental 'class';

# Main UI class for CLI interface
class Iterum::UI::CLI {

    use File::Spec;
    use Clay;

    # Clay infrastructure
    field $context :reader = create_context();
    field $root;             # Root UI element
    field $commands = [];    # Current rendering commands

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
        $root = create_root(
            $context,
            {
                id            => 'root',
                layout_config => Clay::Types::LayoutConfig->new(
                    sizing_width_type  => $SIZING_GROW,
                    sizing_height_type => $SIZING_GROW,
                    layout_direction   => $TOP_TO_BOTTOM,
                    padding            => padding_all(1),
                    child_gap          => 1,
                ),
                border_config => border_box( color( 200, 200, 200 ) ),
                children      => [
                    {
                        id            => 'header',
                        layout_config => Clay::Types::LayoutConfig->new(
                            sizing_width_type   => $SIZING_GROW,
                            sizing_height_type  => $SIZING_FIXED,
                            sizing_height_value => 1,
                            layout_direction    => $LEFT_TO_RIGHT,
                        ),
                    },
                    {
                        id            => 'title',
                        layout_config => Clay::Types::LayoutConfig->new(
                            sizing_width_type   => $SIZING_GROW,
                            sizing_height_type  => $SIZING_FIXED,
                            sizing_height_value => 1,
                        ),
                    },
                    {
                        id            => 'status_area',
                        layout_config => Clay::Types::LayoutConfig->new(
                            sizing_width_type   => $SIZING_GROW,
                            sizing_height_type  => $SIZING_FIXED,
                            sizing_height_value => 4,
                            layout_direction    => $LEFT_TO_RIGHT,
                            child_gap           => 2,
                        ),
                        children => [
                            {
                                id            => 'player',
                                layout_config => Clay::Types::LayoutConfig->new(
                                    sizing_width_type  => $SIZING_FIXED,
                                    sizing_width_value => 40,
                                    sizing_height_type => $SIZING_GROW,
                                ),
                                border_config =>
                                  border_all( 1, color( 100, 100, 200 ) ),
                            },
                            {
                                id            => 'enemy',
                                layout_config => Clay::Types::LayoutConfig->new(
                                    sizing_width_type  => $SIZING_FIXED,
                                    sizing_width_value => 40,
                                    sizing_height_type => $SIZING_GROW,
                                ),
                                border_config =>
                                  border_all( 1, color( 200, 100, 100 ) ),
                            },
                        ],
                    },
                    {
                        id            => 'messages',
                        layout_config => Clay::Types::LayoutConfig->new(
                            sizing_width_type  => $SIZING_GROW,
                            sizing_height_type => $SIZING_GROW,
                        ),
                        border_config =>
                          border_all( 1, color( 150, 150, 150 ) ),
                    },
                    {
                        id            => 'feedback_area',
                        layout_config => Clay::Types::LayoutConfig->new(
                            sizing_width_type   => $SIZING_GROW,
                            sizing_height_type  => $SIZING_FIXED,
                            sizing_height_value => 5,
                            layout_direction    => $LEFT_TO_RIGHT,
                            child_gap           => 2,
                        ),
                        children => [
                            {
                                id            => 'combat_options',
                                layout_config => Clay::Types::LayoutConfig->new(
                                    sizing_width_type  => $SIZING_FIXED,
                                    sizing_width_value => 40,
                                    sizing_height_type => $SIZING_GROW,
                                ),
                                border_config =>
                                  border_all( 1, color( 100, 200, 100 ) ),
                            },
                            {
                                id            => 'ev_feedback',
                                layout_config => Clay::Types::LayoutConfig->new(
                                    sizing_width_type  => $SIZING_FIXED,
                                    sizing_width_value => 40,
                                    sizing_height_type => $SIZING_GROW,
                                ),
                                border_config =>
                                  border_all( 1, color( 200, 200, 100 ) ),
                            },
                        ],
                    },
                    {
                        id            => 'result',
                        layout_config => Clay::Types::LayoutConfig->new(
                            sizing_width_type   => $SIZING_GROW,
                            sizing_height_type  => $SIZING_FIXED,
                            sizing_height_value => 4,
                        ),
                        border_config =>
                          border_all( 1, color( 150, 150, 150 ) ),
                    },
                    {
                        id            => 'input',
                        layout_config => Clay::Types::LayoutConfig->new(
                            sizing_width_type   => $SIZING_GROW,
                            sizing_height_type  => $SIZING_FIXED,
                            sizing_height_value => 1,
                        ),
                    },
                ],
            }
        );
    }

    # ========================
    # Input Handling Methods
    # ========================

    # Get a single keystroke
    method read_key() {
        if ( $context->key_pressed() ) {
            return $context->get_key();
        }
        return '';
    }

    # Check if a key is pressed
    method key_pressed( $timeout = 0 ) {
        return $context->key_pressed($timeout);
    }

    # ========================
    # Color Handling Functions
    # ========================

    # Convert a color name to RGB values for Clay's color function
    # Renamed to get_color to avoid conflict with Clay's color function
    method get_color( $name = 'white' ) {

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

        # Return color using the Clay helper function
        return color( $rgb->[0], $rgb->[1], $rgb->[2] );
    }

    # ========================
    # Basic Drawing Functions
    # ========================

    # Clear the screen
    method clear() {
        $context->clear();
        return $self;
    }

    # Alias for compatibility with existing code
    method clear_screen() {
        return $self->clear();
    }

    # Refresh/render the screen
    method refresh() {
        if ( $context->layout() ) {
            $context->render();
        }
        return $self;
    }

    # Find an element by ID
    method find_element($id) {

        # Simple recursive finder function
        my $find_by_id = sub ( $elem, $search_id ) {
            return $elem if $elem->id eq $search_id;

            if ( $elem->children ) {
                for my $child ( $elem->children->@* ) {
                    my $found = __SUB__->( $child, $search_id );
                    return $found if $found;
                }
            }
            return undef;
        };

        return $find_by_id->( $root->element, $id );
    }

    # ==============================
    # Higher-Level Display Methods
    # ==============================

    # Display a header
    method display_header($text) {
        my $header_element = $self->find_element('header');
        if ($header_element) {
            $header_element->add_child(
                {
                    text => "=== $text ===",
                }
            );
        }
        $self->refresh();
        return $self;
    }

    # Display a title
    method display_title($title) {
        my $title_element = $self->find_element('title');
        if ($title_element) {
            $title_element->add_child( { text => $title } );
        }
        $self->refresh();
        return $self;
    }

    # Display text (compatibility method)
    method display_text( $text, $color = 'white' ) {

        # Add the text as a message
        $self->add_message( $text, 'info', $color );
        return $self;
    }

    # Display player stats
    method display_player($player) {
        return $self unless $player && ref $player eq 'HASH';

        my $player_element = $self->find_element('player');
        if ($player_element) {

            # Calculate HP percentage for color
            my $hp_percent =
              $player->{health}{current_hp} / $player->{health}{max_hp};
            my $hp_color =
              $hp_percent > 0.7
              ? color_green(1)
              : ( $hp_percent > 0.3 ? color_yellow(1) : color_red(1) );

            $player_element->add_child(
                {
                    layout_config => Clay::Types::LayoutConfig->new(
                        sizing_width_type  => $SIZING_GROW,
                        sizing_height_type => $SIZING_GROW,
                        layout_direction   => $TOP_TO_BOTTOM,
                        padding            => padding_all(1),
                        child_gap          => 1,
                    ),
                    children => [
                        {
                            text        => "Player: " . $player->{name},
                            text_config =>
                              text_config( color_white(1), { bold => 1 } ),
                        },
                        {
                            layout_config => Clay::Types::LayoutConfig->new(
                                sizing_width_type  => $SIZING_GROW,
                                sizing_height_type => $SIZING_FIT,
                                layout_direction   => $LEFT_TO_RIGHT,
                            ),
                            children => [
                                {
                                    text => "HP: ",
                                },
                                {
                                    text => $player->{health}{current_hp} . "/"
                                      . $player->{health}{max_hp},
                                }
                            ]
                        },
                        {
                                text => "ATK: "
                              . $player->{stats}{attack}
                              . " DEF: "
                              . $player->{stats}{defense},
                        }
                    ]
                }
            );
        }

        $self->refresh();
        return $self;
    }

    # Display enemy stats
    method display_enemy($enemy) {
        return $self unless $enemy && ref $enemy eq 'HASH';

        my $enemy_element = $self->find_element('enemy');
        if ($enemy_element) {

            # Calculate HP percentage for color
            my $hp_percent =
              $enemy->{health}{current_hp} / $enemy->{health}{max_hp};
            my $hp_color =
              $hp_percent > 0.7
              ? color_green(1)
              : ( $hp_percent > 0.3 ? color_yellow(1) : color_red(1) );

            $enemy_element->add_child(
                {
                    layout_config => Clay::Types::LayoutConfig->new(
                        sizing_width_type  => $SIZING_GROW,
                        sizing_height_type => $SIZING_GROW,
                        layout_direction   => $TOP_TO_BOTTOM,
                        padding            => padding_all(1),
                        child_gap          => 1,
                    ),
                    children => [
                        {
                            text        => "Enemy: " . $enemy->{name},
                            text_config =>
                              text_config( color_white(1), { bold => 1 } ),
                        },
                        {
                            layout_config => Clay::Types::LayoutConfig->new(
                                sizing_width_type  => $SIZING_GROW,
                                sizing_height_type => $SIZING_FIT,
                                layout_direction   => $LEFT_TO_RIGHT,
                            ),
                            children => [
                                {
                                    text        => "HP: ",
                                    text_config =>
                                      text_config( color_white(1) ),
                                },
                                {
                                    text => $enemy->{health}{current_hp} . "/"
                                      . $enemy->{health}{max_hp},
                                    text_config => text_config($hp_color),
                                }
                            ]
                        },
                        {
                            text => "ATK: "
                              . $enemy->{stats}{attack}
                              . " DEF: "
                              . $enemy->{stats}{defense},
                            text_config => text_config( color_white(1) ),
                        }
                    ]
                }
            );
        }

        $self->refresh();
        return $self;
    }

    # Display entity status (compatibility method)
    method display_entity_status($entity) {
        if ( $entity->{type} eq 'player' ) {
            return $self->display_player($entity);
        }
        else {
            return $self->display_enemy($entity);
        }
    }

    # Display combat status (player and enemy)
    method display_status( $player, $enemy ) {

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

    # Alias for display_text
    method display_message( $message, $color = 'white' ) {
        return $self->add_message( $message, 'info', $color );
    }

    # Display message history
    method display_message_history() {
        my $messages_element = $self->find_element('messages');
        if ($messages_element) {
            my @message_children = ();

            # Process from newest to oldest
            for ( my $i = $#$messages ; $i >= 0 ; $i-- ) {
                my $msg = $messages->[$i];

                # Format prefix based on message type
                my $prefix = '';

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
                }

                # Add count if more than 1
                my $count_suffix = $msg->{count} > 1 ? " (x$msg->{count})" : "";

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

                push @message_children, { text => $full_msg, };
            }

            $messages_element->add_child(
                {
                    layout_config => Clay::Types::LayoutConfig->new(
                        sizing_width_type  => $SIZING_GROW,
                        sizing_height_type => $SIZING_GROW,
                        layout_direction   => $TOP_TO_BOTTOM,
                        padding            => padding_all(1),
                        child_gap          => 0,
                    ),
                    children => \@message_children,
                }
            );
        }

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
        my $options_element = $self->find_element('combat_options');
        if ($options_element) {
            my @option_children = (
                {
                    text        => "Combat Options:",
                    text_config => text_config( color_white(1), { bold => 1 } ),
                }
            );

            # Display each option with its number
            for my $i ( 0 .. $#$options ) {
                push @option_children,
                  {
                    text        => ( $i + 1 ) . ". " . $options->[$i],
                    text_config => text_config( color_white(1) ),
                  };
            }

            $options_element->add_child(
                {
                    layout_config => Clay::Types::LayoutConfig->new(
                        sizing_width_type  => $SIZING_GROW,
                        sizing_height_type => $SIZING_GROW,
                        layout_direction   => $TOP_TO_BOTTOM,
                        padding            => padding_all(1),
                        child_gap          => 1,
                    ),
                    children => \@option_children,
                }
            );
        }

        $self->refresh();
        return $self;
    }

    # Get combat action from player
    method get_combat_action() {
        my @options = ( 'attack', 'defend', 'help', 'quit' );

        # Display options
        $self->display_combat_options( \@options );

        # Add the input prompt at the bottom
        my $input_element = $self->find_element('input');
        if ($input_element) {
            $input_element->add_child(
                {
                    text        => "Enter your choice (or first letter): ",
                    text_config => text_config( color_white(1) ),
                }
            );
        }

        $self->refresh();

        # Get player input
        my $input;
        while ( !$input ) {
            if ( $self->key_pressed() ) {
                $input = $self->read_key();
            }
            select( undef, undef, undef, 0.05 );    # Small delay
        }

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
        my $result_element = $self->find_element('result');
        if ($result_element) {

            # Display action and result
            my $ev_score = $result->{ev_score};
            my $ev_color =
              $ev_score > 0.7
              ? color_green(1)
              : ( $ev_score > 0.3 ? color_yellow(1) : color_red(1) );

            my $success_text;
            my $success_color;
            if ( $result->{success} ) {
                $success_text  = "Success! Damage dealt: " . $result->{damage};
                $success_color = color_green(1);
            }
            else {
                $success_text  = "Failed!";
                $success_color = color_red(1);
            }

            $result_element->add_child(
                {
                    layout_config => Clay::Types::LayoutConfig->new(
                        sizing_width_type  => $SIZING_GROW,
                        sizing_height_type => $SIZING_GROW,
                        layout_direction   => $TOP_TO_BOTTOM,
                        padding            => padding_all(1),
                        child_gap          => 1,
                    ),
                    children => [
                        {
                            text        => "ACTION RESULT",
                            text_config =>
                              text_config( color_white(1), { bold => 1 } ),
                        },
                        {
                            text        => "Action: " . $result->{action},
                            text_config => text_config( color_white(1) ),
                        },
                        {
                            text        => $success_text,
                            text_config => text_config($success_color),
                        },
                        {
                            text        => "EV Score: " . $ev_score,
                            text_config => text_config($ev_color),
                        }
                    ]
                }
            );
        }

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
        my $feedback_element = $self->find_element('ev_feedback');
        if ($feedback_element) {
            my @feedback_children = (
                {
                    text        => "AI COACH FEEDBACK",
                    text_config => text_config( color_white(1), { bold => 1 } ),
                }
            );

            # Add each feedback item
            for my $i ( 0 .. $#$feedback ) {
                push @feedback_children,
                  {
                    text        => "* " . $feedback->[$i],
                    text_config => text_config( color_cyan(1) ),
                  };
            }

            $feedback_element->add_child(
                {
                    layout_config => Clay::Types::LayoutConfig->new(
                        sizing_width_type  => $SIZING_GROW,
                        sizing_height_type => $SIZING_GROW,
                        layout_direction   => $TOP_TO_BOTTOM,
                        padding            => padding_all(1),
                        child_gap          => 1,
                    ),
                    children => \@feedback_children,
                }
            );
        }

        # Also add each feedback item as a separate message
        for my $comment (@$feedback) {
            $self->add_ev_message( $comment, 'cyan' );
        }

        $self->refresh();
        return $self;
    }

    # Get generic input from user
    method get_input( $options = undef ) {
        my $input_element = $self->find_element('input');
        if ($input_element) {
            if ( defined $options ) {    # Options mode - display prompt
                $input_element->add_child(
                    {
                        text => "Enter your choice (1-"
                          . scalar(@$options) . "): ",
                        text_config => text_config( color_white(1) ),
                    }
                );
            }
            else {
                # Any key mode
                $input_element->add_child(
                    {
                        text        => "Press any key to continue...",
                        text_config => text_config( color_white(1) ),
                    }
                );
            }
        }

        $self->refresh();

        # Get input
        my $input;
        while ( !$input ) {
            if ( $self->key_pressed() ) {
                $input = $self->read_key();
            }
            select( undef, undef, undef, 0.05 );    # Small delay
        }

        if ( defined $options ) {

            # Process numeric choice
            if ( $input =~ /^\d+$/ ) {
                my $index = $input - 1;
                if ( $index >= 0 && $index <= $#$options ) {
                    return $options->[$index];
                }
            }

            # Handle special keys
            if ( $input eq 'q' || $input eq 'Q' ) {
                die "User quit the game";
            }

            # Default to first option on invalid input
            return $options->[0];
        }

        return $input;
    }

    # Prompt user to continue
    method prompt_continue() {
        return $self->get_input();
    }

    # Clean up and reset terminal
    method cleanup() {
        $self->clear();
        $self->refresh();
        return $self;
    }
}

1;
