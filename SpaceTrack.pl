#!/usr/bin/perl
#	Title:	SpaceTrack.pl
#	Author:	T. R. Wyant
#	Date:	07-Mar-2005
#	Modified:
#	Remarks:
#		This Perl script is just a really simple encapsulation
#		of the Astro::SpaceTrack shell subroutine. Note that the
#		command line arguments are passed, so you can do things
#		like
#		$ perl SpaceTrack.pl 'set username me password secret'
#		followed by whatever commands you like at the SpaceTrack
#		prompt.

use strict;
use warnings;

use Astro::SpaceTrack qw{shell};

shell (@ARGV);
