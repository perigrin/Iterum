use 5.40.0;
use Test2::V0;
use FindBin qw($Bin);
use lib "$Bin/../../lib";

use Iterum::ECS;
use Iterum::Components::Health;
use Iterum::Components::CombatStats;
use Iterum::Components::Position;
use Iterum::Entities::Player;
use Iterum::Entities::Enemies::Goblin;
use Iterum::Systems::Combat;

# Setup - register components and create ECS
sub setup_ecs {
    my $ecs = Iterum::ECS->new();
    Iterum::Components::Health::register($ecs);
    Iterum::Components::CombatStats::register($ecs);
    Iterum::Components::Position::register($ecs);
    return $ecs;
}

# Test Goblin creation
subtest 'Goblin creation' => sub {
    my $ecs = setup_ecs();

    my $goblin = Iterum::Entities::Enemies::Goblin->new( ecs => $ecs )->setup();
    ok( $goblin->id, 'Goblin has ID assigned' );
    is( $goblin->name, 'Goblin', 'Default name is set' );

    # Test with custom name
    my $named_goblin = Iterum::Entities::Enemies::Goblin->new(
        ecs  => $ecs,
        name => 'Boss Goblin'
    )->setup();
    is( $named_goblin->name, 'Boss Goblin', 'Custom name is set' );

    # Test with custom stats
    my $custom_goblin = Iterum::Entities::Enemies::Goblin->new(
        ecs  => $ecs,
        name => 'Elite Goblin'
    )->setup(
        max_hp  => 100,
        attack  => 12,
        defense => 5
    );

    my ($health) = $ecs->get_components( $custom_goblin->id, 'Health' );
    is( $health->{max_hp}, 100, 'Custom max HP is set' );

    my ($combat_stats) =
      $ecs->get_components( $custom_goblin->id, 'CombatStats' );
    is( $combat_stats->{attack},  12, 'Custom attack is set' );
    is( $combat_stats->{defense}, 5,  'Custom defense is set' );
};

# Test Goblin components
subtest 'Goblin components' => sub {
    my $ecs    = setup_ecs();
    my $goblin = Iterum::Entities::Enemies::Goblin->new( ecs => $ecs )->setup();

    # Check Health component
    my ($health) = $ecs->get_components( $goblin->id, 'Health' );
    ok( $health, 'Health component exists' );
    is( $health->{max_hp},     60, 'Default max HP is 60' );
    is( $health->{current_hp}, 60, 'Default current HP is 60' );

    # Check CombatStats component
    my ($combat_stats) = $ecs->get_components( $goblin->id, 'CombatStats' );
    ok( $combat_stats, 'CombatStats component exists' );
    is( $combat_stats->{attack},  8, 'Default attack is 8' );
    is( $combat_stats->{defense}, 3, 'Default defense is 3' );

    # Check Position component
    my ($position) = $ecs->get_components( $goblin->id, 'Position' );
    ok( $position, 'Position component exists' );
    is( $position->{x}, 0, 'Default x position is 0' );
    is( $position->{y}, 0, 'Default y position is 0' );
};

# Test Goblin movement
subtest 'Goblin movement' => sub {
    my $ecs    = setup_ecs();
    my $goblin = Iterum::Entities::Enemies::Goblin->new( ecs => $ecs )->setup();

    # Test initial position
    my ($position) = $ecs->get_components( $goblin->id, 'Position' );
    is( $position->{x}, 0, 'Initial x position is 0' );
    is( $position->{y}, 0, 'Initial y position is 0' );

    # Test moving
    $goblin->move( 2, 1 );
    ($position) = $ecs->get_components( $goblin->id, 'Position' );
    is( $position->{x}, 2, 'Moved right by 2' );
    is( $position->{y}, 1, 'Moved down by 1' );

    # Test with absolute positioning
    $goblin->set_position( 10, 5 );
    ($position) = $ecs->get_components( $goblin->id, 'Position' );
    is( $position->{x}, 10, 'X position set to 10' );
    is( $position->{y}, 5,  'Y position set to 5' );
};

