#!/p/gat/tools/perl/perl5.14/bin/perl

=head1 NAME

gen_alps_data.pl - Creates a consolidated ALPS model in a CSV file from multiple ALPS YAML files 

=head1 SYNOPSIS

	"help"			For printing help message 
	"man" 			For printing detailed information
	"debug"			For printing the sequence of commands
	"alps_model_dir"	Path to directory containing *.yml files
	"work_area"		Path to print output ALPS *.csv file
	"output_csv_file"	Name of output CSV file

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

use YAML::XS qw(LoadFile);

#use lib "$Bin/lib/site_perl/5.8.5";

#use Text::CSV::Slurp;

my $optHelp;
my $optMan;
my $debugMode;

my $alpsModelDir;
my $workArea;
my $outputCsvFile;

Getopt::Long::GetOptions(
	"help" => \$optHelp,
	"man"  => \$optMan,   	
	"debug" => \$debugMode,
	"alps_model_dir=s" => \$alpsModelDir,
	"work_area=s" => \$workArea,
	"output_csv_file=s" => \$outputCsvFile
) or Pod::Usage::pod2usage("Try $0 --help/--man for more information...");

pod2usage( -verbose => 1 ) if $optHelp;
pod2usage( -verbose => 2 ) if $optMan;

if ($alpsModelDir =~ /^$/) {die "Path to ALPS model directory not provided\n";}
if (! -d $alpsModelDir) {die "Path to ALPS model directory $alpsModelDir not a directory\n";}
if (! -r $alpsModelDir) {die "Path to ALPS model directory $alpsModelDir not readable\n";}

if ($workArea =~ /^$/) {die "Path to output directory not provided\n";}
if (! -d $workArea) {die "Path to output directory $workArea not a directory\n";}
if (! -w $workArea) {die "Path to output directory $workArea not writeable\n";}

