use Test;
use Bot::Pluggable::Joiner;
use strict;

my @tests = (
sub {
    ok 1;
},
);

plan tests => 0+@tests;

$_->() for @tests;
