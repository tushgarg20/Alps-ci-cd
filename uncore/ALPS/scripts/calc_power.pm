package calc_power;

use diagnostics;
use strict;
use warnings;
use Data::Dumper;
use FindBin qw($Bin $Script $RealBin $RealScript $Dir $RealDir);

use lib $RealBin;
use general;
use general_config;
use output_functions;
use stats_handler;
use db_hash;
use calc_leakage;

our $debug;
our $calc_power_even_if_zero_ipc = 0;
our $output_histograms_sizes_report_file = 1;
our $calculate_groups = 1;
our $output_counters_values = 1;
our $output_power_output_files = 1;
our $output_power_into_stats_files = 0;
our $overwrite_stats_files = 0;
our $power_too_big_threshold;

################# calculate the ECs which can be dependant on knob values coming from a stat file
### usage: calc_ECs(<experiment name>, <log list>, <pointer to the formulasHash>, <pointer to functions activity hash>, <pointer to the blocks_defined hash>, <output dir>, <leakage data file path>, <number of TDP traces>, \%stats_used_in_formulas)
sub calc_ECs
{
	if (@_ != 5) {die "Error in function parameters";}
	my ($logs, $powerHash, $fullformulasHash, $ecStatsFile, $aliasesHash) = @_;

	my %ec_stats_hash;
	my %ec_stats_validity;
	my $ec_histos_to_exclude = ();

	# If "designated stats file" for EC formulas is given, read it,
	# taking care not to perturb any other state of the data model
	# by providing throw-away args to make the call
	# Else, use the first file from @$logs[] as "designated stats file"
	if ($ecStatsFile eq "") {
		$ecStatsFile = $$logs[0];
	}
	chomp $ecStatsFile;
	$ecStatsFile =~ s/\r$//;
	my %ecStats;
	my $ecStatsFile_trace_name = stats_handler::get_trace_name_from_stats_file_name($ecStatsFile);
	stats_handler::read_stats_from_file(	\%ecStats, \%ec_stats_hash, \%ec_stats_validity, $ecStatsFile,
														$ec_histos_to_exclude, 1, $ecStatsFile_trace_name);

	insertECs($powerHash, $fullformulasHash, \%ecStats, $aliasesHash);

	return \%ecStats;
}
#################


################# calculate the power of a list of traces
### usage: calc_power(<experiment name>, <log list>, <pointer to the formulasHash>, <pointer to functions activity hash>, <pointer to the blocks_defined hash>, <output dir>, <leakage data file path>, <number of TDP traces>, \%stats_used_in_formulas)
sub calc_power
{
	if (@_ != 14) {die "Error in function parameters";}
	my (	$experiment, $logs,
			$formulasHash, $powerHash, $blocks_defined, $outputDir, $leakageDataFilePath, $GRPs, $traces_not_to_include,
			$fullformulasHash, $cycles_counter_hash, $ecStats, $aliasesHash, $num_of_traces_to_output_in_excel_in_fubs_level
		) = @_;

	my @testsListSorted;
	my %ipc_hash;
	my %stats_hash;
	my %stats_validity;
	my %stats_GRP_hash;
	my %GRPs_hash;

	my %empty_hash = ();
	my $histograms_to_exclude = general_config::getKnob("histograms_to_exclude");
	($histograms_to_exclude ne "-1") or $histograms_to_exclude = \%empty_hash;

	print STDOUT "The current time is: " . output_functions::time_stamp() . "\n";

	#********************************
	calc_leakage::createHash(1266,"$leakageDataFilePath/input_1266.txt");
	#********************************

	output_functions::print_to_log("\n*** Calculating results per trace ***\n");
	my $c = 0;
	if (scalar(keys(%$formulasHash)) > 0)   ### There is a formula file. Calculate power according to it.
	{
		foreach my $File (@{$logs})	# Iterate over all stats files
		{
			$c++;
			print STDOUT "t$c ";

			chomp $File;
			$File =~ s/\r$//;
			if ($debug eq 1) {print STDOUT "$File\n";}

			my %huge_histos;
			my %stats;
			my $trace_name = stats_handler::get_trace_name_from_stats_file_name($File);
			stats_handler::read_stats_from_file(\%stats, \%stats_hash, \%stats_validity, $File, $histograms_to_exclude, 0, $trace_name);
			#print Dumper(\%stats);

			if (($c % 50) == 0)
			{
				stats_handler::check_for_huge_histograms_and_remove_them(\%stats_hash, \%huge_histos, $histograms_to_exclude, \%stats_validity);
			}

			stats_handler::calc_IPC(\%ipc_hash, $trace_name, \%stats);

			# If running scenarios where core is off, just simulating uncore activity,
			# or if IPC is nonzero, calc power
			if ( $calc_power_even_if_zero_ipc ||
			     ($ipc_hash{$trace_name}{"IPC"} > 0) )
			{
			    calc_power_in_test_using_formulas($fullformulasHash, $cycles_counter_hash, "", \%stats, $trace_name, $powerHash, "Platform", $ecStats, $aliasesHash);
			
				### Generate power stats in the stats files format and insert it into the stats file
				if ($output_power_into_stats_files)
				{
					my $stats_file = $File;
					my $stats_file_data = "";
					stats_handler::read_stats_file_without_powerstats(\$stats_file_data, $stats_file);
					$stats_file_data .= generate_powerstats_data($trace_name, $powerHash, "p0");
					if (!$overwrite_stats_files)	# output modified stats files into a local output dir
					{
						my $stats_out_dir = $outputDir . "\/stats_files_with_power_stats\/";
						(-d $stats_out_dir) or (system "mkdir -p $stats_out_dir");
						$stats_file =~ s/^.*\///;
						$stats_file = $stats_out_dir . "\/" . $stats_file;
					}
					stats_handler::save_stats_file(\$stats_file_data, $stats_file);
				}
			}

			#print Dumper($powerHash);
		}
		print STDOUT "\n";
	}
	else   ### There is no formula file. Dump the power data that is already in the stats files.
	{
#		foreach my $File (@{$logs})
#		{
#			calc_power_in_test_based_on_power_stats($File, \%stats_hash, \%ipc_hash, $blocks_defined, \%fubsActive, \%fubsStatic, \%unitsActive, \%unitsStatic, \%clustersActive, \%clustersStatic, \%testsbypower);
#		}
	}

	generate_tests_list_sorted_by_power($powerHash, \@testsListSorted);	### sort the tests according to core power
	
	output_functions::print_to_log_the_repeated_messages_summary();

	### Create a file summarizing the histograms' sizes
	if ($output_histograms_sizes_report_file)
	{
		print STDOUT "The current time is: " . output_functions::time_stamp() . "\n";
		print STDOUT "creating a histograms count summary file\n";
		stats_handler::huge_histo_dump($outputDir, $experiment, \%stats_hash);
	}
	###

	### Find which traces to put in each group and calculate the groups' values
	my @GRP_list = ();
	if (($calculate_groups) and ($GRPs ne "-1"))
	{
		print STDOUT "The current time is: " . output_functions::time_stamp() . "\n";
		print STDOUT "calculating groups\n";
		foreach my $grpType ("independent", "dependant")
		{
			if (! defined ($$GRPs{$grpType})) {
				# Not an error for LRB3
				next;
			}
			my $GRPs_pointer = $$GRPs{$grpType};
			foreach my $nameOfGRP (sort keys %$GRPs_pointer)
			{
				push @GRP_list, $nameOfGRP;
				calc_GRP($GRPs_pointer, \@testsListSorted, $traces_not_to_include, $powerHash, $nameOfGRP, \%GRPs_hash);
		#		print Dumper(\%GRPs_hash);
				calc_GRP_for_block($GRPs_hash{$nameOfGRP}, "all_blocks", $powerHash, 0, $nameOfGRP, "power hash root");
				calc_GRP_for_stats($GRPs_hash{$nameOfGRP}, "all_blocks", \%stats_hash, \%stats_GRP_hash, \%ipc_hash, $nameOfGRP);
			}
		}
	}
	###

	if (!$stats_handler::consider_counter_as_exists_even_if_zero_value)
	{
		stats_handler::find_stats_used_in_formulas_and_signify_they_were_found(\%stats_hash);
	}

#print Dumper($powerHash);

	if ($output_power_output_files)
	{
		print STDOUT "The current time is: " . output_functions::time_stamp() . "\n";
		print STDOUT "creating power output\n";
		output_functions::output_power($experiment, \@testsListSorted, \%ipc_hash, $outputDir, $powerHash, \@GRP_list, $fullformulasHash, $num_of_traces_to_output_in_excel_in_fubs_level);
	}
	if ($output_counters_values)
	{
		print STDOUT "The current time is: " . output_functions::time_stamp() . "\n";
		print STDOUT "creating stats output\n";
		output_functions::output_stats($experiment, \@testsListSorted, \%stats_hash, \%stats_GRP_hash, \@GRP_list, \%ipc_hash, $outputDir);
	}

	print STDOUT "The current time is: " . output_functions::time_stamp() . "\n";
	print STDOUT "finished dumping output\n";

	return 1;
}
#################


