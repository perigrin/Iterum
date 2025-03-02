use 5.40.0;
use experimental 'class';
use experimental 'try';

# EVScoring system for Iterum ECS
# Calculates expected value scores for player decisions

use Iterum::Components::EVScore;

class Iterum::Systems::EVScoring {
    use Carp               qw(croak);
    use Iterum::Util::Data qw(load_json_data);
    use Time::HiRes        qw(time);

    field $ecs :param :reader;
    field $ev_lookup_file :param = 'ev_lookup.json';
    field $ev_lookup :reader     = load_json_data($ev_lookup_file);
    field @entities;
    field $time_window :param = 10;    # Last N turns to analyze for trends

    # Define required components for this system
    method components_required {
        return ('EVScore');
    }

    # Set entities for processing
    method set_entities(@new_entities) {
        @entities = @new_entities;
    }

    # Update method - called by ECS
    method update($components) {

        # Not much to do in update cycle for EV scoring
        # Most work happens when record_decision is called
    }

    # Calculate EV for a given action
    method calculate_ev( $entity_id, $target_id, $action ) {

        # Check if we have EV data for this action
        return 0 unless exists $ev_lookup->{$action};

        my $action_data = $ev_lookup->{$action};
        my $base_score  = $action_data->{base_score};
        my $modifiers   = $action_data->{modifiers} // {};

        # Accumulate modifiers based on entity and target state
        my $total_modifier = 0;

        # Get relevant components
        my ($entity_health) = $ecs->get_components( $entity_id, 'Health' );
        my ($entity_combat) = $ecs->get_components( $entity_id, 'CombatStats' );
        my ($target_health) = $ecs->get_components( $target_id, 'Health' );

        # Apply health modifiers
        if ($entity_health) {
            my $health_percent =
              ( $entity_health->{current_hp} / $entity_health->{max_hp} ) * 100;

            if ( $health_percent < 30
                && exists $modifiers->{health_below_30_percent} )
            {
                $total_modifier += $modifiers->{health_below_30_percent};
            }
        }

        if ($target_health) {
            my $target_health_percent =
              ( $target_health->{current_hp} / $target_health->{max_hp} ) * 100;

            if ( $target_health_percent < 30
                && exists $modifiers->{opponent_health_below_30_percent} )
            {
                $total_modifier +=
                  $modifiers->{opponent_health_below_30_percent};
            }
        }

        # Apply combat state modifiers
        if ($entity_combat) {
            if (   $action eq 'defend'
                && $entity_combat->{defending}
                && exists $modifiers->{already_defending} )
            {
                $total_modifier += $modifiers->{already_defending};
            }

            if (   $action eq 'attack'
                && $entity_combat->{defending}
                && exists $modifiers->{defensive_stance} )
            {
                $total_modifier += $modifiers->{defensive_stance};
            }
        }

        # Apply item-related modifiers (placeholder for future implementation)
        if ( $action eq 'use_item' ) {

            # Check if the entity has items (placeholder)
            my $has_items =
              0;    # This would be implemented with an inventory system

            if ( !$has_items && exists $modifiers->{no_items} ) {
                $total_modifier += $modifiers->{no_items};
            }
        }

        # Calculate final EV score
        my $ev_score = $base_score + $total_modifier;

        # Ensure score is within a reasonable range (0-100)
        $ev_score = 0   if $ev_score < 0;
        $ev_score = 100 if $ev_score > 100;

        return $ev_score;
    }

    # Record a decision and update EVScore component
    method record_decision( $entity_id, $target_id, $action ) {

        # Check if entity has EVScore component
        my ($ev_data) = $ecs->get_components( $entity_id, 'EVScore' );
        return 0 unless $ev_data;    # Skip if no EVScore component

        # Check action validity
        croak "Invalid action: $action" unless exists $ev_lookup->{$action};

        # Calculate the EV score
        my $score = $self->calculate_ev( $entity_id, $target_id, $action );

        # Create decision record
        my $decision = {
            action    => $action,
            target    => $target_id,
            ev_score  => $score,
            timestamp => time(),
        };

        # Update the EVScore component
        Iterum::Components::EVScore::record_decision( $ecs, $entity_id,
            $decision );

        return $score;
    }

