use v5.40.0;

use Test2::V0;

use Test::Term::Screen;

# Test basic initialization
subtest 'Initialization' => sub {
    my $screen = Test::Term::Screen->new();
    is($screen->rows(), 25, "Default rows is 25");
    is($screen->cols(), 80, "Default cols is 80");
    
    my $screen2 = Test::Term::Screen->new(rows => 30, cols => 100);
    is($screen2->rows(), 30, "Custom rows value works");
    is($screen2->cols(), 100, "Custom cols value works");
};

# Test screen operations
subtest 'Screen Operations' => sub {
    my $screen = Test::Term::Screen->new(rows => 10, cols => 20);
    
    # Test at and puts
    $screen->at(3, 5)->puts("Hello");
    is($screen->get_char_at(3, 5), 'H', "Character written at correct position");
    is($screen->get_char_at(3, 6), 'e', "Character written at correct position");
    
    # Test verify
    ok($screen->verify(3, 5, "Hello"), "Verify returns true for matching text");
    ok(!$screen->verify(3, 5, "Goodbye"), "Verify returns false for non-matching text");
    
    # Test writing past edge
    $screen->at(9, 18)->puts("123");
    is($screen->get_char_at(9, 18), '1', "First character written");
    is($screen->get_char_at(9, 19), '2', "Second character written");
    
    # The third character would wrap to the next line
    # But we're at the bottom, so it should stay there
    is($screen->get_char_at(9, 0), ' ', "No character wrapped to next line at bottom of screen");
    
    # Test clrscr
    $screen->clrscr();
    for my $r (0..9) {
        for my $c (0..19) {
            is($screen->get_char_at($r, $c), ' ', "Screen cleared at position $r,$c");
        }
    }
    
    # Test clreol
    $screen->at(5, 5)->puts("XXXXX");
    $screen->at(5, 7)->clreol();
    is($screen->get_char_at(5, 5), 'X', "Character before clreol start preserved");
    is($screen->get_char_at(5, 6), 'X', "Character before clreol start preserved");
    is($screen->get_char_at(5, 7), ' ', "Character at clreol start cleared");
    is($screen->get_char_at(5, 8), ' ', "Character after clreol start cleared");
};

# Test input simulation
subtest 'Input Simulation' => sub {
    my $screen = Test::Term::Screen->new();
    
    # No keys initially
    ok(!$screen->key_pressed(), "No keys pressed initially");
    
    # Queue some keys
    $screen->queue_keypress('a')->queue_keypress('b')->queue_keypress('c');
    
    # Now we should have keys
    ok($screen->key_pressed(), "Keys pressed after queuing");
    
    # Test getch
    is($screen->getch(), 'a', "First key is correct");
    is($screen->getch(), 'b', "Second key is correct");
    is($screen->getch(), 'c', "Third key is correct");
    
    # Should be empty again
    ok(!$screen->key_pressed(), "No keys pressed after dequeuing all");
    
    # Test stuff_input
    $screen->stuff_input("test");
    
    is($screen->getch(), 't', "First character from stuff_input");
    is($screen->getch(), 'e', "Second character from stuff_input");
    
    $screen->flush_input();
    
    ok(!$screen->key_pressed(), "Input queue flushed");
};

# Test line operations
subtest 'Line Operations' => sub {
    my $screen = Test::Term::Screen->new(rows => 10, cols => 20);
    
    # Insert a line
    $screen->at(3, 0)->puts("Line 3");
    $screen->at(4, 0)->puts("Line 4");
    $screen->at(5, 0)->puts("Line 5");
    
    $screen->at(4, 0)->il();
    
    is($screen->get_char_at(3, 0), 'L', "Line 3 remains in place");
    is($screen->get_char_at(4, 0), ' ', "New blank line inserted");
    is($screen->get_char_at(5, 0), 'L', "Line 4 moved down");
    is($screen->get_char_at(6, 0), 'L', "Line 5 moved down");
    
    # Delete a line
    $screen->at(5, 0)->dl();
    
    is($screen->get_char_at(3, 0), 'L', "Line 3 remains in place");
    is($screen->get_char_at(4, 0), ' ', "Blank line remains");
    is($screen->get_char_at(5, 0), 'L', "Line 5 moved up");
};

# Test clear to end of screen
subtest 'Clear to End of Screen' => sub {
    my $screen = Test::Term::Screen->new(rows => 10, cols => 20);
    
    $screen->at(3, 5)->puts("Partial");
    $screen->at(3, 12)->puts("Line"); # Should make 'L' be at position 12
    $screen->at(4, 0)->puts("FullLine");
    $screen->at(5, 0)->puts("WillBeCleared");
    
    # Print the contents of the screen before and after clreos
    diag("Before clreos: Character at (3,9) is '" . $screen->get_char_at(3, 9) . "'");
    
    $screen->at(3, 10)->clreos();
    
    diag("After clreos: Character at (3,9) is '" . $screen->get_char_at(3, 9) . "'");
    
    is($screen->get_char_at(3, 5), 'P', "Beginning of line preserved");
    is($screen->get_char_at(3, 9), 'i', "Last character before cursor preserved"); # 'i' is the 5th char of 'Partial'
    is($screen->get_char_at(3, 10), ' ', "Character at cursor cleared");
    is($screen->get_char_at(4, 0), ' ', "Next line cleared");
    is($screen->get_char_at(5, 0), ' ', "Lines below cleared");
};

# Test debug and rendering
subtest 'Debug and Rendering' => sub {
    my $screen = Test::Term::Screen->new(rows => 5, cols => 10);
    
    $screen->at(2, 3)->puts("Test");
    
    my $render = $screen->render();
    like($render, qr/   Test   /, "Rendered output contains the text");
    
    my $debug = $screen->debug_screen();
    like($debug, qr/2:.*Test.*/, "Debug output shows text at correct row");
};

# Test find_text
subtest 'Finding Text' => sub {
    my $screen = Test::Term::Screen->new(rows => 10, cols => 20);
    
    $screen->at(3, 5)->puts("Hello");
    $screen->at(7, 2)->puts("Hello");
    
    my @locations = $screen->find_text("Hello");
    is(scalar @locations, 2, "Found 2 occurrences of text");
    is($locations[0]->[0], 3, "First occurrence row");
    is($locations[0]->[1], 5, "First occurrence column");
    is($locations[1]->[0], 7, "Second occurrence row");
    is($locations[1]->[1], 2, "Second occurrence column");
    
    @locations = $screen->find_text("NotPresent");
    is(scalar @locations, 0, "Found 0 occurrences of absent text");
};

# Test overlapping text detection
subtest 'Overlapping Text Detection' => sub {
    my $screen = Test::Term::Screen->new(rows => 10, cols => 20);
    
    $screen->at(5, 5)->puts("Hello");
    
    # Is_overlapping should detect potential overlaps
    ok($screen->is_overlapping(5, 7, "World"), "Detects overlap correctly");
    ok(!$screen->is_overlapping(6, 5, "NoOverlap"), "Correctly identifies no overlap");
    
    # Reset modifications and try again
    $screen->reset_modifications();
    
    # Now this shouldn't trigger a warning even though it's overlapping
    # because we've reset the timestamps
    $screen->at(5, 8)->puts("World");
};

done_testing();
