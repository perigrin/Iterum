use 5.40.0;
use Test2::V0;
use FindBin qw($Bin);
use lib "$Bin/../../lib";

use Iterum::ECS;
use Iterum::Components::AIState;

# Test component registration
subtest 'Component Registration' => sub {
    my $ecs          = Iterum::ECS->new();
    my $component_id = Iterum::Components::AIState::register($ecs);
    ok( $component_id, 'AIState component type was registered' );

    my $retrieved_id = $ecs->get_id_for_component_type('AIState');
    is( $retrieved_id, $component_id, 'Component ID can be retrieved by type' );
};

# Test adding AIState component with default values
subtest 'Default AIState Values' => sub {
    my $ecs = Iterum::ECS->new();
    Iterum::Components::AIState::register($ecs);

    my $entity_id = $ecs->new_entity('ai_coach');
    Iterum::Components::AIState::add( $ecs, $entity_id );

    my ($ai_state) = $ecs->get_components( $entity_id, 'AIState' );
    ok( $ai_state->{personality}, 'Default personality is set' );
    is( $ai_state->{feedback_history}, [], 'Default feedback history is empty' );
    ok( $ai_state->{adaptation_threshold} > 0, 'Default adaptation threshold is positive' );
    ok( exists $ai_state->{player_patterns}, 'Player patterns tracking exists' );
};

# Test adding AIState component with custom values
subtest 'Custom AIState Values' => sub {
    my $ecs = Iterum::ECS->new();
    Iterum::Components::AIState::register($ecs);

    my $entity_id = $ecs->new_entity('ai_coach');
    
    my $custom_personality = {
        encouraging => 0.8,
        critical    => 0.2,
        analytical  => 0.5,
        helpful     => 0.7,
        sarcastic   => 0.1
    };
    
    Iterum::Components::AIState::add( 
        $ecs, 
        $entity_id,
        personality => $custom_personality,
        adaptation_threshold => 5
    );

    my ($ai_state) = $ecs->get_components( $entity_id, 'AIState' );
    is( $ai_state->{personality}, $custom_personality, 'Custom personality is set correctly' );
    is( $ai_state->{adaptation_threshold}, 5, 'Custom adaptation threshold is set correctly' );
};

# Test recording feedback
subtest 'Recording Feedback' => sub {
    my $ecs = Iterum::ECS->new();
    Iterum::Components::AIState::register($ecs);

    my $entity_id = $ecs->new_entity('ai_coach');
    Iterum::Components::AIState::add( $ecs, $entity_id );

    # Record some feedback
    my $feedback = {
        message => "Your decision to attack was good, but consider defending when low on health.",
        tone => "encouraging",
        timestamp => time(),
        ev_context => {
            overall_avg => 70,
            recent_trend => "improving"
        }
    };

    my $result = Iterum::Components::AIState::record_feedback( $ecs, $entity_id, $feedback );
    ok( $result, 'Feedback recorded successfully' );

    # Check the updated component
    my ($ai_state) = $ecs->get_components( $entity_id, 'AIState' );
    is( scalar @{ $ai_state->{feedback_history} }, 1, 'One feedback in history' );
    is( $ai_state->{feedback_history}[0], $feedback, 'Feedback content is correct' );

    # Record another feedback
    my $feedback2 = {
        message => "You're relying too much on attacks. Try a more balanced approach.",
        tone => "critical",
        timestamp => time(),
        ev_context => {
            overall_avg => 65,
            recent_trend => "stable"
        }
    };

    Iterum::Components::AIState::record_feedback( $ecs, $entity_id, $feedback2 );

    # Check the updated component again
    ($ai_state) = $ecs->get_components( $entity_id, 'AIState' );
    is( scalar @{ $ai_state->{feedback_history} }, 2, 'Two feedbacks in history' );
    is( $ai_state->{feedback_history}[1], $feedback2, 'Second feedback content is correct' );
};

