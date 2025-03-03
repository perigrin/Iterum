#!/usr/bin/env perl
use 5.40.0;
use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../lib";

# Import Clay::Types
use_ok('Clay::Types');

# Import the constants
use Clay::Types::LayoutConfig qw(
    $SIZING_FIXED $SIZING_GROW $SIZING_PERCENT $SIZING_FIT
    $LEFT_TO_RIGHT $RIGHT_TO_LEFT $TOP_TO_BOTTOM $BOTTOM_TO_TOP
);

# Test Point class
subtest 'Point' => sub {
    my $point = Clay::Types::Point->new(x => 10, y => 20);
    is($point->x, 10, 'Point x coordinate');
    is($point->y, 20, 'Point y coordinate');
    
    my $point2 = Clay::Types::Point->new(x => 5, y => 10);
    my $sum = $point->add($point2);
    is($sum->x, 15, 'Point addition x');
    is($sum->y, 30, 'Point addition y');
};

# Test Size class
subtest 'Size' => sub {
    my $size = Clay::Types::Size->new(width => 100, height => 50);
    is($size->width, 100, 'Size width');
    is($size->height, 50, 'Size height');
};

# Test Rect class
subtest 'Rect' => sub {
    my $rect = Clay::Types::Rect->new(x => 10, y => 20, width => 100, height => 50);
    is($rect->x, 10, 'Rect x');
    is($rect->y, 20, 'Rect y');
    is($rect->width, 100, 'Rect width');
    is($rect->height, 50, 'Rect height');
    
    # Test contains
    my $inside_point = Clay::Types::Point->new(x => 50, y => 30);
    my $outside_point = Clay::Types::Point->new(x => 200, y => 200);
    
    ok($rect->contains($inside_point), 'Rect contains point inside');
    ok(!$rect->contains($outside_point), 'Rect does not contain point outside');
};

# Test Color class
subtest 'Color' => sub {
    my $color = Clay::Types::Color->new(r => 255, g => 0, b => 0, a => 255, foreground => 1);
    like($color->ansi_code, qr/red/, 'Color generates proper ANSI code for red foreground');
    
    my $color2 = Clay::Types::Color->new(r => 255, g => 0, b => 0, a => 255, foreground => 0);
    like($color2->ansi_code, qr/on_red/, 'Color generates proper ANSI code for red background');
};

# Test Padding class
subtest 'Padding' => sub {
    my $padding = Clay::Types::Padding->new(left => 5, right => 10, top => 15, bottom => 20);
    is($padding->left, 5, 'Padding left');
    is($padding->right, 10, 'Padding right');
    is($padding->top, 15, 'Padding top');
    is($padding->bottom, 20, 'Padding bottom');
    
    is($padding->horizontal, 15, 'Padding horizontal');
    is($padding->vertical, 35, 'Padding vertical');
};

# Test LayoutConfig class
subtest 'LayoutConfig' => sub {
    my $config = Clay::Types::LayoutConfig->new(
        sizing_width_type => $SIZING_FIXED,
        sizing_width_value => 200,
        sizing_height_type => $SIZING_GROW,
        sizing_height_min => 50
    );
    
    is($config->effective_width(1000, 100), 200, 'Fixed width is independent of content');
    is($config->effective_height(1000, 100), 1000, 'Grow height fills available space');
    
    # Test percent sizing
    my $percent_config = Clay::Types::LayoutConfig->new(
        sizing_width_type => $SIZING_PERCENT,
        sizing_width_value => 0.5
    );
    is($percent_config->effective_width(1000, 100), 500, 'Percent width is percentage of available');
    
    # Test fit sizing with min/max
    my $fit_config = Clay::Types::LayoutConfig->new(
        sizing_width_type => $SIZING_FIT,
        sizing_width_min => 50,
        sizing_width_max => 200
    );
    is($fit_config->effective_width(1000, 30), 50, 'Fit width respects minimum');
    is($fit_config->effective_width(1000, 250), 200, 'Fit width respects maximum');
};

done_testing();