#! /usr/bin/perl -w
#
#
#
#	Copyright Aelintra Telecom Limited(2008-23), all rights reserved
#  
# Parse the monstage directory and convert queue calls to match regular calls
# Once finished, the monstage should be empty and all the files should now be moved to monout ready for 
# rsync to send them to their destination bucket in the recordings folder
#
# load required modules

use strict;
use File::ReadBackwards;
use File::Copy;
use DBI;

sub SQLiteGet($$) {
#
#  Return a column value for a given key
#
    my ($dbh, $getcmd) = @_;
    my $out;
    my $sth = $dbh->prepare($getcmd);
    $sth->execute();
    $sth->bind_columns(\$out);
    $sth->fetch();
    $sth->finish();
    return $out;
}

my $dbh = DBI->connect( "dbi:SQLite:dbname=/opt/gcs/db/sqlite.db","", "", { RaiseError => 1, AutoCommit => 1 });

my $monitorstage =  SQLiteGet($dbh, "SELECT MONITORSTAGE FROM globals where pkey = 'global'") || "/home/gcs/monstage";
my $monitorout = SQLiteGet($dbh, "SELECT MONITOROUT FROM globals where pkey = 'global'") || "/home/gcs/monout";
my $recqsearchlim = SQLiteGet($dbh, "SELECT RECQSEARCHLIM FROM globals where pkey = 'global'") || 400;
my $recqdither = SQLiteGet($dbh, "SELECT RECQDITHER FROM globals where pkey = 'global'") || 1;
my $rfdlim = SQLiteGet($dbh, "SELECT RECFILEDLIM FROM globals where pkey = 'global'") || '_-_';

$dbh->disconnect;

print STDERR "RFDLIM IS $rfdlim \n";
print STDERR "monstage IS $monitorstage \n";


print STDERR "monout IS $monitorout \n";

$monitorstage =~ s/\/$//;
$monitorout =~ s/\/$//;

unless ( -d $monitorstage ) {
        die "Srkqmove104 - Invalid Stage Directory entry  \n";
}
unless ( -d $monitorout ) {
        die "Srkqmove105 - Invalid Out Directory entry  \n";
}

my @files = ();
my @qlogtail;
my $line;
my $linecnt = 1;
my $found;
my $filename;

my $Qlog = File::ReadBackwards->new('/var/log/asterisk/queue_log')
    or die "SrkQmove102 - Couldn't open queue_log - ending \n";

$linecnt = 1;
while ( defined($line = $Qlog->readline) ) {
    push @qlogtail, $line
		if $line =~ /CONNECT/;
	if ( $linecnt >= $recqsearchlim ) {
		last;
	}
	$linecnt++;
}

unless ( -e $monitorstage ) {
	die "SrkQmove106 - Couldn't open monstage - ending \n";
}

opendir STAGE, $monitorstage
	or die "Srkqmove103 - Couldn't open stageing directory - ending $_ \n";

while ($filename = readdir STAGE) {
	next if $filename =~ /^\./;
	push @files, $filename;
}
closedir STAGE;

if (@files) {
	foreach (@files) {
        if (/Qexec(\d+)$rfdlim(\w+)$rfdlim(\d+)$rfdlim(\w+).wav$/) {
			my $filename = $_;
			my $filetimestamp = $1;
			my $tenant = $2;
			my $dnid = $3;
			my $clid = $4;
			$found = 0;
			print STDERR "Candidate found $_ \n";
			foreach (@qlogtail) {
print STDERR "qlogrec being examined is $_ \n";
				my @fields = split /\|/, $_;
				my $logtimestamp = $fields[0];
				my $queue =  $fields[2];
				my $extension =  $fields[3];
				$extension =~ s/\///;
print STDERR "Found $logtimestamp, $queue, $extension \n";
                if ( ($filetimestamp + $recqdither) >= $logtimestamp &&
					($filetimestamp - $recqdither) <= $logtimestamp ) {
print STDERR "Matched $_ \n";
                    my $newfilename = $monitorout."/".$filetimestamp.$rfdlim.$tenant.$rfdlim.$queue.$rfdlim.$extension.$rfdlim.$clid.".wav";
print STDERR "Moving Queue file $filename to $newfilename\n";
					move ($monitorstage."/".$filename, $newfilename);
					$found = 1;
					last;
				}
            }
            unless ($found) {  # Bugger! we didn't find it!				
print STDERR "Couldn't find a match for Queuefile $filename using $filetimestamp and $recqdither - will strip Qexec and  move anyway \n";
				move ($monitorstage."/".$filename, $monitorout."/".$filetimestamp.$rfdlim.$tenant.$rfdlim.$dnid.$rfdlim.$clid.".wav");
			}
        }
		else {  # It's a regular file
				print STDERR "Moving regular file $_ \n";
				move ($monitorstage."/".$_, $monitorout."/".$_);
		}
    }
}

