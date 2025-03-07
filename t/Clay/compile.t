#!/usr/bin/env perl
use 5.40.0;
use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../lib";

# Test basic compilation of all modules
use_ok('Clay::Types');
use_ok('Clay::Types::Point');
use_ok('Clay::Types::Size');
use_ok('Clay::Types::Rect');
use_ok('Clay::Types::Color');
use_ok('Clay::Types::BorderConfig');
use_ok('Clay::Types::BorderRadius');
use_ok('Clay::Types::LayoutConfig');
use_ok('Clay::Types::TextConfig');
use_ok('Clay::Element');
use_ok('Clay::Context');
use_ok('Clay::Builder');
use_ok('Clay::UI');
use_ok('Clay');

done_testing();
