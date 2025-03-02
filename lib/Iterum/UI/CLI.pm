use 5.40.0;

package Iterum::UI::CLI;

use experimental 'class';
use Term::Screen;
use Term::ANSIColor;

class Iterum::UI::CLI {
    my sub optionally_load_screen($test_mode) {
        return if $test_mode;

        # Term::Screen object for terminal operations
        return Term::Screen->new() // die "Could not initialize Term::Screen";
    }

    # Fields
    field $test_mode :param = 0;    # Flag for test mode (no actual display)
    field $screen     = optionally_load_screen($test_mode);    # Screen object
    field $test_input = '';    # Input to use in test mode
    field $width      = 80;    # Terminal width
    field $height     = 24;    # Terminal height

    # Constructor
    ADJUST {
        unless ($test_mode) {
            $screen->clrscr();

            # Get terminal dimensions
            ( $height, $width ) = ( $screen->rows, $screen->cols );
        }
    }

    # Test mode methods
    method set_test_input($input) {
        die "Not in test mode" unless $test_mode;
        $test_input = $input;
    }

    # Utility methods
    method clear_screen() {
        return if $test_mode;
        $screen->clrscr();
    }

    method colored_puts( $text, $color = '' ) {
        return if $test_mode;

        if ($color) {
            my $colored_text = colored( [$color], $text );
            $screen->puts($colored_text);
        }
        else {
            $screen->puts($text);
        }
    }

    method display_header($text) {
        return if $test_mode;

        $screen->at( 0, 0 );
        $screen->bold();
        $screen->puts("=== $text ");
        $screen->puts( "=" x ( $width - length($text) - 5 ) );
        $screen->normal();
    }

    # Display methods
    method display_status( $player, $enemy ) {
        return 1 if $test_mode;

        # Clear the screen
        $self->clear_screen();

        # Display header
        $self->display_header("ITERUM - COMBAT");

        # Display player status
        $screen->at( 2, 0 );
        $screen->bold();
        $screen->puts( "Player: " . $player->{name} );
        $screen->normal();

        $screen->at( 3, 2 );
        my $hp_percent =
          $player->{health}{current_hp} / $player->{health}{max_hp};
        my $hp_color =
          $hp_percent > 0.7
          ? 'green'
          : ( $hp_percent > 0.3 ? 'yellow' : 'red' );

        $screen->puts("HP: ");
        $self->colored_puts(
            $player->{health}{current_hp} . "/" . $player->{health}{max_hp},
            $hp_color );

        $screen->at( 4, 2 );
        $screen->puts( "ATK: "
              . $player->{stats}{attack}
              . " DEF: "
              . $player->{stats}{defense} );

        # Display enemy status
        $screen->at( 2, $width - 30 );
        $screen->bold();
        $screen->puts( "Enemy: " . $enemy->{name} );
        $screen->normal();

        $screen->at( 3, $width - 28 );
        $hp_percent = $enemy->{health}{current_hp} / $enemy->{health}{max_hp};
        $hp_color =
          $hp_percent > 0.7
          ? 'green'
          : ( $hp_percent > 0.3 ? 'yellow' : 'red' );

        $screen->puts("HP: ");
        $self->colored_puts(
            $enemy->{health}{current_hp} . "/" . $enemy->{health}{max_hp},
            $hp_color );

        $screen->at( 4, $width - 28 );
        $screen->puts( "ATK: "
              . $enemy->{stats}{attack}
              . " DEF: "
              . $enemy->{stats}{defense} );

        return 1;
    }

    method display_combat_options($options) {
        return 1 if $test_mode;

        $screen->at( 6, 0 );
        $screen->bold();
        $screen->puts("Combat Options:");
        $screen->normal();

        for my $i ( 0 .. $options->$#* ) {
            $screen->at( 7 + $i, 2 );
            $screen->puts( ( $i + 1 ) . ". " . $options->[$i] );
        }

        return 1;
    }

    method display_result($result) {
        return 1 if $test_mode;

        $screen->at( 13, 0 );
        $screen->bold();
        $screen->puts("Result:");
        $screen->normal();

        $screen->at( 14, 2 );
        $screen->puts( "Action: " . $result->{action} );

        $screen->at( 15, 2 );
        if ( $result->{success} ) {
            $self->colored_puts( "Success! ", 'green' );
            $screen->puts( "Damage dealt: " . $result->{damage} );
        }
        else {
            $self->colored_puts( "Failed!", 'red' );
        }

        $screen->at( 16, 2 );
        my $ev_score = $result->{ev_score};
        my $ev_color =
          $ev_score > 0.7 ? 'green' : ( $ev_score > 0.3 ? 'yellow' : 'red' );

        $screen->puts("EV Score: ");
        $self->colored_puts( $ev_score, $ev_color );

        return 1;
    }

