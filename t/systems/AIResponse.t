use 5.40.0;
use experimental 'try';
use Test2::V0;
use FindBin qw($Bin);
use lib "$Bin/../../lib";

use Iterum::ECS;
use Iterum::Components::Health;
use Iterum::Components::CombatStats;
use Iterum::Components::EVScore;
use Iterum::Components::AIState;
use Iterum::Systems::EVScoring;
use Iterum::Systems::AIResponse;

# Test AIResponse system creation
subtest 'AIResponse System Creation' => sub {
    my $ecs = Iterum::ECS->new();

    Iterum::Components::Health::register($ecs);
    Iterum::Components::CombatStats::register($ecs);
    Iterum::Components::EVScore::register($ecs);
    Iterum::Components::AIState::register($ecs);

    my $ev_system = Iterum::Systems::EVScoring->new( ecs => $ecs );
    my $ai_system = Iterum::Systems::AIResponse->new(
        ecs       => $ecs,
        ev_system => $ev_system
    );

    ok( $ai_system, 'AIResponse system created' );
    is( $ai_system->ev_system, $ev_system,
        'EVScoring system linked correctly' );
};

# Test required components
subtest 'Required Components' => sub {
    my $ecs = Iterum::ECS->new();

    Iterum::Components::EVScore::register($ecs);
    Iterum::Components::AIState::register($ecs);

    my $ev_system = Iterum::Systems::EVScoring->new( ecs => $ecs );
    my $ai_system = Iterum::Systems::AIResponse->new(
        ecs       => $ecs,
        ev_system => $ev_system
    );

    my @required = $ai_system->components_required();
    is( \@required, ['AIState'], 'Required components are correct' );
};

# Test feedback generation based on EV data
subtest 'Feedback Generation' => sub {
    my $ecs = Iterum::ECS->new();

    Iterum::Components::Health::register($ecs);
    Iterum::Components::CombatStats::register($ecs);
    Iterum::Components::EVScore::register($ecs);
    Iterum::Components::AIState::register($ecs);

    my $ev_system = Iterum::Systems::EVScoring->new( ecs => $ecs );
    my $ai_system = Iterum::Systems::AIResponse->new(
        ecs       => $ecs,
        ev_system => $ev_system
    );

    # Create player with EVScore
    my $player_id = $ecs->new_entity('player');
    Iterum::Components::Health::add(
        $ecs, $player_id,
        max_hp     => 100,
        current_hp => 80
    );
    Iterum::Components::CombatStats::add(
        $ecs, $player_id,
        attack  => 10,
        defense => 5
    );
    Iterum::Components::EVScore::add( $ecs, $player_id );

    # Create AI Coach with AIState
    my $coach_id = $ecs->new_entity('ai_coach');
    Iterum::Components::AIState::add(
        $ecs,
        $coach_id,
        personality => {
            encouraging => 0.8,
            critical    => 0.2,
            analytical  => 0.7,
            helpful     => 0.6,
            sarcastic   => 0.1
        }
    );

    # Create an enemy
    my $enemy_id = $ecs->new_entity('enemy');
    Iterum::Components::Health::add(
        $ecs, $enemy_id,
        max_hp     => 100,
        current_hp => 20
    );
    Iterum::Components::CombatStats::add(
        $ecs, $enemy_id,
        attack  => 8,
        defense => 3
    );

    # Record some decisions
    $ev_system->record_decision( $player_id, $enemy_id, 'attack' );
    $ev_system->record_decision( $player_id, $enemy_id, 'attack' );
    $ev_system->record_decision( $player_id, $enemy_id, 'defend' );

    # Generate feedback
    my $feedback = $ai_system->generate_feedback( $coach_id, $player_id );

    ok( $feedback,              'Feedback generated' );
    ok( length($feedback) > 20, 'Feedback has reasonable length' );

    # Generate with different personality traits
    Iterum::Components::AIState::add(
        $ecs,
        $coach_id,
        personality => {
            encouraging => 0.2,
            critical    => 0.8,
            analytical  => 0.3,
            helpful     => 0.4,
            sarcastic   => 0.7
        }
    );

    my $critical_feedback =
      $ai_system->generate_feedback( $coach_id, $player_id );

    ok( $critical_feedback, 'Critical feedback generated' );
    isnt( $critical_feedback, $feedback,
        'Different personality produces different feedback' );
};

