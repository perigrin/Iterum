use 5.40.0;
use Test2::V0;
use FindBin qw($Bin);
use lib "$Bin/../../lib";

use Iterum::ECS;
use Iterum::Components::Health;
use Iterum::Components::CombatStats;
use Iterum::Components::EVScore;
use Iterum::Systems::Combat;

# Setup helper function - create an ECS with registered components
sub setup_ecs {
    my $ecs = Iterum::ECS->new();
    Iterum::Components::Health::register($ecs);
    Iterum::Components::CombatStats::register($ecs);
    Iterum::Components::EVScore::register($ecs);
    return $ecs;
}

# Setup helper function - create an entity with health and combat stats
sub create_entity {
    my ($ecs, %params) = @_;
    
    my $entity_id = $ecs->new_entity($params{label} // 'test_entity');
    
    Iterum::Components::Health::add($ecs, $entity_id,
        max_hp     => $params{max_hp} // 100,
        current_hp => $params{current_hp} // ($params{max_hp} // 100),
    );
    
    Iterum::Components::CombatStats::add($ecs, $entity_id,
        attack  => $params{attack}  // 10,
        defense => $params{defense} // 5,
    );
    
    # Add EVScore component for EV tracking
    Iterum::Components::EVScore::add($ecs, $entity_id);
    
    return $entity_id;
}

# Test Combat system creation and registration
subtest 'Combat System Creation' => sub {
    my $ecs = setup_ecs();
    
    my $combat = Iterum::Systems::Combat->new(ecs => $ecs);
    ok($combat, 'Combat system created');
    
    my @required = $combat->components_required();
    is(\@required, ['Health', 'CombatStats'], 'Required components are correct');
    
    $ecs->add_system($combat);
    pass('Combat system added to ECS');
};

# Test initiating combat
subtest 'Initiating Combat' => sub {
    my $ecs = setup_ecs();
    my $combat = Iterum::Systems::Combat->new(ecs => $ecs);
    $ecs->add_system($combat);
    
    # Create two entities
    my $entity1 = create_entity($ecs, label => 'entity1', attack => 15, defense => 5);
    my $entity2 = create_entity($ecs, label => 'entity2', attack => 10, defense => 8);
    
    # Initiate combat
    ok($combat->start_combat($entity1, $entity2), 'Combat initiated');
    ok($combat->is_in_combat($entity1), 'Entity 1 is in combat');
    ok($combat->is_in_combat($entity2), 'Entity 2 is in combat');
    
    # Test with invalid entity
    like(
        dies { $combat->start_combat('invalid_id', $entity2) },
        qr/Entity does not have required components/,
        'Starting combat with invalid entity throws error'
    );
};

# Test attack calculation
subtest 'Attack Calculation' => sub {
    my $ecs = setup_ecs();
    my $combat = Iterum::Systems::Combat->new(ecs => $ecs);
    
    # Create attacker and defender
    my $attacker = create_entity($ecs, attack => 20);
    my $defender = create_entity($ecs, defense => 10);
    
    # Test basic attack
    my ($hit, $damage) = $combat->calculate_attack($attacker, $defender);
    ok(defined $hit, 'Hit result is defined');
    ok($damage >= 0, 'Damage is non-negative');
    
    if ($hit) {
        # If hit, damage should be attacker's attack - defender's defense
        is($damage, 10, 'Damage calculation is correct');
    }
    
    # Test with defender in defensive stance
    Iterum::Components::CombatStats::set_defending($ecs, $defender, 1);
    ($hit, $damage) = $combat->calculate_attack($attacker, $defender);
    
    if ($hit) {
        # Defense should be boosted by 50%
        # 20 - (10 * 1.5) = 20 - 15 = 5
        is($damage, 5, 'Damage is reduced when defender is defending');
    }
};

# Test applying damage
subtest 'Applying Damage' => sub {
    my $ecs = setup_ecs();
    my $combat = Iterum::Systems::Combat->new(ecs => $ecs);
    
    # Create entity with 100 HP
    my $entity = create_entity($ecs, max_hp => 100, current_hp => 100);
    
    # Test damage application
    $combat->apply_damage($entity, 30);
    my ($health) = $ecs->get_components($entity, 'Health');
    is($health->{current_hp}, 70, 'Health reduced correctly');
    
    # Test with damage exceeding current HP
    $combat->apply_damage($entity, 100);
    ($health) = $ecs->get_components($entity, 'Health');
    is($health->{current_hp}, 0, 'Health reduced to 0 when damage exceeds it');
};

# Test complete combat round
subtest 'Combat Round Processing' => sub {
    my $ecs = setup_ecs();
    my $combat = Iterum::Systems::Combat->new(ecs => $ecs);
    $ecs->add_system($combat);
    
    # Create attacker and defender
    my $attacker = create_entity($ecs, 
        label => 'attacker', 
        max_hp => 100, 
        attack => 20,
        defense => 5
    );
    
    my $defender = create_entity($ecs, 
        label => 'defender', 
        max_hp => 80, 
        attack => 15,
        defense => 10
    );
    
    # Start combat
    $combat->start_combat($attacker, $defender);
    
    # Process a round with attacker attacking
    $combat->set_action($attacker, 'attack');
    $combat->set_target($attacker, $defender);
    
    # Process a round with defender defending
    $combat->set_action($defender, 'defend');
    
    # Update the system
    $ecs->update();
    
    # Check results
    my ($defender_health) = $ecs->get_components($defender, 'Health');
    my ($defender_stats) = $ecs->get_components($defender, 'CombatStats');
    
    # Defender should have lost some health if attack hit
    if ($combat->last_hit($attacker)) {
        ok($defender_health->{current_hp} < 80, 'Defender lost health');
    }
    
    # Defender should be in defensive stance
    ok($defender_stats->{defending}, 'Defender is in defensive stance');
    
    # End combat
    $combat->end_combat($attacker, $defender);
    ok(!$combat->is_in_combat($attacker), 'Attacker no longer in combat');
    ok(!$combat->is_in_combat($defender), 'Defender no longer in combat');
};

# Test combat with multiple entities
subtest 'Multiple Entities Combat' => sub {
    my $ecs = setup_ecs();
    my $combat = Iterum::Systems::Combat->new(ecs => $ecs);
    $ecs->add_system($combat);
    
    # Create three entities
    my $entity1 = create_entity($ecs, label => 'entity1');
    my $entity2 = create_entity($ecs, label => 'entity2');
    my $entity3 = create_entity($ecs, label => 'entity3');
    
    # Start combat between entity1 and entity2
    $combat->start_combat($entity1, $entity2);
    
    # Start combat between entity2 and entity3
    $combat->start_combat($entity2, $entity3);
    
    # Entity2 should be in combat with both entity1 and entity3
    ok($combat->are_in_combat($entity1, $entity2), 'Entity1 and Entity2 are in combat');
    ok($combat->are_in_combat($entity2, $entity3), 'Entity2 and Entity3 are in combat');
    
    # Entity1 and Entity3 should not be in combat with each other
    ok(!$combat->are_in_combat($entity1, $entity3), 'Entity1 and Entity3 are not in combat');
    
    # Process some actions
    $combat->set_action($entity1, 'attack');
    $combat->set_target($entity1, $entity2);
    
    $combat->set_action($entity2, 'attack');
    $combat->set_target($entity2, $entity3);
    
    $combat->set_action($entity3, 'defend');
    
    # Update
    $ecs->update();
    
    # End all combats
    $combat->end_all_combats();
    
    ok(!$combat->is_in_combat($entity1), 'Entity1 no longer in combat');
    ok(!$combat->is_in_combat($entity2), 'Entity2 no longer in combat');
    ok(!$combat->is_in_combat($entity3), 'Entity3 no longer in combat');
};

done_testing;