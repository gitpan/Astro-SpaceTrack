package main;

use strict;
use warnings;

use Test::More 0.96;

use Astro::SpaceTrack;
use HTTP::Status qw{ HTTP_I_AM_A_TEAPOT };

sub is_resp (@);
sub year();

my $loader = Astro::SpaceTrack->__get_loader() or do {
    plan skip_all => 'JSON required to check Space Track requests.';
    exit;
};

my $st = Astro::SpaceTrack->new(
    space_track_version	=> 1,
    dump_headers =>
	Astro::SpaceTrack->DUMP_REQUEST | Astro::SpaceTrack->DUMP_NO_EXECUTE,
);

my $base_url = $st->_make_space_track_base_url();

note 'Space Track v1 interface';

is_resp qw{retrieve 25544}, {
	args => {
	    _sessionid => '',
	    _submitted => 1,
	    ascii => 'yes',
	    common_name => '',
	    descending => '',
	    ids => 25544,
	    sort => 'catnum',
	    timeframe => 'latest',
	},
	method => 'POST',
	url => "$base_url/perl/id_query.pl",
	version => 1,
    },
;

is_resp qw{retrieve -sort catnum 25544}, {
	args => {
	    _sessionid => '',
	    _submitted => 1,
	    ascii => 'yes',
	    common_name => '',
	    descending => '',
	    ids => 25544,
	    sort => 'catnum',
	    timeframe => 'latest',
	},
	method => 'POST',
	url => "$base_url/perl/id_query.pl",
	version => 1,
    },
;

is_resp qw{retrieve -sort epoch 25544}, {
	args => {
	    _sessionid => '',
	    _submitted => 1,
	    ascii => 'yes',
	    common_name => '',
	    descending => '',
	    ids => 25544,
	    sort => 'epoch',
	    timeframe => 'latest',
	},
	method => 'POST',
	url => "$base_url/perl/id_query.pl",
	version => 1,
    },
;

is_resp qw{retrieve -descending 25544}, {
	args => {
	    _sessionid => '',
	    _submitted => 1,
	    ascii => 'yes',
	    common_name => '',
	    descending => 'yes',
	    ids => 25544,
	    sort => 'catnum',
	    timeframe => 'latest',
	},
	method => 'POST',
	url => "$base_url/perl/id_query.pl",
	version => 1,
    },
;

is_resp qw{retrieve -last5 25544}, {
	args => {
	    _sessionid => '',
	    _submitted => 1,
	    ascii => 'yes',
	    common_name => '',
	    descending => '',
	    ids => 25544,
	    sort => 'catnum',
	    timeframe => 'last5',
	},
	method => 'POST',
	url => "$base_url/perl/id_query.pl",
	version => 1,
    },
;

is_resp qw{retrieve -start_epoch 2009-04-01 25544}, {
	args => {
	    _sessionid => '',
	    _submitted => 1,
	    ascii => 'yes',
	    common_name => '',
	    descending => '',
	    end_day => 2,
	    end_month => 4,
	    end_year => 2009,
	    ids => 25544,
	    sort => 'catnum',
	    start_day => 1,
	    start_month => 4,
	    start_year => 2009,
	    timeframe => 'timespan',
	},
	method => 'POST',
	url => "$base_url/perl/id_query.pl",
	version => 1,
    },
;

is_resp qw{retrieve -last5 -start_epoch 2009-04-01 25544}, {
	args => {
	    _sessionid => '',
	    _submitted => 1,
	    ascii => 'yes',
	    common_name => '',
	    descending => '',
	    end_day => 2,
	    end_month => 4,
	    end_year => 2009,
	    ids => 25544,
	    sort => 'catnum',
	    start_day => 1,
	    start_month => 4,
	    start_year => 2009,
	    timeframe => 'timespan',
	},
	method => 'POST',
	url => "$base_url/perl/id_query.pl",
	version => 1,
    },
;

is_resp qw{retrieve -end_epoch 2009-04-01 25544}, {
	args => {
	    _sessionid => '',
	    _submitted => 1,
	    ascii => 'yes',
	    common_name => '',
	    descending => '',
	    end_day => 1,
	    end_month => 4,
	    end_year => 2009,
	    ids => 25544,
	    sort => 'catnum',
	    start_day => 31,
	    start_month => 3,
	    start_year => 2009,
	    timeframe => 'timespan',
	},
	method => 'POST',
	url => "$base_url/perl/id_query.pl",
	version => 1,
    },
;

is_resp qw{retrieve -start_epoch 2009-03-01 -end_epoch 2009-04-01 25544}, {
	args => {
	    _sessionid => '',
	    _submitted => 1,
	    ascii => 'yes',
	    common_name => '',
	    descending => '',
	    end_day => 1,
	    end_month => 4,
	    end_year => 2009,
	    ids => 25544,
	    sort => 'catnum',
	    start_day => 1,
	    start_month => 3,
	    start_year => 2009,
	    timeframe => 'timespan',
	},
	method => 'POST',
	url => "$base_url/perl/id_query.pl",
	version => 1,
    },
;

is_resp qw{set with_name 1}, 'OK';

