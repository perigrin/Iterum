use 5.40.0;
use experimental 'class';
use experimental 'try';

# AIResponse system for Iterum ECS
# Analyzes player decisions, generates personalized feedback, and adapts AI personality

use Iterum::Components::AIState;

class Iterum::Systems::AIResponse {
    use Carp qw(croak);
    use Time::HiRes qw(time);
    
    field $ecs :param :reader;
    field $ev_system :param :reader;  # Reference to EVScoring system
    field @entities;
    
    # Define required components for this system
    method components_required {
        return ('AIState');
    }
    
    # Set entities for processing
    method set_entities(@new_entities) {
        @entities = @new_entities;
    }
    
    # Update method - called by ECS
    method update($components) {
        # This system primarily responds to requests rather than updating each cycle
        # We could potentially implement automatic periodic feedback here
    }
    
    # Generate feedback based on player's decision history and AI coach personality
    method generate_feedback($coach_id, $player_id) {
        # Get AI coach state
        my ($ai_state) = $ecs->get_components($coach_id, 'AIState');
        return "AI Coach not found" unless $ai_state;
        
        # Get player's decision stats and trend from EVScoring system
        my $stats = $ev_system->get_decision_stats($player_id);
        my $trend = $ev_system->get_decision_trend($player_id);
        
        # Skip if not enough data
        return "Not enough decision data for meaningful feedback" 
            if !$stats || $stats->{total_decisions} < 2;
        
        # Get AI personality traits
        my $personality = $ai_state->{personality};
        my $dominant_trait = '';
        my $max_value = -1;
        
        foreach my $trait (keys %$personality) {
            if ($personality->{$trait} > $max_value) {
                $max_value = $personality->{$trait};
                $dominant_trait = $trait;
            }
        }
        
        # Build appropriate feedback based on stats and personality
        my @feedback_parts;
        
        # Add personality-influenced intro
        push @feedback_parts, $self->_get_personality_intro($personality, $stats->{overall_avg});
        
        # Overall assessment
        push @feedback_parts, $self->_get_overall_assessment($stats, $personality);
        
        # Trend feedback - influenced by encouraging/critical traits
        if (defined $trend->{improving}) {
            if ($trend->{improving}) {
                if ($personality->{encouraging} > 0.5) {
                    push @feedback_parts, "I'm impressed with your improvement in recent decisions!";
                } else {
                    push @feedback_parts, "Your recent decisions show improvement.";
                }
            } else {
                if ($personality->{critical} > 0.7) {
                    push @feedback_parts, "Your decision quality has been declining. You need to reconsider your approach.";
                } elsif ($personality->{critical} > 0.4) {
                    push @feedback_parts, "I've noticed your recent decisions haven't been as strong as before.";
                } else {
                    push @feedback_parts, "Your recent decisions could use a bit more thought.";
                }
            }
        }
        
        # Action-specific feedback - influenced by analytical trait
        if ($personality->{analytical} > 0.5) {
            push @feedback_parts, $self->_get_action_specific_feedback($stats);
        }
        
        # Add helpful suggestions based on patterns
        if ($personality->{helpful} > 0.5) {
            push @feedback_parts, $self->_get_helpful_suggestions($stats, $trend);
        }
        
        # Add sarcastic comment if applicable
        if ($personality->{sarcastic} > 0.5) {
            push @feedback_parts, $self->_get_sarcastic_comment($stats, $trend);
        }
        
        # Combine all feedback parts
        my $feedback = join " ", @feedback_parts;
        
        return $feedback;
    }
    
    # Helper method to get personality-appropriate intro
    method _get_personality_intro($personality, $overall_avg) {
        if ($personality->{encouraging} > 0.7) {
            return "Let's take a look at how you're doing!";
        } elsif ($personality->{critical} > 0.7) {
            return "Time to assess your performance.";
        } elsif ($personality->{analytical} > 0.7) {
            return "Let's analyze your decision patterns.";
        } elsif ($personality->{helpful} > 0.7) {
            return "I'd like to offer some observations to help you improve.";
        } elsif ($personality->{sarcastic} > 0.7) {
            if ($overall_avg < 40) {
                return "Well, that was... interesting.";
            } else {
                return "Not bad, for a human.";
            }
        } else {
            return "Here's my assessment of your decisions:";
        }
    }
    
