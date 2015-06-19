#!/p/gat/tools/perl/perl5.14/bin/perl

=head1 NAME

gen_top_power.pl - Creates a partition DOP and top level glue/BUF power model model in a CSV file from power virus/idle data

=head1 SYNOPSIS

	"help"			For printing help message 
	"man" 			For printing detailed information
	"debug"			For printing the sequence of commands
	"small_part"		Partition the SMALL unit Cdyn into CP, ASSIGN, RPT
	"par_list"		List of partitions (only required if --small_part is specified)
	"gt_power_data"		Path to file containing idle/power virus data
	"alps_unit_map"		Path to file unit to cluster ALPS-G mapping
	"work_area"		Path to print output power data in a *.csv file
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
my $smallPart;

my $parList;
my $gtPowerData;
my $alpsUnitMap;
my $workArea;
my $outputCsvFile;

#my $dfxPattern = "mcr|noa|cpunit|lcp|misr|scan|idv|ramdt|gdx";
my $dfxPattern = "mcr|noa|lcp|misr|scan|idv|ramdt|gdx";

Getopt::Long::GetOptions(
	"help" => \$optHelp,
	"man"  => \$optMan,   	
	"debug" => \$debugMode,
        "small_part" => \$smallPart,
	"par_list=s" => \$parList,
	"gt_power_data=s" => \$gtPowerData,
	"alps_unit_map=s" => \$alpsUnitMap,
	"work_area=s" => \$workArea,
	"output_csv_file=s" => \$outputCsvFile
) or Pod::Usage::pod2usage("Try $0 --help/--man for more information...");

pod2usage( -verbose => 1 ) if $optHelp;
pod2usage( -verbose => 2 ) if $optMan;

if ($smallPart) {print "Will partition SMALL Cdyn into CP|RPT|ASSIGN|REST\n";}

if ($smallPart)
{
	if ($parList =~ /^$/) {die "Input partition list has not been provided\n";}
	if (!(-f $parList)) {warn "Input partition list file $parList doesn't exist\n";}
}

if ($gtPowerData =~ /^$/) {die "Input GT power data file name not provided\n";}
if (!(-f $gtPowerData)) {warn "Input file $gtPowerData doesn't exist\n"}

if ($alpsUnitMap =~ /^$/) {die "ALPS input map file name not provided\n";}
if (!(-f $alpsUnitMap)) {warn "ALPS input map file $alpsUnitMap doesn't exist\n"}

if ($workArea =~ /^$/) {die "Path to output directory not provided\n";}
if (! -d $workArea) {die "Path to output directory $workArea not a directory\n";}
if (! -w $workArea) {die "Path to output directory $workArea not writeable\n";}

