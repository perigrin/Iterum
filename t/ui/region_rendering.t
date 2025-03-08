use 5.40.0;
use Test2::V0;
use FindBin qw($Bin);
use lib "$Bin/../../lib";

# Import actual Clay classes
use Clay;
use Clay::Context;
use Clay::Types;
use Clay::Builder;
use Clay::UI;

# Skip the test if Iterum::UI::CLI is not available
eval "use Iterum::UI::CLI";
if ($@) {
    plan skip_all => "Iterum::UI::CLI is not available";
}

# Set up mock screen for testing
{
    package Test::Term::Screen;
    use experimental 'class';
    
    class Test::Term::Screen {
        field $rows :reader :param = 24;
        field $cols :reader :param = 80;
        field $buffer = [];
        field $key_queue = [];
        
        ADJUST {
            # Initialize buffer with spaces
            for my $r (0..$rows-1) {
                $buffer->[$r] = [];
                for my $c (0..$cols-1) {
                    $buffer->[$r][$c] = ' ';
                }
            }
        }
        
        method at($row, $col) {
            $self->{current_row} = $row;
            $self->{current_col} = $col;
            return $self;
        }
        
        method puts($text) {
            my $row = $self->{current_row};
            my $col = $self->{current_col};
            
            # Handle text that goes beyond the screen edges
            my $len = length($text);
            for my $i (0..$len-1) {
                last if $col + $i >= $cols;
                $buffer->[$row][$col + $i] = substr($text, $i, 1);
            }
            
            return $self;
        }
        
        method clrscr() {
            for my $r (0..$rows-1) {
                for my $c (0..$cols-1) {
                    $buffer->[$r][$c] = ' ';
                }
            }
            return $self;
        }
        
        method clear() { return $self->clrscr(); }
        
        method getch() {
            return @$key_queue ? shift @$key_queue : '';
        }
        
        method key_pressed($timeout = 0) {
            return scalar @$key_queue > 0;
        }
        
        method send_keys(@keys) {
            push @$key_queue, @keys;
            return $self;
        }
        
        method render() {
            my $result = '';
            for my $r (0..$rows-1) {
                $result .= join('', map { $buffer->[$r][$_] } (0..$cols-1)) . "\n";
            }
            return $result;
        }
        
        method contains($text) {
            my $screen_text = $self->render();
            return $screen_text =~ /\Q$text\E/ ? 1 : 0;
        }
        
        method extract_region($row, $col, $height, $width) {
            my $result = '';
            for my $r ($row..$row+$height-1) {
                last if $r >= $rows;
                for my $c ($col..$col+$width-1) {
                    last if $c >= $cols;
                    $result .= $buffer->[$r][$c];
                }
                $result .= "\n";
            }
            return $result;
        }
    }
}

# Set up a test screen
my $test_screen = Test::Term::Screen->new(
    rows => 24,
    cols => 80,
);

# Create a CLI instance with our test buffer
sub create_test_cli {
    my $test_buffer = Clay::Buffer->new(
        screen => $test_screen,
        width => 80,
        height => 24
    );
    
    my $cli = Iterum::UI::CLI->new();
    return $cli;
}

# Helper function to detect region overlap
sub regions_overlap {
    my ($bounds1, $bounds2) = @_;
    
    # Calculate region boundaries
    my $r1_left = $bounds1->{x};
    my $r1_right = $bounds1->{x} + $bounds1->{width} - 1;
    my $r1_top = $bounds1->{y};
    my $r1_bottom = $bounds1->{y} + $bounds1->{height} - 1;
    
    my $r2_left = $bounds2->{x};
    my $r2_right = $bounds2->{x} + $bounds2->{width} - 1;
    my $r2_top = $bounds2->{y};
    my $r2_bottom = $bounds2->{y} + $bounds2->{height} - 1;
    
    # Check for overlap
    return 1 if (
        $r1_left <= $r2_right &&
        $r1_right >= $r2_left &&
        $r1_top <= $r2_bottom &&
        $r1_bottom >= $r2_top
    );
    
    return 0;
}

