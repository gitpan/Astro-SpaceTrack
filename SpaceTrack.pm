#!/usr/bin/perl

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
a named data set, and then queries L<http://www.space-track.org> for
the orbital elements of the objects in the data set.

There is no provision for the retrieval of historical data.

Nothing is exported by default, but the shell method/subroutine
can be exported if you so desire.

=head2 Methods

The following methods should be considered public:

=over 4

=cut

use strict;
use warnings;

use 5.006;

package Astro::SpaceTrack;

use base qw{Exporter};
use vars qw{$VERSION @EXPORT_OK};

$VERSION = 0.007;
@EXPORT_OK = qw{shell};

use Astro::SpaceTrack::Parser;
use Carp;
use Compress::Zlib ();
use Config;
use FileHandle;
use HTTP::Response;	# Not in the base, but comes with LWP.
use HTTP::Status qw{RC_NOT_FOUND RC_OK RC_PRECONDITION_FAILED
	RC_UNAUTHORIZED RC_INTERNAL_SERVER_ERROR};	# Not in the base, but comes with LWP.
use LWP::UserAgent;	# Not in the base.
use Text::ParseWords;
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

my ($read, $print);
BEGIN {
my $out;
my $prompt = 'SpaceTrack> ';
eval {
    require Term::ReadLine;
    my $rdln = Term::ReadLine->new ('SpaceTrack orbital element access');
    $out = $rdln->OUT || \*STDOUT;
    $read = sub {$rdln->readline ($prompt)};
    };

$out ||= \*STDOUT;
$read ||= sub {print $out $prompt; <STDIN>};
$print = sub {
	my $hndl = UNIVERSAL::isa ($_[0], 'FileHandle') ? shift : $out;
	print $hndl @_};
}


