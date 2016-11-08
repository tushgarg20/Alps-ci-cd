#!/p/gat/tools/perl/perl5.14/bin/perl

=head1 NAME

gen_alps_data.pl - Creates a consolidated ALPS model in a CSV file from multiple ALPS YAML files 

=head1 SYNOPSIS

	"help"			For printing help message 
	"man" 			For printing detailed information
	"debug"			For printing the sequence of commands
	"alps_model_dir"	Path to directory or multiple directories containing *.yml|*.yaml files
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

my @alpsModelDir;
my $workArea;
my $outputCsvFile;

Getopt::Long::GetOptions(
	"help" => \$optHelp,
	"man"  => \$optMan,   	
	"debug" => \$debugMode,
	"alps_model_dir=s" => \@alpsModelDir,
	"work_area=s" => \$workArea,
	"output_csv_file=s" => \$outputCsvFile
) or Pod::Usage::pod2usage("Try $0 --help/--man for more information...");

pod2usage( -verbose => 1 ) if $optHelp;
pod2usage( -verbose => 2 ) if $optMan;

if (scalar(@alpsModelDir) == 0) {die "Path to ALPS model directory not provided\n";}
foreach my $mDir (@alpsModelDir) {
	if (! -d $mDir) {die "Path to ALPS model directory $mDir not a directory\n";}
	if (! -r $mDir) {die "Path to ALPS model directory $mDir not readable\n";}
}

if ($workArea =~ /^$/) {die "Path to output directory not provided\n";}
if (! -d $workArea) {die "Path to output directory $workArea not a directory\n";}
if (! -w $workArea) {die "Path to output directory $workArea not writeable\n";}

if ($outputCsvFile =~ /^$/) {die "Output file name not provided\n";}
if ($outputCsvFile =~ /\//) {die "Please only provided file name...don't give path\n";}
if (-f $outputCsvFile) {warn "Output file $outputCsvFile already exists...will be overwritten...\n"}

my @alpsModelFile = ();
foreach my $mDir (@alpsModelDir) {
	my @tempFileList = <$mDir/*.yaml>;
	if (scalar(@tempFileList) == 0) {@tempFileList = <$mDir/*.yml>;}
	if (scalar(@tempFileList) == 0) {die "Couldn't find any ALPS models in the directory provided: $mDir\n";}
	push(@alpsModelFile, @tempFileList);
}

my %consolidatedAlpsData;

foreach my $alps (@alpsModelFile) {
	my $frameName = $alps;
	$frameName =~ s/.*\/([a-zA-Z0-9_\-\.]+)$/$1/;
	$frameName =~ s/.yml$//;
	$frameName =~ s/.yaml$//;
	print "Processing frame $frameName...\n";
	my $alpsData = LoadFile("$alps");
	foreach my $key (keys %{$alpsData}) {
		if ($key =~ /fps/i) {$consolidatedAlpsData{$frameName}{FPS} = $alpsData->{$key};}
		if ($key =~ /total_gt_cdyn/i) {$consolidatedAlpsData{$frameName}{CDYN} = $alpsData->{$key};}
		if ($key =~ /cluster_cdyn/i) {
			#my %clusterCdynData = %{$alpsData{$key}};
			my $clusterCdynData = $alpsData->{$key};
			foreach my $cluster (keys %{$clusterCdynData}) {
				my %clusterCdynBkUp = %{$clusterCdynData->{$cluster}};
				foreach my $category (keys %clusterCdynBkUp) {
					if ($category =~ /total/i) {$consolidatedAlpsData{$frameName}{$cluster}{CDYN} = $clusterCdynBkUp{$category};}
				}
			}
		}
		if ($key =~ /unit_cdyn/i) {
			#my %unitCdynHash = %{$alpsData{$key}};
			my %unitCdynHash = %{$alpsData->{$key}};
			foreach my $cluster (keys %unitCdynHash) {
				my %unitCdynData = %{$unitCdynHash{$cluster}};
				foreach my $unit (keys %unitCdynData) {
					my $tUnit;
					if ($unit =~ /^gti$/i) {
						$tUnit = "uGTI";
					} else {
						$tUnit = $unit;
					}
					$consolidatedAlpsData{$frameName}{$cluster}{$tUnit}{CDYN} = $unitCdynData{$unit};
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
							my $tUnit;
							if ($units =~ /^gti$/i) {
								$tUnit = "uGTI";
							} else {
								$tUnit = $units;
							}
							$consolidatedAlpsData{$frameName}{$clusters}{$tUnit}{$pState}{CDYN} = $unitCdynData{$pState};
						} else {
							my %ps2CdynData = %{$testVal};
							foreach my $subPs2 (keys %ps2CdynData) {
								if ($subPs2 =~ /total/i) {
									my $tUnit;
									if ($units =~ /^gti$/i) {
										$tUnit = "uGTI";
									} else {
										$tUnit = $units;
									}
									$consolidatedAlpsData{$frameName}{$clusters}{$tUnit}{$pState}{CDYN} = $ps2CdynData{$subPs2};
								} else {
									my $tUnit;
									if ($units =~ /^gti$/i) {
										$tUnit = "uGTI";
									} else {
										$tUnit = $units;
									}
									$consolidatedAlpsData{$frameName}{$clusters}{$tUnit}{$pState}{$subPs2}{CDYN} = $ps2CdynData{$subPs2};
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
			#print "CLUS $clus\n";	
			if ($clus =~ /FPS|^GT$|KEYSTATS|CDYN/i) {next;}
			my %clusDataTemp = %{$frameDataTemp{$clus}};
			push(@{$outputCsvFileHash{$clus}},$clusDataTemp{CDYN});
			if ($count == 0) {push @orderArray, $clus;}
			foreach my $unit (keys %clusDataTemp) {
				if ($unit =~ /CDYN/) {next;}
				my %unitDataTemp = %{$clusDataTemp{$unit}};
                #print "Cluster is $clus Unit is $unit Cdyn is $unitDataTemp{CDYN}\n";
                if($unit =~/^CPunit|^Repeater|^Assign|^CLKGLUE|^NONCLKGLUE|^SMALL|^DFX|^DOP/i) {$unit = $clus . '_' . $unit;} 
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
