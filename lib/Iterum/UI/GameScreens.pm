use 5.40.0;
use utf8;
use experimental 'class';

# GameScreens module for Iterum roguelike
# Provides enhanced start and end game screens

class Iterum::UI::GameScreens {
    use Term::ANSIColor;
    
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
    
    # Get buffer via CLI - using proper accessor
    method _buffer() {
        # Access the buffer through the CLI's buffer() method
        return $cli->buffer();
    }
    
    # Display a decorative frame
    method _frame($title) {
        my $buffer = $self->_buffer();
        my $term_width = $cli->width;
        my $horizontal_line = '═' x ($term_width - 4);
        my $title_line = '═' x (($term_width - length($title) - 8) / 2);
        
        # Draw top border
        $buffer->draw_box(0, 0, $term_width, $cli->height, 'double');
        
        # Create title bar
        my $title_bar = " $title_line [ $title ] $title_line";
        if (length($title_line) * 2 + length($title) + 8 < $term_width - 4) {
            $title_bar .= "═";
        }
        
        $buffer->put_string(2, 2, $title_bar);
        $buffer->refresh();
    }
    
    # Close the decorative frame (now handled by the buffer's box drawing)
    method _close_frame() {
        $self->_buffer()->refresh();
    }

    # Display centered text
    method _centered_text($text, $color = 'white') {
        my $buffer = $self->_buffer();
        my $term_width = $cli->width;
        my $padding = int(($term_width - length($text) - 4) / 2);
        $padding = 0 if $padding < 0;
        
        my $y = $buffer->cy();
        $buffer->put_string($y, $padding + 2, $text, $self->_get_attrs_for_color($color));
        $buffer->at($y + 1, 0); # Move to next line
    }
    
    # Helper to convert color names to attribute hash
    method _get_attrs_for_color($color) {
        my %attrs;
        
        if ($color =~ /bright_/) {
            $attrs{bold} = 1;
            $color =~ s/bright_//;
        }
        
        # More color handling can be added here
        
        return \%attrs;
    }
    
    # Display multi-line centered ASCII art
    method _display_ascii_art($art, $color = 'bright_cyan') {
        my $buffer = $self->_buffer();
        my @lines = split /\n/, $art;
        my $max_length = 0;
        
        # Find the longest line
        for my $line (@lines) {
            $max_length = length($line) if length($line) > $max_length;
        }
        
        my $term_width = $cli->width;
        my $current_y = $buffer->cy();
        
        for my $line (@lines) {
            next unless length($line) > 0; # Skip empty lines
            
            my $padding = int(($term_width - length($line) - 4) / 2);
            $padding = 1 if $padding < 1;
            
            $buffer->put_string($current_y, $padding + 2, $line, 
                $self->_get_attrs_for_color($color));
            $current_y++;
        }
        
        $buffer->at($current_y + 1, 0);
    }
    
    # Display the start screen
    method display_start_screen($version = '1.0.0') {
        my $buffer = $self->_buffer();
        
        $cli->clear_screen();
        $self->_frame("ITERUM");
        
        $buffer->at(4, 0);
        $self->_display_ascii_art($logo, 'bright_green');
        
        $buffer->at($buffer->cy() + 1, 0);
        $self->_centered_text("", 'bright_white');
        $self->_centered_text("An EV-Based Decision Roguelike", 'bright_white');
        $self->_centered_text("Version $version", 'bright_white');
        $self->_centered_text("", 'bright_white');
        $self->_centered_text("In this game, your decisions are evaluated based on", 'white');
        $self->_centered_text("Expected Value (EV) rather than outcomes.", 'white');
        $self->_centered_text("", 'bright_white');
        $self->_centered_text("Controls:", 'bright_yellow');
        $self->_centered_text("[a] Attack  [d] Defend  [i] Use Item  [f] Flee", 'bright_cyan');
        $self->_centered_text("", 'bright_white');
        $self->_centered_text("Press any key to begin your adventure...", 'bright_green');
        
        $buffer->refresh();
        $cli->get_input();
        return 1;
    }
    
