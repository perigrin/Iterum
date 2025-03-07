use 5.40.0;
use utf8;
use experimental 'class';

# GameScreens module for Iterum roguelike
# Provides enhanced game screens using the Clay renderer

class Iterum::UI::GameScreens {
    
    field $cli :param :reader;  # CLI instance for rendering
    
    # ASCII art logo for the game
    my $logo = q{
    _____________  ___________ ____ ___   _____ 
    \_   ___ \   \/  |_   ___ \|    |   | /     \  
    /    \  \/\     /    \  \/|    |   |/  \ /  \ 
    \     \____/     \     \___|    |  /    Y    \
     \______  /___/\  \______  /______/\____|__  /
            \/      \_/      \/                \/ 
    };
    
    # ASCII art for game over screen
    my $game_over = q{
     _______  _______  _______  _______    _______  _______  _______  _______ 
    |       ||   _   ||       ||       |  |       ||       ||       ||       |
    |    ___||  |_|  ||    ___||    ___| |   _   ||    ___| |   _   |  |    |
    |   | __ |       ||   |___ |   |___  |  | |  ||   |      |  | |  |  |    |
    |   ||  ||       ||    ___||    ___| |  |_|  ||   |      |  |_|  |  |    |
    |   |_| ||   _   ||   |    |   |___  |       ||   |___   |       |  |    |
    |_______||__| |__||___|    |_______| |_______||_______||_________|  |____|
    };
    
    # ASCII art for victory screen
    my $victory = q{
    __     __  ____    ____  ________   ______    _______   __      __
    |  \   |  \|    \  /    \|        \ /      \  |       \ |  \    /  \
    | $$   | $$| $$$$\|  $$$$\\$$$$$$$$|  $$$$$$\ | $$$$$$$\| $$\  /  $$
    | $$   | $$| $$ $$ $$ | $$ | $$   | $$  | $$ | $$__| $$| $$$\/$$$$ 
     \$$\ /  $$| $$  \$$  | $$ | $$   | $$  | $$ | $$    $$| $$  $$ $$ 
      \$$\  $$ | $$   $$/  $$ | $$   | $$  | $$ | $$$$$$$\| $$      $$
       \$$ $$  | $$  / $$/ $$ | $$   | $$__/ $$ | $$  | $$| $$      $$
        \$$$   | $$ /  $$/  $$ | $$    \$$    $$ | $$  | $$| $$      $$
         \$     \$$ |_  $$/   $$ \$$     \$$$$$$  \$$   \$$ \$$      \$$
    };
    
    # ==========================================
    # Helper Methods for Screen Rendering
    # ==========================================
    
    # Draw a decorative frame
    method _draw_frame($title) {
        # Clear the screen first
        $cli->clear();
        
        # Create a border around the entire screen
        $cli->draw_box('root', 'double', $title);
        
        return $self;
    }
    
    # Display centered text
    method _centered_text($text, $y_offset = 0, $color = 'white', $bold = 0) {
        # Get dimensions of the root element to center within
        my $bounds = $cli->get_element_bounds('root');
        return $self unless $bounds;
        
        # Calculate centering
        my $width = $bounds->{width};
        my $x_padding = int(($width - length($text)) / 2);
        $x_padding = 2 if $x_padding < 2;
        
        # Add the text
        $cli->add_text_to_element('root', $x_padding, 4 + $y_offset, $text, $color, $bold);
        
        return $self;
    }
    
    # Display multi-line centered ASCII art
    method _display_ascii_art($art, $y_offset = 0, $color = 'cyan') {
        my @lines = split /\n/, $art;
        
        # Get dimensions of the root element to center within
        my $bounds = $cli->get_element_bounds('root');
        return $self unless $bounds;
        
        # Find the longest line for centering
        my $max_length = 0;
        for my $line (@lines) {
            $max_length = length($line) if length($line) > $max_length;
        }
        
        # Display each line centered
        my $current_y = $y_offset;
        for my $line (@lines) {
            next unless length($line) > 0; # Skip empty lines
            
            # Calculate centering for this specific line
            my $x_padding = int(($bounds->{width} - length($line)) / 2);
            $x_padding = 2 if $x_padding < 2;
            
            # Add the text
            $cli->add_text_to_element('root', $x_padding, 4 + $current_y, $line, $color, 1);
            $current_y++;
        }
        
        return $current_y; # Return the next available Y position
    }
    
