#!/usr/bin/perl

use strict;
use warnings;

use FileHandle;
use Test;

$| = 1;	# Turn on autoflush to try to keep I/O in sync.

my $test_num = 1;
my $skip = '';

################### We start with some black magic to print on failure.

# (It may become useful if the test is moved to ./t subdirectory.)


my $loaded;

sub prompt {
print STDERR @_;
return unless defined (my $input = <STDIN>);
chomp $input;
return $input;
}

BEGIN {
plan (tests => 7);
print "# Test 1 - Loading the library.\n"
}

END {print "not ok 1\n" unless $loaded;}

if ($ENV{SPACETRACK_USER}) {
    # Do nothing if we have the environment variable.
    }
  elsif ($^O eq 'VMS') {

    warn <<eod;

Several tests will be skipped because you have not provided logical
name SPACETRACK_USER. This should be set to your Space Track username
and password, separated by a slash ("/") character.

eod

    $skip = "No SPACETRACK_USER environment variable provided.";

    }
  else {
    
    warn <<eod;

Several tests require the username and password of a registered Space
Track user. Because you have not provided environment variable
SPACETRACK_USER, you will be prompted for this information. If you
leave either username or password blank, the tests will be skipped.

If you set environment variable SPACETRACK_USER to your Space Track
username and password, separated by a slash ("/") character, that
username and password will be used, and you will not be prompted.

eod

    my $user = prompt ("Space-Track username: ");
    my $pass = prompt ("Space-Track password: ") if $user;

    if ($user && $pass) {
	$ENV{SPACETRACK_USER} = "$user/$pass";
	}
      else {
	$skip = "No Space Track account provided.";
	}
    }

use Astro::SpaceTrack;

$loaded = 1;
ok ($loaded);

######################### End of black magic.

$test_num++;
print "# Test $test_num - Instantiate the object.\n";
my $st;
ok ($st = Astro::SpaceTrack->new ());

$test_num++;
print "# Test $test_num - Log in to Space Track.\n";
skip ($skip, $skip || $st->login ()->is_success);

$test_num++;
print "# Test $test_num - Fetch a catalog entry.\n";
skip ($skip, $skip || $st->spacetrack ('special')->is_success);

$test_num++;
print "# Test $test_num - Retrieve some orbital elements.\n";
skip ($skip, $skip || $st->retrieve (25544)->is_success);

$test_num++;
print "# Test $test_num - Search for something up by name.\n";
skip ($skip, $skip || $st->search_name ('zarya')->is_success);

$test_num++;
print "# Test $test_num - Fetch a Celestrak data set.\n";
skip ($skip, $skip || $st->celestrak ('stations')->is_success);