    # Helper method to get overall assessment
    method _get_overall_assessment($stats, $personality) {
        my $assessment = "";
        
        if ($stats->{overall_avg} >= 80) {
            if ($personality->{encouraging} > 0.5) {
                $assessment = "Your decision-making is excellent! You're consistently making high-value choices.";
            } else {
                $assessment = "Your decision-making is strong. You're making good choices overall.";
            }
        } elsif ($stats->{overall_avg} >= 60) {
            if ($personality->{encouraging} > 0.5) {
                $assessment = "You're making generally solid decisions. Keep it up!";
            } else {
                $assessment = "Your decisions are above average, but there's room for improvement.";
            }
        } elsif ($stats->{overall_avg} >= 40) {
            if ($personality->{critical} > 0.5) {
                $assessment = "Your decision-making needs work. You're missing opportunities to maximize value.";
            } else {
                $assessment = "Your decisions show room for improvement, but you're on the right track.";
            }
        } else {
            if ($personality->{critical} > 0.5) {
                $assessment = "Your decisions have been poor. You need to seriously reconsider your approach.";
            } else {
                $assessment = "I think we need to work on your decision-making strategy.";
            }
        }
        
        return $assessment;
    }
    
    # Helper method to get action-specific feedback
    method _get_action_specific_feedback($stats) {
        my @feedback;
        my @actions = sort keys %{$stats->{action_counts}};
        
        foreach my $action (@actions) {
            my $count = $stats->{action_counts}{$action};
            my $avg = $stats->{action_avgs}{$action};
            
            if ($count > 2) {  # Only comment on actions with enough data
                if ($avg > $stats->{overall_avg} + 10) {
                    push @feedback, "Your '$action' decisions are particularly strong at $avg points.";
                } elsif ($avg < $stats->{overall_avg} - 10) {
                    push @feedback, "Your '$action' decisions are below your average at $avg points.";
                }
            }
        }
        
        # Most used action feedback
        my $most_used = $actions[0];
        my $most_count = $stats->{action_counts}{$most_used};
        foreach my $action (@actions) {
            if ($stats->{action_counts}{$action} > $most_count) {
                $most_used = $action;
                $most_count = $stats->{action_counts}{$action};
            }
        }
        
        if ($most_count > $stats->{total_decisions} * 0.6) {
            push @feedback, "You rely heavily on '$most_used' ($most_count out of $stats->{total_decisions} decisions).";
        }
        
        return join " ", @feedback;
    }
    
    # Helper method to get helpful suggestions
    method _get_helpful_suggestions($stats, $trend) {
        my @suggestions;
        
        # Check for over-reliance on one action
        my $most_used = '';
        my $most_count = 0;
        
        foreach my $action (keys %{$stats->{action_counts}}) {
            if ($stats->{action_counts}{$action} > $most_count) {
                $most_used = $action;
                $most_count = $stats->{action_counts}{$action};
            }
        }
        
        if ($most_count > $stats->{total_decisions} * 0.6) {
            push @suggestions, "Try varying your strategy beyond just '$most_used'. Different situations call for different approaches.";
        }
        
        # Check for missing action types
        my %basic_actions = (
            'attack' => 1,
            'defend' => 1,
            'use_item' => 1
        );
        
        foreach my $action (keys %basic_actions) {
            if (!exists $stats->{action_counts}{$action} || $stats->{action_counts}{$action} < 1) {
                push @suggestions, "Consider using '$action' when appropriate - it hasn't appeared in your strategy yet.";
            }
        }
        
        # Suggestion based on trend
        if (defined $trend->{improving} && !$trend->{improving} && $trend->{avg_change} < -5) {
            push @suggestions, "Take a moment to plan your moves more carefully. Quick decisions aren't working well.";
        }
        
        return @suggestions ? "Suggestion: " . join(" ", @suggestions) : "";
    }
    