my %catalogs = (	# Catalog names (and other info) for each source.
    celestrak => {
	'tle-new' => {name => q{Last 30 Days' Launches}},
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
    dump_headers => \&_mutate_attrib,	# Dump all HTTP headers. Undocumented and unsupported.
    password => \&_mutate_attrib,
    username => \&_mutate_attrib,
    verbose => \&_mutate_attrib,
    with_name => \&_mutate_attrib,
    );
# Maybe I really want a cookie_file attribute, which is used to do
# $self->{agent}->cookie_jar ({file => $self->{cookie_file}, autosave => 1}).
# We'll want to use a false attribute value to pass an empty hash. Going to
# this may imply modification of the new () method where the cookie_jar is
# defaulted and the session cookie's age is initialized.


=item $st = Astro::SpaceTrack->new ( ... )

This method instantiates a new Space-Track accessor object. If any
arguments are passed, the set () method is called on the new object,
and passed the arguments given.

Proxies are taken from the environment if defined. See the ENVIRONMENT
section of the Perl LWP documentation for more information on how to
set these up.

=cut

sub new {
my $class = shift;
$class = ref $class if ref $class;

my $self = {
    agent => LWP::UserAgent->new (),
    banner => 1,	# shell () displays banner if true.
    password => undef,	# Login password.
    username => undef,	# Login username.
    verbose => undef,	# Verbose error messages for catalogs.
    with_name => undef,	# True to retrieve three-line element sets.
    };
bless $self, $class;

$self->{agent}->env_proxy;

$ENV{SPACETRACK_OPT} and
    $self->set (grep {defined $_} split '\s+', $ENV{SPACETRACK_OPT});

$ENV{SPACETRACK_USER} and do {
    my ($user, $pass) = split '/', $ENV{SPACETRACK_USER}, 2;
    $self->set (username => $user, password => $pass);
    };

@_ and $self->set (@_);

$self->{agent}->cookie_jar ({})
    unless $self->{agent}->cookie_jar;

$self->{cookie_expires} = $self->_cookie_expiration ();

return $self;
}


=item $resp = banner ();

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

Copyright 2005 T. R. Wyant (wyant at cpan dot org)

This module is free software; you can use it, redistribute it
and/or modify it under the same terms as Perl itself.
@{[$self->{addendum} || '']}
eod
}


=item $resp = $st->celestrak ($name);

This method takes the name of a Celestrak data set and returns an
HTTP::Response object whose content is the relevant element sets.
If called in list context, the first element of the list is the
aforementioned HTTP::Response object, and the second element is a
list reference to list references  (i.e. a list of lists). Each
of the list references contains the catalog ID of a satellite or
other orbiting body and the common name of the body.

This method implicitly calls the login () method if the session cookie
is missing or expired. If login () fails, you will get the
HTTP::Response from login ().

=cut

{	# Local symbol block.

my %valid_type = ('text/plain' => 1, 'text/text' => 1);

sub celestrak {
my $self = shift;
my $name = shift;
my $resp = $self->{agent}->get ("http://celestrak.com/SpaceTrack/query/$name.txt");
return $self->_no_such_catalog (celestrak => $name)
    if $resp->code == RC_NOT_FOUND;
return $resp unless $resp->is_success;
return $self->_no_such_catalog (celestrak => $name)
    unless $valid_type{lc $resp->header ('Content-Type')};
$self->_convert_content ($resp);
return $self->_handle_observing_list ($resp->content)
}

}	# End local symbol block.

=item $resp = $st->file ($name)

This method takes the name of an observing list file and returns an
HTTP::Response object whose content is the relevant element sets.
If called in list context, the first element of the list is the
aforementioned HTTP::Response object, and the second element is a
list reference to list references  (i.e. a list of lists). Each
of the list references contains the catalog ID of a satellite or
other orbiting body and the common name of the body.

This method implicitly calls the login () method if the session cookie
is missing or expired. If login () fails, you will get the
HTTP::Response from login ().

The observing list file is (how convenient!) in the Celestrak format,
with the first five characters of each line containing the object ID,
and the rest containing a name of the object. Lines whose first five
characters do not look like a right-justified number will be ignored.

=cut

sub file {
my $self = shift;
my $name = shift;
-e $name or return HTTP::Response->new (RC_NOT_FOUND, "Can't find file $name");
my $fh = FileHandle->new ($name) or
    return HTTP::Response->new (RC_INTERNAL_SERVER_ERROR, "Can't open $name: $!");
local $/;
$/ = undef;
return $self->_handle_observing_list (<$fh>)
}


=item $resp = $st->get (attrib)

This method returns an HTTP::Response object whose content is the value
of the given attribute. If called in list context, the second element
of the list is just the value of the attribute, for those who don't want
to winkle it out of the response object. We croak on a bad attribute name.

Since we currently have no read-only attributes, see the set() documentation
for what you can get().

=cut

sub get {
my $self = shift;
my $name = shift;
croak "Attribute $name may not be set. Legal attributes are ",
	join (', ', sort keys %mutator), ".\n"
    unless $mutator{$name};
my $resp = HTTP::Response->new (RC_OK, undef, undef, $self->{$name});
return wantarray ? ($resp, $self->{$name}) : $resp;
}


=item $resp = $st->help ()

This method exists for the convenience of the shell () method. It
always returns success, with the content being whatever it's
convenient (to the author) to include.

=cut

sub help {
HTTP::Response->new (RC_OK, undef, undef, <<eod);
The following commands are defined:
  celestrak name
    Retrieves the named catalog of IDs from Celestrak, and the
    corresponding orbital elements from Space Track.
  exit (or bye)
    Terminate the shell. End-of-file also works.
  file filename
    Retrieve the catalog IDs given in the named file (one per
    line, with the first five characters being the ID).
  get
    Get the value of a single attribute.
  help
    Display this help text.
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
      banner = false to supress the shell () banner;
      password = the Space-Track password;
      username = the Space-Track username;
      verbose = true for verbose catalog error messages;
      with_name = true to retrieve common names as well.
  source filename
    Executes the contents of the given file as shell commands.
  spacetrack name
    Retrieves the named catalog of orbital elements from
    Space Track.
The shell supports a pseudo-redirection of standard output,
using the usual Unix shell syntax (i.e. '>output_file').
eod
}


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
@_ and $self->set (@_);
$self->{username} && $self->{password} or
    return HTTP::Response->new (
	RC_PRECONDITION_FAILED, NO_CREDENTIALS);

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

($self->{cookie_expires} = $self->_cookie_expiration ()) > time ()
    or return HTTP::Response->new (RC_UNAUTHORIZED, LOGIN_FAILED);
HTTP::Response->new (RC_OK, undef, undef, "Login successful.\n");
}


=item $resp = $st->names (source)

This method retrieves the names of the catalogs for the given source,
either 'celestrak' or 'spacetrack', in the content of the given
HTTP::Response object. In list context, you also get a reference to
a list of two-element lists; each inner list contains the description
and the catalog name (suitable for inserting into a Tk Optionmenu).

=cut

sub names {
my $self = shift;
my $name = lc shift;
$catalogs{$name} or return HTTP::Response (
	RC_NOT_FOUND, "Data source '$name' not found.");
my $src = $catalogs{$name};
my @list;
foreach my $cat (sort keys %$src) {
    push @list, "$cat: $src->{$cat}{name}\n";
    }
my $resp = HTTP::Response->new (RC_OK, undef, undef, join ('', @list));
return $resp unless wantarray;
@list = ();
foreach my $cat (sort {$src->{$a}{name} cmp $src->{$b}{name}} keys %$src) {
    push @list, [$src->{$cat}{name}, $cat];
    }
return ($resp, \@list);
}


=item $resp = $st->retrieve (number ...)

This method retrieves the latest element set for each of the given
catalog numbers. Non-numeric catalog numbers are ignored, as are
(at a later stage) numbers that don't actually represent a satellite.

This method implicitly calls the login () method if the session cookie
is missing or expired. If login () fails, you will get the
HTTP::Response from login ().

=cut

sub retrieve {
my $self = shift;
@_ = grep {m/^\d+$/} @_;
@_ or return HTTP::Response->new (RC_PRECONDITION_FAILED, NO_CAT_ID);
my $content = '';
local $_;
my $resp;
while (@_) {
    my @batch = splice @_, 0, 50;
    $resp = $self->_post ('perl/id_query.pl',
	ids => "@batch",
	timeframe => 'latest',
	common_name => $self->{with_name} ? 'yes' : '',
	sort => 'catnum',
	descending => '',	# or 'yes'
	ascii => 'yes',		# or ''
	_sessionid => '',
	_submitted => 1,
	);
    return $resp unless $resp->is_success;
    $_ = $resp->content;
    next if m/No records found/i;
    s|</pre>.*||ms;
    s|.*<pre>||ms;
    s|^\n||ms;
    $content .= $_;
    }
$content or return HTTP::Response->new (RC_NOT_FOUND, NO_RECORDS);
$resp->content ($content);
$self->_convert_content ($resp);
$resp;
}


=item $resp = $st->search_id (id ...)

This method searches the database for objects having the given
international IDs. The international ID is the last two digits
of the launch year (in the range 1957 through 2056), the
three-digit sequence number of the launch within the year (with
leading zeroes as needed), and the piece (A through ZZ, with A
typically being the payload). You can omit the piece and get all
pieces of that launch, or omit both the piece and the launch
number and get all launches for the year. There is no
mechanism to restrict the search to a given date range, on-orbit
status, or to filter out debris or rocket bodies.

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

=cut

sub search_id {
my $self = shift;
my $p = Astro::SpaceTrack::Parser->new ();
@_ or return HTTP::Response->new (RC_PRECONDITION_FAILED, NO_OBJ_NAME);

my @table;
my %id;
foreach my $name (@_) {
# Note that the only difference between this and search_name is
# the code from here vvvvvvvv
    my ($year, $number, $piece) =
	$name =~ m/^(\d\d)(\d{3})?([[:alpha:]])?$/ or next;
    $year += $year < 57 ? 2000 : 1900;
    my $resp = $self->_post ('perl/launch_query.pl',
	launch_year => $year,
	launch_number => $number || '',
	piece => uc ($piece || ''),
	status => 'all',	# or 'onorbit' or 'decayed'.
##	exclude => '',		# or 'debris' or 'rocket' or both.
	_sessionid => '',
	_submit => 'submit',
	_submitted => 1,
	);
# to here ^^^^^^^^^^^^^^^^
    return $resp unless $resp->is_success;
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
my $resp = $self->retrieve (sort {$a <=> $b} keys %id);
wantarray ? ($resp, \@table) : $resp;
}

=item $resp = $st->search_name (name ...)

This method searches the database for the named objects. Matches
are case-insensitive and all matches are returned. There is no
mechanism to restrict the search to a given date range, on-orbit
status, or to filter out debris or rocket bodies.

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

=cut

sub search_name {
my $self = shift;
my $p = Astro::SpaceTrack::Parser->new ();
@_ or return HTTP::Response->new (RC_PRECONDITION_FAILED, NO_OBJ_NAME);

my @table;
my %id;
foreach my $name (@_) {
    my $resp = $self->_post ('perl/name_query.pl',
	name => $name,
	launch_year_start => 1957,
	launch_year_end => (gmtime)[5] + 1900,
	status => 'all',	# or 'onorbit' or 'decayed'.
##	exclude => '',		# or 'debris' or 'rocket' or both.
	_sessionid => '',
	_submit => 'Submit',
	_submitted => 1,
	);
    return $resp unless $resp->is_success;
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
my $resp = $self->retrieve (sort {$a <=> $b} keys %id);
wantarray ? ($resp, \@table) : $resp;
}


=item $st->set ( ... )

This is the mutator method for the object. It can be called explicitly,
but other methods as noted may call it implicitly also. It croaks if
you give it an odd number of arguments, or if given an attribute that
either does not exist or cannot be set.

For the convenience of the shell method, we return a HTTP::Response
object with a success status if all goes well. But if we encounter
an error we croak.

The following attributes may be set:

 addendum text
   specifies text to add to the output of the banner() method.
 banner boolean
   specifies whether or not the shell() method should emit the banner
   text on invocation. True by default.
 password text
   specifies the Space-Track password.
 username text
   specifies the Space-Track username.
 verbose boolean
   specifies verbose error messages. False by default.
 with_name boolean
   specifies whether the returned element sets should include the
   common name of the body (three-line format) or not (two-line
   format). False by default.

=cut

sub set {
my $self = shift;
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


=item $st->shell ()

This method implements a simple shell. Any public method name except
'new' or 'shell' is a command, and its arguments if any are parameters.
We use Text::ParseWords to parse the line, and blank lines or lines
beginning with a hash mark ('#') are ignored. Input is via
Term::ReadLine if that's available. If not, we do the best we can.

We also recognize 'bye' and 'exit' as commands.

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

sub shell {
my $self = shift if UNIVERSAL::isa $_[0], __PACKAGE__;
$self ||= Astro::SpaceTrack->new (addendum => <<eod);

'help' gets you a list of valid commands.
eod

$read && $print or croak "Sorry, no I/O routines available";
unshift @_, 'banner' if $self->{banner};
while (defined (my $buffer = @_ ? shift : $read->())) {

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
    my $rslt = eval {$self->$verb (@args)};
    $@ and do {warn $@; next; };
    if ($rslt->is_success) {
	$print->(@fh, $rslt->content);
	}
      else {
	$print->($rslt->status_line);
	}
    $print->("\n");
    }
$print->("\n");
}


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


=item $resp = $st->spacetrack ($name_or_number);

This method downloads the given bulk catalog of orbital elements. If
the argument is an integer, it represents the number of the
catalog to download. Otherwise, it is expected to be the name of
the catalog, and whether you get a two-line or three-line dataset is
specified by the setting of the with_name attribute. The return is
the HTTP::Response object fetched. If an invalid catalog name is
requested, an HTTP::Response object is returned, with an appropriate
message and the error code set to RC_NOTFOUND from HTTP::Status
(a.k.a. 404).

Assuming success, the content of the response is the literal element
set requested. Yes, it comes down gzipped, but we unzip it for you.
See the synopsis for sample code to retrieve and print the 'special'
catalog in three-line format.

This method implicitly calls the login () method if the session cookie
is missing or expired. If login () fails, you will get the
HTTP::Response from login ().

=cut

sub spacetrack {
my $self = shift;
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

$resp->is_success and do {
    $catnum and $resp->content (
	Compress::Zlib::memGunzip ($resp->content));
    $resp->remove_header ('content-disposition');
    $resp->header (
	'content-type' => 'text/plain',
##	'content-length' => length ($resp->content),
	);
    $self->_convert_content ($resp);
    };
$resp;
}


####
#
#	Private methods.
#

#	_convert_content converts the content of an HTTP::Response
#	from crlf-delimited to lf-delimited.

{	# Begin local symbol block
my $lookfor = $^O eq 'MacOS' ? qr{\012|\015+} : qr{\r\n};
sub _convert_content {
my $self = shift;
local $/;
$/ = undef;	# Slurp mode.
foreach my $resp (@_) {
    my $buffer = $resp->content;
##print STDERR "Debug _convert_content: first is ", ord (substr ($buffer, 0, 1)), "\n";
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

#	_cookie_expiration checks the cookie jar for the session cookie.
#	If it exists, it returns the expiration time (which may already
#	have passed). Otherwise it returns 0.

sub _cookie_expiration {
my $self = shift;
my $expir = 0;
$self->{agent}->cookie_jar->scan (sub {
    $expir = $_[8] if $_[4] eq DOMAIN && $_[3] eq SESSION_PATH &&
	$_[1] eq SESSION_KEY});
return $expir;
}

#	_get gets the given path on the domain. Arguments after the
#	first are the CGI parameters. It checks the currency of the
#	session cookie, and executes a login if it deems it necessary.
#	The normal return is the HTTP::Response object from the get (),
#	but if a login was attempted and failed, the HTTP::Response
#	object from the login will be returned.

sub _get {
my $self = shift;
$self->{cookie_expires} > time () or do {
    my $resp = $self->login ();
    return $resp unless $resp->is_success;
    };
my $path = shift;
my $cgi = '';
while (@_) {
    my $name = shift;
    my $val = shift || '';
    $cgi .= "&$name=$val";
    }
$cgi and substr ($cgi, 0, 1) = '?';
my $resp = $self->{agent}->get ("http://@{[DOMAIN]}/$path$cgi");
$resp->is_success and do {
    my $content = $resp->content;
    };
warn $resp->headers->as_string if $self->{dump_headers};
$resp;
}

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
foreach (map {split '\n', $_} @_) {
    s/\s+$//;
    my ($id) = m/^([\s\d]{5})/ or next;
    $id =~ m/^\s*\d+$/ or next;
    push @catnum, $id;
    push @data, [$id, substr $_, 5];
    }
my $resp = $self->retrieve (sort {$a <=> $b} @catnum);
return wantarray ? ($resp, \@data) : $resp;
}

#	_mutate_attrib takes the name of an attribute and the new value
#	for the attribute, and does what its name says.

sub _mutate_attrib {$_[0]{$_[1]} = $_[2]}

#	_no_such_catalog takes as arguments a source and catalog name,
#	and returns the appropriate HTTP::Response object based on the
#	current verbosity setting.

my %no_such_lead = (
    celestrak => "No such CelesTrak catalog as '%s'.",
    spacetrack => "No such Space Track catalog as '%s'.",
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
    join '', "$lead Try one of:\n", $resp->content);
}

#	_post is just like _get, except for the method used. DO NOT use
#	this method in the login () method, or you get a bottomless
#	recursion.

sub _post {
my $self = shift;
$self->{cookie_expires} > time () or do {
    my $resp = $self->login ();
    return $resp unless $resp->is_success;
    };
my $path = shift;
my $resp = $self->{agent}->post ("http://@{[DOMAIN]}/$path", [@_]);
warn $resp->headers->as_string if $self->{dump_headers};
$resp;
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
     to return 401 any time we didn't get the cookie.

=head1 ACKNOWLEDGMENTS

The author wishes to thank Dr. T. S. Kelso of
L<http://celestrak.com/> and the staff of L<http://www.space-track.org/>
(whose names are unfortunately unknown to me) for their co-operation, assistance and
encouragement.

=head1 AUTHOR

Thomas R. Wyant, III (F<wyant at cpan dot org>)

=head1 COPYRIGHT

Copyright 2005 by Thomas R. Wyant, III
(F<wyant at cpan dot org>)

This module is free software; you can use it, redistribute it
and/or modify it under the same terms as Perl itself.

The data obtained by this module is provided subject to the Space
Track user agreement (L<http://www.space-track.org/perl/user_agreement.pl>).

This software is provided without any warranty of any kind, express or
implied. The author will not be liable for any damages of any sort
relating in any way to this software.

=cut
