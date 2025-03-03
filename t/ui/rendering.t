use strict;
use warnings;
use utf8;
use 5.40.0;

use Test::More;
use FindBin qw($Bin);
use lib "$Bin/../../lib";

# Create Test::Clay::Buffer - an in-memory buffer for testing
{
    package Test::Clay::Buffer;
    use experimental 'class';
    
    class Test::Clay::Buffer {
        field $width :reader :param = 80;
        field $height :reader :param = 24;
        field $x :reader = 0;
        field $y :reader = 0;
        field $buffer = [];
        field $debug_mode = 0;
        
        ADJUST {
            # Initialize buffer with spaces
            for my $y (0..$height-1) {
                $buffer->[$y] = [];
                for my $x (0..$width-1) {
                    $buffer->[$y][$x] = ' ';
                }
            }
        }
        
        # Add compatibility methods for code that expects cols() and rows()
        method cols() { return $width; }
        method rows() { return $height; }
        
        method at($row, $col) {
            if ($row >= 0 && $row < $height && $col >= 0 && $col < $width) {
                $x = $col;
                $y = $row;
            }
            return $self;
        }
        
        method put_char($row, $col, $char, $attrs = {}) {
            if ($row >= 0 && $row < $height && $col >= 0 && $col < $width) {
                $buffer->[$row][$col] = substr($char, 0, 1);
                $x = $col + 1;
                $y = $row;
            }
            return $self;
        }
        
        method put_string($row, $col, $string, $attrs = {}) {
            if ($row >= 0 && $row < $height && $col >= 0 && $col < $width) {
                my $len = length($string);
                my $max_len = $width - $col;
                $len = $max_len if $len > $max_len;
                
                for my $i (0..$len-1) {
                    $buffer->[$row][$col + $i] = substr($string, $i, 1);
                }
                
                $x = $col + $len;
                $y = $row;
            }
            return $self;
        }
        
        method fill($row, $col, $fill_width, $fill_height, $char, $attrs = {}) {
            return $self if $fill_width <= 0 || $fill_height <= 0;
            
            my $char_to_use = substr($char, 0, 1) || ' ';
            
            for my $y_offset (0..$fill_height-1) {
                my $current_row = $row + $y_offset;
                last if $current_row >= $height;
                
                for my $x_offset (0..$fill_width-1) {
                    my $current_col = $col + $x_offset;
                    last if $current_col >= $width;
                    
                    $buffer->[$current_row][$current_col] = $char_to_use;
                }
            }
            
            $x = $col;
            $y = $row + $fill_height - 1;
            $y = $height - 1 if $y >= $height;
            
            return $self;
        }
        
        method draw_hline($row, $col, $length, $char, $attrs = {}) {
            return $self->fill($row, $col, $length, 1, $char, $attrs);
        }
        
        method draw_vline($row, $col, $length, $char, $attrs = {}) {
            return $self->fill($row, $col, 1, $length, $char, $attrs);
        }
        
        method draw_box($row, $col, $width, $height, $style = 'single', $attrs = {}) {
            return $self if $width <= 2 || $height <= 2;
            
            # Define box characters
            my $h_char = $style eq 'double' ? '=' : '-';
            my $v_char = '|';
            my $corner = '+';
            
            # Draw top horizontal line
            $self->put_char($row, $col, $corner, $attrs);
            $self->draw_hline($row, $col + 1, $width - 2, $h_char, $attrs);
            $self->put_char($row, $col + $width - 1, $corner, $attrs);
            
            # Draw vertical lines
            for my $y_offset (1..$height-2) {
                $self->put_char($row + $y_offset, $col, $v_char, $attrs);
                $self->put_char($row + $y_offset, $col + $width - 1, $v_char, $attrs);
            }
            
            # Draw bottom horizontal line
            $self->put_char($row + $height - 1, $col, $corner, $attrs);
            $self->draw_hline($row + $height - 1, $col + 1, $width - 2, $h_char, $attrs);
            $self->put_char($row + $height - 1, $col + $width - 1, $corner, $attrs);
            
            return $self;
        }
        
        method clear() {
            for my $y (0..$height-1) {
                for my $x (0..$width-1) {
                    $buffer->[$y][$x] = ' ';
                }
            }
            $x = 0;
            $y = 0;
            return $self;
        }
        
        method clrscr() { return $self->clear(); }
        
        method getch() { return 'a'; }  # Mock user input
        
        method key_pressed($seconds = 0) { return 0; }
        
        method refresh() { return $self; }
        
        method set_debug_mode($mode) {
            $debug_mode = $mode ? 1 : 0;
            return $self;
        }
        
        method colored_puts($text, $color = undef) {
            return $self->put_string($y, $x, $text);
        }
        
        # Testing-specific methods
        method get_cell($row, $col) {
            return '' unless $row >= 0 && $row < $height && $col >= 0 && $col < $width;
            return $buffer->[$row][$col];
        }
        
        method get_row($row) {
            return '' unless $row >= 0 && $row < $height;
            return join('', map { $buffer->[$row][$_] } (0..$width-1));
        }
        
        method get_region($row, $col, $width, $height) {
            my @result;
            for my $y ($row..min($row+$height-1, $height-1)) {
                push @result, join('', map { $buffer->[$y][$_] } ($col..min($col+$width-1, $width-1)));
            }
            return @result;
        }
        
        method find_text($text) {
            for my $y (0..$height-1) {
                my $row = join('', map { $buffer->[$y][$_] } (0..$width-1));
                if ($row =~ /$text/) {
                    return ($y, index($row, $text));
                }
            }
            return (undef, undef);
        }
        
        method dump_buffer() {
            my $result = '';
            for my $y (0..$height-1) {
                $result .= join('', map { $buffer->[$y][$_] } (0..$width-1)) . "\n";
            }
            return $result;
        }
        
        sub min {
            my ($a, $b) = @_;
            return $a < $b ? $a : $b;
        }
    }
}

