=head1 NAME

Astro::SpaceTrack - Retrieve orbital data from www.space-track.org.

=head1 SYNOPSIS

 my $st = Astro::SpaceTrack->new (username => $me,
     password => $secret, with_name => 1) or die;
 my $rslt = $st->spacetrack ('special');
 print $rslt->is_success ? $rslt->content :
     $rslt->status_line;

or

 perl -MAstro::SpaceTrack=shell -e shell
 
 (some banner text gets printed here)
 
 SpaceTrack> set username me password secret
 OK
 SpaceTrack> set with_name 1
 OK
 SpaceTrack> spacetrack special >special.txt
 SpaceTrack> celestrak visual >visual.txt
 SpaceTrack> exit

=head1 LEGAL NOTICE

The following two paragraphs are quoted from the Space Track web site.

Due to existing National Security Restrictions pertaining to access of
and use of U.S. Government-provided information and data, all users
accessing this web site must be an approved registered user to access
data on this site.

By logging in to the site, you accept and agree to the terms of the
User Agreement specified in
L<http://www.space-track.org/perl/user_agreement.pl>.

You should consult the above link for the full text of the user
agreement before using this software.

=head1 DESCRIPTION

This package accesses the Space-Track web site,
L<http://www.space-track.org>, and retrieves orbital data from this
site. You must register and get a username and password before you
can make use of this package, and you must abide by the site's
restrictions, which include not making the data available to a
third party.

In addition, the celestrak method queries L<http://celestrak.com/> for
a named data set, and then queries L<http://www.space-track.org/> for
the orbital elements of the objects in the data set.

Beginning with version 0.017, there is provision for retrieval of
historical data.

Nothing is exported by default, but the shell method/subroutine
and the BODY_STATUS constants (see L</iridium_status>) can be
exported if you so desire.

Most methods return an HTTP::Response object. See the individual
method document for details. Methods which return orbital data on
success add a 'Pragma: spacetrack-type = orbit' header to the
HTTP::Response object if the request succeeds.

=head2 Methods

The following methods should be considered public:

=over 4

=cut

use strict;
use warnings;

use 5.006;

package Astro::SpaceTrack;

use base qw{Exporter};

our $VERSION = '0.029';
our @EXPORT_OK = qw{shell BODY_STATUS_IS_OPERATIONAL BODY_STATUS_IS_SPARE
    BODY_STATUS_IS_TUMBLING};
our %EXPORT_TAGS = (
    status => [qw{BODY_STATUS_IS_OPERATIONAL BODY_STATUS_IS_SPARE
	BODY_STATUS_IS_TUMBLING}],
);

use Astro::SpaceTrack::Parser;
use Carp;
use Compress::Zlib ();
use Config;
use FileHandle;
use Getopt::Long;
use HTTP::Response;	# Not in the base, but comes with LWP.
use HTTP::Status qw{RC_NOT_FOUND RC_OK RC_PRECONDITION_FAILED
	RC_UNAUTHORIZED RC_INTERNAL_SERVER_ERROR};	# Not in the base, but comes with LWP.
use LWP::UserAgent;	# Not in the base.
use POSIX qw{strftime};
use Text::ParseWords;
use Time::Local;
use UNIVERSAL qw{isa};

use constant COPACETIC => 'OK';
use constant INVALID_CATALOG =>
	'Catalog name %s invalid. Legal names are %s.';
use constant LOGIN_FAILED => 'Login failed';
use constant NO_CREDENTIALS => 'Username or password not specified.';
use constant NO_CAT_ID => 'No catalog IDs specified.';
use constant NO_OBJ_NAME => 'No object name specified.';
use constant NO_RECORDS => 'No records found.';

use constant DOMAIN => 'www.space-track.org';
use constant SESSION_PATH => '/';
use constant SESSION_KEY => 'spacetrack_session';

my %catalogs = (	# Catalog names (and other info) for each source.
    celestrak => {
	'tle-new' => {name => "Last 30 Days' Launches"},
	stations => {name => 'International Space Station'},
	visual => {name => '100 (or so) brightest'},
	weather => {name => 'Weather'},
	noaa => {name => 'NOAA'},
	goes => {name => 'GOES'},
	resource => {name => 'Earth Resources'},
	sarsat => {name => 'Search and Rescue (SARSAT)'},
	dmc => {name => 'Disaster Monitoring'},
	tdrss => {name => 'Tracking and Data Relay Satellite System (TDRSS)'},
	geo => {name => 'Geostationary'},
	intelsat => {name => 'Intelsat'},
	gorizont => {name => 'Gorizont'},
	raduga => {name => 'Raduga'},
	molniya => {name => 'Molniya'},
	iridium => {name => 'Iridium'},
	orbcomm => {name => 'Orbcomm'},
	globalstar => {name => 'Globalstar'},
	amateur => {name => 'Amateur Radio'},
	'x-comm' => {name => 'Experimental Communications'},
	'other-comm' => {name => 'Other communications'},
	'gps-ops' => {name => 'GPS Operational'},
	'glo-ops' => {name => 'Glonass Operational'},
	galileo => {name => 'Galileo'},
	sbas => {name =>
	    'Satellite-Based Augmentation System (WAAS/EGNOS/MSAS)'},
	nnss => {name => 'Navy Navigation Satellite System (NNSS)'},
	musson => {name => 'Russian LEO Navigation'},
	science => {name => 'Space and Earth Science'},
	geodetic => {name => 'Geodetic'},
	engineering => {name => 'Engineering'},
	education => {name => 'Education'},
	military => {name => 'Miscellaneous Military'},
	radar => {name => 'Radar Calibration'},
	cubesat => {name => 'CubeSats'},
	other => {name => 'Other'},
	},
    iridium_status => {
	kelso => {name => 'Celestrak (Kelso)'},
	mccants => {name => 'McCants'},
    },
    spaceflight => {
	iss => {name => 'International Space Station',
		url => 'http://spaceflight.nasa.gov/realdata/sightings/SSapplications/Post/JavaSSOP/orbit/ISS/SVPOST.html',
		},
	shuttle => {name => 'Current shuttle mission',
		url => 'http://spaceflight.nasa.gov/realdata/sightings/SSapplications/Post/JavaSSOP/orbit/SHUTTLE/SVPOST.html',
		},
	},
    spacetrack => {
	md5 => {name => 'MD5 checksums', number => 0, special => 1},
	full => {name => 'Full catalog', number => 1},
	geosynchronous => {name => 'Geosynchronous satellites', number => 3},
	navigation => {name => 'Navigation satellites', number => 5},
	weather => {name => 'Weather satellites', number => 7},
	iridium => {name => 'Iridium satellites', number => 9},
	orbcomm => {name => 'OrbComm satellites', number => 11},
	globalstar => {name => 'Globalstar satellites', number => 13},
	intelsat => {name => 'Intelsat satellites', number => 15},
	inmarsat => {name => 'Inmarsat satellites', number => 17},
	amateur => {name => 'Amateur Radio satellites', number => 19},
	visible => {name => 'Visible satellites', number => 21},
	special => {name => 'Special satellites', number => 23},
	},
    );

my %mutator = (	# Mutators for the various attributes.
    addendum => \&_mutate_attrib,		# Addendum to banner text.
    banner => \&_mutate_attrib,
    cookie_expires => \&_mutate_attrib,
    debug_url => \&_mutate_attrib,	# Force the URL. Undocumented and unsupported.
    direct => \&_mutate_attrib,
    dump_headers => \&_mutate_attrib,	# Dump all HTTP headers. Undocumented and unsupported.
    fallback => \&_mutate_attrib,
    filter => \&_mutate_attrib,
    iridium_status_format => \&_mutate_iridium_status_format,
    max_range => \&_mutate_number,
    password => \&_mutate_authen,
    session_cookie => \&_mutate_cookie,
    url_iridium_status_kelso => \&_mutate_attrib,
    url_iridium_status_mccants => \&_mutate_attrib,
    username => \&_mutate_authen,
    verbose => \&_mutate_attrib,
    webcmd => \&_mutate_attrib,
    with_name => \&_mutate_attrib,
    );
# Maybe I really want a cookie_file attribute, which is used to do
# $self->{agent}->cookie_jar ({file => $self->{cookie_file}, autosave => 1}).
# We'll want to use a false attribute value to pass an empty hash. Going to
# this may imply modification of the new () method where the cookie_jar is
# defaulted and the session cookie's age is initialized.


=item $st = Astro::SpaceTrack->new ( ... )

=for html <a name="new"></a>

This method instantiates a new Space-Track accessor object. If any
arguments are passed, the set () method is called on the new object,
and passed the arguments given.

Proxies are taken from the environment if defined. See the ENVIRONMENT
section of the Perl LWP documentation for more information on how to
set these up.

=cut

my @inifil;

=begin comment

At some point I thought that an initialization file would be a good
idea. But it seems unlikely to me that anyone will want commands
other than 'set' commands issued every time an object is instantiated,
and the 'set' commands are handled by the environment variables. So
I changed my mind.

my $inifil = $^O eq 'MSWin32' || $^O eq 'VMS' || $^O eq 'MacOS' ?
    'SpaceTrack.ini' : '.SpaceTrack';

$inifil = $^O eq 'VMS' ? "SYS\$LOGIN:$inifil" :
    $^O eq 'MacOS' ? $inifil :
    $ENV{HOME} ? "$ENV{HOME}/$inifil" :
    $ENV{LOGDIR} ? "$ENV{LOGDIR}/$inifil" : undef or warn <<eod;
Warning - Can't find home directory. Initialization file will not be
        executed.
eod

@inifil = __PACKAGE__->_source ($inifil) if $inifil && -e $inifil;

=end comment

=cut

sub new {
my $class = shift;
$class = ref $class if ref $class;

my $self = {
    agent => LWP::UserAgent->new (),
    banner => 1,	# shell () displays banner if true.
    cookie_expires => 0,
    debug_url => undef,	# Not turned on
    direct => 0,	# Do not direct-fetch from redistributors
    dump_headers => 0,	# No dumping.
    fallback => 0,	# Do not fall back if primary source offline
    filter => 0,	# Filter mode.
    iridium_status_format => 'mccants',	# For historical reasons.
    max_range => 500,	# Sanity limit on range size.
    password => undef,	# Login password.
    session_cookie => undef,
    url_iridium_status_kelso =>
	'http://celestrak.com/SpaceTrack/query/iridium.txt',
    url_iridium_status_mccants =>
	'http://www.io.com/~mmccants/tles/iridium.html',
    username => undef,	# Login username.
    verbose => undef,	# Verbose error messages for catalogs.
    webcmd => undef,	# Command to get web help.
    with_name => undef,	# True to retrieve three-line element sets.
    };
bless $self, $class;

$self->{agent}->env_proxy;

if (@inifil) {
    $self->{filter} = 1;
    $self->shell (@inifil, 'exit');
    $self->{filter} = 0;
    }

$ENV{SPACETRACK_OPT} and
    $self->set (grep {defined $_} split '\s+', $ENV{SPACETRACK_OPT});

$ENV{SPACETRACK_USER} and do {
    my ($user, $pass) = split '/', $ENV{SPACETRACK_USER}, 2;
    $self->set (username => $user, password => $pass);
    };

@_ and $self->set (@_);

$self->{agent}->cookie_jar ({})
    unless $self->{agent}->cookie_jar;

$self->_check_cookie ();

return $self;
}

