use 5.40.0;

package Iterum::Components::Position;

# Position component for Iterum ECS
# Handles entity position in 2D space for movement, collision, etc.

use Carp qw(croak);

# Register the Position component type in the ECS
sub register ($ecs) {
    return $ecs->new_component_type( 'Position',
        'Tracks entity position in 2D space', {} );
}

# Add Position component to an entity with default or custom values
sub add ( $ecs, $entity_id, %options ) {

    # Default values
    my $x = $options{x} // 0;
    my $y = $options{y} // 0;

    # Validation
    croak "x must be numeric" unless $x =~ /^-?\d+(?:\.\d+)?$/;
    croak "y must be numeric" unless $y =~ /^-?\d+(?:\.\d+)?$/;

    $ecs->add_component(
        $entity_id,
        'Position',
        {
            x => $x,
            y => $y,
        }
    );
}

# Move entity by delta x and y
sub move ( $ecs, $entity_id, $dx, $dy ) {

    # Validation
    croak "dx must be numeric" unless $dx =~ /^-?\d+(?:\.\d+)?$/;
    croak "dy must be numeric" unless $dy =~ /^-?\d+(?:\.\d+)?$/;

    my ($position) = $ecs->get_components( $entity_id, 'Position' );
    croak "Entity does not have a Position component" unless $position;

    $ecs->add_component(
        $entity_id,
        'Position',
        {
            x => $position->{x} + $dx,
            y => $position->{y} + $dy,
        }
    );
}

# Set absolute position
sub set_position ( $ecs, $entity_id, $x, $y ) {

    # Validation
    croak "x must be numeric" unless $x =~ /^-?\d+(?:\.\d+)?$/;
    croak "y must be numeric" unless $y =~ /^-?\d+(?:\.\d+)?$/;

    my ($position) = $ecs->get_components( $entity_id, 'Position' );
    croak "Entity does not have a Position component" unless $position;

    $ecs->add_component(
        $entity_id,
        'Position',
        {
            x => $x,
            y => $y,
        }
    );
}

# Calculate distance between two entities
sub distance ( $ecs, $entity_id1, $entity_id2 ) {
    my ($pos1) = $ecs->get_components( $entity_id1, 'Position' );
    my ($pos2) = $ecs->get_components( $entity_id2, 'Position' );

    croak "First entity does not have a Position component"  unless $pos1;
    croak "Second entity does not have a Position component" unless $pos2;

    my $dx = $pos2->{x} - $pos1->{x};
    my $dy = $pos2->{y} - $pos1->{y};

    return sqrt( $dx * $dx + $dy * $dy );
}

# Check if two entities are adjacent (distance <= 1)
sub is_adjacent ( $ecs, $entity_id1, $entity_id2 ) {
    return distance( $ecs, $entity_id1, $entity_id2 ) <=
      1.5;    # Using 1.5 to account for diagonal moves
}

1;
