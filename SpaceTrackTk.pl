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

use Astro::SpaceTrack;
use Tk;

my @pad = qw{-padx 5 -pady 5};

my $st = Astro::SpaceTrack->new ();

my ($mw, $row, $col);
$row = $col = 0;
my ($user, $pwd, $rslt);

my $banner = !$st->get ('banner')->content;

sub banner {
my $mw = MainWindow->new (-title => 'Front Matter');
my $text = $st->banner->content;
$text =~ s/^\s+//s;
$text =~ s/[\s\n]+$//s;
$mw->Label (-text => $text)->pack (-side => 'top', @pad);
$mw->Button (-text => 'OK', -command => sub {$mw->destroy})
    ->pack (-side => 'bottom', @pad);

MainLoop;

1;
}

$rslt = $st->login ();
unless ($rslt && $rslt->is_success) {

    $banner ||= banner ();

    $user = $pwd = '';
    $mw = MainWindow->new (-title => 'Log in to Space Track');

    $mw->Label (-text => 'Username:')
	->grid (-row => $row, -column => $col++, -sticky => 'e', @pad);
    $mw->Entry (-relief => 'sunken', -textvariable => \$user)
	->grid (-row => $row, -column => $col++, -sticky => 'w', @pad);
    $row++; $col = 0;
    $mw->Label (-text => 'Password:')
	->grid (-row => $row, -column => $col++, -sticky => 'e', @pad);
    $mw->Entry (-relief => 'sunken', -textvariable => \$pwd, -show => '*')
	->grid (-row => $row, -column => $col++, -sticky => 'w', @pad);
    $row++; $col = 0;
    $mw->Button (-text => 'Log in', -command => sub {
	$rslt = $st->login (username => $user, password => $pwd);
	$rslt->is_success and do {
	    $mw->destroy;
	    return;
	    };
	$mw->messageBox (-icon => 'error', -type => 'RetryCancel',
		-title => 'Login failure', -message => $rslt->status_line)
		eq 'Cancel' and do {
	    $mw->destroy;
	    return;
	    };
	})
	->grid (-row => $row, -column => $col, -columnspan => 2, @pad);

    MainLoop;

    }

exit unless $rslt && $rslt->is_success;

$banner ||= banner ();

my ($command, $current, $data, $label, $names);
$command = $data = $label = '';
$mw = MainWindow->new (-title => 'Retrieve Space Track data');

my %dsdata;
my %dslbl = (
    celestrak => 'Catalog name:',
    spacetrack => 'Catalog name:',
    file => 'Catalog file:',
    search_name => 'Name to search for:',
    retrieve => 'ID(s) to retrieve:',
    );
my $dsfile_widget = $mw->Frame;
$dsfile_widget->Entry (-relief => 'sunken', -textvariable => \$dsdata{file})
	->grid (-row => 0, -column => 0, -padx => 5);
$dsfile_widget->Button (-text => 'Find file ...', -command => sub {
	my $file = $mw->getOpenFile (-filetypes => [
		['Text files', '.txt', 'TEXT'],
		['All files', '*'],
		], -initialfile => $dsdata{$command},
		-defaultextension => '.txt');
	$dsdata{file} = $file if $file;
	})->grid (-row => 0, -column => 1, -padx => 5);
my %dswdgt = (
    celestrak => $mw->Optionmenu (-options => ($st->names ('celestrak'))[1],
	-variable => \$dsdata{celestrak}),
    spacetrack => $mw->Optionmenu (-options => ($st->names ('spacetrack'))[1],
	-variable => \$dsdata{spacetrack}),
    file => $dsfile_widget,
    search_name => $mw->Entry (-relief => 'sunken', -textvariable => \$dsdata{search_name}),
    retrieve => $mw->Entry (-relief => 'sunken', -textvariable => \$dsdata{retrieve}),
    );
my %dsxfrm = (
    retrieve => sub {(split '\s+', $_[0])},
    );
$row = $col = 0;
$mw->Label (-text => 'Object ID source:')
	->grid (-row => $row, -column => $col++, -sticky => 'e', @pad);