################# insert the EC values to the power hash
### usage: insertECs(<pointer to the powerHash>, <pointer to the formulas hash>, <pointer to EC stats hash>)
sub insertECs
{
	output_functions::print_to_log("\n*** Inserting (and calculating) ECs into the power hash ***\n");

	if (@_ != 4) {return 0;}
	my ($powerHash, $fullformulasHash, $ecStats, $aliasesHash) = @_;

	foreach my $location (keys %$fullformulasHash)
	{
		foreach my $cluster (keys %{$$fullformulasHash{$location}})
		{
			foreach my $unit (keys %{$$fullformulasHash{$location}{$cluster}})
			{
				foreach my $fub (keys %{$$fullformulasHash{$location}{$cluster}{$unit}})
				{
					# Initialize power_section field, if present in formula files
					if (general_config::getKnob ("powerSection") == 1) {
						$$powerHash{"SubBlocks"}{$location}{"SubBlocks"}{$cluster}{"SubBlocks"}{$unit}{"SubBlocks"}{$fub}{"Power_section"} = $$fullformulasHash{$location}{$cluster}{$unit}{$fub}{"Power_section"};
					}

					foreach my $function (keys %{$$fullformulasHash{$location}{$cluster}{$unit}{$fub}{"Functions"}})   ### find EC for each formula
					{
						# Evaluate EC separately using %ecStats, the designated stats for EC formulas
						my $EC_orig = $$fullformulasHash{$location}{$cluster}{$unit}{$fub}{"Functions"}{$function}{"Power"};
						my $EC = stats_handler::evalulate_stats_in_expression($EC_orig, $ecStats, $aliasesHash);
						$EC = general::evaluate_numerical_expression($EC, "Error calculating EC with expression: \"$EC_orig\" at $location.$cluster.$unit.$fub.$function", $EC_orig);

						$$powerHash{"SubBlocks"}{$location}{"SubBlocks"}{$cluster}{"SubBlocks"}{$unit}{"SubBlocks"}{$fub}{"Functions"}{$function}{"EC"} = $EC;
						$$powerHash{"SubBlocks"}{$location}{"SubBlocks"}{$cluster}{"SubBlocks"}{$unit}{"SubBlocks"}{$fub}{"Functions"}{$function}{"EC_formula"} = $EC_orig;

						if (defined $$fullformulasHash{$location}{$cluster}{$unit}{$fub}{"Functions"}{$function}{"Comment"})
						{
							$$powerHash{"SubBlocks"}{$location}{"SubBlocks"}{$cluster}{"SubBlocks"}{$unit}{"SubBlocks"}{$fub}{"Functions"}{$function}{"Comment"} = $$fullformulasHash{$location}{$cluster}{$unit}{$fub}{"Functions"}{$function}{"Comment"};
						}
					}
				}
			}
		}
	}

	return 1;
}
#################