    # ==========================================
    # Main Screen Methods
    # ==========================================
    
    # Display the start screen
    method display_start_screen($version = '1.0.0') {
        # Draw the frame
        $self->_draw_frame("ITERUM");
        
        # Display logo
        my $next_y = $self->_display_ascii_art($logo, 0, 'green');
        
        # Add spacing
        $next_y += 1;
        
        # Display game information
        $self->_centered_text("An EV-Based Decision Roguelike", $next_y, 'white', 1);
        $self->_centered_text("Version $version", $next_y + 1, 'white', 1);
        $self->_centered_text("", $next_y + 2);
        $self->_centered_text("In this game, your decisions are evaluated based on", $next_y + 3);
        $self->_centered_text("Expected Value (EV) rather than outcomes.", $next_y + 4);
        $self->_centered_text("", $next_y + 5);
        $self->_centered_text("Controls:", $next_y + 6, 'yellow', 1);
        $self->_centered_text("[a] Attack  [d] Defend  [i] Use Item  [f] Flee", $next_y + 7, 'cyan');
        $self->_centered_text("", $next_y + 8);
        $self->_centered_text("Press any key to begin your adventure...", $next_y + 9, 'green');
        
        # Render the screen
        $cli->refresh();
        
        # Wait for input
        $cli->read_key();
        
        return $self;
    }
    
    # Display help screen
    method display_help_screen() {
        # Draw the frame
        $self->_draw_frame("HELP");
        
        # Display help content
        $self->_centered_text("GAME CONCEPTS", 0, 'yellow', 1);
        $self->_centered_text("", 1);
        $self->_centered_text("Expected Value (EV)", 2, 'cyan', 1);
        $self->_centered_text("Each decision has an expected value based on risk/reward.", 3);
        $self->_centered_text("Higher EV scores mean better decisions, regardless of outcome.", 4);
        $self->_centered_text("", 5);
        $self->_centered_text("AI Coach", 6, 'cyan', 1);
        $self->_centered_text("An AI coach analyzes your decisions and provides feedback.", 7);
        $self->_centered_text("It looks for patterns in your decision-making.", 8);
        $self->_centered_text("", 9);
        $self->_centered_text("Enemy Types", 10, 'cyan', 1);
        $self->_centered_text("Goblin: Aggressive, always attacks.", 11);
        $self->_centered_text("Giant Rat: Cautious, attacks when you're weakened.", 12);
        $self->_centered_text("", 13);
        $self->_centered_text("COMMANDS", 14, 'yellow', 1);
        $self->_centered_text("", 15);
        $self->_centered_text("[a] Attack: High EV when enemy is weak or you're strong", 16);
        $self->_centered_text("[d] Defend: High EV when low on health or enemy is strong", 17);
        $self->_centered_text("[i] Use Item: High EV in the right situation", 18);
        $self->_centered_text("[f] Flee: High EV when severely outmatched", 19);
        $self->_centered_text("[h] Help: Display this screen", 20);
        $self->_centered_text("[q] Quit: Exit the game", 21);
        $self->_centered_text("", 22);
        $self->_centered_text("Press any key to return...", 23, 'green');
        
        # Render the screen
        $cli->refresh();
        
        # Wait for input
        $cli->read_key();
        
        return $self;
    }
    
