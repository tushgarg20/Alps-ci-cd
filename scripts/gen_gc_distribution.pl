#!/p/gat/tools/perl/perl5.14/bin/perl

=head1 NAME

gen_gc_distribution.pl - Creates the GC distribution for use with ALPS 

=head1 SYNOPSIS

	"help"			For printing help message 
	"man" 			For printing detailed information
	"debug"			For printing the sequence of commands
	"gc_csv_file"		GC CSV file from design team
	"unit_alps_map_file"	Mapping file from design unit/cluster to ALPS unit/cluster
	"gc_alps_inp_file"	Output GC file to be used as ALPS input (YAML/CSV)
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

our $gcCsvFile;
our $unitAlpsMapFileDefault = "$Bin/unitAlpsMap.csv";
our $unitAlpsMapFile;
our $gcAlpsIpFile;

Getopt::Long::GetOptions(
	"help" => \$optHelp,
	"man"  => \$optMan,   	
	"debug" => \$debugMode,
	"gc_csv_file=s" => \$gcCsvFile,
	"unit_alps_map_file=s" => \$unitAlpsMapFile,
	"gc_alps_inp_file=s" => \$gcAlpsIpFile,
	"yaml"	=> \$optYaml,
	"csv"	=> \$optCsv		
) or Pod::Usage::pod2usage("Try $0 --help/--man for more information...");

pod2usage( -verbose => 1 ) if $optHelp;
pod2usage( -verbose => 2 ) if $optMan;

if ($gcCsvFile =~ /^\s*$/) {die "Input GC file from design not specified\n";}
if ($gcAlpsIpFile =~ /^\s*$/) {die "O/P GC file for ALPS I/P not specified\n";}
if ($unitAlpsMapFile =~ /^\s*$/) 
{
	$unitAlpsMapFile = $unitAlpsMapFileDefault;
	print "ALPS mapping file for units not specified...\n";
	print "Using the default mapping file $unitAlpsMapFile\n";
} else {
	print "Using user provided ALPS mapping file $unitAlpsMapFile...\n";
}

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
create_gc_alps_inp_file();

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
		$alpsMapHash{"$unitName"}{"ALPSCLUSTER"} = $alpsCluster;
		$alpsMapHash{"$unitName"}{"FUNC"} = $function;		 
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
		my $cluster = $parts[2];
		$cluster =~ s/^\s*//;
		$cluster =~ s/\s*$//;
		if ($cluster eq "NOT USED") {$count++; next;}
		my $gc = $parts[10];
		$gc =~ s/^\s*//;
		$gc =~ s/\s*$//;
		$gc = $gc*1000;
		$gcHash{"$unitName"} = $gc;	
		$count++;
	}
	close $fileRH;
	return 1;
}

sub create_gc_alps_inp_file {
	my $fileW = $gcAlpsIpFile;
	my $fileWH;
	open $fileWH, ">$fileW" or die "Can't open file $fileW:$!";
	print $fileWH "Unit, Cluster, GC\n";
	foreach my $unit (keys %gcHash) {
		my $gc = $gcHash{"$unit"};	
		if (exists $alpsMapHash{"$unit"}) {
			my $cluster = $alpsMapHash{"$unit"}{"ALPSCLUSTER"};
			my $alpsUnit = $alpsMapHash{"$unit"}{"ALPS"};
			my $func = $alpsMapHash{"$unit"}{"FUNC"};
			if ($alpsUnit =~ /FPUWRAP/) {
				$alpsIpTempHash{"$cluster"}{"FPU"}{"TOTAL"} += $gc/2;	
				$alpsIpTempHash{"$cluster"}{"FPU"}{"COUNT"} += 1;
				$alpsIpTempHash{"$cluster"}{"FPU"}{"FUNC"} = $func;
				$alpsIpTempHash{"$cluster"}{"EM"}{"TOTAL"} += $gc/2;	
				$alpsIpTempHash{"$cluster"}{"EM"}{"COUNT"} += 1;
				$alpsIpTempHash{"$cluster"}{"EM"}{"FUNC"} = $func;
			} elsif ($alpsUnit =~ /DFX|SmallUnits/) {
				$alpsIpTempHash{"$cluster"}{"$alpsUnit"}{"TOTAL"} += $gc;
				$alpsIpTempHash{"$cluster"}{"$alpsUnit"}{"COUNT"} += 1;
				$alpsIpTempHash{"$cluster"}{"$alpsUnit"}{"FUNC"} = $func;
			} else {
				$alpsIpTempHash{"$cluster"}{"$alpsUnit"}{"TOTAL"} += $gc;
				$alpsIpTempHash{"$cluster"}{"$alpsUnit"}{"COUNT"} += 1;
				$alpsIpTempHash{"$cluster"}{"$alpsUnit"}{"FUNC"} = $func;
			} 
		} else {
			#die "Unit $unit doesn't exist in the map file\n";
			warn "Unit $unit doesn't exist in the map file\n";
		}
	}	
	foreach my $cluster (keys %alpsIpTempHash) {
		my %unitHash = %{$alpsIpTempHash{"$cluster"}};
		foreach my $unit (keys %unitHash) {
			my $func = $unitHash{"$unit"}{"FUNC"};
			if ($func eq "SUM") {
				$alpsIpHash{"$cluster"}{"$unit"} = $unitHash{"$unit"}{"TOTAL"};
			} elsif ($func eq "AVG") {
				$alpsIpHash{"$cluster"}{"$unit"} = $unitHash{"$unit"}{"TOTAL"}/$unitHash{"$unit"}{"COUNT"};
			} else {
				die "Function $func is not yet supported\n";
			}
		}
	}
	if ($opYaml == 1) { 
		print $fileWH Dump \%alpsIpHash;	
	}
	if ($opCsv == 1) {
		#my @alpsIpArray;
		#push(@alpsIpArray, \%alpsIpHash);	 
		foreach my $cluster (keys %alpsIpHash) {
			foreach my $unit (keys %{$alpsIpHash{"$cluster"}}) {
					my $gc = $alpsIpHash{"$cluster"}{"$unit"};
				print $fileWH "$unit, $cluster, $gc\n";
			}  
		}
		#my $csv = Text::CSV::Slurp->create( input => \@alpsIpArray);
		#print $fileWH $csv;
	}
	close $fileWH;
	return 1;
}