################# calculate the power in a test using the formula file
### usage: calc_power_in_test_using_formulas($formulasHash, $cycles_counter, \$stats, \$fubsActive, \$fubsStatic, $functionsActivity, \$unitsActive, \$unitsStatic, \$clustersActive, \$clustersStatic, \$total_dynamic, $File, $ecStats, $aliasesHash)
sub calc_power_in_test_using_formulas
{
	if (@_ != 9) {die "Error in function parameters";}
	my ($fullformulasHash, $cycles_counter_hash, $cycles_counter, $stats, $File, $powerHash, $blockName, $ecStats, $aliasesHash) = @_;

	#print "Block name : $blockName . \n";

	my $dynamic = 0;
	my $idle = 0;
	my $idle_formula = "";
	my $idle_comment = "";
	my $leakage = 0;
	my $processScalingFactor = general_config::getKnob("process_scaling_factor");

	if(!defined($processScalingFactor) or ($processScalingFactor eq "-1")) {
	    output_functions::print_to_log("process scaling factor not specified. Assuming to be 1.\n");
	    $processScalingFactor = 1.0;
	}

	my @ddr_block_names = ("ddr", "ddrio", "vccsa", "vccio", "vccio", "vccddq");
	if(grep(($_ eq $blockName), @ddr_block_names)) {
	    $processScalingFactor = 1.0;
	}

	if (defined $$fullformulasHash{"Functions"})	# got to fubs' level
	{
#print Dumper($powerHash);

		my $fub_active = 0;
		$idle = $$fullformulasHash{"Idle"};
		if ((defined $$fullformulasHash{"Idle_comment"}) and ($$fullformulasHash{"Idle_comment"} ne ""))
		{
			$idle_comment = $$fullformulasHash{"Idle_comment"};
		}

		#******************************************
		$leakage = $$fullformulasHash{"Leakage"};
		#$leakage = 0;
		#******************************************

		foreach my $function (keys %{$$fullformulasHash{"Functions"}})	 ### calculate values for each formula
		{
			my $formula = $$fullformulasHash{"Functions"}{$function}{"Formula"};
			my $EC = $$fullformulasHash{"Functions"}{$function}{"Power"};
			my $activityFactor_orig = "( $formula ) / ( $cycles_counter )";
			if ($cycles_counter eq "")
			{
				output_functions::print_to_log_only_once("Error! No total cycles counter available for the formula: \"$formula\" with event cost \"$EC\" at $blockName.$function\nActivity factor is set to 0!\n");
				$activityFactor_orig = 0;
			}

			my $activityFactor = stats_handler::evalulate_stats_in_expression($activityFactor_orig, $stats, $aliasesHash);

			# Evaluate EC separately using %ecStats, the designated stats for EC formulas
			$EC = stats_handler::evalulate_stats_in_expression($EC, $ecStats, $aliasesHash);

			$activityFactor = general::evaluate_numerical_expression($activityFactor, "Error calculating the activity factor for the formula: \"$activityFactor_orig\" at $blockName.$function", $formula);
			my $cdyn = "( $activityFactor ) * ( $EC ) * ($processScalingFactor)";
			$cdyn = general::evaluate_numerical_expression($cdyn, "Error calculating the Cdyn using this formula: \"$formula\" with event cost \"$EC\" at $blockName.$function", $formula);

			if (($power_too_big_threshold > 0) && ($cdyn >= $power_too_big_threshold))
			{
				output_functions::print_to_log_only_once("Error! Cdyn is huge for the formula: \"$formula\" with event cost \"$EC\" at $blockName.$function\nCdyn for this formula is set to 0!\n");
				$cdyn = 0;
			}

			$fub_active += $cdyn;

			$$powerHash{"Functions"}{$function}{"Cdyn"}{$File} = $cdyn;
			if ((!defined($$powerHash{"Functions"}{$function}{"Max Cdyn"})) or ($$powerHash{"Functions"}{$function}{"Max Cdyn"} < $cdyn))
			{$$powerHash{"Functions"}{$function}{"Max Cdyn"} = $cdyn;}
			$$powerHash{"Functions"}{$function}{"AF"}{$File} = $activityFactor;
			if ((!defined($$powerHash{"Functions"}{$function}{"Max AF"})) or ($$powerHash{"Functions"}{$function}{"Max AF"} < $activityFactor))
			{$$powerHash{"Functions"}{$function}{"Max AF"} = $activityFactor;}
		}

		$idle_formula = $idle;
		$idle = stats_handler::evalulate_stats_in_expression($idle, $ecStats, $aliasesHash);
		$idle = general::evaluate_numerical_expression($idle, "Error calculating the idle at $blockName\nThe Idle formula is: $idle_formula", $idle_formula);

		if (($power_too_big_threshold > 0) && ($idle >= $power_too_big_threshold))
		{
			output_functions::print_to_log_only_once("Error! Idle Cdyn is huge at $blockName\nThe Idle formula is: $idle_formula\nIdle for this fub is set to 0!\n");
			$idle = 0;
		}

		$idle *= $processScalingFactor;

		#**********************************************
		calculate_leakage($fullformulasHash, $blockName, \$leakage);
		#**********************************************

		$dynamic = $fub_active + $idle;
	}
	else
	{
		foreach my $block (keys %$fullformulasHash)
		{
			if ($block ne "Functions")
			{
				my $cycles_counter_local = $cycles_counter;
				if (defined $$cycles_counter_hash{$block})
				{
					my @k = keys(%{$$cycles_counter_hash{$block}});
					$cycles_counter_local = $k[0];
					(defined $cycles_counter_local) or output_functions::die_cmd("Error: bad cycles counter for block $block.\n");
				}
				calc_power_in_test_using_formulas(\%{$$fullformulasHash{$block}}, $cycles_counter_hash, $cycles_counter_local, $stats, $File, \%{$$powerHash{"SubBlocks"}{$block}}, $block, $ecStats, $aliasesHash);
				$dynamic += $$powerHash{"SubBlocks"}{$block}{"Cdyn"}{$File};
				$idle += $$powerHash{"SubBlocks"}{$block}{"Idle"};
				$leakage += $$powerHash{"SubBlocks"}{$block}{"Leakage"};
			}
			else
			{
				output_functions::print_to_log("Error in function calc_power_in_test_using_formulas. Unexpected Functions entry in hash.\n");
			}
		}
	}

	$$powerHash{"Cdyn"}{$File} = $dynamic;
	$$powerHash{"Idle"} = $idle;
	$$powerHash{"Idle_formula"} = $idle_formula;
	$$powerHash{"Idle_comment"} = $idle_comment;
	$$powerHash{"Leakage"} = $leakage * $processScalingFactor;
	if ((!defined($$powerHash{"Max Cdyn"})) or ($$powerHash{"Max Cdyn"} < $dynamic))
	{$$powerHash{"Max Cdyn"} = $dynamic;}

	return 1;
}
#################


