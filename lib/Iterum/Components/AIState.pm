use 5.40.0;

package Iterum::Components::AIState;

# AIState component for Iterum ECS
# Stores AI Coach personality, feedback history, and adaptation parameters

use Carp qw(croak);

# Register the AIState component type in the ECS
sub register ($ecs) {
    return $ecs->new_component_type( 'AIState',
        'Stores AI Coach personality and adaptation parameters', {} );
}

# Add AIState component to an entity with default or custom values
sub add ( $ecs, $entity_id, %options ) {

    # Default personality traits (values from 0.0 to 1.0)
    my $personality = $options{personality} // {
        encouraging => 0.6,    # Offers positive reinforcement
        critical    => 0.4,    # Points out mistakes
        analytical  => 0.7,    # Provides detailed analysis
        helpful     => 0.8,    # Offers actionable advice
        sarcastic   => 0.2,    # Uses mild humor/sarcasm
    };

    # Default adaptation parameters
    my $adaptation_threshold = $options{adaptation_threshold}
      // 5;                    # How many instances of a pattern before adapting
    my $adaptation_strength = $options{adaptation_strength}
      // 0.1;                  # How much to adjust traits (0.0-0.2)

    # Initial empty feedback history
    my $feedback_history = $options{feedback_history} // [];

    # Player behavior pattern tracking
    my $player_patterns = $options{player_patterns} // {
        repetitive_actions  => 0,    # Player repeats same action many times
        low_health_attacks  => 0,    # Player attacks when at low health
        defensive_stance    => 0,    # Player uses defend action frequently
        optimal_choices     => 0,    # Player makes high EV choices
        poor_choices        => 0,    # Player makes low EV choices
        improved_decisions  => 0,    # Player's EV scores are trending up
        worsening_decisions => 0,    # Player's EV scores are trending down
    };

    # Validation
    croak "personality must be a hash reference"
      unless ref $personality eq 'HASH';
    croak "feedback_history must be an array reference"
      unless ref $feedback_history eq 'ARRAY';
    croak "player_patterns must be a hash reference"
      unless ref $player_patterns eq 'HASH';

    # Add all necessary traits if they aren't present
    for my $trait (qw(encouraging critical analytical helpful sarcastic)) {
        $personality->{$trait} //= 0.5;
    }

    # Ensure trait values are between 0 and 1
    for my $trait ( keys %$personality ) {
        $personality->{$trait} = 0 if $personality->{$trait} < 0;
        $personality->{$trait} = 1 if $personality->{$trait} > 1;
    }

    $ecs->add_component(
        $entity_id,
        'AIState',
        {
            personality          => $personality,
            feedback_history     => $feedback_history,
            adaptation_threshold => $adaptation_threshold,
            adaptation_strength  => $adaptation_strength,
            player_patterns      => $player_patterns,
        }
    );
}

# Record feedback given to the player
sub record_feedback ( $ecs, $entity_id, $feedback ) {
    croak "Feedback must be a hash reference" unless ref $feedback eq 'HASH';
    croak "Feedback must include a message" unless defined $feedback->{message};

    my ($ai_state) = $ecs->get_components( $entity_id, 'AIState' );
    croak "Entity does not have an AIState component" unless $ai_state;

    # Copy the feedback history array
    my @feedback_history = @{ $ai_state->{feedback_history} };
    push @feedback_history, $feedback;

    # Update the component with new feedback history
    $ecs->add_component(
        $entity_id,
        'AIState',
        {
            %$ai_state, feedback_history => \@feedback_history,
        }
    );

    return 1;
}

# Track a player behavior pattern
sub track_pattern ( $ecs, $entity_id, $pattern, $increment = 1 ) {
    my ($ai_state) = $ecs->get_components( $entity_id, 'AIState' );
    croak "Entity does not have an AIState component" unless $ai_state;

    # Create a copy of patterns with the incremented value
    my %patterns = %{ $ai_state->{player_patterns} };
    $patterns{$pattern} //= 0;
    $patterns{$pattern} += $increment;

    # Update the component with new pattern counts
    $ecs->add_component(
        $entity_id,
        'AIState',
        {
            %$ai_state, player_patterns => \%patterns,
        }
    );

    return $patterns{$pattern};
}

# Reset pattern tracking (e.g., at start of new game/level)
sub reset_patterns ( $ecs, $entity_id ) {
    my ($ai_state) = $ecs->get_components( $entity_id, 'AIState' );
    croak "Entity does not have an AIState component" unless $ai_state;

    # Create a reset pattern hash with all keys but zero values
    my %reset_patterns = map { $_ => 0 } keys %{ $ai_state->{player_patterns} };

    # Update the component with reset pattern counts
    $ecs->add_component(
        $entity_id,
        'AIState',
        {
            %$ai_state, player_patterns => \%reset_patterns,
        }
    );

    return 1;
}

