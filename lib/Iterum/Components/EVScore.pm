use 5.40.0;

package Iterum::Components::EVScore;

# EVScore component for Iterum ECS
# Tracks decision history and expected value scores for player actions

use Carp qw(croak);

# Register the EVScore component type in the ECS
sub register ($ecs) {
    return $ecs->new_component_type( 'EVScore',
        'Tracks expected value of decisions and decision history', {} );
}

# Add EVScore component to an entity with default values
sub add ( $ecs, $entity_id, %options ) {

    # Default values
    my $decisions        = $options{decisions}        // [];
    my $current_decision = $options{current_decision} // undef;
    my $total_score      = $options{total_score}      // 0;
    my $avg_score        = $options{avg_score}        // 0;

    # Validation
    croak "decisions must be an array reference"
      unless ref $decisions eq 'ARRAY';

    $ecs->add_component(
        $entity_id,
        'EVScore',
        {
            decisions        => $decisions,
            current_decision => $current_decision,
            total_score      => $total_score,
            avg_score        => $avg_score,
        }
    );
}

# Record a new decision and update statistics
sub record_decision ( $ecs, $entity_id, $decision ) {
    croak "Decision must be a hash reference" unless ref $decision eq 'HASH';
    croak "Decision must include an action" unless defined $decision->{action};
    croak "Decision must include an ev_score"
      unless defined $decision->{ev_score};

    my ($ev_score) = $ecs->get_components( $entity_id, 'EVScore' );
    croak "Entity does not have an EVScore component" unless $ev_score;

    # Copy the decisions array
    my @decisions = @{ $ev_score->{decisions} };
    push @decisions, $decision;

    # Update total and average scores
    my $total_score = $ev_score->{total_score} + $decision->{ev_score};
    my $avg_score   = $total_score / scalar @decisions;

    # Update the component
    $ecs->add_component(
        $entity_id,
        'EVScore',
        {
            decisions        => \@decisions,
            current_decision => $decision,
            total_score      => $total_score,
            avg_score        => $avg_score,
        }
    );

    return 1;
}

# Get statistics about decisions
sub get_stats ( $ecs, $entity_id ) {
    my ($ev_score) = $ecs->get_components( $entity_id, 'EVScore' );
    croak "Entity does not have an EVScore component" unless $ev_score;

    my $decisions = $ev_score->{decisions};

    # Default stats
    my $stats = {
        total_decisions => scalar @$decisions,
        overall_avg     => $ev_score->{avg_score},
        action_counts   => {},
        action_avgs     => {},
    };

    return $stats if @$decisions == 0;

    # Collect counts and scores by action type
    my %action_scores;

    foreach my $decision (@$decisions) {
        my $action = $decision->{action};
        $stats->{action_counts}{$action}++;
        $action_scores{$action} += $decision->{ev_score};
    }

    # Calculate average scores per action
    foreach my $action ( keys %{ $stats->{action_counts} } ) {
        $stats->{action_avgs}{$action} =
          $action_scores{$action} / $stats->{action_counts}{$action};
    }

    return $stats;
}

# Get trend analysis (improvement over time)
sub get_trend ( $ecs, $entity_id, $last_n = 10 ) {
    my ($ev_score) = $ecs->get_components( $entity_id, 'EVScore' );
    croak "Entity does not have an EVScore component" unless $ev_score;

    my $decisions = $ev_score->{decisions};
    return { improving => undef, avg_change => 0 } if @$decisions < 2;

    # Get the last N decisions (or all if fewer)
    my $count  = @$decisions < $last_n ? @$decisions : $last_n;
    my @recent = @{$decisions}[ -$count .. -1 ];

    # Calculate average change
    my $prev_score   = $recent[0]->{ev_score};
    my $total_change = 0;

    for ( my $i = 1 ; $i < @recent ; $i++ ) {
        my $change = $recent[$i]->{ev_score} - $prev_score;
        $total_change += $change;
        $prev_score = $recent[$i]->{ev_score};
    }

    my $avg_change = $total_change / ( @recent - 1 );

    return {
        improving  => $avg_change > 0,
        avg_change => $avg_change,
    };
}

# Reset decision history
sub reset_history ( $ecs, $entity_id ) {
    my ($ev_score) = $ecs->get_components( $entity_id, 'EVScore' );
    croak "Entity does not have an EVScore component" unless $ev_score;

    $ecs->add_component(
        $entity_id,
        'EVScore',
        {
            decisions        => [],
            current_decision => undef,
            total_score      => 0,
            avg_score        => 0,
        }
    );

    return 1;
}

1;
