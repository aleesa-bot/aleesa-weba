package WebApp;

# общие модули - синтаксис, кодировки итд
use 5.018;
use strict;
use warnings;
use utf8;
use open qw (:std :utf8);

# модули для работы приложения
use Log::Any qw ($log);
use Mojo::Redis;
use Mojo::IOLoop;

# плагины web-клиентов
use Buni qw (Buni);
use Conf qw (LoadConf);
use Drink qw (Drink);
use Fox qw (Fox);
use Image qw (Rabbit Owl Frog Horse Snail);
use Kitty qw (Kitty);
use Monkeyuser qw (Monkeyuser);
use Weather qw (Weather);
use Xkcd qw (Xkcd);

use version; our $VERSION = qw (1.0);
use Exporter qw (import);
our @EXPORT_OK = qw (RunWebApp);

my $c = LoadConf ();

# основной парсер
my $parse_message = sub {
	my $self = shift;
	my $m = shift;
	my $answer = $m;
	my $send_to = $answer->{from};

	if (substr ($m->{message}, 1) eq 'buni') {
		$answer->{message} = Buni ();
	} elsif (substr ($m->{message}, 1) eq 'cat' || substr ($m->{message}, 1) eq 'кис') {
		$answer->{message} = Kitty ();
	} elsif (substr ($m->{message}, 1) eq 'drink' || substr ($m->{message}, 1) eq 'праздник') {
		$answer->{message} = Drink ();
	} elsif (substr ($m->{message}, 1) eq 'fox' || substr ($m->{message}, 1) eq 'лис') {
		$answer->{message} = Fox ();
	} elsif (substr ($m->{message}, 1) eq 'frog' || substr ($m->{message}, 1) eq 'лягушка') {
		$answer->{message} = Frog ();
	} elsif (substr ($m->{message}, 1) eq 'horse' || substr ($m->{message}, 1) eq 'лошадь' || substr ($m->{message}, 1) eq 'лошадка') {
		$answer->{message} = Horse ();
	} elsif (substr ($m->{message}, 1) eq 'monkeyuser') {
		$answer->{message} = Monkeyuser ();
	} elsif (substr ($m->{message}, 1) eq 'owl' || substr ($m->{message}, 1) eq 'сова' || substr ($m->{message}, 1) eq 'сыч') {
		$answer->{message} = Owl ();
	} elsif (substr ($m->{message}, 1) eq 'rabbit' || substr ($m->{message}, 1) eq 'bunny' || substr ($m->{message}, 1) eq 'кролик') {
		$answer->{message} = Rabbit ();
	} elsif (substr ($m->{message}, 1) eq 'snail' || substr ($m->{message}, 1) eq 'улитка') {
		$answer->{message} = Snail ();
	} elsif (substr ($m->{message}, 1) eq 'xkcd') {
		$answer->{message} = Xkcd ();
	} elsif (substr ($m->{message}, 1, 2) eq 'w ' || substr ($m->{message}, 1, 2) eq 'п ') {
		my $city = substr $m->{message}, 2;
		$answer->{message} = Weather ($city);
	} else {
		$log->info (sprintf 'Unable to process unknown message: %s', $m->{message});
	}

	$self->json ($send_to)->notify (
		$send_to => {
			from    => $answer->{from},
			userid  => $answer->{userid},
			chatid  => $answer->{chatid},
			plugin  => $answer->{plugin},
			message => $answer->{message}
		}
	);

	return;
};

# main loop, он же event loop
sub RunWebApp {
	my $redis = Mojo::Redis->new (
		sprintf 'redis://%s:%s/1', $c->{server}, $c->{port}
	);

	my $pubsub = $redis->pubsub;
	my $sub;

	$pubsub->listen (
		# Вот такая ебическая конструкция для авто-подписывания на все новые каналы.
		# Странное ограничение, при котором на шаблон каналов можно подписаться только, подписавшись на каждый из
		# каналов. То есть подписка создаётся по запросу. В AnyEvent::Redis подписаться можно сразу на * :(
		# Но конкретно в моём случае этот момент неважен, т.к. подразумевается, что каналы будут добавляться, но не 
		# будут убавляться.
		'webapp:*' => sub {
			my ($ps, $channel) = @_ ;

			unless (defined $sub->{$channel}) {
				$log->info ("Subscribing to $channel");

				$sub->{$channel} = $ps->json ($channel)->listen (
					$channel => sub { $parse_message->(@_); }
				);
			}
		}
	);

	do { Mojo::IOLoop->start } until Mojo::IOLoop->is_running;
	return;
}

1;

# vim: set ft=perl noet ai ts=4 sw=4 sts=4:
