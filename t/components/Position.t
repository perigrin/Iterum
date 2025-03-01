use 5.40.0;
use Test2::V0;
use FindBin qw($Bin);
use lib "$Bin/../../lib";

use Iterum::ECS;
use Iterum::Components::Position;

# Test component registration
subtest 'Component Registration' => sub {
    my $ecs = Iterum::ECS->new();
    my $component_id = Iterum::Components::Position::register($ecs);
    ok($component_id, 'Position component type was registered');
    
    my $retrieved_id = $ecs->get_id_for_component_type('Position');
    is($retrieved_id, $component_id, 'Component ID can be retrieved by type');
};

# Test adding position component with default values
subtest 'Default Position Values' => sub {
    my $ecs = Iterum::ECS->new();
    Iterum::Components::Position::register($ecs);
    
    my $entity_id = $ecs->new_entity('test_entity');
    Iterum::Components::Position::add($ecs, $entity_id);
    
    my ($position) = $ecs->get_components($entity_id, 'Position');
    is($position->{x}, 0, 'Default x position is 0');
    is($position->{y}, 0, 'Default y position is 0');
};

# Test adding position component with custom values
subtest 'Custom Position Values' => sub {
    my $ecs = Iterum::ECS->new();
    Iterum::Components::Position::register($ecs);
    
    my $entity_id = $ecs->new_entity('test_entity');
    Iterum::Components::Position::add($ecs, $entity_id, x => 10, y => 20);
    
    my ($position) = $ecs->get_components($entity_id, 'Position');
    is($position->{x}, 10, 'Custom x position is set correctly');
    is($position->{y}, 20, 'Custom y position is set correctly');
};

# Test position modification
subtest 'Position Modification' => sub {
    my $ecs = Iterum::ECS->new();
    Iterum::Components::Position::register($ecs);
    
    my $entity_id = $ecs->new_entity('test_entity');
    Iterum::Components::Position::add($ecs, $entity_id, x => 5, y => 5);
    
    # Test move
    Iterum::Components::Position::move($ecs, $entity_id, 3, 4);
    my ($position) = $ecs->get_components($entity_id, 'Position');
    is($position->{x}, 8, 'X position updated correctly after move');
    is($position->{y}, 9, 'Y position updated correctly after move');
    
    # Test set_position
    Iterum::Components::Position::set_position($ecs, $entity_id, 15, 25);
    ($position) = $ecs->get_components($entity_id, 'Position');
    is($position->{x}, 15, 'X position set correctly');
    is($position->{y}, 25, 'Y position set correctly');
};

# Test distance calculation
subtest 'Distance Calculation' => sub {
    my $ecs = Iterum::ECS->new();
    Iterum::Components::Position::register($ecs);
    
    my $entity1 = $ecs->new_entity('entity1');
    my $entity2 = $ecs->new_entity('entity2');
    
    Iterum::Components::Position::add($ecs, $entity1, x => 0, y => 0);
    Iterum::Components::Position::add($ecs, $entity2, x => 3, y => 4);
    
    my $distance = Iterum::Components::Position::distance($ecs, $entity1, $entity2);
    is($distance, 5, 'Distance calculated correctly (3-4-5 triangle)');
    
    # Test adjacency
    ok(!Iterum::Components::Position::is_adjacent($ecs, $entity1, $entity2), 
        'Entities at distance 5 are not adjacent');
        
    Iterum::Components::Position::set_position($ecs, $entity2, 1, 0);
    ok(Iterum::Components::Position::is_adjacent($ecs, $entity1, $entity2), 
        'Entities at distance 1 are adjacent');
};

# Test validation
subtest 'Position Validation' => sub {
    my $ecs = Iterum::ECS->new();
    Iterum::Components::Position::register($ecs);
    
    my $entity_id = $ecs->new_entity('test_entity');
    
    # Test non-numeric position validation
    like(
        dies { Iterum::Components::Position::add($ecs, $entity_id, x => 'abc') },
        qr/x must be numeric/,
        'Non-numeric x throws error'
    );
    
    like(
        dies { Iterum::Components::Position::add($ecs, $entity_id, y => 'def') },
        qr/y must be numeric/,
        'Non-numeric y throws error'
    );
    
    # Add valid position first
    Iterum::Components::Position::add($ecs, $entity_id);
    
    # Test move validation
    like(
        dies { Iterum::Components::Position::move($ecs, $entity_id, 'abc', 1) },
        qr/dx must be numeric/,
        'Non-numeric dx throws error'
    );
    
    like(
        dies { Iterum::Components::Position::move($ecs, $entity_id, 1, 'def') },
        qr/dy must be numeric/,
        'Non-numeric dy throws error'
    );
};

done_testing;