is_resp qw{retrieve 25544}, {
	args => {
	    _sessionid => '',
	    _submitted => 1,
	    ascii => 'yes',
	    common_name => 'yes',
	    descending => '',
	    ids => 25544,
	    sort => 'catnum',
	    timeframe => 'latest',
	},
	method => 'POST',
	url => "$base_url/perl/id_query.pl",
	version => 1,
    },
;

is_resp qw{search_date 2009-04-01}, {
	args => {
	    _sessionid => '',
	    _submit => 'submit',
	    _submitted => 1,
	    date_spec => 'month',
	    exclude => [],
	    launch_day => '01',
	    launch_month => '04',
	    launch_year => '2009',
	    status => 'all',
	},
	method => 'POST',
	url => "$base_url/perl/launch_query.pl",
	version => 1,
    },
;

is_resp qw{search_date -status all 2009-04-01}, {
	args => {
	    _sessionid => '',
	    _submit => 'submit',
	    _submitted => 1,
	    date_spec => 'month',
	    exclude => [],
	    launch_day => '01',
	    launch_month => '04',
	    launch_year => '2009',
	    status => 'all',
	},
	method => 'POST',
	url => "$base_url/perl/launch_query.pl",
	version => 1,
    },
;

is_resp qw{search_date -status onorbit 2009-04-01}, {
	args => {
	    _sessionid => '',
	    _submit => 'submit',
	    _submitted => 1,
	    date_spec => 'month',
	    exclude => [],
	    launch_day => '01',
	    launch_month => '04',
	    launch_year => '2009',
	    status => 'onorbit',
	},
	method => 'POST',
	url => "$base_url/perl/launch_query.pl",
	version => 1,
    },
;

is_resp qw{search_date -status decayed 2009-04-01}, {
	args => {
	    _sessionid => '',
	    _submit => 'submit',
	    _submitted => 1,
	    date_spec => 'month',
	    exclude => [],
	    launch_day => '01',
	    launch_month => '04',
	    launch_year => '2009',
	    status => 'decayed',
	},
	method => 'POST',
	url => "$base_url/perl/launch_query.pl",
	version => 1,
    },
;

is_resp qw{search_date -exclude debris 2009-04-01}, {
	args => {
	    _sessionid => '',
	    _submit => 'submit',
	    _submitted => 1,
	    date_spec => 'month',
	    exclude => [qw{debris}],
	    launch_day => '01',
	    launch_month => '04',
	    launch_year => '2009',
	    status => 'all',
	},
	method => 'POST',
	url => "$base_url/perl/launch_query.pl",
	version => 1,
    },
;

is_resp qw{search_date -exclude rocket 2009-04-01}, {
	args => {
	    _sessionid => '',
	    _submit => 'submit',
	    _submitted => 1,
	    date_spec => 'month',
	    exclude => [qw{rocket}],
	    launch_day => '01',
	    launch_month => '04',
	    launch_year => '2009',
	    status => 'all',
	},
	method => 'POST',
	url => "$base_url/perl/launch_query.pl",
	version => 1,
    },
;

{
    no warnings qw{qw};	## no critic (ProhibitNoWarnings)
    is_resp qw{search_date -exclude debris,rocket 2009-04-01}, {
	    args => {
		_sessionid => '',
		_submit => 'submit',
		_submitted => 1,
		date_spec => 'month',
		exclude => [qw{debris rocket}],
		launch_day => '01',
		launch_month => '04',
		launch_year => '2009',
		status => 'all',
	    },
	    method => 'POST',
	    url => "$base_url/perl/launch_query.pl",
	version => 1,
	},
    ;
}

is_resp qw{search_date -exclude debris -exclude rocket 2009-04-01}, {
	args => {
	    _sessionid => '',
	    _submit => 'submit',
	    _submitted => 1,
	    date_spec => 'month',
	    exclude => [qw{debris rocket}],
	    launch_day => '01',
	    launch_month => '04',
	    launch_year => '2009',
	    status => 'all',
	},
	method => 'POST',
	url => "$base_url/perl/launch_query.pl",
	version => 1,
    },
;

is_resp qw{search_id 98067}, {
	args => {
	    _sessionid => '',
	    _submit => 'submit',
	    _submitted => 1,
	    date_spec => 'number',
	    exclude => [],
	    launch_number => '067',
	    launch_year => '1998',
	    piece => '',
	    status => 'all',
	},
	method => 'POST',
	url => "$base_url/perl/launch_query.pl",
	version => 1,
    },
;

is_resp qw{search_id 98}, {
	args => {
	    _sessionid => '',
	    _submit => 'submit',
	    _submitted => 1,
	    date_spec => 'number',
	    exclude => [],
	    launch_number => '',
	    launch_year => '1998',
	    piece => '',
	    status => 'all',
	},
	method => 'POST',
	url => "$base_url/perl/launch_query.pl",
	version => 1,
    },
;

is_resp qw{search_id 98067A}, {
	args => {
	    _sessionid => '',
	    _submit => 'submit',
	    _submitted => 1,
	    date_spec => 'number',
	    exclude => [],
	    launch_number => '067',
	    launch_year => '1998',
	    piece => 'A',
	    status => 'all',
	},
	method => 'POST',
	url => "$base_url/perl/launch_query.pl",
	version => 1,
    },
;