=for html <a name="amsat"></a>

=item $resp = $st->amsat ()

This method downloads current orbital elements from the Radio Amateur
Satellite Corporation's web page, L<http://www.amsat.org/>. This lists
satellites of interest to radio amateurs, and appears to be updated
weekly.

No Space Track account is needed to access this data, even if the
'direct' attribute is false. But if the 'direct' attribute is true,
the setting of the 'with_name' attribute is ignored.

This method is a web page scraper. any change in the location of the
web page will break this method.

=cut

sub amsat {
my $self = shift;
delete $self->{_content_type};
my $content = '';
my $now = time ();
foreach my $url (
	'http://www.amsat.org/amsat/ftp/keps/current/nasabare.txt',
	) {
    my $resp = $self->{agent}->get ($url);
    return $resp unless $resp->is_success;
    $self->_dump_headers ($resp) if $self->{dump_headers};
    my ($tle, @data, $epoch);
    foreach (split '\n', $resp->content) {
	push @data, "$_\n";
	@data == 3 or next;
	shift @data unless $self->{direct} || $self->{with_name};
	$content .= join '', @data;
	@data = ();
	}
    }

$content or
    return HTTP::Response->new (RC_PRECONDITION_FAILED, NO_CAT_ID);

my $resp = HTTP::Response->new (RC_OK, undef, undef, $content);
$self->{_content_type} = 'orbit';
$resp->push_header (pragma => 'spacetrack-type = orbit');
$self->_dump_headers ($resp) if $self->{dump_headers};
$resp;
}

=item @names = $st->attribute_names

This method returns a list of legal attribute names.

=cut

sub attribute_names {wantarray ? sort keys %mutator : [sort keys %mutator]}


=for html <a name="banner"></a>

=item $resp = $st->banner ();

This method is a convenience/nuisance: it simply returns a fake
HTTP::Response with standard banner text. It's really just for the
benefit of the shell method.

=cut

sub banner {
my $self = shift;
HTTP::Response->new (RC_OK, undef, undef, <<eod);

@{[__PACKAGE__]} version $VERSION
Perl $Config{version} under $^O

You must register with http://@{[DOMAIN]}/ and get a
username and password before you can make use of this package,
and you must abide by that site's restrictions, which include
not making the data available to a third party without prior
permission.

Copyright 2005, 2006, 2007 T. R. Wyant (wyant at cpan dot org). All
rights reserved.

This module is free software; you can use it, redistribute it
and/or modify it under the same terms as Perl itself.
@{[$self->{addendum} || '']}
eod

}


=for html <a name="celestrak"></a>

=item $resp = $st->celestrak ($name);

This method takes the name of a Celestrak data set and returns an
HTTP::Response object whose content is the relevant element sets.
If called in list context, the first element of the list is the
aforementioned HTTP::Response object, and the second element is a
list reference to list references  (i.e. a list of lists). Each
of the list references contains the catalog ID of a satellite or
other orbiting body and the common name of the body.

A list of valid names and brief descriptions can be obtained by calling
$st->names ('celestrak'). If you have set the 'verbose' attribute true
(e.g. $st->set (verbose => 1)), the content of the error response will
include this list. Note, however, that this list does not determine what
can be retrieved; if Dr.  Kelso adds a data set, it can be retrieved
even if it is not on the list, and if he removes one, being on the list
won't help.

In general, the data set names are the same as the file names given at
L<http://celestrak.com/NORAD/elements/>, but without the '.txt' on the
end; for example, the name of the 'International Space Station' data set
is 'stations', since the URL for this is
L<http://celestrak.com/NORAD/elements/stations.txt>.

As of October 11 2007, the data set for the debris from the People's
Republic of China's anti-satellite test is available from Celestrak only
by direct-fetching ($st->set (direct => 1), see below), as data set
'1999-025'. I have not corresponded with Dr. Kelso on this, but I think
it reasonable to believe that the effect of asking Space Track for all
2126 pieces of debris at once would not be good.

If the 'direct' attribute is true, or if the 'fallback' attribute is
true and the data are not available from Space Track, the elements will
be fetched directly from Celestrak, and no login is needed. Otherwise,
This method implicitly calls the login () method if the session cookie
is missing or expired, and returns the SpaceTrack data for the OIDs
fetched from Celestrak. If login () fails, you will get the
HTTP::Response from login ().

If this method succeeds, a 'Pragma: spacetrack-type = orbit' header is
added to the HTTP::Response object returned.

You can specify the L</retrieve> options on this method as well, but
they will have no effect if the 'direct' attribute is true.

=cut

