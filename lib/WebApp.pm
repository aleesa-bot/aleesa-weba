package WebApp;

# Общие модули - синтаксис, кодировки итд
use 5.018; ## no critic (ProhibitImplicitImport)
use strict;
use warnings;
use utf8;
use open qw (:std :utf8);

# Модули для работы приложения
use Data::Dumper qw (Dumper);
use Log::Any qw ($log);
use Math::Random::Secure qw (irand);
use Mojo::Redis ();
use Mojo::IOLoop ();
use Mojo::IOLoop::Signal ();

# Плагины web-клиентов
use Conf qw (LoadConf);
use WebApp::Client qw (Anek Buni Drink Monkeyuser Kitty Fox Oboobs Obutts Rabbit Owl Frog Horse Snail Xkcd Weather);

use version; our $VERSION = qw (1.0);
use Exporter qw (import);
our @EXPORT_OK = qw (RunWebApp);

my $c = LoadConf ();
my $fwd_cnt = $c->{'forward_max'} // 5;

# Основной парсер
my $parse_message = sub {
	my $self = shift;
	my $m = shift;
	my $answer = $m;
	$answer->{from} = 'webapp';
	my $send_to = $m->{plugin};
	my $reply;

	if (defined $answer->{misc}) {
		unless (defined $answer->{misc}->{fwd_cnt}) {
			$answer->{misc}->{fwd_cnt} = 1;
		} else {
			if ($answer->{misc}->{fwd_cnt} > $fwd_cnt) {
				$log->error ('Forward loop detected, discarding message.');
				$log->debug (Dumper $m);
				return;
			} else {
				$answer->{misc}->{fwd_cnt}++;
			}
		}

		unless (defined $answer->{misc}->{answer}) {
			$answer->{misc}->{answer} = 1;
		}

		unless (defined $answer->{misc}->{csign}) {
			$answer->{misc}->{csign} = '!';
		}
	} else {
		$answer->{misc}->{answer} = 1;
		$answer->{misc}->{csign} = '!';
		$answer->{misc}->{msg_format} = 0;
	}

	$log->debug ('[DEBUG] Incoming message ' . Dumper($m));

	if (substr ($m->{message}, 1) eq 'buni') {
		if (($m->{plugin} eq 'telegram')  &&  $answer->{misc}->{msg_format}) {
			$reply = sprintf '[buni](%s)', Buni ();
		} else {
			$reply = Buni ();
		}
	} elsif (substr ($m->{message}, 1) eq 'anek' || substr ($m->{message}, 1) eq 'анек' || substr ($m->{message}, 1) eq 'анекдот') {
		if (($m->{plugin} eq 'telegram')  &&  $answer->{misc}->{msg_format}) {
			$reply = "```\n" . Anek () . "\n```";
		} else {
			$reply = Anek ();
		}
	} elsif (substr ($m->{message}, 1) eq 'cat' || substr ($m->{message}, 1) eq 'кис') {
		if (($m->{plugin} eq 'telegram')  &&  $answer->{misc}->{msg_format}) {
			my @cats = ('龴ↀ◡ↀ龴', '=^..^=', '≧◔◡◔≦ ','^ↀᴥↀ^');
			$reply = sprintf '[%s](%s)', $cats[irand ($#cats + 1)], Kitty ();
		} else {
			$reply = Kitty ();
		}
	} elsif (substr ($m->{message}, 1) eq 'drink' || substr ($m->{message}, 1) eq 'праздник') {
		$reply = Drink ();
	} elsif (substr ($m->{message}, 1) eq 'fox' || substr ($m->{message}, 1) eq 'лис') {
		if (($m->{plugin} eq 'telegram')  &&  $answer->{misc}->{msg_format}) {
			$reply = sprintf '[-^^,--,~](%s)', Fox ();
		} else {
			$reply = Fox ();
		}
	} elsif (substr ($m->{message}, 1) eq 'frog' || substr ($m->{message}, 1) eq 'лягушка') {
		if (($m->{plugin} eq 'telegram')  &&  $answer->{misc}->{msg_format}) {
			my @art = qw (frog toad лягушка);
			$reply = sprintf '[%s](%s)', $art [irand ($#art + 1)], Frog ();
		} else {
			$reply = Frog ();
		}
	} elsif (substr ($m->{message}, 1) eq 'horse' || substr ($m->{message}, 1) eq 'лошадь' || substr ($m->{message}, 1) eq 'лошадка') {
		if (($m->{plugin} eq 'telegram')  &&  $answer->{misc}->{msg_format}) {
			my @art = qw (horse лошадь лошадка);
			$reply = sprintf '[%s](%s)', $art [irand ($#art + 1)], Horse ();
		} else {
			$reply = Horse ();
		}
	} elsif (substr ($m->{message}, 1) eq 'monkeyuser') {
		if (($m->{plugin} eq 'telegram')  &&  $answer->{misc}->{msg_format}) {
			$reply = sprintf '[monkeyuser](%s)', Monkeyuser ();
		} else {
			$reply = Monkeyuser ();
		}
	} elsif (substr ($m->{message}, 1) eq 'owl' || substr ($m->{message}, 1) eq 'сова' || substr ($m->{message}, 1) eq 'сыч') {
		if (($m->{plugin} eq 'telegram')  &&  $answer->{misc}->{msg_format}) {
			$reply = sprintf '[{ O v O }](%s)', Owl ();
		} else {
			$reply = Owl ();
		}
	} elsif (substr ($m->{message}, 1) eq 'rabbit' || substr ($m->{message}, 1) eq 'bunny' || substr ($m->{message}, 1) eq 'кролик') {
		if (($m->{plugin} eq 'telegram')  &&  $answer->{misc}->{msg_format}) {
			$reply = sprintf '[(\_/)](%s)', Rabbit ();
		} else {
			$reply = Rabbit ();
		}
	} elsif (substr ($m->{message}, 1) eq 'snail' || substr ($m->{message}, 1) eq 'улитка') {
		if (($m->{plugin} eq 'telegram')  &&  $answer->{misc}->{msg_format}) {
			my @art = qw ('-'_@_ @╜ @_'-');
			$reply = sprintf '[%s](%s)', $art [irand ($#art + 1)], Snail ();
		} else {
			$reply = Snail ();
		}
	} elsif (substr ($m->{message}, 1) eq 'xkcd') {
		if (($m->{plugin} eq 'telegram')  &&  $answer->{misc}->{msg_format}) {
			$reply = sprintf '[xkcd](%s)', Xkcd ();
		} else {
			$reply = Xkcd ();
		}
	} elsif (substr ($m->{message}, 1, 2) eq 'w ' || substr ($m->{message}, 1, 2) eq 'п ') {
		my $city = substr $m->{message}, 2;
		$reply = Weather ($city);
	} elsif (substr ($m->{message}, 1, 8) eq 'weather ' || substr ($m->{message}, 1, 8) eq 'погодка ' || substr ($m->{message}, 1, 8) eq 'погадка ') {
		my $city = substr $m->{message}, 9;
		$reply = Weather ($city);
	} elsif (substr ($m->{message}, 1, 7) eq 'погода ') {
		my $city = substr $m->{message}, 8;
		$reply = Weather ($city);
	} elsif (substr ($m->{message}, 1) eq 'tits'    ||
             substr ($m->{message}, 1) eq 'boobs'   ||
             substr ($m->{message}, 1) eq 'tities'  ||
             substr ($m->{message}, 1) eq 'boobies' ||
             substr ($m->{message}, 1) eq 'сиси'    ||
             substr ($m->{message}, 1) eq 'сисечки') {
		if ($m->{plugin} eq 'telegram') {
			my @art = ('(. )( .)', '(  . Y .  )', '(o)(o)', '( @ )( @ )', '(.)(.)');
			my $oboobs = Oboobs ();
			$reply = sprintf '[%s](%s)', $art [irand ($#art + 1)], $oboobs;
			$answer->{misc}->{msg_format} = 1;
		} else {
			$reply = Oboobs ();
		}
	} elsif (substr ($m->{message}, 1) eq 'butt'  ||
		     substr ($m->{message}, 1) eq 'booty' ||
		     substr ($m->{message}, 1) eq 'ass'   ||
		     substr ($m->{message}, 1) eq 'попа'  ||
		     substr ($m->{message}, 1) eq 'попка') {
		if ($m->{plugin} eq 'telegram') {
			my @art = ('(__(__)', '(_!_)', '(__.__)');
			my $obutts = Obutts ();
			$reply = sprintf '[%s](%s)', $art [irand ($#art + 1)], $obutts;
			$answer->{misc}->{msg_format} = 1;
		} else {
			$reply = Oboobs ();
		}
	} else {
		$log->info (sprintf 'Unable to process unknown message: %s', $m->{message});
	}

	if (defined $reply) {
		$answer->{message} = $reply;
		$log->debug ("[DEBUG] Sending message to channel $send_to " . Dumper ($answer));

		$self->json ($send_to)->notify (
			$send_to => $answer,
		);
	}

	return;
};

my $__signal_handler = sub {
	my ($self, $name) = @_;
	$log->info ("[INFO] Caught a signal $name");

	if (defined $main::pidfile && -e $main::pidfile) {
		unlink $main::pidfile;
	}

	exit 0;
};


# main loop, он же event loop
sub RunWebApp {
	$log->info ("[INFO] Connecting to $c->{server}, $c->{port}");

	my $redis = Mojo::Redis->new (
		sprintf 'redis://%s:%s/1', $c->{server}, $c->{port},
	);

	$log->info ('[INFO] Registering connection-event callback');

	$redis->on (
		connection => sub {
			my ($r, $connection) = @_;

			$log->info ('[INFO] Triggering callback on new client connection');

			# Залоггируем ошибку, если соединение внезапно порвалось.
			$connection->on (
				error => sub {
					my ($conn, $error) = @_;
					$log->error ("[ERROR] Redis connection error: $error");
					return;
				},
			);

			return;
		},
	);

	my $pubsub = $redis->pubsub;
	my $sub;
	$log->info ('[INFO] Subscribing to redis channels');

	foreach my $channel (@{$c->{channels}}) {
		$log->debug ("[DEBUG] Subscribing to $channel");

		$sub->{$channel} = $pubsub->json ($channel)->listen (
			$channel => sub { $parse_message->(@_); },
		);
	}

	Mojo::IOLoop::Signal->on (
		TERM => $__signal_handler,
		INT  => $__signal_handler,
	);

	do { Mojo::IOLoop->start } until Mojo::IOLoop->is_running;
	return;
}

1;

# vim: set ft=perl noet ai ts=4 sw=4 sts=4:
