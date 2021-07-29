#!/usr/bin/perl

use 5.018;
use strict;
use warnings;
use utf8;
use open qw (:std :utf8);
use English qw ( -no_match_vars );
use version; our $VERSION = qw (1.0);

my $workdir;

# before we run, change working dir
BEGIN {
	use Cwd qw (chdir abs_path);
	my @CWD = split /\//xms, abs_path ($PROGRAM_NAME);
	if ($#CWD > 1) { $#CWD = $#CWD - 2; }
	$workdir = join '/', @CWD;
	chdir $workdir;
}

use lib ("$workdir/lib", "$workdir/vendor_perl", "$workdir/vendor_perl/lib/perl5");
use Carp qw (carp);
use Mojo::Redis;
use Data::Dumper;

use Conf qw (LoadConf);

my $c = LoadConf ();

my $redis = Mojo::Redis->new (
	sprintf 'redis://%s:%s/1', $c->{server}, $c->{port}
);

my $pubsub = $redis->pubsub;

$pubsub->json('webapp:TEST')->listen (
	'webapp:TEST' => sub {
		my $self = shift;
		my $message = shift;
		carp Dumper ($message);
	 }
);

$pubsub->json('broadcast')->listen (
	'broadcast' => sub {
		my $self = shift;
		my $message = shift;
		carp Dumper ($message);
	}
);

Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