    # Display the victory screen with EV analysis
    method display_victory_screen($player_status, $enemy_name, $ev_system) {
        # Draw the frame
        $self->_draw_frame("VICTORY");
        
        # Display victory art
        my $next_y = $self->_display_ascii_art($victory, 0, 'yellow');
        
        # Add spacing
        $next_y += 1;
        
        # Display victory message
        $self->_centered_text("You have defeated the $enemy_name!", $next_y, 'green', 1);
        
        # Display HP stats
        my $hp_remaining = int(($player_status->{health}{current_hp} / $player_status->{health}{max_hp}) * 100);
        $self->_centered_text("HP Remaining: $hp_remaining%", $next_y + 1, 'cyan');
        
        # Display EV analysis
        $self->_centered_text("", $next_y + 2);
        $self->_centered_text("EV ANALYSIS", $next_y + 3, 'yellow', 1);
        
        my $stats = $ev_system->get_decision_stats($player_status->{id});
        my $avg_score = $stats->{overall_avg} // 0;
        
        my $score_color = 'red';
        $score_color = 'yellow' if $avg_score >= 40;
        $score_color = 'green' if $avg_score >= 70;
        
        $self->_centered_text("Overall EV Score: $avg_score", $next_y + 4, $score_color, 1);
        
        # Display decision breakdown
        my $decisions = $stats->{decisions} // [];
        my %action_counts;
        for my $decision (@$decisions) {
            $action_counts{$decision->{action}}++;
        }
        
        $self->_centered_text("", $next_y + 5);
        $self->_centered_text("Decision Breakdown:", $next_y + 6, 'white', 1);
        
        my $breakdown_y = $next_y + 7;
        for my $action (sort keys %action_counts) {
            $self->_centered_text("$action: $action_counts{$action} times", $breakdown_y);
            $breakdown_y++;
        }
        
        # Display AI coach feedback
        $self->_centered_text("", $breakdown_y + 1);
        $self->_centered_text("AI COACH FEEDBACK", $breakdown_y + 2, 'yellow', 1);
        my $feedback = $ev_system->generate_feedback($player_status->{id});
        $self->_centered_text($feedback, $breakdown_y + 3, 'cyan');
        
        $self->_centered_text("", $breakdown_y + 4);
        $self->_centered_text("Press any key to continue...", $breakdown_y + 5, 'green');
        
        # Render the screen
        $cli->refresh();
        
        # Wait for input
        $cli->read_key();
        
        return $self;
    }
    
    # Display the defeat screen with EV analysis
    method display_defeat_screen($player_status, $enemy_name, $ev_system) {
        # Draw the frame
        $self->_draw_frame("DEFEAT");
        
        # Display defeat art
        my $next_y = $self->_display_ascii_art($game_over, 0, 'red');
        
        # Add spacing
        $next_y += 1;
        
        # Display defeat message
        $self->_centered_text("You have been defeated by the $enemy_name!", $next_y, 'red', 1);
        
        # Display EV analysis
        $self->_centered_text("", $next_y + 1);
        $self->_centered_text("EV ANALYSIS", $next_y + 2, 'yellow', 1);
        
        my $stats = $ev_system->get_decision_stats($player_status->{id});
        my $avg_score = $stats->{overall_avg} // 0;
        
        my $score_color = 'red';
        $score_color = 'yellow' if $avg_score >= 40;
        $score_color = 'green' if $avg_score >= 70;
        
        $self->_centered_text("Overall EV Score: $avg_score", $next_y + 3, $score_color, 1);
        
        # Display decision breakdown
        my $decisions = $stats->{decisions} // [];
        my %action_counts;
        for my $decision (@$decisions) {
            $action_counts{$decision->{action}}++;
        }
        
        $self->_centered_text("", $next_y + 4);
        $self->_centered_text("Decision Breakdown:", $next_y + 5, 'white', 1);
        
        my $breakdown_y = $next_y + 6;
        for my $action (sort keys %action_counts) {
            $self->_centered_text("$action: $action_counts{$action} times", $breakdown_y);
            $breakdown_y++;
        }
        
        # Display AI coach feedback
        $self->_centered_text("", $breakdown_y + 1);
        $self->_centered_text("AI COACH FEEDBACK", $breakdown_y + 2, 'yellow', 1);
        my $feedback = $ev_system->generate_feedback($player_status->{id});
        $self->_centered_text($feedback, $breakdown_y + 3, 'cyan');
        
        $self->_centered_text("", $breakdown_y + 4);
        $self->_centered_text("Even when defeated, the value of your decisions matters.", $breakdown_y + 5);
        $self->_centered_text("Press any key to continue...", $breakdown_y + 6, 'green');
        
        # Render the screen
        $cli->refresh();
        
        # Wait for input
        $cli->read_key();
        
        return $self;
    }
    
