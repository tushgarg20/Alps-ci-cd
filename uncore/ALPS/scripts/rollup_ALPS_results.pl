#!/usr/intel/bin/perl5.82

require 5.001;
use diagnostics;
use strict;
use Getopt::Long;
use Data::Dumper;


my $IPCfile = "";
my $outfile = "";
my %IPChash;
my %IPCratios;
my $data = "";
my $refBkt = "gesher";

GetOptions(	"-i=s" => \$IPCfile,
				"-o=s" => \$outfile);# || &usage_and_bye();

($IPCfile ne "") or die("bad IPC file name\n");
($outfile ne "") or die("bad outfile name\n");


open (FILE, $IPCfile) or die("can't open $IPCfile\n");
my @rolluplines = <FILE>;
close(FILE);
shift @rolluplines;

foreach my $line (@rolluplines)
{
	chomp $line;
	$line =~ s/\r$//;

	my @line = split("\t", $line);	
#print "$line[0]\n";
	my $bucket = $line[0];
	my $condition = $line[1];
	my $trace = $line[2];
	my $IPC = $line[3];
	
	if (defined($trace))
	{
#		$trace =~ s/\.[\w\d\-]+$//;
		$trace =~ s/\.${bucket}$//;
		$IPChash{$bucket}{$condition}{$trace} = $IPC;
	}
}
#	print STDERR Dumper(\%IPChash);
#$data .= "$refBkt\tmobile\t1\n";
foreach my $bkt (keys %IPChash)
{
	my $numOfTraces = 0;
	$IPCratios{$bkt} = 0;
	
	foreach my $trc (keys %{$IPChash{$bkt}{"mobile"}})
	{
		if ((defined($IPChash{$refBkt}{"mobile"}{$trc})) and ($IPChash{$refBkt}{"mobile"}{$trc} > 0) and ($IPChash{$bkt}{"mobile"}{$trc} > 0))
		{
			$IPCratios{$bkt} += $IPChash{$bkt}{"mobile"}{$trc} / $IPChash{$refBkt}{"mobile"}{$trc};
			$numOfTraces++;
		}
	}
	if ($numOfTraces > 0) {$IPCratios{$bkt} /= $numOfTraces;}
	
	$data .= "$bkt\tmobile\t$IPCratios{$bkt}\n";
}

open(OFILE, ">$outfile") or die("can't open $outfile for writing\n");
print OFILE $data;
close(OFILE);

