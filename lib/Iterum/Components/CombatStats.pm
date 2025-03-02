use 5.40.0;

package Iterum::Components::CombatStats;

# CombatStats component for Iterum ECS
# Handles entity attack and defense values, buffs/debuffs, and combat calculations

use Carp qw(croak);

# Register the CombatStats component type in the ECS
sub register ($ecs) {
    return $ecs->new_component_type(
        'CombatStats',
        'Stores combat-related statistics including attack and defense values',
        {}
    );
}

# Add CombatStats component to an entity with default or custom values
sub add ( $ecs, $entity_id, %options ) {

    # Default values
    my $attack  = $options{attack}  // 10;
    my $defense = $options{defense} // 5;

    # Validation
    croak "attack must be non-negative"  if $attack < 0;
    croak "defense must be non-negative" if $defense < 0;

    $ecs->add_component(
        $entity_id,
        'CombatStats',
        {
            attack        => $attack,
            defense       => $defense,
            defending     => 0,          # Flag for defensive stance
            attack_buffs  => [],         # Temporary attack modifiers
            defense_buffs => [],         # Temporary defense modifiers
        }
    );
}

# Calculate effective attack value (base + buffs)
sub effective_attack ( $ecs, $entity_id ) {
    my ($stats) = $ecs->get_components( $entity_id, 'CombatStats' );
    croak "Entity does not have a CombatStats component" unless $stats;

    my $total_attack = $stats->{attack};

    # Add buff values
    foreach my $buff ( @{ $stats->{attack_buffs} } ) {
        $total_attack += $buff->{value};
    }

    return $total_attack;
}

# Calculate effective defense value (base + buffs)
sub effective_defense ( $ecs, $entity_id ) {
    my ($stats) = $ecs->get_components( $entity_id, 'CombatStats' );
    croak "Entity does not have a CombatStats component" unless $stats;

    my $total_defense = $stats->{defense};

    # Add defense buffs
    foreach my $buff ( @{ $stats->{defense_buffs} } ) {
        $total_defense += $buff->{value};
    }

    # Apply defense boost if defending
    $total_defense *= 1.5 if $stats->{defending};

    return $total_defense;
}

# Add a temporary attack buff
sub add_attack_buff ( $ecs, $entity_id, $buff ) {
    croak "Buff must be a hash reference" unless ref $buff eq 'HASH';
    croak "Buff must have a value"        unless defined $buff->{value};
    croak "Buff value must be numeric"
      unless $buff->{value} =~ /^-?\d+(?:\.\d+)?$/;
    croak "Buff must have a duration" unless defined $buff->{duration};
    croak "Buff duration must be a positive integer"
      unless $buff->{duration} =~ /^\d+$/ && $buff->{duration} > 0;

    my ($stats) = $ecs->get_components( $entity_id, 'CombatStats' );
    croak "Entity does not have a CombatStats component" unless $stats;

    push @{ $stats->{attack_buffs} }, $buff;

    $ecs->add_component( $entity_id, 'CombatStats', $stats );
}

# Add a temporary defense buff
sub add_defense_buff ( $ecs, $entity_id, $buff ) {
    croak "Buff must be a hash reference" unless ref $buff eq 'HASH';
    croak "Buff must have a value"        unless defined $buff->{value};
    croak "Buff value must be numeric"
      unless $buff->{value} =~ /^-?\d+(?:\.\d+)?$/;
    croak "Buff must have a duration" unless defined $buff->{duration};
    croak "Buff duration must be a positive integer"
      unless $buff->{duration} =~ /^\d+$/ && $buff->{duration} > 0;

    my ($stats) = $ecs->get_components( $entity_id, 'CombatStats' );
    croak "Entity does not have a CombatStats component" unless $stats;

    push @{ $stats->{defense_buffs} }, $buff;

    $ecs->add_component( $entity_id, 'CombatStats', $stats );
}

# Update buff durations and remove expired buffs
sub update_buffs ( $ecs, $entity_id ) {
    my ($stats) = $ecs->get_components( $entity_id, 'CombatStats' );
    croak "Entity does not have a CombatStats component" unless $stats;

    # Process attack buffs
    my @active_attack_buffs;
    foreach my $buff ( @{ $stats->{attack_buffs} } ) {
        $buff->{duration}--;
        push @active_attack_buffs, $buff if $buff->{duration} > 0;
    }
    $stats->{attack_buffs} = \@active_attack_buffs;

    # Process defense buffs
    my @active_defense_buffs;
    foreach my $buff ( @{ $stats->{defense_buffs} } ) {
        $buff->{duration}--;
        push @active_defense_buffs, $buff if $buff->{duration} > 0;
    }
    $stats->{defense_buffs} = \@active_defense_buffs;

    $ecs->add_component( $entity_id, 'CombatStats', $stats );
}

# Set defending status
sub set_defending ( $ecs, $entity_id, $is_defending ) {
    my ($stats) = $ecs->get_components( $entity_id, 'CombatStats' );
    croak "Entity does not have a CombatStats component" unless $stats;

    $stats->{defending} = $is_defending ? 1 : 0;

    $ecs->add_component( $entity_id, 'CombatStats', $stats );
}

# Update base attack value
sub set_attack ( $ecs, $entity_id, $new_attack ) {
    croak "Attack must be non-negative" if $new_attack < 0;

    my ($stats) = $ecs->get_components( $entity_id, 'CombatStats' );
    croak "Entity does not have a CombatStats component" unless $stats;

    $stats->{attack} = $new_attack;

    $ecs->add_component( $entity_id, 'CombatStats', $stats );
}

# Update base defense value
sub set_defense ( $ecs, $entity_id, $new_defense ) {
    croak "Defense must be non-negative" if $new_defense < 0;

    my ($stats) = $ecs->get_components( $entity_id, 'CombatStats' );
    croak "Entity does not have a CombatStats component" unless $stats;

    $stats->{defense} = $new_defense;

    $ecs->add_component( $entity_id, 'CombatStats', $stats );
}

1;
