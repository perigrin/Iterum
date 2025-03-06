use 5.40.0;
use Test2::V0;
use FindBin qw($Bin);
use lib "$Bin/../../lib";

use Test::Term::Screen;
use Clay::Buffer;
use File::Temp qw(tempfile);

# Skip the test if Iterum::UI::CLI is not available
eval "use Iterum::UI::CLI";
if ($@) {
    plan skip_all => "Iterum::UI::CLI is not available";
}

# Set up a test screen
my $test_screen = Test::Term::Screen->new(
    rows => 24,
    cols => 80,
);

# Test debug logging functionality
subtest 'Debug Logging' => sub {
    # Create CLI with debugging explicitly disabled for this test
    my $cli = Iterum::UI::CLI->new(
        buffer => Clay::Buffer->new(screen => $test_screen)
    );
    
    # Clear any ENV vars that might affect tests
    local $ENV{ITERUM_DEBUG} = 0;
    
    # Test debug_toggle_log
    # CLI starts with debugging disabled
    is($cli->debug_toggle_log(), 1, "Debug logging enabled");  # 1 means enabled
    is($cli->debug_toggle_log(), 0, "Debug logging now disabled"); # 0 means disabled
    
    # Enable debug logging for snapshot testing
    is($cli->debug_toggle_log(), 1, "Debug logging enabled");  # 1 means enabled
    
    # Test debug_snapshot
    my $snapshot = $cli->debug_snapshot("Test snapshot");
    ok($snapshot, "Snapshot created");
    is($snapshot->{label}, "Test snapshot", "Snapshot has correct label");
    ok($snapshot->{timestamp} > 0, "Snapshot has timestamp");
    is($snapshot->{screen_size}{width}, 80, "Snapshot captured screen width");
    is($snapshot->{screen_size}{height}, 24, "Snapshot captured screen height");
    
    # Log an operation
    $cli->display_title("Test Title");
    
    # Get a temporary file for the log dump
    my ($fh, $filename) = tempfile();
    close $fh;
    
    ok($cli->dump_debug_log($filename), "Debug log dumped to file");
    
    # Read the dumped log file
    open my $log_fh, '<', $filename or die "Cannot open log file: $!";
    my $log_content = do { local $/; <$log_fh> };
    close $log_fh;
    
    # Check log content
    like($log_content, qr/ITERUM DEBUG LOG/, "Log has header");
    like($log_content, qr/\[operation\]/, "Log contains operation entries");
    like($log_content, qr/\[snapshot\]/, "Log contains snapshot entries");
    
    # Clean up
    unlink $filename;
};

# Test UI region visualization
subtest 'UI Region Visualization' => sub {
    my $cli = Iterum::UI::CLI->new(
        buffer => Clay::Buffer->new(screen => $test_screen)
    );
    $test_screen->clear();
    
    # Toggle region visualization on
    ok($cli->debug_toggle_regions(), "Region visualization enabled");
    
    # Check that regions are displayed
    like($test_screen->render(), qr/header/, "Region header is labeled");
    like($test_screen->render(), qr/player/, "Region player is labeled");
    like($test_screen->render(), qr/enemy/, "Region enemy is labeled");
    
    # Toggle region visualization off
    ok(!$cli->debug_toggle_regions(), "Region visualization disabled");
};

# Test debug_set_region and debug_get_regions
subtest 'UI Region Management' => sub {
    my $cli = Iterum::UI::CLI->new(
        buffer => Clay::Buffer->new(screen => $test_screen)
    );
    
    # Check default regions
    my $regions = $cli->debug_get_regions();
    ok($regions->{header}, "Header region exists");
    ok($regions->{player}, "Player region exists");
    ok($regions->{enemy}, "Enemy region exists");
    
    # Set a custom region
    my $custom_region = $cli->debug_set_region('custom', 10, 10, 20, 5);
    ok($custom_region, "Custom region created");
    is($custom_region->{row}, 10, "Custom region has correct row");
    is($custom_region->{col}, 10, "Custom region has correct column");
    is($custom_region->{width}, 20, "Custom region has correct width");
    is($custom_region->{height}, 5, "Custom region has correct height");
    
    # Verify region was stored
    $regions = $cli->debug_get_regions();
    ok($regions->{custom}, "Custom region exists in debug regions");
};

# Test debug key handling
subtest 'Debug Key Handling' => sub {
    my $cli = Iterum::UI::CLI->new(
        buffer => Clay::Buffer->new(screen => $test_screen)
    );
    $test_screen->clear();
    
    # Set up keys for testing
    $test_screen->send_keys('`', '~', 'x');
    
    # Test in get_combat_action
    my $action = $cli->get_combat_action();
    is($action, 'attack', "get_combat_action returns correct value after debug keys");
    
    # Reset keys for testing
    $test_screen->clear();
    $test_screen->send_keys('`', '~', 'x');
    
    # Test in prompt_continue
    ok($cli->prompt_continue(), "prompt_continue handles debug keys");
    
    # Reset keys for testing
    $test_screen->clear();
    $test_screen->send_keys('`', '~', 'x');
    
    # Test in get_input without options
    is($cli->get_input(), 'x', "get_input (any key) returns correct value after debug keys");
    
    # Reset keys for testing
    $test_screen->clear();
    $test_screen->send_keys('`', '~', '1');
    
    # Test in get_input with options
    is($cli->get_input(['Option 1', 'Option 2']), 'Option 1', "get_input (options) returns correct value after debug keys");
};

done_testing();
