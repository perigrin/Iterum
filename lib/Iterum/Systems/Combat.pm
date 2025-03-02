use 5.40.0;

use experimental 'class';
use Iterum::Systems::EVScoring;
use Iterum::Components::EVScore;

# Combat system for Iterum ECS
# Handles entity combat interactions, turns, and damage calculations

class Iterum::Systems::Combat {
    use Carp qw(croak);

    field $ecs :param :reader;    # ECS instance
    field @entities;              # Current entities in the system
    field %combatants;            # Maps entities to their opponents
    field %actions;               # Current entity actions (attack, defend)
    field %targets;               # Current entity targets for attacks
    field %last_hit;              # Records if the last attack hit
    field %last_damage;           # Records damage dealt in last attack

    field $ev_system = Iterum::Systems::EVScoring->new( ecs => $ecs, );

    # Return the required components for this system
    method components_required {
        return ( 'Health', 'CombatStats' );
    }

    # Set entities for this system (called by ECS)
    method set_entities(@entity_ids) {
        @entities = @entity_ids;
    }

    # Update method called by the ECS each cycle
    method update($components_array) {

        # Process each entity's combat action
        foreach my $entity_id (@entities) {

            # Skip entities not in combat
            next unless $self->is_in_combat($entity_id);

            # Get the action for this entity
            my $action = $actions{$entity_id} // 'none';

            # Process different actions
            if ( $action eq 'attack' ) {
                $self->process_attack($entity_id);
            }
            elsif ( $action eq 'defend' ) {
                $self->process_defend($entity_id);
            }

            # Reset defending status if not defending this turn
            if ( $action ne 'defend' ) {
                my ($stats) = $ecs->get_components( $entity_id, 'CombatStats' );
                if ( $stats->{defending} ) {
                    Iterum::Components::CombatStats::set_defending( $ecs,
                        $entity_id, 0 );
                }
            }

            # Update temporary buffs
            Iterum::Components::CombatStats::update_buffs( $ecs, $entity_id );
        }

        # Reset actions for next turn
        %actions = ();
        %targets = ();
    }

    # Start combat between two entities
    method start_combat( $entity1, $entity2 ) {

        # Verify both entities have required components
        foreach my $entity ( $entity1, $entity2 ) {
            my ( $health, $stats ) =
              $ecs->get_components( $entity, 'Health', 'CombatStats' );
            croak "Entity does not have required components"
              unless $health && $stats;
        }

        # Add entities to combatants hash
        $combatants{$entity1}{$entity2} = 1;
        $combatants{$entity2}{$entity1} = 1;

        return 1;
    }

    # End combat between two entities
    method end_combat( $entity1, $entity2 ) {
        delete $combatants{$entity1}{$entity2};
        delete $combatants{$entity2}{$entity1};

        # Clean up empty entries
        delete $combatants{$entity1} unless keys %{ $combatants{$entity1} };
        delete $combatants{$entity2} unless keys %{ $combatants{$entity2} };

        # Reset any ongoing actions for these entities
        delete $actions{$entity1};
        delete $actions{$entity2};
        delete $targets{$entity1};
        delete $targets{$entity2};

        return 1;
    }

    # End all combats
    method end_all_combats {
        %combatants  = ();
        %actions     = ();
        %targets     = ();
        %last_hit    = ();
        %last_damage = ();
    }

    # Check if entity is in combat
    method is_in_combat($entity) {
        return exists $combatants{$entity} && keys %{ $combatants{$entity} };
    }

    # Check if two entities are in combat with each other
    method are_in_combat( $entity1, $entity2 ) {
        return ( exists $combatants{$entity1}
              && exists $combatants{$entity1}{$entity2} );
    }

    # Get all entities an entity is in combat with
    method get_opponents($entity) {
        return
          exists $combatants{$entity} ? keys %{ $combatants{$entity} } : ();
    }

    # Set an action for an entity
    method set_action( $entity, $action ) {
        croak "Invalid action: $action"
          unless $action =~ /^(attack|defend|none)$/;
        $actions{$entity} = $action;

        # If there's a target, record the EV score for this decision
        if ( $action ne 'none' && exists $targets{$entity} ) {

            # Only record EV score if entity has EVScore component
            my ($ev_component) = $ecs->get_components( $entity, 'EVScore' );
            if ($ev_component) {
                $ev_system->record_decision( $entity, $targets{$entity},
                    $action );
            }
        }
        elsif ( $action eq 'defend' ) {

            # Defend doesn't need a target
            # Only record EV score if entity has EVScore component
            my ($ev_component) = $ecs->get_components( $entity, 'EVScore' );
            if ($ev_component) {
                $ev_system->record_decision( $entity, $entity, $action );
            }
        }
    }

    # Set a target for an entity
    method set_target( $entity, $target ) {
        $targets{$entity} = $target;
    }

    # Process an attack action
    method process_attack($attacker) {

        # Ensure there's a target
        my $target = $targets{$attacker};
        return unless $target;

        # Ensure attacker and target are in combat
        return unless $self->are_in_combat( $attacker, $target );

        # Calculate attack result
        my ( $hit, $damage ) = $self->calculate_attack( $attacker, $target );

        # Record results
        $last_hit{$attacker}    = $hit;
        $last_damage{$attacker} = $damage;

        # Apply damage if hit
        if ($hit) {
            $self->apply_damage( $target, $damage );
        }
    }

    # Process a defend action
    method process_defend($entity) {
        Iterum::Components::CombatStats::set_defending( $ecs, $entity, 1 );
    }

    # Calculate attack result
    method calculate_attack( $attacker, $defender ) {

        # Get attacker's attack value
        my $attack =
          Iterum::Components::CombatStats::effective_attack( $ecs, $attacker );

        # Get defender's defense value
        my $defense =
          Iterum::Components::CombatStats::effective_defense( $ecs, $defender );

        # Calculate hit chance (simple model: 75% base chance)
        my $hit_chance = 0.75;

        # Adjust hit chance based on attack vs defense
        if ( $attack > $defense ) {
            $hit_chance += 0.1;    # Bonus when attack > defense
        }
        elsif ( $defense > $attack ) {
            $hit_chance -= 0.1;    # Penalty when defense > attack
        }

        # Determine if attack hits
        my $hit = rand() < $hit_chance;

        # Calculate damage if hit
        my $damage = 0;
        if ($hit) {
            $damage = $attack - $defense;
            $damage = 1 if $damage < 1;     # Minimum damage of 1
        }

        return ( $hit, $damage );
    }

    # Apply damage to an entity
    method apply_damage( $entity, $damage ) {
        return Iterum::Components::Health::damage( $ecs, $entity, $damage );
    }

    # Check if the last attack hit
    method last_hit($entity) {
        return $last_hit{$entity} // 0;
    }

    # Get damage from last attack
    method last_damage($entity) {
        return $last_damage{$entity} // 0;
    }

    # Add a new method to get decision statistics and feedback
    method get_player_feedback($player_id) {

        # Check if player has EVScore component
        my ($ev_component) = $ecs->get_components( $player_id, 'EVScore' );
        return "No decision history available" unless $ev_component;

        return $ev_system->generate_feedback($player_id);
    }

    # Add a method to get the optimal action
    method get_optimal_action( $entity_id, $target_id ) {

        # Check if entity has EVScore component
        my ($ev_component) = $ecs->get_components( $entity_id, 'EVScore' );
        return ( 'attack', 50, { attack => 50, defend => 40 } )
          unless $ev_component;

        return $ev_system->get_optimal_action( $entity_id, $target_id,
            qw(attack defend) );
    }
}