    # Display help screen
    method display_help_screen() {
        my $buffer = $self->_buffer();
        
        $cli->clear_screen();
        $self->_frame("HELP");
        
        $buffer->at(4, 0);
        $self->_centered_text("GAME CONCEPTS", 'bright_yellow');
        $self->_centered_text("", 'white');
        $self->_centered_text("Expected Value (EV)", 'bright_cyan');
        $self->_centered_text("Each decision has an expected value based on risk/reward.", 'white');
        $self->_centered_text("Higher EV scores mean better decisions, regardless of outcome.", 'white');
        $self->_centered_text("", 'white');
        $self->_centered_text("AI Coach", 'bright_cyan');
        $self->_centered_text("An AI coach analyzes your decisions and provides feedback.", 'white');
        $self->_centered_text("It looks for patterns in your decision-making.", 'white');
        $self->_centered_text("", 'white');
        $self->_centered_text("Enemy Types", 'bright_cyan');
        $self->_centered_text("Goblin: Aggressive, always attacks.", 'white');
        $self->_centered_text("Giant Rat: Cautious, attacks when you're weakened.", 'white');
        $self->_centered_text("", 'white');
        $self->_centered_text("COMMANDS", 'bright_yellow');
        $self->_centered_text("", 'white');
        $self->_centered_text("[a] Attack: High EV when enemy is weak or you're strong", 'white');
        $self->_centered_text("[d] Defend: High EV when low on health or enemy is strong", 'white');
        $self->_centered_text("[i] Use Item: High EV in the right situation", 'white');
        $self->_centered_text("[f] Flee: High EV when severely outmatched", 'white');
        $self->_centered_text("[h] Help: Display this screen", 'white');
        $self->_centered_text("[q] Quit: Exit the game", 'white');
        $self->_centered_text("", 'white');
        $self->_centered_text("Press any key to return...", 'bright_green');
        
        $buffer->refresh();
        $cli->get_input();
        return 1;
    }
    
    # Display the victory screen with EV analysis
    method display_victory_screen($player_status, $enemy_name, $ev_system) {
        my $buffer = $self->_buffer();
        
        $cli->clear_screen();
        $self->_frame("VICTORY");
        
        $buffer->at(4, 0);
        $self->_display_ascii_art($victory, 'bright_yellow');
        $self->_centered_text("", 'white');
        $self->_centered_text("You have defeated the $enemy_name!", 'bright_green');
        
        my $hp_remaining = int(($player_status->{health}{current_hp} / $player_status->{health}{max_hp}) * 100);
        $self->_centered_text("HP Remaining: $hp_remaining%", 'bright_cyan');
        
        $self->_centered_text("", 'white');
        $self->_centered_text("EV ANALYSIS", 'bright_yellow');
        
        my $stats = $ev_system->get_decision_stats($player_status->{id});
        my $avg_score = $stats->{overall_avg} // 0;
        
        my $score_color = 'bright_red';
        $score_color = 'bright_yellow' if $avg_score >= 40;
        $score_color = 'bright_green' if $avg_score >= 70;
        
        $self->_centered_text("Overall EV Score: $avg_score", $score_color);
        
        my $decisions = $stats->{decisions} // [];
        my %action_counts;
        for my $decision (@$decisions) {
            $action_counts{$decision->{action}}++;
        }
        
        $self->_centered_text("", 'white');
        $self->_centered_text("Decision Breakdown:", 'bright_white');
        for my $action (sort keys %action_counts) {
            $self->_centered_text("$action: $action_counts{$action} times", 'white');
        }
        
        $self->_centered_text("", 'white');
        $self->_centered_text("AI COACH FEEDBACK", 'bright_yellow');
        my $feedback = $ev_system->generate_feedback($player_status->{id});
        $self->_centered_text($feedback, 'bright_cyan');
        
        $self->_centered_text("", 'white');
        $self->_centered_text("Press any key to continue...", 'bright_green');
        
        $buffer->refresh();
        $cli->get_input();
        return 1;
    }
    