# Test analyzing player patterns
subtest 'Player Pattern Analysis' => sub {
    my $ecs = Iterum::ECS->new();

    Iterum::Components::Health::register($ecs);
    Iterum::Components::CombatStats::register($ecs);
    Iterum::Components::EVScore::register($ecs);
    Iterum::Components::AIState::register($ecs);

    my $ev_system = Iterum::Systems::EVScoring->new( ecs => $ecs );
    my $ai_system = Iterum::Systems::AIResponse->new(
        ecs       => $ecs,
        ev_system => $ev_system
    );

    # Create player with EVScore
    my $player_id = $ecs->new_entity('player');
    Iterum::Components::Health::add(
        $ecs, $player_id,
        max_hp     => 100,
        current_hp => 25     # Low health
    );
    Iterum::Components::CombatStats::add(
        $ecs, $player_id,
        attack  => 10,
        defense => 5
    );
    Iterum::Components::EVScore::add( $ecs, $player_id );

    # Create AI Coach with AIState
    my $coach_id = $ecs->new_entity('ai_coach');
    Iterum::Components::AIState::add( $ecs, $coach_id );

    # Create an enemy
    my $enemy_id = $ecs->new_entity('enemy');
    Iterum::Components::Health::add(
        $ecs, $enemy_id,
        max_hp     => 100,
        current_hp => 50
    );
    Iterum::Components::CombatStats::add(
        $ecs, $enemy_id,
        attack  => 8,
        defense => 3
    );

    # Record repetitive attack decisions at low health
    for ( 1 .. 3 ) {
        $ev_system->record_decision( $player_id, $enemy_id, 'attack' );
    }

    # Analyze patterns
    my $patterns = $ai_system->analyze_player_patterns( $coach_id, $player_id );

    ok( $patterns, 'Pattern analysis returned results' );
    ok( $patterns->{repetitive_actions} > 0, 'Detected repetitive actions' );
    ok( $patterns->{low_health_attacks} > 0, 'Detected attacks at low health' );

    # Check if patterns were stored in AIState
    my ($ai_state) = $ecs->get_components( $coach_id, 'AIState' );
    ok( $ai_state->{player_patterns}{repetitive_actions} > 0,
        'Repetitive actions pattern stored' );
    ok( $ai_state->{player_patterns}{low_health_attacks} > 0,
        'Low health attacks pattern stored' );
};

# Test personality adaptation
subtest 'Personality Adaptation' => sub {
    my $ecs = Iterum::ECS->new();

    Iterum::Components::Health::register($ecs);
    Iterum::Components::CombatStats::register($ecs);
    Iterum::Components::EVScore::register($ecs);
    Iterum::Components::AIState::register($ecs);

    my $ev_system = Iterum::Systems::EVScoring->new( ecs => $ecs );
    my $ai_system = Iterum::Systems::AIResponse->new(
        ecs       => $ecs,
        ev_system => $ev_system
    );

    # Create player with EVScore and many poor decisions
    my $player_id = $ecs->new_entity('player');
    Iterum::Components::Health::add(
        $ecs, $player_id,
        max_hp     => 100,
        current_hp => 20     # Low health
    );
    Iterum::Components::CombatStats::add(
        $ecs, $player_id,
        attack  => 10,
        defense => 5
    );
    Iterum::Components::EVScore::add( $ecs, $player_id );

    # Create AI Coach with AIState - with a low adaptation threshold
    my $coach_id            = $ecs->new_entity('ai_coach');
    my $initial_personality = {
        encouraging => 0.5,
        critical    => 0.3,
        analytical  => 0.6,
        helpful     => 0.5,
        sarcastic   => 0.2
    };

    Iterum::Components::AIState::add(
        $ecs, $coach_id,
        personality          => $initial_personality,
        adaptation_threshold => 2    # Lower threshold for testing
    );

    # Create an enemy
    my $enemy_id = $ecs->new_entity('enemy');
    Iterum::Components::Health::add(
        $ecs, $enemy_id,
        max_hp     => 100,
        current_hp => 50
    );
    Iterum::Components::CombatStats::add(
        $ecs, $enemy_id,
        attack  => 8,
        defense => 3
    );

    # Record several attack decisions at low health
    for ( 1 .. 3 ) {
        $ev_system->record_decision( $player_id, $enemy_id, 'attack' );
    }

    # Run pattern analysis
    $ai_system->analyze_player_patterns( $coach_id, $player_id );

    # Manually ensure we have enough pattern count for testing
    my ($ai_state) = $ecs->get_components( $coach_id, 'AIState' );
    my %patterns = %{ $ai_state->{player_patterns} };
    $patterns{low_health_attacks} = 3;    # Ensure pattern is above threshold

    $ecs->add_component(
        $coach_id,
        'AIState',
        {
            %$ai_state, player_patterns => \%patterns,
        }
    );

    # Now adapt personality
    my $adapted = $ai_system->adapt_coach_personality($coach_id);

    ok( $adapted, 'Personality adaptation performed' );

    # Check that personality traits were adjusted
    ($ai_state) = $ecs->get_components( $coach_id, 'AIState' );

    isnt(
        $ai_state->{personality}{encouraging},
        $initial_personality->{encouraging},
        'Encouraging trait changed after adaptation'
    );
    isnt(
        $ai_state->{personality}{critical},
        $initial_personality->{critical},
        'Critical trait changed after adaptation'
    );
};

