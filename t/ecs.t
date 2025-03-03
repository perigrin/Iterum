use 5.40.0;
use Test2::V0;
use FindBin qw($Bin);
use lib "$Bin/../lib";

use Iterum::ECS;

# Test entity creation
subtest 'Entity Creation' => sub {
    my $ecs       = Iterum::ECS->new();
    my $entity_id = $ecs->new_entity('test_entity');
    ok( $entity_id, 'Entity ID was created' );

    # Test that adding components works, which implies the entity exists
    $ecs->new_component_type( 'TestComponent', 'A test component', {} );
    $ecs->add_component( $entity_id, 'TestComponent', { value => 'test' } );
    my ($component) = $ecs->get_components( $entity_id, 'TestComponent' );
    is( $component->{value}, 'test', 'Component added to entity successfully' );
};

# Test component creation
subtest 'Component Creation' => sub {
    my $ecs = Iterum::ECS->new();
    my $component_id =
      $ecs->new_component_type( 'TestComponent', 'A test component', {} );
    ok( $component_id, 'Component type was created' );

    my $retrieved_id = $ecs->get_id_for_component_type('TestComponent');
    is( $retrieved_id, $component_id, 'Component ID can be retrieved by type' );
};

# Test entity-component relationships
subtest 'Entity-Component Relationships' => sub {
    my $ecs       = Iterum::ECS->new();
    my $entity_id = $ecs->new_entity('test_entity');
    $ecs->new_component_type( 'TestComponent', 'A test component', {} );
    $ecs->add_component( $entity_id, 'TestComponent', { value => 'test' } );

    my @entities = $ecs->entities_for_components('TestComponent');
    is( \@entities, [$entity_id], 'Entity can be found by component' );

    $ecs->remove_components( $entity_id, 'TestComponent' );
    @entities = $ecs->entities_for_components('TestComponent');
    is( \@entities, [], 'Component was removed from entity' );
};

# Test system management
subtest 'System Management' => sub {

    package TestSystem {
        sub new                 { bless {}, shift }
        sub components_required { return ('TestComponent') }
        sub set_entities        { shift->{entities} = [@_] }
        sub update              { shift->{updated}  = 1 }
    }

    my $ecs = Iterum::ECS->new();
    $ecs->new_component_type( 'TestComponent', 'A test component', {} );
    my $system = TestSystem->new();
    $ecs->add_system($system);

    my $entity_id = $ecs->new_entity('test_entity');
    $ecs->add_component( $entity_id, 'TestComponent', { value => 'test' } );

    $ecs->update();
    ok( $system->{updated}, 'System was updated' );

    $ecs->remove_system($system);

    # Reset updated flag
    $system->{updated} = 0;
    $ecs->update();
    ok( !$system->{updated}, 'System was removed and not updated' );
};

# Test entity destruction
subtest 'Entity Destruction' => sub {
    my $ecs       = Iterum::ECS->new();
    my $entity_id = $ecs->new_entity('test_entity');
    $ecs->new_component_type( 'TestComponent', 'A test component', {} );
    $ecs->add_component( $entity_id, 'TestComponent', { value => 'test' } );

    $ecs->destroy_entity($entity_id);
    my @entities = $ecs->entities_for_components('TestComponent');
    is( \@entities, [], 'Entity was destroyed' );
};

done_testing;