# Helper to check if region fits within screen bounds
sub region_fits_screen {
    my ($bounds, $width, $height) = @_;
    
    return (
        $bounds->{x} >= 0 &&
        $bounds->{y} >= 0 &&
        $bounds->{x} + $bounds->{width} <= $width &&
        $bounds->{y} + $bounds->{height} <= $height
    );
}

# Test UI element discovery and bounds retrieval
subtest 'UI Element Discovery' => sub {
    my $cli = create_test_cli();
    
    # Test find_element method for basic UI elements
    ok($cli->find_element('root'), 'Root element exists');
    ok($cli->find_element('header'), 'Header element exists');
    ok($cli->find_element('title'), 'Title element exists');
    ok($cli->find_element('status_area'), 'Status area element exists');
    ok($cli->find_element('player'), 'Player element exists');
    ok($cli->find_element('enemy'), 'Enemy element exists');
    ok($cli->find_element('messages'), 'Messages element exists');
    ok($cli->find_element('input'), 'Input element exists');
    
    # Test getting bounds of elements
    my $root_bounds = $cli->get_element_bounds('root');
    ok($root_bounds, 'Root element bounds retrieved');
    is($root_bounds->{x}, 0, 'Root element starts at x=0');
    is($root_bounds->{y}, 0, 'Root element starts at y=0');
    ok($root_bounds->{width} > 0, 'Root element has positive width');
    ok($root_bounds->{height} > 0, 'Root element has positive height');
    
    # Test with non-existent element
    ok(!$cli->find_element('non_existent'), 'Non-existent element returns undef');
    ok(!$cli->get_element_bounds('non_existent'), 'Non-existent element bounds returns undef');
};

# Test that UI elements don't overlap
subtest 'UI Element Layout' => sub {
    my $cli = create_test_cli();
    
    # Get the bounds of key UI elements
    my $header_bounds = $cli->get_element_bounds('header');
    my $title_bounds = $cli->get_element_bounds('title');
    my $player_bounds = $cli->get_element_bounds('player');
    my $enemy_bounds = $cli->get_element_bounds('enemy');
    my $messages_bounds = $cli->get_element_bounds('messages');
    my $feedback_area_bounds = $cli->get_element_bounds('feedback_area');
    my $combat_options_bounds = $cli->get_element_bounds('combat_options');
    my $ev_feedback_bounds = $cli->get_element_bounds('ev_feedback');
    my $result_bounds = $cli->get_element_bounds('result');
    my $input_bounds = $cli->get_element_bounds('input');
    
    # Check that elements don't overlap (except parent/child)
    ok(!regions_overlap($header_bounds, $messages_bounds), 'Header and messages do not overlap');
    ok(!regions_overlap($player_bounds, $enemy_bounds), 'Player and enemy do not overlap');
    ok(!regions_overlap($messages_bounds, $result_bounds), 'Messages and result do not overlap');
    ok(!regions_overlap($combat_options_bounds, $ev_feedback_bounds), 'Combat options and EV feedback do not overlap');
    
    # Check that elements fit within the screen
    my $width = $cli->find_element('root')->{computed_width};
    my $height = $cli->find_element('root')->{computed_height};
    
    ok(region_fits_screen($header_bounds, $width, $height), 'Header fits within screen');
    ok(region_fits_screen($title_bounds, $width, $height), 'Title fits within screen');
    ok(region_fits_screen($player_bounds, $width, $height), 'Player fits within screen');
    ok(region_fits_screen($enemy_bounds, $width, $height), 'Enemy fits within screen');
    ok(region_fits_screen($messages_bounds, $width, $height), 'Messages fits within screen');
    ok(region_fits_screen($combat_options_bounds, $width, $height), 'Combat options fits within screen');
    ok(region_fits_screen($ev_feedback_bounds, $width, $height), 'EV feedback fits within screen');
    ok(region_fits_screen($result_bounds, $width, $height), 'Result fits within screen');
    ok(region_fits_screen($input_bounds, $width, $height), 'Input fits within screen');
    
    # Check relative positions of elements
    ok($header_bounds->{y} < $messages_bounds->{y}, 'Header is above messages');
    ok($messages_bounds->{y} < $result_bounds->{y}, 'Messages is above result');
    ok($combat_options_bounds->{x} != $ev_feedback_bounds->{x}, 'Combat options and EV feedback are side by side');
    ok($input_bounds->{y} > $result_bounds->{y}, 'Input is below result');
};