# Mock the Clay module to use our test buffer
{
    package Clay;
    use experimental 'class';
    use Exporter 'import';
    
    our @EXPORT = qw(create_context);
    
    sub create_context {
        my ($buffer) = @_;
        # If a real buffer was passed, replace it with our test buffer
        $buffer = Test::Clay::Buffer->new() if $buffer;
        return Clay::Context->new(buffer => $buffer);
    }
}

# Import required modules
use Iterum::UI::CLI;
use Iterum::Util::Logger;

# Simple logger stub to avoid actual logging during tests
{
    package Test::Logger;
    use experimental 'class';
    
    class Test::Logger {
        method debug($msg) { }
        method info($msg) { }
        method warn($msg) { }
        method error($msg) { }
        
        method get_child($name) {
            return $self;
        }
    }
    
    # Override Iterum::Util::Logger to return our test logger
    no warnings 'redefine';
    *Iterum::Util::Logger::get_instance = sub {
        state $instance = Test::Logger->new();
        return $instance;
    };
}

# Test helper to create a CLI instance with our test buffer
sub create_cli {
    my $buffer = Test::Clay::Buffer->new();
    my $cli = Iterum::UI::CLI->new(buffer => $buffer);
    return ($cli, $buffer);
}

# Begin tests
subtest 'UI region definitions' => sub {
    my ($cli, $buffer) = create_cli();
    
    # Test define_ui_regions method
    my $regions = $cli->define_ui_regions();
    ok($regions, 'define_ui_regions returns a value');
    ok(exists $regions->{header}, 'header region exists');
    ok(exists $regions->{player}, 'player region exists');
    ok(exists $regions->{enemy}, 'enemy region exists');
    ok(exists $regions->{messages}, 'messages region exists');
    ok(exists $regions->{combat_options}, 'combat_options region exists');
    ok(exists $regions->{input}, 'input region exists');
    
    # Test get_region method
    my $header_region = $cli->get_region('header');
    ok($header_region, 'get_region returns a value for valid region');
    is($header_region->{row}, 0, 'header region starts at row 0');
    is($header_region->{col}, 0, 'header region starts at column 0');
    is($header_region->{width}, $buffer->width, 'header region width matches terminal width');
    is($header_region->{height}, 2, 'header region has correct height');
    
    # Test region overlap detection
    my $player_region = $cli->get_region('player');
    my $enemy_region = $cli->get_region('enemy');
    
    # Check that player and enemy regions don't overlap horizontally
    isnt($player_region->{col} + $player_region->{width}, $enemy_region->{col},
        'Player region should not overlap with enemy region');
    
    # Check that all regions are within terminal boundaries
    for my $region_name (keys %$regions) {
        my $region = $regions->{$region_name};
        ok($region->{row} >= 0, "$region_name region row start is non-negative");
        ok($region->{col} >= 0, "$region_name region column start is non-negative");
        ok($region->{row} + $region->{height} <= $buffer->height, 
           "$region_name region fits within terminal height");
        ok($region->{col} + $region->{width} <= $buffer->width, 
           "$region_name region fits within terminal width");
    }
};

