use 5.40.0;
use Test2::V0;
use FindBin qw($Bin);
use lib "$Bin/../../../lib";

use Iterum::ECS;
use Iterum::UI::CLI;
use Iterum::Systems::UI::Display;

# Test UI Display System initialization
subtest 'Initialization' => sub {
    my $ecs = Iterum::ECS->new();
    my $cli = Iterum::UI::CLI->new( test_mode => 1 );

    my $ui_system = Iterum::Systems::UI::Display->new(
        ecs => $ecs,
        cli => $cli
    );

    ok( $ui_system isa Iterum::Systems::UI::Display,
        'UI System is correct class' );

    # Test that the UI System has the required methods
    can_ok( $ui_system, 'update', 'display_combat_options',
        'get_player_choice', 'display_combat_result' );
};

# Test UI System with mock entities
subtest 'UI System with entities' => sub {
    my $ecs = Iterum::ECS->new();
    my $cli = Iterum::UI::CLI->new( test_mode => 1 );

    # Create mock components
    $ecs->new_component_type( 'Health',      'Health component',       undef );
    $ecs->new_component_type( 'CombatStats', 'Combat stats component', undef );
    $ecs->new_component_type( 'Player',      'Player component',       undef );
    $ecs->new_component_type( 'Enemy',       'Enemy component',        undef );

    # Create mock entities
    my $player_id = $ecs->new_entity('player');
    $ecs->add_component( $player_id, 'Health',
        { current_hp => 80, max_hp => 100 } );
    $ecs->add_component( $player_id, 'CombatStats',
        { attack => 10, defense => 5 } );
    $ecs->add_component( $player_id, 'Player', {} );

    my $enemy_id = $ecs->new_entity('goblin');
    $ecs->add_component( $enemy_id, 'Health',
        { current_hp => 30, max_hp => 50 } );
    $ecs->add_component( $enemy_id, 'CombatStats',
        { attack => 8, defense => 3 } );
    $ecs->add_component( $enemy_id, 'Enemy', {} );

    # Create UI System
    my $ui_system = Iterum::Systems::UI::Display->new(
        ecs => $ecs,
        cli => $cli
    );

    # Test entity finding methods
    is( $ui_system->find_player_entity(), $player_id, 'Found player entity' );
    is( $ui_system->find_enemy_entity(),  $enemy_id,  'Found enemy entity' );

    # Test update with entities
    $ui_system->set_entities( $player_id, $enemy_id );
    ok( lives { $ui_system->update(undef) }, 'Update works with entities' );

    # Test combat options
    my @options = ( 'Attack', 'Defend', 'Use Item' );
    ok( $ui_system->display_combat_options(@options),
        'Display combat options works' );

    # Test player choice (with mock input)
    $cli->set_test_input('1');
    is( $ui_system->get_player_choice(@options),
        'Attack', 'Get player choice works' );

    # Test result display
    my $result = {
        action   => 'Attack',
        success  => 1,
        damage   => 8,
        ev_score => 0.75
    };
    ok( $ui_system->display_combat_result($result),
        'Display combat result works' );
};

done_testing();
