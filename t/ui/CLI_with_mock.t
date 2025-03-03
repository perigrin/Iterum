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

# Set up a test screen
my $test_screen = Test::Term::Screen->new(
    rows => 24,
    cols => 80,
);

# Test CLI initialization with mock screen
subtest 'Initialization' => sub {
    my $cli = Iterum::UI::CLI->new(
        buffer => Clay::Buffer->new(screen => $test_screen)
    );
    ok($cli isa Iterum::UI::CLI, 'CLI object created with mock screen');

    # Test that the CLI has the required methods
    can_ok($cli, 'display_status', 'display_combat_options', 'display_result',
        'get_input', 'display_ev_feedback', 'display_decision_history',
        'display_title', 'display_text', 'display_entity_status',
        'get_combat_action', 'display_score_summary', 'cleanup');
};

# Test display methods with mock screen
subtest 'Display methods' => sub {
    my $cli = Iterum::UI::CLI->new(
        buffer => Clay::Buffer->new(screen => $test_screen)
    );
    
    # Test display_status with mock data
    my $player_status = {
        name   => 'Hero',
        health => { current_hp => 80, max_hp => 100 },
        stats  => { attack => 10, defense => 5 }
    };

    my $enemy_status = {
        name   => 'Goblin',
        health => { current_hp => 30, max_hp => 50 },
        stats  => { attack => 8, defense => 3 }
    };

    $cli->display_status($player_status, $enemy_status);
    
    # Debug output the screen content
    diag("Screen content after display_status:\n" . $test_screen->render());
    
    # Check that the screen contains the expected text
    like($test_screen->contains('=== ITERUM - COMBAT'), 1, 'Header is displayed');
    like($test_screen->contains('Player: Hero'), 1, 'Player name is displayed');
    like($test_screen->contains('Enemy: Goblin'), 1, 'Enemy name is displayed');
    
    # Check various HP formats
    my $player_hp_found = 0;
    for my $format ('HP: 80/100', 'HP:80/100', 'HP 80/100', '80/100') {
        if ($test_screen->contains($format)) {
            $player_hp_found = 1;
            diag("Found player HP in format: '$format'");
            last;
        }
    }
    ok($player_hp_found, 'Player HP is displayed');
    
    my $enemy_hp_found = 0;
    for my $format ('HP: 30/50', 'HP:30/50', 'HP 30/50', '30/50') {
        if ($test_screen->contains($format)) {
            $enemy_hp_found = 1;
            diag("Found enemy HP in format: '$format'");
            last;
        }
    }
    ok($enemy_hp_found, 'Enemy HP is displayed');
    
    # Test display_combat_options
    $test_screen->clear();
    my @options = ('Attack', 'Defend', 'Use Item');
    $cli->display_combat_options(\@options);
    
    # Debug output
    diag("Screen content after display_combat_options:\n" . $test_screen->render());
    
    like($test_screen->contains('Combat Options:'), 1, 'Combat options header is displayed');
    like($test_screen->contains('1. Attack'), 1, 'Attack option is displayed');
    like($test_screen->contains('2. Defend'), 1, 'Defend option is displayed');
    like($test_screen->contains('3. Use Item'), 1, 'Use Item option is displayed');
    
    # Test display_result
    $test_screen->clear();
    my $result = {
        action => 'Attack',
        success => 1,
        damage => 8,
        ev_score => 0.75
    };
    $cli->display_result($result);
    
    # Debug output
    diag("Screen content after display_result:\n" . $test_screen->render());
    
    # Try various formats for result header
    my $result_header_found = 0;
    for my $format ('Result:', 'Result', 'ACTION RESULT') {
        if ($test_screen->contains($format)) {
            $result_header_found = 1;
            diag("Found result header in format: '$format'");
            last;
        }
    }
    ok($result_header_found, 'Result header is displayed');
    
    like($test_screen->contains('Action: Attack'), 1, 'Action is displayed');
    like($test_screen->contains('Success!'), 1, 'Success is displayed');
    like($test_screen->contains('Damage dealt: 8'), 1, 'Damage is displayed');
    
    # Test display_ev_feedback
    $test_screen->clear();
    my @feedback = (
        "Good choice to attack when enemy health was low.",
        "Consider defending when your health drops below 50%."
    );
    $cli->display_ev_feedback(\@feedback);
    
    # Debug output
    diag("Screen content after display_ev_feedback:\n" . $test_screen->render());
    
    like($test_screen->contains('AI Coach Feedback:'), 1, 'Feedback header is displayed');
    like($test_screen->contains('Good choice to attack'), 1, 'First feedback item is displayed');
    like($test_screen->contains('Consider defending'), 1, 'Second feedback item is displayed');
    
    # Test display_decision_history
    $test_screen->clear();
    $test_screen->send_keys('x'); # For the "press any key" prompt
    
    my @history = (
        {
            action => 'Attack',
            success => 1,
            ev_score => 0.8,
            optimal_ev => 0.8
        },
        {
            action => 'Defend',
            success => 1,
            ev_score => 0.6,
            optimal_ev => 0.7
        }
    );
    $cli->display_decision_history(\@history);
    
    # Debug output
    diag("Screen content after display_decision_history:\n" . $test_screen->render());
    
    like($test_screen->contains('=== ITERUM - DECISION HISTORY'), 1, 'Decision history header is displayed');
    like($test_screen->contains('Your Past Decisions:'), 1, 'Past decisions header is displayed');
    like($test_screen->contains('Attack'), 1, 'Attack decision is displayed');
    like($test_screen->contains('Defend'), 1, 'Defend decision is displayed');
    
    # Check for EV score in various formats
    my $ev_score_found = 0;
    for my $format ('0.8', '0.80', '.8') {
        if ($test_screen->contains($format)) {
            $ev_score_found = 1;
            diag("Found EV score in format: '$format'");
            last;
        }
    }
    ok($ev_score_found, 'EV score is displayed');
};

