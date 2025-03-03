#!/usr/bin/env perl
use 5.40.0;
use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../lib";

use Clay::Types;
use Clay::Element;
use Clay::Types::LayoutConfig qw(
  $SIZING_FIXED $SIZING_GROW $SIZING_PERCENT $SIZING_FIT
  $LEFT_TO_RIGHT $RIGHT_TO_LEFT $TOP_TO_BOTTOM $BOTTOM_TO_TOP
  $ALIGN_LEFT $ALIGN_RIGHT $ALIGN_CENTER $ALIGN_TOP $ALIGN_BOTTOM
);
use Clay::Types::TextConfig qw(
  $WRAP_WORDS $WRAP_NEWLINES $WRAP_NONE
  $ALIGN_LEFT $ALIGN_RIGHT $ALIGN_CENTER
);

# Test basic element creation
subtest 'Basic Element Creation' => sub {
    my $element = Clay::Element->new( id => 'test-element' );

    ok( $element isa Clay::Element, 'Element is a Clay::Element' );
    is( $element->id(), 'test-element', 'Element has correct ID' );
    is( scalar @{ $element->children() }, 0,
        'Element starts with no children' );
};

# Test parent-child relationship
subtest 'Parent-Child Relationship' => sub {
    my $parent = Clay::Element->new( id => 'parent' );
    my $child  = Clay::Element->new( id => 'child' );

    $parent->add_child($child);

    is( scalar @{ $parent->children() }, 1, 'Parent has one child' );
    is( $parent->children()->[0], $child,   'Child is correctly referenced' );
    is( $child->parent(),         $parent,  'Child has reference to parent' );

    # Test multiple children
    my $child2 = Clay::Element->new( id => 'child2' );
    $parent->add_child($child2);

    is( scalar @{ $parent->children() }, 2, 'Parent has two children' );
};

# Test text elements
subtest 'Text Elements' => sub {
    my $text_element = Clay::Element->new(
        id   => 'text',
        text => 'Hello World'
    );

    ok( length( $text_element->text() ), 'Text element has text content' );
    is( $text_element->text(), 'Hello World', 'Text content is stored' );
    ok( $text_element->text_config() isa Clay::Types::TextConfig,
        'Text element has text config' );
};

# Test measurement
subtest 'Element Measurement' => sub {

    # Test horizontal layout
    my $parent = Clay::Element->new(
        id            => 'parent',
        layout_config => Clay::Types::LayoutConfig->new(
            layout_direction => $LEFT_TO_RIGHT,
            padding          => Clay::Types::Padding->new(
                left   => 5,
                right  => 5,
                top    => 5,
                bottom => 5
            ),
            child_gap => 10
        )
    );

    my $child1 = Clay::Element->new(
        id            => 'child1',
        layout_config => Clay::Types::LayoutConfig->new(
            sizing_width_type   => $SIZING_FIXED,
            sizing_width_value  => 100,
            sizing_height_type  => $SIZING_FIXED,
            sizing_height_value => 50
        )
    );

    my $child2 = Clay::Element->new(
        id            => 'child2',
        layout_config => Clay::Types::LayoutConfig->new(
            sizing_width_type   => $SIZING_FIXED,
            sizing_width_value  => 200,
            sizing_height_type  => $SIZING_FIXED,
            sizing_height_value => 100
        )
    );

    $parent->add_child($child1);
    $parent->add_child($child2);

    my $size = $parent->measure( 1000, 1000 );
    is(
        $size->width,
        100 + 200 + 10 + 5 + 5,
        'Parent width is sum of children plus gap and padding'
    );
    is(
        $size->height,
        100 + 5 + 5,
        'Parent height is max child height plus padding'
    );

    # Test vertical layout
    my $vertical_parent = Clay::Element->new(
        id            => 'vertical_parent',
        layout_config => Clay::Types::LayoutConfig->new(
            layout_direction => $TOP_TO_BOTTOM,
            padding          => Clay::Types::Padding->new(
                left   => 5,
                right  => 5,
                top    => 5,
                bottom => 5
            ),
            child_gap => 10
        )
    );

    $vertical_parent->add_child($child1);
    $vertical_parent->add_child($child2);

    $size = $vertical_parent->measure( 1000, 1000 );
    is(
        $size->width,
        200 + 5 + 5,
        'Vertical parent width is max child width plus padding'
    );
    is(
        $size->height,
        50 + 100 + 10 + 5 + 5,
        'Vertical parent height is sum of children plus gap and padding'
    );
};

# Test text wrapping
subtest 'Text Wrapping' => sub {
    my $text_element = Clay::Element->new(
        id   => 'wrapped_text',
        text =>
'This is a long text that should wrap when the available width is limited',
        text_config => Clay::Types::TextConfig->new(
            color     => Clay::Types::Color->new(),
            wrap_mode => $WRAP_WORDS
        )
    );

    my $size = $text_element->measure( 20, 100 )
      ;    # Very limited width should cause wrapping
    ok( $size->height > 1,
        'Text wraps to multiple lines when width is limited' );

    # Test newline wrapping
    my $newline_text = Clay::Element->new(
        id          => 'newline_text',
        text        => "Line 1\nLine 2\nLine 3",
        text_config => Clay::Types::TextConfig->new(
            color     => Clay::Types::Color->new(),
            wrap_mode => $WRAP_NEWLINES
        )
    );

    $size = $newline_text->measure( 100, 100 );
    is( $size->height, 3,
        'Text with newlines creates correct number of lines' );
};

# Stub out remaining tests to be implemented
subtest 'Element Layout' => sub {
    pass("Layout tests stubbed out for now");
};

subtest 'Render Commands' => sub {
    pass("Render command tests stubbed out for now");
};

done_testing();