################# calculate the leakage
### usage: calculate_leakage()
sub calculate_leakage
{
	if (@_ != 3) {return 0;}

	my ($fullformulasHash, $fub, $fub_leakage) = @_;

	my $myCounter = 0;
	foreach my $key (keys %{$$fullformulasHash{"LeakageData"}})
	{
		$myCounter++;
	}

	if( 	($myCounter > 0) and ((!defined $$fub_leakage) or ($$fub_leakage eq 0) or ($$fub_leakage eq "")) and
		defined($$fullformulasHash{'LeakageData'}{'zTotal'}) and
		($$fullformulasHash{'LeakageData'}{'zTotal'} ne "") and
		defined($$fullformulasHash{'LeakageData'}{'llPr'}) and
		($$fullformulasHash{'LeakageData'}{'llPr'} ne "") and
		defined($$fullformulasHash{'LeakageData'}{'uvtPr'}) and
		($$fullformulasHash{'LeakageData'}{'uvtPr'} ne "")	and
		defined($$fullformulasHash{'LeakageData'}{'lluvtPr'}) and
		($$fullformulasHash{'LeakageData'}{'lluvtPr'} ne "") and
		defined($$fullformulasHash{'LeakageData'}{'pnRatio'}) and
		($$fullformulasHash{'LeakageData'}{'pnRatio'} ne "") and
		defined($$fullformulasHash{'LeakageData'}{'subthresholdStackFactor'}) and
		($$fullformulasHash{'LeakageData'}{'subthresholdStackFactor'} ne "") and
		defined($$fullformulasHash{'LeakageData'}{'gateStackFactor'}) and
		($$fullformulasHash{'LeakageData'}{'gateStackFactor'} ne "") and
		defined($$fullformulasHash{'LeakageData'}{'junctionStackFactor'}) and
		($$fullformulasHash{'LeakageData'}{'junctionStackFactor'} ne "") 
		#		and defined($$fullformulasHash{'LeakageData'}{'temp'}) and
		#		($$fullformulasHash{'LeakageData'}{'temp'} ne "") and
		#		defined($$fullformulasHash{'LeakageData'}{'ldrawn'}) and
		#		($$fullformulasHash{'LeakageData'}{'ldrawn'} ne "") and
		#		defined($$fullformulasHash{'LeakageData'}{'vccGate'}) and
		#		($$fullformulasHash{'LeakageData'}{'vccGate'} ne "")
		)
	{
		my $vccGate = 0.9;
		my $ldrawn = 0.04;
		my $temp = 100;

		#		my $vccGate = $$fullformulasHash{"LeakageData"}{"vccGate"};
		#		my $temp = $$fullformulasHash{"LeakageData"}{"temp"};
		#		my $ldrawn = $$fullformulasHash{"LeakageData"}{"ldrawn"};
		my $zTotal = eval($$fullformulasHash{"LeakageData"}{"zTotal"});
		if (not defined($zTotal))
		{
			my $z = $$fullformulasHash{"LeakageData"}{"zTotal"};
			output_functions::print_to_log("Error parsing the zTotal: \"$z\" at $fub\n");
			$zTotal = 0;
		}
		my $llPr = $$fullformulasHash{"LeakageData"}{"llPr"};
		my $lluvtPr = $$fullformulasHash{"LeakageData"}{"lluvtPr"};
		my $uvtPr = $$fullformulasHash{"LeakageData"}{"uvtPr"};
		my $subthresholdStackFactor = $$fullformulasHash{"LeakageData"}{"subthresholdStackFactor"};
		my $gateStackFactor = $$fullformulasHash{"LeakageData"}{"gateStackFactor"};
		my $junctionStackFactor = $$fullformulasHash{"LeakageData"}{"junctionStackFactor"};
		my $pnRatio = $$fullformulasHash{"LeakageData"}{"pnRatio"};

		$$fub_leakage =
			calc_leakage::calcLeakage(1266,
				$vccGate,$temp,$zTotal,$llPr,$uvtPr,
				$lluvtPr,$subthresholdStackFactor,$gateStackFactor,
				$junctionStackFactor,$ldrawn,$pnRatio,1.7);

		### For debugging...
		#print STDERR "$fub -> Leakage: $fub_leakage\n";
		#print STDERR "V = $vccGate, Ld = $ldrawn, T = $temp, %LL = $llPr	%LLUVT = $lluvtPr, %UVT = $uvtPr\n";
		#print STDERR "Ztotal = $zTotal,SubSF = $subthresholdStackFactor, GateSF = $gateStackFactor, JunctSF = $junctionStackFactor, PN = $pnRatio\n";
		#print STDERR "..............................................................................................\n";
	}

	return 1;
}
#################