is_resp qw{search_id -status all 98067}, {
	args => {
	    _sessionid => '',
	    _submit => 'submit',
	    _submitted => 1,
	    date_spec => 'number',
	    exclude => [],
	    launch_number => '067',
	    launch_year => '1998',
	    piece => '',
	    status => 'all',
	},
	method => 'POST',
	url => "$base_url/perl/launch_query.pl",
	version => 1,
    },
;

is_resp qw{search_id -status onorbit 98067}, {
	args => {
	    _sessionid => '',
	    _submit => 'submit',
	    _submitted => 1,
	    date_spec => 'number',
	    exclude => [],
	    launch_number => '067',
	    launch_year => '1998',
	    piece => '',
	    status => 'onorbit',
	},
	method => 'POST',
	url => "$base_url/perl/launch_query.pl",
	version => 1,
    },
;

is_resp qw{search_id -status decayed 98067}, {
	args => {
	    _sessionid => '',
	    _submit => 'submit',
	    _submitted => 1,
	    date_spec => 'number',
	    exclude => [],
	    launch_number => '067',
	    launch_year => '1998',
	    piece => '',
	    status => 'decayed',
	},
	method => 'POST',
	url => "$base_url/perl/launch_query.pl",
	version => 1,
    },
;

is_resp qw{search_id -exclude debris 98067}, {
	args => {
	    _sessionid => '',
	    _submit => 'submit',
	    _submitted => 1,
	    date_spec => 'number',
	    exclude => [qw{debris}],
	    launch_number => '067',
	    launch_year => '1998',
	    piece => '',
	    status => 'all',
	},
	method => 'POST',
	url => "$base_url/perl/launch_query.pl",
	version => 1,
    },
;

is_resp qw{search_id -exclude rocket 98067}, {
	args => {
	    _sessionid => '',
	    _submit => 'submit',
	    _submitted => 1,
	    date_spec => 'number',
	    exclude => [qw{rocket}],
	    launch_number => '067',
	    launch_year => '1998',
	    piece => '',
	    status => 'all',
	},
	method => 'POST',
	url => "$base_url/perl/launch_query.pl",
	version => 1,
    },
;

{
    no warnings qw{qw};	## no critic (ProhibitNoWarnings)
    is_resp qw{search_id -exclude debris,rocket 98067}, {
	    args => {
		_sessionid => '',
		_submit => 'submit',
		_submitted => 1,
		date_spec => 'number',
		exclude => [qw{debris rocket}],
		launch_number => '067',
		launch_year => '1998',
		piece => '',
		status => 'all',
	    },
	    method => 'POST',
	    url => "$base_url/perl/launch_query.pl",
	    version => 1,
	},
    ;
}

is_resp qw{search_id -exclude debris -exclude rocket 98067}, {
	args => {
	    _sessionid => '',
	    _submit => 'submit',
	    _submitted => 1,
	    date_spec => 'number',
	    exclude => [qw{debris rocket}],
	    launch_number => '067',
	    launch_year => '1998',
	    piece => '',
	    status => 'all',
	},
	method => 'POST',
	url => "$base_url/perl/launch_query.pl",
	version => 1,
    },
;

is_resp qw{search_name ISS}, {
	args => {
	    _sessionid => '',
	    _submit => 'Submit',
	    _submitted => 1,
	    exclude => [],
	    launch_year_end => year,
	    launch_year_start => 1957,
	    name => 'ISS',
	    status => 'all',
	},
	method => 'POST',
	url => "$base_url/perl/name_query.pl",
	version => 1,
    },
;

is_resp qw{search_name -status all ISS}, {
	args => {
	    _sessionid => '',
	    _submit => 'Submit',
	    _submitted => 1,
	    exclude => [],
	    launch_year_end => year,
	    launch_year_start => 1957,
	    name => 'ISS',
	    status => 'all',
	},
	method => 'POST',
	url => "$base_url/perl/name_query.pl",
	version => 1,
    },
;

is_resp qw{search_name -status onorbit ISS}, {
	args => {
	    _sessionid => '',
	    _submit => 'Submit',
	    _submitted => 1,
	    exclude => [],
	    launch_year_end => year,
	    launch_year_start => 1957,
	    name => 'ISS',
	    status => 'onorbit',
	},
	method => 'POST',
	url => "$base_url/perl/name_query.pl",
	version => 1,
    },
;

is_resp qw{search_name -status decayed ISS}, {
	args => {
	    _sessionid => '',
	    _submit => 'Submit',
	    _submitted => 1,
	    exclude => [],
	    launch_year_end => year,
	    launch_year_start => 1957,
	    name => 'ISS',
	    status => 'decayed',
	},
	method => 'POST',
	url => "$base_url/perl/name_query.pl",
	version => 1,
    },
;

is_resp qw{search_name -exclude debris ISS}, {
	args => {
	    _sessionid => '',
	    _submit => 'Submit',
	    _submitted => 1,
	    exclude => [qw{debris}],
	    launch_year_end => year,
	    launch_year_start => 1957,
	    name => 'ISS',
	    status => 'all',
	},
	method => 'POST',
	url => "$base_url/perl/name_query.pl",
	version => 1,
    },
;

