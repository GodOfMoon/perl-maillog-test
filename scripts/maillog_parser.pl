#! /usr/bin/perl

use strict;
use warnings;
use Time::Local;
use Getopt::Std;
use File::Basename;
use lib dirname (dirname(__FILE__)); # if the file in the scripts directory

use core;

sub start {
    print "start. " . localtime() . "\n";
}
sub end {
    print "end. " . localtime() . "\n";
    exit;
}
sub text_date_to_timestamp ($) {
    my $datetime = shift;
    my ($year,$mon,$mday,$hour,$min,$sec) = split(/[\s\-:]+/, $datetime);
    return timelocal($sec, $min, $hour, $mday, $mon-1, $year);
}
start();
my $dbh = db_connect();
if (!$dbh) {
    print "Не удалось подключиться к DB\n";
    end();
}

if (!open(FILE, 'Test-2023/maillog')) {
    print "Server Error\n";
    end();
}

my @operations = ( ' <= ', ' => ', ' -> ', ' \*\* ', ' == ' );
$dbh->do('START TRANSACTION');

my $counter = 0;
while (<FILE>) {
    my $splited = 0;
    my @vars;
    my $operation;
    foreach my $op (@operations) {
        @vars = split ($op, $_);
        if (scalar(@vars) == 2) {
            $splited = 1;
            $operation = $op;
            last;
        }
    }

    my ($date, $time, $msg_id) = split(' ', $vars[0]);
    my $timestamp = text_date_to_timestamp("$date $time");
    $timestamp = "$date $time";
    my $email;
    my $message;
    my $id;
    if (defined $splited && $splited == 1) {
        if ($vars[1] =~ /^(:[^:]+: <([^>]+)>)/) {
            $email = $2;
            $message = (split($1, $vars[1]))[1];
        }
        else {
            my @split_data = split(' ', $vars[1]);
            $email = $split_data[0];
            $message = $vars[1];
            $message =~ s/^$email //;
        }
        $message =~ s/^\s+(.*)/$1/;
        chomp($message);
        # print "Email [$email] Message [$message]\n";
        if ($operation eq ' <= ' && $email ne '<>' && $message =~ /id=([^\s]+)/) {
            $id = $1;
        }
    }
    elsif ($_ =~ /$date $time $msg_id (.*)/) {
        $message = $1;
    }
    if (defined $operation && $operation eq ' <= ') {
        # table message
=pod
table message
describe:
    created - timestamp строки лога
    id - значение поля id=xxxx из строки лога
    int_id - внутренний id сообщения
    str - строка лога (без временной метки)
=cut
        # Здесь можно сделать insert через 1 огромный объединенный запрос (в сумме было бы 2 для двух таблиц)
        # но по реализации чуть быстрее делать кучу запросов через транзакцию
        my $Q = "INSERT INTO message (created, id, int_id, str) VALUES (?,?,?,?)";
        my $rv = query_execute($dbh, $Q, 2, [$timestamp, $id, $msg_id, $message]);
        if ($rv->{status} != 0) {
            print "Error while insert, details: $rv->{message}";
        }
    }
    else {
=pod
table log
describe:
    created - timestamp строки лога
    int_id - внутренний id сообщения
    str - строка лога (без временной метки)
    address - адрес получателя
=cut
        my $Q = "INSERT INTO log (created, int_id, str, address) VALUES (?,?,?,?)";
        my $rv = query_execute($dbh, $Q, 2, [$timestamp, $msg_id, $message, $email]);
        if ($rv->{status} != 0) {
            print "Error while insert, details: $rv->{message}";
        }
    }
}

close(FILE);

$dbh->do('COMMIT');
$dbh->disconnect();
end();
