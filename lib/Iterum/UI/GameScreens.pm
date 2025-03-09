use 5.40.0;
use utf8;
use experimental 'class';

# GameScreens module for Iterum roguelike
# Provides enhanced game screens using the Clay renderer

class Iterum::UI::GameScreens {

    use Clay;    # Import Clay functions and constants

    field $cli :param :reader;    # CLI instance for rendering

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

    # Create a new root for a specific screen
    method _create_screen_root($title) {

        # Clear the screen first
        $cli->clear();

        # Create a new root with a border
        my $context = $cli->context;    # Access the context from CLI object

        my $root = create_root(
            $context,
            {
                id            => 'screen_root',
                layout_config => Clay::Types::LayoutConfig->new(
                    sizing_width_type  => $SIZING_GROW,
                    sizing_height_type => $SIZING_GROW,
                    layout_direction   => $TOP_TO_BOTTOM,
                    padding            => padding_all(2),
                    child_gap          => 1,
                ),
                border_config =>
                  border_all( 2, color( 200, 200, 200 ), 'double' ),
                children => [
                    {
                        id            => 'title_area',
                        layout_config => Clay::Types::LayoutConfig->new(
                            sizing_width_type   => $SIZING_GROW,
                            sizing_height_type  => $SIZING_FIXED,
                            sizing_height_value => 1,
                        ),
                        text        => $title,
                        text_config =>
                          text_config( color_white(1), { bold => 1 } ),
                    },
                    {
                        id            => 'content_area',
                        layout_config => Clay::Types::LayoutConfig->new(
                            sizing_width_type  => $SIZING_GROW,
                            sizing_height_type => $SIZING_GROW,
                            layout_direction   => $TOP_TO_BOTTOM,
                            alignment_x        => $ALIGN_CENTER,
                            padding            => padding_all(1),
                            child_gap          => 1,
                        ),
                    }
                ],
            }
        );

        return $root;
    }

    # Display centered text
    method _add_centered_text( $content_area, $text, $color_name = 'white',
        $bold = 0 )
    {
        my $color_method = "color_${color_name}";
        $color_method = "color_white" unless defined &$color_method;

        push @{ $content_area->{children} },
          {
            layout_config => Clay::Types::LayoutConfig->new(
                sizing_width_type  => $SIZING_FIT,
                sizing_height_type => $SIZING_FIT,
                alignment_x        => $ALIGN_CENTER,
            ),
            text => $text,
          };

        return $self;
    }

    # Display multi-line centered ASCII art
    method _add_ascii_art( $content_area, $art, $color_name = 'cyan' ) {
        my @lines = split /\n/, $art;

        # Skip empty lines at beginning and end
        while ( @lines && $lines[0] =~ /^\s*$/ ) {
            shift @lines;
        }

        while ( @lines && $lines[-1] =~ /^\s*$/ ) {
            pop @lines;
        }

        # Set up color
        my $color_method = "color_${color_name}";
        $color_method = "color_white" unless defined &$color_method;

        # Create a container for the ASCII art
        my $art_container = {
            layout_config => Clay::Types::LayoutConfig->new(
                sizing_width_type  => $SIZING_FIT,
                sizing_height_type => $SIZING_FIT,
                layout_direction   => $TOP_TO_BOTTOM,
                alignment_x        => $ALIGN_CENTER,
                child_gap          => 0,
            ),
            children => [],
        };

        # Add each line
        for my $line (@lines) {
            push $art_container->{children}->@*, { text => $line, };
        }

        # Add the art container to the content area
        push @{ $content_area->{children} }, $art_container;

        return $self;
    }

    # Add a spacer
    method _add_spacer($content_area) {
        push @{ $content_area->{children} },
          {
            layout_config => Clay::Types::LayoutConfig->new(
                sizing_width_type   => $SIZING_GROW,
                sizing_height_type  => $SIZING_FIXED,
                sizing_height_value => 1,
            ),
          };

        return $self;
    }

    # ==========================================
    # Main Screen Methods
    # ==========================================

