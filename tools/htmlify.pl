#! /usr/pkg/bin/perl -Tw
#
# Originally written by Jan Schaumann
# <jschauma@netmeister.org> in July 2023.
#
# This script is part of the glue to generate TLD zone
# stats (see https://www.netmeister.org/blog/tldstats.html).
#
# Specifically, it generates the index.html and
# .js files for the given TLD.

use strict;
use warnings;

use DateTime;
use File::Basename;
use LWP::UserAgent;

my $BASEDIR = "/misc/dnsdata/zonecount";
my $COUNTDIR = "${BASEDIR}/counts";
my $HTMLDIR =  "${BASEDIR}/html";

my %DATA;
my $LASTDATE = "";
my $LASTCOUNT = "";

###

sub checkHsts($) {
	my ($tld) = @_;
	my $url = "https://hstspreload.org/api/v2/status?domain=$tld";

	my $ua = LWP::UserAgent->new();
	$ua->ssl_opts("SSL_ca_file" => "/etc/openssl/cert.pem");
	my $response = $ua->get($url);
	if (!$response->is_success) {
		print STDERR "Unable to fetch $url: " . $response->status_line . "\n";
		return undef;
	}

	if ($response->content =~ m/"status": "(.*?)"/) {
		return "$1";
	}
	return undef;
}

sub fillData($$$) {
	my ($wh, $prev, $next) = @_;
	my ($prevDate, $nextDate);

	if (length($prev) == 0) {
		return;
	}

	if ($prev =~ m/^([0-9]{4})([0-9]{2})([0-9]{2})$/) {
		$prevDate = DateTime->new(
				year => $1,
				month => $2,
				day => $3);
	} else {
		print STDERR "Illegal format: $prev\n";
		exit(1);
	}

	if ($next =~ m/^([0-9]{4})([0-9]{2})([0-9]{2})$/) {
		$nextDate = DateTime->new(
				year => $1,
				month => $2,
				day => $3);
	} else {
		print STDERR "Illegal format: $next\n";
		exit(1);
	}

	my $diff = $nextDate->subtract_datetime($prevDate)->in_units('days');
	my $fill = $prevDate;
	while ($diff > 1) {
		my $fill = $fill->add(days=>1);
		my $missing = $fill->strftime("%Y%m%d");
		print $wh ",\n    { x:'$missing', y:null }";
		$diff--;
	}
}

###

my $PROGNAME = basename($0);

if ((scalar(@ARGV) < 1) || (scalar(@ARGV) > 3)) {
	print STDERR "Usage: $PROGNAME <TLD> [<fill>] [<guessed>]\n";
	exit(1);
}

my $TLD = $ARGV[0];
my $FILL = $ARGV[1];
my $GUESSED = $ARGV[2];

if ($TLD =~ m/([0-9a-z-]+)/) {
	$TLD = $1;
}

my $OUTDIR = "${HTMLDIR}/${TLD}";
my $TLDFILE = "${COUNTDIR}/${TLD}";

if ( ! -f ${TLDFILE} ) {
	print STDERR "No countfile ${TLDFILE} found for '${TLD}'.\n";
	exit(1);
}

if (! -d ${OUTDIR} ) {
	mkdir ${OUTDIR} || die "Unable to create $OUTDIR: $!";
}

my ($rh, $wh);

my $now = DateTime->now->strftime("%Y-%m-%d");

open($rh, "<", $TLDFILE) or die "Unable to open $TLDFILE: $!";

$TLD =~ s/-/_/g;

open($wh, ">", "$OUTDIR/$TLD.js") or die "Unable to open $OUTDIR/$TLD.js: $!";

print $wh <<EOF
const data_${TLD} = {
  label: '.${TLD}',
  data: [
EOF
;

my $n = 0;
my $prev = "";
my $comma = "";
while (my $line = <$rh>) {
	$n++;
	chomp($line);
	if ($line =~ m/^([0-9]+) ([0-9]+)$/) {
		if ($FILL && ($FILL eq "true")) {
			fillData($wh, $prev, $1);
		}
		print $wh "$comma    { x:'$1', y:'$2' }";
		$comma = ",\n";
		$prev = $1;
		$LASTDATE = $1;
		$LASTCOUNT = $2;
	} else {
		print STDERR "Unexpected data on line $n in $TLDFILE:\n";
		print STDERR "|$line|\n";
	}
}
close($rh);

print $wh <<EOF

  ]
}

const ctx_${TLD} = document.getElementById('${TLD}');
new Chart(ctx_${TLD}, {
    type: 'line',
    data: {
      labels: data_${TLD}.labels,
      datasets: [{
        data: data_${TLD}.data,
        label: '.${TLD}',
        fill: false,
        borderColor: 'rgb(0, 0, 255)',
        tension: 0.1
      }]
    },
    options: {
      spanGaps: true,
      plugins: {
        legend: {
          display: false
        }
      }
    }
});
EOF
;
close($wh);

my $hsts = checkHsts($TLD);
my $hstsMessage = "";

if (($hsts) && ($hsts eq "preloaded")) {
	$hstsMessage = "<p>Note: this TLD is included in the <a href=\"https://hstspreload.org/?domain=$TLD\">HSTS preload list</a> in many browsers.</p>\n";
}

my $guessMessage = "";
if ($GUESSED eq "true") {
	$guessMessage = "<p>Source: <a href=\"https://research.domaintools.com/statistics/tld-counts/\">DomainTools</a> discovery, which may be quite off.</p>\n";
}

open($rh, "<", "${OUTDIR}/tmpl") or die "Unable to open ${OUTDIR}/tmpl: $!";
open($wh, ">", "${OUTDIR}/index.html") or die "Unable to open ${OUTDIR}/index.html: $!";

# use ',' as thousands separator
while ($LASTCOUNT =~ s/^(\d+)(\d{3})/$1,$2/) {}

while (my $tline = <$rh>) {
	$tline =~ s/::DATE::/${now}/g;
	$tline =~ s/::LASTCOUNT::/${LASTCOUNT}/g;
	$tline =~ s/::LASTDATE::/${LASTDATE}/g;
	$tline =~ s/::TLD::/${TLD}/g;

	$tline =~ s/::HSTS::/${hstsMessage}/g;

	if ($GUESSED eq "true") {
		$tline =~ s/^.*<p>Source:.*//;
	}
	$tline =~ s/::GUESS::/${guessMessage}/g;

	print $wh $tline;
}
close($rh);
close($wh);