    # Display game credits
    method display_credits() {
        # Draw the frame
        $self->_draw_frame("CREDITS");
        
        # Display credits content
        $self->_centered_text("ITERUM", 0, 'yellow', 1);
        $self->_centered_text("An EV-Based Decision Roguelike", 1, 'cyan');
        $self->_centered_text("", 2);
        $self->_centered_text("Design & Development", 3, 'white', 1);
        $self->_centered_text("7 Day Roguelike Challenge Team", 4);
        $self->_centered_text("", 5);
        $self->_centered_text("Architecture", 6, 'white', 1);
        $self->_centered_text("Entity Component System (ECS)", 7);
        $self->_centered_text("", 8);
        $self->_centered_text("Special Thanks", 9, 'white', 1);
        $self->_centered_text("Test2::V0 team for the test framework", 10);
        $self->_centered_text("Clay for UI rendering", 11);
        $self->_centered_text("EV concepts inspired by strategic games", 12);
        $self->_centered_text("", 13);
        $self->_centered_text("Press any key to return...", 14, 'green');
        
        # Render the screen
        $cli->refresh();
        
        # Wait for input
        $cli->read_key();
        
        return $self;
    }
    
    # Display the EV stats during gameplay
    method display_ev_stats($player_id, $ev_system) {
        # Get the stats from the EV system
        my $stats = $ev_system->get_decision_stats($player_id);
        my $avg_score = $stats->{overall_avg} // 0;
        
        # Create a region for the EV stats if it doesn't exist
        # (This would typically be part of the main UI layout)
        my $bounds = $cli->get_element_bounds('root');
        return $self unless $bounds;
        
        # Create a box at the bottom of the screen
        my $box_width = $bounds->{width} - 4;
        my $box_height = 3;
        my $box_x = 2;
        my $box_y = $bounds->{height} - $box_height - 2;
        
        # Add a box with the EV score
        $cli->fill_rect($box_x, $box_y, $box_width, $box_height, 'black');
        $cli->add_commands([{
            type => 'border',
            rect => Clay::Types::Rect->new(
                x => $box_x,
                y => $box_y,
                width => $box_width,
                height => $box_height
            ),
            config => Clay::Types::BorderConfig->new(
                width_top => 1,
                width_right => 1,
                width_bottom => 1,
                width_left => 1,
                color => $cli->color('white'),
            ),
            z_index => 1,
        }]);
        
        # Display the EV score centered in the box
        my $score_text = "EV Score: $avg_score";
        my $x_padding = int(($box_width - length($score_text)) / 2);
        $cli->add_text($box_y + 1, $box_x + $x_padding, $score_text);
        
        # Render the changes
        $cli->refresh();
        
        return $self;
    }
    
    # Play again prompt
    method play_again_prompt() {
        # Draw the frame
        $self->_draw_frame("GAME OVER");
        
        # Display prompt
        $self->_centered_text("", 0);
        $self->_centered_text("Would you like to play again?", 1, 'yellow', 1);
        $self->_centered_text("", 2);
        $self->_centered_text("[y] Yes - Start a new adventure", 3, 'green');
        $self->_centered_text("[n] No - Exit to the main menu", 4, 'red');
        $self->_centered_text("[c] Credits - View game credits", 5, 'cyan');
        $self->_centered_text("", 6);
        
        # Render the screen
        $cli->refresh();
        
        # Get user input
        my $input = $cli->read_key();
        
        return $input;
    }
}

1;
