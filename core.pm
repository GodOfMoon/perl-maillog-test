package core;

use strict;
use warnings;

use DBI;
use Env;
use utf8;
use Encode qw( :all );
use Time::Local;
use Sys::Syslog;

use vars (qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION));

BEGIN {
	use Exporter ();
	@ISA = qw(Exporter);

	# список экспортируемых функций
	@EXPORT = qw(
		db_connect
		get_logs_by_email
		query_execute
		writelog
	);

	# список экспортируемых переменных
	@EXPORT_OK = qw();
	%EXPORT_TAGS = (
		FIELDS => [
			@EXPORT_OK,
			@EXPORT
		]
	);
	$VERSION = 0.01;
}

sub get_opt () {
	my %opt = (
		db_type => $ENV{'PERL_MAIL_LOG_PARSER_DB_TYPE'},
		db_name => $ENV{'PERL_MAIL_LOG_PARSER_DB_NAME'},
		db_host => $ENV{'PERL_MAIL_LOG_PARSER_DB_HOST'},
		db_user => $ENV{'PERL_MAIL_LOG_PARSER_DB_USER'},
		db_pwd => $ENV{'PERL_MAIL_LOG_PARSER_DB_PWD'},
	);
	return %opt;
}

sub writelog ($) {
	my $str = shift;
	openlog("perl-maillog-test-core", "notfatal", "local0");
	syslog("LOG_INFO", $str);
	closelog();
}

sub db_connect() {

    my %opt = get_opt();
	# use Data::Dumper;
	# print Dumper(\%opt);
    my $dsn = "dbi:$opt{'db_type'}:dbname=$opt{'db_name'}:host=$opt{'db_host'}";

    my $dbh = DBI->connect($dsn, $opt{'db_user'}, $opt{'db_pwd'});

    if (!$dbh) {
		writelog("Cannot connect to $dsn");
        return 0;
    }
    $dbh->do('set names utf8');
    $dbh->{mysql_enable_utf8} = 1;

    return $dbh;
}

sub query_execute ($$$;$) {

	my ($dbh,
		$query,
		$type,
		$vars,
	) = @_;

	my $answer = {
		module  => "query_execute",
		status  => 1,
		message => "",
	};
	# status 1 -- error, status 0 -- ok

	if (!$dbh) {
		# $query =~ s/\s+/ /g;
		# $answer->{message} = "Cannot connect to base. Q = $query ";
		# writelog("$answer->{module}: $answer->{message}");
		$answer->{message} = "Не могу подключиться к базе. ";
		return $answer;
	}

	my $sth = $dbh->prepare($query);
	my $counter = 1;

	foreach my $var (@$vars) {
		my $is_bind = $sth->bind_param($counter++, $var);
		if (!$is_bind) {
			$query =~ s/\s+/ /g;
			$answer->{message} = "Q: [$query], params: [" . join(', ', @$vars) . "], cannot bind param [$var]";
			writelog("$answer->{module}: $answer->{message}");
		}
	}
	my $log_queries = 0;
	if ($log_queries) {
		$query =~ s/\s+/ /g;
		$answer->{message} = "Q: [$query], params: [" . join(', ', @$vars) . "] ";
		writelog("$answer->{module}: $answer->{message}");
	}

	my $ret = $sth->execute();

	if (!$ret) {
		$query =~ s/\s+/ /g;
		$answer->{message} = "Incorrect sql query: code [" . $sth->err . "] message [" . $sth->errstr . "] Q = [$query]. ";
		writelog("$answer->{module}: $answer->{message}");
		$answer->{message} = "Некорректный запрос к базе. ";
		return $answer;
	}

	if ($type == 1) {
		# select query_execute($dbh, $Q, 1, \@arr);

		my $data;

		while (my $row = $sth->fetchrow_hashref()) {
			push @$data, $row;
		}

		if ($data) {
			$answer->{data} = $data;
		}
		else {
			$answer->{message} = "Данные отсутствуют. ";
		}
	}
	if ($type == 2) {
		# insert query_execute($dbh, $Q, 2, \@arr);
		$answer->{message} = "Запись добавлена. ";
	}
	if ($type == 3) {
		# update query_execute($dbh, $Q, 3, \@arr);
		$answer->{message} = "Обновлено. ";
		if ($ret eq '0E0') {
			$answer->{message} = "No update. ";
			$answer->{noupd} = 1;
		}
	}

	$sth->finish();
	$answer->{status} = 0;
	return $answer;
}

sub get_logs_by_email($$) {
	my ($dbh, $email) = @_;
	my $Q = "SELECT created, str FROM log WHERE address = ? ORDER BY int_id, created LIMIT 101";
	my $rv = query_execute($dbh, $Q, 1, [$email]);
	if ($rv->{status} == 0) {
		if (scalar @{$rv->{data}} > 100) {
			$rv->{data}[100] = {
				'created' => '',
				'str'     => 'Обнаружено более 100 записей. ',
			}
		}
	}
	return $rv;
}

1;















