use 5.40.0;

package Iterum::Components::Health;

# Health component for Iterum ECS
# Handles entity health points, damage, healing, and status checks

use Carp qw(croak);

# Register the Health component type in the ECS
sub register ($ecs) {
    return $ecs->new_component_type( 'Health',
        'Tracks entity health points, damage, and healing', {} );
}

# Add Health component to an entity with default or custom values
sub add ( $ecs, $entity_id, %options ) {

    # Default values
    my $max_hp     = $options{max_hp}     // 100;
    my $current_hp = $options{current_hp} // $max_hp;

    # Validation
    croak "max_hp must be positive"         if $max_hp <= 0;
    croak "current_hp cannot be negative"   if $current_hp < 0;
    croak "current_hp cannot exceed max_hp" if $current_hp > $max_hp;

    $ecs->add_component(
        $entity_id,
        'Health',
        {
            max_hp     => $max_hp,
            current_hp => $current_hp,
        }
    );
}

# Apply damage to an entity
sub damage ( $ecs, $entity_id, $amount ) {
    croak "Damage amount must be non-negative" if $amount < 0;

    my ($health) = $ecs->get_components( $entity_id, 'Health' );
    croak "Entity does not have a Health component" unless $health;

    my $new_hp = $health->{current_hp} - $amount;
    $new_hp = 0 if $new_hp < 0;    # Don't go below 0

    $ecs->add_component(
        $entity_id,
        'Health',
        {
            %$health, current_hp => $new_hp,
        }
    );

    return $new_hp;
}

# Heal an entity
sub heal ( $ecs, $entity_id, $amount ) {
    croak "Heal amount must be non-negative" if $amount < 0;

    my ($health) = $ecs->get_components( $entity_id, 'Health' );
    croak "Entity does not have a Health component" unless $health;

    my $new_hp = $health->{current_hp} + $amount;
    $new_hp = $health->{max_hp}
      if $new_hp > $health->{max_hp};    # Don't exceed max_hp

    $ecs->add_component(
        $entity_id,
        'Health',
        {
            %$health, current_hp => $new_hp,
        }
    );

    return $new_hp;
}

# Check if entity is alive (hp > 0)
sub is_alive ( $ecs, $entity_id ) {
    my ($health) = $ecs->get_components( $entity_id, 'Health' );
    croak "Entity does not have a Health component" unless $health;

    return $health->{current_hp} > 0;
}

# Check if entity is at full health
sub is_full_health ( $ecs, $entity_id ) {
    my ($health) = $ecs->get_components( $entity_id, 'Health' );
    croak "Entity does not have a Health component" unless $health;

    return $health->{current_hp} == $health->{max_hp};
}

# Get health percentage (0-100)
sub health_percentage ( $ecs, $entity_id ) {
    my ($health) = $ecs->get_components( $entity_id, 'Health' );
    croak "Entity does not have a Health component" unless $health;

    return 0 if $health->{max_hp} == 0;    # Prevent division by zero
    return int( ( $health->{current_hp} / $health->{max_hp} ) * 100 );
}

# Set max health (and optionally current health)
sub set_max_health ( $ecs, $entity_id, $new_max, $adjust_current = 1 ) {
    croak "Max health must be positive" if $new_max <= 0;

    my ($health) = $ecs->get_components( $entity_id, 'Health' );
    croak "Entity does not have a Health component" unless $health;

    my $new_current = $health->{current_hp};

    # If adjusting current health proportionally
    if ($adjust_current) {
        my $percentage = $health->{current_hp} / $health->{max_hp};
        $new_current = int( $new_max * $percentage );
    }

    # Ensure current doesn't exceed new max
    $new_current = $new_max if $new_current > $new_max;

    $ecs->add_component(
        $entity_id,
        'Health',
        {
            %$health,
            max_hp     => $new_max,
            current_hp => $new_current,
        }
    );
}

1;