# Adapt AI personality based on player patterns
sub adapt_personality ( $ecs, $entity_id ) {
    my ($ai_state) = $ecs->get_components( $entity_id, 'AIState' );
    croak "Entity does not have an AIState component" unless $ai_state;

    my $patterns  = $ai_state->{player_patterns};
    my $threshold = $ai_state->{adaptation_threshold};
    my $strength  = $ai_state->{adaptation_strength};

    # Copy personality for modification
    my %personality = %{ $ai_state->{personality} };

    # Track if any adaptations were made
    my $adapted = 0;

    # Adapt based on repetitive actions
    if ( $patterns->{repetitive_actions} >= $threshold ) {

        # Increase critical trait to encourage variety
        $personality{critical} += $strength;

        # Decrease encouraging trait to balance
        $personality{encouraging} -= $strength * 0.5;

        # Increase analytical trait to explain why variety matters
        $personality{analytical} += $strength * 0.5;
        $adapted = 1;
    }

    # Adapt based on low health attacks
    if ( $patterns->{low_health_attacks} >= $threshold ) {

        # Increase encouraging trait to boost confidence
        $personality{encouraging} += $strength * 0.5;

        # Increase helpful trait to provide better survival advice
        $personality{helpful} += $strength;

        # Increase critical trait to point out the risk
        $personality{critical} += $strength * 0.5;
        $adapted = 1;
    }

    # Adapt based on defensive stance
    if ( $patterns->{defensive_stance} >= $threshold ) {

        # Increase encouraging trait to boost confidence
        $personality{encouraging} += $strength;

        # Decrease critical trait as player is being cautious
        $personality{critical} -= $strength * 0.5;

        # Maybe add a touch of sarcasm to liven things up
        $personality{sarcastic} += $strength * 0.3;
        $adapted = 1;
    }

    # Adapt based on optimal choices
    if ( $patterns->{optimal_choices} >= $threshold ) {

        # Increase encouraging trait to reinforce good behavior
        $personality{encouraging} += $strength;

        # Decrease critical trait as less criticism needed
        $personality{critical} -= $strength;
        $adapted = 1;
    }

    # Adapt based on poor choices
    if ( $patterns->{poor_choices} >= $threshold ) {

        # Increase critical trait to highlight mistakes
        $personality{critical} += $strength;

        # Increase helpful trait to offer more guidance
        $personality{helpful} += $strength;

        # Decrease sarcastic trait to avoid discouraging player
        $personality{sarcastic} -= $strength;
        $adapted = 1;
    }

    # Adapt based on improving decisions
    if ( $patterns->{improved_decisions} >= $threshold ) {

        # Increase encouraging trait to celebrate improvement
        $personality{encouraging} += $strength;

        # Decrease critical trait
        $personality{critical} -= $strength;
        $adapted = 1;
    }

    # Adapt based on worsening decisions
    if ( $patterns->{worsening_decisions} >= $threshold ) {

        # Increase analytical trait to help understand problems
        $personality{analytical} += $strength;

        # Increase helpful trait to provide more guidance
        $personality{helpful} += $strength;

        # Decrease sarcastic trait to avoid demoralizing player
        $personality{sarcastic} -= $strength;
        $adapted = 1;
    }

    # Ensure all traits stay within 0-1 range
    for my $trait ( keys %personality ) {
        $personality{$trait} = 0 if $personality{$trait} < 0;
        $personality{$trait} = 1 if $personality{$trait} > 1;
    }

    # Only update if adaptations were made
    if ($adapted) {

        # Update the component with new personality
        $ecs->add_component(
            $entity_id,
            'AIState',
            {
                %$ai_state, personality => \%personality,
            }
        );

        # Reset the pattern counters that triggered adaptation
        my %reset_patterns = %{ $ai_state->{player_patterns} };
        for my $pattern ( keys %reset_patterns ) {
            if ( $reset_patterns{$pattern} >= $threshold ) {
                $reset_patterns{$pattern} = 0;
            }
        }

        # Update pattern tracking
        $ecs->add_component(
            $entity_id,
            'AIState',
            {
                %$ai_state,
                personality     => \%personality,
                player_patterns => \%reset_patterns,
            }
        );
    }

    return $adapted;
}

# Get current AI Coach status
sub get_status ( $ecs, $entity_id ) {
    my ($ai_state) = $ecs->get_components( $entity_id, 'AIState' );
    croak "Entity does not have an AIState component" unless $ai_state;

    # Find the dominant personality trait
    my $dominant_trait = '';
    my $max_value      = -1;

    foreach my $trait ( keys %{ $ai_state->{personality} } ) {
        if ( $ai_state->{personality}{$trait} > $max_value ) {
            $max_value      = $ai_state->{personality}{$trait};
            $dominant_trait = $trait;
        }
    }

    # Count patterns and feedback
    my $pattern_count = 0;
    for my $count ( values %{ $ai_state->{player_patterns} } ) {
        $pattern_count += $count;
    }

    return {
        personality          => $ai_state->{personality},
        dominant_trait       => $dominant_trait,
        pattern_count        => $pattern_count,
        feedback_count       => scalar @{ $ai_state->{feedback_history} },
        adaptation_threshold => $ai_state->{adaptation_threshold},
    };
}

1;
