#!/usr/intel/bin/perl5.85

#require 5.001;
use diagnostics;
use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;

# Explicitly force glob to execute this function because of a
# bug wherein the 1st call to glob within the 2nd invocation of a sub
# returns null (as happens within readFile below)
use File::Glob "glob";

use FindBin qw($Bin $Script $RealBin $RealScript $Dir $RealDir);

use lib $RealBin;
use general_config;
use hierarchy;
use db_hash;
use implement_updates_to_formulas;
use output_functions;
use calc_power;
use regression;
use version;
#use map_suit2trace;


my ($mypath) = $RealBin;
my ($myname) = $RealScript;
my $myroot = "";
if ($mypath =~ m|^(.*?)/scripts/$|) {
	# Set $myroot to top-level ALPS directory = parent of scripts,config,formulas
	$myroot = $1;
} else {
	# Running from a non-standard source directory structure
	# Set $myroot to scripts dir itself
	$myroot = $mypath;
}
#print STDERR "\"$myname\" is running from: \"$mypath\"\n";
######


################# input parameters
(scalar(@ARGV) > 0) or (usage_and_bye());

my $cmdline;
my $lrb3Mode = 0;
my $cfgFile = "";
my $cfgDir = "";
my $hierarchyFile = "";
my $outputDir = "";
my $formulaFile = "";
my $aliasesFile = "";
my $xlformulaFile = "";
my $baselineUpdatesFile = "";
my $baselineUpdatesFileList = "";
my $procUpdatesFile = "";
my $procUpdatesFileList = "";
my $experiment = "";
my $logs = "";
my $loglist = "";
my $logsdir = "";
my $logsgrep = "";
my $logs_extension_to_remove_from_file_name = "\\.\\w+";
my @final_logslist = ();
my $numOfTDP = "";
my $num_of_traces_to_output_in_excel_in_fubs_level = 250;	# Set it to "0" or "" to disable this limit.
my $report_missing_counters = 1;
my $debug = '';
my $ecStatsFile = "";
my $regPowerFile = "";
my $regMapFile = "";
my $genECFormulaCol = 1;
my $sendEmail = 0;
my $printVersion = 0;
my $cohoPrep = 0;
my $enable_GT = 0;

$cmdline = join (' ', $0, @ARGV);

GetOptions(
			"-lrb3_mode" => \$lrb3Mode,

			"-cfg=s" => \$cfgFile,
			"-h|hierarchyfile=s" => \$hierarchyFile,
			"-o|outputdir=s" => \$outputDir,

			"-f|formulafile=s" => \$formulaFile,
            "-gtenable" => \$enable_GT,
			"-a|aliasesfile=s" => \$aliasesFile,
			"-xl|xlformulafile=s" => \$xlformulaFile,
			"-bf|baselineupdatesfile|powerformulas=s" => \$baselineUpdatesFile,
			"-bl|baselineupdateslist|powerformulaslist=s" => \$baselineUpdatesFileList,
			"-pf|procupdatesfile=s" => \$procUpdatesFile,
			"-pl|procupdateslist=s" => \$procUpdatesFileList,

			"-exp=s" => \$experiment,

			"-logs=s" => \$logs,
			"-loglist=s" => \$loglist,
			"-logsdir=s" => \$logsdir,
			"-logsgrep=s" => \$logsgrep,
			"-logs_extension_to_remove_from_file_name=s" => \$logs_extension_to_remove_from_file_name,

			"-TDP=s" => \$numOfTDP,

			"-num_of_traces_to_output_in_excel_in_fubs_level=i" => \$num_of_traces_to_output_in_excel_in_fubs_level,

			"-report_missing_counters=s" => \$report_missing_counters,
			"-debug" => \$debug,
			"-coho_prep" => \$cohoPrep,
			"-calc_power_even_if_zero_ipc!" => \$calc_power::calc_power_even_if_zero_ipc,

			"-ecs|ecstatsfile=s" => \$ecStatsFile,

			"-regression_powerfile=s" => \$regPowerFile,
			"-regression_mapfile=s" => \$regMapFile,

			"-output_ecformula=s" => \$genECFormulaCol,

			"-send_email" => \$sendEmail,
			"-v|version" => \$printVersion
		  ) || &usage_and_bye();