    # Display the start screen
    method display_start_screen( $version = '1.0.0' ) {

        # Create screen with title
        my $root = $self->_create_screen_root("ITERUM");

        # Get content area
        my $content_area = ( $root->element->children )[1];

        # Add logo
        $self->_add_ascii_art( $content_area, $logo, 'green' );

        # Add spacing
        $self->_add_spacer($content_area);

        # Display game information
        $self->_add_centered_text( $content_area,
            "An EV-Based Decision Roguelike",
            'white', 1 );
        $self->_add_centered_text( $content_area, "Version $version",
            'white', 1 );
        $self->_add_spacer($content_area);
        $self->_add_centered_text( $content_area,
            "In this game, your decisions are evaluated based on",
            'white', 0 );
        $self->_add_centered_text( $content_area,
            "Expected Value (EV) rather than outcomes.",
            'white', 0 );
        $self->_add_spacer($content_area);
        $self->_add_centered_text( $content_area, "Controls:", 'yellow', 1 );
        $self->_add_centered_text( $content_area,
            "[a] Attack  [d] Defend  [i] Use Item  [f] Flee",
            'cyan', 0 );
        $self->_add_spacer($content_area);
        $self->_add_centered_text( $content_area,
            "Press any key to begin your adventure...",
            'green', 0 );

        # Render the screen
        $cli->context->layout();
        $cli->context->render();

        # Wait for input
        while (1) {
            if ( $cli->context->key_pressed() ) {
                $cli->context->get_key();
                last;
            }
            select( undef, undef, undef, 0.05 );    # Small delay
        }

        return $self;
    }

    # Display help screen
    method display_help_screen() {

        # Create screen with title
        my $root = $self->_create_screen_root("HELP");

        # Get content area
        my $content_area = $root->{children}[1];

        # Display help content
        $self->_add_centered_text( $content_area, "GAME CONCEPTS", 'yellow',
            1 );
        $self->_add_spacer($content_area);

        $self->_add_centered_text( $content_area, "Expected Value (EV)",
            'cyan', 1 );
        $self->_add_centered_text( $content_area,
            "Each decision has an expected value based on risk/reward.",
            'white', 0 );
        $self->_add_centered_text( $content_area,
            "Higher EV scores mean better decisions, regardless of outcome.",
            'white', 0 );
        $self->_add_spacer($content_area);

        $self->_add_centered_text( $content_area, "AI Coach", 'cyan', 1 );
        $self->_add_centered_text( $content_area,
            "An AI coach analyzes your decisions and provides feedback.",
            'white', 0 );
        $self->_add_centered_text( $content_area,
            "It looks for patterns in your decision-making.",
            'white', 0 );
        $self->_add_spacer($content_area);

        $self->_add_centered_text( $content_area, "Enemy Types", 'cyan', 1 );
        $self->_add_centered_text( $content_area,
            "Goblin: Aggressive, always attacks.",
            'white', 0 );
        $self->_add_centered_text( $content_area,
            "Giant Rat: Cautious, attacks when you're weakened.",
            'white', 0 );
        $self->_add_spacer($content_area);

        $self->_add_centered_text( $content_area, "COMMANDS", 'yellow', 1 );
        $self->_add_spacer($content_area);

        $self->_add_centered_text( $content_area,
            "[a] Attack: High EV when enemy is weak or you're strong",
            'white', 0 );
        $self->_add_centered_text( $content_area,
            "[d] Defend: High EV when low on health or enemy is strong",
            'white', 0 );
        $self->_add_centered_text( $content_area,
            "[i] Use Item: High EV in the right situation",
            'white', 0 );
        $self->_add_centered_text( $content_area,
            "[f] Flee: High EV when severely outmatched",
            'white', 0 );
        $self->_add_centered_text( $content_area,
            "[h] Help: Display this screen",
            'white', 0 );
        $self->_add_centered_text( $content_area, "[q] Quit: Exit the game",
            'white', 0 );
        $self->_add_spacer($content_area);

        $self->_add_centered_text( $content_area, "Press any key to return...",
            'green', 0 );

        # Render the screen
        $cli->{context}->layout();
        $cli->{context}->render();

        # Wait for input
        while (1) {
            if ( $cli->{context}->key_pressed() ) {
                $cli->{context}->get_key();
                last;
            }
            select( undef, undef, undef, 0.05 );    # Small delay
        }

        return $self;
    }

