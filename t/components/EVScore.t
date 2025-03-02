use 5.40.0;
use Test2::V0;
use FindBin qw($Bin);
use lib "$Bin/../../lib";

use Iterum::ECS;
use Iterum::Components::EVScore;

# Test component registration
subtest 'Component Registration' => sub {
    my $ecs          = Iterum::ECS->new();
    my $component_id = Iterum::Components::EVScore::register($ecs);
    ok( $component_id, 'EVScore component type was registered' );

    my $retrieved_id = $ecs->get_id_for_component_type('EVScore');
    is( $retrieved_id, $component_id, 'Component ID can be retrieved by type' );
};

# Test adding EVScore component with default values
subtest 'Default EVScore Values' => sub {
    my $ecs = Iterum::ECS->new();
    Iterum::Components::EVScore::register($ecs);

    my $entity_id = $ecs->new_entity('test_entity');
    Iterum::Components::EVScore::add( $ecs, $entity_id );

    my ($ev_score) = $ecs->get_components( $entity_id, 'EVScore' );
    is( $ev_score->{decisions}, [], 'Default decisions list is empty' );
    is( $ev_score->{current_decision},
        undef, 'Default current decision is undef' );
    is( $ev_score->{total_score}, 0, 'Default total score is 0' );
    is( $ev_score->{avg_score},   0, 'Default average score is 0' );
};

# Test recording a new decision
subtest 'Recording Decisions' => sub {
    my $ecs = Iterum::ECS->new();
    Iterum::Components::EVScore::register($ecs);

    my $entity_id = $ecs->new_entity('test_entity');
    Iterum::Components::EVScore::add( $ecs, $entity_id );

    # Record a decision
    my $decision = {
        action    => 'attack',
        target    => 'enemy1',
        ev_score  => 75,
        timestamp => time()
    };

    my $result = Iterum::Components::EVScore::record_decision( $ecs, $entity_id,
        $decision );
    ok( $result, 'Decision recorded successfully' );

    # Check the updated component
    my ($ev_score) = $ecs->get_components( $entity_id, 'EVScore' );
    is( $ev_score->{current_decision}, $decision, 'Current decision is set' );
    is( scalar @{ $ev_score->{decisions} }, 1,    'One decision in history' );
    is( $ev_score->{total_score},           75,   'Total score is updated' );
    is( $ev_score->{avg_score},             75,   'Average score is updated' );

    # Record another decision
    my $decision2 = {
        action    => 'defend',
        target    => undef,
        ev_score  => 85,
        timestamp => time()
    };

    Iterum::Components::EVScore::record_decision( $ecs, $entity_id,
        $decision2 );

    # Check the updated component again
    ($ev_score) = $ecs->get_components( $entity_id, 'EVScore' );
    is( $ev_score->{current_decision},
        $decision2, 'Current decision is updated' );
    is( scalar @{ $ev_score->{decisions} }, 2,   'Two decisions in history' );
    is( $ev_score->{total_score},           160, 'Total score is updated' );
    is( $ev_score->{avg_score},             80,  'Average score is updated' );
};

# Test getting decision statistics
subtest 'Decision Statistics' => sub {
    my $ecs = Iterum::ECS->new();
    Iterum::Components::EVScore::register($ecs);

    my $entity_id = $ecs->new_entity('test_entity');
    Iterum::Components::EVScore::add( $ecs, $entity_id );

    # Record several decisions
    my @decisions = (
        {
            action    => 'attack',
            target    => 'enemy1',
            ev_score  => 75,
            timestamp => time()
        },
        {
            action    => 'attack',
            target    => 'enemy2',
            ev_score  => 85,
            timestamp => time()
        },
        {
            action    => 'defend',
            target    => undef,
            ev_score  => 90,
            timestamp => time()
        }
    );

    foreach my $decision (@decisions) {
        Iterum::Components::EVScore::record_decision( $ecs, $entity_id,
            $decision );
    }

    # Get statistics
    my $stats = Iterum::Components::EVScore::get_stats( $ecs, $entity_id );

    ok( $stats, 'Statistics returned' );
    is( $stats->{total_decisions}, 3, 'Total decisions count is correct' );
    is( $stats->{action_counts}{attack}, 2, 'Attack count is correct' );
    is( $stats->{action_counts}{defend}, 1, 'Defend count is correct' );

    # Average scores should be calculated per action type
    ok( exists $stats->{action_avgs}{attack}, 'Attack average exists' );
    ok( exists $stats->{action_avgs}{defend}, 'Defend average exists' );

    # Calculate expected averages
    my $expected_attack_avg = ( 75 + 85 ) / 2;
    my $expected_defend_avg = 90;

    is( $stats->{action_avgs}{attack},
        $expected_attack_avg, 'Attack average score is correct' );
    is( $stats->{action_avgs}{defend},
        $expected_defend_avg, 'Defend average score is correct' );

    # Overall average
    my $expected_overall_avg = ( 75 + 85 + 90 ) / 3;
    is( $stats->{overall_avg}, $expected_overall_avg,
        'Overall average score is correct' );
};

done_testing;