# Test combat analysis and post-combat feedback
subtest 'Post-Combat Feedback' => sub {
    my $ecs = Iterum::ECS->new();

    Iterum::Components::Health::register($ecs);
    Iterum::Components::CombatStats::register($ecs);
    Iterum::Components::EVScore::register($ecs);
    Iterum::Components::AIState::register($ecs);

    my $ev_system = Iterum::Systems::EVScoring->new( ecs => $ecs );
    my $ai_system = Iterum::Systems::AIResponse->new(
        ecs       => $ecs,
        ev_system => $ev_system
    );

    # Create player with EVScore
    my $player_id = $ecs->new_entity('player');
    Iterum::Components::Health::add(
        $ecs, $player_id,
        max_hp     => 100,
        current_hp => 60
    );
    Iterum::Components::CombatStats::add(
        $ecs, $player_id,
        attack  => 10,
        defense => 5
    );
    Iterum::Components::EVScore::add( $ecs, $player_id );

    # Create AI Coach with AIState
    my $coach_id = $ecs->new_entity('ai_coach');
    Iterum::Components::AIState::add( $ecs, $coach_id );

    # Create an enemy
    my $enemy_id = $ecs->new_entity('enemy');
    Iterum::Components::Health::add(
        $ecs, $enemy_id,
        max_hp     => 100,
        current_hp => 50
    );
    Iterum::Components::CombatStats::add(
        $ecs, $enemy_id,
        attack  => 8,
        defense => 3
    );

    # Record various decisions to simulate a combat
    $ev_system->record_decision( $player_id, $enemy_id, 'attack' );
    $ev_system->record_decision( $player_id, $enemy_id, 'defend' );
    $ev_system->record_decision( $player_id, $enemy_id, 'attack' );

    # Generate post-combat feedback
    my $feedback =
      $ai_system->generate_post_combat_feedback( $coach_id, $player_id,
        $enemy_id, 'victory' );

    ok( $feedback,              'Post-combat feedback generated' );
    ok( length($feedback) > 20, 'Feedback has reasonable length' );

    # Check if feedback was recorded in AIState
    my ($ai_state) = $ecs->get_components( $coach_id, 'AIState' );
    is( scalar @{ $ai_state->{feedback_history} },
        1, 'Feedback recorded in history' );

# Need to create a new player/enemy for the second feedback to ensure decisions are tracked correctly
    my $player_id2 = $ecs->new_entity('player2');
    Iterum::Components::Health::add(
        $ecs, $player_id2,
        max_hp     => 100,
        current_hp => 30
    );
    Iterum::Components::CombatStats::add(
        $ecs, $player_id2,
        attack  => 10,
        defense => 5
    );
    Iterum::Components::EVScore::add( $ecs, $player_id2 );

    my $enemy_id2 = $ecs->new_entity('enemy2');
    Iterum::Components::Health::add(
        $ecs, $enemy_id2,
        max_hp     => 100,
        current_hp => 0      # Dead enemy for "defeat" outcome
    );
    Iterum::Components::CombatStats::add(
        $ecs, $enemy_id2,
        attack  => 12,
        defense => 4
    );

    $ev_system->record_decision( $player_id2, $enemy_id2, 'attack' );
    $ev_system->record_decision( $player_id2, $enemy_id2, 'attack' );

    # Generate different outcome feedback
    my $defeat_feedback =
      $ai_system->generate_post_combat_feedback( $coach_id, $player_id2,
        $enemy_id2, 'defeat' );

    ok( $defeat_feedback, 'Defeat feedback generated' );
    isnt( $defeat_feedback, $feedback,
        'Different outcome produces different feedback' );

    # Check feedback history again
    ($ai_state) = $ecs->get_components( $coach_id, 'AIState' );
    is( scalar @{ $ai_state->{feedback_history} },
        2, 'Second feedback recorded in history' );
};

# Test system integration with ECS update
subtest 'System Integration with ECS' => sub {
    my $ecs = Iterum::ECS->new();

    Iterum::Components::EVScore::register($ecs);
    Iterum::Components::AIState::register($ecs);

    my $ev_system = Iterum::Systems::EVScoring->new( ecs => $ecs );
    my $ai_system = Iterum::Systems::AIResponse->new(
        ecs       => $ecs,
        ev_system => $ev_system
    );

    $ecs->add_system($ai_system);

    # Create an AI coach with AIState
    my $coach_id = $ecs->new_entity('ai_coach');
    Iterum::Components::AIState::add( $ecs, $coach_id );

    # ECS update should not cause errors
    try {
        $ecs->update();
        pass('ECS update with AIResponse system works');
    }
    catch ($e) {
        fail("ECS update failed: $e");
    }
};

done_testing;
