use 5.40.0;
use experimental 'try';
use Test2::V0;
use FindBin qw($Bin);
use lib "$Bin/../../lib";

use Iterum::ECS;
use Iterum::Components::Health;
use Iterum::Components::CombatStats;
use Iterum::Components::EVScore;
use Iterum::Systems::EVScoring;

# Test EVScoring system creation
subtest 'EVScoring System Creation' => sub {
    my $ecs = Iterum::ECS->new();
    
    Iterum::Components::EVScore::register($ecs);
    
    Iterum::Components::Health::register($ecs);
    Iterum::Components::CombatStats::register($ecs);
    Iterum::Components::EVScore::register($ecs);
    
    my $ev_system = Iterum::Systems::EVScoring->new(
        ecs => $ecs,
    );
    
    ok($ev_system, 'EVScoring system created');
    ok($ev_system->ev_lookup, 'EV lookup data loaded');
    ok(exists $ev_system->ev_lookup->{attack}, 'Attack data loaded');
    ok(exists $ev_system->ev_lookup->{defend}, 'Defend data loaded');
};

# Test required components
subtest 'Required Components' => sub {
    my $ecs = Iterum::ECS->new();
    
    Iterum::Components::EVScore::register($ecs);
    
    my $ev_system = Iterum::Systems::EVScoring->new(
        ecs => $ecs,
    );
    
    my @required = $ev_system->components_required();
    is(
        \@required,
        ['EVScore'],
        'Required components are correct'
    );
};

# Test EV calculation for various scenarios
subtest 'EV Score Calculation' => sub {
    my $ecs = Iterum::ECS->new();
    
    Iterum::Components::Health::register($ecs);
    Iterum::Components::CombatStats::register($ecs);
    Iterum::Components::EVScore::register($ecs);
    
    my $ev_system = Iterum::Systems::EVScoring->new(
        ecs => $ecs,
    );
    
    # Create player and enemy with various health/combat states
    my $player_id = $ecs->new_entity('player');
    Iterum::Components::Health::add($ecs, $player_id, max_hp => 100, current_hp => 80);
    Iterum::Components::CombatStats::add($ecs, $player_id, attack => 10, defense => 5);
    Iterum::Components::EVScore::add($ecs, $player_id);
    
    my $enemy_id = $ecs->new_entity('enemy');
    Iterum::Components::Health::add($ecs, $enemy_id, max_hp => 100, current_hp => 20); # Below 30%
    Iterum::Components::CombatStats::add($ecs, $enemy_id, attack => 8, defense => 3);
    
    # Test attack EV calculation - Player at good health, enemy at low health
    my $attack_ev = $ev_system->calculate_ev(
        $player_id,
        $enemy_id,
        'attack'
    );
    
    # Base attack score: 50, opponent_health_below_30_percent: +30
    is($attack_ev, 80, 'Attack EV calculated correctly for low health enemy');
    
    # Change player health to below 30%
    Iterum::Components::Health::damage($ecs, $player_id, 60); # Now at 20/100
    
    # Test attack EV again - Player at low health, enemy at low health
    $attack_ev = $ev_system->calculate_ev(
        $player_id,
        $enemy_id,
        'attack'
    );
    
    # Base attack score: 50, health_below_30_percent: -20, opponent_health_below_30_percent: +30
    is($attack_ev, 60, 'Attack EV calculated correctly for low health player and enemy');
    
    # Test defend EV - Player at low health, enemy at low health
    my $defend_ev = $ev_system->calculate_ev(
        $player_id,
        $enemy_id,
        'defend'
    );
    
    # Base defend score: 40, health_below_30_percent: +30, opponent_health_below_30_percent: -10
    is($defend_ev, 60, 'Defend EV calculated correctly for low health player and enemy');
    
    # Put player in defensive stance
    Iterum::Components::CombatStats::set_defending($ecs, $player_id, 1);
    
    # Test defend EV again - Player already defending
    $defend_ev = $ev_system->calculate_ev(
        $player_id,
        $enemy_id,
        'defend'
    );
    
    # Base defend score: 40, health_below_30_percent: +30, opponent_health_below_30_percent: -10, already_defending: -30
    is($defend_ev, 30, 'Defend EV correctly penalized when already defending');
};

# Test recording decisions
subtest 'Recording Player Decisions' => sub {
    my $ecs = Iterum::ECS->new();
    
    Iterum::Components::Health::register($ecs);
    Iterum::Components::CombatStats::register($ecs);
    Iterum::Components::EVScore::register($ecs);
    
    my $ev_system = Iterum::Systems::EVScoring->new(
        ecs => $ecs,
    );
    
    # Create player and enemy
    my $player_id = $ecs->new_entity('player');
    Iterum::Components::Health::add($ecs, $player_id, max_hp => 100, current_hp => 80);
    Iterum::Components::CombatStats::add($ecs, $player_id, attack => 10, defense => 5);
    Iterum::Components::EVScore::add($ecs, $player_id);
    
    my $enemy_id = $ecs->new_entity('enemy');
    Iterum::Components::Health::add($ecs, $enemy_id, max_hp => 100, current_hp => 20);
    Iterum::Components::CombatStats::add($ecs, $enemy_id, attack => 8, defense => 3);
    
    # Record an attack decision
    $ev_system->record_decision($player_id, $enemy_id, 'attack');
    
    # Check that the EVScore component was updated
    my ($ev_score) = $ecs->get_components($player_id, 'EVScore');
    ok($ev_score->{current_decision}, 'Current decision is set');
    is($ev_score->{current_decision}->{action}, 'attack', 'Action is recorded correctly');
    is($ev_score->{current_decision}->{target}, $enemy_id, 'Target is recorded correctly');
    is($ev_score->{current_decision}->{ev_score}, 80, 'EV score is calculated and recorded');
    is(scalar @{$ev_score->{decisions}}, 1, 'Decision history contains one entry');
    
    # Record a defend decision
    $ev_system->record_decision($player_id, $enemy_id, 'defend');
    
    # Check updates
    ($ev_score) = $ecs->get_components($player_id, 'EVScore');
    is($ev_score->{current_decision}->{action}, 'defend', 'New action is recorded');
    is(scalar @{$ev_score->{decisions}}, 2, 'Decision history contains two entries');
    
    # First decision should still be in history
    is($ev_score->{decisions}[0]->{action}, 'attack', 'First decision preserved in history');
};

# Test system integration with ECS update
subtest 'System Integration with ECS' => sub {
    my $ecs = Iterum::ECS->new();
    
    Iterum::Components::Health::register($ecs);
    Iterum::Components::CombatStats::register($ecs);
    Iterum::Components::EVScore::register($ecs);
    
    my $ev_system = Iterum::Systems::EVScoring->new(
        ecs => $ecs,
    );
    
    $ecs->add_system($ev_system);
    
    # Create player with EVScore
    my $player_id = $ecs->new_entity('player');
    Iterum::Components::EVScore::add($ecs, $player_id);
    
    # ECS update should not cause errors
    try {
        $ecs->update();
        pass('ECS update with EVScoring system works');
    } catch ($e) {
        fail("ECS update failed: $e");
    }
};

done_testing;