################# calculate the power in a test base on the power stats
### usage: calc_power_in_test_based_on_power_stats($File, \%stats_hash, \%ipc_hash, $blocks_defined, \%fubsActive, \%fubsStatic, \%unitsActive, \%unitsStatic, \%clustersActive, \%clustersStatic, \%testsbypower)
sub calc_power_in_test_based_on_power_stats
{
	if (@_ != 10) {return 0;}
	my ($File, $stats_hash, $ipc_hash, $blocks_defined, $fubsActive, $fubsStatic, $unitsActive, $unitsStatic, $clustersActive, $clustersStatic, $testsbypower) = @_;

	my %fubsHash;
	my %unitsHash;
	my %clustersHash;
	my %stats;

	##### for IPC
	my $File_tmp = $File;
	stats_handler::read_stats_from_file(\%stats, $stats_hash, \$File_tmp, 0);
	#####

	chomp $File;

	open(INFILE, "zgrep -v ^# $File | grep power | grep -v nan\$ |") or output_functions::die_cmd("Can't open $File.\n");	### get only uncommented lines
	my @lines = <INFILE>;
	close(INFILE);

	$File =~ s/\.gz$//;
	$File =~ s/.*\///g;

	foreach my $line (@lines)
	{
		my %blockHash;
		chomp $line;
		$line =~ s/\r$//;

		if (db_hash::parse_block_name($line, $blocks_defined, \%blockHash, "stats_file"))	# managed to parse the line
		{
			my $type = $blockHash{"Type"};
			my $value = $blockHash{"Value"};
			my $parameter = $blockHash{"Parameter"};
			my $location = $blockHash{"Location"};
			my $cluster = $blockHash{"Cluster"};
			my $unit = $blockHash{"Unit"};
			my $fub = $blockHash{"Fub"};
			my $formula_name = $blockHash{"Formula_name"};

			if	($type eq "core/uncore")	# This is a core/uncore type
			{
				$cluster = $location;
			}

			if (($type eq "core/uncore") or ($type eq "Cluster"))	# This is a Cluster type or core/uncore type
			{
				$clustersHash{$cluster}{$parameter} = $value;
				$clustersHash{$cluster}{"Location"} = $location;

				if ((defined $clustersHash{$cluster}{"Idle"}) and (defined $clustersHash{$cluster}{"Active"}))
				{
					$clustersHash{$cluster}{"Dynamic"} = $clustersHash{$cluster}{"Idle"} + $clustersHash{$cluster}{"Active"};

					$$clustersActive{$cluster}{"Location"} = $clustersHash{$cluster}{"Location"};
					$$clustersActive{$cluster}{$File} = $clustersHash{$cluster}{"Dynamic"};
					if ((!defined($$clustersActive{$cluster}{"Max power"})) or ($$clustersActive{$cluster}{"Max power"} < $clustersHash{$cluster}{"Dynamic"}))
					{$$clustersActive{$cluster}{"Max power"} = $clustersHash{$cluster}{"Dynamic"};}
					if ((!defined $$clustersActive{$cluster}{"Idle power"}) or
					($$clustersActive{$cluster}{"Idle power"} > $clustersHash{$cluster}{"Idle"}))
					{$$clustersActive{$cluster}{"Idle power"} = $clustersHash{$cluster}{"Idle"};}
				}
				if ((defined $clustersHash{$cluster}{"Leakage"}) and (!defined $$clustersActive{$cluster}{"Leakage power"}))
				{
					$$clustersActive{$cluster}{"Leakage power"} = $clustersHash{$cluster}{"Leakage"};
				}
				if ((defined $clustersHash{$cluster}{"Idle"}) and (defined $clustersHash{$cluster}{"Leakage"}))
				{
					$$clustersStatic{$cluster}{"Idle"}{$File} = $clustersHash{$cluster}{"Idle"};
					$$clustersStatic{$cluster}{"Leakage"}{$File} = $clustersHash{$cluster}{"Leakage"};
				}
			}
			elsif ($type eq "Unit") # This is a Unit type
			{
				$unitsHash{$unit}{$parameter} = $value;
				$unitsHash{$unit}{"Location"} = $location;

				if ((defined $unitsHash{$unit}{"Idle"}) and (defined $unitsHash{$unit}{"Active"}))
				{
					$unitsHash{$unit}{"Dynamic"} = $unitsHash{$unit}{"Idle"} + $unitsHash{$unit}{"Active"};

					$$unitsActive{$unit}{"Location"} = $unitsHash{$unit}{"Location"};
					$$unitsActive{$unit}{$File} = $unitsHash{$unit}{"Dynamic"};
					if ((!defined($$unitsActive{$unit}{"Max power"})) or ($$unitsActive{$unit}{"Max power"} < $unitsHash{$unit}{"Dynamic"}))
					{$$unitsActive{$unit}{"Max power"} = $unitsHash{$unit}{"Dynamic"};}
					if ((!defined $$unitsActive{$unit}{"Idle power"}) or
					($$unitsActive{$unit}{"Idle power"} > $unitsHash{$unit}{"Idle"}))
					{$$unitsActive{$unit}{"Idle power"} = $unitsHash{$unit}{"Idle"};}
				}
				if ((defined $unitsHash{$unit}{"Leakage"}) and (!defined $$unitsActive{$unit}{"Leakage power"}))
				{
					$$unitsActive{$unit}{"Leakage power"} = $unitsHash{$unit}{"Leakage"};
				}
				if ((defined $unitsHash{$unit}{"Idle"}) and (defined $unitsHash{$unit}{"Leakage"}))
				{
					$$unitsStatic{$unit}{"Idle"}{$File} = $unitsHash{$unit}{"Idle"};
					$$unitsStatic{$unit}{"Leakage"}{$File} = $unitsHash{$unit}{"Leakage"};
				}
			}
			elsif ($type eq "Fub")	# This is a Fub type
			{
				if ($parameter eq "Formula")
				{
					$fubsHash{$fub}{"Functions"}{$formula_name} = $value;
					$$fubsActive{$fub}{"Functions"}{$formula_name}{$File} = $value;
					if ((!defined($$fubsActive{$fub}{"Functions"}{$formula_name}{"Max power"})) or ($$fubsActive{$fub}{"Functions"}{$formula_name}{"Max power"} < $value))
					{$$fubsActive{$fub}{"Functions"}{$formula_name}{"Max power"} = $value;}
				}
				else
				{
					$fubsHash{$fub}{$parameter} = $value;
					$fubsHash{$fub}{"Location"} = $location;
					$fubsHash{$fub}{"Unit"} = $unit;

					if ((defined $fubsHash{$fub}{"Idle"}) and (defined $fubsHash{$fub}{"Active"}))
					{
						$fubsHash{$fub}{"Dynamic"} = $fubsHash{$fub}{"Idle"} + $fubsHash{$fub}{"Active"};

						$$fubsActive{$fub}{"Location"} = $fubsHash{$fub}{"Location"};
						$$fubsActive{$fub}{"Unit"} = $fubsHash{$fub}{"Unit"};
						$$fubsActive{$fub}{$File} = $fubsHash{$fub}{"Dynamic"};
						if ((!defined($$fubsActive{$fub}{"Max power"})) or ($$fubsActive{$fub}{"Max power"} < $fubsHash{$fub}{"Dynamic"}))
						{$$fubsActive{$fub}{"Max power"} = $fubsHash{$fub}{"Dynamic"};}
						if ((!defined $$fubsActive{$fub}{"Idle power"}) or
						($$fubsActive{$fub}{"Idle power"} > $fubsHash{$fub}{"Idle"}))
						{$$fubsActive{$fub}{"Idle power"} = $fubsHash{$fub}{"Idle"};}
					}
					if ((defined $fubsHash{$fub}{"Leakage"}) and (!defined $$fubsActive{$fub}{"Leakage power"}))
					{
						$$fubsActive{$fub}{"Leakage power"} = $fubsHash{$fub}{"Leakage"};
					}
					if ((defined $fubsHash{$fub}{"Idle"}) and (defined $fubsHash{$fub}{"Leakage"}))
					{
						$$fubsStatic{$fub}{"Idle"}{$File} = $fubsHash{$fub}{"Idle"};
						$$fubsStatic{$fub}{"Leakage"}{$File} = $fubsHash{$fub}{"Leakage"};
					}
				}
			}
			else
			{
				output_functions::print_to_log("Unknown block type at $line\n");
			}
		}
		else	# didn't manage to parse the line
		{
			output_functions::print_to_log("Error parsing this line: $line\n");
		}
	}

	my $totalpower;
	if (defined($clustersHash{"core"}{"Dynamic"}) and defined($clustersHash{"core"}{"Leakage"}))
	{
		$totalpower = $clustersHash{"core"}{"Dynamic"} + $clustersHash{"core"}{"Leakage"}; # + $clustersHash{"uncore"}{"Dynamic"};
	}
	if (!defined $totalpower)
	{
		output_functions::print_to_log("Error finding total power for $File. Using 0.\n");
		$totalpower = 0;
	}
	push @{$$testsbypower{$totalpower}}, $File;

	stats_handler::calc_IPC($ipc_hash, $File, \%stats);


	return 1;
}
#################