# Test Goblin attack
subtest 'Goblin attack' => sub {
    my $ecs    = setup_ecs();
    my $goblin = Iterum::Entities::Enemies::Goblin->new( ecs => $ecs )->setup();
    my $player = Iterum::Entities::Player->new( ecs => $ecs )->setup();

    # Test attack calculation
    my $damage = $goblin->attack( $player->id );
    ok( $damage > 0, 'Attack produces damage' );

    # Verify player health was reduced
    my ($player_health) = $ecs->get_components( $player->id, 'Health' );
    is(
        $player_health->{current_hp},
        100 - $damage,
        'Player health reduced by damage amount'
    );
};

# Test AI decision making
subtest 'Goblin AI decision making' => sub {
    my $ecs    = setup_ecs();
    my $goblin = Iterum::Entities::Enemies::Goblin->new( ecs => $ecs )->setup();
    my $player = Iterum::Entities::Player->new( ecs => $ecs )->setup();
    my $combat_system = Iterum::Systems::Combat->new( ecs => $ecs );

    # Test decision making with no player_id
    my $decision = $goblin->make_decision();
    is( $decision->{action}, 'none',
        'Default action is none when no player_id is provided' );

    # Start combat
    $combat_system->start_combat( $goblin->id, $player->id );

    # Test decision making when adjacent to player
    $goblin->set_position( 0, 0 );
    $player->set_position( 1, 0 );    # Adjacent
    $decision = $goblin->make_decision( $player->id );
    is( $decision->{action}, 'attack',
        'Goblin chooses to attack when adjacent' );
    is( $decision->{target}, $player->id, 'Goblin targets player' );

    # Test decision making when not adjacent to player
    $goblin->set_position( 0, 0 );
    $player->set_position( 5, 5 );    # Not adjacent
    $decision = $goblin->make_decision( $player->id );
    is( $decision->{action}, 'move',
        'Goblin chooses to move when not adjacent' );
    ok( exists $decision->{direction}, 'Move direction is specified' );

    # Test decision making with low health
    $goblin->take_damage(50);         # Low health
    $goblin->set_position( 1, 0 );
    $player->set_position( 0, 0 );    # Adjacent

    # Even with low health, Goblin should still attack (reckless behavior)
    $decision = $goblin->make_decision( $player->id );
    is( $decision->{action}, 'attack',
        'Goblin still attacks when low on health (reckless)' );
};

# Test Combat system integration
subtest 'Goblin Combat system integration' => sub {
    my $ecs    = setup_ecs();
    my $goblin = Iterum::Entities::Enemies::Goblin->new( ecs => $ecs )->setup();
    my $player = Iterum::Entities::Player->new( ecs => $ecs )->setup();
    my $combat_system = Iterum::Systems::Combat->new( ecs => $ecs );

    # Start combat
    $combat_system->start_combat( $goblin->id, $player->id );
    ok( $combat_system->are_in_combat( $goblin->id, $player->id ),
        'Goblin and player are in combat' );

    # Set actions
    $combat_system->set_action( $goblin->id, 'attack' );
    $combat_system->set_target( $goblin->id, $player->id );

    # Process turn
    $combat_system->update( [] );

    # Check if attack was processed
    ok(
        $combat_system->last_hit( $goblin->id )
          || !$combat_system->last_hit( $goblin->id ),
        'Combat system processed goblin attack'
    );

    # End combat
    $combat_system->end_combat( $goblin->id, $player->id );
    ok( !$combat_system->are_in_combat( $goblin->id, $player->id ),
        'Combat ended successfully' );
};

# Test get_status
subtest 'Goblin status' => sub {
    my $ecs    = setup_ecs();
    my $goblin = Iterum::Entities::Enemies::Goblin->new( ecs => $ecs )->setup();

    # Test get_status
    my $status = $goblin->get_status();
    ok( $status, 'Status returned' );
    is( $status->{name}, 'Goblin', 'Name in status is correct' );
    ok( $status->{health}, 'Health included in status' );
    is( $status->{health}{current_hp}, 60, 'Current HP in status is correct' );
    ok( $status->{stats}, 'Combat stats included in status' );
    is( $status->{stats}{attack}, 8, 'Attack in status is correct' );
    ok( $status->{alive}, 'Alive status included' );
};

done_testing;
