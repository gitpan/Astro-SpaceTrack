package main;

use 5.006002;

use strict;
use warnings;

use Astro::SpaceTrack;
use Test::More 0.96;	# For subtest

use lib qw{ inc };
use My::Module::Test;

my $skip;
$skip = site_check 'celestrak.com'
    and plan skip_all => $skip;
$skip = site_check 'mike.mccants'
    and plan skip_all => $skip;

my $st = Astro::SpaceTrack->new();

$st->set(
    iridium_status_format	=> 'mccants',
);

is_success $st, 'iridium_status', 'Get Iridium status (McCants)';

is $st->content_type(), 'iridium-status',
    "Content type is 'iridium-status'";

is $st->content_source(), 'mccants', "Content source is 'mccants'";


done_testing;

1;

# ex: set textwidth=72 :
