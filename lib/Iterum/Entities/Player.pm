use 5.40.0;

package Iterum::Entities::Player;

use experimental 'class';
use Carp qw(croak);

# Player entity for Iterum roguelike
# Represents the player character with health, combat abilities, and movement

class Iterum::Entities::Player {
    field $ecs :param :reader;   # ECS instance
    field $id :reader;           # Entity ID
    field $name :param :reader = 'Adventurer';  # Player name
    
    ADJUST {
        # Create entity ID
        $id = $ecs->new_entity('player');
    }
    
    # Initialize the player with components and default values
    method setup(%params) {
        # Ensure all components are registered
        eval "require Iterum::Components::Health";
        eval "require Iterum::Components::CombatStats";
        eval "require Iterum::Components::Position";
        
        Iterum::Components::Health::register($ecs);
        Iterum::Components::CombatStats::register($ecs);
        Iterum::Components::Position::register($ecs);
        
        # Add Health component
        my $max_hp = $params{max_hp} // 100;
        my $current_hp = $params{current_hp} // $max_hp;
        
        Iterum::Components::Health::add($ecs, $id, 
            max_hp => $max_hp,
            current_hp => $current_hp
        );
        
        # Add CombatStats component
        Iterum::Components::CombatStats::add($ecs, $id, 
            attack => $params{attack} // 10,
            defense => $params{defense} // 5
        );
        
        # Add Position component
        Iterum::Components::Position::add($ecs, $id,
            x => $params{x} // 0,
            y => $params{y} // 0
        );
        
        return $self;
    }
    
    # Move the player by delta x and delta y
    method move($dx, $dy) {
        Iterum::Components::Position::move($ecs, $id, $dx, $dy);
    }
    
    # Set absolute position
    method set_position($x, $y) {
        Iterum::Components::Position::set_position($ecs, $id, $x, $y);
    }
    
    # Attack another entity
    method attack($target_id) {
        # Verify target has Health component
        # This will implicitly check if the entity exists in most cases
        my ($target_health) = $ecs->get_components($target_id, 'Health');
        croak "Target entity does not have a Health component" unless $target_health;
        
        # Get target's defense
        my ($target_combat) = $ecs->get_components($target_id, 'CombatStats');
        my $target_defense = $target_combat ? 
            Iterum::Components::CombatStats::effective_defense($ecs, $target_id) : 0;
        
        # Get player's attack
        my $attack = Iterum::Components::CombatStats::effective_attack($ecs, $id);
        
        # Calculate damage
        my $base_damage = $attack - $target_defense;
        $base_damage = 1 if $base_damage < 1; # Minimum damage of 1
        
        # Apply damage to target
        Iterum::Components::Health::damage($ecs, $target_id, $base_damage);
        
        return $base_damage;
    }
    
    # Enter defensive stance
    method defend() {
        Iterum::Components::CombatStats::set_defending($ecs, $id, 1);
        return 1;
    }
    
    # End defensive stance
    method end_defend() {
        Iterum::Components::CombatStats::set_defending($ecs, $id, 0);
        return 1;
    }
    
    # Take damage
    method take_damage($amount) {
        return Iterum::Components::Health::damage($ecs, $id, $amount);
    }
    
    # Heal
    method heal($amount) {
        return Iterum::Components::Health::heal($ecs, $id, $amount);
    }
    
    # Check if player is alive
    method is_alive() {
        return Iterum::Components::Health::is_alive($ecs, $id);
    }
    
    # Get player status
    method get_status() {
        my ($health, $combat_stats, $position) = $ecs->get_components(
            $id, 'Health', 'CombatStats', 'Position'
        );
        
        return {
            id       => $id,
            name     => $name,
            health   => $health,
            stats    => $combat_stats,
            position => $position,
            alive    => Iterum::Components::Health::is_alive($ecs, $id),
        };
    }
}

1;