subtest 'Text wrapping' => sub {
    my ($cli, $buffer) = create_cli();
    
    # Test the _wrap_message method with various inputs
    my @wrapped = $cli->_wrap_message("This is a test message", 20);
    is(scalar @wrapped, 1, 'Short message produces 1 line');
    is($wrapped[0], "This is a test message", 'Short message content preserved');
    
    @wrapped = $cli->_wrap_message("This is a much longer test message that should wrap to multiple lines", 20);
    ok(scalar @wrapped > 1, 'Long message produces multiple lines');
    ok(length($wrapped[0]) <= 20, 'Each wrapped line respects max width');
    ok(length($wrapped[1]) <= 20, 'Each wrapped line respects max width');
    
    # Test with very long words
    @wrapped = $cli->_wrap_message("This supercalifragilisticexpialidocious word is very long", 20);
    ok(scalar @wrapped >= 2, 'Message with long word produces multiple lines');
    like($wrapped[1], qr/\.\.\.$/, 'Long word gets truncated with ellipsis');
    
    # Test with empty input
    @wrapped = $cli->_wrap_message("", 20);
    is(scalar @wrapped, 1, 'Empty string produces 1 empty line');
    is($wrapped[0], "", 'Empty string content preserved');
    
    # Test with undef
    @wrapped = $cli->_wrap_message(undef, 20);
    is(scalar @wrapped, 0, 'Undef produces no lines');
    
    # Test with zero width
    @wrapped = $cli->_wrap_message("This is a test", 0);
    is(scalar @wrapped, 0, 'Zero width produces no lines');
};

subtest 'Entity status display' => sub {
    my ($cli, $buffer) = create_cli();
    
    # Create test entity data
    my $player = {
        name => "TestPlayer",
        health => {
            current_hp => 80,
            max_hp => 100,
        },
        stats => {
            attack => 15,
            defense => 10,
        }
    };
    
    my $enemy = {
        name => "TestEnemy",
        health => {
            current_hp => 50,
            max_hp => 100,
        },
        stats => {
            attack => 12,
            defense => 8,
        }
    };
    
    # Test player status display
    my $result = $cli->display_player_status($player);
    ok($result, 'display_player_status returns success');
    
    # Verify player name appears in the buffer
    my ($row, $col) = $buffer->find_text('TestPlayer');
    ok(defined $row, 'Player name found in buffer');
    
    # Test enemy status display
    $buffer->clear();
    $result = $cli->display_enemy_status($enemy);
    ok($result, 'display_enemy_status returns success');
    
    # Verify enemy name appears in the buffer
    ($row, $col) = $buffer->find_text('TestEnemy');
    ok(defined $row, 'Enemy name found in buffer');
    
    # Test invalid entity handling
    $result = $cli->display_entity_status(undef);
    is($result, 0, 'display_entity_status returns 0 for undefined entity');
    
    $result = $cli->display_entity_status({});
    is($result, 0, 'display_entity_status returns 0 for entity missing fields');
    
    $result = $cli->display_entity_status({
        name => "Incomplete",
        health => { current_hp => 10 }  # Missing max_hp and stats
    });
    is($result, 0, 'display_entity_status returns 0 for incomplete entity data');
};

subtest 'Message handling' => sub {
    my ($cli, $buffer) = create_cli();
    
    # Test adding various message types
    ok($cli->add_message("Test info message"), 'add_message returns success');
    ok($cli->add_combat_message("Test combat message"), 'add_combat_message returns success');
    ok($cli->add_ev_message("Test EV message"), 'add_ev_message returns success');
    ok($cli->add_system_message("Test system message"), 'add_system_message returns success');
    ok($cli->add_error_message("Test error message"), 'add_error_message returns success');
    
    # Test message coalescing
    $cli->configure_message_display({ coalesce_time => 10 });
    ok($cli->add_message("Duplicate message"), 'First duplicate message added');
    ok($cli->add_message("Duplicate message"), 'Second duplicate message coalesced');
    
    # Test message history display
    $buffer->clear();
    ok($cli->display_message_history(), 'display_message_history returns success');
    
    # Verify messages appear in the buffer
    my ($row, $col) = $buffer->find_text('Messages');
    ok(defined $row, 'Message header found in buffer');
    
    # Test message stats
    my $stats = $cli->get_message_stats();
    ok($stats, 'get_message_stats returns a value');
    ok($stats->{count} > 0, 'Message count is positive');
    ok(exists $stats->{types}{combat}, 'Combat message type tracked');
    ok(exists $stats->{types}{ev}, 'EV message type tracked');
    ok(exists $stats->{types}{system}, 'System message type tracked');
    ok(exists $stats->{types}{error}, 'Error message type tracked');
    
    # Test clearing messages
    ok($cli->clear_messages(), 'clear_messages returns success');
    $stats = $cli->get_message_stats();
    is($stats->{count}, 0, 'Message count is zero after clearing');
};

