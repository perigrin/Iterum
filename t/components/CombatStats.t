use 5.40.0;
use Test2::V0;
use FindBin qw($Bin);
use lib "$Bin/../../lib";

use Iterum::ECS;
use Iterum::Components::CombatStats;

# Test component registration
subtest 'Component Registration' => sub {
    my $ecs = Iterum::ECS->new();
    my $component_id = Iterum::Components::CombatStats::register($ecs);
    ok($component_id, 'CombatStats component type was registered');
    
    my $retrieved_id = $ecs->get_id_for_component_type('CombatStats');
    is($retrieved_id, $component_id, 'Component ID can be retrieved by type');
};

# Test adding CombatStats with default values
subtest 'Default CombatStats Values' => sub {
    my $ecs = Iterum::ECS->new();
    Iterum::Components::CombatStats::register($ecs);
    
    my $entity_id = $ecs->new_entity('test_entity');
    Iterum::Components::CombatStats::add($ecs, $entity_id);
    
    my ($stats) = $ecs->get_components($entity_id, 'CombatStats');
    is($stats->{attack}, 10, 'Default attack is 10');
    is($stats->{defense}, 5, 'Default defense is 5');
    is($stats->{attack_buffs}, [], 'No attack buffs by default');
    is($stats->{defense_buffs}, [], 'No defense buffs by default');
};

# Test adding CombatStats with custom values
subtest 'Custom CombatStats Values' => sub {
    my $ecs = Iterum::ECS->new();
    Iterum::Components::CombatStats::register($ecs);
    
    my $entity_id = $ecs->new_entity('test_entity');
    Iterum::Components::CombatStats::add($ecs, $entity_id, attack => 15, defense => 8);
    
    my ($stats) = $ecs->get_components($entity_id, 'CombatStats');
    is($stats->{attack}, 15, 'Custom attack is set correctly');
    is($stats->{defense}, 8, 'Custom defense is set correctly');
};

# Test validation
subtest 'CombatStats Validation' => sub {
    my $ecs = Iterum::ECS->new();
    Iterum::Components::CombatStats::register($ecs);
    
    my $entity_id = $ecs->new_entity('test_entity');
    
    # Test negative stats validation
    like(
        dies { Iterum::Components::CombatStats::add($ecs, $entity_id, attack => -5) },
        qr/attack must be non-negative/,
        'Negative attack throws error'
    );
    
    like(
        dies { Iterum::Components::CombatStats::add($ecs, $entity_id, defense => -3) },
        qr/defense must be non-negative/,
        'Negative defense throws error'
    );
};

# Test stat buffs
subtest 'Stat Buffs' => sub {
    my $ecs = Iterum::ECS->new();
    Iterum::Components::CombatStats::register($ecs);
    
    my $entity_id = $ecs->new_entity('test_entity');
    Iterum::Components::CombatStats::add($ecs, $entity_id, attack => 10, defense => 5);
    
    # Test adding attack buff
    Iterum::Components::CombatStats::add_attack_buff($ecs, $entity_id, {
        value => 5,
        duration => 3,
        source => 'potion'
    });
    
    my ($stats) = $ecs->get_components($entity_id, 'CombatStats');
    is(scalar @{$stats->{attack_buffs}}, 1, 'Attack buff added');
    is($stats->{attack_buffs}[0]{value}, 5, 'Attack buff value is correct');
    is($stats->{attack_buffs}[0]{duration}, 3, 'Attack buff duration is correct');
    
    # Test adding defense buff
    Iterum::Components::CombatStats::add_defense_buff($ecs, $entity_id, {
        value => 3,
        duration => 2,
        source => 'shield'
    });
    
    ($stats) = $ecs->get_components($entity_id, 'CombatStats');
    is(scalar @{$stats->{defense_buffs}}, 1, 'Defense buff added');
    is($stats->{defense_buffs}[0]{value}, 3, 'Defense buff value is correct');
    is($stats->{defense_buffs}[0]{duration}, 2, 'Defense buff duration is correct');
    
    # Test calculating effective stats
    is(
        Iterum::Components::CombatStats::effective_attack($ecs, $entity_id),
        15,
        'Effective attack includes buffs'
    );
    
    is(
        Iterum::Components::CombatStats::effective_defense($ecs, $entity_id),
        8,
        'Effective defense includes buffs'
    );
    
    # Test buff duration decrease
    Iterum::Components::CombatStats::update_buffs($ecs, $entity_id);
    
    ($stats) = $ecs->get_components($entity_id, 'CombatStats');
    is($stats->{attack_buffs}[0]{duration}, 2, 'Attack buff duration decreased');
    is($stats->{defense_buffs}[0]{duration}, 1, 'Defense buff duration decreased');
    
    # Test expired buffs removal
    Iterum::Components::CombatStats::update_buffs($ecs, $entity_id);
    Iterum::Components::CombatStats::update_buffs($ecs, $entity_id);
    
    ($stats) = $ecs->get_components($entity_id, 'CombatStats');
    is(scalar @{$stats->{attack_buffs}}, 0, 'Expired attack buff removed');
    is(scalar @{$stats->{defense_buffs}}, 0, 'Expired defense buff removed');
    
    # Verify effective stats return to base after buffs expire
    is(
        Iterum::Components::CombatStats::effective_attack($ecs, $entity_id),
        10,
        'Effective attack returns to base after buffs expire'
    );
    
    is(
        Iterum::Components::CombatStats::effective_defense($ecs, $entity_id),
        5,
        'Effective defense returns to base after buffs expire'
    );
};

# Test defending status
subtest 'Defending Status' => sub {
    my $ecs = Iterum::ECS->new();
    Iterum::Components::CombatStats::register($ecs);
    
    my $entity_id = $ecs->new_entity('test_entity');
    Iterum::Components::CombatStats::add($ecs, $entity_id);
    
    # Test set_defending
    Iterum::Components::CombatStats::set_defending($ecs, $entity_id, 1);
    my ($stats) = $ecs->get_components($entity_id, 'CombatStats');
    ok($stats->{defending}, 'Defending flag set to true');
    
    # Test defense bonus when defending
    is(
        Iterum::Components::CombatStats::effective_defense($ecs, $entity_id),
        7.5, # 5 * 1.5
        'Defense is increased by 50% when defending'
    );
    
    # Test resetting defending status
    Iterum::Components::CombatStats::set_defending($ecs, $entity_id, 0);
    ($stats) = $ecs->get_components($entity_id, 'CombatStats');
    ok(!$stats->{defending}, 'Defending flag set to false');
    
    is(
        Iterum::Components::CombatStats::effective_defense($ecs, $entity_id),
        5,
        'Defense returns to normal when not defending'
    );
};

done_testing;