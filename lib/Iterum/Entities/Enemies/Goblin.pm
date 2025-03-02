use 5.40.0;
use experimental 'class';

# Goblin entity for Iterum roguelike
# Represents a basic aggressive enemy with reckless behavior

class Iterum::Entities::Enemies::Goblin {
    use Carp qw(croak);

    field $ecs :param :reader;                                  # ECS instance
    field $name :param :reader = 'Goblin';                      # Enemy name
    field $id :reader = $ecs->new_entity('goblin');             # Entity ID

    # Initialize the goblin with components and default values
    method setup(%params) {

        # Ensure all components are registered
        eval "require Iterum::Components::Health";
        eval "require Iterum::Components::CombatStats";
        eval "require Iterum::Components::Position";

        # Add Health component
        my $max_hp     = $params{max_hp}     // 60;        # Weaker than player
        my $current_hp = $params{current_hp} // $max_hp;

        Iterum::Components::Health::add(
            $ecs, $id,
            max_hp     => $max_hp,
            current_hp => $current_hp
        );

        # Add CombatStats component - moderately strong attack but weak defense
        Iterum::Components::CombatStats::add(
            $ecs, $id,
            attack  => $params{attack}  // 8,
            defense => $params{defense} // 3
        );

        # Add Position component
        Iterum::Components::Position::add(
            $ecs, $id,
            x => $params{x} // 0,
            y => $params{y} // 0
        );

        return $self;
    }

    # Move the goblin by delta x and delta y
    method move( $dx, $dy ) {
        Iterum::Components::Position::move( $ecs, $id, $dx, $dy );
    }

    # Set absolute position
    method set_position( $x, $y ) {
        Iterum::Components::Position::set_position( $ecs, $id, $x, $y );
    }

    # Attack another entity
    method attack($target_id) {

        # Verify target has Health component
        my ($target_health) = $ecs->get_components( $target_id, 'Health' );
        croak "Target entity does not have a Health component"
          unless $target_health;

        # Get target's defense
        my ($target_combat) = $ecs->get_components( $target_id, 'CombatStats' );
        my $target_defense =
          $target_combat
          ? Iterum::Components::CombatStats::effective_defense( $ecs,
            $target_id )
          : 0;

        # Get goblin's attack
        my $attack =
          Iterum::Components::CombatStats::effective_attack( $ecs, $id );

        # Calculate damage
        my $base_damage = $attack - $target_defense;
        $base_damage = 1 if $base_damage < 1;    # Minimum damage of 1

        # Apply damage to target
        Iterum::Components::Health::damage( $ecs, $target_id, $base_damage );

        return $base_damage;
    }

    # Take damage
    method take_damage($amount) {
        return Iterum::Components::Health::damage( $ecs, $id, $amount );
    }

    # Check if goblin is alive
    method is_alive() {
        return Iterum::Components::Health::is_alive( $ecs, $id );
    }

    # Get goblin status
    method get_status() {
        my ( $health, $combat_stats, $position ) =
          $ecs->get_components( $id, 'Health', 'CombatStats', 'Position' );

        return {
            id       => $id,
            name     => $name,
            health   => $health,
            stats    => $combat_stats,
            position => $position,
            alive    => Iterum::Components::Health::is_alive( $ecs, $id ),
        };
    }

    # AI decision-making method
    # Returns a decision hash with action and related data
    method make_decision( $player_id = undef ) {

        # If not given a player_id, we can't make a decision
        # In a real game, the main loop would pass the player_id
        # or the combat system to the make_decision method
        unless ($player_id) {
            return { action => 'none' };
        }

        # If we still don't have a target, do nothing
        return { action => 'none' } unless $player_id;

        # Check if player is adjacent (can attack)
        my $is_adjacent =
          Iterum::Components::Position::is_adjacent( $ecs, $id, $player_id );

        # Health status affects decision-making slightly
        my $health_percent =
          Iterum::Components::Health::health_percentage( $ecs, $id );

        # GOBLIN AI: Aggressive, always prefers attacking
        if ($is_adjacent) {

            # If adjacent, always attack (reckless behavior)
            return {
                action => 'attack',
                target => $player_id,
            };
        }
        else {
            # If not adjacent, move toward player
            my ($my_pos)     = $ecs->get_components( $id,        'Position' );
            my ($player_pos) = $ecs->get_components( $player_id, 'Position' );

            # Calculate direction to move (simplified)
            my $dx = 0;
            my $dy = 0;

            if ( $player_pos->{x} > $my_pos->{x} ) {
                $dx = 1;
            }
            elsif ( $player_pos->{x} < $my_pos->{x} ) {
                $dx = -1;
            }

            if ( $player_pos->{y} > $my_pos->{y} ) {
                $dy = 1;
            }
            elsif ( $player_pos->{y} < $my_pos->{y} ) {
                $dy = -1;
            }

            return {
                action    => 'move',
                direction => {
                    dx => $dx,
                    dy => $dy,
                },
                target => $player_id,
            };
        }
    }

    # Process a turn based on AI decision
    method process_turn( $combat_system, $player_id ) {
        my $decision = $self->make_decision($player_id);

        if ( $decision->{action} eq 'attack' ) {

            # Set attack action in combat system
            $combat_system->set_action( $id, 'attack' );
            $combat_system->set_target( $id, $decision->{target} );
            return "attacks";
        }
        elsif ( $decision->{action} eq 'move' ) {

            # Move toward player
            $self->move( $decision->{direction}{dx},
                $decision->{direction}{dy} );
            return "moves toward player";
        }

        return "does nothing";
    }
}

1;
