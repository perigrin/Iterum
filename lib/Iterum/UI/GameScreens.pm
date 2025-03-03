use 5.40.0;
use experimental 'class';

# GameScreens module for Iterum roguelike
# Provides enhanced start and end game screens

class Iterum::UI::GameScreens {
    use Term::ANSIColor;
    use Term::Screen;
    
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
    
    # Display a decorative frame
    method _frame($title) {
        my $term_width = $cli->width;
        my $horizontal_line = '═' x ($term_width - 4);
        my $title_line = '═' x (($term_width - length($title) - 8) / 2);
        
        $cli->colored_puts('bright_blue', "╔$horizontal_line╗\n");
        $cli->colored_puts('bright_blue', "║" . " " x ($term_width - 4) . "║\n");
        $cli->colored_puts('bright_blue', "║ $title_line [ ");
        $cli->colored_puts('bright_yellow', $title);
        $cli->colored_puts('bright_blue', " ] $title_line");
        if (length($title_line) * 2 + length($title) + 8 < $term_width - 4) {
            $cli->colored_puts('bright_blue', "═");
        }
        $cli->colored_puts('bright_blue', " ║\n");
        $cli->colored_puts('bright_blue', "║" . " " x ($term_width - 4) . "║\n");
    }
    
    # Close the decorative frame
    method _close_frame() {
        my $term_width = $cli->width;
        my $horizontal_line = '═' x ($term_width - 4);
        $cli->colored_puts('bright_blue', "║" . " " x ($term_width - 4) . "║\n");
        $cli->colored_puts('bright_blue', "╚$horizontal_line╝\n");
    }
    
    # Display centered text
    method _centered_text($text, $color = 'white') {
        my $term_width = $cli->width;
        my $padding = int(($term_width - length($text) - 4) / 2);
        $padding = 0 if $padding < 0;
        
        $cli->colored_puts('bright_blue', "║");
        $cli->colored_puts('bright_blue', " " x $padding);
        $cli->colored_puts($color, $text);
        $cli->colored_puts('bright_blue', " " x ($term_width - length($text) - $padding - 4));
        $cli->colored_puts('bright_blue', "║\n");
    }
    
    # Display multi-line centered ASCII art
    method _display_ascii_art($art, $color = 'bright_cyan') {
        my @lines = split /\n/, $art;
        my $max_length = 0;
        
        # Find the longest line
        for my $line (@lines) {
            $max_length = length($line) if length($line) > $max_length;
        }
        
        my $term_width = $cli->width;
        for my $line (@lines) {
            my $padding = int(($term_width - length($line) - 4) / 2);
            $padding = 1 if $padding < 1;
            
            $cli->colored_puts('bright_blue', "║");
            $cli->colored_puts('bright_blue', " " x $padding);
            $cli->colored_puts($color, $line);
            my $remaining = $term_width - length($line) - $padding - 4;
            $remaining = 0 if $remaining < 0;
            $cli->colored_puts('bright_blue', " " x $remaining);
            $cli->colored_puts('bright_blue', "║\n");
        }
    }
    
    # Display the start screen
    method display_start_screen($version = '1.0.0') {
        $cli->clear_screen();
        $self->_frame("ITERUM");
        $self->_display_ascii_art($logo, 'bright_green');
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
        $self->_close_frame();
        
        $cli->get_input();
        return 1;
    }
    
    # Display help screen
    method display_help_screen() {
        $cli->clear_screen();
        $self->_frame("HELP");
        
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
        
        $self->_close_frame();
        $cli->get_input();
        return 1;
    }
    
    # Display the victory screen with EV analysis
    method display_victory_screen($player_status, $enemy_name, $ev_system) {
        $cli->clear_screen();
        $self->_frame("VICTORY");
        
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
        
        $self->_close_frame();
        $cli->get_input();
        return 1;
    }
    
    # Display the defeat screen with EV analysis
    method display_defeat_screen($player_status, $enemy_name, $ev_system) {
        $cli->clear_screen();
        $self->_frame("DEFEAT");
        
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
        
        $self->_close_frame();
        $cli->get_input();
        return 1;
    }
    
    # Display game credits
    method display_credits() {
        $cli->clear_screen();
        $self->_frame("CREDITS");
        
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
        
        $self->_close_frame();
        $cli->get_input();
        return 1;
    }
    
    # Display the EV stats during gameplay
    method display_ev_stats($player_id, $ev_system) {
        my $stats = $ev_system->get_decision_stats($player_id);
        my $avg_score = $stats->{overall_avg} // 0;
        
        my $term_width = $cli->width;
        my $horizontal_line = '─' x ($term_width - 4);
        
        $cli->colored_puts('bright_blue', "┌$horizontal_line┐\n");
        $cli->colored_puts('bright_blue', "│");
        $cli->colored_puts('bright_yellow', " EV Score: ");
        
        my $score_color = 'bright_red';
        $score_color = 'bright_yellow' if $avg_score >= 40;
        $score_color = 'bright_green' if $avg_score >= 70;
        
        $cli->colored_puts($score_color, $avg_score);
        
        my $padding = $term_width - 15 - length($avg_score);
        $cli->colored_puts('bright_blue', " " x $padding . "│\n");
        $cli->colored_puts('bright_blue', "└$horizontal_line┘\n");
        
        return 1;
    }
    
    # Play again prompt
    method play_again_prompt() {
        $cli->clear_screen();
        $self->_frame("GAME OVER");
        
        $self->_centered_text("", 'white');
        $self->_centered_text("Would you like to play again?", 'bright_yellow');
        $self->_centered_text("", 'white');
        $self->_centered_text("[y] Yes - Start a new adventure", 'bright_green');
        $self->_centered_text("[n] No - Exit to the main menu", 'bright_red');
        $self->_centered_text("[c] Credits - View game credits", 'bright_cyan');
        $self->_centered_text("", 'white');
        
        $self->_close_frame();
        
        my $input = $cli->get_input();
        return $input;
    }
}

1;