    # Helper method to get sarcastic comment
    method _get_sarcastic_comment($stats, $trend) {
        my @comments = ();
        
        # Very low average
        if ($stats->{overall_avg} < 30) {
            push @comments, "I've seen training dummies with better decision-making skills.";
            push @comments, "Are you making these choices randomly? Just checking.";
        }
        
        # Over-reliance on one action
        my $most_used = '';
        my $most_count = 0;
        
        foreach my $action (keys %{$stats->{action_counts}}) {
            if ($stats->{action_counts}{$action} > $most_count) {
                $most_used = $action;
                $most_count = $stats->{action_counts}{$action};
            }
        }
        
        if ($most_count > $stats->{total_decisions} * 0.7) {
            push @comments, "Have you considered that your '$most_used' key might be worn out by now?";
            push @comments, "I'm starting to think '$most_used' is the only command you know.";
        }
        
        # Declining performance
        if (defined $trend->{improving} && !$trend->{improving} && $trend->{avg_change} < -10) {
            push @comments, "Your decision quality is dropping faster than a stone. Impressive, in a way.";
            push @comments, "If getting worse were the goal, you'd be winning.";
        }
        
        # Randomly select one comment if we have any
        return @comments ? $comments[rand @comments] : "";
    }
    
    # Analyze player behavior patterns
    method analyze_player_patterns($coach_id, $player_id) {
        # Get EVScore data
        my ($ev_data) = $ecs->get_components($player_id, 'EVScore');
        return {} unless $ev_data;
        
        # Get player health for context
        my ($health) = $ecs->get_components($player_id, 'Health');
        my $is_low_health = 0;
        if ($health) {
            $is_low_health = ($health->{current_hp} / $health->{max_hp}) < 0.3;
        }
        
        # Get decision stats and trends
        my $stats = $ev_system->get_decision_stats($player_id);
        my $trend = $ev_system->get_decision_trend($player_id);
        my $decisions = $ev_data->{decisions};
        
        # Initialize pattern counter
        my %patterns;
        
        # Check for repetitive actions
        if (@$decisions >= 3) {
            my $last_action = $decisions->[-1]{action};
            if ($decisions->[-2]{action} eq $last_action && $decisions->[-3]{action} eq $last_action) {
                $patterns{repetitive_actions} = 1;
            }
        }
        
        # Check for attacks at low health
        if ($is_low_health && @$decisions > 0 && $decisions->[-1]{action} eq 'attack') {
            $patterns{low_health_attacks} = 1;
        }
        
        # Check for defensive stance
        if (@$decisions > 0 && $decisions->[-1]{action} eq 'defend') {
            $patterns{defensive_stance} = 1;
        }
        
        # Check for optimal/poor choices
        if (@$decisions > 0) {
            my $last_score = $decisions->[-1]{ev_score};
            if ($last_score >= 80) {
                $patterns{optimal_choices} = 1;
            } elsif ($last_score <= 30) {
                $patterns{poor_choices} = 1;
            }
        }
        
        # Check for improving/worsening decisions
        if (defined $trend->{improving}) {
            if ($trend->{improving} && $trend->{avg_change} > 5) {
                $patterns{improved_decisions} = 1;
            } elsif (!$trend->{improving} && $trend->{avg_change} < -5) {
                $patterns{worsening_decisions} = 1;
            }
        }
        
        # Record detected patterns in AIState
        foreach my $pattern (keys %patterns) {
            Iterum::Components::AIState::track_pattern($ecs, $coach_id, $pattern, $patterns{$pattern});
        }
        
        # Get updated patterns from AIState
        my ($ai_state) = $ecs->get_components($coach_id, 'AIState');
        return $ai_state->{player_patterns};
    }
    
    # Adapt AI coach personality based on patterns
    method adapt_coach_personality($coach_id) {
        return Iterum::Components::AIState::adapt_personality($ecs, $coach_id);
    }
    
