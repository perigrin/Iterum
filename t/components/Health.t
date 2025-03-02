use 5.40.0;
use Test2::V0;
use FindBin qw($Bin);
use lib "$Bin/../../lib";

use Iterum::ECS;
use Iterum::Components::Health;

# Test component registration
subtest 'Component Registration' => sub {
    my $ecs          = Iterum::ECS->new();
    my $component_id = Iterum::Components::Health::register($ecs);
    ok( $component_id, 'Health component type was registered' );

    my $retrieved_id = $ecs->get_id_for_component_type('Health');
    is( $retrieved_id, $component_id, 'Component ID can be retrieved by type' );
};

# Test adding health component with default values
subtest 'Default Health Values' => sub {
    my $ecs = Iterum::ECS->new();
    Iterum::Components::Health::register($ecs);

    my $entity_id = $ecs->new_entity('test_entity');
    Iterum::Components::Health::add( $ecs, $entity_id );

    my ($health) = $ecs->get_components( $entity_id, 'Health' );
    is( $health->{max_hp},     100, 'Default max HP is 100' );
    is( $health->{current_hp}, 100, 'Default current HP is 100' );
};

# Test adding health component with custom values
subtest 'Custom Health Values' => sub {
    my $ecs = Iterum::ECS->new();
    Iterum::Components::Health::register($ecs);

    my $entity_id = $ecs->new_entity('test_entity');
    Iterum::Components::Health::add(
        $ecs, $entity_id,
        max_hp     => 200,
        current_hp => 150
    );

    my ($health) = $ecs->get_components( $entity_id, 'Health' );
    is( $health->{max_hp},     200, 'Custom max HP is set correctly' );
    is( $health->{current_hp}, 150, 'Custom current HP is set correctly' );
};

# Test validation
subtest 'Health Validation' => sub {
    my $ecs = Iterum::ECS->new();
    Iterum::Components::Health::register($ecs);

    my $entity_id = $ecs->new_entity('test_entity');

    # Test negative HP validation
    like(
        dies {
            Iterum::Components::Health::add( $ecs, $entity_id, max_hp => -50 )
        },
        qr/max_hp must be positive/,
        'Negative max_hp throws error'
    );

    like(
        dies {
            Iterum::Components::Health::add( $ecs, $entity_id,
                current_hp => -10 )
        },
        qr/current_hp cannot be negative/,
        'Negative current_hp throws error'
    );

    # Test current_hp > max_hp validation
    like(
        dies {
            Iterum::Components::Health::add(
                $ecs, $entity_id,
                max_hp     => 50,
                current_hp => 100
            )
        },
        qr/current_hp cannot exceed max_hp/,
        'current_hp exceeding max_hp throws error'
    );
};

# Test health modification
subtest 'Health Modification' => sub {
    my $ecs = Iterum::ECS->new();
    Iterum::Components::Health::register($ecs);

    my $entity_id = $ecs->new_entity('test_entity');
    Iterum::Components::Health::add(
        $ecs, $entity_id,
        max_hp     => 100,
        current_hp => 100
    );

    # Test damage
    Iterum::Components::Health::damage( $ecs, $entity_id, 30 );
    my ($health) = $ecs->get_components( $entity_id, 'Health' );
    is( $health->{current_hp}, 70, 'Damage reduces current HP correctly' );

    # Test overkill damage (shouldn't go below 0)
    Iterum::Components::Health::damage( $ecs, $entity_id, 100 );
    ($health) = $ecs->get_components( $entity_id, 'Health' );
    is( $health->{current_hp}, 0, 'Damage does not reduce HP below 0' );

    # Test healing
    Iterum::Components::Health::heal( $ecs, $entity_id, 50 );
    ($health) = $ecs->get_components( $entity_id, 'Health' );
    is( $health->{current_hp}, 50, 'Healing increases current HP correctly' );

    # Test overheal (shouldn't go above max_hp)
    Iterum::Components::Health::heal( $ecs, $entity_id, 100 );
    ($health) = $ecs->get_components( $entity_id, 'Health' );
    is( $health->{current_hp}, 100,
        'Healing does not increase HP above max_hp' );
};

# Test health status checks
subtest 'Health Status Checks' => sub {
    my $ecs = Iterum::ECS->new();
    Iterum::Components::Health::register($ecs);

    my $entity_id = $ecs->new_entity('test_entity');
    Iterum::Components::Health::add(
        $ecs, $entity_id,
        max_hp     => 100,
        current_hp => 100
    );

    ok( Iterum::Components::Health::is_alive( $ecs, $entity_id ),
        'Entity is alive at full health' );
    ok( Iterum::Components::Health::is_full_health( $ecs, $entity_id ),
        'Entity is at full health' );

    Iterum::Components::Health::damage( $ecs, $entity_id, 50 );
    ok( Iterum::Components::Health::is_alive( $ecs, $entity_id ),
        'Entity is still alive at half health' );
    ok( !Iterum::Components::Health::is_full_health( $ecs, $entity_id ),
        'Entity is not at full health after damage' );

    Iterum::Components::Health::damage( $ecs, $entity_id, 50 );
    ok( !Iterum::Components::Health::is_alive( $ecs, $entity_id ),
        'Entity is not alive at 0 health' );
};

done_testing;
