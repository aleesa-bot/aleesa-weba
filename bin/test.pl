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
my @messages = ('!cat', '!fox', '!drink', '!monkeyuser', '!xkcd');
my $c = LoadConf ();

my $redis = Mojo::Redis->new (
	sprintf 'redis://%s:%s/1', $c->{server}, $c->{port}
);

my $pubsub = $redis->pubsub;

# Добавим коллбэк на приход события в test.
$pubsub->json ('test')->listen (
	'test' => sub { 
#		my $self = shift;
#		my $message = shift;
		carp Dumper (@_);
	 }
);

# Добавим коллбэк на приход события в broadcast.
$pubsub->json ('broadcast')->listen (
	'broadcast' => sub {
#		my $self = shift;
#		my $message = shift;
		carp Dumper (@_);
	}
);

# Попробуем потыкать в наш сервер приложений разными сообщениями.
# Этот коллбэк запускается по таймеру, раз в 3 секунды.
Mojo::IOLoop->recurring (
	3 => sub {
		my $channel = 'test';
		if (int (rand (2))) { $channel = 'broadcast' }

		$pubsub->json ('webapp:test')->notify (
			'webapp:test' => {
				from    => $channel, # <- отвечаем в этот pubsub-канал
				userid  => 'test_user',
				chatid  => '#test_chat',
				plugin  => 'dummy_plugin',
				message => $messages [int (rand ($#messages + 1))]
			}
		);
	}
);

# поприветствуем наше тестируемое приложение, это необходимо чтобы оно подписалось на нас.
$pubsub->json ('webapp:TEST')->notify (
	'webapp:TEST' => {
		from    => 'test', # <- отвечаем в этот pubsub-канал
		userid  => 'test_user',
		chatid  => '#test_chat',
		plugin  => 'dummy_plugin',
		message => 'Hello'
	}
);

# Приветствовать test не нужно, так как он безо всякой эвристики подписан и на себя и на broadcast

# Все нужные обработчики напиханы в ивент-луп, можно его запускать.
Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
