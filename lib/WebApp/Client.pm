package WebApp::Client;

use 5.018;
use strict;
use warnings;
use utf8;
use open qw (:std :utf8);
use English qw ( -no_match_vars );

use Carp qw (carp cluck);
use CHI;
use CHI::Driver::BerkeleyDB;
use DateTime;
use Encode;
use HTML::TokeParser;
use JSON::XS;
use Log::Any qw ($log);
use Math::Random::Secure qw (irand);
use Mojo::UserAgent;
use Mojo::UserAgent::Cached;
use Mojo::Util qw (trim);
use POSIX qw (strftime);
use URI::URL;

use Conf qw (LoadConf);
use WebApp::Client::API::Flickr qw (FlickrByTags);

use version; our $VERSION = qw (1.0);
use Exporter qw (import);
our @EXPORT_OK = qw (Anek Buni Drink Monkeyuser Kitty Fox Oboobs Obutts Rabbit Owl Frog Horse Snail Xkcd Weather);

my @MONTH = qw (yanvar fevral mart aprel may iyun iyul avgust sentyabr oktyabr noyabr dekabr);
my $c = LoadConf ();
my $cachedir = $c->{cachedir};

my @useragents = _get_ua_list ();

sub _get_ua_list {
	my $file = $c->{useragentfile};
	my $file_opened = 1;

	open my $FILEHANDLE, '<', $file || do {
		carp "[ERROR] No browser useragent list at $file: $OS_ERROR\n";
		$file_opened = 0;
	};

	my @ua_list;

	if ($file_opened) {
		while (my $str = <$FILEHANDLE>) {
			chomp $str;
			next unless $str eq '';
			push @ua_list, $str;
		}

		close $FILEHANDLE;                                       ## no critic (InputOutput::RequireCheckedSyscalls
		return @ua_list;
	}

	if ($#ua_list < 31) {
		carp "[ERROR] Useragent list in $file have less than 31 enties, discarding it\n";
		$#ua_list = -1;
	} elsif ($#ua_list > 31) {
		carp "[INFO] Useragent list in $file have more than 31 enties, truncating it to 31 entries\n";
		$#ua_list = 31;
	}

	return @ua_list;
}

sub urlencode {
	my $str = shift;

	unless (defined $str) {
		cluck '[ERROR] Str is undefined';
		return '';
	}

	my $urlobj = url $str;
	return $urlobj->as_string;
}