is_resp qw{search_name -exclude rocket ISS}, {
	args => {
	    _sessionid => '',
	    _submit => 'Submit',
	    _submitted => 1,
	    exclude => [qw{rocket}],
	    launch_year_end => year,
	    launch_year_start => 1957,
	    name => 'ISS',
	    status => 'all',
	},
	method => 'POST',
	url => "$base_url/perl/name_query.pl",
	version => 1,
    },
;

{
    no warnings qw{qw};	## no critic (ProhibitNoWarnings)
    is_resp qw{search_name -exclude debris,rocket ISS}, {
	    args => {
		_sessionid => '',
		_submit => 'Submit',
		_submitted => 1,
		exclude => [qw{debris rocket}],
		launch_year_end => year,
		launch_year_start => 1957,
		name => 'ISS',
		status => 'all',
	    },
	    method => 'POST',
	    url => "$base_url/perl/name_query.pl",
	    version => 1,
	},
    ;
}

is_resp qw{search_name -exclude debris -exclude rocket ISS}, {
	args => {
	    _sessionid => '',
	    _submit => 'Submit',
	    _submitted => 1,
	    exclude => [qw{debris rocket}],
	    launch_year_end => year,
	    launch_year_start => 1957,
	    name => 'ISS',
	    status => 'all',
	},
	method => 'POST',
	url => "$base_url/perl/name_query.pl",
	version => 1,
    },
;

is_resp qw{spacetrack iridium}, {
	args => {
	    ID => 10,
	},
	method => 'GET',
	url => "$base_url/perl/dl.pl",
	version => 1,
    },
;

is_resp qw{set with_name 0}, 'OK';

is_resp qw{spacetrack iridium}, {
	args => {
	    ID => 9,
	},
	method => 'GET',
	url => "$base_url/perl/dl.pl",
	version => 1,
    },
;

is_resp qw{spacetrack 10}, {
	args => {
	    ID => 10,
	},
	method => 'GET',
	url => "$base_url/perl/dl.pl",
	version => 1,
    },
;

is_resp qw{box_score}, {
	args => {
	},
	method => 'GET',
	url => "$base_url/perl/boxscore.pl",
	version => 1,
    },
;

################################

note 'Space Track v2 interface';

$st->set( space_track_version => 2 );

$base_url = $st->_make_space_track_base_url();

is_resp qw{retrieve 25544}, [ {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'tle',
	    NORAD_CAT_ID => 25544,
	    format	=> 'tle',
	    orderby	=> 'EPOCH desc',
	    sublimit	=> 1,
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/tle/NORAD_CAT_ID/25544/format/tle/orderby/EPOCH%20desc/sublimit/1",
	version => 2,
    } ],
;

is_resp qw{retrieve -sort catnum 25544}, [ {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'tle',
	    NORAD_CAT_ID => 25544,
	    format	=> 'tle',
	    orderby	=> 'EPOCH desc',
	    sublimit	=> 1,
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/tle/NORAD_CAT_ID/25544/format/tle/orderby/EPOCH%20desc/sublimit/1",
	version => 2,
    } ],
;

is_resp qw{retrieve -sort epoch 25544}, [ {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'tle',
	    NORAD_CAT_ID => 25544,
	    format	=> 'tle',
	    orderby	=> 'EPOCH desc',
	    sublimit	=> 1,
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/tle/NORAD_CAT_ID/25544/format/tle/orderby/EPOCH%20desc/sublimit/1",
	version => 2,
    } ],
;

is_resp qw{retrieve -descending 25544}, [ {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'tle',
	    NORAD_CAT_ID => 25544,
	    format	=> 'tle',
	    orderby	=> 'EPOCH desc',
	    sublimit	=> 1,
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/tle/NORAD_CAT_ID/25544/format/tle/orderby/EPOCH%20desc/sublimit/1",
	version => 2,
    } ],
;

is_resp qw{retrieve -last5 25544}, [ {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'tle',
	    NORAD_CAT_ID => 25544,
	    format	=> 'tle',
	    orderby	=> 'EPOCH desc',
	    sublimit	=> 5,
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/tle/NORAD_CAT_ID/25544/format/tle/orderby/EPOCH%20desc/sublimit/5",
	version => 2,
    } ],
;

is_resp qw{retrieve -start_epoch 2009-04-01 25544}, [ {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'tle',
	    NORAD_CAT_ID => 25544,
	    EPOCH	=> '2009-04-01 00:00:00--2009-04-02 00:00:00',
	    format	=> 'tle',
	    orderby	=> 'EPOCH desc',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/tle/NORAD_CAT_ID/25544/EPOCH/2009-04-01%2000:00:00--2009-04-02%2000:00:00/format/tle/orderby/EPOCH%20desc",
	version => 2,
    } ],
;

is_resp qw{retrieve -last5 -start_epoch 2009-04-01 25544}, [ {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'tle',
	    NORAD_CAT_ID => 25544,
	    EPOCH	=> '2009-04-01 00:00:00--2009-04-02 00:00:00',
	    format	=> 'tle',
	    orderby	=> 'EPOCH desc',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/tle/NORAD_CAT_ID/25544/EPOCH/2009-04-01%2000:00:00--2009-04-02%2000:00:00/format/tle/orderby/EPOCH%20desc",
	version => 2,
    } ],
;

is_resp qw{retrieve -end_epoch 2009-04-01 25544}, [ {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'tle',
	    NORAD_CAT_ID => 25544,
	    EPOCH	=> '2009-03-31 00:00:00--2009-04-01 00:00:00',
	    format	=> 'tle',
	    orderby	=> 'EPOCH desc',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/tle/NORAD_CAT_ID/25544/EPOCH/2009-03-31%2000:00:00--2009-04-01%2000:00:00/format/tle/orderby/EPOCH%20desc",
	version => 2,
    } ],
;

is_resp qw{retrieve -start_epoch 2009-03-01 -end_epoch 2009-04-01 25544}, [ {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'tle',
	    NORAD_CAT_ID => 25544,
	    EPOCH	=> '2009-03-01 00:00:00--2009-04-01 00:00:00',
	    format	=> 'tle',
	    orderby	=> 'EPOCH desc',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/tle/NORAD_CAT_ID/25544/EPOCH/2009-03-01%2000:00:00--2009-04-01%2000:00:00/format/tle/orderby/EPOCH%20desc",
	version => 2,
    } ],
;

note <<'EOD';
The point of the following test is to ensure that the request is being
properly broken into two pieces, and that the joining of the JSON in the
responses is being handled properly.
EOD

is_resp retrieve => 1 .. 66, [
    {
	args => [
	    basicspacedata	=> 'query',
	    class		=> 'tle',
	    NORAD_CAT_ID	=> '1--50',
	    format		=> 'tle',
	    orderby		=> 'EPOCH desc',
	    sublimit		=> 1,
	],
	method	=> 'GET',
	url => "$base_url/basicspacedata/query/class/tle/NORAD_CAT_ID/1--50/format/tle/orderby/EPOCH%20desc/sublimit/1",
	version	=> 2
    },
    {
	args => [
	    basicspacedata	=> 'query',
	    class		=> 'tle',
	    NORAD_CAT_ID	=> '51--66',
	    format		=> 'tle',
	    orderby		=> 'EPOCH desc',
	    sublimit		=> 1,
	],
	method	=> 'GET',
	url => "$base_url/basicspacedata/query/class/tle/NORAD_CAT_ID/51--66/format/tle/orderby/EPOCH%20desc/sublimit/1",
	version	=> 2
    },
],
;

is_resp qw{set with_name 1}, 'OK';

# TODO NASA-format TLEs not supported via REST interface.
is_resp qw{retrieve 25544}, [ {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'tle',
	    NORAD_CAT_ID => 25544,
	    format	=> 'tle',
	    orderby	=> 'EPOCH desc',
	    sublimit	=> 1,
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/tle/NORAD_CAT_ID/25544/format/tle/orderby/EPOCH%20desc/sublimit/1",
	version => 2,
    } ],
;

is_resp qw{search_date 2009-04-01}, {
	args => [
	    basicspacedata	=> 'query',
	    CURRENT	=> 'Y',
	    LAUNCH	=> '2009-04-01',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'NORAD_CAT_ID asc',
	    predicates	=> 'all',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/CURRENT/Y/LAUNCH/2009-04-01/class/satcat/format/json/orderby/NORAD_CAT_ID%20asc/predicates/all",
	version => 2,
    },
;

is_resp qw{search_date -status all 2009-04-01}, {
	args => [
	    basicspacedata	=> 'query',
	    CURRENT	=> 'Y',
	    LAUNCH	=> '2009-04-01',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'NORAD_CAT_ID asc',
	    predicates	=> 'all',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/CURRENT/Y/LAUNCH/2009-04-01/class/satcat/format/json/orderby/NORAD_CAT_ID%20asc/predicates/all",
	version => 2,
    },
;

is_resp qw{search_date -status onorbit 2009-04-01}, {
	args => [
	    basicspacedata	=> 'query',
	    CURRENT	=> 'Y',
	    DECAY	=> 'null-val',
	    LAUNCH	=> '2009-04-01',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'NORAD_CAT_ID asc',
	    predicates	=> 'all',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/CURRENT/Y/DECAY/null-val/LAUNCH/2009-04-01/class/satcat/format/json/orderby/NORAD_CAT_ID%20asc/predicates/all",
	version => 2,
    },
;

is_resp qw{search_date -status decayed 2009-04-01}, {
	args => [
	    basicspacedata	=> 'query',
	    CURRENT	=> 'Y',
	    DECAY	=> '<>null-val',
	    LAUNCH	=> '2009-04-01',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'NORAD_CAT_ID asc',
	    predicates	=> 'all',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/CURRENT/Y/DECAY/%3C%3Enull-val/LAUNCH/2009-04-01/class/satcat/format/json/orderby/NORAD_CAT_ID%20asc/predicates/all",
	version => 2,
    },
;

# TODO -exclude not supported by Space Track v2. We simulate it.
is_resp qw{search_date -exclude debris 2009-04-01}, {
	args => [
	    basicspacedata	=> 'query',
	    CURRENT	=> 'Y',
	    LAUNCH	=> '2009-04-01',
	    OBJECT_TYPE	=> 'PAYLOAD,ROCKET BODY,UNKNOWN,OTHER',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'NORAD_CAT_ID asc',
	    predicates	=> 'all',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/CURRENT/Y/LAUNCH/2009-04-01/OBJECT_TYPE/PAYLOAD,ROCKET%20BODY,UNKNOWN,OTHER/class/satcat/format/json/orderby/NORAD_CAT_ID%20asc/predicates/all",
	version => 2,
    },
;

# TODO -exclude not supported by Space Track v2. We simulate it.
is_resp qw{search_date -exclude rocket 2009-04-01}, {
	args => [
	    basicspacedata	=> 'query',
	    CURRENT	=> 'Y',
	    LAUNCH	=> '2009-04-01',
	    OBJECT_TYPE	=> 'PAYLOAD,DEBRIS,UNKNOWN,OTHER',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'NORAD_CAT_ID asc',
	    predicates	=> 'all',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/CURRENT/Y/LAUNCH/2009-04-01/OBJECT_TYPE/PAYLOAD,DEBRIS,UNKNOWN,OTHER/class/satcat/format/json/orderby/NORAD_CAT_ID%20asc/predicates/all",
	version => 2,
    },
;

{
    no warnings qw{qw};	## no critic (ProhibitNoWarnings)
    # TODO -exclude not supported by Space Track v2. We simulate it.
    is_resp qw{search_date -exclude debris,rocket 2009-04-01}, {
	    args => [
		basicspacedata	=> 'query',
		CURRENT	=> 'Y',
		LAUNCH	=> '2009-04-01',
		OBJECT_TYPE	=> 'PAYLOAD,UNKNOWN,OTHER',
		class	=> 'satcat',
		format	=> 'json',
		orderby	=> 'NORAD_CAT_ID asc',
		predicates	=> 'all',
	    ],
	    method => 'GET',
	    url => "$base_url/basicspacedata/query/CURRENT/Y/LAUNCH/2009-04-01/OBJECT_TYPE/PAYLOAD,UNKNOWN,OTHER/class/satcat/format/json/orderby/NORAD_CAT_ID%20asc/predicates/all",
	version => 2,
	},
    ;
}

# TODO -exclude not supported by Space Track v2. We simulate it.
is_resp qw{search_date -exclude debris -exclude rocket 2009-04-01}, {
	args => [
	    basicspacedata	=> 'query',
	    CURRENT	=> 'Y',
	    LAUNCH	=> '2009-04-01',
	    OBJECT_TYPE	=> 'PAYLOAD,UNKNOWN,OTHER',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'NORAD_CAT_ID asc',
	    predicates	=> 'all',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/CURRENT/Y/LAUNCH/2009-04-01/OBJECT_TYPE/PAYLOAD,UNKNOWN,OTHER/class/satcat/format/json/orderby/NORAD_CAT_ID%20asc/predicates/all",
	version => 2,
    },
;

is_resp qw{search_id 98067}, {
	args => [
	    basicspacedata	=> 'query',
	    CURRENT	=> 'Y',
	    INTLDES	=> '~~1998-067',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'NORAD_CAT_ID asc',
	    predicates	=> 'all',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/CURRENT/Y/INTLDES/~~1998-067/class/satcat/format/json/orderby/NORAD_CAT_ID%20asc/predicates/all",
	version => 2,
    },
;

is_resp qw{search_id 98}, {
	args => [
	    basicspacedata	=> 'query',
	    CURRENT	=> 'Y',
	    INTLDES	=> '~~1998',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'NORAD_CAT_ID asc',
	    predicates	=> 'all',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/CURRENT/Y/INTLDES/~~1998/class/satcat/format/json/orderby/NORAD_CAT_ID%20asc/predicates/all",
	version => 2,
    },
;

is_resp qw{search_id 98067A}, {
	args => [
	    basicspacedata	=> 'query',
	    CURRENT	=> 'Y',
	    INTLDES	=> '1998-067A',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'NORAD_CAT_ID asc',
	    predicates	=> 'all',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/CURRENT/Y/INTLDES/1998-067A/class/satcat/format/json/orderby/NORAD_CAT_ID%20asc/predicates/all",
	version => 2,
    },
;

is_resp qw{search_id -status all 98067}, {
	args => [
	    basicspacedata	=> 'query',
	    CURRENT	=> 'Y',
	    INTLDES	=> '~~1998-067',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'NORAD_CAT_ID asc',
	    predicates	=> 'all',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/CURRENT/Y/INTLDES/~~1998-067/class/satcat/format/json/orderby/NORAD_CAT_ID%20asc/predicates/all",
	version => 2,
    },
;

is_resp qw{search_id -status onorbit 98067}, {
	args => [
	    basicspacedata	=> 'query',
	    CURRENT	=> 'Y',
	    DECAY	=> 'null-val',
	    INTLDES	=> '~~1998-067',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'NORAD_CAT_ID asc',
	    predicates	=> 'all',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/CURRENT/Y/DECAY/null-val/INTLDES/~~1998-067/class/satcat/format/json/orderby/NORAD_CAT_ID%20asc/predicates/all",
	version => 2,
    },
;

is_resp qw{search_id -status decayed 98067}, {
	args => [
	    basicspacedata	=> 'query',
	    CURRENT	=> 'Y',
	    DECAY	=> '<>null-val',
	    INTLDES	=> '~~1998-067',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'NORAD_CAT_ID asc',
	    predicates	=> 'all',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/CURRENT/Y/DECAY/%3C%3Enull-val/INTLDES/~~1998-067/class/satcat/format/json/orderby/NORAD_CAT_ID%20asc/predicates/all",
	version => 2,
    },
;

# TODO -exclude not supported by Space Track v2. We simulate it.
is_resp qw{search_id -exclude debris 98067}, {
	args => [
	    basicspacedata	=> 'query',
	    CURRENT	=> 'Y',
	    INTLDES	=> '~~1998-067',
	    OBJECT_TYPE	=> 'PAYLOAD,ROCKET BODY,UNKNOWN,OTHER',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'NORAD_CAT_ID asc',
	    predicates	=> 'all',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/CURRENT/Y/INTLDES/~~1998-067/OBJECT_TYPE/PAYLOAD,ROCKET%20BODY,UNKNOWN,OTHER/class/satcat/format/json/orderby/NORAD_CAT_ID%20asc/predicates/all",
	version => 2,
    },
;

# TODO -exclude not supported by Space Track v2. We simulate it.
is_resp qw{search_id -exclude rocket 98067}, {
	args => [
	    basicspacedata	=> 'query',
	    CURRENT	=> 'Y',
	    INTLDES	=> '~~1998-067',
	    OBJECT_TYPE	=> 'PAYLOAD,DEBRIS,UNKNOWN,OTHER',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'NORAD_CAT_ID asc',
	    predicates	=> 'all',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/CURRENT/Y/INTLDES/~~1998-067/OBJECT_TYPE/PAYLOAD,DEBRIS,UNKNOWN,OTHER/class/satcat/format/json/orderby/NORAD_CAT_ID%20asc/predicates/all",
	version => 2,
    },
;

{
    no warnings qw{qw};	## no critic (ProhibitNoWarnings)
    # TODO -exclude not supported by Space Track v2. We simulate it.
    is_resp qw{search_id -exclude debris,rocket 98067}, {
	    args => [
		basicspacedata	=> 'query',
		CURRENT	=> 'Y',
		INTLDES	=> '~~1998-067',
		OBJECT_TYPE	=> 'PAYLOAD,UNKNOWN,OTHER',
		class	=> 'satcat',
		format	=> 'json',
		orderby	=> 'NORAD_CAT_ID asc',
		predicates	=> 'all',
	    ],
	    method => 'GET',
	    url => "$base_url/basicspacedata/query/CURRENT/Y/INTLDES/~~1998-067/OBJECT_TYPE/PAYLOAD,UNKNOWN,OTHER/class/satcat/format/json/orderby/NORAD_CAT_ID%20asc/predicates/all",
	version => 2,
	},
    ;
}

# TODO -exclude not supported by Space Track v2. We simulate it.
is_resp qw{search_id -exclude debris -exclude rocket 98067}, {
	args => [
	    basicspacedata	=> 'query',
	    CURRENT	=> 'Y',
	    INTLDES	=> '~~1998-067',
	    OBJECT_TYPE	=> 'PAYLOAD,UNKNOWN,OTHER',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'NORAD_CAT_ID asc',
	    predicates	=> 'all',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/CURRENT/Y/INTLDES/~~1998-067/OBJECT_TYPE/PAYLOAD,UNKNOWN,OTHER/class/satcat/format/json/orderby/NORAD_CAT_ID%20asc/predicates/all",
	version => 2,
    },
;

is_resp qw{search_name ISS}, {
	args => [
	    basicspacedata	=> 'query',
	    CURRENT	=> 'Y',
	    SATNAME	=> '~~ISS',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'NORAD_CAT_ID asc',
	    predicates	=> 'all',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/CURRENT/Y/SATNAME/~~ISS/class/satcat/format/json/orderby/NORAD_CAT_ID%20asc/predicates/all",
	version => 2,
    },
;

is_resp qw{search_name -status all ISS}, {
	args => [
	    basicspacedata	=> 'query',
	    CURRENT	=> 'Y',
	    SATNAME	=> '~~ISS',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'NORAD_CAT_ID asc',
	    predicates	=> 'all',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/CURRENT/Y/SATNAME/~~ISS/class/satcat/format/json/orderby/NORAD_CAT_ID%20asc/predicates/all",
	version => 2,
    },
;

is_resp qw{search_name -status onorbit ISS}, {
	args => [
	    basicspacedata	=> 'query',
	    CURRENT	=> 'Y',
	    DECAY	=> 'null-val',
	    SATNAME	=> '~~ISS',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'NORAD_CAT_ID asc',
	    predicates	=> 'all',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/CURRENT/Y/DECAY/null-val/SATNAME/~~ISS/class/satcat/format/json/orderby/NORAD_CAT_ID%20asc/predicates/all",
	version => 2,
    },
;

is_resp qw{search_name -status decayed ISS}, {
	args => [
	    basicspacedata	=> 'query',
	    CURRENT	=> 'Y',
	    DECAY	=> '<>null-val',
	    SATNAME	=> '~~ISS',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'NORAD_CAT_ID asc',
	    predicates	=> 'all',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/CURRENT/Y/DECAY/%3C%3Enull-val/SATNAME/~~ISS/class/satcat/format/json/orderby/NORAD_CAT_ID%20asc/predicates/all",
	version => 2,
    },
;

# TODO -exclude not supported by Space Track v2. We simulate it.
is_resp qw{search_name -exclude debris ISS}, {
	args => [
	    basicspacedata	=> 'query',
	    CURRENT	=> 'Y',
	    OBJECT_TYPE	=> 'PAYLOAD,ROCKET BODY,UNKNOWN,OTHER',
	    SATNAME	=> '~~ISS',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'NORAD_CAT_ID asc',
	    predicates	=> 'all',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/CURRENT/Y/OBJECT_TYPE/PAYLOAD,ROCKET%20BODY,UNKNOWN,OTHER/SATNAME/~~ISS/class/satcat/format/json/orderby/NORAD_CAT_ID%20asc/predicates/all",
	version => 2,
    },
;

# TODO -exclude not supported by Space Track v2. We simulate it.
is_resp qw{search_name -exclude rocket ISS}, {
	args => [
	    basicspacedata	=> 'query',
	    CURRENT	=> 'Y',
	    OBJECT_TYPE	=> 'PAYLOAD,DEBRIS,UNKNOWN,OTHER',
	    SATNAME	=> '~~ISS',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'NORAD_CAT_ID asc',
	    predicates	=> 'all',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/CURRENT/Y/OBJECT_TYPE/PAYLOAD,DEBRIS,UNKNOWN,OTHER/SATNAME/~~ISS/class/satcat/format/json/orderby/NORAD_CAT_ID%20asc/predicates/all",
	version => 2,
    },
;

{
    no warnings qw{qw};	## no critic (ProhibitNoWarnings)
    # TODO -exclude not supported by Space Track v2. We simulate it.
    is_resp qw{search_name -exclude debris,rocket ISS}, {
	args => [
	    basicspacedata	=> 'query',
	    CURRENT	=> 'Y',
	    OBJECT_TYPE	=> 'PAYLOAD,UNKNOWN,OTHER',
	    SATNAME	=> '~~ISS',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'NORAD_CAT_ID asc',
	    predicates	=> 'all',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/CURRENT/Y/OBJECT_TYPE/PAYLOAD,UNKNOWN,OTHER/SATNAME/~~ISS/class/satcat/format/json/orderby/NORAD_CAT_ID%20asc/predicates/all",
	version => 2,
	},
    ;
}

# TODO -exclude not supported by Space Track v2. We simulate it.
is_resp qw{search_name -exclude debris -exclude rocket ISS}, {
	args => [
	    basicspacedata	=> 'query',
	    CURRENT	=> 'Y',
	    OBJECT_TYPE	=> 'PAYLOAD,UNKNOWN,OTHER',
	    SATNAME	=> '~~ISS',
	    class	=> 'satcat',
	    format	=> 'json',
	    orderby	=> 'NORAD_CAT_ID asc',
	    predicates	=> 'all',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/CURRENT/Y/OBJECT_TYPE/PAYLOAD,UNKNOWN,OTHER/SATNAME/~~ISS/class/satcat/format/json/orderby/NORAD_CAT_ID%20asc/predicates/all",
	version => 2,
    },
;

=begin comment

# TODO Not supported by Space Track v2 interface
is_resp qw{spacetrack iridium}, {
	args => [
	    basicspacedata	=> 'query',
	],
	method => 'GET',
	url => $base_url,
	version => 2,
    },
;

=end comment

=cut

is_resp qw{set with_name 0}, 'OK';

=begin comment

# TODO Not supported by Space Track v2 interface
is_resp qw{spacetrack iridium}, {
	args => [
	    basicspacedata	=> 'query',
	],
	method => 'GET',
	url => $base_url,
	version => 2,
    },
;

# TODO Not supported by Space Track v2 interface
is_resp qw{spacetrack 10}, {
	args => [
	    basicspacedata	=> 'query',
	],
	method => 'GET',
	url => $base_url,
	version => 2,
    },
;

=end comment

=cut

is_resp qw{box_score}, {
	args => [
	    basicspacedata	=> 'query',
	    class	=> 'boxscore',
	    format	=> 'json',
	    predicates	=> 'all',
	],
	method => 'GET',
	url => "$base_url/basicspacedata/query/class/boxscore/format/json/predicates/all",
	version => 2,
    },
;

done_testing;

sub is_resp (@) {	## no critic (RequireArgUnpacking)
    my ($method, @args) = @_;
    my $query = pop @args;
    my $name = "\$st->$method(" . join( ', ', map {"'$_'"} @args ) . ')';
    my $resp = $st->$method( @args );
    my ($got);

    if ( $resp && $resp->isa('HTTP::Response') ) {
	if ( $resp->code() == HTTP_I_AM_A_TEAPOT ) {
	    $got = $loader->( $resp->content() );
	} elsif ( $resp->is_success() ) {
	    $got = $resp->content();
	} else {
	    $got = $resp->status_line();
	}
    } else {
	$got = $resp;
    }

    @_ = ($got, $query, $name);
    goto &is_deeply;
}

sub year () {
    return (localtime)[5] + 1900;
}

1;