    # Display the victory screen with EV analysis
    method display_victory_screen( $player_status, $enemy_name, $ev_system ) {

        # Create screen with title
        my $root = $self->_create_screen_root("VICTORY");

        # Get content area
        my $content_area = $root->{children}[1];

        # Add victory art
        $self->_add_ascii_art( $content_area, $victory, 'yellow' );

        # Add spacing
        $self->_add_spacer($content_area);

        # Display victory message
        $self->_add_centered_text( $content_area,
            "You have defeated the $enemy_name!",
            'green', 1 );

        # Display HP stats
        my $hp_remaining = int(
            (
                $player_status->{health}{current_hp} /
                  $player_status->{health}{max_hp}
            ) * 100
        );
        $self->_add_centered_text( $content_area,
            "HP Remaining: $hp_remaining%",
            'cyan', 0 );

        # Display EV analysis
        $self->_add_spacer($content_area);
        $self->_add_centered_text( $content_area, "EV ANALYSIS", 'yellow', 1 );

        my $stats     = $ev_system->get_decision_stats( $player_status->{id} );
        my $avg_score = $stats->{overall_avg} // 0;

        my $score_color = 'red';
        $score_color = 'yellow' if $avg_score >= 40;
        $score_color = 'green'  if $avg_score >= 70;

        $self->_add_centered_text( $content_area,
            "Overall EV Score: $avg_score",
            $score_color, 1 );

        # Display decision breakdown
        my $decisions = $stats->{decisions} // [];
        my %action_counts;
        for my $decision (@$decisions) {
            $action_counts{ $decision->{action} }++;
        }

        $self->_add_spacer($content_area);
        $self->_add_centered_text( $content_area, "Decision Breakdown:",
            'white', 1 );

        for my $action ( sort keys %action_counts ) {
            $self->_add_centered_text( $content_area,
                "$action: $action_counts{$action} times",
                'white', 0 );
        }

        # Display AI coach feedback
        $self->_add_spacer($content_area);
        $self->_add_centered_text( $content_area, "AI COACH FEEDBACK",
            'yellow', 1 );
        my $feedback = $ev_system->generate_feedback( $player_status->{id} );
        $self->_add_centered_text( $content_area, $feedback, 'cyan', 0 );

        $self->_add_spacer($content_area);
        $self->_add_centered_text( $content_area,
            "Press any key to continue...",
            'green', 0 );

        # Render the screen
        $cli->{context}->layout();
        $cli->{context}->render();

        # Wait for input
        while (1) {
            if ( $cli->{context}->key_pressed() ) {
                $cli->{context}->get_key();
                last;
            }
            select( undef, undef, undef, 0.05 );    # Small delay
        }

        return $self;
    }

    # Display the defeat screen with EV analysis
    method display_defeat_screen( $player_status, $enemy_name, $ev_system ) {

        # Create screen with title
        my $root = $self->_create_screen_root("DEFEAT");

        # Get content area
        my $content_area = $root->{children}[1];

        # Add defeat art
        $self->_add_ascii_art( $content_area, $game_over, 'red' );

        # Add spacing
        $self->_add_spacer($content_area);

        # Display defeat message
        $self->_add_centered_text( $content_area,
            "You have been defeated by the $enemy_name!",
            'red', 1 );

        # Display EV analysis
        $self->_add_spacer($content_area);
        $self->_add_centered_text( $content_area, "EV ANALYSIS", 'yellow', 1 );

        my $stats     = $ev_system->get_decision_stats( $player_status->{id} );
        my $avg_score = $stats->{overall_avg} // 0;

        my $score_color = 'red';
        $score_color = 'yellow' if $avg_score >= 40;
        $score_color = 'green'  if $avg_score >= 70;

        $self->_add_centered_text( $content_area,
            "Overall EV Score: $avg_score",
            $score_color, 1 );

        # Display decision breakdown
        my $decisions = $stats->{decisions} // [];
        my %action_counts;
        for my $decision (@$decisions) {
            $action_counts{ $decision->{action} }++;
        }

        $self->_add_spacer($content_area);
        $self->_add_centered_text( $content_area, "Decision Breakdown:",
            'white', 1 );

        for my $action ( sort keys %action_counts ) {
            $self->_add_centered_text( $content_area,
                "$action: $action_counts{$action} times",
                'white', 0 );
        }

        # Display AI coach feedback
        $self->_add_spacer($content_area);
        $self->_add_centered_text( $content_area, "AI COACH FEEDBACK",
            'yellow', 1 );
        my $feedback = $ev_system->generate_feedback( $player_status->{id} );
        $self->_add_centered_text( $content_area, $feedback, 'cyan', 0 );

        $self->_add_spacer($content_area);
        $self->_add_centered_text( $content_area,
            "Even when defeated, the value of your decisions matters.",
            'white', 0 );
        $self->_add_centered_text( $content_area,
            "Press any key to continue...",
            'green', 0 );

        # Render the screen
        $cli->{context}->layout();
        $cli->{context}->render();

        # Wait for input
        while (1) {
            if ( $cli->{context}->key_pressed() ) {
                $cli->{context}->get_key();
                last;
            }
            select( undef, undef, undef, 0.05 );    # Small delay
        }

        return $self;
    }