################# generate the power stats data for dumping into a stats file
### usage: generate_powerstats_data()
sub generate_powerstats_data
{
	if (@_ != 3) {die "Error in function parameters";}
	my ($trace_name, $powerHash, $blockName) = @_;

	my $stats_file_data = "";

	if (defined $$powerHash{"Functions"})	# got to fubs' level
	{
		foreach my $function (sort keys %{$$powerHash{"Functions"}})	 ### calculate values for each formula
		{
			my $cdyn = $$powerHash{"Functions"}{$function}{"Cdyn"}{$trace_name};
			defined($cdyn) or ($cdyn = 0);
			#my $activityFactor = $$powerHash{"Functions"}{$function}{"AF"}{$trace_name};
			
			$stats_file_data .= $blockName . "." . $function . ".power " . $cdyn . "\n";
		}
	}
	else
	{
		foreach my $block (sort keys %{$$powerHash{"SubBlocks"}})
		{
			if ($block ne "Functions")
			{
				my $next_block_name = $block;
				if ($next_block_name =~ /^core(\d*)$/)	# traslate ALPS core name syntax to Keiko's syntax (core0, core1 => c0, c1, etc.)
				{
					my $core_num = $1;
					defined($core_num) or ($core_num = 0);
					$next_block_name = "c" . $core_num;
				}
				
				$stats_file_data .= generate_powerstats_data($trace_name, \%{$$powerHash{"SubBlocks"}{$block}}, $blockName . "." . $next_block_name);
			}
			else
			{
				output_functions::die_cmd("Error in function generate_powerstats_data. Unexpected Functions entry in hash.\n");
			}
		}
	}

	my $cdyn = $$powerHash{"Cdyn"}{$trace_name};
	defined($cdyn) or ($cdyn = 0);
	my $idle = $$powerHash{"Idle"};
	defined($idle) or ($idle = 0);

	$stats_file_data .= $blockName . ".Active.power " . ($cdyn - $idle) . "\n";
	$stats_file_data .= $blockName . ".Idle.power " . $idle . "\n";
	$stats_file_data .= $blockName . ".Total.power " . $cdyn . "\n";

	return $stats_file_data;
}
#################


################# generate a list of the tests sorted by power
### usage: generate_tests_list_sorted_by_power()
sub generate_tests_list_sorted_by_power
{
	output_functions::print_to_log("\n*** Generating sorted tests list ***\n");

	if (@_ != 2) {die("Error in parameters to function");}
	my ($powerHash, $testsListSorted) = @_;

	my %testsbypower;

	foreach my $location (keys %{$$powerHash{"SubBlocks"}})
	{
		if ($location =~ /^core0?$/)
		{
			foreach my $trace_name (keys %{$$powerHash{"SubBlocks"}{$location}{"Cdyn"}})
			{
				my $totalpower = 0;
				if (defined($$powerHash{"SubBlocks"}{$location}{"Cdyn"}{$trace_name}) and defined($$powerHash{"SubBlocks"}{$location}{"Idle"}) and defined($$powerHash{"SubBlocks"}{$location}{"Leakage"}))
				{
					$totalpower = $$powerHash{"SubBlocks"}{$location}{"Cdyn"}{$trace_name} + $$powerHash{"SubBlocks"}{$location}{"Idle"}; # + $$powerHash{"SubBlocks"}{$location}{"Leakage"};
				}

				if (!defined $totalpower)
				{
					output_functions::print_to_log("Error finding total power for $trace_name. Using 0.\n");
					$totalpower = 0;
				}
				push @{$testsbypower{$totalpower}}, $trace_name;
			}
		}
	}


	foreach my $totalpower (sort { $a <=> $b } keys(%testsbypower)) ### sort the tests according to core power
	{
		foreach my $trace_name (@{$testsbypower{$totalpower}})
		{
			unshift @$testsListSorted, $trace_name;
		}
	}

	return 1;
}
#################