if ($printVersion) {
	print STDOUT "Running alps.pl version " . version::alps_version() . "\n";
	exit (0);
}


if ($outputDir eq "")
{
	$outputDir = "ALPSrun/";
} elsif (not ($outputDir =~ /\/$/))
{
	$outputDir = $outputDir."\/";
}
$outputDir = glob($outputDir);

if ($sendEmail) {
	system "echo 'Started running ALPS with configuration \"${experiment}\", at directory \"${outputDir}\"' | mail -s \"ALPS started with ${experiment} job\" \$LOGNAME >& /dev/null";
}

(-d $outputDir) or (system "mkdir -p $outputDir");
(-d $outputDir) or (output_functions::die_cmd("Can't find \"$outputDir\" as output directory"));
$output_functions::outputDir = $outputDir;
($experiment eq "") and ($experiment = "exp");
$output_functions::experiment = $experiment;
$calc_power::debug = $debug;

output_functions::open_log($outputDir . "ALPS_log_$experiment.txt") or output_functions::die_cmd("Can't open log file $outputDir" . "ALPS_log_$experiment.txt\n");

my $start_msg = "Running alps.pl version " . version::alps_version() . " at " . output_functions::time_stamp() . "\n";
print STDOUT "$start_msg";
output_functions::print_to_log("$start_msg");
output_functions::print_to_log("Command-line for this run: $cmdline\n\n");
output_functions::print_to_log("Using \"$outputDir\" as output directory\n");
output_functions::print_to_log("\"$myname\" is running from: \"$mypath\"\n");

input_and_initialize_config(\$cfgFile, $myroot, \$cfgDir, $lrb3Mode, $genECFormulaCol, $cohoPrep);

### Get the aliases file from the config if it exists there and was not given in the command line.
if ( ($aliasesFile eq "") and (general_config::getKnob("aliases_file") ne "-1") )
{
	$aliasesFile = general_config::getKnob("aliases_file");
}

# Find hierarchy.cfg file from same directory as top-level config file
# provided as -cfg argument; default = scripts-hsw/config/hsw/hierarchy.cfg
if ($hierarchyFile eq "") {
	$hierarchyFile = "$cfgDir/hierarchy.cfg";
} elsif ($hierarchyFile !~ /^\//) {
	$hierarchyFile = "$cfgDir/$hierarchyFile";
} else {
	$hierarchyFile =~ s|(.*)/([^/]+)|$2|;
	my $hierarchyDir = glob($1);
	if ($hierarchyDir ne $cfgDir) {
		output_functions::print_to_log("Replacing \"$hierarchyDir\" with \"$cfgDir\" as directory for hierarchy file\n");
	}
}
output_functions::print_to_log("Using \"$hierarchyFile\" as hierarchy file\n");

if (not ((defined $numOfTDP) and ($numOfTDP =~ /^\d+%?$/)))
{
	output_functions::print_to_log("Error in the number of TDP tests. Using 0 instead.\n");
	$numOfTDP = 0;
}
#################

################# main parsing algorithms
my %blocks_defined;
my %formulasHash;
my %fullformulasHash;
my %aliasesHash;
my %powerHash;
my $retVal = 1;
my %stats_used_in_formulas;
my %ecStats;

### Get the stats files list
if($enable_GT)
{
    #In case of un cleared temporary fiels from previous runs this is to clean them
    system("rm -f $logsdir/*$logsgrep*withgt*");
}

output_functions::print_to_log("Getting the list of stats files\n");
stats_handler::input_stats_files_list($logs, $loglist, $logsdir, $logsgrep, \@final_logslist);

