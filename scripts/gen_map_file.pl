#!/p/gat/tools/perl/perl5.14/bin/perl

=head1 NAME

gen_map_file.pl - Creates the first cut new map file from old map file for generation of ALPS GC data 

=head1 SYNOPSIS

	"help"			For printing help message 
	"man" 			For printing detailed information
	"debug"			For printing the sequence of commands
	"gc_csv_file"		GC CSV file from design team
	"unit_alps_map_file"	Old mapping file from design unit/cluster to ALPS unit/cluster
	"new_alps_map_file"	Output GC file to be used as ALPS input (YAML/CSV)
	"new_skl_format"	GC CSV file in new SKL format (post ww39 2014)
	"new_kbl_format"	GC CSV file in new KBL format (post ww14 2015)
	"yaml"			Output in YAML format
	"csv" 			Output in CSV format

=cut

use strict;
use warnings;

use Getopt::Long;

use Pod::Usage;
use POSIX;
use FindBin qw($Bin);

use Cwd;
use File::Copy;
#use IPC::System::Simple qw(system capture);

use YAML::XS qw(Dump);

#use lib "$Bin/lib/site_perl/5.8.5";

#use Text::CSV::Slurp;


my $optHelp;
my $optMan;
my $debugMode;

my $optYaml;
my $optCsv;

our $opYaml;
our $opCsv;

our $newSklFmt;
our $newKblFmt;

our $gcCsvFile;
our $unitAlpsMapFileDefault = "$Bin/unitAlpsMap.csv";
our $unitAlpsMapFile;
our $newAlpsMapFile;

Getopt::Long::GetOptions(
	"help" => \$optHelp,
	"man"  => \$optMan,   	
	"debug" => \$debugMode,
	"gc_csv_file=s" => \$gcCsvFile,
	"unit_alps_map_file=s" => \$unitAlpsMapFile,
	"new_alps_map_file=s" => \$newAlpsMapFile,
	"new_skl_format" => \$newSklFmt,
	"new_kbl_format" => \$newKblFmt,
	"yaml"	=> \$optYaml,
	"csv"	=> \$optCsv		
) or Pod::Usage::pod2usage("Try $0 --help/--man for more information...");

pod2usage( -verbose => 1 ) if $optHelp;
pod2usage( -verbose => 2 ) if $optMan;

if ($gcCsvFile =~ /^\s*$/) {die "Input GC file from design not specified\n";}
if ($newAlpsMapFile =~ /^\s*$/) {die "O/P GC file for ALPS I/P not specified\n";}
if ($unitAlpsMapFile =~ /^\s*$/) 
{
	$unitAlpsMapFile = $unitAlpsMapFileDefault;
	print "ALPS mapping file for units not specified...\n";
	print "Using the default mapping file $unitAlpsMapFile\n";
} else {
	print "Using user provided ALPS mapping file $unitAlpsMapFile...\n";
}

if ($newSklFmt) {print "Input GC file in new SKL format\n";}
if ($newKblFmt) {print "Input GC file in new KBL format\n";}

if ($newSklFmt && $newKblFmt) {die "Cannot specify both SKL and KBL formats at the same time:$!";}

if ($optYaml && !$optCsv) {print "Output file will be dumped in YAML format\n"; $opYaml = 1; $opCsv = 0;} 
if (!$optYaml && $optCsv) {print "Output file will be dumped in CSV format\n"; $opCsv = 1; $opYaml = 0;} 
if ($optYaml && $optCsv) {die "Only one format YAML/CSV is supported at a time\n"} 
if (!$optYaml && !$optCsv) {print "No output format selected. Default output format is CSV\n"; $opCsv = 1; $opYaml = 0;} 


our %alpsMapHash;
our %gcHash;
our %alpsIpTempHash;
our %alpsIpHash;

read_unit_alps_map_file();
read_gc_csv_file();
create_new_alps_map_file();

