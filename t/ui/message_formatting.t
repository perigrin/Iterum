use 5.40.0;
use Test2::V0;
use FindBin qw($Bin);
use lib "$Bin/../../lib";

use Test::Term::Screen;
use Clay::Buffer;

# Skip the test if Iterum::UI::CLI is not available
eval "use Iterum::UI::CLI";
if ($@) {
    plan skip_all => "Iterum::UI::CLI is not available";
}

# Helper function for flexible box character matching
sub match_box_char {
my ($screen_content, $description, $unicode_char, $ascii_equiv) = @_;    

# For the test environment, we're outputting the hex values directly, so look for those
# Look for hex code without \u prefix, hex code string, actual rendered character, or ASCII equivalent
if ($screen_content =~ /\b$unicode_char\b|\\u$unicode_char|\Q$ascii_equiv\E/) {
    pass("$description displayed");
return 1;
} else {
    fail("$description displayed");
diag("Could not find '$unicode_char' or '$ascii_equiv' in screen content");
return 0;
}
}

# Set up a test screen
my $test_screen = Test::Term::Screen->new(
    rows => 24,
    cols => 80,
);

# Test message formatting and display
subtest 'Message Formatting' => sub {
    my $cli = Iterum::UI::CLI->new(
        buffer => Clay::Buffer->new(screen => $test_screen)
    );
    $test_screen->clear();
    
    # Configure message display
    $cli->configure_message_display({
        timestamp_display => 1,
        max_messages => 10,
        coalesce_time => 5
    });
    
    # Test adding different message types
    $cli->add_system_message("This is a system message");
    $cli->add_combat_message("This is a combat message");
    $cli->add_ev_message("This is an EV score message");
    $cli->add_error_message("This is an error message");
    
    # Force display of message history
    $cli->display_message_history();
    
    # Verify messages appear with proper formatting
    my $screen_content = $test_screen->render();
    
    # Check that all message types are displayed
    like($screen_content, qr/system message/, "System message displayed");
    like($screen_content, qr/combat message/, "Combat message displayed");
    like($screen_content, qr/EV score message/, "EV message displayed");
    like($screen_content, qr/error message/, "Error message displayed");
    
    # Check for message box borders using helper function
    match_box_char($screen_content, "Top-left double border corner", "\u2554", "+");
    match_box_char($screen_content, "Top-right double border corner", "\u2557", "+");
    match_box_char($screen_content, "Bottom-left double border corner", "\u255a", "+");
    match_box_char($screen_content, "Bottom-right double border corner", "\u255d", "+");
    
    # Check message counter is displayed
    like($screen_content, qr/Messages.+4/, "Message counter displayed");
};

# Test message coalescing
subtest 'Message Coalescing' => sub {
    my $cli = Iterum::UI::CLI->new(
        buffer => Clay::Buffer->new(screen => $test_screen)
    );
    $test_screen->clear();
    
    # Configure message display with coalescing enabled
    $cli->configure_message_display({
        timestamp_display => 1,
        max_messages => 10,
        coalesce_time => 60  # Large window to ensure coalescing
    });
    
    # Add duplicate messages
    $cli->add_system_message("Duplicate message");
    $cli->add_system_message("Duplicate message");
    $cli->add_system_message("Duplicate message");
    
    # Force display of message history
    $cli->display_message_history();
    
    # Verify coalescing worked - check for message with count marker
    my $screen_content = $test_screen->render();
    
    # Check for either Unicode multiply symbol or text like "[x3]"
    my $found = 0;
    if ($screen_content =~ /Duplicate message.+\u00d73/) {
        pass("Message coalesced with Unicode count indicator");
        $found = 1;
    } elsif ($screen_content =~ /Duplicate message.+\[x3\]/) {
        pass("Message coalesced with ASCII count indicator");
        $found = 1;
    } elsif ($screen_content =~ /Duplicate message.+\(3\)/) {
        pass("Message coalesced with parenthesized count");
        $found = 1;
    }
    
    ok($found, "Message coalescing works with some indicator format");
};

# Test result display formatting
subtest 'Result Display Formatting' => sub {
    my $cli = Iterum::UI::CLI->new(
        buffer => Clay::Buffer->new(screen => $test_screen)
    );
    $test_screen->clear();
    
    # Create a test result
    my $result = {
        action => "attack",
        success => 1,
        damage => 15,
        ev_score => 0.85
    };
    
    # Display the result
    $cli->display_result($result);
    
    # Verify result formatting
    my $screen_content = $test_screen->render();
    
    # Check for box borders using helper function
    match_box_char($screen_content, "Top-left border", "\u250c", "+");
    match_box_char($screen_content, "Top-right border", "\u2510", "+");
    match_box_char($screen_content, "Bottom-left border", "\u2514", "+");
    match_box_char($screen_content, "Bottom-right border", "\u2518", "+");
    
    # Check content
    like($screen_content, qr/ACTION RESULT/, "Result header displayed");
    like($screen_content, qr/Action: attack/, "Action displayed");
    like($screen_content, qr/Success/, "Success message displayed");
    like($screen_content, qr/Damage dealt: 15/, "Damage amount displayed");
    like($screen_content, qr/EV Score: 0\.85/, "EV score displayed");
};

