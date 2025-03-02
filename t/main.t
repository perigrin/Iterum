use 5.40.0;
use Test2::V0;
use FindBin;
use lib "$FindBin::Bin/../lib";

# Import required modules
use Iterum::ECS;

# Mock modules for testing
package MockPlayer {
    sub new { bless {id => 'player_id', name => 'Player'}, shift }
    sub id { 'player_id' }
    sub get_status { {name => 'Player', health => {current_hp => 100, max_hp => 100}} }
    sub defend { 1 }
}

package MockGoblin {
    sub new { bless {id => 'goblin_id', name => 'Goblin'}, shift }
    sub id { 'goblin_id' }
    sub get_status { {name => 'Goblin', health => {current_hp => 50, max_hp => 50}} }
}

package MockCombat {
    sub new { bless {}, shift }
    sub process_attack { {hit => 1, damage => 10} }
    sub get_enemy_action { 'attack' }
    sub process_enemy_action { {hit => 1, damage => 5} }
}

package MockEVScoring {
    sub new { bless {scores => {}}, shift }
    sub score_decision { my ($self, $entity_id, $action, $result) = @_; $self->{scores}{$entity_id} = 10; }
    sub get_current_score { 10 }
    sub get_score_summary { {total_score => 10, best_decision => 'attack', worst_decision => 'defend'} }
}

package MockCLI {
    sub new { bless {}, shift }
    sub clear_screen { 1 }
    sub display_title { 1 }
    sub display_text { 1 }
    sub display_entity_status { 1 }
    sub display_message { 1 }
    sub display_ev_score { 1 }
    sub display_score_summary { 1 }
    sub get_input { 'y' }
    sub get_combat_action { 'attack' }
    sub cleanup { 1 }
}

# Game state constants
use constant {
    STATE_START => 'start',
    STATE_COMBAT => 'combat',
    STATE_END => 'end',
};

# Test initialization
subtest 'Initialization' => sub {
    my $ecs = Iterum::ECS->new();
    ok($ecs, 'ECS created');
    
    my $player = MockPlayer->new();
    ok($player, 'Player created');
    ok($player->id, 'Player has ID');
    
    my $goblin = MockGoblin->new();
    ok($goblin, 'Goblin created');
    ok($goblin->id, 'Goblin has ID');
    
    my $combat_system = MockCombat->new();
    ok($combat_system, 'Combat system created');
    
    my $ev_system = MockEVScoring->new();
    ok($ev_system, 'EV scoring system created');
    
    my $cli = MockCLI->new();
    ok($cli, 'CLI created');
    
    # Create game state
    my $game_state = {
        running => 1,
        current_state => STATE_START,
        player => $player,
        enemy => $goblin,
        ecs => $ecs,
        systems => [$combat_system, $ev_system],
        cli => $cli,
        turn => 0,
        message => '',
    };
    
    ok($game_state, 'Game state created');
};

# Test process_start_state function
subtest 'Process start state' => sub {
    my $game_state = {
        running => 1,
        current_state => STATE_START,
        player => MockPlayer->new(),
        enemy => MockGoblin->new(),
        ecs => Iterum::ECS->new(),
        systems => [MockCombat->new(), MockEVScoring->new()],
        cli => MockCLI->new(),
        turn => 0,
        message => '',
    };
    
    process_start_state($game_state);
    is($game_state->{current_state}, STATE_COMBAT, 'Transition from start to combat');
};

# Test process_combat_state function
subtest 'Process combat state' => sub {
    my $game_state = {
        running => 1,
        current_state => STATE_COMBAT,
        player => MockPlayer->new(),
        enemy => MockGoblin->new(),
        ecs => Iterum::ECS->new(),
        systems => [MockCombat->new(), MockEVScoring->new()],
        cli => MockCLI->new(),
        turn => 0,
        message => '',
    };
    
    # Mock ECS get_components to return health
    no warnings 'redefine';
    local *Iterum::ECS::get_components = sub {
        my ($self, $id, @types) = @_;
        if ($id eq 'player_id') {
            return {current_hp => 100, max_hp => 100};
        } elsif ($id eq 'goblin_id') {
            return {current_hp => 40, max_hp => 50}; # Goblin took damage
        }
    };
    
    process_combat_state($game_state);
    is($game_state->{turn}, 1, 'Turn incremented');
    like($game_state->{message}, qr/attacked/, 'Message set with attack result');
};

# Test process_end_state function
subtest 'Process end state' => sub {
    my $game_state = {
        running => 1,
        current_state => STATE_END,
        player => MockPlayer->new(),
        enemy => MockGoblin->new(),
        ecs => Iterum::ECS->new(),
        systems => [MockCombat->new(), MockEVScoring->new()],
        cli => MockCLI->new(),
        turn => 10,
        message => 'Game over',
    };
    
    process_end_state($game_state);
    is($game_state->{current_state}, STATE_START, 'Transition from end to start (new game)');
    is($game_state->{turn}, 0, 'Turn reset');
    is($game_state->{message}, '', 'Message reset');
};

