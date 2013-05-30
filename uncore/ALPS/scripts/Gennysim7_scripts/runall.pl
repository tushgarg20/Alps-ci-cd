#!/usr/bin/perl

use strict;
use Getopt::Long;
use Pod::Usage;
use POSIX;
use FindBin qw($Bin);

##################################################
# Knobs and Cmdline Processing
##################################################
my $k_input				   = "";
my $vlv				  	   = 0 ;
my $gen				   	   = 0 ;
my $k_odir			  	   = "";
my $k_file			  	   = "";
my $k_sdir				   = $Bin;
my $k_media				   = '' ;

Getopt::Long::GetOptions(
        "input|i=s"      => \$k_input,
		# "sdir=s"		 => \$k_sdir,
		"odir=s"	 	 => \$k_odir,
		"media"			 => \$k_media,
		"ofile=s"		 => \$k_file
        
) or Pod::Usage::pod2usage(-exitstatus => 1, -verbose =>1);

print $k_file . "\n";
if($k_odir eq "")
{
	die "Output directory is not specified\n" ;
}
if($k_file eq "")
{
	die "Output CSV file is not specified\n" ;
}
if($k_file !~ m/\.csv$/)
{
	die "Output file should be a CSV file\n" ;
}

$k_sdir .= "/" if $k_sdir !~ /\/$/;
die "Illegal output directory specification: $k_sdir!!" unless -e $k_sdir and -d $k_sdir;

$k_odir .= "/" if $k_odir !~ /\/$/;
die "Illegal output directory specification: $k_odir!!" unless -e $k_odir and -d $k_odir;

###################################################
# Asking for Version
###################################################
# print "##############################\n" ;
# print "Old Equations           \t -- \t 1\n" ;
# print "New Equations           \t -- \t 2\n" ;
# print "##############################\n" ;
# print "Which version you want: ";
# my $version = <STDIN> ;
# chomp($version) ;
# if(($version > 2) || ($version < 1))
# {
	# die "You enter wrong choice for version\n" ;
# }

###################################################
# Asking for Config
###################################################
print "##############################\n" ;
print "Gen7            \t -- \t 1\n" ;
print "Gen7.5          \t -- \t 2\n" ;
print "Gen8            \t -- \t 3\n" ;
print "Gen9            \t -- \t 4\n" ;
print "Vlv1(2EUs,3:1)  \t -- \t 5\n" ;
print "Vlv2(4EUs,3:2)  \t -- \t 6\n" ;
print "Vlv3(6EUs,1:1)  \t -- \t 7\n" ;
print "Vlv4(4EUs,1:1)  \t -- \t 8\n" ;
print "CHV (4EUs,8EUs) \t -- \t 9\n" ;
print "CHV (16EUs)     \t -- \t 10\n" ;
print "WLV (16EUs)     \t -- \t 11\n" ;
print "BRX (4EUs)      \t -- \t 12\n" ;
print "CHV (GT0)       \t -- \t 13\n" ;
print "##############################\n" ;
print "Enter your choice: " ;

my $cfg = 11 ;
chomp($cfg) ;
if(($cfg > 12) || ($cfg < 1))
{
	die "You have entered a wrong choice for the configuration\n" ;
}

if($cfg == 1)
{
	$gen = 7 ;
	$vlv = 0 ;
}
if($cfg == 2)
{
	$gen = 7.5 ;
	$vlv = 0 ;
}
if($cfg == 3)
{
	$gen = 8 ;
	$vlv = 0 ;
}
if($cfg == 4)
{
	$gen = 9 ;
	$vlv = 0 ;
}
if($cfg == 5)
{
	$gen = 0 ;
	$vlv = 1 ;
}
if($cfg == 6)
{
	$gen = 0 ;
	$vlv = 2 ;
}
if($cfg == 7)
{
	$gen = 0 ;
	$vlv = 3 ;
}
if($cfg == 8)
{
	$gen = 0 ;
	$vlv = 4 ;
}
if($cfg == 9 || $cfg == 12)
{
	$gen = 0 ;
	$vlv = 5 ;
}
if($cfg == 10 || $cfg == 11 || $cfg == 13)
{
	$gen = 0 ;
	$vlv = 6 ;
}