    # Generate comprehensive feedback after combat
    method generate_post_combat_feedback($coach_id, $player_id, $enemy_id, $outcome) {
        # Analyze patterns first
        $self->analyze_player_patterns($coach_id, $player_id);
        
        # Get AI coach state
        my ($ai_state) = $ecs->get_components($coach_id, 'AIState');
        return "AI Coach not found" unless $ai_state;
        
        # Get player's decision stats
        my $stats = $ev_system->get_decision_stats($player_id);
        my $trend = $ev_system->get_decision_trend($player_id);
        
        # Generate basic feedback
        my $basic_feedback = $self->generate_feedback($coach_id, $player_id);
        
        # Add outcome-specific commentary
        my @feedback_parts = ($basic_feedback);
        
        if ($outcome eq 'victory') {
            if ($ai_state->{personality}{encouraging} > 0.6) {
                push @feedback_parts, "Congratulations on your victory!";
            } elsif ($ai_state->{personality}{analytical} > 0.6) {
                push @feedback_parts, "Your combat strategy resulted in a successful outcome.";
            } else {
                push @feedback_parts, "You won the battle.";
            }
            
            # Add victory quality assessment based on health and decisions
            my ($health) = $ecs->get_components($player_id, 'Health');
            if ($health) {
                my $health_percent = ($health->{current_hp} / $health->{max_hp}) * 100;
                
                if ($health_percent > 75) {
                    if ($ai_state->{personality}{encouraging} > 0.5) {
                        push @feedback_parts, "You handled that fight exceptionally well, taking minimal damage.";
                    } else {
                        push @feedback_parts, "You emerged with most of your health intact.";
                    }
                } elsif ($health_percent < 25) {
                    if ($ai_state->{personality}{critical} > 0.5) {
                        push @feedback_parts, "Though you won, you took a dangerous amount of damage. More caution is advised.";
                    } else {
                        push @feedback_parts, "That was a close call with your health so low.";
                    }
                }
            }
        } elsif ($outcome eq 'defeat') {
            if ($ai_state->{personality}{encouraging} > 0.6) {
                push @feedback_parts, "Don't worry about the defeat - it's a learning opportunity.";
            } elsif ($ai_state->{personality}{critical} > 0.6) {
                push @feedback_parts, "Your defeat was the result of flawed decision-making.";
            } elsif ($ai_state->{personality}{analytical} > 0.6) {
                push @feedback_parts, "Let's analyze what led to this unfortunate outcome.";
            } else {
                push @feedback_parts, "You lost the battle.";
            }
            
            # Add advice for improvement
            if ($ai_state->{personality}{helpful} > 0.5) {
                if ($stats->{overall_avg} < 50) {
                    push @feedback_parts, "Focus on making higher-value decisions next time. Each choice matters.";
                } else {
                    push @feedback_parts, "Even with decent decision-making, sometimes battles don't go our way.";
                }
            }
            
            if ($ai_state->{personality}{sarcastic} > 0.7) {
                push @feedback_parts, "At least you're consistent - consistently ending up defeated.";
            }
        } else {  # Draw or other outcome
            push @feedback_parts, "The battle ended without a clear resolution.";
            
            if ($ai_state->{personality}{analytical} > 0.5) {
                push @feedback_parts, "Consider what factors led to this stalemate and how you might tip the balance next time.";
            }
        }
        
        # Add final thoughts based on personality
        if ($ai_state->{personality}{encouraging} > 0.7) {
            push @feedback_parts, "Keep improving and you'll master this in no time!";
        } elsif ($ai_state->{personality}{helpful} > 0.7) {
            push @feedback_parts, "Remember to assess each situation uniquely and choose actions that maximize your expected value.";
        }
        
        # Combine all feedback parts
        my $feedback = join " ", @feedback_parts;
        
        # Record this feedback in the AI coach's history
        my $feedback_record = {
            message => $feedback,
            tone => $self->_get_dominant_trait($ai_state->{personality}),
            timestamp => time(),
            ev_context => {
                overall_avg => $stats->{overall_avg} // 0,
                recent_trend => defined $trend->{improving} ? 
                    ($trend->{improving} ? "improving" : "declining") : "unknown",
                outcome => $outcome
            }
        };
        
        Iterum::Components::AIState::record_feedback($ecs, $coach_id, $feedback_record);
        
        # Check if we should adapt the coach's personality
        $self->adapt_coach_personality($coach_id);
        
        return $feedback;
    }
    
    # Helper method to get the dominant personality trait
    method _get_dominant_trait($personality) {
        my $dominant_trait = '';
        my $max_value = -1;
        
        foreach my $trait (keys %$personality) {
            if ($personality->{$trait} > $max_value) {
                $max_value = $personality->{$trait};
                $dominant_trait = $trait;
            }
        }
        
        return $dominant_trait;
    }
    