{	# Local symbol block.

    my %valid_type = ('text/plain' => 1, 'text/text' => 1);

    sub celestrak {
	my $self = shift;
	delete $self->{_content_type};

	@_ = _parse_retrieve_args (@_) unless ref $_[0] eq 'HASH';
	my $opt = shift;

	my $name = shift;
	$self->{direct}
	    and return $self->_celestrak_direct ($opt, $name);
	my $resp = $self->{agent}->get (
	    "http://celestrak.com/SpaceTrack/query/$name.txt");
	return $self->_no_such_catalog (celestrak => $name)
	    if $resp->code == RC_NOT_FOUND;
	return $resp unless $resp->is_success;
	return $self->_no_such_catalog (celestrak => $name)
	    unless $valid_type{lc $resp->header ('Content-Type')};
	$self->_convert_content ($resp);
	$self->_dump_headers ($resp) if $self->{dump_headers};
	$resp = $self->_handle_observing_list ($opt, $resp->content);
	return ($resp->is_success || !$self->{fallback}) ? $resp :
	    $self->_celestrak_direct ($opt, $name);
    }

    sub _celestrak_direct {
	my $self = shift;
	delete $self->{_content_type};

	@_ = _parse_retrieve_args (@_) unless ref $_[0] eq 'HASH';
	my $opt = shift;

	my $name = shift;
	my $resp = $self->{agent}->get (
	    "http://celestrak.com/NORAD/elements/$name.txt");
	return $self->_no_such_catalog (celestrak => $name)
	    if $resp->code == RC_NOT_FOUND;
	return $resp unless $resp->is_success;
	return $self->_no_such_catalog (celestrak => $name)
	    unless $valid_type{lc $resp->header ('Content-Type')};
	$self->_convert_content ($resp);
	if ($name eq 'iridium') {
	    $resp->content (join "\n",
		map {s/\s+\[.\]\s*$//; $_} split '\n', $resp->content);
	}
	$self->{_content_type} = 'orbit';
	$resp->push_header (pragma => 'spacetrack-type = orbit');
	$self->_dump_headers ($resp) if $self->{dump_headers};
	$resp;
    }

}	# End local symbol block.


=item $type = $st->content_type ($resp);

This method takes the given HTTP::Response object and returns the
data type specified by the 'Pragma: spacetrack-type =' header. The
following values are supported:

 'get': The content is a parameter value.
 'help': The content is help text.
 'orbit': The content is NORAD data sets.
 undef: No spacetrack-type pragma was specified. The
        content is something else (typically 'OK').

If the response object is not provided, it returns the data type
from the last method call that returned an HTTP::Response object.

=cut

sub content_type {
my $self = shift;
return $self->{_content_type} unless @_;
my $resp = shift;
foreach ($resp->header ('Pragma')) {
    m/spacetrack-type = (.+)/i and return $1;
    }
return;
}


=for html <a name="file"></a>

=item $resp = $st->file ($name)

This method takes the name of an observing list file, or a handle to
an open observing list file, and returns an HTTP::Response object whose
content is the relevant element sets. If called in list context, the
first element of the list is the aforementioned HTTP::Response object,
and the second element is a list reference to list references  (i.e.
a list of lists). Each of the list references contains the catalog ID
of a satellite or other orbiting body and the common name of the body.

This method implicitly calls the login () method if the session cookie
is missing or expired. If login () fails, you will get the
HTTP::Response from login ().

The observing list file is (how convenient!) in the Celestrak format,
with the first five characters of each line containing the object ID,
and the rest containing a name of the object. Lines whose first five
characters do not look like a right-justified number will be ignored.

If this method succeeds, a 'Pragma: spacetrack-type = orbit' header is
added to the HTTP::Response object returned.

You can specify the L</retrieve> options on this method as well.

=cut

sub file {
my $self = shift;

@_ = _parse_retrieve_args (@_) unless ref $_[0] eq 'HASH';
my $opt = shift;

delete $self->{_content_type};
my $name = shift;
ref $name and fileno ($name) and return $self->_handle_observing_list (<$name>);
-e $name or return HTTP::Response->new (RC_NOT_FOUND, "Can't find file $name");
my $fh = FileHandle->new ($name) or
    return HTTP::Response->new (RC_INTERNAL_SERVER_ERROR, "Can't open $name: $!");
local $/;
$/ = undef;
return $self->_handle_observing_list ($opt, <$fh>)
}


=for html <a name="get"></a>

=item $resp = $st->get (attrib)

B<This method returns an HTTP::Response object> whose content is the value
of the given attribute. If called in list context, the second element
of the list is just the value of the attribute, for those who don't want
to winkle it out of the response object. We croak on a bad attribute name.

See L</Attributes> for the names and functions of the attributes.

=cut

sub get {
my $self = shift;
delete $self->{_content_type};
my $name = shift;
croak "No attribute name specified. Legal attributes are ",
	join (', ', sort keys %mutator), ".\n"
    unless defined $name;
croak "Attribute $name may not be gotten. Legal attributes are ",
	join (', ', sort keys %mutator), ".\n"
    unless $mutator{$name};
my $resp = HTTP::Response->new (RC_OK, undef, undef, $self->{$name});
$self->{_content_type} = 'get';
$resp->push_header (pragma => 'spacetrack-type = get');
$self->_dump_headers ($resp) if $self->{dump_headers};
return wantarray ? ($resp, $self->{$name}) : $resp;
}


=for html <a name="help"></a>

=item $resp = $st->help ()

This method exists for the convenience of the shell () method. It
always returns success, with the content being whatever it's
convenient (to the author) to include.

If the L<webcmd|/webcmd> attribute is set, the L<http://search.cpan.org/>
web page for this version of Astro::Satpass is launched.

=cut

sub help {
my $self = shift;
delete $_[0]->{_content_type};
if ($self->{webcmd}) {
    system (join ' ', $self->{webcmd},
	"http://search.cpan.org/~wyant/Astro-SpaceTrack-$VERSION/");
    HTTP::Response->new (RC_OK, undef, undef, 'OK');
    }
  else {
    my $resp = HTTP::Response->new (RC_OK, undef, undef, <<eod);
The following commands are defined:
  celestrak name
    Retrieves the named catalog of IDs from Celestrak. If the
    direct attribute is false (the default), the corresponding
    orbital elements come from Space Track. If true, they come
    from Celestrak, and no login is needed.
  exit (or bye)
    Terminate the shell. End-of-file also works.
  file filename
    Retrieve the catalog IDs given in the named file (one per
    line, with the first five characters being the ID).
  get
    Get the value of a single attribute.
  help
    Display this help text.
  iridium_status
    Status of Iridium satellites, from Mike McCants and/or
    T. S. Kelso.
  login
    Acquire a session cookie. You must have already set the
    username and password attributes. This will be called
    implicitly if needed by any method that accesses data.
  names source
    Lists the catalog names from the given source.
  retrieve number ...
    Retieves the latest orbital elements for the given
    catalog numbers.
  search_id id ...
    Retrieves orbital elements by international designator.
  search_name name ...
    Retrieves orbital elements by satellite common name.
  set attribute value ...
    Sets the given attributes. Legal attributes are
      addendum = extra text for the shell () banner;
      banner = false to supress the shell () banner;
      cookie_expires = Perl date the session cookie expires;
      debug_url = Override canned url for debugging - do not
        set this in normal use;
      direct = true to fetch orbital elements directly
        from a redistributer. Currently this only affects the
        celestrak() method. The default is false.
      dump_headers is unsupported, and intended for debugging -
        don't be suprised at anything it does, and don't rely
        on anything it does;
      filter = true supresses all output to stdout except
        orbital elements;
      max_range = largest range of numbers that can be re-
        trieved (default: 500);
      password = the Space-Track password;
      session_cookie = the text of the session cookie;
      username = the Space-Track username;
      verbose = true for verbose catalog error messages;
      webcmd = command to launch a URL (for web-based help);
      with_name = true to retrieve common names as well.
    The session_cookie and cookie_expires attributes should
    only be set to previously-retrieved, matching values.
  source filename
    Executes the contents of the given file as shell commands.
  spaceflight
    Retrieves orbital elements from http://spaceflight.nasa.gov/.
    No login needed, but you get at most the ISS and the current
    shuttle mission.
  spacetrack name
    Retrieves the named catalog of orbital elements from
    Space Track.
The shell supports a pseudo-redirection of standard output,
using the usual Unix shell syntax (i.e. '>output_file').
eod
    $self->{_content_type} = 'help';
    $resp->push_header (pragma => 'spacetrack-type = help');
    $self->_dump_headers ($resp) if $self->{dump_headers};
    $resp;
    }
}


=for html <a name="iridium_status"></a>

=item $resp = $st->iridium_status ($format);

This method queries its sources of Iridium status, returning an
HTTP::Response object containing the relevant data (if all queries
succeeded) or the status of the first failure. If the queries succeed,
the content is a series of lines formatted by "%6d   %-15s%-8s %s\n",
with NORAD ID, name, status, and comment substituted in.

The source of the data and, to a certain extent, the format of the
results is determined by the optional $format argument, which defaults
to the value of the L</iridium_status_format> attribute.

If the format is 'kelso', only celestrak.com is queried for the
data. The possible status values are:

    '[S]' - Spare;
    '[-]' - Tumbling (or otherwise unservicable);
    '[+]' - In service and able to produce predictable flares.

The comment will be 'Spare', 'Tumbling', or '' depending on the status.

If the format is 'mccants', the primary source of information
will be Mike McCants' "Status of Iridium Payloads" web
page, http://www.io.com/~mmccants/tles/iridium.html (which gives
status on non-functional Iridium satellites). The Celestrak list
will be used to fill in the functioning satellites so that a complete
list is generated. The comment will be whatever text is provided by
Mike McCants' web page, or 'Celestrak' if the satellite data came
from that source.

As of 20-Feb-2006 Mike's web page documented the possible statuses as
follows:

 blank - object is operational
 'tum' - tumbling
 '?' - not at operational altitude
 'man' - maneuvering, at least slightly.

In addition, the data from Celestrak may contain the following
status:

 'dum' - Dummy mass

A blank status indicates that the satellite is in service and
therefore capable of producing flares.

If the method is called in list context, the first element of the
returned list will be the HTTP::Response object, and the second
element will be a reference to a list of anonymous lists, each
containing [$id, $name, $status, $comment, $portable_status] for
an Iridium satellite. The portable statuses are:

  0 = BODY_STATUS_IS_OPERATIONAL means object is operational
  1 = BODY_STATUS_IS_SPARE means object is a spare
  2 = BODY_STATUS_IS_TUMBLING means object is tumbling
      or otherwise unservicable.

The correspondence between the Kelso statuses and the portable statuses
is pretty much one-to-one. In the McCants statuses, '?' identifies a
spare, '+' identifies an in-service satellite, and anything else is
considered to be tumbling.

The BODY_STATUS constants are exportable using the :status tag.

=cut

{	# Begin local symbol block.

    use constant BODY_STATUS_IS_OPERATIONAL => 0;
    use constant BODY_STATUS_IS_SPARE => 1;
    use constant BODY_STATUS_IS_TUMBLING => 2;

    my %kelso_comment = (	# Expand Kelso status.
	'[S]' => 'Spare',
	'[-]' => 'Tumbling',
	);
    my %status_map = (	# Map Kelso status to McCants status.
	kelso => {
	    mccants => {
		'[S]' => '?',	# spare
		'[-]' => 'tum',	# tumbling
		'[+]' => '',	# operational
		},
	    },
	);
    my %status_portable = (	# Map statuses to portable.
	kelso => {
	    ''	=> BODY_STATUS_IS_OPERATIONAL,
	    '[-]' => BODY_STATUS_IS_TUMBLING,
	    '[S]' => BODY_STATUS_IS_SPARE,
	    '[+]' => BODY_STATUS_IS_OPERATIONAL,
	},
	mccants => {
	    '' => BODY_STATUS_IS_OPERATIONAL,
	    '?' => BODY_STATUS_IS_SPARE,
	    'dum' => BODY_STATUS_IS_TUMBLING,
	    'man' => BODY_STATUS_IS_TUMBLING,
	    'tum' => BODY_STATUS_IS_TUMBLING,
	    'tum?' => BODY_STATUS_IS_TUMBLING,
	},
    );

    sub iridium_status {
    my $self = shift;
    my $fmt = shift || $self->{iridium_status_format};
    delete $self->{_content_type};
    my %rslt;
    my $kelso_url = $self->get ('url_iridium_status_kelso')->content;
    my $resp = $self->{agent}->get ($kelso_url);
    $resp->is_success or return $resp;
    foreach my $buffer (split '\n', $resp->content) {
	$buffer =~ s/\s+$//;
	my $id = substr ($buffer, 0, 5) + 0;
	my $name = substr ($buffer, 5);
	$name =~ s/\s+(\[[^\]]+])\s*$//;
	my $status = $1 || '';
	my $portable_status = $status_portable{kelso}{$status};
	my $comment;
	if ($fmt eq 'kelso') {
	    $comment = $kelso_comment{$status} || '';
	    }
	  else {
	    $status = $status_map{kelso}{$fmt}{$status} || '';
	    $status = 'dum' unless $name =~ m/^IRIDIUM/i;
	    $comment = 'Celestrak';
	    }
	$name = ucfirst lc $name;
	$rslt{$id} = [$id, $name, $status, $comment,
	    $portable_status];
    }
    if ($fmt eq 'mccants') {
	my $mccants_url = $self->get ('url_iridium_status_mccants')->content;
	$resp = $self->{agent}->get ($mccants_url);
	$resp->is_success or return $resp;
	foreach my $buffer (split '\n', $resp->content) {
	    $buffer =~ m/^\s*(\d+)\s+Iridium\s+\S+/ or next;
	    my ($id, $name, $status, $comment) =
	        map {s/\s+$//; s/^\s+//; $_ || ''}
		$buffer =~ m/(.{8})(.{0,15})(.{0,9})(.*)/;
	    my $portable_status =
		exists $status_portable{mccants}{$status} ?
		    $status_portable{mccants}{$status} :
		    BODY_STATUS_IS_TUMBLING;
	    $rslt{$id} = [$id, $name, $status, $comment,
		$portable_status];
	#0         1         2         3         4         5         6         7
	#01234567890123456789012345678901234567890123456789012345678901234567890
	# 24836   Iridium 914    tum      Failed; was called Iridium 14
	    }
	}
    $resp->content (join '', map {
	    sprintf "%6d   %-15s%-8s %s\n", @{$rslt{$_}}}
	sort {$a <=> $b} keys %rslt);
    $self->{_content_type} = 'iridium-status';
    $resp->push_header (pragma => 'spacetrack-type = iridium-status');
    $self->_dump_headers ($resp) if $self->{dump_headers};
    wantarray ? ($resp, [values %rslt]) : $resp;
    }
}	# End of local symbol block.


=for html <a name="login"></a>

=item $resp = $st->login ( ... )

If any arguments are given, this method passes them to the set ()
method. Then it executes a login. The return is normally the
HTTP::Response object from the login. But if no session cookie was
obtained, the return is an HTTP::Response with an appropriate message
and the code set to RC_UNAUTHORIZED from HTTP::Status (a.k.a. 401). If
a login is attempted without the username and password being set, the
return is an HTTP::Response with an appropriate message and the
code set to RC_PRECONDITION_FAILED from HTTP::Status (a.k.a. 412).

=cut

sub login {
my $self = shift;
delete $self->{_content_type};
@_ and $self->set (@_);
$self->{username} && $self->{password} or
    return HTTP::Response->new (
	RC_PRECONDITION_FAILED, NO_CREDENTIALS);
$self->{dump_headers} and warn <<eod;
Logging in as $self->{username}.
eod

#	Do not use the _post method to retrieve the session cookie,
#	unless you like bottomless recursions.
my $resp = $self->{agent}->post (
    "http://@{[DOMAIN]}/perl/login.pl", [
	username => $self->{username},
	password => $self->{password},
	_submitted => 1,
	_sessionid => "",
	]);

$resp->is_success or return $resp;
$self->_dump_headers ($resp) if $self->{dump_headers};

$self->_check_cookie () > time ()
    or return HTTP::Response->new (RC_UNAUTHORIZED, LOGIN_FAILED);

$self->{dump_headers} and warn <<eod;
Login successful.
eod
HTTP::Response->new (RC_OK, undef, undef, "Login successful.\n");
}


=for html <a name="names"></a>

=item $resp = $st->names (source)

This method retrieves the names of the catalogs for the given source,
either 'celestrak' or 'spacetrack', in the content of the given
HTTP::Response object. In list context, you also get a reference to
a list of two-element lists; each inner list contains the description
and the catalog name (suitable for inserting into a Tk Optionmenu).

=cut

sub names {
my $self = shift;
delete $self->{_content_type};
my $name = lc shift;
$catalogs{$name} or return HTTP::Response (
	RC_NOT_FOUND, "Data source '$name' not found.");
my $src = $catalogs{$name};
my @list;
foreach my $cat (sort keys %$src) {
    push @list, defined ($src->{$cat}{number}) ?
	"$cat ($src->{$cat}{number}): $src->{$cat}{name}\n" :
	"$cat: $src->{$cat}{name}\n";
    }
my $resp = HTTP::Response->new (RC_OK, undef, undef, join ('', @list));
return $resp unless wantarray;
@list = ();
foreach my $cat (sort {$src->{$a}{name} cmp $src->{$b}{name}} keys %$src) {
    push @list, [$src->{$cat}{name}, $cat];
    }
return ($resp, \@list);
}


=for html <a name="retrieve"></a>

=item $resp = $st->retrieve (number_or_range ...)

This method retrieves the latest element set for each of the given
satellite ID numbers (also known as SATCAT IDs, NORAD IDs, or OIDs).
Non-numeric catalog numbers are ignored, as are (at a later stage)
numbers that do not actually represent a satellite.

Number ranges are represented as 'start-end', where both 'start' and
'end' are catalog numbers. If 'start' > 'end', the numbers will be
taken in the reverse order. Non-numeric ranges are ignored.

You can specify options for the retrieval as either command-type
options (e.g. retrieve ('-last5', ...)) or as a leading hash reference
(e.g. retrieve ({last5 => 1}, ...)). If you specify the hash reference,
option names must be specified in full, without the leading '-', and
the argument list will not be parsed for command-type options. If you
specify command-type options, they may be abbreviated, as long as
the abbreviation is unique. Errors in either sort result in an
exception being thrown.

The legal options are:

 descending
   specifies the data be returned in descending order.
 end_epoch date
   specifies the end epoch for the desired data.
 last5
   specifies the last 5 element sets be retrieved.
   Ignored if start_epoch or end_epoch specified.
 start_epoch date
   specifies the start epoch for the desired data.
 sort type
   specifies how to sort the data. Legal types are
   'catnum' and 'epoch', with 'catnum' the default.

If you specify either start_epoch or end_epoch, you get data with
epochs at least equal to the start epoch, but less than the end
epoch (i.e. the interval is closed at the beginning but open at
the end). If you specify only one of these, you get a one-day
interval. Dates are specified either numerically (as a Perl date)
or as numeric year-month-day, punctuated by any non-numeric string.
It is an error to specify an end_epoch before the start_epoch.

If you are passing the options as a hash reference, you must specify
a value for the boolean options 'descending' and 'last5'. This value is
interpreted in the Perl sense - that is, undef, 0, and '' are false,
and anything else is true.

In order not to load the Space Track web site too heavily, data are
retrieved in batches of 50. Ranges will be subdivided and handled in
more than one retrieval if necessary. To limit the damage done by a
pernicious range, ranges greater than the max_range setting (which
defaults to 500) will be ignored with a warning to STDERR.

This method implicitly calls the login () method if the session cookie
is missing or expired. If login () fails, you will get the
HTTP::Response from login ().

If this method succeeds, a 'Pragma: spacetrack-type = orbit' header is
added to the HTTP::Response object returned.

=cut

use constant RETRIEVAL_SIZE => 50;

sub retrieve {
my $self = shift;
delete $self->{_content_type};

@_ = _parse_retrieve_args (@_) unless ref $_[0] eq 'HASH';
my $opt = _parse_retrieve_dates (shift);

my @params = $opt->{start_epoch} ?
    (timeframe => 'timespan',
	start_year => $opt->{start_epoch}[5] + 1900,
	start_month => $opt->{start_epoch}[4] + 1,
	start_day => $opt->{start_epoch}[3],
	end_year => $opt->{end_epoch}[5] + 1900,
	end_month => $opt->{end_epoch}[4] + 1,
	end_day => $opt->{end_epoch}[3],
	) :
    $opt->{last5} ? (timeframe => 'last5') : (timeframe => 'latest');
push @params, common_name => $self->{with_name} ? 'yes' : '';
push @params, sort => $opt->{sort};
push @params, descending => $opt->{descending} ? 'yes' : '';

@_ = grep {m/^\d+(?:-\d+)?$/} @_;

@_ or return HTTP::Response->new (RC_PRECONDITION_FAILED, NO_CAT_ID);
my $content = '';
local $_;
my $resp;
while (@_) {
    my @batch;
    my $ids = 0;
    while (@_ && $ids < RETRIEVAL_SIZE) {
	$ids++;
	my ($lo, $hi) = split '-', shift @_;
	defined $hi and do {
	    ($lo, $hi) = ($hi, $lo) if $lo > $hi;
	    $hi - $lo >= $self->{max_range} and do {
		carp <<eod;
Warning - Range $lo-$hi ignored because it is greater than the
          currently-set maximum of $self->{max_range}.
eod
		next;
		};
	    $ids += $hi - $lo;
	    $ids > RETRIEVAL_SIZE and do {
		my $mid = $hi - $ids + RETRIEVAL_SIZE;
		unshift @_, "@{[$mid + 1]}-$hi";
		$hi = $mid;
		};
	    $lo = "$lo-$hi" if $hi > $lo;
	    };
	push @batch, $lo;
	}
    next unless @batch;
    $resp = $self->_post ('perl/id_query.pl',
	ids => "@batch",
	@params,
	ascii => 'yes',		# or ''
	_sessionid => '',
	_submitted => 1,
	);
    return $resp unless $resp->is_success;
    $_ = $resp->content;
    next if m/No records found/i;
    if (m/ERROR:/) {
	return HTTP::Response->new (RC_INTERNAL_SERVER_ERROR,
	    "Failed to retrieve IDs @batch.\n",
	    undef, $content);
    }
    s|</pre>.*||ms;
    s|.*<pre>||ms;
    s|^\n||ms;
    $content .= $_;
    }
$content or return HTTP::Response->new (RC_NOT_FOUND, NO_RECORDS);
$resp->content ($content);
$self->_convert_content ($resp);
$self->{_content_type} = 'orbit';
$resp->push_header (pragma => 'spacetrack-type = orbit');
$resp;
}


=for html <a name="search_date"></a>

=item $resp = $st->search_date (date ...)

This method searches the database for objects launched on the given
date. The date is specified as year-month-day, with any non-digit being
legal as the separator. You can omit -day or specify it as 0 to get
all launches for the given month. You can omit -month (or specify it
as 0) as well to get all launches for the given year.

You can specify options for the search as either command-type options
(e.g. search (-status => 'onorbit', ...)) or as a leading hash reference
(e.g. search ({status => onorbit}, ...)). If you specify the hash
reference, option names must be specified in full, without the leading
'-', and the argument list will not be parsed for command-type options.
Options that take multiple values (i.e. 'exclude') must have their
values specified as a hash reference, even if you only specify one value
- or none at all.

If you specify command-type options, they may be abbreviated, as long as
the abbreviation is unique. Errors in either sort of specification
result in an exception being thrown.

In addition to the options available for L</retrieve>, the following
options may be specified:

 exclude
   specifies the types of bodies to exclude. The
   value is one or more of 'debris' or 'rocket'.
   If you specify both as command-style options,
   you may either specify the option more than once,
   or specify the values comma-separated.
 status
   specifies the desired status of the returned body
   (or bodies). Must be 'onorbit', 'decayed', or 'all'.
   The default is 'all'. Note that this option
   represents status at the time the search was done;
   you can not combine it with the retrieve() date
   options to find bodies onorbit as of a given date
   in the past.

Examples:

 search_date (-status => 'onorbit', -exclude =>
    'debris,rocket', -last5 '2005-12-25');
 search_date (-exclude => 'debris',
    -exclude => 'rocket', '2005/12/25');
 search_date ({exclude => ['debris', 'rocket']},
    '2005-12-25');
 search_date ({exclude => 'debris,rocket'}, # INVALID!
    '2005-12-25');

This method implicitly calls the login () method if the session cookie
is missing or expired. If login () fails, you will get the
HTTP::Response from login ().

On success, this method returns an HTTP::Response object whose content
is the relevant element sets. If called in list context, the first
element of the list is the aforementioned HTTP::Response object, and
the second element is a list reference to list references  (i.e. a list
of lists). The first list reference contains the header text for all
columns returned, and the subsequent list references contain the data
for each match.

If this method succeeds, a 'Pragma: spacetrack-type = orbit' header is
added to the HTTP::Response object returned.

=cut

sub search_date {
my $self = shift;
@_ = _parse_search_args (@_);
$self->_search_generic (sub {
    my ($self, $name, $opt) = @_;
    my ($year, $month, $day) =
	$name =~ m/^(\d+)(?:\D+(\d+)(?:\D+(\d+))?)?/
	    or return undef;
    $year += $year < 57 ? 2000 : $year < 100 ? 1900 : 0;
    $month ||= 0;
    $day ||= 0;
    my $resp = $self->_post ('perl/launch_query.pl',
	date_spec => 'month',
	launch_year => $year,
	launch_month => $month,
	launch_day => $day,
	status => $opt->{status},	# 'all', 'onorbit' or 'decayed'.
	exclude => $opt->{exclude},	# ['debris', 'rocket', or both]
	_sessionid => '',
	_submit => 'submit',
	_submitted => 1,
	);
    }, @_);
}


=for html <a name="search_id"></a>

=item $resp = $st->search_id (id ...)

This method searches the database for objects having the given
international IDs. The international ID is the last two digits of the
launch year (in the range 1957 through 2056), the three-digit sequence
number of the launch within the year (with leading zeroes as needed),
and the piece (A through ZZ, with A typically being the payload). You
can omit the piece and get all pieces of that launch, or omit both the
piece and the launch number and get all launches for the year. There is
no mechanism to restrict the search to a given on-orbit status, or to
filter out debris or rocket bodies.

This method implicitly calls the login () method if the session cookie
is missing or expired. If login () fails, you will get the
HTTP::Response from login ().

On success, this method returns an HTTP::Response object whose content
is the relevant element sets. If called in list context, the first
element of the list is the aforementioned HTTP::Response object, and the
second element is a list reference to list references  (i.e. a list of
lists). The first list reference contains the header text for all
columns returned, and the subsequent list references contain the data
for each match.

If this method succeeds, a 'Pragma: spacetrack-type = orbit' header is
added to the HTTP::Response object returned.

You can specify the L</retrieve> options on this method as well.

=cut

sub search_id {
my $self = shift;
## @_ = _parse_search_args (@_);
$self->_search_generic (sub {
    my ($self, $name, $opt) = @_;
    my ($year, $number, $piece) =
	$name =~ m/^(\d\d)(\d{3})?([[:alpha:]])?$/ or return undef;
    $year += $year < 57 ? 2000 : 1900;
    my $resp = $self->_post ('perl/launch_query.pl',
	date_spec => 'number',
	launch_year => $year,
	launch_number => $number || '',
	piece => uc ($piece || ''),
	status => $opt->{status},	# 'all', 'onorbit' or 'decayed'.
	exclude => $opt->{exclude},	# ['debris', 'rocket', or both]
	_sessionid => '',
	_submit => 'submit',
	_submitted => 1,
	);
    }, @_);
}


=for html <a name="search_name"></a>

=item $resp = $st->search_name (name ...)

This method searches the database for the named objects. Matches
are case-insensitive and all matches are returned.

This method implicitly calls the login () method if the session cookie
is missing or expired. If login () fails, you will get the
HTTP::Response from login ().

On success, this method returns an HTTP::Response object whose content
is the relevant element sets. If called in list context, the first
element of the list is the aforementioned HTTP::Response object, and
the second element is a list reference to list references  (i.e. a list
of lists). The first list reference contains the header text for all
columns returned, and the subsequent list references contain the data
for each match.

If this method succeeds, a 'Pragma: spacetrack-type = orbit' header is
added to the HTTP::Response object returned.

You can specify the L</retrieve> and L</search_date> options on this
method as well. The L</search_date> -status option is known to work,
but I am not sure about the efficacy the -exclude option.

=cut

sub search_name {
my $self = shift;
@_ = _parse_search_args (@_);
$self->_search_generic (sub {
    my ($self, $name, $opt) = @_;
    $self->_post ('perl/name_query.pl',
	_submitted => 1,
	_sessionid => '',
	name => $name,
	launch_year_start => 1957,
	launch_year_end => (gmtime)[5] + 1900,
	status => $opt->{status},	# 'all', 'onorbit' or 'decayed'.
	exclude => $opt->{exclude},	# ['debris', 'rocket', or both]
	_submit => 'Submit',
	);
    }, @_);
}


=for html <a name="set"></a>

=item $st->set ( ... )

This is the mutator method for the object. It can be called explicitly,
but other methods as noted may call it implicitly also. It croaks if
you give it an odd number of arguments, or if given an attribute that
either does not exist or cannot be set.

For the convenience of the shell method we return a HTTP::Response
object with a success status if all goes well. But if we encounter an
error we croak.

See L</Attributes> for the names and functions of the attributes.

=cut

sub set {
my $self = shift;
delete $self->{_content_type};
croak "@{[__PACKAGE__]}->set (@{[join ', ', map {qq{'$_'}} @_]}) requires an even number of arguments"
    if @_ % 2;
while (@_) {
    my $name = shift;
    croak "Attribute $name may not be set. Legal attributes are ",
	    join (', ', sort keys %mutator), ".\n"
	unless $mutator{$name};
    my $value = shift;
    $mutator{$name}->($self, $name, $value);
    }
HTTP::Response->new (RC_OK, undef, undef, COPACETIC);
}


=for html <a name="shell"></a>

=item $st->shell ()

This method implements a simple shell. Any public method name except
'new' or 'shell' is a command, and its arguments if any are parameters.
We use Text::ParseWords to parse the line, and blank lines or lines
beginning with a hash mark ('#') are ignored. Input is via
Term::ReadLine if that is available. If not, we do the best we can.

We also recognize 'bye' and 'exit' as commands, which terminate the
method. In addition, 'show' is recognized as a synonym for 'get', and
'get' (or 'show') without arguments is special-cased to list all
attribute names and their values. Attributes listed without a value have
the undefined value.

For commands that produce output, we allow a sort of pseudo-redirection
of the output to a file, using the syntax ">filename" or ">>filename".
If the ">" is by itself the next argument is the filename. In addition,
we do pseudo-tilde expansion by replacing a leading tilde with the
contents of environment variable HOME. Redirection can occur anywhere
on the line. For example,

 SpaceTrack> catalog special >special.txt

sends the "Special Interest Satellites" to file special.txt. Line
terminations in the file should be appropriate to your OS.

This method can also be called as a subroutine - i.e. as

 Astro::SpaceTrack::shell (...)

Whether called as a method or as a subroutine, each argument passed
(if any) is parsed as though it were a valid command. After all such
have been executed, control passes to the user. Unless, of course,
one of the arguments was 'exit'.

Unlike most of the other methods, this one returns nothing.

=cut

my ($read, $print, $out, $rdln);

sub shell {
my $self = shift if UNIVERSAL::isa $_[0], __PACKAGE__;
$self ||= Astro::SpaceTrack->new (addendum => <<eod);

'help' gets you a list of valid commands.
eod

my $prompt = 'SpaceTrack> ';

$out = \*STDOUT;
$print = sub {
	my $hndl = UNIVERSAL::isa ($_[0], 'FileHandle') ? shift : $out;
	print $hndl @_
	};

unshift @_, 'banner' if $self->{banner} && !$self->{filter};
while (1) {
    my $buffer;
    if (@_) {
	$buffer = shift;
	}
      else {
	unless ($read) {
	    -t STDIN ? eval {
		require Term::ReadLine;
		$rdln ||= Term::ReadLine->new ('SpaceTrack orbital element access');
		$out = $rdln->OUT || \*STDOUT;
		$read = sub {$rdln->readline ($prompt)};
		} || ($read = sub {print $out $prompt; <STDIN>}):
		eval {$read = sub {<STDIN>}};
	    }
	$buffer = $read->();
	}
    last unless defined $buffer;

    chomp $buffer;
    $buffer =~ s/^\s+//;
    $buffer =~ s/\s+$//;
    next unless $buffer;
    next if $buffer =~ m/^#/;
    my @args = parse_line ('\s+', 0, $buffer);
    my $redir = '';
    @args = map {m/^>/ ? do {$redir = $_; ()} :
	$redir =~ m/^>+$/ ? do {$redir .= $_; ()} :
	$_} @args;
    $redir =~ s/^(>+)~/$1$ENV{HOME}/;
    my $verb = lc shift @args;
    last if $verb eq 'exit' || $verb eq 'bye';
    $verb eq 'show' and $verb = 'get';
    $verb eq 'source' and do {
	eval {
	    splice @_, 0, 0, $self->_source (shift @args);
	    };
	$@ and warn $@;
	next;
	};
    $verb eq 'new' || $verb =~ m/^_/ || $verb eq 'shell' ||
	!$self->can ($verb) and do {
	warn <<eod;
Verb '$verb' undefined. Use 'help' to get help.
eod
	next;
	};
    my @fh = (FileHandle->new ($redir)) or do {warn <<eod; next} if $redir;
Error - Failed to open $redir
        $^E
eod
    my $rslt;
    if ($verb eq 'get' && @args == 0) {
	$rslt = [];
	foreach my $name ($self->attribute_names ()) {
	    my $val = $self->get ($name)->content ();
	    push @$rslt, defined $val ? "$name $val" : $name;
	}
    } else {
	$rslt = eval {$self->$verb (@args)};
    }
    $@ and do {warn $@; next; };
    if (ref $rslt eq 'ARRAY') {
	foreach (@$rslt) {print "$_\n"}
	}
      elsif ($rslt->is_success) {
	my $content = $rslt->content;
	chomp $content;
	$print->(@fh, "$content\n")
	    if !$self->{filter} || $self->content_type ();
	}
      else {
	my $status = $rslt->status_line;
	chomp $status;
	warn $status, "\n";
	}
    }
$print->("\n") if -t STDIN && !$self->{filter};
}


=for html <a name="source"></a>

=item $st->source ($filename);

This convenience method reads the given file, and passes the individual
lines to the shell method. It croaks if the file is not provided or
cannot be read.

=cut

sub source {
my $self = shift if UNIVERSAL::isa $_[0], __PACKAGE__;
$self ||= Astro::SpaceTrack->new ();
$self->shell ($self->_source (@_), 'exit');
}


=for html <a name="spaceflight"></a>

=item $resp = $st->spaceflight ()

This method downloads current orbital elements from NASA's human
spaceflight site, L<http://spaceflight.nasa.gov/>. As of July 2006
you get the International Space Station, and the current Space Shuttle
mission, if any.

No Space Track account is needed to access this data, even if the
'direct' attribute is false. But if the 'direct' attribute is true,
the setting of the 'with_name' attribute is ignored.

This method is a web page scraper. any change in the location of the
web pages, or any substantial change in their format, will break this
method.

You can specify the L</retrieve> options on this method as well. In
addition, you can specify -all to get all data. -all will be ignored
if -start_epoch, -end_epoch, or -last5 is specified.

=cut


sub spaceflight {
my $self = shift;
delete $self->{_content_type};

@_ = _parse_retrieve_args ([all => 'retrieve all data'], @_)
    unless ref $_[0] eq 'HASH';
my $opt = _parse_retrieve_dates (shift, {perldate => 1});

$opt->{all} = 0 if $opt->{last5} || $opt->{start_epoch};

my @list;
if (@_) {
    foreach (@_) {
	my $info = $catalogs{spaceflight}{lc $_} or
	    return $self->_no_such_catalog (spaceflight => $_);
	push @list, $info->{url};
	}
    }
  else {
    my $hash = $catalogs{spaceflight};
    @list = map {$hash->{$_}{url}} sort keys %$hash;
    }

my $content = '';
my $now = time ();
my %tle;
foreach my $url (@list) {
    my $resp = $self->{agent}->get ($url);
    return $resp unless $resp->is_success;
    my (@data, $acquire);
    foreach (split '\n', $resp->content) {
	chomp;
	m/TWO LINE MEAN ELEMENT SET/ and do {
	    $acquire = 1;
	    @data = ();
	    next;
	    };
	next unless $acquire;
	s/^\s+//;
	$_ and do {push @data, "$_\n"; next};
	@data and do {
	    $acquire = undef;
	    @data == 2 || @data == 3 or next;
	    shift @data
		if @data == 3 && !$self->{direct} && !$self->{with_name};
	    my $ix = @data - 2;
	    my $id = substr ($data[$ix], 2, 5) + 0;
	    my $yr = substr ($data[$ix], 18, 2);
	    my $da = substr ($data[$ix], 20, 12);
	    $yr += 100 if $yr < 57;
	    my $ep = timegm (0, 0, 0, 1, 0, $yr) + ($da - 1) * 86400;
	    unless (!$opt->{all} and $opt->{start_epoch} ?
		    $ep > $opt->{end_epoch} || $ep <= $opt->{start_epoch} :
		    $ep > $now) {
		$tle{$id} ||= [];
		my @keys = $opt->{descending} ? (-$id, -$ep) : ($id, $ep);
		@keys = reverse @keys if $opt->{sort} eq 'epoch';
		push @{$tle{$id}}, [@keys, join '', @data];
		}
	    @data = ();
	    };
	}
    }

unless ($opt->{all} || $opt->{start_epoch}) {
    my $left = $opt->{last5} ? 5 : 1;
    foreach (values %tle) {splice @$_, $left}
    }
$content .= join '',
    map {$_->[2]}
    sort {$a->[0] <=> $b->[0] || $a->[1] <=> $b->[1]}
    map {@$_} values %tle;


$content or
    return HTTP::Response->new (RC_PRECONDITION_FAILED, NO_RECORDS);

my $resp = HTTP::Response->new (RC_OK, undef, undef, $content);
$self->{_content_type} = 'orbit';
$resp->push_header (pragma => 'spacetrack-type = orbit');
$self->_dump_headers ($resp) if $self->{dump_headers};
$resp;
}

=for html <a name="spacetrack"></a>

=item $resp = $st->spacetrack ($name_or_number);

This method downloads the given bulk catalog of orbital elements. If
the argument is an integer, it represents the number of the
catalog to download. Otherwise, it is expected to be the name of
the catalog, and whether you get a two-line or three-line dataset is
specified by the setting of the with_name attribute. The return is
the HTTP::Response object fetched. If an invalid catalog name is
requested, an HTTP::Response object is returned, with an appropriate
message and the error code set to RC_NOTFOUND from HTTP::Status
(a.k.a. 404). This will also happen if the HTTP get succeeds but we
do not get the expected content.

Note that when requesting spacetrack data sets by catalog number the
setting of the 'with_name' attribute is ignored.

Assuming success, the content of the response is the literal element
set requested. Yes, it comes down gzipped, but we unzip it for you.
See the synopsis for sample code to retrieve and print the 'special'
catalog in three-line format.

A list of valid names and brief descriptions can be obtained by calling
$st->names ('spacetrack'). If you have set the 'verbose' attribute true
(e.g. $st->set (verbose => 1)), the content of the error response will
include this list. Note, however, that this list does not determine what
can be retrieved; if Space Track adds a data set, it can still be
retrieved by number, even if it does not appear in the list by either
number or name. Similarly, if they remove a data set, being on the list
will not help. If they decide to renumber the data sets, retrieval by
name will become useless until I get the code updated. The numbers
correspond to the 'id=' portion of the URL for the dataset on the Space
Track web site

This method implicitly calls the login () method if the session cookie
is missing or expired. If login () fails, you will get the
HTTP::Response from login ().

If this method succeeds, a 'Pragma: spacetrack-type = orbit' header is
added to the HTTP::Response object returned.

=cut

sub spacetrack {
my $self = shift;
delete $self->{_content_type};
my $catnum = shift;
$catnum =~ m/\D/ and do {
    my $info = $catalogs{spacetrack}{$catnum} or
	return $self->_no_such_catalog (spacetrack => $catnum);
    $catnum = $info->{number};
    $self->{with_name} && $catnum++ unless $info->{special};
    };
my $resp = $self->_get ('perl/dl.pl', ID => $catnum);
# At this point, assuming we succeeded, we should have headers
# content-disposition: attachment; filename=the_desired_file_name
# content-type: application/force-download
# In the above, the_desired_file_name is (e.g.) something like
#   spec_interest_2l_2005_03_22_am.txt.gz

=begin comment

It is possible (e.g. 04-May-2007) to get the following instead:

<html>
<body><script type="text/javascript">
alert("There was a problem processing your request!\nPlease email admin@space-track.org
Requested file  doesn't exist");history.go(-1);
</script>
</body></html>

=end comment

=cut

$resp->is_success and do {
    my $content = $resp->content ();
    if ($content =~ m/<html>/) {
	if ($content =~ m/Requested file doesn't exist/i) {
	    $resp = HTTP::Response->new (RC_NOT_FOUND,
		"The file for catalog $catnum is missing.\n",
		undef, $content);
	} else {
	    $resp = HTTP::Response->new (RC_INTERNAL_SERVER_ERROR,
		"The file for catalog $catnum could not be retrieved.\n",
		undef, $content);
	}
    } else {
	$catnum and $resp->content (
	    Compress::Zlib::memGunzip ($resp->content));
	# SpaceTrack returns status 200 on a non-existent catalog
	# number, but whatever content they send back doesn't unzip, so
	# we catch it here.
	defined ($resp->content ())
	    or return $self->_no_such_catalog (spacetrack => $catnum);
	$resp->remove_header ('content-disposition');
	$resp->header (
	    'content-type' => 'text/plain',
##	    'content-length' => length ($resp->content),
	    );
	$self->_convert_content ($resp);
	$self->{_content_type} = 'orbit';
	$resp->push_header (pragma => 'spacetrack-type = orbit');
    }
    };
$resp;
}


####
#
#	Private methods.
#

#	_check_cookie looks for our session cookie. If it's found, it returns
#	the cookie's expiration time and sets the relevant attributes.
#	Otherwise it returns zero.

sub _check_cookie {
my $self = shift;
my ($cookie, $expir);
$expir = 0;
$self->{agent}->cookie_jar->scan (sub {
    $self->{dump_headers} > 1 and _dump_cookie ("_check_cookie:\n", @_);
    ($cookie, $expir) = @_[2, 8] if $_[4] eq DOMAIN &&
	$_[3] eq SESSION_PATH && $_[1] eq SESSION_KEY;
    });
$self->{dump_headers} and warn $expir ? <<eod : <<eod;
Session cookie: $cookie
Cookie expiration: @{[strftime '%d-%b-%Y %H:%M:%S', localtime $expir]} ($expir)
eod
Session cookie not found
eod
$self->{session_cookie} = $cookie;
$self->{cookie_expires} = $expir;
return $expir || 0;
}

#	_convert_content converts the content of an HTTP::Response
#	from crlf-delimited to lf-delimited.

{	# Begin local symbol block
my $lookfor = $^O eq 'MacOS' ? qr{\012|\015+} : qr{\r\n};
sub _convert_content {
my $self = shift;
local $/ = undef;	# Slurp mode.
foreach my $resp (@_) {
    my $buffer = $resp->content;
    # If we request a non-existent Space Track catalog number, we get
    # 200 OK but the unzipped content is undefined. We catch this before
    # we get this far, but the buffer check is left in in case something
    # else leaks through.
    defined $buffer or $buffer = '';
    $buffer =~ s|$lookfor|\n|gms;
    1 while ($buffer =~ s|^\n||ms);
    $buffer =~ s|\s+$||ms;
    $buffer .= "\n";
    $resp->content ($buffer);
    $resp->header (
	'content-length' => length ($buffer),
	);
    }
}
}	# End local symbol block.

#	_dump_cookie is intended to be called from inside the
#	HTTP::Cookie->scan method. The first argument is prefix text
#	for the dump, and the subsequent arguments are the arguments
#	passed to the scan method.
#	It dumps the contents of the cookie to STDERR via a warn ().
#	A typical session cookie looks like this:
#	    version => 0
#	    key => 'spacetrack_session'
#	    val => whatever
#	    path => '/'
#	    domain => 'www.space-track.org'
#	    port => undef
#	    path_spec => 1
#	    secure => undef
#	    expires => undef
#	    discard => 1
#	    hash => {}
#	The response to the login, though, has an actual expiration
#	time, which we take cognisance of.

use Data::Dumper;
{	# begin local symbol block
my @names = qw{version key val path domain port path_spec secure
	expires discard hash};
sub _dump_cookie {
local $Data::Dumper::Terse = 1;
my $prefix = shift;
$prefix and warn $prefix;
for (my $inx = 0; $inx < @names; $inx++) {
    warn "    $names[$inx] => ", Dumper ($_[$inx]);
    }
}
}	# end local symbol block


#	_dump_headers dumps the headers of the passed-in response
#	object.

sub _dump_headers {
my $self = shift;
my $resp = shift;
local $Data::Dumper::Terse = 1;
my $rqst = $resp->request;
$rqst = ref $rqst ? $rqst->as_string : "undef\n";
chomp $rqst;
warn "\nRequest:\n$rqst\nHeaders:\n",
    $resp->headers->as_string, "\nCookies:\n";
$self->{agent}->cookie_jar->scan (sub {
    _dump_cookie ("\n", @_);
    });
warn "\n";
}

#	_get gets the given path on the domain. Arguments after the
#	first are the CGI parameters. It checks the currency of the
#	session cookie, and executes a login if it deems it necessary.
#	The normal return is the HTTP::Response object from the get (),
#	but if a login was attempted and failed, the HTTP::Response
#	object from the login will be returned.

sub _get {
my $self = shift;
my $path = shift;
my $cgi = '';
while (@_) {
    my $name = shift;
    my $val = shift || '';
    $cgi .= "&$name=$val";
    }
$cgi and substr ($cgi, 0, 1) = '?';
{	# Single-iteration loop
    $self->{cookie_expires} > time () or do {
	my $resp = $self->login ();
	return $resp unless $resp->is_success;
	};
    my $resp = $self->{agent}->get ("http://@{[DOMAIN]}/$path$cgi");
    $self->_dump_headers ($resp) if $self->{dump_headers};
    return $resp unless $resp->is_success;
    local $_ = $resp->content;
    m/login\.pl/i and do {
	$self->{cookie_expires} = 0;
	redo;
	};
    return $resp;
    }	# end of single-iteration loop
}

#	Note: If we have a bad cookie, we get a success status, with
#	the text
# <?xml version="1.0" encoding="iso-8859-1"?>
# <!DOCTYPE html
#         PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
#          "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
# <html xmlns="http://www.w3.org/1999/xhtml" lang="en-US" xml:lang="en-US"><head><title>Space-Track</title>
# </head><body>
# <body bgcolor='#fffacd' text='#191970' link='#3333e6'>
#          <div align='center'><img src='http://www.space-track.org/icons/spacetrack_logo3.jpg' width=640 height=128 align='top' border=0></div>
# <h2>Error, Corrupted session cookie<br>
# Please <A HREF='login.pl'>LOGIN</A> again.<br>
# </h2>
# </body></html>
#	If this happens, it would be good to retry the login.


#	_handle_observing_list takes as input any number of arguments.
#	each is split on newlines, and lines beginning with a five-digit
#	number (with leading spaces allowed) are taken to specify the
#	catalog number (first five characters) and common name (the rest)
#	of an object. The resultant catalog numbers are run through the
#	retrieve () method. If called in scalar context, the return is
#	the resultant HTTP::Response object. In list context, the first
#	return is the HTTP::Response object, and the second is a reference
#	to a list of list references, each lower-level reference containing
#	catalog number and name.

sub _handle_observing_list {
my $self = shift;
my (@catnum, @data);

@_ = _parse_retrieve_args (@_) unless ref $_[0] eq 'HASH';
my $opt = shift;

foreach (map {split '\n', $_} @_) {
    s/\s+$//;
    my ($id) = m/^([\s\d]{5})/ or next;
    $id =~ m/^\s*\d+$/ or next;
    push @catnum, $id;
    push @data, [$id, substr $_, 5];
    }
my $resp = $self->retrieve ($opt, sort {$a <=> $b} @catnum);
if ($resp->is_success) {
    unless ($self->{_content_type}) {
	$self->{_content_type} = 'orbit';
	$resp->push_header (pragma => 'spacetrack-type = orbit');
	}
    $self->_dump_headers ($resp) if $self->{dump_headers};
    }
return wantarray ? ($resp, \@data) : $resp;
}

#	_mutate_attrib takes the name of an attribute and the new value
#	for the attribute, and does what its name says.

sub _mutate_attrib {$_[0]{$_[1]} = $_[2]}

#	_mutate_authen clears the session cookie and then sets the
#	desired attribute

sub _mutate_authen {
    $_[0]->set (session_cookie => undef, cookie_expires => 0);
    goto &_mutate_attrib;
}

#	_mutate_cookie sets the session cookie, in both the object and
#	the user agent's cookie jar.

sub _mutate_cookie {
$_[0]->{agent} && $_[0]->{agent}->cookie_jar
    and $_[0]->{agent}->cookie_jar->set_cookie (0, SESSION_KEY, $_[2],
	SESSION_PATH, DOMAIN, undef, 1, undef, undef, 1, {});
goto &_mutate_attrib;
}

sub _mutate_iridium_status_format {
croak "Error - Illegal status format '$_[2]'"
##    unless $_[2] eq 'kelso' || $_[2] eq 'mccants';
    unless $catalogs{iridium_status}{$_[2]};
$_[0]->{$_[1]} = $_[2];
}

#	_mutate_number croaks if the value to be set is not numeric.
#	Otherwise it sets the value. Only unsigned integers pass.

sub _mutate_number {
$_[2] =~ m/\D/ and croak <<eod;
Attribute $_[1] must be set to a numeric value.
eod
goto &_mutate_attrib;
}


#	_no_such_catalog takes as arguments a source and catalog name,
#	and returns the appropriate HTTP::Response object based on the
#	current verbosity setting.

my %no_such_lead = (
    celestrak => "No such CelesTrak catalog as '%s'.",
    spaceflight => "No such Manned Spaceflight catalog as '%s'.",
    spacetrack => "No such Space Track catalog as '%s'.",
    );
my %no_such_trail = (
    spacetrack => <<eod,
The Space Track data sets are actually numbered. The given number
corresponds to the data set without names; if you are requesting data
sets by number and want names, add 1 to the given number. When
requesting Space Track data sets by number the 'with_name' attribute is
ignored.
eod
);
sub _no_such_catalog {
my $self = shift;
my $source = lc shift;
my $catalog = shift;
$no_such_lead{$source} or return HTTP::Response->new (RC_NOT_FOUND,
	"No such data source as '$source'.\n");
my $lead = sprintf $no_such_lead{$source}, $catalog;
return HTTP::Response->new (RC_NOT_FOUND, "$lead\n")
    unless $self->{verbose};
my $resp = $self->names ($source);
return HTTP::Response->new (RC_NOT_FOUND,
    join '', "$lead Try one of:\n", $resp->content,
    $no_such_trail{$source} || ''
);
}

#	_parse_retrieve_args parses the retrieve() options off its
#	arguments, prefixes a reference to the resultant options
#	hash to the remaining arguments, and returns the resultant
#	list. If the first argument is a hash reference, it simply
#	returns its argument list, under the assumption that it
#	has already been called.

my @legal_retrieve_args = (descending => '(direction of sort)',
		'end_epoch=s' => 'date',
		last5 => '(ignored f -start_epoch or -end_epoch specified)',
		'sort=s' => "type ('catnum' or 'epoch', with 'catnum' the default)",
		'start_epoch=s' => 'date',
		);
sub _parse_retrieve_args {
unless (ref ($_[0]) eq 'HASH') {
    my %lgl = (@legal_retrieve_args, ref $_[0] eq 'ARRAY' ? @{shift @_} : ());
    my $opt = {};
    local @ARGV = @_;

    GetOptions ($opt, keys %lgl) or croak <<eod;
Error - Legal options are@{[map {(my $q = $_) =~ s/=.*//;
	"\n  -$q $lgl{$_}"} sort keys %lgl]}
with dates being either Perl times, or numeric year-month-day, with any
non-numeric character valid as punctuation.
eod

    $opt->{sort} ||= 'catnum';

    $opt->{sort} eq 'catnum' || $opt->{sort} eq 'epoch' or die <<eod;
Error - Illegal sort '$opt->{sort}'. You must specify 'catnum'
        (the default) or 'epoch'.
eod

    @_ = ($opt, @ARGV);
    }
@_;
}

#	$opt = _parse_retrieve_dates ($opt);

#	This subroutine looks for keys start_epoch and end_epoch in the
#	given option hash, parses them as YYYY-MM-DD (where the letters
#	are digits and the dashes are any non-digit punctuation), and
#	replaces those keys' values with a reference to a list
#	containing the output of timegm() for the given time. If only
#	one epoch is provided, the other is defaulted to provide a
#	one-day date range. If the syntax is invalid, we croak.
#
#	The return is the same hash reference that was passed in.

sub _parse_retrieve_dates {
my $opt = shift;
my $ctl = shift || {};

my $found;
foreach my $key (qw{end_epoch start_epoch}) {
    next unless $opt->{$key};
    $opt->{$key} !~ m/\D/ or
	$opt->{$key} =~ m/^(\d+)\D+(\d+)\D+(\d+)$/ and
	    $opt->{$key} = eval {timegm (0, 0, 0, $3, $2-1, $1)} or
	croak <<eod;
Error - Illegal date '$opt->{$key}'. Valid dates are a number
	(interpreted as a Perl date) or numeric year-month-day.
eod
    $found++;
    }

if ($found) {
    if ($found == 1) {
	$opt->{start_epoch} ||= $opt->{end_epoch} - 86400;
	$opt->{end_epoch} ||= $opt->{start_epoch} + 86400;
	}
    $opt->{start_epoch} <= $opt->{end_epoch} or croak <<eod;
Error - End epoch must not be before start epoch.
eod
    unless ($ctl->{perldate}) {
	foreach my $key (qw{start_epoch end_epoch}) {
	    $opt->{$key} = [gmtime ($opt->{$key})];
	    }
	}
    }

$opt;
}

#	_parse_search_args parses the search_*() options off its
#	arguments, prefixes a reference to the resultant options
#	hash to the remaining arguments, and returns the resultant
#	list. If the first argument is a hash reference, it simply
#	returns its argument list, under the assumption that it
#	has already been called.

my @legal_search_args = (
    'status=s' => q{('onorbit', 'decayed', or 'all')},
    'exclude=s@' => q{('debris', 'rocket', or 'debris,rocket')},
);
my %legal_search_exclude = map {$_ => 1} qw{debris rocket};
my %legal_search_status = map {$_ => 1} qw{onorbit decayed all};
sub _parse_search_args {
unless (ref ($_[0]) eq 'HASH') {
    ref $_[0] eq 'ARRAY' and my @extra = @{shift @_};
    @_ = _parse_retrieve_args ([@legal_search_args, @extra], @_);

##    my %lgl = (@legal_search_args, ref $_[0] eq 'ARRAY' ? @{shift @_} : ());
##    my $opt = {};
##    local @ARGV = @_;

##    GetOptions ($opt, keys %lgl) or croak <<eod;
##Error - Legal options are@{[map {(my $q = $_) =~ s/=.*//;
##	"\n  -$q $lgl{$_}"} sort keys %lgl]}
##eod
    my $opt = $_[0];
    $opt->{status} ||= 'all',
    $legal_search_status{$opt->{status}} or croak <<eod;
Error - Illegal status '$opt->{status}'. You must specify one of
        @{[join ', ', map {"'$_'"} sort keys %legal_search_status]}
eod
    $opt->{exclude} ||= [];
    $opt->{exclude} = [map {split ',', $_} @{$opt->{exclude}}];
    foreach (@{$opt->{exclude}}) {
	$legal_search_exclude{$_} or croak <<eod;
Error - Illegal exclusion '$_'. You must specify one or more of
        @{[join ', ', map {"'$_'"} sort keys %legal_search_exclude]}
eod
	}
##    @_ = ($opt, @ARGV);
    }
@_;
}

#	_post is just like _get, except for the method used. DO NOT use
#	this method in the login () method, or you get a bottomless
#	recursion.

sub _post {
my $self = shift;
my $path = shift;
{	# Single-iteration loop
    $self->{cookie_expires} > time () or do {
	my $resp = $self->login ();
	return $resp unless $resp->is_success;
	};
    my $url = $self->{debug_url} || "http://@{[DOMAIN]}/$path";
    my $resp = $self->{agent}->post ($url, [@_]);
    $self->_dump_headers ($resp) if $self->{dump_headers};
    return $resp unless $resp->is_success && !$self->{debug_url};
    local $_ = $resp->content;
    m/login\.pl/i and do {
	$self->{cookie_expires} = 0;
	redo;
	};
    return $resp;
    }	# end of single-iteration loop
}

#	_search wraps the specific search functions. It is called
#	O-O style, with the first argument (after $self) being a
#	reference to the code that actually requests the data from
#	the server. This code takes two arguments ($self and $name,
#	the latter being the thing to search for), and returns the
#	HTTP::Response object from the request.
#
#	The referenced code is given three arguments: $self, the name
#	of the object to search for, and the option hash. If the
#	referenced code needs the name parsed further, it must do so
#	itself, returning undef if the parse fails.


sub _search_generic {
my $self = shift;
my $poster = shift;
delete $self->{_content_type};

@_ = _parse_retrieve_args (@_) unless ref $_[0] eq 'HASH';
my $opt = shift;

@_ or return HTTP::Response->new (RC_PRECONDITION_FAILED, NO_OBJ_NAME);
my $p = Astro::SpaceTrack::Parser->new ();

my @table;
my %id;
foreach my $name (@_) {
    defined (my $resp = $poster->($self, $name, $opt)) or next;
    return $resp unless $resp->is_success && !$self->{debug_url};
    my $content = $resp->content;
    next if $content =~ m/No results found/i;
    my @this_page = @{$p->parse_string (table => $content)};
    my @data = @{$this_page[0]};
    foreach my $row (@data) {
	pop @$row; pop @$row;
	}
    if (@table) {shift @data} else {push @table, shift @data};
    foreach my $row (@data) {
	push @table, $row unless $id{$row->[0]}++;
	}
    }
my $resp = $self->retrieve ($opt, sort {$a <=> $b} keys %id);
wantarray ? ($resp, \@table) : $resp;
}


#	_source takes a filename, and returns the contents of the file
#	as a list. It dies if anything goes wrong.

sub _source {
my $self = shift;
wantarray or die <<eod;
Error - _source () called in scalar or no context. This is a bug.
eod
my $fn = shift or die <<eod;
Error - No source file name specified.
eod
my $fh = FileHandle->new ("<$fn") or die <<eod;
Error - Failed to open source file '$fn'.
        $!
eod
return <$fh>;
}

1;

__END__

=back

=head2 Attributes

The following attributes may be modified by the user to affect the
operation of the Astro::SpaceTrack object. The data type of each is
given in parentheses after the attribute name.

Boolean attributes are typically set to 1 for true, and 0 for false.

=over

=item addendum (text)

This attribute specifies text to add to the output of the banner()
method.

The default is an empty string.

=item banner (boolean)

This attribute specifies whether or not the shell() method should emit
the banner text on invocation.

The default is true (i.e. 1).

=item cookie_expires (number)

This attribute specifies the expiration time of the cookie. You should
only set this attribute with a previously-retrieved value, which
matches the cookie.

=item direct (boolean)

This attribute specifies that orbital elements should be fetched
directly from the redistributer if possible. At the moment the only
methods affected by this are celestrak() and spaceflight().

The default is false (i.e. 0).

=item fallback (boolean)

This attribute specifies that orbital elements should be fetched from
the redistributer if the original source is offline. At the moment the
only method affected by this is celestrak().

The default is false (i.e. 0).

=item filter (boolean)

If true, this attribute specifies that the shell is being run in filter
mode, and prevents any output to STDOUT except orbital elements -- that
is, if I found all the places that needed modification.

The default is false (i.e. 0).

=item iridium_status_format (string)

This attribute specifies the format of the data returned by the
L<iridium_status> method. Valid values are 'kelso' and 'mccants'.
See that method for more information.

The default is 'mccants' for historical reasons, but 'kelso' is probably
preferred.

=item max_range (number)

This attribute specifies the maximum size of a range of NORAD IDs to be
retrieved. Its purpose is to impose a sanity check on the use of the
range functionality.

The default is 500.

=item password (text)

This attribute specifies the Space-Track password.

The default is an empty string.

=item session_cookie (text)

This attribute specifies the session cookie. You should only set it
with a previously-retrieved value.

The default is an empty string.

=item url_iridium_status_kelso (text)

This attribute specifies the location of the celestrak.com Iridium
information. You should normally not change this, but it is provided
so you will not be dead in the water if Dr. Kelso needs to re-arrange
his web site.

The default is 'http://celestrak.com/SpaceTrack/query/iridium.txt'

=item url_iridium_status_mccants (text)

This attribute specifies the location of Mike McCants' Iridium status
page. You should normally not change this, but it is provided so you
will not be dead in the water if Mr. McCants needs to change his
ISP or re-arrange his web site.

The default is 'http://www.io.com/~mmccants/tles/iridium.html'

=item username (text)

This attribute specifies the Space-Track username.

The default is an empty string.

=item verbose (boolean)

This attribute specifies verbose error messages.

The default is false (i.e. 0).

=item webcmd (string)

This attribute specifies a system command that can be used to launch
a URL into a browser. If specified, the 'help' command will append
a space and the search.cpan.org URL for the documentation for this
version of Astro::SpaceTrack, and spawn that command to the operating
system. You can use 'open' under Mac OS X, and 'start' under Windows.
Anyone else will probably need to name an actual browser.

=item with_name (boolean)

This attribute specifies whether the returned element sets should
include the common name of the body (three-line format) or not
(two-line format). It is ignored if the 'direct' attribute is true;
in this case you get whatever the redistributer provides.

The default is false (i.e. 0).

=back

=head1 ENVIRONMENT

The following environment variables are recognized by Astro::SpaceTrack.

=head2 SPACETRACK_OPT

If environment variable SPACETRACK_OPT is defined at the time an
Astro::SpaceTrack object is instantiated, it is broken on spaces,
and the result passed to the set command.

If you specify username or password in SPACETRACK_OPT and you also
specify SPACETRACK_USER, the latter takes precedence, and arguments
passed explicitly to the new () method take precedence over both.

=head2 SPACETRACK_USER

If environment variable SPACETRACK_USER is defined at the time an
Astro::SpaceTrack object is instantiated, the username and password
will be initialized from it. The value of the environment variable
should be the username followed by a slash ("/") and the password.

An explicit username and/or password passed to the new () method
overrides the environment variable, as does any subsequently-set
username or password.

=head1 EXECUTABLES

A couple specimen executables are included in this distribution:

=head2 SpaceTrack

This is just a wrapper for the shell () method.

=head2 SpaceTrackTk

This provides a Perl/Tk interface to Astro::SpaceTrack.

=head1 BUGS

This software is essentially a web page scraper, and relies on the
stability of the user interface to Space Track. The Celestrak
portion of the functionality relies on the presence of .txt files
named after the desired data set residing in the expected location.
The Human Space Flight portion of the functionality relies on the
stability of the layout of the relevant web pages.

This software has not been tested under a HUGE number of operating
systems, Perl versions, and Perl module versions. It is rather likely,
for example, that the module will die horribly if run with an
insufficiently-up-to-date version of LWP or HTML::Parser.

=head1 MODIFICATIONS

 0.003 26-Mar-2005 T. R. Wyant
   Initial release to CPAN.
 0.004 30-Mar-2005 T. R. Wyant
   Added file method, for local observing lists.
   Changed Content-Type header of spacetrack () response
     to text/plain. Used to be text/text.
   Manufactured pristine HTTP::Response for successsful
     login call.
   Added source method, for passing the contents of a file
     to the shell method
   Skip username and password prompts, and login and
     retrieval tests if environment variable
     AUTOMATED_TESTING is true and environment variable
     SPACETRACK_USER is undefined.
 0.005 02-Apr-2005 T. R. Wyant
   Proofread and correct POD.
 0.006 08-Apr-2005 T. R. Wyant
   Added search_id method.
   Made specimen scripts into installable executables.
   Add pseudo-tilde expansion to shell method.
 0.007 15-Apr-2005 T. R. Wyant
   Document attributes (under set() method)
   Have login return actual failure on HTTP error. Used
     to return 401 any time we did not get the cookie.
 0.008 19-Jul-2005 T. R. Wyant
   Consolidate dump code.
   Have file() method take open handle as arg.
   Modify cookie check.
   Add mutator, accessor for cookie_expires,
     session_cookie.
 0.009 17-Sep-2005 T. R. Wyant
   Only require Term::ReadLine and create interface if
   the shell() method actually called.
 0.010 14-Oct-2005 T. R. Wyant
   Added the 'direct' attribute, to fetch elements
   directly from celestrak. And about time, too.
 0.011 30-Oct-2005 T. R. Wyant
   Added 'Pragma: spacetrack-type = orbit' header to
   the response for those methods that return orbital
   elements, if the request in fact succeeded.
   Added content_type() method to check for the above.
   Played the CPANTS game.
   Added "All rights reserved." to copyright statement.
 0.012 04-Nov-2005 T. R. Wyant
   Added support for number ranges in retrieve(), to
   track support for these on www.space-track.org.
   Added max_range attribute for sanity checking.
 0.013 21-Nov-2005 T. R. Wyant
   Added spaceflight() method.
   Added "All rights reserved." to banner() output.
   Spiffed up the documentation.
 0.014 28-Jan-2006 T. R. Wyant
   Added filter attribute.
   Jocky the Term::ReadLine code yet again.
 0.015 01-Feb-2006 T. R. Wyant
   Added webcmd attribute, and use it in help().
 0.016 11-Feb-2006 T. R. Wyant
   Added content types 'help' and 'get', so -filter
   does not supress output.
   Added iridium_status, & content type 'iridium-status'.
 0.017 27-Apr-2006 T. R. Wyant
   Added retrieve() options.
 0.018 30-May-2006 T. R. Wyant
   Added amsat() method.
 0.019 11-Jun-2006 T. R. Wyant
   Added the retrieve() options to celestrak() and file().
 0.020 01-Jul-2006 T. R. Wyant
   Add the retrieve() qualifiers to spaceflight().
   Add the attribute_names() method.
   Tweak docs, correct spelling.
 0.021 13-Jul-2006 T. R. Wyant
   Add -all qualifier to spaceflight().
   Add search_date().
 0.022 20-Jul-2006 T. R. Wyant
    Documentation corrections.
 0.023 08-Sep-2006 T. R. Wyant
    Added spaceflight() pseudo-catalogs 'iss' and 'station'.
    Have spaceflight() return NO_RECORDS on failure, not
      NO_CAT_ID.
    Have attribute_names() return list ref in scalar context.
    Add attribute iridium_status_format; have iridium_status()
      use this to decide who to access and what format to
      return, including support for the new Celestrak status
      information.
    Have iridium_status() return parsed data with 'portable'
      status if called in list context.
 0.024 12-Sep-2006 T. R. Wyant
    No substantive changes to this module, but retracted
      t/pod_spelling.t, and tried to make Build.PL work with
      ActiveState's build system.
 0.025 19-Oct-2006 T. R. Wyant
    Recognize new Kelso Iridium status '[+]' = working.
    Make Makefile.PL not run Build.PL with old MakeMaker.
    Retract kluge to Build.PL, which is no longer needed.
 0.026 06-Nov-2006 T. R. Wyant
    New location for Mike McCants' Iridium status page.
    New attributes url_iridium_status_kelso and
      url_iridium_status_mccants so users are not dead
      in the water if this happens again.
 0.027 30-Jan-2007 T. R. Wyant
    Add ability to search by on-orbit status ('onorbit',
      'decayed', or 'all'), and to exclude 'debris' and
      'rocket' (bodies).
    Tweak docs.
    Update copyright.
 0.028 15-May-2007 T. R. Wyant
    Interpret missing spacetrack() catalog as a failure,
      even though the request succeeds.
    Ditto missing Space Track retrieve() data.
    Add 'fallback' attribute to cause celestrak() to fall
      back to using Celestrak data if Space Track data
      are not available.
    Clear session cookie when username or password change.
 0.029 13-Oct-2007 T. R. Wyant
     Add Celestrak galileo and sbas data set names to catalog.
     Document celestrak data set names, or at least how to get them and
	 in general how they are formed.
     Trap and error out on invalid spacetrack() data set numbers.
     Add data set numbers to spacetrack() help.
     Document how to get the current spacetrack data set names and
	 numbers, and what happens if they renumber.
     Trap case where 'get' is called without an argument.
     Have 'shell' method interpret 'show' as 'get', and special-case
	 'get' without arguments to display all attributes. Document
	 this.

=head1 ACKNOWLEDGMENTS

The author wishes to thank Dr. T. S. Kelso of
L<http://celestrak.com/> and the staff of L<http://www.space-track.org/>
(whose names are unfortunately unknown to me) for their co-operation,
assistance and encouragement.

=head1 AUTHOR

Thomas R. Wyant, III (F<wyant at cpan dot org>)

=head1 COPYRIGHT

Copyright 2005, 2006, 2007 by Thomas R. Wyant, III
(F<wyant at cpan dot org>). All rights reserved.

=head1 LICENSE

This module is free software; you can use it, redistribute it
and/or modify it under the same terms as Perl itself.

The data obtained by this module is provided subject to the Space
Track user agreement (L<http://www.space-track.org/perl/user_agreement.pl>).

This software is provided without any warranty of any kind, express or
implied. The author will not be liable for any damages of any sort
relating in any way to this software.

=cut