    method display_ev_feedback($feedback) {
        return 1 if $test_mode;

        $screen->at( 18, 0 );
        $screen->bold();
        $screen->puts("AI Coach Feedback:");
        $screen->normal();

        my $line = 19;
        for my $comment (@$feedback) {
            $screen->at( $line++, 2 );
            $screen->puts($comment);
        }

        return 1;
    }

    method display_decision_history($history) {
        return 1 if $test_mode;

        # Clear the screen
        $self->clear_screen();

        # Display header
        $self->display_header("ITERUM - DECISION HISTORY");

        $screen->at( 2, 0 );
        $screen->bold();
        $screen->puts("Your Past Decisions:");
        $screen->normal();

        $screen->at( 3, 0 );
        $screen->puts( "-" x $width );

        $screen->at( 4, 0 );
        $screen->puts(
            sprintf(
                "%-20s %-15s %-15s %-15s",
                "Action", "Result", "EV Score", "Optimal EV"
            )
        );

        $screen->at( 5, 0 );
        $screen->puts( "-" x $width );

        my $line = 6;
        for my $decision (@$history) {
            $screen->at( $line, 0 );

            my $ev_score = $decision->{ev_score};
            my $ev_color =
              $ev_score > 0.7
              ? 'green'
              : ( $ev_score > 0.3 ? 'yellow' : 'red' );

            $screen->puts(
                sprintf( "%-20s %-15s ",
                    $decision->{action},
                    $decision->{success} ? "Success" : "Failed" )
            );

            $self->colored_puts( sprintf( "%-15s", $ev_score ), $ev_color );

            $screen->puts( sprintf( "%-15s", $decision->{optimal_ev} ) );

            $line++;
        }

        $screen->at( $height - 1, 0 );
        $screen->puts("Press any key to continue...");
        $screen->getch() unless $test_mode;

        return 1;
    }

    # Input methods
    method get_input($options = undef) {
        if ($test_mode) {
            # In test mode, return the predefined input or empty string
            if (defined $options) {
                # Options mode
                my $input = $test_input;
                
                # Validate input
                if ($input !~ /^\d+$/) {
                    die "Invalid input: not a number";
                }
                
                my $index = $input - 1;
                if ($index < 0 || $index > $options->$#*) {
                    die "Invalid input: out of range";
                }
                
                return $options->[$index];
            } else {
                # Key press mode
                return $test_input || '';
            }
        }
        
        if (defined $options) {
            # Options mode
            $screen->at($height - 3, 0);
            $screen->puts("Enter your choice (1-" . scalar(@$options) . "): ");
            
            my $input;
            my $valid = 0;
            
            while (!$valid) {
                $input = $screen->getch();
                
                # Handle special keys
                if ($input eq 'q' || $input eq 'Q') {
                    die "User quit the game";
                }
                
                # Clear previous error message
                $screen->at($height - 2, 0);
                $screen->puts(" " x $width);
                
                # Validate input
                if ($input !~ /^\d+$/) {
                    $screen->at($height - 2, 0);
                    $self->colored_puts("Invalid input. Please enter a number.", 'red');
                    $screen->at($height - 3, 32);
                    next;
                }
                
                my $index = $input - 1;
                if ($index < 0 || $index > $options->$#*) {
                    $screen->at($height - 2, 0);
                    $self->colored_puts(
                        "Invalid choice. Please choose 1-" . scalar(@$options) . ".",
                        'red'
                    );
                    $screen->at($height - 3, 32);
                    next;
                }
                
                $valid = 1;
                return $options->[$index];
            }
        } else {
            # Any key press mode - just wait for any key
            return $screen->getch();
        }
    }

    method prompt_continue() {
        return if $test_mode;

        $screen->at( $height - 1, 0 );
        $screen->puts("Press any key to continue...");
        $screen->getch();
    }

    method display_message( $message, $color = '' ) {
        return if $test_mode;

        $screen->at( $height - 2, 0 );
        $self->colored_puts( $message, $color );
    }
    
    # Display a title
    method display_title($title) {
        return if $test_mode;
        
        my $padding = int(($width - length($title)) / 2);
        $screen->at(1, $padding);
        $screen->bold();
        $screen->puts($title);
        $screen->normal();
        $screen->at(2, 0);
    }