    # Get decision statistics for an entity
    method get_decision_stats($entity_id) {

        # Check if entity has EVScore component
        my ($ev_data) = $ecs->get_components( $entity_id, 'EVScore' );
        return {} unless $ev_data;

        return Iterum::Components::EVScore::get_stats( $ecs, $entity_id );
    }

    # Get decision trend analysis
    method get_decision_trend($entity_id) {

        # Check if entity has EVScore component
        my ($ev_data) = $ecs->get_components( $entity_id, 'EVScore' );
        return { improving => undef, avg_change => 0 } unless $ev_data;

        return Iterum::Components::EVScore::get_trend( $ecs, $entity_id,
            $time_window );
    }

    # Get optimal action for current situation
    method get_optimal_action( $entity_id, $target_id, @possible_actions ) {
        my %scores;
        my $best_action = undef;
        my $best_score  = -1;

        # Calculate EV for each possible action
        foreach my $action (@possible_actions) {
            my $score = $self->calculate_ev( $entity_id, $target_id, $action );
            $scores{$action} = $score;

            if ( $score > $best_score ) {
                $best_score  = $score;
                $best_action = $action;
            }
        }

        return ( $best_action, $best_score, \%scores );
    }

    # Generate feedback based on decision history
    method generate_feedback($entity_id) {

        # Check if entity has EVScore component
        my ($ev_data) = $ecs->get_components( $entity_id, 'EVScore' );
        return "No decision history available" unless $ev_data;

        my $stats = $self->get_decision_stats($entity_id);
        my $trend = $self->get_decision_trend($entity_id);

        # Skip if not enough data
        return "Not enough decision data for meaningful feedback"
          if !$stats || $stats->{total_decisions} < 2;

        my @feedback;

        # Overall assessment
        if ( $stats->{overall_avg} >= 80 ) {
            push @feedback, "Your decision-making is excellent overall.";
        }
        elsif ( $stats->{overall_avg} >= 60 ) {
            push @feedback, "Your decisions are generally solid.";
        }
        elsif ( $stats->{overall_avg} >= 40 ) {
            push @feedback, "Your decision-making shows room for improvement.";
        }
        else {
            push @feedback, "Your decisions need significant reconsideration.";
        }

        # Trend feedback
        if ( defined $trend->{improving} ) {
            if ( $trend->{improving} ) {
                push @feedback,
                  "You're showing improvement in recent decisions.";
            }
            else {
                push @feedback,
                  "Your recent decisions have been declining in quality.";
            }
        }

        # Action-specific feedback
        my @actions = sort keys %{ $stats->{action_counts} };
        foreach my $action (@actions) {
            my $count = $stats->{action_counts}{$action};
            my $avg   = $stats->{action_avgs}{$action};

            if ( $count > 2 ) {    # Only comment on actions with enough data
                if ( $avg > $stats->{overall_avg} + 10 ) {
                    push @feedback,
                      "Your '$action' decisions are particularly strong.";
                }
                elsif ( $avg < $stats->{overall_avg} - 10 ) {
                    push @feedback,
                      "You should reconsider when to use '$action'.";
                }
            }
        }

        # Most used action feedback
        my $most_used  = $actions[0];
        my $most_count = $stats->{action_counts}{$most_used};
        foreach my $action (@actions) {
            if ( $stats->{action_counts}{$action} > $most_count ) {
                $most_used  = $action;
                $most_count = $stats->{action_counts}{$action};
            }
        }

        if ( $most_count > $stats->{total_decisions} * 0.6 ) {
            push @feedback,
              "You rely heavily on '$most_used'. Try mixing up your strategy.";
        }

        return join " ", @feedback;
    }
}

1;
