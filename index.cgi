#!/usr/bin/perl
{
    package MyWebServer;

    use warnings;
    use strict;
    use HTTP::Server::Simple::CGI;
    use JSON;
    use base qw(HTTP::Server::Simple::CGI);
    use File::Basename;
    use lib dirname(__FILE__);
    use core;

    # print `source conf.cfg`;

    my %dispatch = (
        '/' => \&resp_index,
        '/log' => \&resp_search_email,
    );

    sub print_header (;$) {
        my ($content_type) = @_;
        $content_type = "text/html" if (!$content_type);

        print "Content-type: $content_type; charset=utf-8\n";
        # print "Cache-Control: no-store, no-cache, must-revalidate, post-check=0, pre-check=0\n";
        print "\n";
    }

    sub print_page ($;$) {
        my ($page, $params) = @_;

        if (!open(FILE, 'templates/' . $page)) {
            print "Server Error\n";
            exit;
        }

        while (<FILE>) {
            # while (/({{ ([^}\s]+) }})/) {
            #     my ($p1, $p2) = ($1, $2);
            #     $p2 =~ tr/A-Z/a-z/;
            #     $params->{$p2} = '' if (!defined($params->{$p2}));
            #     s/$p1/$params->{$p2}/gi;
            # }
            print $_;
        }

        close(FILE);
    }

    sub handle_request ($$) {
        my $self = shift;
        my $cgi  = shift;

        my $path = $cgi->path_info();
        my $handler = $dispatch{$path};

        if (ref($handler) eq "CODE") {
            print "HTTP/1.0 200 OK\r\n";
            $handler->($cgi);
        }
        else {
            print "HTTP/1.0 404 Not found\r\n";
            my $rv = {
                'code' => 404,
                'error' => 'Not Found',
            };
            print_header('application/json');
            print(to_json($rv));
            print "\n";
        }
    }

    sub resp_index {
        my $cgi  = shift;
        return if !ref $cgi;
        print_header();
        print_page('index.html');
    }

    sub resp_search_email {
        my $cgi  = shift;
        return if !ref $cgi;

        my $email = $cgi->param('email');
        print_header('application/json');
        my $dbh = db_connect();
        my $rv = get_logs_by_email($dbh, $email);
        print(to_json($rv));
        print "\n";
    }
}

my $port = 8080;
my $pid = MyWebServer->new($port)->background();
print "\nRunning http://localhost:$port\n";
print "Use 'sudo kill $pid' to stop server.\n";