    # Helper method to integrate AI coach feedback into the game loop
    method integrate_with_game_loop($coach_id, $player_id, $enemy_id, $combat_state) {
        my ($ai_state) = $ecs->get_components($coach_id, 'AIState');
        return "AI Coach not found" unless $ai_state;
        
        # Depending on the combat state, provide different types of feedback
        if ($combat_state eq 'start') {
            # Pre-combat advice
            return $self->_generate_pre_combat_advice($coach_id, $player_id, $enemy_id);
        } elsif ($combat_state eq 'in_progress') {
            # Mid-combat hint if player makes a particularly suboptimal choice
            my ($ev_data) = $ecs->get_components($player_id, 'EVScore');
            if ($ev_data && $ev_data->{current_decision} && $ev_data->{current_decision}{ev_score} < 30) {
                return $self->_generate_quick_hint($coach_id, $player_id, $ev_data->{current_decision});
            }
            return '';  # No feedback needed
        } elsif ($combat_state eq 'end') {
            # Post-combat comprehensive feedback
            my $outcome = $self->_determine_combat_outcome($player_id, $enemy_id);
            return $self->generate_post_combat_feedback($coach_id, $player_id, $enemy_id, $outcome);
        }
        
        return '';
    }
    
    # Helper method to generate pre-combat advice
    method _generate_pre_combat_advice($coach_id, $player_id, $enemy_id) {
        my ($ai_state) = $ecs->get_components($coach_id, 'AIState');
        my ($player_health) = $ecs->get_components($player_id, 'Health');
        my ($enemy_health) = $ecs->get_components($enemy_id, 'Health');
        my ($enemy_stats) = $ecs->get_components($enemy_id, 'CombatStats');
        
        my @advice;
        
        # Basic intro based on personality
        if ($ai_state->{personality}{encouraging} > 0.6) {
            push @advice, "You've got this! Remember your training.";
        } elsif ($ai_state->{personality}{analytical} > 0.6) {
            push @advice, "Assess your opponent carefully before committing to a strategy.";
        } elsif ($ai_state->{personality}{helpful} > 0.6) {
            push @advice, "Let me give you some quick advice before this fight.";
        } else {
            push @advice, "Prepare yourself for combat.";
        }
        
        # Enemy assessment
        if ($enemy_stats) {
            if ($enemy_stats->{attack} > $enemy_stats->{defense} * 1.5) {
                push @advice, "This opponent hits hard - consider defensive tactics.";
            } elsif ($enemy_stats->{defense} > $enemy_stats->{attack} * 1.5) {
                push @advice, "This opponent is heavily defensive - patience will be key.";
            }
        }
        
        # Health status advice
        if ($player_health && $player_health->{current_hp} < $player_health->{max_hp} * 0.5) {
            push @advice, "Your health is low going into this fight - exercise caution.";
        }
        
        return join " ", @advice;
    }
    
    # Helper method to generate a quick hint during combat
    method _generate_quick_hint($coach_id, $player_id, $decision) {
        my ($ai_state) = $ecs->get_components($coach_id, 'AIState');
        my $action = $decision->{action};
        my $score = $decision->{ev_score};
        
        # Only give hint for very poor decisions
        return '' unless $score < 30;
        
        my %hints = (
            'attack' => "Attacking might not be optimal right now.",
            'defend' => "Defense isn't your best option in this situation.",
            'use_item' => "That item choice wasn't ideal for this moment."
        );
        
        my $hint = $hints{$action} // "That wasn't the best choice.";
        
        # Modify based on personality
        if ($ai_state->{personality}{critical} > 0.7) {
            $hint = "Poor choice! $hint";
        } elsif ($ai_state->{personality}{helpful} > 0.7) {
            $hint = "$hint Consider your options more carefully.";
        } elsif ($ai_state->{personality}{sarcastic} > 0.7) {
            $hint = "Interesting choice... if you enjoy making mistakes.";
        }
        
        return $hint;
    }
    
    # Helper method to determine combat outcome
    method _determine_combat_outcome($player_id, $enemy_id) {
        my ($player_health) = $ecs->get_components($player_id, 'Health');
        my ($enemy_health) = $ecs->get_components($enemy_id, 'Health');
        
        # Default to draw if we can't determine
        return 'draw' unless $player_health && $enemy_health;
        
        if ($enemy_health->{current_hp} <= 0) {
            return 'victory';
        } elsif ($player_health->{current_hp} <= 0) {
            return 'defeat';
        } else {
            return 'in_progress';
        }
    }
}

1;