    # Display game credits
    method display_credits() {

        # Create screen with title
        my $root = $self->_create_screen_root("CREDITS");

        # Get content area
        my $content_area = $root->{children}[1];

        # Display credits content
        $self->_add_centered_text( $content_area, "ITERUM", 'yellow', 1 );
        $self->_add_centered_text( $content_area,
            "An EV-Based Decision Roguelike",
            'cyan', 0 );
        $self->_add_spacer($content_area);

        $self->_add_centered_text( $content_area, "Design & Development",
            'white', 1 );
        $self->_add_centered_text( $content_area,
            "7 Day Roguelike Challenge Team",
            'white', 0 );
        $self->_add_spacer($content_area);

        $self->_add_centered_text( $content_area, "Architecture", 'white', 1 );
        $self->_add_centered_text( $content_area,
            "Entity Component System (ECS)",
            'white', 0 );
        $self->_add_spacer($content_area);

        $self->_add_centered_text( $content_area, "Special Thanks", 'white',
            1 );
        $self->_add_centered_text( $content_area,
            "Test2::V0 team for the test framework",
            'white', 0 );
        $self->_add_centered_text( $content_area, "Clay for UI rendering",
            'white', 0 );
        $self->_add_centered_text( $content_area,
            "EV concepts inspired by strategic games",
            'white', 0 );
        $self->_add_spacer($content_area);

        $self->_add_centered_text( $content_area, "Press any key to return...",
            'green', 0 );

        # Render the screen
        $cli->{context}->layout();
        $cli->{context}->render();

        # Wait for input
        while (1) {
            if ( $cli->{context}->key_pressed() ) {
                $cli->{context}->get_key();
                last;
            }
            select( undef, undef, undef, 0.05 );    # Small delay
        }

        return $self;
    }

    # Display the EV stats during gameplay
    method display_ev_stats( $player_id, $ev_system ) {

        # Get the stats from the EV system
        my $stats     = $ev_system->get_decision_stats($player_id);
        my $avg_score = $stats->{overall_avg} // 0;

        # Create a root for the EV stats
        my $context = $cli->{context};

        my $root = create_root(
            $context,
            {
                id            => 'ev_stats',
                layout_config => Clay::Types::LayoutConfig->new(
                    sizing_width_type   => $SIZING_GROW,
                    sizing_height_type  => $SIZING_FIXED,
                    sizing_height_value => 3,
                    padding             => padding_all(1),
                    alignment_x         => $ALIGN_CENTER,
                    alignment_y         => $ALIGN_CENTER,
                ),
                border_config => border_all( 1, color( 255, 255, 255 ) ),
                children      => [
                    {
                        text        => "EV Score: $avg_score",
                        text_config =>
                          text_config( color_white(1), { bold => 1 } ),
                    }
                ],
            }
        );

        # Render the screen
        $context->layout();
        $context->render();

        return $self;
    }

    # Play again prompt
    method play_again_prompt() {

        # Create screen with title
        my $root = $self->_create_screen_root("GAME OVER");

        # Get content area
        my $content_area = $root->{children}[1];

        # Display prompt
        $self->_add_spacer($content_area);
        $self->_add_centered_text( $content_area,
            "Would you like to play again?",
            'yellow', 1 );
        $self->_add_spacer($content_area);

        $self->_add_centered_text( $content_area,
            "[y] Yes - Start a new adventure",
            'green', 0 );
        $self->_add_centered_text( $content_area,
            "[n] No - Exit to the main menu",
            'red', 0 );
        $self->_add_centered_text( $content_area,
            "[c] Credits - View game credits",
            'cyan', 0 );
        $self->_add_spacer($content_area);

        # Render the screen
        $cli->{context}->layout();
        $cli->{context}->render();

        # Get user input
        my $input;
        while ( !$input ) {
            if ( $cli->{context}->key_pressed() ) {
                $input = $cli->{context}->get_key();
            }
            select( undef, undef, undef, 0.05 );    # Small delay
        }

        return $input;
    }
}

1;