# Test game state transitions
subtest 'State transitions' => sub {
    my $game_state = {
        running => 1,
        current_state => STATE_START,
        player => MockPlayer->new(),
        enemy => MockGoblin->new(),
        ecs => Iterum::ECS->new(),
        systems => [MockCombat->new(), MockEVScoring->new()],
        cli => MockCLI->new(),
        turn => 0,
        message => '',
    };
    
    # Start -> Combat
    process_start_state($game_state);
    is($game_state->{current_state}, STATE_COMBAT, 'Transition from start to combat');
    
    # Combat -> End (via mock player death)
    no warnings 'redefine';
    local *Iterum::ECS::get_components = sub {
        my ($self, $id, @types) = @_;
        if ($id eq 'player_id') {
            return {current_hp => 0, max_hp => 100}; # Player died
        } elsif ($id eq 'goblin_id') {
            return {current_hp => 50, max_hp => 50};
        }
    };
    
    process_combat_state($game_state);
    is($game_state->{current_state}, STATE_END, 'Transition from combat to end (player died)');
    
    # End -> Start (new game)
    process_end_state($game_state);
    is($game_state->{current_state}, STATE_START, 'Transition from end to start (new game)');
};

# Test main_loop function
subtest 'Main loop' => sub {
    my $game_state = {
        running => 1,
        current_state => STATE_START,
        player => MockPlayer->new(),
        enemy => MockGoblin->new(),
        ecs => Iterum::ECS->new(),
        systems => [MockCombat->new(), MockEVScoring->new()],
        cli => MockCLI->new(),
        turn => 0,
        message => '',
    };
    
    # Mock process functions to track calls
    my $start_calls = 0;
    my $combat_calls = 0;
    my $end_calls = 0;
    
    no warnings 'redefine';
    local *process_start_state = sub {
        my ($state) = @_;
        $start_calls++;
        $state->{current_state} = STATE_COMBAT;
    };
    
    local *process_combat_state = sub {
        my ($state) = @_;
        $combat_calls++;
        $state->{current_state} = STATE_END;
    };
    
    local *process_end_state = sub {
        my ($state) = @_;
        $end_calls++;
        $state->{running} = 0; # End the loop for testing
    };
    
    local *Iterum::ECS::update = sub { 1 }; # Mock ECS update
    
    main_loop($game_state);
    
    is($start_calls, 1, 'Start state processed once');
    is($combat_calls, 1, 'Combat state processed once');
    is($end_calls, 1, 'End state processed once');
    is($game_state->{running}, 0, 'Game stopped after main loop');
};

# Define the functions being tested
sub process_start_state {
    my ($state) = @_;
    
    # Display welcome message (mock)
    $state->{cli}->clear_screen();
    $state->{cli}->display_title("Welcome to Iterum");
    $state->{cli}->display_text("Press any key to start...");
    
    # Wait for key press (mock)
    $state->{cli}->get_input();
    
    # Transition to combat state
    $state->{current_state} = STATE_COMBAT;
}

sub process_combat_state {
    my ($state) = @_;
    
    # Display game state (mock)
    $state->{cli}->clear_screen();
    $state->{cli}->display_title("Iterum - Turn " . $state->{turn});
    
    # Display player and enemy status (mock)
    my $player_status = $state->{player}->get_status();
    my $enemy_status = $state->{enemy}->get_status();
    
    $state->{cli}->display_entity_status($player_status);
    $state->{cli}->display_entity_status($enemy_status);
    
    # Display message if any (mock)
    $state->{cli}->display_message($state->{message}) if $state->{message};
    $state->{message} = '';
    
    # Get player action (mock)
    my $action = $state->{cli}->get_combat_action();
    
    # Process player action (mock)
    my $combat_system = $state->{systems}[0]; # Combat system
    my $ev_system = $state->{systems}[1];     # EV scoring system
    
    if ($action eq 'attack') {
        my $result = $combat_system->process_attack($state->{player}->id, $state->{enemy}->id);
        $state->{message} = "You attacked the " . $enemy_status->{name} . "!";
        
        # Score the player's decision
        $ev_system->score_decision($state->{player}->id, 'attack', $result);
    }
    
    # Process enemy turn (mock)
    my ($player_health) = $state->{ecs}->get_components($state->{player}->id, 'Health');
    
    # Check if combat has ended
    if ($player_health->{current_hp} <= 0) {
        $state->{message} .= "\nYou have been defeated!";
        $state->{current_state} = STATE_END;
    }
    
    # Increment turn counter
    $state->{turn}++;
}

sub process_end_state {
    my ($state) = @_;
    
    # Display end game message (mock)
    $state->{cli}->clear_screen();
    $state->{cli}->display_title("Game Over");
    $state->{cli}->display_text($state->{message});
    
    # Display EV score summary (mock)
    my $ev_system = $state->{systems}[1]; # EV scoring system
    my $score_summary = $ev_system->get_score_summary($state->{player}->id);
    $state->{cli}->display_score_summary($score_summary);
    
    # Ask to play again (mock)
    $state->{cli}->display_text("\nPlay again? (y/n)");
    my $input = $state->{cli}->get_input();
    
    if ($input eq 'y') {
        # Reset game state
        $state->{current_state} = STATE_START;
        $state->{turn} = 0;
        $state->{message} = '';
    } else {
        # End the game
        $state->{running} = 0;
    }
}

sub main_loop {
    my ($state) = @_;
    
    while ($state->{running}) {
        if ($state->{current_state} eq STATE_START) {
            process_start_state($state);
        } elsif ($state->{current_state} eq STATE_COMBAT) {
            process_combat_state($state);
        } elsif ($state->{current_state} eq STATE_END) {
            process_end_state($state);
        }
        
        # Update ECS systems
        $state->{ecs}->update();
    }
}

done_testing();