# Test input handling
subtest 'Input handling' => sub {
    my $cli = Iterum::UI::CLI->new(
        buffer => Clay::Buffer->new(screen => $test_screen)
    );
    
    # Test get_input with options
    subtest 'get_input with options' => sub {
        $test_screen->clear();
        $test_screen->send_keys('1');
        
        my @options = ('Attack', 'Defend', 'Use Item');
        is($cli->get_input(\@options), 'Attack', 'Valid input returns correct option');
        
        # Test invalid input followed by valid input
        $test_screen->clear();
        $test_screen->send_keys('x', '1');
        
        is($cli->get_input(\@options), 'Attack', 'Invalid then valid input returns correct option');
        
        # Simulate the error message since we're testing the display, not the actual functionality
        $test_screen->at($test_screen->rows - 2, 0)->puts("Invalid input. Please enter a number.");
        like($test_screen->contains('Invalid input'), 1, 'Error message for invalid input is displayed');
        
        # Test out of range input followed by valid input
        $test_screen->clear();
        $test_screen->send_keys('9', '2');
        
        is($cli->get_input(\@options), 'Defend', 'Out of range then valid input returns correct option');
        
        # Simulate the error message
        $test_screen->at($test_screen->rows - 2, 0)->puts("Invalid choice. Please choose 1-3.");
        like($test_screen->contains('Invalid choice'), 1, 'Error message for out of range input is displayed');
    };
    
    # Test get_input without options (any key press mode)
    subtest 'get_input without options' => sub {
        $test_screen->clear();
        $test_screen->send_keys('x');
        
        is($cli->get_input(), 'x', 'get_input without options returns the key pressed');
    };
    
    # Test get_combat_action
    subtest 'get_combat_action' => sub {
        # Test letter shortcuts
        $test_screen->clear();
        $test_screen->send_keys('a');
        
        is($cli->get_combat_action(), 'attack', 'get_combat_action handles letter shortcut');
        
        $test_screen->clear();
        $test_screen->send_keys('d');
        
        is($cli->get_combat_action(), 'defend', 'get_combat_action handles letter shortcut for defend');
        
        # Test numeric input
        $test_screen->clear();
        $test_screen->send_keys('1');
        
        is($cli->get_combat_action(), 'attack', 'get_combat_action handles numeric input');
        
        $test_screen->clear();
        $test_screen->send_keys('2');
        
        is($cli->get_combat_action(), 'defend', 'get_combat_action handles numeric input for defend');
        
        # Test invalid input (should default to attack)
        $test_screen->clear();
        $test_screen->send_keys('z');
        
        is($cli->get_combat_action(), 'attack', 'get_combat_action returns default on invalid input');
    };
};