    # Display text with wrapping
    method display_text($text) {
        return if $test_mode;
        
        # Start at current line, track position manually
        my $row = 2; # Start after title
        my $col = 0;
        
        # Simple word wrapping
        my @words = split(/\s+/, $text);
        my $line = "";
        
        foreach my $word (@words) {
            if (length($line) + length($word) + 1 > $width) {
                $screen->at($row, $col);
                $screen->puts($line);
                $line = $word;
                $row++;
            } else {
                $line .= ($line eq "" ? "" : " ") . $word;
            }
        }
        
        # Output the last line
        if ($line ne "") {
            $screen->at($row, $col);
            $screen->puts($line);
            $row++;
        }
        
        # Update cursor position
        $screen->at($row + 1, 0);
        return $row + 1; # Return next row position
    }

    # Display player or enemy status
    method display_entity_status($entity) {
        return if $test_mode;
        
        # Use current row or start after the previous content
        my $row = 6; # Start after title and text
        
        $screen->at($row, 0);
        $screen->bold();
        $screen->puts($entity->{name});
        $screen->normal();
        
        $screen->at($row + 1, 2);
        my $hp_percent = $entity->{health}{current_hp} / $entity->{health}{max_hp};
        my $hp_color = $hp_percent > 0.7 ? 'green' : ($hp_percent > 0.3 ? 'yellow' : 'red');
        
        $screen->puts("HP: ");
        $self->colored_puts($entity->{health}{current_hp} . "/" . $entity->{health}{max_hp}, $hp_color);
        
        $screen->at($row + 2, 2);
        $screen->puts("ATK: " . $entity->{stats}{attack} . " DEF: " . $entity->{stats}{defense});
        
        # Update cursor position
        $screen->at($row + 3, 0);
        return $row + 3; # Return next row position
    }

    # Get combat action from player
    method get_combat_action() {
        my @options = ('attack', 'defend', 'help', 'quit');
        
        if ($test_mode) {
            # In test mode, process the input to mimic real behavior
            my $input = $test_input;
            
            # Handle first letter shortcuts
            if ($input =~ /^[adqh]$/i) {
                if ($input =~ /^a$/i) { return 'attack'; }
                if ($input =~ /^d$/i) { return 'defend'; }
                if ($input =~ /^q$/i) { return 'quit'; }
                if ($input =~ /^h$/i) { return 'help'; }
            }
            
            # Handle numeric choice
            if ($input =~ /^[1-4]$/) {
                return $options[$input - 1];
            }
            
            # Invalid input, return default
            return 'attack';
        }
        
        # Display options
        $screen->at($height - 5, 0);
        $screen->bold();
        $screen->puts("Combat Options:");
        $screen->normal();
        
        for my $i (0 .. $#options) {
            $screen->at($height - 4 + $i, 2);
            $screen->puts(($i + 1) . ". " . $options[$i]);
        }
        
        $screen->at($height - 2, 0);
        $screen->puts("Enter your choice (or first letter): ");
        
        my $input = $screen->getch();
        
        # Handle first letter shortcuts
        if ($input =~ /^[adqh]$/i) {
            if ($input =~ /^a$/i) { return 'attack'; }
            if ($input =~ /^d$/i) { return 'defend'; }
            if ($input =~ /^q$/i) { return 'quit'; }
            if ($input =~ /^h$/i) { return 'help'; }
        }
        
        # Handle numeric choice
        if ($input =~ /^[1-4]$/) {
            return $options[$input - 1];
        }
        
        # Invalid input, return default
        return 'attack';
    }

    # Display EV score summary
    method display_score_summary($summary) {
        return if $test_mode;
        
        # Start at a reasonable position
        my $row = 12; # After entity status displays
        
        $screen->at($row, 0);
        $screen->bold();
        $screen->puts("EV Score Summary:");
        $screen->normal();
        
        $screen->at(++$row, 2);
        $screen->puts("Total Score: " . $summary->{total_score});
        
        $screen->at(++$row, 2);
        $screen->puts("Best Decision: " . $summary->{best_decision});
        
        $screen->at(++$row, 2);
        $screen->puts("Worst Decision: " . $summary->{worst_decision});
        
        # Update cursor position
        $screen->at($row + 1, 0);
        return $row + 1; # Return next row position
    }

    # Clean up and reset terminal
    method cleanup() {
        return if $test_mode;
        
        $screen->at($height - 1, 0);
        $screen->clreos(); # Clear to end of screen
        $screen->normal(); # Reset formatting
    }
}

1;