sub Anek {
	my $r;
	my $ret = 'Все рассказчики анекдотов отдыхают';
	my $got_anek = 0;

	for (1..3) {
		for (1..3) {
			my $ua  = Mojo::UserAgent->new->connect_timeout (3);
			$ua->max_redirects(3);
			$r = $ua->get ('https://www.anekdot.ru/rss/randomu.html')->result;

			if ($r->is_success) {
				last;
			}

			sleep 2;
		}

		if ($r->is_success) {
			my $json;
			my $response_text = decode ('UTF-8', $r->body);
			my @text = split /\n/, $response_text;

			while (my $str = pop @text) {
				if ($str =~ /^var anekdot_texts \= JSON/) {
					$str = (split /JSON\.parse\(\'/, $str, 2)[1];

					if (defined $str && length ($str) > 10) {
						$json = (split /\';\)/, $str, 2)[0];
						last;
					}
				}
			}

			if (defined $json && length ($json) > 10) {
				$json =~ s/\\"/"/g;
				$json =~ s/\\\\"/\\"/g;
				$json = substr $json, 0, -3;

				my $anek = eval { ${JSON::XS->new->relaxed->decode ($json)}[0] };

				if (defined $anek) {
					my @anek = split /<br>/, $anek;
					$ret = join "\n", @anek;

					if (length ($ret) > 1) {
						$got_anek = 1;
					}
				} else {
					$log->warn (sprintf '[WARN] anekdot.ru server returns incorrect json, full response text message: %s', $response_text);
				}
			} else {
				$log->warn (sprintf '[WARN] anekdot.ru server returns unexpected response text: %s', $r->body);
			}

		} else {
			$log->warn (sprintf '[WARN] anekdot.ru server return status %s with message: %s', $r->code, $r->message);
		}

		if ($got_anek) {
			last;
		}
	}

	return $ret;
}

sub Buni {
	my $r;
	my $ret = 'Нету Buni';

	for (1..3) {
		my $ua  = Mojo::UserAgent->new->connect_timeout (3);
		$ua->max_redirects(3);
		$r = $ua->get ('http://www.bunicomic.com/?random&nocache=1')->result;

		if ($r->is_success) {
			last;
		}

		sleep 2;
	}

	if ($r->is_success) {
		my $p = HTML::TokeParser->new(\$r->body);
		my @a;

		# additional {} required in order "last" to work properly :)
		{
			do {
				$#a = -1;
				@a = $p->get_tag('meta'); ## no critic (Variables::RequireLocalizedPunctuationVars)

				if (defined $a[0][1]->{property} && $a[0][1]->{property} eq 'og:image') {
					$ret = sprintf '[buni](%s)', $a[0][1]->{content};
					last;
				}

			} while ($#{$a[0]} > 1);
		}
	} else {
		$log->warn (sprintf '[WARN] Bunicomic server return status %s with message: %s', $r->code, $r->message);
	}

	return $ret;
}

sub Drink {
	my $r;
	my $ret = 'Не знаю праздников - вджобываю весь день на шахтах, как проклятая.';
	my ($dayNum, $monthNum) = (localtime ())[3, 4];
	my $url = sprintf 'https://kakoysegodnyaprazdnik.ru/baza/%s/%s', $MONTH[$monthNum], $dayNum;

	# Those POSIX assholes just forgot to add unix timestamps without TZ offset, so...
	my ($mday, $mon, $year) = (gmtime ())[3, 4, 5];
	my $offset = strftime ('%z', gmtime ());
	my $offsetMinutes = (substr $offset, -2) * 60;
	my $offsetHours = (substr $offset, 1, 2) * 60 * 60;
	my $offsetSign;

	if ((substr $offset, 0, 1) eq '+') {
		$offsetSign = 1;
	}

	my $expirationDate = DateTime->new (
		year => $year + 1900,
		month => $mon + 1,
		day => $mday,
		hour => 0,
		minute => 0,
		second => 0
	)->add (days => 1)->strftime ('%s');

	if ((substr $offset, 0, 1) eq '+') {
		$expirationDate = $expirationDate - $offsetHours - $offsetMinutes;
	} else {
		$expirationDate = $expirationDate + $offsetHours + $offsetMinutes;
	}

	for (1..3) {
		my $ua = Mojo::UserAgent::Cached->new->connect_timeout (3);
		$ua->cache_agent(
				CHI->new (
				driver             => 'BerkeleyDB',
				root_dir           => $cachedir,
				namespace          => __PACKAGE__,
				expires_at         => $expirationDate,
				expires_on_backend => 1,
			)
		);
		# just to make Mojo::UserAgent::Cached happy
		$ua->logger (Mojo::Log->new (path => '/dev/null', level => 'error'));
		my $useragent = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/98.0.4758.80 Safari/537.36';

		if ($#useragents > 0) {
			$useragent = $useragents [ (localtime ()) [3] ];
		}

		$ua->transactor->name ($useragent);

		$r = $ua->get ($url => {'Accept-Language' => 'ru-RU', 'Accept-Charset' => 'utf-8'})->result;

		if ($r->is_success) {
			last;
		}

		sleep 2;
	}

	if ($r->is_success) {
		my $p = HTML::TokeParser->new(\$r->body);
		my @a;
		my @holyday;

		do {
			$#a = -1;
			@a = $p->get_tag('span'); ## no critic (Variables::RequireLocalizedPunctuationVars)

			if ($#{$a[0]} > 2 && defined $a[0][1]->{itemprop} && $a[0][1]->{itemprop} eq 'text') {
				push @holyday,'* ' . decode ('UTF-8', $p->get_trimmed_text ('/span'));
			}

		} while ($#{$a[0]} > 1);

		if ($#holyday > 0) {
			# cut off something weird, definely not a "holyday"
			$#holyday = $#holyday - 1;
		}

		if ($#holyday > 0) {
			$ret = join "\n", @holyday;
		}
	} else {
		$log->warn (sprintf '[WARN] Kakoysegodnyaprazdnik server return status %s with message: %s', $r->code, $r->message);
	}

	return $ret;
}

sub Monkeyuser {
	my $r;
	my $ret = 'Нету Monkey User-ов, они все спрятались.';
	my @link;

	for (1..3) {
		my $ua  = Mojo::UserAgent->new->connect_timeout (3);
		$r = $ua->get ('https://www.monkeyuser.com/toc/')->result;

		if ($r->is_success) {
			last;
		}

		sleep 2;
	}

	if ($r->is_success) {
		my $p = HTML::TokeParser->new(\$r->body);
		my @a;

		do {
			$#a = -1;
			@a = $p->get_tag('a'); ## no critic (Variables::RequireLocalizedPunctuationVars)

			if (defined $a[0][1]->{class} && $a[0][1]->{class} eq 'lazyload small-image') {
				if (defined $a[0][1]->{'data-src'} && ($a[0][1]->{'data-src'} !~ /adlitteram/)) {
					push @link, $a[0][1]->{'data-src'};
				}
			}

		} while ($#{$a[0]} > 1);

		if ($#link > 0) {
			$ret = sprintf '[MonkeyUser](https://www.monkeyuser.com%s)', $link [irand (1 + $#link)];
		}
	} else {
		$log->warn (sprintf '[WARN] MonkeyUser server return status %s with message: %s', $r->{status}, $r->{reason});
	}

	return $ret;
}

sub Kitty {
	my $r;
	my $ret = 'Нету кошечек, все разбежались.';

	for (1..3) {
		my $ua  = Mojo::UserAgent->new->connect_timeout (3);
		$r = $ua->get ('https://api.thecatapi.com/v1/images/search')->result;

		if ($r->is_success) {
			last;
		}

		sleep 2;
	}

	if ($r->is_success) {
		my $jcat = eval {
			return $r->json;
		};

		unless (defined $jcat) {
			$log->warn ("[WARN] Unable to decode JSON from thecatapi: $EVAL_ERROR");
		} else {
			if ($jcat->[0]->{url}) {
				$ret = $jcat->[0]->{url};
			}
		}
	} else {
		$log->warn (sprintf '[WARN] Thecatapi server return status %s with message: %s', $r->code, $r->message);
	}

	return $ret;
}

sub Fox {
	my $r;
	my $ret = 'Нету лисичек, все разбежались.';

	for (1..3) {
		my $ua  = Mojo::UserAgent->new->connect_timeout (3);
		$r = $ua->get ('https://randomfox.ca/floof/')->result;

		if ($r->is_success) {
			last;
		}

		sleep 2;
	}

	if ($r->is_success) {
		my $jfox = eval {
			return $r->json;
		};

		unless (defined $jfox) {
			$log->warn ("[WARN] Unable to decode JSON from randomfox: $EVAL_ERROR");
		} else {
			if ($jfox->{image}) {
				$jfox->{image} =~ s/\\//xmsg;
				$ret = $jfox->{image};
			}
		}
	} else {
		$log->warn (sprintf '[WARN] Randomfox server return status %s with message: %s', $r->code, $r->message);
	}

	return $ret;
}

sub Oboobs {
	my $r;
	my $ret = 'Нету cисичек, все разбежались.';

	for (1..3) {
		my $ua  = Mojo::UserAgent->new->connect_timeout (3);
		$r = $ua->get ('http://api.oboobs.ru/boobs/0/1/random')->result;

		if ($r->is_success) {
			last;
		}

		sleep 2;
	}

	if ($r->is_success) {
		my $joboobs = eval {
			return $r->json;
		};

		unless (defined $joboobs) {
			$log->warn ("[WARN] Unable to decode JSON from oboobs: $EVAL_ERROR");
		} else {
			if ($joboobs->[0]->{preview}) {
				$ret = sprintf 'https://media.oboobs.ru/%s', $joboobs->[0]->{preview};
			}
		}
	} else {
		$log->warn (sprintf '[WARN] Oboobs server return status %s with message: %s', $r->code, $r->message);
	}

	return $ret;
}

sub Obutts {
	my $r;
	my $ret = 'Нету попок, все разбежались.';

	for (1..3) {
		my $ua  = Mojo::UserAgent->new->connect_timeout (3);
		$r = $ua->get ('http://api.obutts.ru/butts/0/1/random')->result;

		if ($r->is_success) {
			last;
		}

		sleep 2;
	}

	if ($r->is_success) {
		my $jobutts = eval {
			return $r->json;
		};

		unless (defined $jobutts) {
			$log->warn ("[ERROR] Unable to decode JSON from obutts: $EVAL_ERROR");
		} else {
			if ($jobutts->[0]->{preview}) {
				$ret = sprintf 'http://media.obutts.ru/%s', $jobutts->[0]->{preview};
			}
		}
	} else {
		$log->warn (sprintf '[WARN] Obutts server return status %s with message: %s', $r->code, $r->message);
	}

	return $ret;
}

sub Rabbit {
	# rabbit, but bunny
	my $url = FlickrByTags ('animal,bunny');

	if (defined $url) {
		return $url;
	} else {
		return 'Нету кроликов, все разбежались.';
	}
}

sub Owl {
	my $url = FlickrByTags ('bird,owl');

	if (defined $url) {
		return $url;
	} else {
		return 'Нету сов, все разлетелись.';
	}
}

sub Frog {
	my $url = FlickrByTags ('frog,toad,amphibian');

	if (defined $url) {
		return $url;
	} else {
		return 'Нету лягушек, все свалили.';
	}
}

sub Horse {
	my $url = FlickrByTags ('horse,equine,mammal');

	if (defined $url) {
		return $url;
	} else {
		return 'Нету коняшек, все разбежались.';
	}
}

sub Snail {
	my $url = FlickrByTags ('snail,slug');

	if (defined $url) {
		return $url;
	} else {
		return 'Нету улиток, все расползлись.';
	}
}

sub Xkcd {
	my $ua  = Mojo::UserAgent->new->connect_timeout (5)->max_redirects (0);
	my $location;
	my $status = 400;
	my $c = 0;

	do {
		my $r = $ua->get ('https://xkcd.ru/random/')->result;

		if (
			defined $r->content &&
			defined $r->content->headers &&
			defined $r->content->headers->location &&
			$r->content->headers->location ne ''
		) {
			$location = substr $r->content->headers->location, 1, -1;
			$location = sprintf 'https://xkcd.ru/i/%s_v1.png', $location;
			$r = $ua->head ($location)->result;
		}

		$c++;
		$status = $r->code;
	} while ($c < 3 || $status >= 404);

	if ($status == 200) {
		return sprintf '[xkcd.ru](%s)', $location;
	}

	return 'Комикс-стрип нарисовать не так-то просто :(';
}

sub Weather {
	my $city = shift;
	$city = trim $city;

	return 'Мне нужно ИМЯ города.' if ($city eq '');
	return 'Длинновато для названия города.' if (length ($city) > 80);

	$city = ucfirst $city;

	if ($city eq 'Мск' || $city eq 'Default' || $city eq 'Dc' || $city eq 'Msk' || $city eq 'Dc-universe') {
		$city = 'Москва';
	} elsif ($city eq 'Спб' || $city eq 'Spb') {
		$city = 'Санкт-Петербург';
	} elsif ($city eq 'Ект' || $city eq 'Ебург' || $city eq 'Ёбург' || $city eq 'Екат' || $city eq 'Ekt' || $city eq 'Eburg' || $city eq 'Ekat') {
		$city = 'Екатеринбург';
	}

	my $w = __weather ($city);
	my $reply;

	if ($w) {
		if ($w->{temperature_min} == $w->{temperature_max}) {
			$reply = sprintf (
				"Погода в городе %s, %s:\n%s, ветер %s %s м/c, температура %s°C, ощущается как %s°C, относительная влажность %s%%, давление %s мм.рт.ст",
				$w->{name},
				$w->{country},
				ucfirst $w->{description},
				$w->{wind_direction},
				$w->{wind_speed},
				$w->{temperature_min},
				$w->{temperature_feelslike},
				$w->{humidity},
				$w->{pressure}
			);
		} elsif ($w->{temperature_min} < 0 && $w->{temperature_max} <= 0) {
			$reply = sprintf (
				"Погода в городе %s, %s:\n%s, ветер %s %s м/c, температура от %s до %s°C, ощущается как %s°C, относительная влажность %s%%, давление %s мм.рт.ст",
				$w->{name},
				$w->{country},
				ucfirst $w->{description},
				$w->{wind_direction},
				$w->{wind_speed},
				$w->{temperature_max},
				$w->{temperature_min},
				$w->{temperature_feelslike},
				$w->{humidity},
				$w->{pressure}
			);
		} else {
			$reply = sprintf (
				"Погода в городе %s, %s:\n%s, ветер %s %s м/c, температура от %s до %s°C, ощущается как %s°C, относительная влажность %s%%, давление %s мм.рт.ст",
				$w->{name},
				$w->{country},
				ucfirst $w->{description},
				$w->{wind_direction},
				$w->{wind_speed},
				$w->{temperature_min},
				$w->{temperature_max},
				$w->{temperature_feelslike},
				$w->{humidity},
				$w->{pressure}
			);
		}
	} else {
		$reply = "Я не знаю, какая погода в $city";
	}

	return $reply;
}

sub __weather {
	my $city = shift;
	$city = urlencode $city;
	my $appid = $c->{openweathermap}->{appid};
	my $now = time ();
	my $fc;
	my $w;

	my $r;

	# try 3 times and giveup
	for (1..3) {
		my $ua = Mojo::UserAgent::Cached->new;
		$ua->local_dir ($cachedir);
		$ua->cache_agent (
				CHI->new (
				driver             => 'BerkeleyDB',
				root_dir           => $cachedir,
				namespace          => __PACKAGE__,
				expires_in         => '3 hours',
				expires_on_backend => 1,
			)
		);
		# just to make Mojo::UserAgent::Cached happy
		$ua->logger (Mojo::Log->new (path => '/dev/null', level => 'error'));
		$r = $ua->get (sprintf ('http://api.openweathermap.org/data/2.5/weather?q=%s&lang=ru&APPID=%s', $city, $appid))->result;

		if ($r->is_success) {
			last;
		}

		sleep 2;
	}

	# all 3 times can give error, so check it here
	if ($r->is_success) {
		$fc = eval {
			return $r->json;
		};

		unless ($fc) {
			$log->warn ("[WARN] openweathermap returns corrupted json: $EVAL_ERROR");
			return undef;
		};
	} else {
		$log->warn (sprintf '[WARN] Server return status %s with message: %s', $r->code, $r->message);
		return undef;
	}

	# TODO: check all of this for existence
	$w->{'name'} = $fc->{name};
	$w->{'state'} = $fc->{state};
	$w->{'country'} = $fc->{sys}->{country};
	$w->{'longitude'} = $fc->{coord}->{lon};
	$w->{'latitude'} = $fc->{coord}->{lat};
	$w->{'temperature_min'} = int ($fc->{main}->{temp_min} - 273.15);
	$w->{'temperature_max'} = int ($fc->{main}->{temp_max} - 273.15);
	$w->{'temperature_feelslike'} = int ($fc->{main}->{feels_like} - 273.15);
	$w->{'humidity'} = $fc->{main}->{humidity};
	$w->{'pressure'} = int ($fc->{main}->{pressure} * 0.75006375541921);
	$w->{'description'} = $fc->{weather}->[0]->{description};
	$w->{'wind_speed'} = $fc->{wind}->{speed};
	$w->{'wind_direction'} = 'разный';
	my $dir = int ($fc->{wind}->{deg} + 0);

	if ($dir == 0) {
		$w->{'wind_direction'} = 'северный';
	} elsif ($dir > 0   && $dir <= 30) {
		$w->{'wind_direction'} = 'северо-северо-восточный';
	} elsif ($dir > 30  && $dir <= 60) {
		$w->{'wind_direction'} = 'северо-восточный';
	} elsif ($dir > 60  && $dir <  90) {
		$w->{'wind_direction'} = 'восточно-северо-восточный';
	} elsif ($dir == 90) {
		$w->{'wind_direction'} = 'восточный';
	} elsif ($dir > 90  && $dir <= 120) {
		$w->{'wind_direction'} = 'восточно-юго-восточный';
	} elsif ($dir > 120 && $dir <= 150) {
		$w->{'wind_direction'} = 'юговосточный';
	} elsif ($dir > 150 && $dir <  180) {
		$w->{'wind_direction'} = 'юго-юго-восточный';
	} elsif ($dir == 180) {
		$w->{'wind_direction'} = 'южный';
	} elsif ($dir > 180 && $dir <= 210) {
		$w->{'wind_direction'} = 'юго-юго-западный';
	} elsif ($dir > 210 && $dir <= 240) {
		$w->{'wind_direction'} = 'юго-западный';
	} elsif ($dir > 240 && $dir <  270) {
		$w->{'wind_direction'} = 'западно-юго-западный';
	} elsif ($dir == 270) {
		$w->{'wind_direction'} = 'западный';
	} elsif ($dir > 270 && $dir <= 300) {
		$w->{'wind_direction'} = 'западно-северо-западный';
	} elsif ($dir > 300 && $dir <= 330) {
		$w->{'wind_direction'} = 'северо-западный';
	} elsif ($dir > 330 && $dir <  360) {
		$w->{'wind_direction'} = 'северо-северо-западный';
	} elsif ($dir == 360) {
		$w->{'wind_direction'} = 'северный';
	}

	return $w;
}

1;

# vim: set ft=perl noet ai ts=4 sw=4 sts=4:
