use Config;
use ExtUtils::MakeMaker;

##my $vers = $] >= 5.008 ? '-5.8' : '';
my $vers = '';

WriteMakefile (
	NAME => 'Astro::SpaceTrack',
	VERSION_FROM => 'SpaceTrack.pm',
	PREREQ_PM => {
			$^O eq 'MSWin32' ? () : (
				LWP::UserAgent => 0,
				)
				
			},
#	'linkext' => {LINKTYPE => ''},
	'dist' => {COMPRESS => 'gzip', SUFFIX => 'gz'},
	$] >= 5.005 ? (
		AUTHOR => 'Tom Wyant (wyant at cpan dot org)',
		ABSTRACT => 'Download satellite orbital elements from Space Track',
		BINARY_LOCATION => "$Config{archname}$vers/Astro-SpaceTrack.tar.gz",
		) : (),
	);

