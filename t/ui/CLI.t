use 5.40.0;
use Test2::V0;
use FindBin qw($Bin);
use lib "$Bin/../../lib";

use Iterum::UI::CLI;

# Test CLI initialization
subtest 'Initialization' => sub {
    my $cli = Iterum::UI::CLI->new( test_mode => 1 );
    ok( $cli isa Iterum::UI::CLI, 'CLI object created' );

    # Test that the CLI has the required methods
    can_ok( $cli, 'display_status', 'display_combat_options', 'display_result',
        'get_input', 'display_ev_feedback', 'display_decision_history' );
};

# Test display methods (in test_mode)
subtest 'Display methods' => sub {
    my $cli = Iterum::UI::CLI->new( test_mode => 1 );

    # Test display_status with mock data
    my $player_status = {
        name   => 'Hero',
        health => { current_hp => 80, max_hp  => 100 },
        stats  => { attack     => 10, defense => 5 }
    };

    my $enemy_status = {
        name   => 'Goblin',
        health => { current_hp => 30, max_hp  => 50 },
        stats  => { attack     => 8,  defense => 3 }
    };

    ok( $cli->display_status( $player_status, $enemy_status ),
        'Status display works' );

    # Test other display methods
    my @options = ( 'Attack', 'Defend', 'Use Item' );
    ok( $cli->display_combat_options( \@options ),
        'Combat options display works' );

    my $result = {
        action   => 'Attack',
        success  => 1,
        damage   => 8,
        ev_score => 0.75
    };
    ok( $cli->display_result($result), 'Result display works' );

    my @feedback = (
        "Good choice to attack when enemy health was low.",
        "Consider defending when your health drops below 50%."
    );
    ok( $cli->display_ev_feedback( \@feedback ), 'EV feedback display works' );

    my @history = (
        {
            action     => 'Attack',
            success    => 1,
            ev_score   => 0.8,
            optimal_ev => 0.8
        },
        {
            action     => 'Defend',
            success    => 1,
            ev_score   => 0.6,
            optimal_ev => 0.7
        }
    );
    ok( $cli->display_decision_history( \@history ),
        'Decision history display works' );
};

# Test input handling
subtest 'Input handling' => sub {
    my $cli = Iterum::UI::CLI->new( test_mode => 1 );

    # Mock user input
    $cli->set_test_input('1');

    # Test get_input with valid options
    my @options = ( 'Attack', 'Defend', 'Use Item' );
    is( $cli->get_input( \@options ),
        'Attack', 'Valid input returns correct option' );

    # Test invalid input
    $cli->set_test_input('4');
    like( dies { $cli->get_input( \@options ) },
        qr/Invalid/i, 'Invalid input throws an error' );

    # Test non-numeric input
    $cli->set_test_input('x');
    like( dies { $cli->get_input( \@options ) },
        qr/Invalid/i, 'Non-numeric input throws an error' );
};

# Test utility methods
subtest 'Utility methods' => sub {
    my $cli = Iterum::UI::CLI->new( test_mode => 1 );

# These methods don't do anything in test_mode, so we're just checking they don't throw errors
    ok( lives { $cli->clear_screen() }, 'clear_screen does not throw errors' );
    ok(
        lives { $cli->display_header('Test Header') },
        'display_header does not throw errors'
    );
    ok(
        lives { $cli->display_message('Test Message') },
        'display_message does not throw errors'
    );
    ok(
        lives { $cli->prompt_continue() },
        'prompt_continue does not throw errors'
    );
    ok(
        lives { $cli->colored_puts( 'Test', 'red' ) },
        'colored_puts does not throw errors'
    );
};

done_testing();
