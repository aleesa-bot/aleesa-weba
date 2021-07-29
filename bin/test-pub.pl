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
use Mojo::Redis;
use Conf qw (LoadConf);

my $c = LoadConf ();

my $redis = Mojo::Redis->new (
	sprintf 'redis://%s:%s/1', $c->{server}, $c->{port}
);

my $pubsub = $redis->pubsub;
my @messages = ('!cat', '!fox', '!drink', '!monkeyuser', '!xkcd');

while (1) {
	$pubsub->json ('webapp:TEST')->notify (
		'webapp:TEST' => {
			from    => 'test-pub.pl',
			userid  => 'test_user',
			chatid  => '#test_chat',
			plugin  => 'dummy_plugin',
			message => $messages [int (rand ($#messages + 1))]
		}
	);

	sleep 3;
}

exit 0;