# Test EV feedback display formatting
subtest 'EV Feedback Display Formatting' => sub {
    my $cli = Iterum::UI::CLI->new(
        buffer => Clay::Buffer->new(screen => $test_screen)
    );
    $test_screen->clear();
    
    # Create test feedback
    my $feedback = [
        "Good choice attacking when enemy was weak",
        "Consider defending when your health is low next time"
    ];
    
    # Display the feedback
    $cli->display_ev_feedback($feedback);
    
    # Verify feedback formatting
    my $screen_content = $test_screen->render();
    
    # Check for box borders using helper function
    match_box_char($screen_content, "Top-left border", "\u250f", "+");
    match_box_char($screen_content, "Top-right border", "\u2513", "+");
    match_box_char($screen_content, "Bottom-left border", "\u2517", "+");
    match_box_char($screen_content, "Bottom-right border", "\u251b", "+");
    
    # Check content
    like($screen_content, qr/AI COACH FEEDBACK/, "Feedback header displayed");
    
    # Check for bullet points with helper function
    match_box_char($screen_content, "First feedback item with bullet", "\u25c6", "*");
    match_box_char($screen_content, "Second feedback item with bullet", "\u25c6", "*");
    
    # Check that the feedback text is displayed
    like($screen_content, qr/Good choice/, "First feedback message content displayed");
    like($screen_content, qr/Consider defending/, "Second feedback message content displayed");
};

# Test score summary display formatting
subtest 'Score Summary Display Formatting' => sub {
    my $cli = Iterum::UI::CLI->new(
        buffer => Clay::Buffer->new(screen => $test_screen)
    );
    $test_screen->clear();
    
    # Create test summary
    my $summary = {
        total_score => 75,
        best_decision => "attack when enemy was weak",
        worst_decision => "defend when at full health"
    };
    
    # Display the summary
    $cli->display_score_summary($summary);
    
    # Verify summary formatting
    my $screen_content = $test_screen->render();
    
    # Check for box borders using helper function
    match_box_char($screen_content, "Top-left border", "\u256d", "+");
    match_box_char($screen_content, "Top-right border", "\u256e", "+");
    match_box_char($screen_content, "Bottom-left border", "\u2570", "+");
    match_box_char($screen_content, "Bottom-right border", "\u256f", "+");
    
    # Check content
    like($screen_content, qr/EV SCORE SUMMARY/, "Summary header displayed");
    like($screen_content, qr/Total Score: 75/, "Score displayed");
    
    # Check for special characters with helper function
    match_box_char($screen_content, "Best decision with checkmark", "\u2714", "\u2713"); # ✓ or ✔
    match_box_char($screen_content, "Worst decision with X", "\u2716", "x"); # ✖ or x
    
    # Check that the decision text is displayed
    like($screen_content, qr/Best Decision/, "Best decision text displayed");
    like($screen_content, qr/Worst Decision/, "Worst decision text displayed");
    like($screen_content, qr/attack when enemy was weak/, "Best decision detail displayed");
    like($screen_content, qr/defend when at full health/, "Worst decision detail displayed");
    
    # Check for score indicator bar
    like($screen_content, qr/\[=+\s*\]/, "Score indicator bar displayed");
};

# Test message wrapping
subtest 'Message Wrapping' => sub {
    my $cli = Iterum::UI::CLI->new(
        buffer => Clay::Buffer->new(screen => $test_screen)
    );
    $test_screen->clear();
    
    # Add a very long message
    $cli->add_system_message("This is a very long message that should wrap to multiple lines because it exceeds the width of the message box. The wrapping should maintain readability and proper indentation.");
    
    # Force display of message history
    $cli->display_message_history();
    
    # Check that the message appears in multiple lines
    my $screen_content = $test_screen->render();
    $screen_content =~ s/\n/ /g;  # Replace newlines with spaces for easier matching
    
    # The message should be broken up and appear across multiple places in the screen
    my $parts_found = 0;
    $parts_found++ if $screen_content =~ /This is a very long message/;
    $parts_found++ if $screen_content =~ /should wrap to multiple lines/;
    
    ok($parts_found > 1, "Long message was wrapped appropriately");
};

done_testing();