if ($outputCsvFile =~ /^$/) {die "Output file name not provided\n";}
if ($outputCsvFile =~ /\//) {die "Please only provided file name...don't give path\n";}
if (-f $outputCsvFile) {warn "Output file $outputCsvFile already exists...will be overwritten...\n"}

my $alpsUnitMapH;

open $alpsUnitMapH, "$alpsUnitMap" or die "Cannot open input file $alpsUnitMap\n";

my %alpsUnitsH;
my %smallUnitsH;

while(<$alpsUnitMapH>) {
	my $line = $_;
	chomp($line);
	my @parts = split(",", $line);
	if ($parts[3] eq "No" && $parts[4] eq "SmallUnits") {
		$smallUnitsH{$parts[0]} = 1;
	}  
	if ($parts[3] eq "Yes") {
		$alpsUnitsH{$parts[0]} = 1;
	}	
}

my %ipParH;

if ($smallPart)
{
	my $ipParListH;
	open $ipParListH, "$parList" or die "Cannot open input partition list $parList\n";

	while (<$ipParListH>)
	{
		my $line = $_;
		chomp($line);
		my @parts = split(",", $line);
		my $par = $parts[0];
		$ipParH{"$par"} = 1;
	}
}

close $alpsUnitMapH;

my $gtPowerDataH;

open $gtPowerDataH, "$gtPowerData" or die "Cannot open input file $gtPowerData\n";

my @gtPowerDataA;
@gtPowerDataA = <$gtPowerDataH>;

my %gtParH;
my %gtCpParH;
my %gtRptParH;
my %gtAssignParH;

my $parNameAssign = "";

foreach (@gtPowerDataA) {
	my $line = $_;
	chomp($line);
	$line =~ s/^\s*//;
	$line =~ s/\s*$//;
	$line =~ s/^(,)+//;
	$line =~ s/(,)+$//;
	$line =~ s/^(,)+$//;
	if ($line eq "") {next;}
	my $parName;
	my $isRptr = "";

	my $parTop;
	my $parDop;

	my $parRpt;
	my $parCpCmp;
	my $parRptrCpCmp;
	my $parCp;	
	my $parAssign;

	if ($smallPart)
	{
		my @parts = split(",", $line);
		my $parLine = $parts[0];
		if (exists $ipParH{"$parLine"})
		{
			$parNameAssign = $line;
		}
	}

	my $parTopCell;
	my $parTopDop;
	my $parTopBuf;
	my $parTopClkDriver;
	my $parTopDelayBuf;
	my $parTopClkInv;
	my $parTopClkCg;
	my $parTopOther;

        if ($smallPart)
        {
        	if ($line =~ /([a-zA-Z0-9_]+)_rpt_Power/)  {
			$parName = $1;
			my @parts = split(",", $line);
			$parRpt = $parts[3];
			$gtParH{$parName}{"RPT"} = $parRpt;
		}

		if ($line =~ /([a-zA-Z0-9_]+)(rptr)?cpunit1/)  {
			$parName = $1;
			if ($parName =~ /^(skl|cnl)/)
			{
				my $match = $1;
				$parName =~ s/^$match//;
			}
			$isRptr  = $2;
			my @parts = split(",", $line);
			if (!(defined $isRptr))
			{
				$gtCpParH{$parName}{"CP"} = $parts[3];
			}
			elsif ($isRptr =~ /^rptr$/)
			{
				$gtCpParH{$parName}{"RPTRCP"} = $parts[3];
			}
			else
			{
				print "-WARN- $parName has a non-standrd RPTR pattern $isRptr\n";
			}
		}

		if ($line =~ /([a-zA-Z0-9_]+)rptunit1/)  {
			$parName = $1;
			if ($parName =~ /_$/)
			{
				$parName =~ s/_$//;
			}
			if ($parName =~ /^(skl|cnl)/)
			{
				my $match = $1;
				$parName =~ s/^$match//;
			}
			my @parts = split(",", $line);
			$gtRptParH{$parName}{"RPT"} = $parts[3];
		}

		if ($line =~ /assign/)
		{
			if ($line !~/([a-zA-Z0-9_]+)_assign_Power/)
			{
				$parName = $parNameAssign;
				my @parts = split(",", $line);
				my $assignUnitName = $parts[0];
				if ($parName !~ /^$/)
				{
					$gtAssignParH{$parName}{"ASSIGN"} += $parts[3];
				}
				else
				{
					print "-WARN- Couldn't find a valid partition name to add the assign unit $assignUnitName power to\n";
				}
			}
		}

		if ($line =~ /([a-zA-Z0-9_]+)_cp_Power/)  {
			$parName = $1;
			my @parts = split(",", $line);
			$parCp = $parts[3];
			$gtParH{$parName}{"CP"} = $parCp;
		}

		if ($line =~ /([a-zA-Z0-9_]+)_assign_Power/)  {
			$parName = $1;
			my @parts = split(",", $line);
			$parAssign = $parts[3];
			$gtParH{$parName}{"ASSIGN"} = $parAssign;
		}
	}

	if ($line =~ /([a-zA-Z0-9_]+)_top_level_power/)  {
		$parName = $1;
		my @parts = split(",", $line);
		$parTop = $parts[3];	
		$gtParH{$parName}{"TOP"} = $parTop;
	}
	if ($line =~ /([a-zA-Z0-9_]+)_Top_Cell_POWER/i) {
		$parName = $1;
		my @parts = split(",", $line);
		$parTopCell = $parts[3];
		$gtParH{$parName}{"TOPCELL"} = $parTopCell;
	}
	if ($line =~ /([a-zA-Z0-9_]+)_Top_Dop_POWER/i) {
		$parName = $1;
		my @parts = split(",", $line);
		$parTopDop = $parts[3];
		$gtParH{$parName}{"TOPDOP"} = $parTopDop;
	}
	if ($line =~ /([a-zA-Z0-9_]+)_Top_Buf_POWER/i) {
		$parName = $1;
		my @parts = split(",", $line);
		$parTopBuf = $parts[3];
		$gtParH{$parName}{"TOPBUF"} = $parTopBuf;
	}
	if ($line =~ /([a-zA-Z0-9_]+)_Top_ClkDriver_POWER/i) {
		$parName = $1;
		my @parts = split(",", $line);
		$parTopClkDriver = $parts[3];
		$gtParH{$parName}{"TOPCLKDRIVER"} = $parTopClkDriver;
	}
	if ($line =~ /([a-zA-Z0-9_]+)_Top_DelayBuf_POWER/i) {
		$parName = $1;
		my @parts = split(",", $line);
		$parTopDelayBuf = $parts[3];
		$gtParH{$parName}{"TOPDELAYBUF"} = $parTopDelayBuf;
	}
	if ($line =~ /([a-zA-Z0-9_]+)_Top_(ClkInv|Inv)_POWER/i) {
		$parName = $1;
		my @parts = split(",", $line);
		$parTopClkInv = $parts[3];
		$gtParH{$parName}{"TOPCLKINV"} = $parTopClkInv;
	}
	if ($line =~ /([a-zA-Z0-9_]+)_Top_ClkCg_POWER/i) {
		$parName = $1;
		my @parts = split(",", $line);
		$parTopClkCg = $parts[3];
		$gtParH{$parName}{"TOPCLKCG"} = $parTopClkCg;
	}
	if ($line =~ /([a-zA-Z0-9_]+)_Top_Other_POWER/i) {
		$parName = $1;
		my @parts = split(",", $line);
		$parTopOther = $parts[3];
		$gtParH{$parName}{"TOPOTHER"} = $parTopOther;
	}
	if ($line =~ /([a-zA-Z0-9_]+)_Clk_DOP_Power/)  {
		$parName = $1;
		my @parts = split(",", $line);
		$parTop = $parts[3];
		if (!exists $gtParH{$parName}) {die "Why doesn't partition $parName exist in the hash already?\n";}	
		$gtParH{$parName}{"DOP"} = $parTop;
	}
	if ($line =~ /([a-zA-Z0-9_]+)_DOP_1x_POWER/)  {
		$parName = $1;
		my @parts = split(",", $line);
		$parTop = $parts[3];
		if (!exists $gtParH{$parName}) {die "Why doesn't partition $parName exist in the hash already?\n";}	
		$gtParH{$parName}{"DOP1X"} = $parTop;
	}
	if ($line =~ /([a-zA-Z0-9_]+)_DOP_2x_POWER/)  {
		$parName = $1;
		my @parts = split(",", $line);
		$parTop = $parts[3];
		if (!exists $gtParH{$parName}) {die "Why doesn't partition $parName exist in the hash already?\n";}	
		$gtParH{$parName}{"DOP2X"} = $parTop;
	}
	
}

my $count;
for ($count = 0; $count < scalar(@gtPowerDataA); $count++) {
	my $line = $gtPowerDataA[$count];
	chomp($line);
	$line =~ s/^\s*//;
	$line =~ s/\s*$//;
	$line =~ s/^(,)+//;
	$line =~ s/(,)+$//;
	$line =~ s/^(,)+$//;
	if ($line eq "") {next;}
	if ($line =~ /Partition\/Unit/) {next;}
	my @parts = split(",", $line);
	my $parName = $parts[0];
	if (exists $gtParH{$parName}) {
		do {
			$count++;		
			my $inLine = $gtPowerDataA[$count];
			chomp($line);
			$inLine =~ s/^\s*//;
			$inLine =~ s/\s*$//;
			$inLine =~ s/^(,)+//;
			$inLine =~ s/(,)+$//;
			$inLine =~ s/^(,)+$//;
			if ($inLine eq "") {next;}
			if ($inLine =~ /$dfxPattern/) {
				my @parts = split(",", $inLine);
				my $parDfx = $parts[3];
				$gtParH{$parName}{"DFX"} += $parDfx;
			}
			my @inParts = split(",", $inLine);
			my $testUnitName = $inParts[0];
			if (exists $smallUnitsH{$testUnitName}) {
				my $parSmall = $inParts[3];
				$gtParH{$parName}{"SMALL"} += $parSmall;
			} elsif ((! exists $alpsUnitsH{$testUnitName}) && ($testUnitName !~ /_rpt_|_assign_|_functional_|_global_|_top_level_|_combo_|_Other_|_Flop_|_LATCH_|_SRAM_|_AND_|_BUF_|_DOP_|_FLOP_|_cf2xclk|_cfclk|_cfts2xclk|_cftsclk|_cmclk|_cpclk|_cr2xclk|_crclk|_csfcclk|_cu2xclk|_cu2xdtclk|_cuclk|_cudtclk|_cvclk|_cwclk|_halfmclk|_halfmdtclk|_halfuclk|_scf2xclk|_scfclk|_scmsclk|_scr2xclk|_scrclk|_scrhdcmdclk|_scrhdrt2xclk|_scrhdrtclk|_scrhdtlbaclk|_scrhdtlbbclk|_scrhdtlbcclk|_scu2xclk|_scu2xdtclk|_scuclk|_scudtclk|_uclk|_udtclk|_Top_Cell_|_Top_Dop_|_Top_Buf_|_Top_ClkDriver_|_Top_DelayBuf_|_Top_ClkInv_|_Top_ClkCg_|_Top_Other_/)) {
				my $parSmall = $inParts[3];
				$gtParH{$parName}{"SMALL"} += $parSmall;
			}  
			
		} while ($line !~ /_functional_/); 	 
	}
	$count++;
} 

my $outputCsvFileH;
$outputCsvFile = $workArea."/".$outputCsvFile;
open $outputCsvFileH, ">$outputCsvFile" or die "Cannot open output CSV file: $outputCsvFile\n";

if ($smallPart)
{
	print $outputCsvFileH "PAR, TOP, TOPCELL, TOPDOP, TOPBUF, TOPCLKDRIVER, TOPDELAYBUF, TOPCLKINV, TOPCLKCG, TOPOTHER, DOP, DFX, SMALL, CP, ASSIGN, RPT\n";
}
else
{
	print $outputCsvFileH "PAR, TOP, TOPCELL, TOPDOP, TOPBUF, TOPCLKDRIVER, TOPDELAYBUF, TOPCLKINV, TOPCLKCG, TOPOTHER, DOP, DFX, SMALL\n";
}

foreach my $key (keys %gtParH) {
	#my $line = $key.",".$gtParH{$key}{"TOP"}.",".$gtParH{$key}{"DOP"}.",".$gtParH{$key}{"DFX"}.",".$gtParH{$key}{"SMALL"};
	my $line;
	if ($smallPart)
	{
		my $totCp;
		my $totRpt;
		my $totAssign;
		if (exists $gtParH{$key}{"CP"})
		{
			$totCp = $gtParH{$key}{"CP"};
		}
		else
		{
			if (exists $gtCpParH{$key}{"CP"} && exists $gtCpParH{$key}{"RPTRCP"})
			{
				$totCp = $gtCpParH{$key}{"CP"} + $gtCpParH{$key}{"RPTRCP"};  
			}
			elsif (exists $gtCpParH{$key}{"CP"} && !(exists $gtCpParH{$key}{"RPTRCP"}))
			{
				$totCp = $gtCpParH{$key}{"CP"};
			}
			elsif (!(exists $gtCpParH{$key}{"CP"}) && exists $gtCpParH{$key}{"RPTRCP"})
			{
				$totCp = $gtCpParH{$key}{"RPTRCP"};
			}
			else
			{
				$totCp = 0;
				print "-WARN- CP Unit power doesn't exist for partition $key\n";
			}
		}

		if (exists $gtParH{$key}{"RPT"})
		{
			$totRpt = $gtParH{$key}{"RPT"};
		}
		else
		{
			if (exists $gtRptParH{$key}{"RPT"})
			{
				$totRpt = $gtRptParH{$key}{"RPT"};
			}
			else
			{
				$totRpt = 0;
				print "-WARN- RPT Unit power doesn't exist for partition $key\n";
			}
		}

		if (exists $gtParH{$key}{"ASSIGN"})
		{
			$totAssign = $gtParH{$key}{"ASSIGN"};
		}
		else
		{
			if (exists $gtAssignParH{$key}{"ASSIGN"})
			{
				$totAssign = $gtAssignParH{$key}{"ASSIGN"};
			}
			else
			{
				$totAssign = 0;
				print "-WARN- ASSIGN Unit power doesn't exist for partition $key\n";
			}
		}

		$line = $key.",".$gtParH{$key}{"TOP"}.",".$gtParH{$key}{"TOPCELL"}.",".$gtParH{$key}{"TOPDOP"}.",".$gtParH{$key}{"TOPBUF"}.",".$gtParH{$key}{"TOPCLKDRIVER"}.",".$gtParH{$key}{"TOPDELAYBUF"}.",".$gtParH{$key}{"TOPCLKINV"}.",".$gtParH{$key}{"TOPCLKCG"}.",".$gtParH{$key}{"TOPOTHER"}.",".$gtParH{$key}{"DOP"}.",".$gtParH{$key}{"DFX"}.",".$gtParH{$key}{"SMALL"}.",".$totCp.",".$totAssign.",".$totRpt;

	}
	else
	{
		$line = $key.",".$gtParH{$key}{"TOP"}.",".$gtParH{$key}{"TOPCELL"}.",".$gtParH{$key}{"TOPDOP"}.",".$gtParH{$key}{"TOPBUF"}.",".$gtParH{$key}{"TOPCLKDRIVER"}.",".$gtParH{$key}{"TOPDELAYBUF"}.",".$gtParH{$key}{"TOPCLKINV"}.",".$gtParH{$key}{"TOPCLKCG"}.",".$gtParH{$key}{"TOPOTHER"}.",".$gtParH{$key}{"DOP"}.",".$gtParH{$key}{"DFX"}.",".$gtParH{$key}{"SMALL"};
	}

	print $outputCsvFileH $line."\n"; 
}

close $gtPowerDataH;
close $outputCsvFileH;