$mw->Optionmenu (-options => [
	['Celestrak catalog' => 'celestrak'],
	['Space Track catalog' => 'spacetrack'],
	['Local file catalog' => 'file'],
	['Space Track name lookup' => 'search_name'],
	['Space Track retrieval by ID' => 'retrieve'],
    ], -variable => \$command, -command => sub {
	$current and $current->gridForget ();
	$label = $dslbl{$command};
	$current = $dswdgt{$command} or return;
	$current->grid (-row => 1, -column => 1, -sticky => 'w', @pad);
	})->grid (-row => $row, -column => $col++, -sticky => 'w', @pad);

$row++; $col = 0;
$label = $dslbl{$command};
$mw->Label (-textvariable => \$label)
	->grid (-row => $row, -column => $col++, -sticky => 'e', @pad);
$current = $dswdgt{$command};
$current->grid (-row => $row, -column => $col++, -sticky => 'w', @pad);

$row++; $col = 0;
$mw->Label (-text => 'Include common names:')
	->grid (-row => $row, -column => $col++, -sticky => 'e', @pad);
$mw->Checkbutton (-variable => \$names, -relief => 'flat', -command => sub {
	$st->set (with_name => $names);
	})
	->grid (-row => $row, -column => $col++, -sticky => 'w', @pad);
$names = !!$st->get ('with_name')->content;

$row++; $col = 0;
my $bf = $mw->Frame->grid (-row => $row, -column => 0, -columnspan => 2, -sticky => 'ew');
$bf->Button (-text => 'Exit', -command => sub {$mw->destroy})
    ->grid (-row => 0, -column => $col++, -sticky => 'ew', @pad);
$bf->Button (-text => 'View data ...', -command => sub {
	my $vw = $mw->Toplevel ();
	my $tx = $vw->Scrolled ('Text', -relief => 'sunken', -scrollbars => 'oe');
	$tx->pack (-expand => 1, -fill => 'both');
	$rslt = $st->$command ($dsxfrm{$command} ?
		($dsxfrm{$command}->($dsdata{$command})) :
		$dsdata{$command});
	if ($rslt->is_success) {
	    $tx->insert ('0.0', $rslt->content);
	    $vw->title ("$command $dsdata{$command}");
	    }
	  else {
	    $mw->messageBox (-icon => 'error', -type => 'OK',
		-title => 'Data fetch error', -message => $rslt->status_line);
	    }
	})
	->grid (-row => 0, -column => $col++, -sticky => 'ew', @pad);
$bf->Button (-text => 'Save data ...', -command => sub {
	my $file = $mw->getSaveFile (-filetypes => [
		['Text files', '.txt', 'TEXT'],
		['All files', '*'],
		], -initialfile => $dsdata{$command},
		-defaultextension => '.txt');
	return unless defined $file && $file ne '';
	$rslt = $st->$command ($dsxfrm{$command} ?
		($dsxfrm{$command}->($dsdata{$command})) :
		$dsdata{$command});
	if ($rslt->is_success) {
	    my $fh;
	    $fh = FileHandle->new (">$file")
		and print $fh $rslt->content
		or $mw->messageBox (-icon => 'error', -type => 'OK',
		-title => 'File open error', -message => $!);
	    }
	  else {
	    $mw->messageBox (-icon => 'error', -type => 'OK',
		-title => 'Data fetch error', -message => $rslt->status_line);
	    }
	})
	->grid (-row => 0, -column => $col++, -sticky => 'ew', @pad);
##	->grid (-row => $row, -column => $col++, @pad);

=pod

$mw->Button (-text => 'Exit', -command => sub {$mw->destroy})
	->grid (-row => $row, -column => $col++, @pad);
$mw->Button (-text => 'Save data ...', -command => sub {
	my $file = $mw->getSaveFile (-filetypes => [
		['Text files', '.txt', 'TEXT'],
		['All files', '*'],
		], -initialfile => $dsdata{$command},
		-defaultextension => '.txt');
	return unless defined $file && $file ne '';
	$rslt = $st->$command ($dsxfrm{$command} ?
		($dsxfrm{$command}->($dsdata{$command})) :
		$dsdata{$command});
	if ($rslt->is_success) {
	    my $fh;
	    $fh = FileHandle->new (">$file")
		and print $fh $rslt->content
		or $mw->messageBox (-icon => 'error', -type => 'OK',
		-title => 'File open error', -message => $!);
	    }
	  else {
	    $mw->messageBox (-icon => 'error', -type => 'OK',
		-title => 'Data fetch error', -message => $rslt->status_line);
	    }
	})
	->grid (-row => $row, -column => $col++, @pad);

=cut

MainLoop;