sub read_unit_alps_map_file {
	my $fileR = $unitAlpsMapFile;
	my $fileRH;
	open $fileRH, "$fileR" or die "Can't open file $fileR:$!";
	my $count = 1;
	while(<$fileRH>) {
		my $line = $_;
		chomp($line);
		if ($count == 1) {$count++; next;}
		my @parts = split(/,/, $line);
		my $unitName = $parts[0];
		$unitName =~ s/^\s*//;
		$unitName =~ s/\s*$//;
                my $partName = $parts[2];
                $partName =~ s/^\s*//;
                $partName =~ s/\s*$//;
		my $alpsUnitName = $parts[4];
		$alpsUnitName =~ s/^\s*//;
		$alpsUnitName =~ s/\s*$//;
		my $alpsCluster = $parts[5];
		$alpsCluster =~ s/^\s*//;
		$alpsCluster =~ s/\s*$//;
		if ($alpsCluster eq "NOT USED") {$count++; next;}	
		my $function = $parts[6];
		$function =~ s/^\s*//;
		$function =~ s/\s*$//;
		$alpsMapHash{"$unitName"}{"ALPS"} = $alpsUnitName;
		$alpsMapHash{"$unitName"}{"PART"} = $partName;
		$alpsMapHash{"$unitName"}{"ALPSCLUSTER"} = $alpsCluster;
		$alpsMapHash{"$unitName"}{"FUNC"} = $function;	
		$alpsMapHash{"$unitName"}{"LINE"} = $line;
		$count++;
	}	
	close $fileRH;
	return 1;
}

sub read_gc_csv_file {
	my $fileR = $gcCsvFile;
	my $fileRH;
	open $fileRH, "$fileR" or die "Can't open file $fileR:$!";
	my $count = 1;
	while(<$fileRH>) {
		my $line = $_;
		chomp($line);
		if ($count == 1) {$count++; next;}
		my @parts = split(/,/, $line);
		my $unitName = $parts[0];
		$unitName =~ s/^\s*//;
		$unitName =~ s/\s*$//;
		my $cluster;
		if ($newSklFmt) {
			$cluster = $parts[1];
                } elsif ($newKblFmt) {
                	$cluster = $parts[11];
                } else {
			$cluster = $parts[2];
		}
		$cluster =~ s/^\s*//;
		$cluster =~ s/\s*$//;
		if ($cluster eq "NOT USED") {$count++; next;}
		my $partition;
		if ($newSklFmt) {
			$partition = $parts[2];
                } elsif ($newKblFmt) {
                	$partition = $parts[10];
		} else {
			$partition = $parts[3];
		}
		$partition =~ s/^\s*//;
		$partition =~ s/\s*$//;
		my $gc;
		if ($newSklFmt) {
			$gc = $parts[6];
                } elsif ($newKblFmt) {
                	$gc = $parts[1];
		} else {
			$gc = $parts[10];
		}
		$gc =~ s/^\s*//;
		$gc =~ s/\s*$//;
		#$gc = $gc*1000;
		if ($gc ne "#N/A") {$gc = $gc*1000;}
		#$gcHash{"$unitName"}{"GC"} = $gc;	
		#$gcHash{"$unitName"}{"CLUSTER"} = $cluster;	
		#$gcHash{"$unitName"}{"PARTITION"} = $partition;
		$gcHash{"$cluster"}{"$partition"}{"$unitName"} = $gc;
		$count++;
	}
	close $fileRH;
	return 1;
}

sub create_new_alps_map_file {
	my $fileW = $newAlpsMapFile;
	my $fileWH;
	open $fileWH, ">$fileW" or die "Can't open file $fileW:$!";
	print $fileWH "Unit,Cluster,Partition,ALPS Map,ALPS Unit Name,ALPS Cluster, Functions\n";
	foreach my $cluster (keys %gcHash) {
		my %partHash = %{$gcHash{"$cluster"}};
		foreach my $partition (keys %partHash) {
			my %unitHash = %{$partHash{"$partition"}};
			foreach my $unit (keys %unitHash) {
				if (exists $alpsMapHash{"$unit"}) {
                                        my $part = $alpsMapHash{"$unit"}{"PART"};
                                        if ($partition eq $part)
                                        {
						my $line = $alpsMapHash{"$unit"}{"LINE"};
						print $fileWH "$line\n";
                                        }
                                        else
                                        {
						print $fileWH "$unit,$cluster,$partition\n";
                                        }
				} else {
					print $fileWH "$unit,$cluster,$partition\n";
				}
			}
		}
	}
	close $fileWH;
	return 1;
}