# Test rendering in regions
subtest 'Region Rendering' => sub {
    my $cli = create_test_cli();
    $test_screen->clear();
    
    # Test render_element to add content to specific regions
    ok($cli->render_element('header', sub {
        my $ctx = shift;
        $ctx->add_text(0, 0, "Test Header");
    }), 'Render to header');
    
    ok($cli->render_element('player', sub {
        my $ctx = shift;
        $ctx->add_text(0, 0, "Player Name");
        $ctx->add_text(0, 1, "HP: 100/100");
    }), 'Render to player');
    
    ok($cli->render_element('enemy', sub {
        my $ctx = shift;
        $ctx->add_text(0, 0, "Enemy Name");
        $ctx->add_text(0, 1, "HP: 50/50");
    }), 'Render to enemy');
    
    $cli->refresh();
    
    # Check that content appears in the correct regions
    my $screen_content = $test_screen->render();
    like($screen_content, qr/Test Header/, 'Header content is displayed');
    like($screen_content, qr/Player Name/, 'Player content is displayed');
    like($screen_content, qr/Enemy Name/, 'Enemy content is displayed');
    
    # Extract region content and check that it appears in the right place
    my $header_bounds = $cli->get_element_bounds('header');
    my $player_bounds = $cli->get_element_bounds('player');
    my $enemy_bounds = $cli->get_element_bounds('enemy');
    
    my $header_content = $test_screen->extract_region(
        $header_bounds->{y},
        $header_bounds->{x},
        $header_bounds->{height},
        $header_bounds->{width}
    );
    my $player_content = $test_screen->extract_region(
        $player_bounds->{y},
        $player_bounds->{x},
        $player_bounds->{height},
        $player_bounds->{width}
    );
    my $enemy_content = $test_screen->extract_region(
        $enemy_bounds->{y},
        $enemy_bounds->{x},
        $enemy_bounds->{height},
        $enemy_bounds->{width}
    );
    
    like($header_content, qr/Test Header/, 'Header content is in header region');
    like($player_content, qr/Player Name/, 'Player content is in player region');
    unlike($player_content, qr/Enemy Name/, 'Enemy content is not in player region');
    like($enemy_content, qr/Enemy Name/, 'Enemy content is in enemy region');
    unlike($enemy_content, qr/Player Name/, 'Player content is not in enemy region');
};