# Test tracking player patterns
subtest 'Tracking Player Patterns' => sub {
    my $ecs = Iterum::ECS->new();
    Iterum::Components::AIState::register($ecs);

    my $entity_id = $ecs->new_entity('ai_coach');
    Iterum::Components::AIState::add( $ecs, $entity_id );

    # Track various player patterns
    Iterum::Components::AIState::track_pattern( $ecs, $entity_id, 'repetitive_actions', 1 );
    Iterum::Components::AIState::track_pattern( $ecs, $entity_id, 'low_health_attacks', 1 );
    Iterum::Components::AIState::track_pattern( $ecs, $entity_id, 'repetitive_actions', 1 );

    # Check patterns are being tracked
    my ($ai_state) = $ecs->get_components( $entity_id, 'AIState' );
    is( $ai_state->{player_patterns}{repetitive_actions}, 2, 'Repetitive actions pattern incremented twice' );
    is( $ai_state->{player_patterns}{low_health_attacks}, 1, 'Low health attacks pattern incremented once' );
};

# Test personality adaptation
subtest 'Personality Adaptation' => sub {
    my $ecs = Iterum::ECS->new();
    Iterum::Components::AIState::register($ecs);

    my $entity_id = $ecs->new_entity('ai_coach');
    
    # Set up initial personality with adaptation threshold of 3
    my $initial_personality = {
        encouraging => 0.5,
        critical    => 0.3,
        analytical  => 0.6,
        helpful     => 0.5,
        sarcastic   => 0.2
    };
    
    Iterum::Components::AIState::add( 
        $ecs, 
        $entity_id,
        personality => $initial_personality,
        adaptation_threshold => 3
    );

    # Track pattern until we reach adaptation threshold
    for (1..3) {
        Iterum::Components::AIState::track_pattern( $ecs, $entity_id, 'repetitive_actions', 1 );
    }

    # Trigger adaptation based on patterns
    my $adapted = Iterum::Components::AIState::adapt_personality( $ecs, $entity_id );
    ok( $adapted, 'Personality adaptation triggered' );

    # Check that personality traits were adjusted
    my ($ai_state) = $ecs->get_components( $entity_id, 'AIState' );
    
    # The critical trait should increase due to repetitive actions
    ok( $ai_state->{personality}{critical} > $initial_personality->{critical}, 
        'Critical trait increased after adaptation' );
    
    # The encouraging trait might decrease to balance
    ok( $ai_state->{personality}{encouraging} != $initial_personality->{encouraging}, 
        'Encouraging trait changed after adaptation' );
};

# Test getting AI coach status
subtest 'Getting AI Coach Status' => sub {
    my $ecs = Iterum::ECS->new();
    Iterum::Components::AIState::register($ecs);

    my $entity_id = $ecs->new_entity('ai_coach');
    Iterum::Components::AIState::add( $ecs, $entity_id );

    # Record some data to have a meaningful status
    Iterum::Components::AIState::track_pattern( $ecs, $entity_id, 'repetitive_actions', 2 );
    
    my $feedback = {
        message => "You should try different approaches.",
        tone => "analytical",
        timestamp => time(),
        ev_context => { overall_avg => 65 }
    };
    Iterum::Components::AIState::record_feedback( $ecs, $entity_id, $feedback );

    # Get the status
    my $status = Iterum::Components::AIState::get_status( $ecs, $entity_id );
    ok( $status, 'Status retrieved successfully' );
    ok( exists $status->{personality}, 'Status includes personality' );
    ok( exists $status->{dominant_trait}, 'Status includes dominant personality trait' );
    ok( exists $status->{pattern_count}, 'Status includes pattern counts' );
    ok( exists $status->{feedback_count}, 'Status includes feedback count' );
    
    # Check that dominant trait is determined correctly
    my ($ai_state) = $ecs->get_components( $entity_id, 'AIState' );
    my $max_trait = '';
    my $max_value = -1;
    
    foreach my $trait (keys %{$ai_state->{personality}}) {
        if ($ai_state->{personality}{$trait} > $max_value) {
            $max_value = $ai_state->{personality}{$trait};
            $max_trait = $trait;
        }
    }
    
    is( $status->{dominant_trait}, $max_trait, 'Dominant trait correctly determined' );
};

done_testing;