if ($outputCsvFile =~ /^$/) {die "Output file name not provided\n";}
if ($outputCsvFile =~ /\//) {die "Please only provided file name...don't give path\n";}
if (-f $outputCsvFile) {warn "Output file $outputCsvFile already exists...will be overwritten...\n"}

my @alpsModelFile;
@alpsModelFile = <$alpsModelDir/*.yaml>;
if (scalar(@alpsModelFile) == 0) {die "Couldn't find any ALPS models in the directory provided: $alpsModelDir\n";}

my %consolidatedAlpsData;

foreach my $alps (@alpsModelFile) {
	my $frameName = $alps;
	$frameName =~ s/.*\/([a-zA-Z0-9_\-\.]+)$/$1/;
	$frameName =~ s/.yml$//;
	print "Processing frame $frameName...\n";
	my $alpsData = LoadFile("$alps");
	foreach my $key (keys %{$alpsData}) {
		if ($key =~ /fps/i) {$consolidatedAlpsData{$frameName}{FPS} = $alpsData->{$key};}
		if ($key =~ /total_gt_cdyn/i) {$consolidatedAlpsData{$frameName}{CDYN} = $alpsData->{$key};}
		if ($key =~ /cluster_cdyn/i) {
			#my %clusterCdynData = %{$alpsData{$key}};
			my %clusterCdynData = %{$alpsData->{$key}};
			foreach my $cluster (keys %clusterCdynData) {
				$consolidatedAlpsData{$frameName}{$cluster}{CDYN} = $clusterCdynData{$cluster};
			}
		}
		if ($key =~ /unit_cdyn/i) {
			#my %unitCdynHash = %{$alpsData{$key}};
			my %unitCdynHash = %{$alpsData->{$key}};
			foreach my $cluster (keys %unitCdynHash) {
				my %unitCdynData = %{$unitCdynHash{$cluster}};
				foreach my $unit (keys %unitCdynData) {
					$consolidatedAlpsData{$frameName}{$cluster}{$unit}{CDYN} = $unitCdynData{$unit};
				} 
			}
		}
		if ($key =~ /key_stats/i) {
			my %keyStatsHash = %{$alpsData->{$key}};
			foreach my $stat (keys %keyStatsHash) {
				$consolidatedAlpsData{$frameName}{KEYSTATS}{$stat} = $keyStatsHash{$stat};
			}
		}
		if ($key =~ /alps/i) {
			print "KEY $key\n";
			my %gtHash = %{$alpsData->{"$key"}};
			my %clusterHash = %{$gtHash{GT}};
			foreach my $clusters (keys %clusterHash) {
				my %unitHash = %{$clusterHash{$clusters}};
				foreach my $units (keys %unitHash) {
					my %unitCdynData = %{$unitHash{$units}};
					foreach my $pState (keys %unitCdynData) {
						my $testVal = $unitCdynData{$pState};
						#print "TEST ".ref($testVal)."\n";
						if (defined ref($testVal) && ref($testVal) eq '') {
							$consolidatedAlpsData{$frameName}{$clusters}{$units}{$pState}{CDYN} = $unitCdynData{$pState};
						} else {
							my %ps2CdynData = %{$testVal};
							foreach my $subPs2 (keys %ps2CdynData) {
								if ($subPs2 =~ /total/i) {
									$consolidatedAlpsData{$frameName}{$clusters}{$units}{$pState}{CDYN} = $ps2CdynData{$subPs2};
								} else {
								$consolidatedAlpsData{$frameName}{$clusters}{$units}{$pState}{$subPs2}{CDYN} = $ps2CdynData{$subPs2};
								}
							}
						}
					}
				}
			}
		} 
		
	}
	#foreach my $key (keys %{$alpsData}) {
	#	$consolidatedAlpsData{$frameName}{$key} = $alpsData->{$key};
	#}	
}


my $outputCsvFileH;
$outputCsvFile = $workArea."/".$outputCsvFile;
open $outputCsvFileH, ">$outputCsvFile" or die "Cannot open output CSV file: $outputCsvFile\n";

my %outputCsvFileHash;
my @orderArray;

my $count = 0;
foreach my $frame (keys %consolidatedAlpsData) {
	my %frameDataTemp = %{$consolidatedAlpsData{$frame}};
	#if ($count == 0) {
		push(@{$outputCsvFileHash{"Frame"}},$frame);
		if ($count == 0) {push @orderArray, "Frame";}
		push(@{$outputCsvFileHash{"FPS"}},$frameDataTemp{FPS});
		if ($count == 0) {push @orderArray, "FPS";}
		push(@{$outputCsvFileHash{"CDYN"}},$frameDataTemp{CDYN});
		if ($count == 0) {push @orderArray, "CDYN";}
		my %keyStatsDataTemp = %{$frameDataTemp{KEYSTATS}};
		foreach my $stat (keys %keyStatsDataTemp) {
			push(@{$outputCsvFileHash{$stat}},$keyStatsDataTemp{$stat});
			if ($count == 0) {push @orderArray, $stat;}
		}
		foreach my $clus (keys %frameDataTemp) {
			print "CLUS $clus\n";	
			if ($clus =~ /FPS|GT|KEYSTATS|CDYN/i) {next;}
			my %clusDataTemp = %{$frameDataTemp{$clus}};
			push(@{$outputCsvFileHash{$clus}},$clusDataTemp{CDYN});
			if ($count == 0) {push @orderArray, $clus;}
			foreach my $unit (keys %clusDataTemp) {
				if ($unit =~ /CDYN/) {next;}
				my %unitDataTemp = %{$clusDataTemp{$unit}};
				push(@{$outputCsvFileHash{$unit}},$unitDataTemp{CDYN});
				if ($count ==0) {push @orderArray, $unit;}
				foreach my $pState (keys %unitDataTemp) {
					if ($pState =~ /CDYN/) {next;}
					my %pStateDataTemp = %{$unitDataTemp{$pState}};
					push(@{$outputCsvFileHash{$pState}},$pStateDataTemp{CDYN});
					if ($count ==0) {push @orderArray, $pState;}
					foreach my $subState (keys %pStateDataTemp) {
						if ($subState =~ /CDYN/) {next;}
						my %subStateDataTemp = %{$pStateDataTemp{$subState}};	
						push(@{$outputCsvFileHash{$subState}},$subStateDataTemp{CDYN});
						if ($count == 0) {push @orderArray, $subState;}
					}
				}
			}
		}
		$count++;
	#} 
	
} 

foreach my $sKey (@orderArray)  {
	my $intVal = $outputCsvFileHash{$sKey};
	my @parts = @$intVal;
	my $pLine = $sKey;
	foreach my $part (@parts) { $pLine = $pLine.",".$part;}
	print $outputCsvFileH $pLine."\n";	
}

close $outputCsvFileH;