################# calculate a group power
### usage: calc_GRP()
sub calc_GRP
{
	if (@_ != 6) {return 0;}
	my ($GRPs, $testsListSorted, $traces_not_to_include, $powerHash, $nameOfGRP, $GRPs_hash) = @_;

	my %traces_not_to_include;
	my $traces_skipped = "";
	my $block = defined($$powerHash{"SubBlocks"}{"core0"}) ? "core0" : "core";

	my $GRP_type;
	my $value;
	my $regular_expression = ".*";

	if (!defined($$GRPs{"$nameOfGRP"}{"GRP_type"}))
	{
		output_functions::die_cmd("Error: Can't find GRP_type for the group $nameOfGRP in the config files.\n");
	}
	elsif (!defined($$GRPs{"$nameOfGRP"}{"value"}))
	{
		output_functions::die_cmd("Error: Can't find value for the group $nameOfGRP in the config files.\n");
	}
	else
	{
		my @k = keys(%{$$GRPs{"$nameOfGRP"}{"GRP_type"}});
		$GRP_type = $k[0];
		$value = $$GRPs{"$nameOfGRP"}{"value"};
		if (defined($$GRPs{"$nameOfGRP"}{"regular_expression"}))
		{
			my @k = keys(%{$$GRPs{"$nameOfGRP"}{"regular_expression"}});
			$regular_expression = $k[0];
		}
	}

	if (($GRP_type eq "percent_from_top_trace") or ($GRP_type eq "top_number_of_traces"))
	{
		my @k = keys(%$value);
		my $value_local = $k[0];
		my $blockMax = 0;
		my $numOfGRPtestsOK = 0;
		my $traces = "";
		my $prcnt = 0;
		my $numOfGRPlocal = $value_local;

		if ($value_local =~ /^(\d+)%$/) # calculate GRP as percentage of top traces
		{
			$prcnt = 1 - (${1} / 100);
			$numOfGRPlocal = scalar(@$testsListSorted);
		}

		my $i = 0;
		while ( (defined($$testsListSorted[$i]))
					and (defined($$powerHash{"SubBlocks"}{$block}{"Cdyn"}{$$testsListSorted[$i]}))
					and ($$powerHash{"SubBlocks"}{$block}{"Cdyn"}{$$testsListSorted[$i]} >= ($blockMax * $prcnt))
					and ($$powerHash{"SubBlocks"}{$block}{"Cdyn"}{$$testsListSorted[$i]} > 0)
					and ($numOfGRPtestsOK < $numOfGRPlocal) )
		{
			if (
					(!defined $$traces_not_to_include{$$testsListSorted[$i]})
					and
					($$testsListSorted[$i] =~ /$regular_expression/)
				)
			{
				if ($blockMax eq 0) {$blockMax = $$powerHash{"SubBlocks"}{$block}{"Cdyn"}{$$testsListSorted[$i]};}
				$numOfGRPtestsOK++;
				$traces .= $$testsListSorted[$i] . "\n";
				$$GRPs_hash{$nameOfGRP}{"all_blocks"}{$$testsListSorted[$i]} = 1;
			}
			else
			{
				$traces_skipped .= $$testsListSorted[$i] . "\n";
			}
			$i++;
		}

		if ($value_local =~ /^(\d+)%$/) # calculate GRP as percentage of top traces
		{
			output_functions::print_to_log("Setting number of \"$nameOfGRP\" traces to $numOfGRPtestsOK. These are the traces that fall in the top $value_local of the power.\n");
		}
		else
		{
			if ($value_local ne $numOfGRPtestsOK)
			{
				if ($numOfGRPtestsOK == 0)
				{
					# No traces in this group
					output_functions::print_to_log("There are no traces that fall in \"$nameOfGRP\". Reporting Idle for this group.\n");
					$traces = "";
					%{$$GRPs_hash{$nameOfGRP}{"all_blocks"}} = ();
				}
				else
				{
					# Number of traces < number needed for this group; adjust expectations
					output_functions::print_to_log("There are only $numOfGRPtestsOK traces that fall in \"$nameOfGRP\" (expected $value_local). Reporting power based on $numOfGRPtestsOK traces.\n");
				}
			}
		}
		output_functions::print_to_log("The number of \"$nameOfGRP\" traces is $numOfGRPtestsOK.\n");
		output_functions::print_to_log("The traces are:\n$traces");
		output_functions::print_to_log("End of traces list.\n");
	}
	elsif ($GRP_type eq "list_of_traces")
	{
		foreach my $traces_block (keys %$value)
		{
			my $numOfGRPtestsOK = 0;
			my $traces = "";

			my $i = 0;
			if (ref($$value{$traces_block}) eq "HASH")
			{
				while ( (defined($$testsListSorted[$i]))
							and (defined($$powerHash{"SubBlocks"}{$block}{"Cdyn"}{$$testsListSorted[$i]}))
							and ($$powerHash{"SubBlocks"}{$block}{"Cdyn"}{$$testsListSorted[$i]} > 0) )
				{
					if ((!defined $$traces_not_to_include{$$testsListSorted[$i]}) and (defined($$value{$traces_block}{$$testsListSorted[$i]})))
					{
						$numOfGRPtestsOK++;
						$traces .= $$testsListSorted[$i] . "\n";
						$$GRPs_hash{$nameOfGRP}{$traces_block}{$$testsListSorted[$i]} = 1;
					}
					elsif (defined $$traces_not_to_include{$$testsListSorted[$i]})
					{
						$traces_skipped .= $$testsListSorted[$i] . "\n";
					}
					$i++;
				}

				if (scalar(keys(%{$$value{$traces_block}})) ne $numOfGRPtestsOK)
				{
					output_functions::print_to_log("Error: There is no complete overlap between the traces in \"$nameOfGRP\" at block $traces_block and the full logs list. Using only the overlaping traces\n");
				}
			}

			output_functions::print_to_log("The number of \"$nameOfGRP\" traces for block $traces_block is $numOfGRPtestsOK.\n");
			output_functions::print_to_log("The traces are:\n$traces");
			output_functions::print_to_log("End of traces list.\n");
		}
	}
	elsif ($GRP_type eq "pointer_to_other_groups")
	{
		foreach my $traces_block (keys %$value)
		{
			my $numOfGRPtestsOK = 0;
			my $traces = "";

			if (ref($$value{$traces_block}) eq "HASH")
			{
				my @k = keys(%{$$value{$traces_block}});
				my $value_local = $k[0];

				foreach my $trace_name (keys(%{$$GRPs_hash{$value_local}{"all_blocks"}}))
				{
					$numOfGRPtestsOK++;
					$traces .= $trace_name . "\n";
					$$GRPs_hash{$nameOfGRP}{$traces_block}{$trace_name} = 1;
				}
			}

			output_functions::print_to_log("The number of \"$nameOfGRP\" traces for block $traces_block is $numOfGRPtestsOK.\n");
			output_functions::print_to_log("The traces are:\n$traces");
			output_functions::print_to_log("End of traces list.\n");
		}
	}
	if ($traces_skipped ne "")
	{
		output_functions::print_to_log("The traces that were not included are:\n$traces_skipped");
		output_functions::print_to_log("End of skipped traces list.\n");
	}

	return 1;
}
#################