subtest 'Combat options display' => sub {
    my ($cli, $buffer) = create_cli();
    
    # Test with various option sets
    my $options = ['attack', 'defend', 'item', 'flee'];
    $buffer->clear();
    ok($cli->display_combat_options($options), 'display_combat_options returns success with 4 options');
    
    # Verify options appear in the buffer
    my ($row, $col) = $buffer->find_text('attack');
    ok(defined $row, 'First option found in buffer');
    ($row, $col) = $buffer->find_text('defend');
    ok(defined $row, 'Second option found in buffer');
    
    $options = ['attack'];
    $buffer->clear();
    ok($cli->display_combat_options($options), 'display_combat_options returns success with 1 option');
    
    # Verify option appears in the buffer
    ($row, $col) = $buffer->find_text('attack');
    ok(defined $row, 'Single option found in buffer');
    
    $options = ['attack', 'defend', 'item', 'flee', 'help', 'quit', 'extra1', 'extra2'];
    $buffer->clear();
    ok($cli->display_combat_options($options), 'display_combat_options returns success with many options');
    
    $options = [];
    $buffer->clear();
    ok($cli->display_combat_options($options), 'display_combat_options returns success with empty options');
};

subtest 'Header and title display' => sub {
    my ($cli, $buffer) = create_cli();
    
    # Test header display
    $buffer->clear();
    ok($cli->display_header("TEST HEADER"), 'display_header returns success');
    
    # Verify header appears in the buffer
    my ($row, $col) = $buffer->find_text('TEST HEADER');
    ok(defined $row, 'Header text found in buffer');
    is($row, 0, 'Header displayed at row 0');
    
    # Test with very long header
    $buffer->clear();
    ok($cli->display_header("THIS IS A VERY LONG HEADER THAT EXCEEDS THE NORMAL WIDTH"), 
       'display_header returns success with long header');
    
    # Verify header appears in the buffer
    ($row, $col) = $buffer->find_text('THIS IS A VERY LONG HEADER');
    ok(defined $row, 'Long header found in buffer');
};

subtest 'UI rendering integration' => sub {
    my ($cli, $buffer) = create_cli();
    
    # Test full status display with player and enemy
    my $player = {
        name => "TestPlayer",
        health => {
            current_hp => 80,
            max_hp => 100,
        },
        stats => {
            attack => 15,
            defense => 10,
        }
    };
    
    my $enemy = {
        name => "TestEnemy",
        health => {
            current_hp => 50,
            max_hp => 100,
        },
        stats => {
            attack => 12,
            defense => 8,
        }
    };
    
    # Test full status display
    $buffer->clear();
    ok($cli->display_status($player, $enemy), 'display_status returns success');
    
    # Verify both player and enemy names appear in the buffer
    my ($player_row, $player_col) = $buffer->find_text('TestPlayer');
    my ($enemy_row, $enemy_col) = $buffer->find_text('TestEnemy');
    ok(defined $player_row, 'Player name found in buffer');
    ok(defined $enemy_row, 'Enemy name found in buffer');
    
    # Verify they don't occupy the same row
    if (defined $player_row && defined $enemy_row) {
        ok($player_row != $enemy_row || 
           abs($player_col - $enemy_col) > length('TestPlayer'), 
           'Player and enemy names do not overlap');
    }
    
    # Test with added messages
    $cli->add_message("Test message for integrated display");
    $buffer->clear();
    ok($cli->display_status($player, $enemy), 'display_status returns success with messages');
    
    # Test with combat options
    my $options = ['attack', 'defend', 'item', 'flee'];
    $buffer->clear();
    ok($cli->display_combat_options($options), 'display_combat_options returns success');
    
    # Verify options appear
    my ($row, $col) = $buffer->find_text('attack');
    ok(defined $row, 'Combat option found in buffer');
    
    # Test result display
    my $result = {
        action => 'attack',
        success => 1,
        damage => 15,
        ev_score => 0.85,
    };
    $buffer->clear();
    ok($cli->display_result($result), 'display_result returns success');
    
    # Verify result appears
    ($row, $col) = $buffer->find_text('Result');
    ok(defined $row, 'Result header found in buffer');
    
    ($row, $col) = $buffer->find_text('attack');
    ok(defined $row, 'Action found in buffer');
    
    # Test EV feedback display
    my $feedback = ['Good choice attacking when enemy was weak', 
                   'Consider defending when your health is low'];
    $buffer->clear();
    ok($cli->display_ev_feedback($feedback), 'display_ev_feedback returns success');
    
    # Verify feedback appears
    ($row, $col) = $buffer->find_text('Good choice');
    ok(defined $row, 'Feedback found in buffer');
};

# Cleanup any resources if needed

done_testing();