    # Display the defeat screen with EV analysis
    method display_defeat_screen($player_status, $enemy_name, $ev_system) {
        my $buffer = $self->_buffer();
        
        $cli->clear_screen();
        $self->_frame("DEFEAT");
        
        $buffer->at(4, 0);
        $self->_display_ascii_art($game_over, 'bright_red');
        $self->_centered_text("", 'white');
        $self->_centered_text("You have been defeated by the $enemy_name!", 'bright_red');
        
        $self->_centered_text("", 'white');
        $self->_centered_text("EV ANALYSIS", 'bright_yellow');
        
        my $stats = $ev_system->get_decision_stats($player_status->{id});
        my $avg_score = $stats->{overall_avg} // 0;
        
        my $score_color = 'bright_red';
        $score_color = 'bright_yellow' if $avg_score >= 40;
        $score_color = 'bright_green' if $avg_score >= 70;
        
        $self->_centered_text("Overall EV Score: $avg_score", $score_color);
        
        my $decisions = $stats->{decisions} // [];
        my %action_counts;
        for my $decision (@$decisions) {
            $action_counts{$decision->{action}}++;
        }
        
        $self->_centered_text("", 'white');
        $self->_centered_text("Decision Breakdown:", 'bright_white');
        for my $action (sort keys %action_counts) {
            $self->_centered_text("$action: $action_counts{$action} times", 'white');
        }
        
        $self->_centered_text("", 'white');
        $self->_centered_text("AI COACH FEEDBACK", 'bright_yellow');
        my $feedback = $ev_system->generate_feedback($player_status->{id});
        $self->_centered_text($feedback, 'bright_cyan');
        
        $self->_centered_text("", 'white');
        $self->_centered_text("Even when defeated, the value of your decisions matters.", 'white');
        $self->_centered_text("Press any key to continue...", 'bright_green');
        
        $buffer->refresh();
        $cli->get_input();
        return 1;
    }
    
    # Display game credits
    method display_credits() {
        my $buffer = $self->_buffer();
        
        $cli->clear_screen();
        $self->_frame("CREDITS");
        
        $buffer->at(4, 0);
        $self->_centered_text("ITERUM", 'bright_yellow');
        $self->_centered_text("An EV-Based Decision Roguelike", 'bright_cyan');
        $self->_centered_text("", 'white');
        $self->_centered_text("Design & Development", 'bright_white');
        $self->_centered_text("7 Day Roguelike Challenge Team", 'white');
        $self->_centered_text("", 'white');
        $self->_centered_text("Architecture", 'bright_white');
        $self->_centered_text("Entity Component System (ECS)", 'white');
        $self->_centered_text("", 'white');
        $self->_centered_text("Special Thanks", 'bright_white');
        $self->_centered_text("Test2::V0 team for the test framework", 'white');
        $self->_centered_text("Term::Screen & Term::ANSIColor for UI capabilities", 'white');
        $self->_centered_text("EV concepts inspired by strategic games", 'white');
        $self->_centered_text("", 'white');
        $self->_centered_text("Press any key to return...", 'bright_green');
        
        $buffer->refresh();
        $cli->get_input();
        return 1;
    }
    
    # Display the EV stats during gameplay
    method display_ev_stats($player_id, $ev_system) {
        my $buffer = $self->_buffer();
        my $stats = $ev_system->get_decision_stats($player_id);
        my $avg_score = $stats->{overall_avg} // 0;
        
        my $term_width = $cli->width;
        
        # Draw box for EV stats
        $buffer->draw_box($cli->height - 3, 2, $term_width - 4, 3, 'single');
        
        my $score_text = "EV Score: $avg_score";
        my $padding = int(($term_width - length($score_text) - 8) / 2);
        $buffer->put_string($cli->height - 2, $padding + 4, $score_text);
        
        $buffer->refresh();
        return 1;
    }
    
    # Play again prompt
    method play_again_prompt() {
        my $buffer = $self->_buffer();
        
        $cli->clear_screen();
        $self->_frame("GAME OVER");
        
        $buffer->at(4, 0);
        $self->_centered_text("", 'white');
        $self->_centered_text("Would you like to play again?", 'bright_yellow');
        $self->_centered_text("", 'white');
        $self->_centered_text("[y] Yes - Start a new adventure", 'bright_green');
        $self->_centered_text("[n] No - Exit to the main menu", 'bright_red');
        $self->_centered_text("[c] Credits - View game credits", 'bright_cyan');
        $self->_centered_text("", 'white');
        
        $buffer->refresh();
        
        my $input = $cli->get_input();
        return $input;
    }
}

1;