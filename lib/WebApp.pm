package WebApp;

# Общие модули - синтаксис, кодировки итд
use 5.018; ## no critic (ProhibitImplicitImport)
use strict;
use warnings;
use utf8;
use open qw (:std :utf8);

# Модули для работы приложения
use Clone qw (clone);
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
my $fwd_cnt = 5;

if (defined $c->{'forward_max'}) {
	$fwd_cnt = $c->{'forward_max'};
}

# Основной парсер
my $parse_message = sub {
	my $self = shift;
	my $m    = shift;

	$log->debug ('[DEBUG] Incoming message ' . Dumper ($m));

	unless (defined $m->{message}) {
		$log->error (sprintf 'Unable to process unknown message: %s', $m->{message});
		return;
	}

	my $answer         = clone ($m);
	$answer->{from}    = 'webapp';
	$answer->{message} = undef;

	my $send_to = $m->{plugin};
	my $reply;

	# Если $answer->{misc}->{answer} не существует, то проставим его как 1, предполагаем, что по-умолчанию ответ от нас
	# всё-таки ожидают. Если что - уточним ниже.
	if (defined $answer->{misc}) {
		unless (defined $answer->{misc}->{answer}) {
			$answer->{misc}->{answer} = 1;
		}

		unless (defined $answer->{misc}->{bot_nick}) {
			$answer->{misc}->{bot_nick} = undef;
		}

		unless (defined $answer->{misc}->{csign}) {
			$answer->{misc}->{csign} = '!';
		}

		unless (defined $answer->{misc}->{fwd_cnt}) {
			$answer->{misc}->{fwd_cnt} = 1;
		} else {
			if ($answer->{misc}->{fwd_cnt} > $fwd_cnt) {
				$log->error ('[ERROR] Forward loop detected, discarding message.');
				$log->debug (Dumper $m);
				return;
			} else {
				$answer->{misc}->{fwd_cnt}++;
			}
		}

		unless (defined $answer->{misc}->{good_morning}) {
			$answer->{misc}->{good_morning} = 0;
		}

		unless (defined $answer->{misc}->{msg_format}) {
			$answer->{misc}->{msg_format} = 0;
		}

		unless (defined $answer->{misc}->{username}) {
			$answer->{misc}->{username} = 'user';
		}
	} else {
		$answer->{misc}->{answer} = 1;
		$answer->{misc}->{bot_nick} = undef;
		$answer->{misc}->{csign} = $c->{csign};
		$answer->{misc}->{fwd_cnt} = 1;
		$answer->{misc}->{good_morning} = 0;
		$answer->{misc}->{msg_format} = 0;
		$answer->{misc}->{username} = 'user';
	}

	if (length $m->{message} <= length $answer->{misc}->{csign}) {
		$log->info (sprintf 'Unable to process unknown message: %s', $m->{message});
		return;
	}

	if (substr ($m->{message}, 0, length ($answer->{misc}->{csign})) ne $answer->{misc}->{csign}) {
		$log->info (sprintf 'Unable to process unknown message: %s', $m->{message});
		return;
	}

	my $cmd = substr $m->{message}, length ($answer->{misc}->{csign});

	if ($cmd eq 'buni') {
		if (($m->{plugin} eq 'telegram')  &&  $answer->{misc}->{msg_format}) {
			$reply = sprintf '[buni](%s)', Buni ();
		} else {
			$reply = Buni ();
		}
	} elsif ($cmd eq 'anek' || $cmd eq 'анек' || $cmd eq 'анекдот') {
		if (($m->{plugin} eq 'telegram')  &&  $answer->{misc}->{msg_format}) {
			$reply = "```\n" . Anek () . "\n```";
		} else {
			$reply = Anek ();
		}
	} elsif ($cmd eq 'cat' || $cmd eq 'кис') {
		if (($m->{plugin} eq 'telegram')  &&  $answer->{misc}->{msg_format}) {
			my @cats = ('龴ↀ◡ↀ龴', '=^..^=', '≧◔◡◔≦ ','^ↀᴥↀ^');
			$reply = sprintf '[%s](%s)', $cats[irand ($#cats + 1)], Kitty ();
		} else {
			$reply = Kitty ();
		}
	} elsif ($cmd eq 'drink' || $cmd eq 'праздник') {
		$reply = Drink ();
	} elsif ($cmd eq 'fox' || $cmd eq 'лис') {
		if (($m->{plugin} eq 'telegram')  &&  $answer->{misc}->{msg_format}) {
			$reply = sprintf '[-^^,--,~](%s)', Fox ();
		} else {
			$reply = Fox ();
		}
	} elsif ($cmd eq 'frog' || $cmd eq 'лягушка') {
		if (($m->{plugin} eq 'telegram')  &&  $answer->{misc}->{msg_format}) {
			my @art = qw (frog toad лягушка);
			$reply = sprintf '[%s](%s)', $art [irand ($#art + 1)], Frog ();
		} else {
			$reply = Frog ();
		}
	} elsif ($cmd eq 'horse' || $cmd eq 'лошадь' || $cmd eq 'лошадка') {
		if (($m->{plugin} eq 'telegram')  &&  $answer->{misc}->{msg_format}) {
			my @art = qw (horse лошадь лошадка);
			$reply = sprintf '[%s](%s)', $art [irand ($#art + 1)], Horse ();
		} else {
			$reply = Horse ();
		}
	} elsif ($cmd eq 'monkeyuser') {
		if (($m->{plugin} eq 'telegram')  &&  $answer->{misc}->{msg_format}) {
			$reply = sprintf '[monkeyuser](%s)', Monkeyuser ();
		} else {
			$reply = Monkeyuser ();
		}
	} elsif ($cmd eq 'owl' || $cmd eq 'сова' || $cmd eq 'сыч') {
		if (($m->{plugin} eq 'telegram')  &&  $answer->{misc}->{msg_format}) {
			$reply = sprintf '[{ O v O }](%s)', Owl ();
		} else {
			$reply = Owl ();
		}
	} elsif ($cmd eq 'rabbit' || $cmd eq 'bunny' || $cmd eq 'кролик') {
		if (($m->{plugin} eq 'telegram')  &&  $answer->{misc}->{msg_format}) {
			$reply = sprintf '[(\_/)](%s)', Rabbit ();
		} else {
			$reply = Rabbit ();
		}
	} elsif ($cmd eq 'snail' || $cmd eq 'улитка') {
		if (($m->{plugin} eq 'telegram')  &&  $answer->{misc}->{msg_format}) {
			my @art = qw ('-'_@_ @╜ @_'-');
			$reply = sprintf '[%s](%s)', $art [irand ($#art + 1)], Snail ();
		} else {
			$reply = Snail ();
		}
	} elsif ($cmd eq 'xkcd') {
		if (($m->{plugin} eq 'telegram')  &&  $answer->{misc}->{msg_format}) {
			$reply = sprintf '[xkcd](%s)', Xkcd ();
		} else {
			$reply = Xkcd ();
		}
	} elsif ($cmd =~ /^(w|weather|п|погода|погодка|погадка)\s+(.+)$/gui) {
		my $city = $2;
		$reply = Weather ($city);
	} elsif ($cmd eq 'tits'    ||
             $cmd eq 'boobs'   ||
             $cmd eq 'tities'  ||
             $cmd eq 'boobies' ||
             $cmd eq 'сиси'    ||
             $cmd eq 'сисечки') {
		if ($m->{plugin} eq 'telegram') {
			my @art = ('(. )( .)', '(  . Y .  )', '(o)(o)', '( @ )( @ )', '(.)(.)');
			my $oboobs = Oboobs ();
			$reply = sprintf '[%s](%s)', $art [irand ($#art + 1)], $oboobs;
			$answer->{misc}->{msg_format} = 1;
		} else {
			$reply = Oboobs ();
		}
	} elsif ($cmd eq 'butt'  ||
		     $cmd eq 'booty' ||
		     $cmd eq 'ass'   ||
		     $cmd eq 'попа'  ||
		     $cmd eq 'попка') {
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

	Mojo::IOLoop::Signal->on (TERM => $__signal_handler);
	Mojo::IOLoop::Signal->on (INT  => $__signal_handler);

	do { Mojo::IOLoop->start } until Mojo::IOLoop->is_running;
	return;
}

1;

# vim: set ft=perl noet ai ts=4 sw=4 sts=4:
