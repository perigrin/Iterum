#!/usr/bin/env perl
use 5.40.0;
use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../lib";

BEGIN {
    # Skip tests if Term::Screen isn't available
    eval "use Term::Screen; 1"
      or plan skip_all => "Term::Screen required for testing";
}

use Clay::Types;
use Clay::Element;
use Clay::Context;
use Clay::Builder;
use Clay::UI;
use Clay::Types::LayoutConfig qw(
  $SIZING_FIXED $SIZING_GROW $SIZING_PERCENT $SIZING_FIT
  $LEFT_TO_RIGHT $RIGHT_TO_LEFT $TOP_TO_BOTTOM $BOTTOM_TO_TOP
  $ALIGN_LEFT $ALIGN_RIGHT $ALIGN_CENTER $ALIGN_TOP $ALIGN_BOTTOM
);
use Clay::Types::TextConfig qw(
  $WRAP_WORDS $WRAP_NEWLINES $WRAP_NONE
  $ALIGN_LEFT $ALIGN_RIGHT $ALIGN_CENTER
);

# Stub out the tests to be implemented later
subtest 'Builder Creation' => sub {
    pass("Builder creation tests stubbed out for now");
};

subtest 'Adding Children' => sub {
    pass("Child adding tests stubbed out for now");
};

subtest 'Builder Chaining' => sub {
    pass("Builder chaining tests stubbed out for now");
};

subtest 'UI Helper Functions' => sub {
    pass("UI helper function tests stubbed out for now");
};

subtest 'Building Simple UI' => sub {
    pass("Simple UI building tests stubbed out for now");
};

done_testing();
