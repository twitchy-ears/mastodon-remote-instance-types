#!/usr/bin/perl

$|++; # autoflush
use strict;

# apt install libdbd-pg-perl
use DBI;

# apt install libio-socket-ssl-perl
use HTTP::Tiny;

# apt install libtry-tiny-perl
use Try::Tiny;


use JSON;
use Data::Dumper::Simple;

use Getopt::Long qw(:config no_ignore_case bundling);
our %defaults = (
  help => 0,
  debug => 0,
  count => 0,
  http_timeout => 2,
  mode => 'followers',
  dump_list => 0,
);
our %config = %defaults;

GetOptions (
  'h|help' => \$config{help},
  'd|debug' => \$config{debug},
  'count' => \$config{count},
  'http-timeout=i' => \$config{http_timeot},
  'dump-list' => \$config{dump_list},
  'mode=s' => \$config{mode},
);
$config{mode} = lc($config{mode});

if ($config{help}) {
	print <<EOL;
$0 [-h|-d] [arguments]

 -h --help
 -d --debug      Display more information prefixed with DD: 

 --count         Add a counter for [x/y] to track progress

 --http-timeout  Set timeout for API requests, 
		 default $defaults{http_timeout}

 --dump-list     Just dump the list, don't fetch anything.

 --mode <m>      Create target domain list from mode, options are:
                 followers  (domains with users followed by users here)
		 all        (read every known instance with >1 user seen)
		 
		 Default: '$defaults{mode}'


Attempts to connect to the mastodon_production DB as the mastodon user without
a password, authenticating as the logged in user.  Dumps instances depending on
the --mode argument then attempts to retrieve the mastodon v2 API instance
information from it. Prints one of these options:

OK: 'url' -> 'source_url'
FAIL: 'url' malformed JSON
FAIL: 'url' had no source_url
FAIL: 'url' had no response
FAIL: 'url' status 'code'

The source_url should be a repo of the remote instances source, which enables
you to best guess its instance type.

If you wanted to block a specific type of instance you'd probably want to read:
https://gardenfence.github.io/ for advice on formatting, broadly if you go to
Moderation -> Federation you can import a CSV in the format: 

#domain,#severity,#reject_media,#reject_reports,#public_comment,#obfuscate
domain1.tld,suspend,false,false,your-reason-here,false
domain2.tld,suspend,false,false,your-reason-here,false
domain3.tld,suspend,false,false,your-reason-here,false

The rest is left as an exercise for the reader, grep, and sed.

EOL
	exit(0);
}


my $api_request = "/api/v2/instance";

my $driver  = "Pg";
my $database = "mastodon_production";
my $dsn = "DBI:$driver:dbname = $database";
my $userid = "mastodon";
my $password = undef;
my $dbh = DBI->connect($dsn, $userid, undef, { RaiseError => 1 })
   or die $DBI::errstr;

# print "DB $dsn connected\n";

my %domains;

if (defined($config{mode}) && $config{mode} eq 'all') {
	print "DD: Selecting from all instances\n" if ($config{debug});
	my $stmt = "SELECT domain,accounts_count FROM instances";
	my $sth = $dbh->prepare($stmt);
	my $rv = $sth->execute() or die $DBI::errstr;
	if($rv < 0) {
   		print $DBI::errstr;
	}
	while(my @row = $sth->fetchrow_array()) {
		if ($row[1] > 0) {
			$domains{ $row[0] } = $row[1];
		}
	}
}
elsif (defined($config{mode}) && $config{mode} eq 'followers') {
	print "DD: selecting from followers\n" if ($config{debug});
	my $stmt = "SELECT follows.id, follows.account_id, follows.target_account_id, accounts.username, accounts.domain FROM follows JOIN accounts ON accounts.id = follows.target_account_id and accounts.domain != ''";
	my $sth = $dbh->prepare($stmt);
	my $rv = $sth->execute() or die $DBI::errstr;
	if ($rv < 0) {
		print $DBI::errstr;
	}
	while (my @row = $sth->fetchrow_array()) {
		$domains{ $row[4] } += 1;
	}
}

$dbh->disconnect();

my $total = scalar(keys(%domains)) + 1;
my $count = 1;

foreach my $domain (sort(keys(%domains))) {
	my $count_str = "";
	if (defined($config{count}) && $config{count}) {
		$count_str = " [$count/$total] ";
	}
	$count++;

	if (defined($config{dump_list}) && $config{dump_list}) {
		print $count_str . "'$domain' $domains{$domain} relations\n";
		next;
	}

	print "DD: '$domain' with $domains{$domain} accounts\n" if ($config{debug});
	my $url = "https://" . $domain . $api_request;
	print "DD: Querying '$url' timeout $config{http_timeout}\n" if ($config{debug});
	my $response = HTTP::Tiny->new(timeout => $config{http_timeout})->get($url);
	if ($response && $response->{status} == 200) {
		# print Dumper($response);
		print "DD: '$url' status $response->{status}\n" if ($config{debug});
		my $data;
		try { 
			$data = decode_json($response->{content});
		}
		catch {
			my $err = $_;
			if ($err =~ m/^malformed JSON string/) {
				print "FAIL:$count_str'$url' malformed JSON\n";
				next;
			}
		};

		if (defined($data) && defined($data->{source_url})) {
			print "OK:$count_str'$url' -> $data->{source_url}\n";
		}
		else {
			print "FAIL:$count_str'$url' had no source_url\n";
		}
	}
	else {
		if (! $response) {
			print "FAIL:$count_str'$url' had no response\n";
		}
		else {
			print "FAIL:$count_str'$url' status '" . $response->{status} . "'\n";
		}
	}
}