if($enable_GT)
{
    print "Running GT ALPS to generate GT residencies ....... \n";
    my $i=0;
    for($i=0; $i <= $#final_logslist; $i++)
    {
        print "Processing trace $final_logslist[$i] for GT residencies\n";
        if($final_logslist[$i] =~ /gz$/)
        {
            system("gunzip $final_logslist[$i]");
            $final_logslist[$i] =~ s/\.gz$//;
            print "Unzipped $final_logslist[$i] before processing... \n";
        }
        my $gtCommand = "./keiko/coho/bin/ALPS/scripts/Gennysim7_scripts/run.pl -i $final_logslist[$i] -o temp.csv -arch 4";
        system("$gtCommand");

        system("sed -i 's/,/\t/g' temp.csv");
        system("echo 'gt_cycles 1' >> temp.csv");
        system("cat $final_logslist[$i] temp.csv > temp1.csv");
        system("mv temp1.csv $final_logslist[$i]_withgt");
        system("gzip $final_logslist[$i]");
        system("gzip $final_logslist[$i]_withgt");

        $final_logslist[$i] = "$final_logslist[$i]_withgt.gz";
        print "Zipped $final_logslist[$i] after processing ..... \n";
    }
}

### if there are no formulas and no logs, fail.
if (
		($formulaFile eq "") and
		($xlformulaFile eq "") and
		($baselineUpdatesFile eq "") and
		(scalar(@final_logslist) < 1)
   )
{
	if ($sendEmail) {
		system "echo 'FAILED running ALPS with configuration \"${experiment}\", at directory \"${outputDir}\"' | mail -s \"ALPS failed with ${experiment} job\" \$LOGNAME >& /dev/null";
	}
	usage_and_bye();
}

output_functions::print_to_log("Reading hierarchy file: $hierarchyFile\n");
hierarchy::read_hierarchy($hierarchyFile, \%blocks_defined) or output_functions::die_cmd("Can't find hierarchy file: \"$hierarchyFile\".\n");

output_functions::print_to_log("Reading power formulas.\n");
input_power_formulas($formulaFile, $aliasesFile, $xlformulaFile, $baselineUpdatesFile, $baselineUpdatesFileList, $procUpdatesFile, $procUpdatesFileList, \%formulasHash, \%aliasesHash, \%blocks_defined, \%fullformulasHash);


if ($report_missing_counters)
{
	stats_handler::get_used_stats_in_formulas(\%fullformulasHash, \%stats_used_in_formulas);
}

if (scalar(@final_logslist) > 0 && (! $cohoPrep))
{
	output_functions::print_to_log("**********************\nCalculating power\n**********************\n");
	my $GRPs = general_config::getKnob("GRPs");
	#($GRPs ne "-1") or output_functions::die_cmd("Can't find \"GRPs\" hash in the config files.\n");
	my $cycles_counter_hash = general_config::getKnob("cycles_counter_hash");
	($cycles_counter_hash ne "-1") or output_functions::die_cmd("Can't find \"cycles_counter_hash\" hash in the config files.\n");
	my $traces_not_to_include = general_config::getKnob("traces_not_to_include");
	#($traces_not_to_include ne "-1") or output_functions::die_cmd("Can't find \"traces_not_to_include\" hash in the config files.\n");

	calc_power::calc_power(	$experiment, \@final_logslist, $logs_extension_to_remove_from_file_name, \%formulasHash, \%powerHash, \%blocks_defined,
									$outputDir, $mypath, $GRPs, $traces_not_to_include, \%stats_used_in_formulas, \%fullformulasHash, $cycles_counter_hash,
									\%ecStats, $ecStatsFile, \%aliasesHash, $num_of_traces_to_output_in_excel_in_fubs_level); # calculate the power of the traces
}

# mkm: moving output_formula_files down past calc_power::calc_power,
# so that it will benefit from read_stats_from_file
# which is called inside calc_power::calc_power
output_formula_files(\%formulasHash, \%aliasesHash, \%fullformulasHash, \%powerHash);

### run regression (this feature is under construction and can't be used yet)
if (($regPowerFile ne "") and (0))
{
	my %regformulasHash;

#	copyHash(\%formulasHash, \%regformulasHash);
	output_functions::print_to_log("Performing regression using: $regPowerFile\n");
	regression::regression_run($experiment, $regPowerFile, $regMapFile, \%powerHash, $outputDir, \%formulasHash, \%regformulasHash); # perform the regression

	if (scalar(@final_logslist) >= 0)
	{
		output_functions::print_to_log("Calculating power using the regression\n");
#		calc_power::calc_power("REG" . $experiment, $final_logslist, \%regformulasHash, \%powerHash, \%blocks_defined, $outputDir, $mypath, $numOfTDP, \%stats_used_in_formulas); # calculate the power of the traces in loglist
	}
}

output_functions::close_log();

if ($sendEmail) {
	system "echo 'Finished running ALPS with configuration \"${experiment}\", at directory \"${outputDir}\"' | mail -s \"ALPS finished with ${experiment} job\" \$LOGNAME >& /dev/null";
}

##Cleaning the temporary gt stat files created during the run \n ###";
if($enable_GT)
{
    my $i=0;
    for($i=0; $i<=$#final_logslist; $i++)
    {
        system("rm $logsdir/$final_logslist[$i]*withgt*");
    }
}

exit(0);
#################



################################################################### Functions definition ##################################################################


################# output formula files
sub output_formula_files {
	if (@_ != 4) {return "";}
	my ($formulasHash, $aliasesHash, $fullformulasHash, $powerHash) = @_;

	output_functions::print_to_log("*****************************\nPrinting formula files\n*****************************\n");

	my $cycles_counter_hash = general_config::getKnob("cycles_counter_hash");

	output_functions::output_formulas_files_in_coho_syntax($formulasHash, $aliasesHash, $cycles_counter_hash);
	if (general_config::getKnob ("cohoPrep") != 1) {
		output_functions::output_formulas_in_ALPS_xls_style($formulasHash, $fullformulasHash, $powerHash);
	}
}
#################


################# input and initialize the config
sub input_and_initialize_config {
	if (@_ != 6) {return "";}
	my ($cfgFile, $myroot, $cfgDir, $lrb3Mode, $genECFormulaCol, $cohoPrep) = @_;

	# Resolve cfgFile
	if ($$cfgFile eq "") {
		output_functions::die_cmd("No \"-cfg <config_file>\" specified; please provide config file and rerun. Exiting...\n");
	} elsif (-e glob ($$cfgFile)) {
		$$cfgFile = glob ($$cfgFile);
	} elsif (-e glob ($myroot . "config/" . $$cfgFile)) {
		$$cfgFile = $myroot . "config/" . $$cfgFile;
	} else {
		output_functions::die_cmd("Can't find config file \"$$cfgFile\"\n");
	}
	$$cfgDir = $$cfgFile;
	$$cfgDir =~ s|^(.*)/[^/]+$|$1|;

	output_functions::print_to_log("Using $$cfgFile as main config file\n");
	general_config::initConfig($$cfgFile);

	my $cfgHash = general_config::getConfigHash();

	# Indicates whether this is a LRB3 model run
	$$cfgHash{lrb3Mode} = $lrb3Mode;

	# Indicates whether to output separate EC formula column in power_*output*.xls files
	$$cfgHash{genECFormulaCol} = $genECFormulaCol;

	# Only generate Coho input formula files?
	$$cfgHash{cohoPrep} = $cohoPrep;

	# Threshold max power for error checking power calc
	$calc_power::power_too_big_threshold = general_config::getKnob ("power_too_big_threshold");

	# Generate power output even if IPC==0?
	my $tmp = general_config::getKnob ("calc_power_even_if_zero_ipc");
	if ($tmp != -1) {
   	 $calc_power::calc_power_even_if_zero_ipc = $tmp;
	}

	# Initialize to non-powerSection state
	$$cfgHash{powerSection} = 0;
}
#################


################# input the power formulas
sub input_power_formulas {
	if (@_ != 11) {return 0;}
	my ($formulaFile, $aliasesFile, $xlformulaFile, $baselineUpdatesFile, $baselineUpdatesFileList, $procUpdatesFile, $procUpdatesFileList, $formulasHash, $aliasesHash, $blocks_defined, $fullformulasHash) = @_;

	my %baselineHash;

	if ($aliasesFile ne "")
	{
		output_functions::print_to_log("Reading aliases file: $aliasesFile\n");
		$retVal = db_hash::read_aliases_into_aliasesHash($aliasesFile, $aliasesHash);
		if (($retVal == 0) or (scalar(keys %$aliasesHash) == 0))
		{
			output_functions::die_cmd("Error reading \"$aliasesFile\"\n");
		}
	}
	if ($formulaFile ne "")
	{
		output_functions::print_to_log("Reading formula file: $formulaFile\n");
		$retVal = db_hash::read_formulas_into_finalHash($formulaFile, $formulasHash, $aliasesHash, $blocks_defined); # read the formulas into %formulasHash
		if (($retVal == 0) or (scalar(keys %$formulasHash) == 0))
		{
			output_functions::die_cmd("Error reading \"$formulaFile\"\n");
		}
	}
	if ($xlformulaFile ne "")
	{
		output_functions::print_to_log("Reading formula file: $xlformulaFile\n");
		$retVal = db_hash::read_formulas_from_excel_into_finalHash($xlformulaFile, $formulasHash, $aliasesHash, $blocks_defined); # read the formulas into %formulasHash
		if (($retVal == 0) or (scalar(keys %$formulasHash) == 0))
		{
			output_functions::die_cmd("Error reading \"$xlformulaFile\"\n");
		}
	}
	if ($baselineUpdatesFile ne "")
	{
		$retVal = implement_updates_to_formulas::implement_updates_to_formulas_from_update_files("updatesfile", $baselineUpdatesFile, $formulasHash, $aliasesHash, \%baselineHash); # implement an update file on top of the coho formula file
		if ($retVal == 0)
		{
			output_functions::die_cmd("Error implementing the updates!\n");
		}
	}
	if ($baselineUpdatesFileList ne "")
	{
		$retVal = implement_updates_to_formulas::implement_updates_to_formulas_from_update_files("updatesfilelist", $baselineUpdatesFileList, $formulasHash, $aliasesHash, \%baselineHash); # implement updates files on top of the coho formula file
		if ($retVal == 0)
		{
			output_functions::die_cmd("Error implementing the updates!\n");
		}
	}

	copyHash($formulasHash, \%baselineHash);

	if ($procUpdatesFile ne "")
	{
		$retVal = implement_updates_to_formulas::implement_updates_to_formulas_from_update_files("updatesfile", $procUpdatesFile, $formulasHash, $aliasesHash, \%baselineHash); # implement an update file on top of the coho formula file
		if ($retVal == 0)
		{
			output_functions::die_cmd("Error implementing the updates!\n");
		}
	}
	if ($procUpdatesFileList ne "")
	{
		$retVal = implement_updates_to_formulas::implement_updates_to_formulas_from_update_files("updatesfilelist", $procUpdatesFileList, $formulasHash, $aliasesHash, \%baselineHash); # implement updates files on top of the coho formula file
		if ($retVal == 0)
		{
			output_functions::die_cmd("Error implementing the updates!\n");
		}
	}

	copyMultiHash($formulasHash, $fullformulasHash);

	return 1;
}
#################


################# copy a hash
sub copyHash {
	if (@_ != 2) {return 0;}
	my ($baseHash, $finalHash) = @_;

	foreach my $location (keys %$baseHash)
	{
		foreach my $cluster (keys %{$$baseHash{$location}})
		{
			foreach my $unit (keys %{$$baseHash{$location}{$cluster}})
			{
				foreach my $fub (keys %{$$baseHash{$location}{$cluster}{$unit}})
				{
					foreach my $element (keys %{$$baseHash{$location}{$cluster}{$unit}{$fub}})
					{
						if ($element ne "Functions")
						{
							$$finalHash{$location}{$cluster}{$unit}{$fub}{$element} = $$baseHash{$location}{$cluster}{$unit}{$fub}{$element};
						}
						else
						{
							foreach my $function (keys %{$$baseHash{$location}{$cluster}{$unit}{$fub}{"Functions"}})
							{
								foreach my $element (keys %{$$baseHash{$location}{$cluster}{$unit}{$fub}{"Functions"}{$function}})
								{
									$$finalHash{$location}{$cluster}{$unit}{$fub}{"Functions"}{$function}{$element} = $$baseHash{$location}{$cluster}{$unit}{$fub}{"Functions"}{$function}{$element};
								}
							}
						}
					}
				}
			}
		}
	}

	return 1;
}
#################


################# copy the formulas hash while changing the hierarchy to support multicores
sub copyMultiHash {
	if (@_ != 2) {return 0;}
	my ($baseHash, $finalHash) = @_;

	foreach my $location (keys %$baseHash)
	{
		if ($location eq "core0") {$location = "core";}

		my $blocks = general_config::getKnob("${location}_multi_inst_num");
		($blocks > 0) or ($blocks = 1);
        my $start_num = 0;
		my $loc = $location;
		my $prefix_org = "";
		my $prefix_dest = "";
		if ($blocks > 1)
		{
            # Enable multiple instantiation to start at user-defined number
            # rather than hard-coding to 0 .. n-1
            $start_num = general_config::getKnob("${location}_multi_inst_start_num");
            if ($start_num == -1) {
                $start_num = 0;
            }

			$loc = general_config::getKnob("${location}_multi_inst_loc");
			$prefix_org = general_config::getKnob("${location}_multi_inst_prefix_org");
			$prefix_dest = general_config::getKnob("${location}_multi_inst_prefix_dest");
			if (($loc eq -1) or ($prefix_org eq -1) or ($prefix_dest eq -1))
			{
				output_functions::print_to_log("Error in knobs parameters of ${location}! Using one instance.\n");
				$blocks = 1;
				$loc = $location;
			}
		}

		for (my $i = $start_num; $i < ($blocks + $start_num); $i++)
		{
			my $location_block = $loc;
			if (($blocks > 1) or ($location_block =~ /^core$/)) {$location_block .= $i;}

			foreach my $cluster (keys %{$$baseHash{$location}})
			{
				foreach my $unit (keys %{$$baseHash{$location}{$cluster}})
				{
					foreach my $fub (keys %{$$baseHash{$location}{$cluster}{$unit}})
					{
						foreach my $element (keys %{$$baseHash{$location}{$cluster}{$unit}{$fub}})
						{
							if ($element eq "LeakageData")
							{
								foreach my $le (keys %{$$baseHash{$location}{$cluster}{$unit}{$fub}{"LeakageData"}})
								{
									$$finalHash{$location_block}{$cluster}{$unit}{$fub}{"LeakageData"}{$le} = $$baseHash{$location}{$cluster}{$unit}{$fub}{"LeakageData"}{$le};
								}
							}
							elsif ($element eq "Functions")
							{
								foreach my $function (keys %{$$baseHash{$location}{$cluster}{$unit}{$fub}{"Functions"}})
								{
									foreach my $func_element (keys %{$$baseHash{$location}{$cluster}{$unit}{$fub}{"Functions"}{$function}})
									{
										my $val = $$baseHash{$location}{$cluster}{$unit}{$fub}{"Functions"}{$function}{$func_element};

										if (($func_element eq "Formula") and ($val eq ""))
										{
											output_functions::print_to_log("Error: Formula has no value at fub $fub at function $function. Setting it to 0.\n");
											$$baseHash{$location}{$cluster}{$unit}{$fub}{"Functions"}{$function}{$func_element} = 0;
											$val = 0;
										}
										if (($func_element eq "Power") and ($val eq ""))
										{
											output_functions::print_to_log("Error: EC has no value at fub $fub at function $function. Setting it to 0.\n");
											$$baseHash{$location}{$cluster}{$unit}{$fub}{"Functions"}{$function}{$func_element} = 0;
											$val = 0;
										}

										if ($blocks > 1)
										{
											$val =~ s/${prefix_org}\./${prefix_dest}${i}\./g;
										}

										$$finalHash{$location_block}{$cluster}{$unit}{$fub}{"Functions"}{$function}{$func_element} = $val;
									}
								}
							}
							else
							{
								$$finalHash{$location_block}{$cluster}{$unit}{$fub}{$element} = $$baseHash{$location}{$cluster}{$unit}{$fub}{$element};
							}
						}
					}
				}
			}

		}
	}

	return 1;
}
#################


################# bad syntax -> usage and bye
sub usage_and_bye {

	print STDERR "
Usage:
------

Parameters are organized into groups, with usage guidelines per group.

Input formula file spec (specify 1 of these):
  -f|formulafile <file>       :   Coho baseline (Nehalem) formula file
  -baselineupdatesfile <file> :   Baseline updates formula file.
                                  These updates will be implemented over the baseline formula file,
                                  to create a new updated baseline (Nehalem).
  -baselineupdateslist <file> :   A file that contains a list of baseline updates formula files.
                                  These updates will be implemented over the baseline formula file,
                                  to create a new updated baseline (Nehalem).
  -pf|procupdatesfile <file>  :   Target processor updates formula file.
                                  These updates will be implemented over the baseline formula file,
                                  to create a new target processor (Gesher).
  -pl|procupdateslist <file>  :   A file that contains a list of target processor updates formula files.
                                  These updates will be implemented over the baseline formula file,
                                  to create a new target processor (Gesher).

Input logs == stats files (specify 1 of these):
  -logs \"<traces log files>\"  :   Coho stats files; important to enclose in \"\" to prevent
                                  premature filename expansion by shell.
  -loglist <file>             :   A file that contains a list of Coho stats files.
                                  For example: gesher.list

Optional arguments (note default action for each option if omitted):
  -a|aliasesfile <file>       :   coho baseline (Nehalem) aliases file.
                                  Default: no aliases set up.
  -ecs|ecstatsfile <file>	 :   Coho stats file designated as the source for knob values
                                  to be applied to expressions in the EC (event energy cost) column.
                                  Default: use knob values from the first Coho stats file read.
  -coho_prep <0|1>			  :   1 ==> only output Coho formula and aliases files
                                  0 ==> generate full set of output files (default)
  -exp <name>                 :   The name of the experiment, concatenated into all
                                  output file names. Default: \"\"
  -h|hierarchyfile <file>     :   A file containing the hierarchy (valid clusters and valid units).
                                  Default: config/hsw/hierarchy.cfg
  -o|outputdir <dir>          :   The output directory. Default: \"./ALPSrun/\"

Output files:
  Formula files:
    \"power_formulas_<exp>.xls\" :   Formula per fub (name, unit, cluster, location, idle,
                                  leakage, function*, formula*, power*),
                                  spread into columns for excel format (tab delimited).
    \"power_formulas_<exp>.input\":  The power formulas in Coho statistics style.
    \"power_formulas_<exp>.aliases.input\":
                                  The aliases formula file.
  Power result files:
    \"power_output.<exp>.<segment>.xls\":
								  The calculated power per test, in Excel spreadsheet,
                                  with separate sheets by function, FUB, unit, cluster, globals and IPC.
    \"power_txt_output_functions.<exp>.<segment>.xls\":
                                  The calculated power per test, in tab-separated text file format,
                                  organized by functions (i.e., events).
    \"power_txt_output_fubs.<exp>.<segment>.xls\":
                                  The calculated power per test, in tab-separated text file format,
                                  organized by FUBs.

  Debug files:

";

	exit(1);
}
#################


#print Dumper(\%fubsHash);

