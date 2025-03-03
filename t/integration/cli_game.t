use 5.40.0;
use Test2::V0;
use FindBin qw($Bin);
use lib "$Bin/../../lib";

use Test::Term::Screen;
use Clay::Buffer;

# Skip the test if Iterum::UI::CLI is not available
eval "use Iterum::UI::CLI";
if ($@) {
    plan skip_all => "Iterum::UI::CLI is not available";
}

# This test simulates a simple game flow using the CLI

# Set up a test screen
my $test_screen = Test::Term::Screen->new(
    rows => 24,
    cols => 80,
);

# Initialize the CLI
my $cli = Iterum::UI::CLI->new(
    buffer => Clay::Buffer->new(screen => $test_screen)
);

# Simulate a game loop with combat
subtest 'Game loop simulation' => sub {
    # Define player and enemy
    my $player = {
        name   => 'Hero',
        health => { current_hp => 100, max_hp => 100 },
        stats  => { attack => 15, defense => 10 }
    };
    
    my $enemy = {
        name   => 'Dragon',
        health => { current_hp => 80, max_hp => 80 },
        stats  => { attack => 12, defense => 8 }
    };
    
    # Display game title and intro
    $cli->clear_screen();
    $cli->display_title('ITERUM - THE ROGUELIKE GAME');
    $cli->display_text(
        "Welcome to Iterum, a roguelike game where Expected Value is more important than luck. "
        . "Make decisions based on the probability of success and maximize your EV score."
    );
    
    # Debug output
    diag("Screen content after title and intro:\n" . $test_screen->render());
    
    like($test_screen->contains('ITERUM - THE ROGUELIKE GAME'), 1, 'Game title is displayed');
    like($test_screen->contains('Welcome to Iterum'), 1, 'Game intro is displayed');
    
    # Display player and enemy status
    my $next_row = $cli->display_entity_status($player);
    ok($next_row > 0, 'display_entity_status returns a row position');
    
    # Simulate a combat turn where player attacks
    # Player chooses to attack
    $test_screen->clear();
    $cli->display_status($player, $enemy);
    $cli->display_combat_options(['attack', 'defend', 'help', 'quit']);
    
    # Debug output
    diag("Screen content after display_status and combat options:\n" . $test_screen->render());
    
    # Simulate player selecting "attack"
    $test_screen->send_keys('1');
    
    # Get player's action
    my @options = ('attack', 'defend', 'help', 'quit');
    my $action = $cli->get_input(\@options);
    is($action, 'attack', 'Player chose to attack');
    
    # Simulate combat result
    my $result = {
        action => 'attack',
        success => 1,
        damage => 10,
        ev_score => 0.75
    };
    
    # Simulate enemy taking damage
    $enemy->{health}{current_hp} -= $result->{damage};
    
    # Display result
    $cli->display_result($result);
    
    # Debug output
    diag("Screen content after display_result:\n" . $test_screen->render());
    
    like($test_screen->contains('Success!'), 1, 'Combat result shows success');
    like($test_screen->contains('Damage dealt: 10'), 1, 'Combat result shows damage');
    
    # Display AI coach feedback
    my @feedback = (
        "Good choice to attack when your health is high.",
        "The EV of attacking was 0.75, which was optimal in this situation."
    );
    $cli->display_ev_feedback(\@feedback);
    
    # Debug output
    diag("Screen content after display_ev_feedback:\n" . $test_screen->render());
    
    like($test_screen->contains('AI Coach Feedback:'), 1, 'Feedback header is displayed');
    like($test_screen->contains('Good choice to attack'), 1, 'First feedback item is displayed');
    
    # Press any key to continue
    $test_screen->send_keys(' ');
    $cli->prompt_continue();
    
    # Simulate a new turn with enemy having lower health
    $test_screen->clear();
    $cli->display_status($player, $enemy);
    
    # Debug output
    diag("Screen content after updated status:\n" . $test_screen->render());
    
    # Check for updated enemy health in multiple formats
    my $updated_enemy_hp_found = 0;
    for my $format ('HP: 70/80', 'HP:70/80', 'HP 70/80', '70/80') {
        if ($test_screen->contains($format)) {
            $updated_enemy_hp_found = 1;
            diag("Found updated enemy HP in format: '$format'");
            last;
        }
    }
    ok($updated_enemy_hp_found, 'Enemy health is updated and displayed');
    
    # Simulate viewing decision history
    $test_screen->send_keys(' '); # For the "press any key" prompt
    
    my @history = (
        {
            action => 'attack',
            success => 1,
            ev_score => 0.75,
            optimal_ev => 0.75
        }
    );
    $cli->display_decision_history(\@history);
    
    # Debug output
    diag("Screen content after display_decision_history:\n" . $test_screen->render());
    
    like($test_screen->contains('=== ITERUM - DECISION HISTORY'), 1, 'Decision history header is displayed');
    like($test_screen->contains('attack'), 1, 'Attack decision is displayed in history');
    like($test_screen->contains('Success'), 1, 'Success is displayed in history');
    
    # Simulate end game with score summary
    $test_screen->clear();
    $cli->display_title('GAME OVER');
    
    my $summary = {
        total_score => 75,
        best_decision => 'attack when enemy was weak',
        worst_decision => 'none'
    };
    $cli->display_score_summary($summary);
    
    # Debug output
    diag("Screen content after display_score_summary:\n" . $test_screen->render());
    
    like($test_screen->contains('GAME OVER'), 1, 'Game over title is displayed');
    
    # Check for score summary header in various formats
    my $score_summary_found = 0;
    for my $format ('EV Score Summary:', 'EV Score Summary', 'Score Summary') {
        if ($test_screen->contains($format)) {
            $score_summary_found = 1;
            diag("Found score summary header in format: '$format'");
            last;
        }
    }
    ok($score_summary_found, 'Score summary header is displayed');
    
    like($test_screen->contains('Total Score: 75'), 1, 'Total score is displayed');
    
    # Simulate cleanup
    $cli->cleanup();
};

done_testing();