################# calc GRP of block
### usage: calc_GRP_for_block()
sub calc_GRP_for_block
{
	if (@_ != 6) {return 0;}

	my ($GRP_traces, $default_traces, $powerHash, $isFunction, $nameOfGRP, $block_name) = @_;


	if ($isFunction)	# This is a function
	{
		my $AFblockSum = 0;
		my $AFnumOfGRPtestsOK = 0;

		foreach my $trace (keys %{$$GRP_traces{$default_traces}})
		{
			if (defined $$powerHash{"AF"}{$trace})
			{
				$AFblockSum += $$powerHash{"AF"}{$trace};
				$AFnumOfGRPtestsOK++;
			}
		}
		$$powerHash{"AF $nameOfGRP"} = ($AFnumOfGRPtestsOK>0) ? ($AFblockSum / $AFnumOfGRPtestsOK) : 0;

		my $CblockSum = 0;
		my $CnumOfGRPtestsOK = 0;

		foreach my $trace (keys %{$$GRP_traces{$default_traces}})
		{
			if (defined $$powerHash{"Cdyn"}{$trace})
			{
				$CblockSum += $$powerHash{"Cdyn"}{$trace};
				$CnumOfGRPtestsOK++;
			}
		}
		$$powerHash{"Cdyn $nameOfGRP"} = ($CnumOfGRPtestsOK>0) ? ($CblockSum / $CnumOfGRPtestsOK) : 0;
	}
	else
	{
		my $blockSum = 0;

		if ((defined $$powerHash{"Functions"})	or (!defined($$powerHash{"SubBlocks"}))) # This is a fub
		{
			foreach my $function (keys %{$$powerHash{"Functions"}})
			{
				calc_GRP_for_block($GRP_traces, $default_traces, \%{$$powerHash{"Functions"}{$function}}, 1, $nameOfGRP, "$block_name" . "__" . "$function");
				$blockSum += $$powerHash{"Functions"}{$function}{"Cdyn $nameOfGRP"};
			}

			if (not defined($$powerHash{"Idle"}))
			{
				die "Error: no idle value found for block \"$block_name\" in Groups calculation.\n";
			}
			else
			{
				$blockSum += $$powerHash{"Idle"};
			}
		}
		else	# This is a higher heirarchy block
		{
			foreach my $block (keys %{$$powerHash{"SubBlocks"}})
			{
				my $default_traces_local = $default_traces;
				if (defined($$GRP_traces{$block})) # this sub block has specific traces to be used under this group
				{
					$default_traces_local = $block;
				}
				calc_GRP_for_block($GRP_traces, $default_traces_local, \%{$$powerHash{"SubBlocks"}{$block}}, 0, $nameOfGRP, $block);
				$blockSum += $$powerHash{"SubBlocks"}{$block}{"Cdyn $nameOfGRP"};
			}
		}

		$$powerHash{"Cdyn $nameOfGRP"} = $blockSum;
	}

	return 1;
}
#################


################# calc GRP of stats
### usage: calc_GRP_for_stats()
sub calc_GRP_for_stats
{
	if (@_ != 6) {return 0;}

	my ($GRP_traces, $default_traces, $stats_hash, $stats_GRP_hash, $ipc_hash, $nameOfGRP) = @_;

	foreach my $counter (sort keys(%$stats_hash))
	{
		my $AFsum = 0;
		my $numOfTraces = 0;

		foreach my $trace (keys %{$$GRP_traces{$default_traces}})
		{
			if ((defined($$ipc_hash{$trace}{"Cycles"})) and
				($$ipc_hash{$trace}{"Cycles"} > 0))
			{
				my $counter_val = (defined($$stats_hash{$counter}{$trace})) ? $$stats_hash{$counter}{$trace} : 0;
				my $cycles_val = $$ipc_hash{$trace}{"Cycles"};
				if ($counter =~ /\_([A-Z]+)$/)
				{
					my $ext = $1;
					if (($ext eq "BUCKETS") or ($ext eq "MIN") or ($ext eq "MAX") or ($ext eq "MEAN") or ($ext eq "MEDIAN"))
					{
						$cycles_val = 1;	# Don't normalize counters of histograms like MIN, MAX, MEAN, etc.
					}
				}
				my $af = $counter_val/$cycles_val;
#				$af = sprintf("%.5f",$af);
#				$af =~ s/\.?0+$//;
				$AFsum += $af;
				$numOfTraces++;
			}
		}

		$$stats_GRP_hash{$counter}{$nameOfGRP} = ($numOfTraces > 0) ? ($AFsum / $numOfTraces) : 0;
	}

	return 1;
}
#################




1;
