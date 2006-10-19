#!/usr/bin/perl

use strict;
use warnings;

use Config;
use FileHandle;
use Module::Build;

#	Generate a builder object.

my $bldr = Module::Build->new (
	dist_author => 'Tom Wyant (wyant at cpan dot org)',
	dist_abstract => 'Download satellite orbital elements from Space Track',
	module_name => 'Astro::SpaceTrack',
##	dist_name => 'Astro-SpaceTrack',
##	dist_version_from => 'SpaceTrack.pm',
	get_options => {y => {}, n => {}},
	dynamic_config => 1,
	license => 'perl',
	);

#	Find out what the user wants to do.

my %opt => $bldr->args ();

my @exe_files;
my @clean_files;

my @possible_exes = ('SpaceTrack');
my $tk = eval {require Tk} and push @possible_exes, 'SpaceTrackTk';
print $tk ? <<eod : <<eod;

The following scripts will be installed:

  SpaceTrack is an interactive interface to Astro::SpaceTrack;
  SpaceTrackTk is a windowed interface to Astro::SpaceTrack, using
    Perl/Tk.
eod

The following script will be installed:

   SpaceTrack is an interactive interface to Astro::SpaceTrack.

SpaceTrackTk, a windowed interface to Astro::SpaceTrack, is provided
but will not be installed because you do not have the Tk package
installed. If you want this, install Tk and then rerun Makefile.PL.
eod
print <<eod;

If you do not want this, run Build.PL with the -n option.

Unless you are running MSWin32 or VMS (which are special-cased),
I will assume you're running some version of U*ix, and behave
accordingly.

eod


if ($opt{n}) {
    print "Because you have asserted -n, the executables will not be installed.\n\n";
    }
  elsif ($opt{y}) {
    print "Because you have asserted -y, the executables will be installed.\n\n";
    @exe_files = @possible_exes;
    }
  else {
    foreach (@possible_exes) {
	push @exe_files, $_
##	    if prompt ("Do you want to install $_?", 'n') =~ m/^y/i
	    ;
	}
    }

if (@exe_files) {
    if ($^O eq 'MSWin32') {
	@exe_files = map {"bin/$_"} @exe_files;
	foreach (@exe_files) {`pl2bat $_`}
	@clean_files = @exe_files =
	    grep {-e $_} map {"$_.bat"} @exe_files;
	}
      elsif ($^O eq 'VMS') {
	foreach my $fni (map {"[.bin]$_"} @exe_files) {
	    my $fno = "$fni.com";
	    my $fhi = FileHandle->new ("<$fni") or die <<eod;
Error - Unable to open $fni
        $!
eod
	    my $fho = FileHandle->new (">$fno") or die <<eod;
Error - Unable to open $fno
        $!
eod
	    print $fho "$Config{startperl}\n";
	    while (<$fhi>) {print $fho $_}
	    }
	@clean_files = @exe_files = map {"[.bin]$_.com"} @exe_files;
	}
      else {
	@exe_files = map {"bin/$_"} @exe_files;
	}
    }

##my $vers = $] >= 5.008 ? '-5.8' : '';
my $vers = '';

#	Tell Module::Build what we want to do.

$bldr->requires ($^O eq 'MSWin32' ? {} : {'LWP::UserAgent' => 0});
$bldr->add_to_cleanup (\@clean_files);
$bldr->script_files (\@exe_files);

#	Generate the build script, at long last.

$bldr->create_build_script ();