open (INFILE, "<$k_input") or die "Cannot Open File $k_input : $!\n";

my @csv_files;
while(my $line = <INFILE>)
{
	chomp($line) ;
	my @fname = split/\//,$line ;
	my @out = split/.stat/,$fname[$#fname] ;
	my $outfile = $out[0] . ".csv" ;
	print $fname[$#fname] . "\n\n" ;
	
	my @clusters = ("fixfunction", "slice", "eu", "halfslice", "sampler", "l3cache", "gti", "media") ;

	foreach my $d (@clusters)
	{
		my $script = $k_sdir . $d ;
		print ("Processing $d\n") ;
		# system("perl " . $script . ".pl " . $line . " " . $vlv . " " . $gen . " " . $version . " " . $k_odir) ;
		if($cfg == 13 && $d =~ m/eu/)
		{
			system("perl " . $script . "_gt0.pl " . $line . " " . $vlv . " " . $gen . " " . $k_odir . " " . $k_media) ;
		}
		else
		{
			system("perl " . $script . ".pl " . $line . " " . $vlv . " " . $gen . " " . $k_odir . " " . $k_media) ;
		}
	}
	
	my $k_output = $k_odir . $outfile ;
	push(@csv_files,$k_output);
	open(OUTFILE, '>' . $k_output);

	my @clusters = ("fixfunction", "slice", "eu", "halfslice", "sampler", "l3cache", "gti", "media") ;

	foreach my $d (@clusters)
	{
		my $k_infile = $k_odir . $d . "_alps1_1.csv" ;
		# print $k_infile . "\n" ;
		open (IN, "<$k_infile"); #or die "Cannot Open File $k_infile : $!\n";
		<IN> ;
		while(my $line = <IN>)
		{
			print OUTFILE"$line" ;
		}
		close(IN) ;
		system("rm " . $k_infile) ;
	}
	close(OUTFILE) ;
	print "-------------------------\n" ;
}

close(INFILE) ;

###################################
# Merging CSV files
###################################
my $count = 0;
my $odir = $k_odir;
foreach my $d (@csv_files)
{
	my @odir = split/\//,$d ;
	my $file = $d;
	my @workload = split/.csv/,$odir[$#odir];
	open (CSV_FILE, "<$file") or die "Cannot Open File $file \n";
	my $tmp = $count - 1 ;
	if($count == 0)
	{
		my $file_name = $odir . "/Gen8_residencies_0.csv";
		open (OUTFILE, ">" . $file_name) ;
		print OUTFILE"," . $workload[0] . "\n" ;
		# print OUTFILE"Command Line," . $command_line . "\n" ;
		# print OUTFILE"Gennysim Stat Clocks," . $stat_clocks . "\n" ;
		while(my $line = <CSV_FILE>)
		{
			print OUTFILE"$line" ;
		}
		close(CSV_FILE) ;
		close(OUTFILE) ;
	}

	else
	{
		my $file_name = $odir . "/Gen8_residencies_" . $tmp . ".csv";
		open (READFILE, "<$file_name") or die "Cannot Open CSV File: $file_name \n";
		my $temp_file = $odir . "/Gen8_residencies_" . $count . ".csv" ;
		open (OUTFILE, ">$temp_file") ;
		my $i = 1 ;
		while(my $out_line = <READFILE>)
		{
			chomp($out_line) ;
			if($i == 1)
			{
				print OUTFILE $out_line . "," . $workload[0] . "\n" ;
			}
			else
			{
				my $copy_line = <CSV_FILE> ;
				chomp($copy_line) ;
				my @data = split/,/,$copy_line ;
				print OUTFILE $out_line . "," . $data[1] . "\n" ;
			}
			$i++ ;
		}
		close(CSV_FILE) ;
		close(READFILE) ;
		close(OUTFILE) ;
		system("rm " . $odir . "/Gen8_residencies_" . $tmp . ".csv") ;
	}
	$count ++ ;
}

$count-- ;
#print "Output file is: " . "Gen8_residencies_" . $count . "\n" ;
my $source = $odir . "/Gen8_residencies_" . $count . ".csv";
my $destination = $k_odir . $k_file;
system("cp " . $source . " " . $destination);
system("rm " . $source);
















