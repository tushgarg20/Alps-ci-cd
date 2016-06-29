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
	"new_skl_format"	GC CSV file in new SKL format (post ww39 2014)
	"powerdb_format"	GC CSV file in power dB format (post ww37 2015)
	"adder_data"		GC CSV file provided has HSD adder GC (post ww26 2016)
	"unit_sd_growth_file"	CSV file with unit SD growth factors (post ww26 2016)
	"clust_sd_growth_file"	CSV file with cluster SD growth factors (post ww26 2016)
	"fub_cg_as_idle"	Fub clock gated adders will be treated on par with idle adders (post ww26 2016)
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

#use Math::Round;

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
our $pwrDbFmt;
our $adderData;

our $gcCsvFile;
our $unitAlpsMapFileDefault = "$Bin/unitAlpsMap.csv";
our $unitAlpsMapFile;
our $gcAlpsIpFile;
our $unitSdGrowthFile = "";
our $clustSdGrowthFile = "";
our $fubCgAsIdle;

Getopt::Long::GetOptions(
	"help" => \$optHelp,
	"man"  => \$optMan,   	
	"debug" => \$debugMode,
	"gc_csv_file=s" => \$gcCsvFile,
	"unit_alps_map_file=s" => \$unitAlpsMapFile,
	"gc_alps_inp_file=s" => \$gcAlpsIpFile,
	"new_skl_format" => \$newSklFmt,
	"powerdb_format" => \$pwrDbFmt,
	"adder_data" => \$adderData,
	"unit_sd_growth_file=s" => \$unitSdGrowthFile,
	"clust_sd_growth_file=s" => \$clustSdGrowthFile,
	"fub_cg_as_idle" => \$fubCgAsIdle,
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

if ($newSklFmt) {print "Input GC file in new SKL format\n";}
if ($pwrDbFmt) {print "Input GC file in power dB format\n";}
if ($adderData) {
	if ($pwrDbFmt) { 
		print "Will assume input GC file as HSD adder file in power dB format\n";
		if ($unitSdGrowthFile eq "" || $clustSdGrowthFile eq "") {
			die "Need to provide both unit and cluster SD growth files if providing HSD adder files\n";
		} else {
			if ((-f $unitSdGrowthFile) && (-f $clustSdGrowthFile)) {
				print "Unit SD growth file - $unitSdGrowthFile\n";
				print "Cluster SD growth file - $clustSdGrowthFile\n";
			} else {
				die "Either unit or cluster SD growth file doesn't exist or isn't a valid file\n";
			}
		}
		if ($fubCgAsIdle) {
			print "Will treat Fub Clock Gated adders on par with idle adders\n";
		} else {
			print "Will treat Fub Clock Gated adders on par with active adders\n";
		}
	} else {
		die "HSD adder files support only in power dB format\n";
	}
}

if ($optYaml && !$optCsv) {print "Output file will be dumped in YAML format\n"; $opYaml = 1; $opCsv = 0;} 
if (!$optYaml && $optCsv) {print "Output file will be dumped in CSV format\n"; $opCsv = 1; $opYaml = 0;} 
if ($optYaml && $optCsv) {die "Only one format YAML/CSV is supported at a time\n"} 
if (!$optYaml && !$optCsv) {print "No output format selected. Default output format is CSV\n"; $opCsv = 1; $opYaml = 0;} 

our %alpsMapHash;
our %gcHash;
our %alpsIpTempHash;
our %alpsIpHash;
our %unitSdGrowthHash;

if ($pwrDbFmt && $adderData) { 
	&read_unit_sd_growth_file($unitSdGrowthFile);
	&read_unit_sd_growth_file($clustSdGrowthFile);
}
&read_unit_alps_map_file();
&read_gc_csv_file();
&create_gc_alps_inp_file();

sub read_unit_sd_growth_file {
	my $fileR = shift;
	print "Using SD growth file - $fileR\n";
	my $fileRH;
	open $fileRH, "$fileR" or die "Can't open $fileR:$!";
	my $line = <$fileRH>;
	my %header;
	my @headers = split/,/,$line;
	my $hCount = 0;
	foreach my $head (@headers)
	{
		$head =~ s/^\s*//;
		$head =~ s/\s*$//;
		$header{$head} = $hCount;
		$hCount++;
	}
	while(<$fileRH>) {
		my $line = $_;
		chomp($line);
		my @parts = split/,/,$line;
		my $unitName;
		my $growth;
		if (defined $header{"unit"}) {
			$unitName = $parts[$header{"unit"}];
		} elsif (defined $header{"cluster"}) {
			$unitName = $parts[$header{"cluster"}];
		} else {
			die "Cannot find any field for unit/cluster in SD growth file $fileR\n";
		}
		if (defined $header{"sd_growth"}) {
			$growth   = $parts[$header{"sd_growth"}];
		} elsif (defined $header{"unit_sd_growth"}) {
			$growth   = $parts[$header{"unit_sd_growth"}];
		} else {
			die "Cannot find any field for unit SD growth in SD growth file $fileR\n";
		}
		$unitSdGrowthHash{"$unitName"} = $growth;
	}
	close $fileRH;
}

sub read_unit_alps_map_file {
	my $fileR = $unitAlpsMapFile;
	my $fileRH;
	open $fileRH, "$fileR" or die "Can't open file $fileR:$!";
	my $count = 1;
	my $line = <$fileRH>;
	my %header;
	my @headers = split/,/,$line;
	my $hCount = 0;
	foreach my $head (@headers)
	{
		$head =~ s/^\s*//;
		$head =~ s/\s*$//;
		$header{$head} = $hCount;
		$hCount++;
	}
	while(<$fileRH>) {
		my $line = $_;
		chomp($line);
		$line =~ s/^\s*//;
		$line =~ s/\s*$//;
		#if ($count == 1) {$count++; next;}
		my @parts = split(/,/, $line);
		my $unitName;
		if ($pwrDbFmt && $adderData) {
			$unitName = $parts[$header{"Unit"}];
		} else {
			$unitName = $parts[0];
		}
		$unitName =~ s/^\s*//;
		$unitName =~ s/\s*$//;
		my $clustName;
		if ($pwrDbFmt && $adderData) {
			$clustName = $parts[$header{"Cluster"}];
		} else {
			$unitName = $parts[1];
		}
		my $alpsUnitName;
		if ($pwrDbFmt && $adderData) {
			$alpsUnitName = $parts[$header{"ALPS Unit Name"}];
		} else {
			$alpsUnitName = $parts[4];
		}
		$alpsUnitName =~ s/^\s*//;
		$alpsUnitName =~ s/\s*$//;
		my $alpsCluster;
		if ($pwrDbFmt && $adderData) {
			$alpsCluster = $parts[$header{"ALPS Cluster"}];
		} else {
			$alpsCluster = $parts[5];
		}
		$alpsCluster =~ s/^\s*//;
		$alpsCluster =~ s/\s*$//;
		if ($alpsCluster eq "NOT USED") {$count++; next;}
		my $function;
		if ($pwrDbFmt && $adderData) {
			$function = $parts[$header{"Functions"}];
		} else {
			$function = $parts[6];
		}
		$function =~ s/^\s*//;
		$function =~ s/\s*$//;
		$alpsMapHash{"$unitName"}{"ALPS"} = $alpsUnitName;
		$alpsMapHash{"$unitName"}{"CLUSTER"} = $clustName;
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
	my $line = <$fileRH>;
	my %header;
	my @headers = split/,/,$line;
	my $hCount = 0;
	foreach my $head (@headers)
	{
		$head =~ s/^\s*//;
		$head =~ s/\s*$//;
		$header{$head} = $hCount;
		$hCount++;
	}
	my $count = 1;
	while(<$fileRH>) {
		my $line = $_;
		chomp($line);
		$line =~ s/^\s*//;
		$line =~ s/\s*$//;
		if ($line =~ /^#/) {next;}
		#if ($count == 1) {$count++; next;}
		my @parts = split(/,/, $line);
		my $unitName;
		if ($pwrDbFmt) {
			if (defined $header{"Unit"}) {
				$unitName = $parts[$header{"Unit"}];
			} elsif (defined $header{"unit"}) {
				$unitName = $parts[$header{"unit"}];
			} else {
				die "Cannot find any units in the inp GC file\n";
			}
			#$unitName = $parts[$header{"Unit"}];
		} else {
			$unitName = $parts[0];
		}
		$unitName =~ s/^\s*//;
		$unitName =~ s/\s*$//;
		my $cluster;
		if ($pwrDbFmt) {
			$cluster = "";
		} elsif ($newSklFmt) {
			$cluster = $parts[1];
		} else {
			$cluster = $parts[2];
		}
		$cluster =~ s/^\s*//;
		$cluster =~ s/\s*$//;
		if ($cluster eq "NOT USED") {$count++; next;}
		my $gc;
		my $infraGc;
		my $scalerStatus;
		if ($pwrDbFmt && $adderData) {
			$infraGc = $parts[$header{"hw_impact_megacluster_syn_kgates"}];
			$infraGc =~ s/^\s*//;
			$infraGc =~ s/\s*$//;
			#my $growth = 1.0;
			#my $unitName1 = $unitName."1";
			#my $unitName0 = $unitName."0";
			#if (defined $unitSdGrowthHash{"$unitName"}) {
			#	$growth = $unitSdGrowthHash{"$unitName"};
			#} elsif (defined $unitSdGrowthHash{"$unitName1"}) {
			#	$growth = $unitSdGrowthHash{"$unitName"};
			#} elsif (defined $unitSdGrowthHash{"$unitName0"}) {
			#	$growth = $unitSdGrowthHash{"$unitName"};
			#} else {
			#	warn "Unit $unitName doesn't have an entry in the SD growth file\n";
			#	print "Assuming a SD growth factor of 1.0 for unit $unitName\n";
			#}
			#$infraGc *= $growth * 1000;
			$scalerStatus = $parts[$header{"threed"}];
			if ($fubCgAsIdle) {
				if ($scalerStatus =~ /ACTIVE/i) {
					$gc = $infraGc;
				} elsif ($scalerStatus =~ /IDLE|Fub_Clock_Gated/i) {
					$gc = $infraGc * 0.11;
				} elsif ($scalerStatus =~ /POWER_GATED/i) {
					$gc = 0;
				} else {
					die "Unknown GC growth scaler status - $scalerStatus\n";
				}
			} else {
				if ($scalerStatus =~ /ACTIVE|Fub_Clock_Gated/i) {
					$gc = $infraGc;
				} elsif ($scalerStatus =~ /IDLE/i) {
					$gc = $infraGc * 0.11;
				} elsif ($scalerStatus =~ /POWER_GATED/i) {
					$gc = 0;
				} else {
					die "Unknown GC growth scaler status - $scalerStatus\n";
				}
			}
		} elsif ($pwrDbFmt && !$adderData) {
			my $isPart = $parts[$header{"is_partition"}];
			my $isGlue = $parts[$header{"is_gluelogic"}];
			if ($isPart || $isGlue) {next;}
			if (defined $header{"GC"}) {
				$gc = $parts[$header{"GC"}];
				$infraGc = $gc;
			} elsif (defined $header{"gc"}) {
				$gc = $parts[$header{"gc"}];
				$infraGc = $gc;
			} else {
				die "SD GC field doesn't have a field for GC\n";
			}
                } elsif ($newSklFmt) {
                        $gc = $parts[6];
                } else {
                        $gc = $parts[10];
                }
		$gc =~ s/^\s*//;
		$gc =~ s/\s*$//;
		#$gc = $gc*1000;
		if (!$pwrDbFmt)
		{
			if ($gc ne "#N/A") {
				$gc = $gc*1000;
			} else {
				$gc = 0;
			}
		}
		my $roundGc = sprintf("%.0f", $gc);
		my $roundInfraGc = sprintf("%.0f", $infraGc);
		if ($pwrDbFmt && $adderData) {
			#$roundInfraGc = sprintf("%.0f", $infraGc);
			$gcHash{"$unitName"}{"GC"} += $roundGc;
			$gcHash{"$unitName"}{"INFRAGC"} += $roundInfraGc;
		} else {
			$gcHash{"$unitName"}{"GC"} = $roundGc;
			$gcHash{"$unitName"}{"INFRAGC"} = $roundInfraGc;
		}
		$count++;
	}
	close $fileRH;
	return 1;
}

sub create_gc_alps_inp_file {
	my $fileW = $gcAlpsIpFile;
	my $fileWH;
	open $fileWH, ">$fileW" or die "Can't open file $fileW:$!";
	print $fileWH "Unit,Cluster,GC,INFRAGC\n";
	foreach my $unit (keys %gcHash) {
		my $gc = $gcHash{"$unit"}{"GC"};
		my $infraGc = $gcHash{"$unit"}{"INFRAGC"};
		my $unit1 = $unit."1";
		my $unit0 = $unit."0";
		if (exists $alpsMapHash{"$unit"}) {
			my $cluster = $alpsMapHash{"$unit"}{"ALPSCLUSTER"};
			my $clustName = $alpsMapHash{"$unit"}{"CLUSTER"};
			my $alpsUnit = $alpsMapHash{"$unit"}{"ALPS"};
			my $func = $alpsMapHash{"$unit"}{"FUNC"};
			if ($func eq "IGNORE") {warn "Unit $unit ignored for GC rollup\n"; next;}
			my $growth = 1.0;
			#my $unitName1 = $unitName."1";
			#my $unitName0 = $unitName."0";
			if ($pwrDbFmt && $adderData) {
				if (defined $unitSdGrowthHash{"$unit"}) {
					$growth = $unitSdGrowthHash{"$unit"};
				} elsif (defined $unitSdGrowthHash{"$clustName"}) {
					$growth = $unitSdGrowthHash{"$clustName"};
				} else {
					warn "Unit $unit doesn't have an entry in the SD growth file\n";
					print "Assuming a SD growth factor of 1.0 for unit $unit\n";
				}
			}
			$gc = $gc * $growth * 1000.0;
			$infraGc = $infraGc * $growth * 1000.0;
			if ($alpsUnit =~ /FPUWRAP|FPU0/) {
				$alpsIpTempHash{"$cluster"}{"FPU0"}{"TOTAL"} += $gc/2;
				$alpsIpTempHash{"$cluster"}{"FPU0"}{"TOTALINFRA"} += $infraGc/2;
				$alpsIpTempHash{"$cluster"}{"FPU0"}{"COUNT"} += 1;
				$alpsIpTempHash{"$cluster"}{"FPU0"}{"FUNC"} = $func;
				$alpsIpTempHash{"$cluster"}{"FPU1"}{"TOTAL"} += $gc/2;
				$alpsIpTempHash{"$cluster"}{"FPU1"}{"TOTALINFRA"} += $infraGc/2;
				$alpsIpTempHash{"$cluster"}{"FPU1"}{"COUNT"} += 1;
				$alpsIpTempHash{"$cluster"}{"FPU1"}{"FUNC"} = $func;
			} elsif ($alpsUnit =~ /DFX|SmallUnits|SMALL|CP|ASSIGN|RPT/) {
				$alpsIpTempHash{"$cluster"}{"$alpsUnit"}{"TOTAL"} += $gc;
				$alpsIpTempHash{"$cluster"}{"$alpsUnit"}{"TOTALINFRA"} += $infraGc;
				$alpsIpTempHash{"$cluster"}{"$alpsUnit"}{"COUNT"} += 1;
				$alpsIpTempHash{"$cluster"}{"$alpsUnit"}{"FUNC"} = $func;
			} else {
				$alpsIpTempHash{"$cluster"}{"$alpsUnit"}{"TOTAL"} += $gc;
				$alpsIpTempHash{"$cluster"}{"$alpsUnit"}{"TOTALINFRA"} += $infraGc;
				$alpsIpTempHash{"$cluster"}{"$alpsUnit"}{"COUNT"} += 1;
				$alpsIpTempHash{"$cluster"}{"$alpsUnit"}{"FUNC"} = $func;
			} 
		} elsif (exists $alpsMapHash{"$unit1"}) {
			my $cluster = $alpsMapHash{"$unit1"}{"ALPSCLUSTER"};
			my $clustName = $alpsMapHash{"$unit1"}{"CLUSTER"};
			my $alpsUnit = $alpsMapHash{"$unit1"}{"ALPS"};
			my $func = $alpsMapHash{"$unit1"}{"FUNC"};
			if ($func eq "IGNORE") {warn "Unit $unit ignored for GC rollup\n"; next;}
			my $growth = 1.0;
			#my $unitName1 = $unitName."1";
			#my $unitName0 = $unitName."0";
			if ($pwrDbFmt && $adderData) {
				if (defined $unitSdGrowthHash{"$unit1"}) {
					$growth = $unitSdGrowthHash{"$unit1"};
				} elsif (defined $unitSdGrowthHash{"$clustName"}) {
					$growth = $unitSdGrowthHash{"$clustName"};
				} else {
					warn "Unit $unit1 doesn't have an entry in the SD growth file\n";
					print "Assuming a SD growth factor of 1.0 for unit $unit1\n";
				}
			}
			$gc = $gc * $growth * 1000.0;
			$infraGc = $infraGc * $growth * 1000.0;
			if ($alpsUnit =~ /FPUWRAP|FPU0/) {
				$alpsIpTempHash{"$cluster"}{"FPU0"}{"TOTAL"} += $gc/2;
				$alpsIpTempHash{"$cluster"}{"FPU0"}{"TOTALINFRA"} += $infraGc/2;
				$alpsIpTempHash{"$cluster"}{"FPU0"}{"COUNT"} += 1;
				$alpsIpTempHash{"$cluster"}{"FPU0"}{"FUNC"} = $func;
				$alpsIpTempHash{"$cluster"}{"FPU1"}{"TOTAL"} += $gc/2;
				$alpsIpTempHash{"$cluster"}{"FPU1"}{"TOTALINFRA"} += $infraGc/2;
				$alpsIpTempHash{"$cluster"}{"FPU1"}{"COUNT"} += 1;
				$alpsIpTempHash{"$cluster"}{"FPU1"}{"FUNC"} = $func;
			} elsif ($alpsUnit =~ /DFX|SmallUnits|SMALL|CP|ASSIGN|RPT/) {
				$alpsIpTempHash{"$cluster"}{"$alpsUnit"}{"TOTAL"} += $gc;
				$alpsIpTempHash{"$cluster"}{"$alpsUnit"}{"TOTALINFRA"} += $infraGc;
				$alpsIpTempHash{"$cluster"}{"$alpsUnit"}{"COUNT"} += 1;
				$alpsIpTempHash{"$cluster"}{"$alpsUnit"}{"FUNC"} = $func;
			} else {
				$alpsIpTempHash{"$cluster"}{"$alpsUnit"}{"TOTAL"} += $gc;
				$alpsIpTempHash{"$cluster"}{"$alpsUnit"}{"TOTALINFRA"} += $infraGc;
				$alpsIpTempHash{"$cluster"}{"$alpsUnit"}{"COUNT"} += 1;
				$alpsIpTempHash{"$cluster"}{"$alpsUnit"}{"FUNC"} = $func;
			}
		} elsif (exists $alpsMapHash{"$unit0"}) {
			my $cluster = $alpsMapHash{"$unit0"}{"ALPSCLUSTER"};
			my $clustName = $alpsMapHash{"$unit0"}{"CLUSTER"};
			my $alpsUnit = $alpsMapHash{"$unit0"}{"ALPS"};
			my $func = $alpsMapHash{"$unit0"}{"FUNC"};
			if ($func eq "IGNORE") {warn "Unit $unit ignored for GC rollup\n"; next;}
			my $growth = 1.0;
			#my $unitName1 = $unitName."1";
			#my $unitName0 = $unitName."0";
			if ($pwrDbFmt && $adderData) {
				if (defined $unitSdGrowthHash{"$unit0"}) {
					$growth = $unitSdGrowthHash{"$unit0"};
				} elsif (defined $unitSdGrowthHash{"$clustName"}) {
					$growth = $unitSdGrowthHash{"$clustName"};
				} else {
					warn "Unit $unit0 doesn't have an entry in the SD growth file\n";
					print "Assuming a SD growth factor of 1.0 for unit $unit0\n";
				}
			}
			$gc = $gc * $growth * 1000.0;
			$infraGc = $infraGc * $growth * 1000.0;
			if ($alpsUnit =~ /FPUWRAP|FPU0/) {
				$alpsIpTempHash{"$cluster"}{"FPU0"}{"TOTAL"} += $gc/2;
				$alpsIpTempHash{"$cluster"}{"FPU0"}{"TOTALINFRA"} += $infraGc/2;
				$alpsIpTempHash{"$cluster"}{"FPU0"}{"COUNT"} += 1;
				$alpsIpTempHash{"$cluster"}{"FPU0"}{"FUNC"} = $func;
				$alpsIpTempHash{"$cluster"}{"FPU1"}{"TOTAL"} += $gc/2;
				$alpsIpTempHash{"$cluster"}{"FPU1"}{"TOTALINFRA"} += $infraGc/2;
				$alpsIpTempHash{"$cluster"}{"FPU1"}{"COUNT"} += 1;
				$alpsIpTempHash{"$cluster"}{"FPU1"}{"FUNC"} = $func;
			} elsif ($alpsUnit =~ /DFX|SmallUnits|SMALL|CP|ASSIGN|RPT/) {
				$alpsIpTempHash{"$cluster"}{"$alpsUnit"}{"TOTAL"} += $gc;
				$alpsIpTempHash{"$cluster"}{"$alpsUnit"}{"TOTALINFRA"} += $infraGc;
				$alpsIpTempHash{"$cluster"}{"$alpsUnit"}{"COUNT"} += 1;
				$alpsIpTempHash{"$cluster"}{"$alpsUnit"}{"FUNC"} = $func;
			} else {
				$alpsIpTempHash{"$cluster"}{"$alpsUnit"}{"TOTAL"} += $gc;
				$alpsIpTempHash{"$cluster"}{"$alpsUnit"}{"TOTALINFRA"} += $infraGc;
				$alpsIpTempHash{"$cluster"}{"$alpsUnit"}{"COUNT"} += 1;
				$alpsIpTempHash{"$cluster"}{"$alpsUnit"}{"FUNC"} = $func;
			}
		} else {
			#die "Unit $unit doesn't exist in the map file\n";
			warn "Unit $unit doesn't exist in the map file\n";
			my $growth = 1.0;
			if (defined $unitSdGrowthHash{"$unit"}) {
				$growth = $unitSdGrowthHash{"$unit"};
				$gc = $gc * $growth * 1000.0;
				$infraGc = $infraGc * $growth * 1000.0;
			} else {
				warn "Unit $unit doesn't have an entry in the SD growth file\n";
				print "Assuming a SD growth factor of 1.0 for unit $unit\n";
				$gc = $gc * $growth * 1000.0;
				$infraGc = $infraGc * $growth * 1000.0;
			}
			print "Unit $unit GC $gc Infra GC $infraGc\n";
		}
	}	
	foreach my $cluster (keys %alpsIpTempHash) {
		my %unitHash = %{$alpsIpTempHash{"$cluster"}};
		foreach my $unit (keys %unitHash) {
			my $func = $unitHash{"$unit"}{"FUNC"};
			if ($func eq "SUM") {
				$alpsIpHash{"$cluster"}{"$unit"}{"GC"} = $unitHash{"$unit"}{"TOTAL"};
				$alpsIpHash{"$cluster"}{"$unit"}{"INFRAGC"} = $unitHash{"$unit"}{"TOTALINFRA"};
			} elsif ($func eq "AVG") {
				$alpsIpHash{"$cluster"}{"$unit"}{"GC"} = $unitHash{"$unit"}{"TOTAL"}/$unitHash{"$unit"}{"COUNT"};
				$alpsIpHash{"$cluster"}{"$unit"}{"INFRAGC"} = $unitHash{"$unit"}{"TOTALINFRA"}/$unitHash{"$unit"}{"COUNT"};
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
				my $gc = $alpsIpHash{"$cluster"}{"$unit"}{"GC"};
				my $infraGc = $alpsIpHash{"$cluster"}{"$unit"}{"INFRAGC"};
				print $fileWH "$unit,$cluster,$gc,$infraGc\n";
				#print "$unit,$cluster,$gc,$infraGc\n";
			}  
		}
		#my $csv = Text::CSV::Slurp->create( input => \@alpsIpArray);
		#print $fileWH $csv;
	}
	close $fileWH;
	return 1;
}
