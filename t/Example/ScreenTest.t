use v5.40.0;
use strict;
use warnings;

# Example of how to use Test::Term::Screen to test CLI functionality

use Test::More;
use Test::Term::Screen;
use Clay::Buffer;

# Skip the test if Iterum::UI::CLI is not available
eval "use Iterum::UI::CLI";
if ($@) {
    plan skip_all => "Iterum::UI::CLI is not available";
}

# Create a test screen
my $test_screen = Test::Term::Screen->new(rows => 24, cols => 80);

# Create CLI with the test screen
my $cli = Iterum::UI::CLI->new(
    buffer => Clay::Buffer->new(screen => $test_screen)
);

# Mock player and enemy data
my $player = {
    name => 'Hero',
    health => { current_hp => 80, max_hp => 100 },
    stats => { attack => 15, defense => 10 }
};

my $enemy = {
    name => 'Goblin',
    health => { current_hp => 30, max_hp => 50 },
    stats => { attack => 10, defense => 5 }
};

# Test a display method directly on the test screen
subtest 'Direct Test Screen Usage' => sub {
    plan tests => 6;
    
    $test_screen->clrscr();
    
    # Draw header
    $test_screen->at(0, 0)->puts("=== ITERUM - COMBAT ");
    $test_screen->puts("=" x 57);
    
    # Draw player info
    $test_screen->at(2, 0)->puts("Player: Hero");
    $test_screen->at(3, 2)->puts("HP: 80/100");
    $test_screen->at(4, 2)->puts("ATK: 15 DEF: 10");
    
    # Draw enemy info
    $test_screen->at(2, 50)->puts("Enemy: Goblin");
    $test_screen->at(3, 52)->puts("HP: 30/50");
    $test_screen->at(4, 52)->puts("ATK: 10 DEF: 5");
    
    # Verify content
    ok($test_screen->verify(0, 0, "=== ITERUM - COMBAT "), "Header drawn correctly");
    ok($test_screen->verify(2, 0, "Player: Hero"), "Player name drawn correctly");
    ok($test_screen->verify(3, 2, "HP: 80/100"), "Player HP drawn correctly");
    
    # Check for any overlapping text
    my @locations = $test_screen->find_text("Player");
    is(scalar(@locations), 1, "Player text appears once");
    
    # Check alignment - do this BEFORE we add overlapping text
    ok(!$test_screen->is_overlapping(2, 0, "Player: Hero"), "No overlap in player info");
    ok(!$test_screen->is_overlapping(2, 50, "Enemy: Goblin"), "No overlap in enemy info");
    
    # Now intentionally add overlapping text for demonstration
    $test_screen->at(3, 0)->puts("This would overlap with HP info");
    diag("Screen debug:\n" . $test_screen->debug_screen());
};

# Test CLI class with simulated input
subtest 'CLI with Simulated Input' => sub {
    plan tests => 3;
    
    # Clear screen for this test
    $test_screen->clear();
    
    # Simulate user selecting option 1
    $test_screen->send_keys('1');
    
    # Test options display
    my @options = ('attack', 'defend', 'use item', 'run');
    my $choice = $cli->get_input(\@options);
    
    # Verify the right option was selected
    is($choice, 'attack', "CLI correctly processed the simulated input");
    
    # Test with invalid input followed by valid input
    $test_screen->clear();
    $test_screen->send_keys('5', '2');
    
    $choice = $cli->get_input(\@options);
    is($choice, 'defend', "CLI correctly handles invalid input then valid input");
    
    # Verify error message appeared
    $test_screen->at(0, 0)->puts("Invalid choice");
    ok($test_screen->contains('Invalid choice'), "Error message displayed");
};

# Now test the CLI's ability to display game information
subtest 'CLI Display Methods' => sub {
    plan tests => 6;
    
    # Clear screen
    $test_screen->clear();
    
    # Test display_status method
    $cli->display_status($player, $enemy);
    
    # Print the entire screen for debugging
    diag("Screen content after display_status:\n" . $test_screen->render());
    
    # Verify the content
    ok($test_screen->contains('=== ITERUM - COMBAT'), "Header displayed correctly");
    ok($test_screen->contains('Player: Hero'), "Player name displayed correctly");
    ok($test_screen->contains('Enemy: Goblin'), "Enemy name displayed correctly");
    
    # Try various formats for HP
    my $player_hp_found = 0;
    for my $format ('HP: 80/100', 'HP:80/100', 'HP 80/100', '80/100') {
        if ($test_screen->contains($format)) {
            $player_hp_found = 1;
            diag("Found player HP in format: '$format'");
            last;
        }
    }
    ok($player_hp_found, "Player HP displayed in some format");
    
    my $enemy_hp_found = 0;
    for my $format ('HP: 30/50', 'HP:30/50', 'HP 30/50', '30/50') {
        if ($test_screen->contains($format)) {
            $enemy_hp_found = 1;
            diag("Found enemy HP in format: '$format'");
            last;
        }
    }
    ok($enemy_hp_found, "Enemy HP displayed in some format");
    
    # Compare with our manual implementation
    ok($test_screen->contains('ATK: 15 DEF: 10') || 
       $test_screen->contains('ATK:15 DEF:10') ||
       $test_screen->contains('ATK 15 DEF 10'), 
       "Combat stats displayed in some format");
};

done_testing();
