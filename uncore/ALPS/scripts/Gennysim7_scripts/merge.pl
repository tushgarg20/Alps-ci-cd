#!/usr/bin/perl

use strict;
use Getopt::Long;
use Pod::Usage;
use POSIX;

open(OUTFILE, '>gennysim_residency.csv');

my @clusters = ("fixfunction", "slice", "eu", "halfslice", "sampler", "l3cache", "gti", "media") ;

foreach my $d (@clusters)
{
	my $k_infile = $d . "_alps1_1.csv" ;
	print $k_infile . "\n" ;
	open (INFILE, "<$k_infile") or die "Merge:Cannot Open File $k_infile : $!\n";
	<INFILE> ;
	while(my $line = <INFILE>)
	{
		print OUTFILE"$line" ;
	}
}