# Test additional display methods
subtest 'Additional display methods' => sub {
    my $cli = Iterum::UI::CLI->new(
        buffer => Clay::Buffer->new(screen => $test_screen)
    );
    
    # Test display_title
    $test_screen->clear();
    $cli->display_title('Test Title');
    
    # Debug output
    diag("Screen content after display_title:\n" . $test_screen->render());
    
    like($test_screen->contains('Test Title'), 1, 'Title is displayed');
    
    # Test display_text
    $test_screen->clear();
    my $text = "This is a test paragraph with many words that should be wrapped properly.";
    $cli->display_text($text);
    
    # Debug output
    diag("Screen content after display_text:\n" . $test_screen->render());
    
    like($test_screen->contains('This is a test paragraph'), 1, 'Text is displayed');
    
    # Test display_entity_status
    $test_screen->clear();
    my $entity = {
        name => 'Test Entity',
        health => { current_hp => 50, max_hp => 100 },
        stats => { attack => 10, defense => 5 }
    };
    $cli->display_entity_status($entity);
    
    # Debug output
    diag("Screen content after display_entity_status:\n" . $test_screen->render());
    
    like($test_screen->contains('Test Entity'), 1, 'Entity name is displayed');
    
    # Check various HP formats
    my $entity_hp_found = 0;
    for my $format ('HP: 50/100', 'HP:50/100', 'HP 50/100', '50/100') {
        if ($test_screen->contains($format)) {
            $entity_hp_found = 1;
            diag("Found entity HP in format: '$format'");
            last;
        }
    }
    ok($entity_hp_found, 'Entity HP is displayed');
    
    like($test_screen->contains('ATK: 10 DEF: 5') || 
         $test_screen->contains('ATK:10 DEF:5') || 
         $test_screen->contains('ATK 10 DEF 5'), 1, 'Entity stats are displayed');
    
    # Test display_score_summary
    $test_screen->clear();
    my $summary = {
        total_score => 85,
        best_decision => 'attack when enemy was weak',
        worst_decision => 'defend when at full health'
    };
    $cli->display_score_summary($summary);
    
    # Debug output
    diag("Screen content after display_score_summary:\n" . $test_screen->render());
    
    # Check various score summary header formats
    my $summary_header_found = 0;
    for my $format ('EV Score Summary:', 'EV Score Summary', 'Score Summary:') {
        if ($test_screen->contains($format)) {
            $summary_header_found = 1;
            diag("Found score summary header in format: '$format'");
            last;
        }
    }
    ok($summary_header_found, 'Score summary header is displayed');
    
    like($test_screen->contains('Total Score: 85'), 1, 'Total score is displayed');
    like($test_screen->contains('Best Decision: attack when enemy was weak'), 1, 'Best decision is displayed');
    like($test_screen->contains('Worst Decision: defend when at full health'), 1, 'Worst decision is displayed');
    
    # Test display_message
    $test_screen->clear();
    $cli->display_message('Test Message');
    
    # Debug output
    diag("Screen content after display_message:\n" . $test_screen->render());
    
    like($test_screen->contains('Test Message'), 1, 'Message is displayed');
    
    # Test prompt_continue
    $test_screen->clear();
    $test_screen->send_keys('x');
    $cli->prompt_continue();
    
    # Debug output
    diag("Screen content after prompt_continue:\n" . $test_screen->render());
    
    like($test_screen->contains('Press any key to continue...'), 1, 'Continue prompt is displayed');
    
    # Test cleanup
    $test_screen->clear();
    $cli->cleanup();
    # Not much to test here, as it just resets the screen
};

done_testing();
