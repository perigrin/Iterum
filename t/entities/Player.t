use 5.40.0;
use Test2::V0;
use FindBin qw($Bin);
use lib "$Bin/../../lib";

use Iterum::ECS;
use Iterum::Components::Health;
use Iterum::Components::CombatStats;
use Iterum::Components::Position;
use Iterum::Entities::Player;

# Setup - register components
sub setup_ecs {
    my $ecs = Iterum::ECS->new();
    Iterum::Components::Health::register($ecs);
    Iterum::Components::CombatStats::register($ecs);
    Iterum::Components::Position::register($ecs);
    return $ecs;
}

# Test Player creation
subtest 'Player creation' => sub {
    my $ecs = setup_ecs();

    my $player = Iterum::Entities::Player->new( ecs => $ecs )->setup();
    ok( $player->id, 'Player has ID assigned' );
    is( $player->name, 'Adventurer', 'Default name is set' );

    # Test with custom name
    my $named_player = Iterum::Entities::Player->new(
        ecs  => $ecs,
        name => 'TestHero'
    )->setup();
    is( $named_player->name, 'TestHero', 'Custom name is set' );

    # Test with custom stats
    my $custom_player = Iterum::Entities::Player->new(
        ecs  => $ecs,
        name => 'StrongHero'
    )->setup(
        max_hp  => 150,
        attack  => 15,
        defense => 8
    );

    my ($health) = $ecs->get_components( $custom_player->id, 'Health' );
    is( $health->{max_hp}, 150, 'Custom max HP is set' );

    my ($combat_stats) =
      $ecs->get_components( $custom_player->id, 'CombatStats' );
    is( $combat_stats->{attack},  15, 'Custom attack is set' );
    is( $combat_stats->{defense}, 8,  'Custom defense is set' );
};

# Test Player components
subtest 'Player components' => sub {
    my $ecs    = setup_ecs();
    my $player = Iterum::Entities::Player->new( ecs => $ecs )->setup();

    # Check Health component
    my ($health) = $ecs->get_components( $player->id, 'Health' );
    ok( $health, 'Health component exists' );
    is( $health->{max_hp},     100, 'Default max HP is 100' );
    is( $health->{current_hp}, 100, 'Default current HP is 100' );

    # Check CombatStats component
    my ($combat_stats) = $ecs->get_components( $player->id, 'CombatStats' );
    ok( $combat_stats, 'CombatStats component exists' );
    is( $combat_stats->{attack},  10, 'Default attack is 10' );
    is( $combat_stats->{defense}, 5,  'Default defense is 5' );

    # Check Position component (needed for movement)
    my ($position) = $ecs->get_components( $player->id, 'Position' );
    ok( $position, 'Position component exists' );
    is( $position->{x}, 0, 'Default x position is 0' );
    is( $position->{y}, 0, 'Default y position is 0' );
};

# Test Player movement
subtest 'Player movement' => sub {
    my $ecs    = setup_ecs();
    my $player = Iterum::Entities::Player->new( ecs => $ecs )->setup();

    # Test initial position
    my ($position) = $ecs->get_components( $player->id, 'Position' );
    is( $position->{x}, 0, 'Initial x position is 0' );
    is( $position->{y}, 0, 'Initial y position is 0' );

    # Test moving right
    $player->move( 1, 0 );
    ($position) = $ecs->get_components( $player->id, 'Position' );
    is( $position->{x}, 1, 'Moved right by 1' );
    is( $position->{y}, 0, 'Y position unchanged' );

    # Test moving diagonally
    $player->move( 1, 1 );
    ($position) = $ecs->get_components( $player->id, 'Position' );
    is( $position->{x}, 2, 'Moved right by 1 more' );
    is( $position->{y}, 1, 'Moved down by 1' );

    # Test with absolute positioning
    $player->set_position( 5, 5 );
    ($position) = $ecs->get_components( $player->id, 'Position' );
    is( $position->{x}, 5, 'X position set to 5' );
    is( $position->{y}, 5, 'Y position set to 5' );

    # Test invalid movement (non-numeric coordinates)
    like(
        dies { $player->move( 'a', 0 ) },
        qr/dx must be numeric/,
        'Non-numeric dx throws error'
    );

    like(
        dies { $player->move( 0, 'b' ) },
        qr/dy must be numeric/,
        'Non-numeric dy throws error'
    );
};

