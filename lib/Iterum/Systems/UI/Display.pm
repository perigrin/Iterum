use 5.40.0;

package Iterum::Systems::UI::Display;

use experimental 'class';

class Iterum::Systems::UI::Display {
    field $ecs :param;    # ECS instance
    field $cli :param;    # CLI instance
    field @entities;      # Tracked entities

    method components_required() {
        return ( 'Health', 'CombatStats' );
    }

    method set_entities(@new_entities) {
        @entities = @new_entities;
    }

    method update( $components = undef ) {

        # Extract player and enemy entities
        my $player_id = $self->find_player_entity();
        my $enemy_id  = $self->find_enemy_entity();

        if ( $player_id && $enemy_id ) {

            # Get entity data
            my ( $player_health, $player_stats ) =
              $ecs->get_components( $player_id, 'Health', 'CombatStats' );
            my ( $enemy_health, $enemy_stats ) =
              $ecs->get_components( $enemy_id, 'Health', 'CombatStats' );

            # Format data for CLI
            my $player_data = {
                name   => 'Hero',
                health => $player_health,
                stats  => $player_stats
            };

            my $enemy_data = {
                name   => 'Goblin',
                health => $enemy_health,
                stats  => $enemy_stats
            };

            # Display game state
            $cli->display_status( $player_data, $enemy_data );
        }
    }

    # Helper methods to find specific entity types
    method find_player_entity() {
        my @player_entities = $ecs->entities_for_components('Player');
        return $player_entities[0] if @player_entities;
        return undef;
    }

    method find_enemy_entity() {
        my @enemy_entities = $ecs->entities_for_components('Enemy');
        return $enemy_entities[0] if @enemy_entities;
        return undef;
    }

    # User interaction methods
    method display_combat_options(@options) {
        return $cli->display_combat_options( \@options );
    }

    method get_player_choice(@options) {
        return $cli->get_input( \@options );
    }

    method display_combat_result($result) {
        return $cli->display_result($result);
    }

    method display_feedback(@feedback) {
        return $cli->display_ev_feedback( \@feedback );
    }

    method display_history($history) {
        return $cli->display_decision_history($history);
    }

    method prompt_continue() {
        return $cli->prompt_continue();
    }

    method display_message( $message, $color = '' ) {
        return $cli->display_message( $message, $color );
    }
}

1;