# Test drawing boxes and filling regions
subtest 'Region Drawing' => sub {
    my $cli = create_test_cli();
    $test_screen->clear();
    
    # Test drawing boxes around regions
    ok($cli->draw_box('player', 'single', 'Player Info'), 'Draw box around player region');
    ok($cli->draw_box('enemy', 'single', 'Enemy Info'), 'Draw box around enemy region');
    
    $cli->refresh();
    
    # Check that boxes are drawn
    my $screen_content = $test_screen->render();
    like($screen_content, qr/Player Info/, 'Player box title is displayed');
    like($screen_content, qr/Enemy Info/, 'Enemy box title is displayed');
    
    # Test filling regions with backgrounds
    $cli->clear();
    ok($cli->fill_element('player', 'blue'), 'Fill player region');
    ok($cli->fill_element('enemy', 'red'), 'Fill enemy region');
    
    # Add text to filled regions
    ok($cli->add_text_to_element('player', 2, 1, 'Player Text', 'white', 1), 'Add text to player region');
    ok($cli->add_text_to_element('enemy', 2, 1, 'Enemy Text', 'white', 1), 'Add text to enemy region');
    
    $cli->refresh();
    
    # Check that text appears in the correct regions
    $screen_content = $test_screen->render();
    like($screen_content, qr/Player Text/, 'Player text is displayed');
    like($screen_content, qr/Enemy Text/, 'Enemy text is displayed');
    
    # Test clearing regions
    $cli->clear();
    ok($cli->clear_element('player'), 'Clear player region');
    ok($cli->clear_element('enemy'), 'Clear enemy region');
    
    $cli->refresh();
    
    # Check that regions are cleared
    $screen_content = $test_screen->render();
    unlike($screen_content, qr/Player Text/, 'Player text is cleared');
    unlike($screen_content, qr/Enemy Text/, 'Enemy text is cleared');
};

# Test integrated UI rendering
subtest 'Integrated UI Rendering' => sub {
    my $cli = create_test_cli();
    $test_screen->clear();
    
    # Test display_status with mock data
    my $player_status = {
        name => 'Hero',
        health => { current_hp => 80, max_hp => 100 },
        stats => { attack => 10, defense => 5 }
    };
    
    my $enemy_status = {
        name => 'Goblin',
        health => { current_hp => 30, max_hp => 50 },
        stats => { attack => 8, defense => 3 }
    };
    
    ok($cli->display_status($player_status, $enemy_status), 'display_status returns success');
    
    # Check that content appears in the correct regions
    my $screen_content = $test_screen->render();
    
    # Extract region content
    my $player_bounds = $cli->get_element_bounds('player');
    my $enemy_bounds = $cli->get_element_bounds('enemy');
    
    my $player_content = $test_screen->extract_region(
        $player_bounds->{y},
        $player_bounds->{x},
        $player_bounds->{height},
        $player_bounds->{width}
    );
    my $enemy_content = $test_screen->extract_region(
        $enemy_bounds->{y},
        $enemy_bounds->{x},
        $enemy_bounds->{height},
        $enemy_bounds->{width}
    );
    
    like($player_content, qr/Hero/, 'Player name is in player region');
    like($player_content, qr/80.*100/, 'Player HP is in player region');
    like($enemy_content, qr/Goblin/, 'Enemy name is in enemy region');
    like($enemy_content, qr/30.*50/, 'Enemy HP is in enemy region');
    
    # Test other UI components
    $cli->clear();
    ok($cli->display_combat_options(['attack', 'defend', 'item']), 'Display combat options');
    $cli->refresh();
    
    my $combat_options_bounds = $cli->get_element_bounds('combat_options');
    my $combat_options_content = $test_screen->extract_region(
        $combat_options_bounds->{y},
        $combat_options_bounds->{x},
        $combat_options_bounds->{height},
        $combat_options_bounds->{width}
    );
    
    like($combat_options_content, qr/attack/i, 'Attack option is in combat options region');
    like($combat_options_content, qr/defend/i, 'Defend option is in combat options region');
    
    # Test result display
    $cli->clear();
    ok($cli->display_result({
        action => 'attack',
        success => 1,
        damage => 15,
        ev_score => 0.75
    }), 'Display result');
    $cli->refresh();
    
    my $result_bounds = $cli->get_element_bounds('result');
    my $result_content = $test_screen->extract_region(
        $result_bounds->{y},
        $result_bounds->{x},
        $result_bounds->{height},
        $result_bounds->{width}
    );
    
    like($result_content, qr/attack/i, 'Action is in result region');
    like($result_content, qr/Success/i, 'Success is in result region');
    like($result_content, qr/15/, 'Damage is in result region');
};

done_testing();