# Test Player attack
subtest 'Player attack' => sub {
    my $ecs    = setup_ecs();
    my $player = Iterum::Entities::Player->new( ecs => $ecs )->setup();

    # Create a test enemy
    my $enemy_id = $ecs->new_entity('test_enemy');
    Iterum::Components::Health::add( $ecs, $enemy_id, max_hp => 50 );
    Iterum::Components::CombatStats::add( $ecs, $enemy_id, defense => 2 );

    # Test attack calculation
    my $damage = $player->attack($enemy_id);
    ok( $damage > 0, 'Attack produces damage' );

    # Verify enemy health was reduced
    my ($enemy_health) = $ecs->get_components( $enemy_id, 'Health' );
    is(
        $enemy_health->{current_hp},
        50 - $damage,
        'Enemy health reduced by damage amount'
    );

    # Test attacking entity without Health
    my $no_health_id = $ecs->new_entity('no_health');
    like(
        dies { $player->attack($no_health_id) },
        qr/Target entity does not have a Health component/,
        'Attacking entity without Health throws error'
    );

# Test non-existent entity ID - it will fail with the same error as an entity without Health
    like(
        dies { $player->attack('invalid_id') },
        qr/Target entity does not have a Health component/,
        'Attacking invalid entity throws error'
    );
};

# Test Player defend
subtest 'Player defend' => sub {
    my $ecs    = setup_ecs();
    my $player = Iterum::Entities::Player->new( ecs => $ecs )->setup();

    # Test defend action
    ok( $player->defend(), 'Defend action returns true' );

    # Verify defense bonus applied
    my ($combat_stats) = $ecs->get_components( $player->id, 'CombatStats' );
    ok( $combat_stats->{defending}, 'Defending flag set' );

    # Test effective defense increases
    is(
        Iterum::Components::CombatStats::effective_defense( $ecs, $player->id ),
        7.5,    # Default 5 * 1.5
        'Defense is increased by 50% when defending'
    );

    # Test resetting defend status
    $player->end_defend();
    ($combat_stats) = $ecs->get_components( $player->id, 'CombatStats' );
    ok( !$combat_stats->{defending}, 'Defending flag cleared' );
};

# Test get_status
subtest 'Player status' => sub {
    my $ecs    = setup_ecs();
    my $player = Iterum::Entities::Player->new( ecs => $ecs )->setup();

    # Test get_status
    my $status = $player->get_status();
    ok( $status, 'Status returned' );
    is( $status->{name}, 'Adventurer', 'Name in status is correct' );
    ok( $status->{health}, 'Health included in status' );
    is( $status->{health}{current_hp}, 100, 'Current HP in status is correct' );
    ok( $status->{stats}, 'Combat stats included in status' );
    is( $status->{stats}{attack}, 10, 'Attack in status is correct' );
    ok( $status->{position}, 'Position included in status' );
    is( $status->{position}{x}, 0, 'X position in status is correct' );
};

# Test damage and healing
subtest 'Player damage and healing' => sub {
    my $ecs    = setup_ecs();
    my $player = Iterum::Entities::Player->new( ecs => $ecs )->setup();

    # Test taking damage
    $player->take_damage(30);
    my ($health) = $ecs->get_components( $player->id, 'Health' );
    is( $health->{current_hp}, 70,
        'Player health reduced after taking damage' );

    # Test healing
    $player->heal(15);
    ($health) = $ecs->get_components( $player->id, 'Health' );
    is( $health->{current_hp}, 85, 'Player health increased after healing' );

    # Test full heal
    $player->heal(100);    # More than needed to reach max
    ($health) = $ecs->get_components( $player->id, 'Health' );
    is( $health->{current_hp}, 100,
        'Player health capped at max_hp after healing' );

    # Test death
    $player->take_damage(200);    # More than current health
    ($health) = $ecs->get_components( $player->id, 'Health' );
    is( $health->{current_hp}, 0,
        'Player health reduced to 0 on lethal damage' );
    ok( !Iterum::Components::Health::is_alive( $ecs, $player->id ),
        'Player is not alive after lethal damage' );
};

done_testing;
