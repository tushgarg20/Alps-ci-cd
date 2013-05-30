package output_functions;

use diagnostics;
use strict;
use warnings;
use Data::Dumper;
use Excel::Writer::XLSX;

use general;
use hierarchy;
use general_config;

my $logFileHandler;
my %printed_to_log;
our $outputDir;
our $experiment;


################# output the ALPS-format formulas file
### usage: output_formulas_in_ALPS_xls_style(<pointer to the formulasHash>)
sub output_formulas_in_ALPS_xls_style
{
	if (@_ != 3) {return 0;}
	my ($formulasHash_base, $fullformulasHash, $powerHash) = @_;

	my %formulas;
	$formulas{"base"}{"hash"} = $formulasHash_base;
	$formulas{"full"}{"hash"} = $fullformulasHash;
	$formulas{"base"}{"outfile"} = "${outputDir}power_formulas_base.${experiment}.xls";
	$formulas{"full"}{"outfile"} = "${outputDir}power_formulas_multi_instance.${experiment}.xls";
	$formulas{"base"}{"outevents"} = "${outputDir}power_formulas_base_EC_per_counter.${experiment}.xls";
	$formulas{"full"}{"outevents"} = "${outputDir}power_formulas_multi_instance_EC_per_counter.${experiment}.xls";

	foreach my $form (keys %formulas)
	{
		my $formulasHash = $formulas{$form}{"hash"};
		my $outputFile = $formulas{$form}{"outfile"};
		my $outputFileEvents = $formulas{$form}{"outevents"};

		my $data = "";
		my $numoffunctions = 0;

		my %eventsWeights;
		my %eventsHierarchy;
		my $eventsData = "";
		my @eventsColumns;

		foreach my $location (sort keys %$formulasHash)
		{
			$eventsHierarchy{"Locations"}{$location} = 1;
			foreach my $cluster (sort keys %{$$formulasHash{$location}})
			{
				$eventsHierarchy{"Clusters"}{$cluster} = 1;
				foreach my $unit (sort keys %{$$formulasHash{$location}{$cluster}})
				{
					$eventsHierarchy{"Units"}{$unit} = 1;
					foreach my $fub (sort keys %{$$formulasHash{$location}{$cluster}{$unit}})
					{
						my $nof = 0;
						my $idle = $$formulasHash{$location}{$cluster}{$unit}{$fub}{"Idle"};

						if ((!defined($idle)) or ($idle eq ""))
						{
							output_functions::print_to_log("Error reading the event cost of $location.$cluster.$unit.$fub.idle from the formula file. Using 0!\n");
							$idle = 0;
							$$formulasHash{$location}{$cluster}{$unit}{$fub}{"Idle"} = 0;
						}
						$data .= "$fub\t$unit\t$cluster\t$location\t$idle"; #\t$leakage"; #\t$maxpower";
						foreach my $function (sort keys %{$$formulasHash{$location}{$cluster}{$unit}{$fub}{"Functions"}})
						{
#							my $functionAlias = $$formulasHash{$location}{$cluster}{$unit}{$fub}{"Functions"}{$function}{"Alias"};
							my $functionForm = $$formulasHash{$location}{$cluster}{$unit}{$fub}{"Functions"}{$function}{"Formula"};
							my $EC = $$formulasHash{$location}{$cluster}{$unit}{$fub}{"Functions"}{$function}{"Power"};
							$data .= "\t$function\t$functionForm\t$EC";
							$nof++;

							$functionForm =~ s/\s*\^\s*/ ** /g;
							$functionForm =~ s/\s*=\s*/ == /g;

							my $EC_val = $EC;
							my $ph_loc = $location;
							$ph_loc =~ s/^(core|llcbo)$/${1}0/;
							$ph_loc =~ s/^uncore$/llcbo0/;
							$EC_val =~ s/\s*\^\s*/ ** /g;
							$EC_val =~ s/\s*=\s*/ == /g;
							if ($EC_val eq $$powerHash{'SubBlocks'}{$ph_loc}{'SubBlocks'}{$cluster}{'SubBlocks'}{$unit}{'SubBlocks'}{$fub}{'Functions'}{$function}{'EC_formula'}) {
								$EC_val = $$powerHash{'SubBlocks'}{$ph_loc}{'SubBlocks'}{$cluster}{'SubBlocks'}{$unit}{'SubBlocks'}{$fub}{'Functions'}{$function}{'EC'};
							} else {
								$EC_val = general::evaluate_numerical_expression($EC, "Error reading and calculating EC with expression: \"$EC\" at $location.$cluster.$unit.$fub.$function", $EC);
								if ($EC_val == 0)
								{
									$$formulasHash{$location}{$cluster}{$unit}{$fub}{"Functions"}{$function}{"Power"} = 0;
								}
							}

							if ($EC_val == 0)
							{
								output_functions::print_to_log("Error in the event cost of $location.$cluster.$unit.$fub.$function. Its value is 0!\n");
							}
							if ($functionForm =~ /^\s*$/)
							{
								output_functions::print_to_log("Error in the formula of $location.$cluster.$unit.$fub.$function. It is missing. Using 0 instead!\n");
								$$formulasHash{$location}{$cluster}{$unit}{$fub}{"Functions"}{$function}{"Formula"} = 0;
							}
							my %counters;
							my $tt = $functionForm;
							$functionForm =~ s/([\w\.\[\d\]:]+)/{add_counter_to_hash($1, \%counters);}/eg;
							if ($functionForm ne $tt) {print "Error: A program error in output_functions.pm: $functionForm ne to $tt\n";}
							my $zero_in_isolating = 0;
							foreach my $counter (keys %counters)
							{
								if (($location =~ /^core/) and ($counter !~ /^p\d\.c\d\./) and ($counter !~ /^knob\..+/))
								{
									output_functions::print_to_log("Error: in the formula of $location.$cluster.$unit.$fub.$function. The core counter $counter has no \"p0.c0.\" or \"knob.\" prefix! The formula is \"$functionForm\"\n");
								}

								defined($eventsWeights{$counter}{$unit}) or $eventsWeights{$counter}{$unit}=0;
								defined($eventsWeights{$counter}{$cluster}) or $eventsWeights{$counter}{$cluster}=0;
								defined($eventsWeights{$counter}{$location}) or $eventsWeights{$counter}{$location}=0;

								my $counter_coefficient = $functionForm;
                                #HACK due to bad GT stats having a " " in the
                                # middle of the stat
                                if(!($counter_coefficient =~ / / && $counter_coefficient =~ /PS/) )
                                { 

								$counter_coefficient =~ s/([\w\.\[\d\]:]+)/{replace_counter_with_value($1, $counter);}/eg; # replace our counter with 1 and the other counters with 0
								$counter_coefficient = general::evaluate_numerical_expression($counter_coefficient, "Warning: in the formula of $location.$cluster.$unit.$fub.$function. Can't isolate the counter $counter out of the formula! The formula is \"$functionForm\"", $functionForm);

								if ($counter_coefficient == 0)
								{
									$zero_in_isolating = 1;
#									output_functions::print_to_log("Error in the formula of $location.$cluster.$unit.$fub.$function. Can't isolate the counter $counter out of the formula! (Is it multiplied by 0? Is it multiplied by another counter? Or is this a real error?). The formula is \"$functionForm\"\n");
								}

								$counter_coefficient *= $EC_val;
								$eventsWeights{$counter}{$unit} += $counter_coefficient;
								if ($unit ne $cluster) {$eventsWeights{$counter}{$cluster} += $counter_coefficient;} # if it equals then we add twice to the same instance
								$eventsWeights{$counter}{$location} += $counter_coefficient;
                                }
							}
							if ($zero_in_isolating == 1)
							{
								output_functions::print_to_log("Warning: in the formula of $location.$cluster.$unit.$fub.$function. Can't isolate a counter or more out of the formula! (Is it multiplied by 0? Is it multiplied by another counter?). The formula is \"$functionForm\"\n");
							}
						}
						$data .= "\n";
						$numoffunctions = ($numoffunctions > $nof) ? $numoffunctions : $nof;
					}
				}
			}
		}

		open (OUTFILE, "| gzip >$outputFile.gz") or die_cmd("Can't open output file: \"$outputFile\".\n");
		print OUTFILE "Fub\tUnit\tCluster\tLocation\tIdle [pF]"; #\tLeakage_Override [mW]"; #\tMaxPower";
		for (my $i = 1; $i <= $numoffunctions; $i++)
		{
#			print OUTFILE "\tFunction$i\tFormula Alias$i\tFormula$i\tCapacitance$i [pF]";
			print OUTFILE "\tFunction$i\tFormula$i\tCapacitance$i [pF]";
		}
		print OUTFILE "\n$data";
		close(OUTFILE);


		$eventsData = "Event";
		foreach my $loc (sort keys(%{$eventsHierarchy{"Locations"}})) {push @eventsColumns, $loc;}
		foreach my $cluster (sort keys(%{$eventsHierarchy{"Clusters"}})) {push @eventsColumns, $cluster;}
		foreach my $unit (sort keys(%{$eventsHierarchy{"Units"}})) {push @eventsColumns, $unit;}
		for (my $col = 0; $col < scalar(@eventsColumns); $col++) {$eventsData .= "\t$eventsColumns[$col]";}
		foreach my $counter (sort keys(%eventsWeights))
		{
			$eventsData .= "\n$counter";
			for (my $col = 0; $col < scalar(@eventsColumns); $col++)
			{
				if (defined($eventsWeights{$counter}{$eventsColumns[$col]}))
				{ 
					$eventsData .= "\t$eventsWeights{$counter}{$eventsColumns[$col]}";
				}
				else
				{
					$eventsData .= "\t0";
				}
			}
		}

		open (EVENTSOUTFILE, "| gzip >$outputFileEvents.gz") or die_cmd("Can't open events output file: \"$outputFileEvents\".\n");
		print EVENTSOUTFILE "$eventsData";
		close(EVENTSOUTFILE);
	}

	return 1;
}
#################


################# add counter to hash
### usage: add_counter_to_hash(<counter>, <counters hash>)
sub add_counter_to_hash
{
	if (@_ != 2) {return 0;}
	my ($counter, $counters) = @_;

	if ($counter =~ /[a-zA-Z_]/)   ### is not a number
	{
		$$counters{$counter} = 1;
	}

	return $counter;
}
#################


################# 
### usage: replace_counter_with_value(<general counter>, <the counter we're after>)
sub replace_counter_with_value
{
	if (@_ != 2) {return 0;}
	my ($gen_counter, $counter) = @_;

	if (not ($gen_counter =~ /[a-zA-Z_]/))   ### is a number, so don't change it
	{
		return $gen_counter;
	}
	if ($gen_counter eq $counter)
	{
		return 1;
	}

	return 0;
}
#################


################# output the Coho-format formulas file
sub output_formulas_files_in_coho_syntax
{
	if (@_ != 3) {return 0;}
	my ($formulasHash, $aliases_hash, $cycles_counter_hash) = @_;

	my $formulasOutputFile = "${outputDir}power_formulas.${experiment}.formulas.Tomer";
	my $aliasesOutputFile = "${outputDir}power_formulas.${experiment}.aliases.Tomer";

	my $rush_through = general_config::getKnob("rushthrough");
	if ($rush_through eq "-1")
	{
		output_functions::print_to_log("Error! \"rushthrough\" knob is not set in config file. Using 1.17 as default.\n");
		$rush_through = 1.17;
	}

	my $v = "p0.c0.voltage";
	my $f = "p0.c0.frequency";
	my $v2f = "p0.c0.v_sqr_f";

	my $cycle_cnt = "";
	my $data = traverse_formulas_hash_and_build_a_printable_coho_syntax_formulas_file($formulasHash, $cycles_counter_hash, $rush_through, $v2f, "p0", "p0", \$cycle_cnt);

	# Replace all occurrences of "uncore1.uncore." with "p0.llcbo0."
	# before writing out the Coho input formula file
	#$data =~ s/\buncore1\.uncore\./p0.llcbo0./ig ;
	$data =~ s/\buncore\.uncore\./llcbo0./ig ;
	# Cleaning empty parentheses
	$data =~ s/\(\s*\)/\(0\)/ig ;

	open (COUTFILE, "| gzip >$formulasOutputFile.gz") or die_cmd("Can't open output file: \"$$formulasOutputFile\".\n");
	print COUTFILE $data . "\n";
	close (COUTFILE);

	my $dataAliases = "";
	foreach my $alias (sort keys %$aliases_hash)
	{
		$dataAliases .= "$alias : $$aliases_hash{$alias}\n";
	}
	$dataAliases .= "
$v : 1
$f : 1
$v2f : ( $v * $v * $f )
p0.c0.UNDEFINED : 0
p0.UNDEFINED : 0
p0.c0.UNKNOWN : 0
p0.UNKNOWN : 0
UNKNOWN : 0\n";
	
	open (COUTFILEA, "| gzip >$aliasesOutputFile.gz") or die_cmd("Can't open output file: \"$$aliasesOutputFile\".\n");
	print COUTFILEA $dataAliases . "\n";
	close (COUTFILEA);

	return 1;
}
#################

################# traverse_formulas_hash_and_build_a_printable_coho_syntax_formulas_file
sub traverse_formulas_hash_and_build_a_printable_coho_syntax_formulas_file
{
	if (@_ != 7) {die "Bad parameters!\n";}
	my ($formulasHash, $cycles_counter_hash, $rush_through, $v2f, $block_heirarchy_name, $block_name, $cycle_cnt) = @_;

	my $data = "";

	if (defined $$cycles_counter_hash{$block_name}) {
		my @k = keys(%{$$cycles_counter_hash{$block_name}});
		$$cycle_cnt = $k[0];
	} elsif (($block_name eq "uncore") and (defined $$cycles_counter_hash{'llcbo'})) {
		my @k = keys(%{$$cycles_counter_hash{'llcbo'}});
		$$cycle_cnt = $k[0];
	}

	$block_heirarchy_name =~ s/['",\s\xa0]//g;
	$block_heirarchy_name =~ s/-/_/g;
	$block_heirarchy_name =~ s/[\(\)\[\]:]/_/g;

	#my $block_Leakage = "";
	my $block_Idle = "";
	my $block_Active = "";

	if ( (not ref($formulasHash)) or (ref($formulasHash) ne "HASH") or (keys(%$formulasHash) == 0) )	# The hash is undefined. This is a block with no formulas info.
	{
		#$block_Leakage = "0";
		$block_Idle = "0";
		$block_Active = "0";
	}
	elsif ( (exists($$formulasHash{"Functions"})) or (exists($$formulasHash{"Idle"})) )	# This is a fub hash
	{
		my $fubName = $block_heirarchy_name;

		if ( (not defined($$cycle_cnt)) or ($$cycle_cnt eq "") )
		{
			die "No cycles_counter_hash entry for block $block_heirarchy_name\n";
		}

		my $functionsSum = "";
		my $funcSumSignal = "";
		foreach my $function (sort keys %{$$formulasHash{"Functions"}})
		{
			my $functionForm = $$formulasHash{"Functions"}{$function}{"Alias"};
			if (not defined $functionForm) {$functionForm = "";}
			($functionForm ne "") or ($functionForm = $$formulasHash{"Functions"}{$function}{"Formula"});
			(defined $functionForm) or ($functionForm = "");
			$functionForm =~ s/\s//g;
			($functionForm ne "") or ($functionForm = 0);
			my $func = $function;
			(defined $func) or ($func = "");
			$func =~ s/['",\s\xa0]//g;
			$func =~ s/-/_/g;
			$func =~ s/[\(\)\[\]:]/_/g;
			my $functionPower = $$formulasHash{"Functions"}{$function}{"Power"};
			if ((not defined $functionPower) or ($functionPower eq "")) {$functionPower = 0;}
			$data .= $fubName . ".$func.power : (($functionForm) / ($$cycle_cnt)) * ($functionPower) * ($rush_through) * ($v2f)\n";
			$functionsSum .= $funcSumSignal . $fubName . ".$func.power";
			$funcSumSignal = " + ";
		}
		if ($functionsSum eq "") {$functionsSum = 0;}

		my $idle = $$formulasHash{"Idle"};
		if ((not defined $idle) or ($idle eq "")) {$idle = 0;}
		#my $fubLeakage = $$formulasHash{"Leakage"};
		#my $maxpower = $$formulasHash{"MaxPower"};

		#$block_Leakage = "($$cycle_cnt / $$cycle_cnt) * $fubLeakage";
		$block_Idle = "(($$cycle_cnt) / ($$cycle_cnt)) * ($idle) * ($rush_through) * ($v2f)";
		$block_Active = "$functionsSum";
	}
	else	# This is not a fub hash (it's a higher hierarchy)
	{
		my $block_SumSignal = "";

		foreach my $sub_block_name (sort keys %$formulasHash)
		{
			my $sub_block_heirarchy_name = $block_heirarchy_name . "." . $sub_block_name;
			$sub_block_heirarchy_name =~ s/['",\s\xa0]//g;
			$sub_block_heirarchy_name =~ s/-/_/g;
			$sub_block_heirarchy_name =~ s/[\(\)\[\]:]/_/g;
			if ($sub_block_name eq "core") {$sub_block_heirarchy_name =~ s/\.core$/\.c0/;}

			$data .= traverse_formulas_hash_and_build_a_printable_coho_syntax_formulas_file($$formulasHash{$sub_block_name}, $cycles_counter_hash, $rush_through, $v2f, $sub_block_heirarchy_name, $sub_block_name, $cycle_cnt);

			#$block_Leakage .= $block_SumSignal . "$sub_block_heirarchy_name.Leakage.power";
			$block_Idle .= $block_SumSignal . "$sub_block_heirarchy_name.Idle.power";
			$block_Active .= $block_SumSignal . "$sub_block_heirarchy_name.Active.power";
			$block_SumSignal = " + ";
		}
	}

	$data .= $block_heirarchy_name . ".Idle.power : " . $block_Idle . "\n";
	#$data .= $block_heirarchy_name . ".Leakage.power : " . $block_Leakage . "\n";
	$data .= $block_heirarchy_name . ".Active.power : " . $block_Active . "\n";
	$data .= $block_heirarchy_name . ".Total.power : $block_heirarchy_name.Active.power + $block_heirarchy_name.Idle.power\n";

	return $data;
}
#################


################# output the power of all the tests
### usage: output_power(<experiment name>, <@testsListSorted>, <%fubsActive>,
### <%unitsActive>, <%clustersActive>, <%staticPower>, <%ipc_hash>,
### <output dir>, <vcc>, <frequency>)
sub output_power
{
	if (@_ != 8) {return 0;}
	my ($experiment, $testsListSorted, $ipc_hash, $outputDir,
		$powerHash, $GRP_list, $fullformulasHash, $num_of_traces_to_output_in_excel_in_fubs_level) = @_;

	my $rush_through = general_config::getKnob("rushthrough");
	if ($rush_through eq "-1")
	{
		output_functions::print_to_log("Error! \"rushthrough\" knob is not set in config file. Using 1.17 as default.\n");
		$rush_through = 1.17;
	}

	# read the planes from the config file
	my %planes;	# create a hash with all the planes v/f per segment in the hash
	my @segments;
	my $segments = general_config::getKnob("segments");
	if ($segments ne "-1")
	{
		@segments = split(",", $segments);
	}
	else
	{
		output_functions::print_to_log("There is no \"segments\" knob! Using capacitance only.\n");
		@segments = ("capacitance");
	}
	foreach my $segment (@segments)	# get per segment the planes v/f
	{
		my $retVal = general_config::getPlanesHash($segment, \%{$planes{$segment}});
		if ($retVal eq "-1")
		{
			undef $planes{$segment};
			output_functions::print_to_log("Error! Segment $segment does not exist in planes config file!\n");
		}
		foreach my $plane (keys %{$planes{$segment}})
		{
			my $v = $planes{$segment}{$plane}{"v"};
			my $f = $planes{$segment}{$plane}{"f"};
			$planes{$segment}{$plane}{"v2frt"} = $v * $v * $f * $rush_through;
		}
	}

	foreach my $segment (keys %planes) {
		### go over the planes hash and send per segment
		### the planes hash to the output functions
		output_power_xls_style("${experiment}.${segment}", $testsListSorted,
								$ipc_hash, $outputDir, \%{$planes{$segment}},
								$rush_through, "Cdyn", $powerHash, $GRP_list, $num_of_traces_to_output_in_excel_in_fubs_level);
		output_power_txt_format($testsListSorted, \%{$planes{$segment}},
								 $rush_through, "${outputDir}power_txt_output_cluster.${experiment}.${segment}.xls",
								 $ipc_hash, $powerHash, "Cdyn", $GRP_list, "Location");

		output_power_txt_format($testsListSorted, \%{$planes{$segment}},
								 $rush_through, "${outputDir}power_txt_output_functions.${experiment}.${segment}.xls",
								 $ipc_hash, $powerHash, "Cdyn", $GRP_list, "Function");
		output_power_txt_format($testsListSorted, \%{$planes{$segment}},
								 $rush_through, "${outputDir}power_txt_output_fubs.${experiment}.${segment}.xls",
								 $ipc_hash, $powerHash, "Cdyn", $GRP_list, "Fub");
	}

	output_power_txt_format($testsListSorted, "no planes data",
							 $rush_through,
							 "${outputDir}activity_output_${experiment}.xls",
							 $ipc_hash, $powerHash, "AF", $GRP_list, "Function");
	output_leakage_txt_format("${outputDir}leakage_txt_output_fubs.${experiment}.xls",
							  $fullformulasHash);

	return 1;
}
#################


################# output the power of all the tests
### usage: output_power_xls_style(<experiment name>, <@testsListSorted>,
###                                <%ipc_hash>, <output dir>, <planes hash>,
###                                <rush through>, <data type (Cdyn/AF)>,
###                                <power hash>, <groups list>)
sub output_power_xls_style
{
	if (@_ != 10) {return 0;}
	my ($experiment, $testsListSorted, $ipc_hash, $outputDir, $planes,
		$rush_through, $dataType, $powerHash, $GRP_list, $num_of_traces_to_output_in_excel_in_fubs_level) = @_;

	my $outputFile = "${outputDir}power_output.${experiment}.xlsx";
	my %sheets;
	my %sigColNums;
	my @hierarchy = ("Fub", "Unit", "Cluster", "Location");
	my @sheetsNames = ("Functions", "Fubs", "Units", "Clusters", "Globals");
	my $numOfTests = scalar(@$testsListSorted);
	foreach my $sheetName (@sheetsNames) {
		### get the sheets template ready before putting the blocks' data in

		$sheets{$sheetName}{"index"} = 1;
		push @{$sheets{$sheetName}{"data"}[0]}, "Log";
		foreach my $h (@hierarchy)
		{
			push @{$sheets{$sheetName}{"data"}[0]}, $h;
		}
		shift @hierarchy;

		# Save index of last hierarchy column: after this, real data starts
		$sigColNums{$sheetName}{'Hierarchy'} = $#{$sheets{$sheetName}{"data"}[0]};

		push @{$sheets{$sheetName}{"data"}[0]}, ("Max");
		push @{$sheets{$sheetName}{"first indexes"}}, ("Max " . $dataType);
		foreach my $GRP (@$GRP_list)
		{
			push @{$sheets{$sheetName}{"data"}[0]}, ($GRP);
			push @{$sheets{$sheetName}{"first indexes"}}, ($dataType . " " . $GRP);
		}
		if ($sheetName eq "Functions" )
		{
			push @{$sheets{$sheetName}{"data"}[0]}, ("EC");
			push @{$sheets{$sheetName}{"first indexes"}}, ("EC");
		}
		else
		{
			push @{$sheets{$sheetName}{"data"}[0]}, ("Idle", "Leakage");
			push @{$sheets{$sheetName}{"first indexes"}}, ("Idle", "Leakage");
		}

		# Save index of "Leakage" column: after this, only traces exist
		$sigColNums{$sheetName}{'Leakage'} = $#{$sheets{$sheetName}{"data"}[0]};

		for (my $col = 0; $col < $numOfTests; $col++)
		{
			push @{$sheets{$sheetName}{"data"}[0]}, $$testsListSorted[$col];
		}
	}

	@hierarchy = ();
	add_blocks_data_to_sheets(\%sheets, \@hierarchy, \@sheetsNames,
							  $powerHash, $planes, $rush_through, $dataType);

	##### create IPC sheet
	push @{$sheets{"IPC"}{"data"}[0]}, "Log";
	$sheets{"IPC"}{"index"} = 1;
	foreach my $trace (@$testsListSorted)
	{
		push @{$sheets{"IPC"}{"data"}[0]}, $trace;
	}
	my @header_items = ("Instructions", "Cycles", "IPC");
	foreach my $cbo ("cbo0", "cbo1", "cbo2")
	{
		foreach my $item ("llc_lookup", "llc_miss", "llc_hit")
		{
			push @header_items, $cbo . "." . $item;
			push @header_items, $cbo . "." . $item . "_per_cycle";
		}
	}
	foreach my $item ("llc_lookup", "llc_miss", "llc_hit")
	{
		push @header_items, "cbo." . $item;
		push @header_items, "cbo." . $item . "_per_cycle";
	}
	push @header_items, ("cbo_BW");
	foreach my $cbo ("mc_channel0", "mc_channel1", "mc_channel2")
	{
		foreach my $item ("mc_num_reads", "mc_num_writes")
		{
			push @header_items, $cbo . "." . $item;
			push @header_items, $cbo . "." . $item . "_per_cycle";
		}
	}
	foreach my $item ("mc_num_reads", "mc_num_writes")
	{
		push @header_items, "mc." . $item;
		push @header_items, "mc." . $item . "_per_cycle";
	}
	push @header_items, ("mc_cycles", "mc_BW");

	foreach my $header (@header_items)
	{
		my $col = $sheets{"IPC"}{"index"};
		push @{$sheets{"IPC"}{"data"}[$col]}, $header;
		foreach my $trace (@$testsListSorted)
		{
			push @{$sheets{"IPC"}{"data"}[$col]}, $$ipc_hash{$trace}{$header};
		}
		$sheets{"IPC"}{"index"}++;
	}
	#####

	my $destname = "$outputFile";
	if (-f $destname) {system "rm $destname";}
	my $dest_book  = Excel::Writer::XLSX->new("$destname") or
	  die_cmd("Could not create a new Excel file as: ${destname}!");

	### Write the data into the excel file
	### For Units, Clusters and Globals sheets, roll up power numbers
	### from corresponding lower levels, since those lower levels
	### may have individually assigned voltage/freq planes
	my $prevSheetName = "";
	foreach my $sheetName (@sheetsNames, "IPC")
	{
		my $dest_sheet = $dest_book->add_worksheet($sheetName);

		my $numOfColumns = scalar(@{$sheets{$sheetName}{"data"}});
		if (($sheetName eq "Fubs") or ($sheetName eq "Functions"))
		{
			for (my $col = 0; $col < $numOfColumns; $col++)
			{
				my $numOfRows = scalar(@{$sheets{$sheetName}{"data"}[$col]});
				if (	($num_of_traces_to_output_in_excel_in_fubs_level ne "")
						and ($num_of_traces_to_output_in_excel_in_fubs_level > 0)
						and ($num_of_traces_to_output_in_excel_in_fubs_level < $numOfRows)
					)
				{
					$numOfRows = $num_of_traces_to_output_in_excel_in_fubs_level;
				}
				for (my $row = 0; $row < $numOfRows; $row++)
				{
					my $val = $sheets{$sheetName}{"data"}[$col][$row];
					(defined $val) or ($val = "");
					$dest_sheet->write($col,$row,$val);
				}
			}
		}
		else
		{
			# Roll up power numbers from lower level sheet,
			# overwriting sums computed earlier that may not reflect
			# different voltage/frequency plane settings for subblocks
			if ($sheetName ne "IPC") {
				my $curSheet = $sheets{$sheetName};
				my $prevSheet = $sheets{$prevSheetName};
				rollup_from_lower_level ($sheetName, $prevSheetName,
										 $curSheet, $prevSheet,
										 ($sigColNums{$sheetName}{'Hierarchy'}+1),
										 ($sigColNums{$sheetName}{'Leakage'}+1));
			}

			# Write out rolled-up data
			for (my $col = 0; $col < $numOfColumns; $col++)
			{
				my $numOfRows = scalar(@{$sheets{$sheetName}{"data"}[$col]});
				for (my $row = 0; $row < $numOfRows; $row++)
				{
					my $val = $sheets{$sheetName}{"data"}[$col][$row];
					(defined $val) or ($val = "");
					$dest_sheet->write($row,$col,$val);
				}
			}
		}

		$prevSheetName = $sheetName;
	}
	$dest_book->close();
	print_to_log("Power numbers writen into $destname\n");
	system("gzip -f $destname");
	print_to_log("Zipped $destname\n");

	return 1;
}
#################


################# roll up power data from lower level sheet
### usage: rollup_from_lower_level (<cur_sheetName>, <prevSheetName>,
###									<curSheetPtr>, <prevSheetPtr>,
###                                 <idx>, <sidx>)
sub rollup_from_lower_level
{
	if (@_ != 6) {return 0;}

	my ($curSheetName, $prevSheetName, $curSheetPtr, $prevSheetPtr, $idx, $sidx) = @_;

	# idx = index of power data field in curSheet (right after "Location")
	# pidx = corresponding index in prevSheet
	my $pidx = $idx + 1;

	# Index to "row" tracker in prevSheet.  Since the sheet entries
	# are sorted, we can advance in curSheet 1 block at a time,
	# and for each block, advance through all the "rows" of prevSheet
	# which belong under the current block.
	# E.g., curSheet = Units; prevSheet = Fubs; in curSheet, we are
	# at block "EXE"; in prevSheet, we loop through all Fubs with
	# unit == EXE, leaving $prow pointing to the next Fub which should
	# correspond to the next unit in curSheet.
	my $prow = 1;
	my $max_idx;

	# Initialize power data in block arrays in curSheet
	foreach my $barray (@{$$curSheetPtr{'data'}}) {
		if ($$barray[0] eq "Log") {
			# Locate the "Max" column, then skip the header line
			$max_idx = 1;
			while ((defined $$barray[$max_idx]) && ($$barray[$max_idx] ne "Max")) {
				$max_idx++;
			}
			if ($$barray[$max_idx] ne "Max") {
				output_functions::print_to_log("Error: Couldn't find Max column in sheet \"$curSheetName\".\n");
				$max_idx = -1;
			}
			next;
		}
		my $blockName = $$barray[0]; # == Unit, Cluster or Location

		# Zero out all power data fields for this block
		my $bidx = $idx;		# where power data starts in curSheet
		while (defined $$barray[$bidx]) {
			$$barray[$bidx] = 0;
			$bidx++;
		}

		# Roll up power data from prevSheet into curSheet for this block
		# Depends on the fact that both are already sorted, so we can
		# run through prevSheet 1 time
		while (defined $$prevSheetPtr{'data'}) {
			# Ptr to this block's power data array in prevSheet
			my $parray = \@{$$prevSheetPtr{'data'}[$prow]};

			# Include only the sub-hierarchy of the current block
			my $notSameSubHier = 0;
			for (my $level=0; $level < $idx; $level++) {
				if ((not defined $$barray[$level]) ||
					(not defined $$parray[($level+1)]) ||
					($$barray[$level] ne $$parray[($level+1)])) {
					$notSameSubHier = 1;
					last;
				}
			}
			if ($notSameSubHier) {
				# prow is past the sub-hierarchy elements below blockname
				last;
			}

			$bidx = $idx;		# where power data starts in curSheet
			my $bpidx = $pidx;	# where power data starts in prevSheet

			# Loop over all fields of this block in prevSheet,
			# rolling it up into corresponding field in curSheet
			while (defined $$parray[$bpidx]) {
				$$barray[$bidx] += $$parray[$bpidx];
				$bidx++;
				$bpidx++;
			}

			# Compute the Max column at this hierarchy level,
			# replacing the sum rolled up from the lower level
			if ($max_idx > -1) {
				my $bsidx = $sidx;
				$$barray[$max_idx] = $$barray[$bsidx];
				$bsidx++;
				while (defined $$barray[$bsidx]) {
					if ($$barray[$bsidx] > $$barray[$max_idx]) {
						$$barray[$max_idx] = $$barray[$bsidx];
					}
					$bsidx++;
				}
			}

			$prow++;			# Advance to next row in prevSheet
		}
	}
}


################# insert the power data to the excel sheet hash
### usage: add_blocks_data_to_sheets(\%sheets, \@hierarchy, \@sheets,
### $powerHash, $process, "Cdyn")
sub add_blocks_data_to_sheets
{
	if (@_ != 7) {return 0;}
	my ($sheetsHash, $hierarchy, $sheetsNames, $powerHash, $planes,
		$rushthrough, $dataType) = @_;

	my $sheetName = pop @$sheetsNames;
	((defined $sheetName) and ($sheetName ne "")) or
	  die_cmd("Error. Two few sheet names for power excel.\n");
	my $sheetHash = \%{$$sheetsHash{$sheetName}};

	if (defined $$powerHash{"Functions"})	# This is a fub
	{
		foreach my $block (sort keys %{$$powerHash{"Functions"}})
		{
			my $pHash = \%{$$powerHash{"Functions"}{$block}};
			add_block_data_to_sheet($sheetHash, $block, $hierarchy, $pHash,
									$planes, $rushthrough, $dataType);
		}
	}
	else	# This is a higher heirarchy block
	{
		foreach my $block (sort keys %{$$powerHash{"SubBlocks"}})
		{
			my $pHash = \%{$$powerHash{"SubBlocks"}{$block}};

			# Change recursion to post-order: descend to FUB-level and
			# compute leaf-level power numbers (add_block_data_to_sheet)
			# Then, rollup FUB power numbers to upper hierarchy levels
			unshift @$hierarchy, $block;
			add_blocks_data_to_sheets($sheetsHash, $hierarchy, $sheetsNames,
									  $pHash, $planes, $rushthrough, $dataType);
			shift @$hierarchy;

			# After returning from recursive processing of all hierarchy
			# below current block, compute power sum for this block
			add_block_data_to_sheet($sheetHash, $block, $hierarchy, $pHash,
									$planes, $rushthrough, $dataType);
		}
	}

	push @$sheetsNames, $sheetName;

	return 1;
}
#################


################# insert the power data to the excel sheet hash
### usage: add_block_data_to_sheet()
sub add_block_data_to_sheet
{
	if (@_ != 7) {return 0;}
	my ($sheetHash, $block, $hierarchy, $pHash, $planes,
		$rushthrough, $dataType) = @_;

	my $index = $$sheetHash{"index"}; # next available row in sheet
	push @{$$sheetHash{"data"}[$index]}, $block;
	my $row = 1;
	foreach my $h (@$hierarchy)
	{
		push @{$$sheetHash{"data"}[$index]}, $h;
		$row++;
	}

	### Determine the voltage/frequency of the block
	my $process;
	my $location = "";

	# Find v2frt at lowest-level in block's hierarchy with plane defined
	$process = get_plane_v2frt ($dataType, $planes, ($block, @$hierarchy));

	foreach my $item (@{$$sheetHash{"first indexes"}})
	{
		my $itemVal = $$pHash{$item};
		(defined $itemVal) or ($itemVal = 0);
		if ($item eq "EC")
		{
			if ($itemVal =~ /^\s*-?\d+\.?\d*(e-)?\d*\s*$/)
			{
				$itemVal *= $rushthrough;
			}
			else
			{
				print_to_log("Error: ($itemVal) is not a numeric value at $block at EC\n");
			}
		}
		elsif ($item ne "Leakage")
		{
			if ($itemVal =~ /^\s*-?\d+\.?\d*(e-)?\d*\s*$/)
			{
				$itemVal *= $process;
			}
			else
			{
				print_to_log("Error: ($itemVal) is not a numeric value at $block\n");
			}
		}
		push @{$$sheetHash{"data"}[$index]}, $itemVal;
		$row++;
	}
	while (defined $$sheetHash{"data"}[0][$row])
	{
		my $trace = $$sheetHash{"data"}[0][$row];
		my $traceVal = $$pHash{$dataType}{$trace};
		(defined $traceVal) or ($traceVal = 0);
		if ($traceVal =~ /^\s*-?\d+\.?\d*(e-)?\d*\s*$/)
		{
			$traceVal *= $process;
		}
		else
		{
			print_to_log("Error: ($traceVal) is not a numeric value at $block at $dataType at trace $trace\n");
		}
		push @{$$sheetHash{"data"}[$index]}, $traceVal;
		$row++;
	}

	$$sheetHash{"index"}++;

	return 1;
}
#################


################# output the stats of all the tests
### usage: output_stats(<experiment name>, <@testsListSorted>, <%stats_hash>, <%ipc_hash>, <output dir>)
sub output_stats
{
	if (@_ != 7) {return 0;}
	my ($experiment, $testsListSorted, $stats_hash, $stats_GRP_hash, $GRP_list, $ipc_hash, $outputDir) = @_;
	($experiment eq "") or ($experiment = "_" . $experiment);

	my $outputFile = "${outputDir}stats_output${experiment}.xls";
	open (STATSOUTFILE, "| gzip >$outputFile.gz") or die_cmd("Can't open stats output file: \"$outputFile\.gz\".\n");
	my $data = "";

	my $numOfTests = scalar(@$testsListSorted);

	$data = "Counter";
	foreach my $GRP (@$GRP_list) {$data .= "\t$GRP";}
	for (my $col = 0; $col < $numOfTests; $col++) {$data .= "\t$$testsListSorted[$col]";}

	foreach my $counter (sort keys(%$stats_hash))
	{
		$data .= "\n$counter";

		foreach my $GRP (@$GRP_list) 
		{
			if (defined($$stats_GRP_hash{$counter}{$GRP}))
			{
				my $af = $$stats_GRP_hash{$counter}{$GRP};
				$af = sprintf("%.5f",$af);
				$af =~ s/\.?0+$//;
				$data .= "\t$af";
			}
			else
			{
				$data .= "\t0";
			}
		}
		for (my $col = 0; $col < $numOfTests; $col++)
		{
			if ((defined($$stats_hash{$counter}{$$testsListSorted[$col]})) and (defined($$stats_hash{"cycles"}{$$testsListSorted[$col]})))
			{
				my $counter_val = $$stats_hash{$counter}{$$testsListSorted[$col]};
				my $cycles_val = $$stats_hash{"cycles"}{$$testsListSorted[$col]}/2;
				if ($counter =~ /\_([A-Z]+)$/)
				{
					my $ext = $1;
					if (($ext eq "BUCKETS") or ($ext eq "MIN") or ($ext eq "MAX") or ($ext eq "MEAN") or ($ext eq "MEDIAN"))
					{
						$cycles_val = 1;	# Don't normalize counters of histograms like MIN, MAX, MEAN, etc.
					}
				}
				my $af = $counter_val/$cycles_val;
				$af = sprintf("%.5f",$af);
				$af =~ s/\.?0+$//;
				$data .= "\t$af";
			}
			else
			{
				$data .= "\t0";
			}
		}
		print STATSOUTFILE "$data";
		$data = "";
	}

	print STATSOUTFILE "$data";
	close(STATSOUTFILE);

	print_to_log("Stats numbers writen into $outputFile\n");

	return 1;
}
#################


################# output the stats that are not used in all the tests
### usage: output_not_used_stats(<experiment name>, <%stats_hash>, <output dir>, \%stats_used_in_formulas)
sub output_not_used_stats
{
	if (@_ != 4) {return 0;}
	my ($experiment, $stats_hash, $outputDir, $stats_used_in_formulas) = @_;
	($experiment eq "") or ($experiment = "_" . $experiment);

	my $needed_stats_outputFile = "${outputDir}stats_needed_output${experiment}.xls";
	open (NEEDEDSTATSOUTFILE, "| gzip >$needed_stats_outputFile.gz") or die_cmd("Can't open stats output file: \"$needed_stats_outputFile\.gz\".\n");
	my $not_used_stats_outputFile = "${outputDir}stats_not_used_output${experiment}.xls";
	open (NOTUSEDSTATSOUTFILE, "| gzip >$not_used_stats_outputFile.gz") or die_cmd("Can't open stats output file: \"$not_used_stats_outputFile\.gz\".\n");

	print NEEDEDSTATSOUTFILE "Counter\tMissing in stats files?\ttotal EC\tLocation info";
	print NOTUSEDSTATSOUTFILE "Counter\ttotal EC\tLocation info";

	foreach my $counter (sort keys(%$stats_used_in_formulas))
	{
		if (($counter !~ /^\d+(\.\d+)?$/) and ($counter !~ /^p0\.c[1-9]\./))	# check if this is a valid counter name
		{
			my $EC = $$stats_used_in_formulas{$counter}{"EC"};
			my $info = $$stats_used_in_formulas{$counter}{"Info"};

			if (!defined $$stats_hash{$counter})
			{
				print NEEDEDSTATSOUTFILE "\n$counter\tmissing\t$EC\t$info";
				print NOTUSEDSTATSOUTFILE "\n$counter\t$EC\t$info";
			}
			else
			{
				print NEEDEDSTATSOUTFILE "\n$counter\t\t$EC\t$info";
			}
		}
	}

	close(NEEDEDSTATSOUTFILE);
	close(NOTUSEDSTATSOUTFILE);

	print_to_log("Stats that were needed were writen into $needed_stats_outputFile\n");
	print_to_log("Stats that were not used were writen into $not_used_stats_outputFile\n");

	return 1;
}
#################


################# create output in txt format
### usage: output_power_txt_format()
sub output_power_txt_format
{
	if (@_ != 9) {return 0;}
	my ($testsListSorted, $planes, $ECprocess, $outputFileTXT, $ipc_hash, $powerHash, $dataType, $GRP_list, $heirarchy) = @_;

	(($dataType eq "AF") or ($dataType eq "Cdyn")) or die_cmd("($dataType) is bad data type in function output_power_txt_format!\n");

	open (OUTFILE, "| gzip >$outputFileTXT.gz") or die_cmd("Can't open output file: \"$outputFileTXT\.gz\".\n");
	my $data = "";
	my $process;  # vsq*f*rushthrough of the block
	my $hierCols; 				# columns of hier data with/without power_section

	my @commonHeaders;
	if ($heirarchy eq "Function") {
		$hierCols = 5;
		@commonHeaders = ("Function", "Fub", "Unit", "Cluster", "Location");
		if (general_config::getKnob ("powerSection") == 1) {
			push (@commonHeaders, "Power_section");
			$hierCols++;
		}
		push (@commonHeaders,  ("EC_formula", "EC", "Comment", "Max"));
	} elsif ($heirarchy eq "Fub") {
		$hierCols = 4;
		@commonHeaders = ("Fub", "Unit", "Cluster", "Location");
		if (general_config::getKnob ("powerSection") == 1) {
			push (@commonHeaders, "Power_section");
			$hierCols++;
		}
		push (@commonHeaders,  ("Idle", "Max"));
	} else
    {
        $hierCols = 4;
		@commonHeaders = ("Location");
		if (general_config::getKnob ("powerSection") == 1) {
			push (@commonHeaders, "Power_section");
			$hierCols++;
		}
		push (@commonHeaders,  ("Idle", "Max"));
    }

	my %mapH2H = (
		"Idle" => "Idle",
		"Leakage" => "Leakage",
		"EC_formula" => "EC_formula",
		"EC" => "EC",
		"Comment" => "Comment",
		"Max" => "Max $dataType",
		);
	foreach my $GRP (@$GRP_list)
	{
		push @commonHeaders, $GRP;
		$mapH2H{$GRP} = "$dataType $GRP";
	}

	my $numOfCommonHeaders = scalar(@commonHeaders);
	my @columns = (@commonHeaders, @$testsListSorted);
	$data = "$columns[0]";
	for (my $col = 1; $col < scalar(@columns); $col++) {$data .= "\t$columns[$col]";}

	### output the IPC data
	$data .= "\nIPC";
	for (my $i = 1; $i<$numOfCommonHeaders; $i++) {$data .= "\t";}
	for (my $col = $numOfCommonHeaders; $col < scalar(@columns); $col++)
	{
		if (defined($$ipc_hash{$columns[$col]}{"IPC"}))
		{
			my $val = $$ipc_hash{$columns[$col]}{"IPC"};
			(defined $val) or ($val = "");
			if ($val !~ /^\s*-?\d+\.?\d*(e-)?\d*\s*$/)
			{
				print_to_log("Error: ($val) is not a numeric value at IPC at $columns[$col]\n");
			}
			$data .= "\t$val";
		}
    }
###
    foreach my $location (sort keys %{$$powerHash{"SubBlocks"}})
    {
#        if (defined($$powerHash{"SubBlocks"}{$location}))
#        {
#            my $val =$$powerHash{{"SubBlocks"}{$location}}; 
#            print "$location $val \n";
#        }
#        					$process = get_plane_v2frt ($dataType, $planes, $fub, $unit, $cluster, $location);

		foreach my $cluster (sort keys %{$$powerHash{"SubBlocks"}{$location}{"SubBlocks"}})
		{
        my $locHash = \%{$$powerHash{"SubBlocks"}{$location}{"SubBlocks"}{$cluster}};
        my $locHeirarchy = "$location";

        $process = get_plane_v2frt ($dataType, $planes, $location);

        if (general_config::getKnob ("powerSection") == 1) {
            if (defined $$locHash{'Power_section'}) {
                $locHeirarchy .= "\t$$locHash{'Power_section'}";
            } else {
                $locHeirarchy .= "\t";
            }
        }

        if ($heirarchy eq "Location")
        {			# $heirarchy == Fub
            $data .= "\n$locHeirarchy";

            for (my $col = $hierCols; $col < $numOfCommonHeaders; $col++)
            {
                my $index = $mapH2H{$columns[$col]};
                if (defined($$locHash{$index}))
                {
                    my $val = $$locHash{$index};
                    (defined $val) or ($val = "");
                    if ($val =~ /^\s*-?\d+\.?\d*(e-)?\d*\s*$/)
                    {
                        $val *= $process;
                    }
                    else
                    {
                        print_to_log("Error: ($val) is not a numeric value at Location $location at $columns[$col]\n");
                    }
                    $data .= "\t$val";
                }
                else
                {
                    print_to_log("Error: ($columns[$col]) not found at location $location\n");
                    $data .= "\t";
                }
            }

            for (my $col = $numOfCommonHeaders; $col < scalar(@columns); $col++)	# the results per trace
            {
                if (defined($$locHash{$dataType}{$columns[$col]}))
                {
                    my $val = $$locHash{$dataType}{$columns[$col]};
                    (defined $val) or ($val = "0");
                    if ($val =~ /^\s*-?\d+\.?\d*(e-)?\d*\s*$/)
                    {
                        $val *= $process;
                    }
                    else
                    {
                        print_to_log("Error: ($val) is not a numeric value at location $location at $columns[$col]\n");
                    }
                    $data .= "\t$val";
                }
                else
                {
                    $data .= "\t";
                }
            }
            print OUTFILE "$data";
            $data = "";

        }

        }#cluster hash

    }

	foreach my $location (sort keys %{$$powerHash{"SubBlocks"}})
	{
		foreach my $cluster (sort keys %{$$powerHash{"SubBlocks"}{$location}{"SubBlocks"}})
		{
			foreach my $unit (sort keys %{$$powerHash{"SubBlocks"}{$location}{"SubBlocks"}{$cluster}{"SubBlocks"}})
			{
				foreach my $fub (sort keys %{$$powerHash{"SubBlocks"}{$location}{"SubBlocks"}{$cluster}{"SubBlocks"}{$unit}{"SubBlocks"}})
				{
					$process = get_plane_v2frt ($dataType, $planes, $fub, $unit, $cluster, $location);

					my $fubHash = \%{$$powerHash{"SubBlocks"}{$location}{"SubBlocks"}{$cluster}{"SubBlocks"}{$unit}{"SubBlocks"}{$fub}};
					my $fubHeirarchy = "$fub\t$unit\t$cluster\t$location";
					if (general_config::getKnob ("powerSection") == 1) {
						if (defined $$fubHash{'Power_section'}) {
							$fubHeirarchy .= "\t$$fubHash{'Power_section'}";
						} else {
							$fubHeirarchy .= "\t";
						}
					}

					if ($heirarchy eq "Fub")
					{			# $heirarchy == Fub
						$data .= "\n$fubHeirarchy";

						for (my $col = $hierCols; $col < $numOfCommonHeaders; $col++)
						{
							my $index = $mapH2H{$columns[$col]};
							if (defined($$fubHash{$index}))
							{
								my $val = $$fubHash{$index};
								(defined $val) or ($val = "");
								if ($val =~ /^\s*-?\d+\.?\d*(e-)?\d*\s*$/)
								{
									$val *= $process;
								}
								else
								{
									print_to_log("Error: ($val) is not a numeric value at fub $fub at $columns[$col]\n");
								}
								$data .= "\t$val";
							}
							else
							{
								print_to_log("Error: ($columns[$col]) not found at fub $fub\n");
								$data .= "\t";
							}
						}

						for (my $col = $numOfCommonHeaders; $col < scalar(@columns); $col++)	# the results per trace
						{
							if (defined($$fubHash{$dataType}{$columns[$col]}))
							{
								my $val = $$fubHash{$dataType}{$columns[$col]};
								(defined $val) or ($val = "0");
								if ($val =~ /^\s*-?\d+\.?\d*(e-)?\d*\s*$/)
								{
									$val *= $process;
								}
								else
								{
									print_to_log("Error: ($val) is not a numeric value at fub $fub at $columns[$col]\n");
								}
								$data .= "\t$val";
							}
							else
							{
								$data .= "\t";
							}
						}
						print OUTFILE "$data";
						$data = "";


#						$data .= "\nLeakage\t$fubHeirarchy";
	#					for (my $col = 2; $col < 5; $col++) {$data .= "\t$$fubsActive{$fub}{$columns[$col]}";}

#						if (defined($$fubHash{$mapH2H{"Leakage"}}))
#						{
#							$val = $$fubHash{$mapH2H{"Leakage"}};
#							(defined $val) or ($val = "");
#						}
#						$data .= "\t$val";
					}
					elsif($heirarchy eq "Function")
					{			# $heirarchy == Function
						if ($dataType eq "Cdyn")	# take care of Idle and Leakage
						{
							$data .= "\nIdle\t$fubHeirarchy";

							if (defined($$fubHash{$mapH2H{"Idle"}}))
							{
								my $formula = $$fubHash{"Idle_formula"};
								my $val = $$fubHash{$mapH2H{"Idle"}};
								my $comment = $$fubHash{"Idle_comment"};
								(defined $formula) or ($formula = "");
								(defined $val) or ($val = "");
								(defined $comment) or ($comment = "");
								if ($formula eq $val) {
									# Print only real formulas
									$formula = "";
								}
								if ($val =~ /^\s*-?\d+\.?\d*(e-)?\d*\s*$/)
								{
									$val *= $process;
								}
								else
								{
									print_to_log("Error: ($val) is not a numeric value at fub $fub at idle\n");
								}
								$data .= "\t$formula\t$val\t$comment";
							}

							$data .= "\nLeakage\t$fubHeirarchy";

							if (defined($$fubHash{$mapH2H{"Leakage"}}))
							{
								my $val = $$fubHash{$mapH2H{"Leakage"}};
								(defined $val) or ($val = "");
								$data .= "\t\t$val\t"; # no formula or comment to print
							}
						}

						foreach my $function (sort keys(%{$$fubHash{"Functions"}}))
						{
							my $functionHash = \%{$$fubHash{"Functions"}{$function}};
							$data .= "\n$function\t$fubHeirarchy";

							for (my $col = $hierCols; $col < $numOfCommonHeaders; $col++)
							{
								my $index = $mapH2H{$columns[$col]};
								if (defined($$functionHash{$index}))
								{
									my $val = $$functionHash{$index};
									(defined $val) or ($val = "");
									if ($val =~ /^\s*-?\d+\.?\d*(e-)?\d*\s*$/)
									{
										if ($index eq "EC_formula")
										{
											# Formula is just a number, don't print it
											$val = "";
										}
										else
										{
											my $p = $process;
											if ($index eq "EC") {$p = $ECprocess;}
											$val *= $p;
										}
									}
									elsif (($index ne "EC_formula") && ($index ne "Comment"))
									{
										print_to_log("Error: ($val) is not a numeric value at fub $fub at function $function at $columns[$col]\n");
									}
									$data .= "\t$val";
								}
								else
								{
									print_to_log("Error: ($columns[$col]) not found at fub $fub at function $function\n");
									$data .= "\t";
								}
							}

							for (my $col = $numOfCommonHeaders; $col < scalar(@columns); $col++)	# the results per trace
							{
								if (defined($$functionHash{$dataType}{$columns[$col]}))
								{
									my $val = $$functionHash{$dataType}{$columns[$col]};
									(defined $val) or ($val = "0");
									if ($val =~ /^\s*-?\d+\.?\d*(e-)?\d*\s*$/)
									{
										$val *= $process;
									}
									else
									{
										print_to_log("Error: ($val) is not a numeric value at fub $fub at function $function at $columns[$col]\n");
									}
									$data .= "\t$val";
								}
								else
								{
									$data .= "\t";
								}
							}
							print OUTFILE "$data";
							$data = "";
						}
					}
				}
			}
		}
	}

	close(OUTFILE);

	print_to_log("Power numbers writen into $outputFileTXT\n");

	return 1;
}
#################


################# Find and return v2frt = v*v*f*rushthrough
################# defined for the lowest-level hierarchy level,
################# provided in lowest-to-highest order
sub get_plane_v2frt {
	my ($dataType, $planes, @hier) = @_;
	my $block;

	if ($dataType ne "Cdyn") {
		return 1;
	}

	foreach $block (@hier) {
		if (defined $$planes{$block}) {
			return $$planes{$block}{"v2frt"};
		}

		# May need "core0" -> "core" type conversion
		$block =~ s/\d*$//;
		if (defined $$planes{$block}) {
			return $$planes{$block}{"v2frt"};
		}
	}

	# If you reach this point, didn't find plane data for this hierarchy
	my $str = "";
	foreach $block (@hier) {
		$str = "$block/$str";
	}

	# couldn't find this block! reporting a warning and returning 0 INSTEAD OF dying.
	print("Error: no voltage/frequency info for \"$str\" in planes config file! Using 0!\n");
	return 0;
}
#################


################# create leakage output in txt format
### usage: output_leakage_txt_format()
sub output_leakage_txt_format
{
	if (@_ != 2) {return 0;}
	my ($outputFileTXT, $fullformulasHash) = @_;

#	(($dataType eq "AF") or ($dataType eq "Cdyn")) or die_cmd("($dataType) is bad data type in function output_power_txt_format!\n");

	open (OUTFILE, "| gzip >$outputFileTXT.gz") or die_cmd("Can't open output file: \"$outputFileTXT\.gz\".\n");
	my $data = "";

#	my $idle_EC = "EC";
#	if ($heirarchy ne "Function") {$idle_EC = "Idle";}
	my @commonHeaders = ("Fub", "Unit", "Cluster", "Location");
#	my @leakageHeaders = ("Z_Total", "Des_type", "\%LL", "\%UVT", "PN_ratio", "SD_SF", "G_SF", "J_SF", "Leak_Ovr");
	my @leakageHeaders = ("Z_Total", "Design_Type", "\%LL", "\%UVT", "PN_ratio", "Subthreshold_Stack_Factor", "Gate_Stack_Factor", "Junction_Stack_Factor", "Leakage_Override [mW]");
#	while ((0 < scalar(@commonHeaders)) and ($commonHeaders[0] ne $heirarchy)) {shift @commonHeaders;}
	my %mapH2H = (
		"Z_Total" => "zTotal",
		"Design_Type" => "Design_Type",
		"\%LL" => "llPr",
		"\%UVT" => "uvtPr",
		"PN_ratio" => "pnRatio",
		"Subthreshold_Stack_Factor" => "subthresholdStackFactor",
		"Gate_Stack_Factor" => "gateStackFactor",
		"Junction_Stack_Factor" => "junctionStackFactor",
		"Leakage_Override [mW]" => "Leakage_Override [mW]"
		);
#	foreach my $GRP (@$GRP_list)
#	{
#		push @commonHeaders, $GRP;
#		$mapH2H{$GRP} = "$dataType $GRP";
#	}

	my $numOfCommonHeaders = scalar(@commonHeaders);
	my @columns = (@commonHeaders, @leakageHeaders);
	$data = "$columns[0]";
	for (my $col = 1; $col < scalar(@columns); $col++) {$data .= "\t$columns[$col]";}

	foreach my $location (sort keys %$fullformulasHash)
	{
		### Determine the voltage/frequency of the block
#		my $process;
#		if ($dataType eq "Cdyn")
#		{
#			my $loc = $location;
#			(defined $$planes{$loc}) or ($loc =~ s/\d*$//);
#			if (defined $$planes{$loc})
#			{
#				$process = $$planes{$loc}{"v2frt"}; #$v * $v * $f * $rushthrough;
#			}
#			else
#			{
#				die_cmd("Error: no voltage/frequency info for \"$loc\" in planes config file!\n");
#			}
#		}
#		else
#		{
#			$process = 1;
#		}
		###
		foreach my $cluster (sort keys %{$$fullformulasHash{$location}})
		{
			foreach my $unit (sort keys %{$$fullformulasHash{$location}{$cluster}})
			{
				foreach my $fub (sort keys %{$$fullformulasHash{$location}{$cluster}{$unit}})
				{
					my $fubHash = \%{$$fullformulasHash{$location}{$cluster}{$unit}{$fub}};
					my $fubHeirarchy = "$fub\t$unit\t$cluster\t$location";

					$data .= "\n$fubHeirarchy";

					for (my $col = $numOfCommonHeaders; $col < scalar(@columns); $col++)	# the leakage data
					{
						my $LD_col = $mapH2H{$columns[$col]};
						if ((defined $LD_col) and (defined($$fubHash{"LeakageData"}{$LD_col})))
						{
							my $val = $$fubHash{"LeakageData"}{$LD_col};
							(defined $val) or ($val = "");
#							if ($val =~ /^\s*-?\d+\.?\d*(e-)?\d*\s*$/)
#							{
#								$val *= $process;
#							}
#							else
#							{
#								print_to_log("Error: ($val) is not a numeric value at fub $fub at $columns[$col]\n");
#							}
							$data .= "\t$val";
						}
						else
						{
#								print_to_log("Error: ($columns[$col]) not found at fub $fub at function $function\n");
							$data .= "\t";
						}
					}
					print OUTFILE "$data";
					$data = "";
				}
			}
		}
	}

	close(OUTFILE);

	print_to_log("Leakage numbers writen into $outputFileTXT\n");

	return 1;
}
#################


################# output the regression results
### usage: output_regression(<experiment name>, <pointer to %regressionResults_hash>, <pointer to the testsUsed hash>, <output dir>)
sub output_regression
{
	if (@_ != 4) {return 0;}
	my ($experiment, $regressionResults, $testsUsed, $outputDir) = @_;
	($experiment eq "") or ($experiment = "_" . $experiment);

	my $numOfTotalFuncs = 0;
	my $numOfTotalToggledFuncs = 0;
	my $numOfTotalECs = 0;
	my $numOfTotalNotNegativeECs = 0;

	my $outputFile = "${outputDir}regression_output${experiment}.xls";
	my $outputFileFiltered = "${outputDir}regression_output_filtered${experiment}.xls";
	my $inputFile = "${outputDir}regression_input${experiment}.xls";
	my $dataOut = "Fub\tResults\tR squared\tNegetive event costs?\tIdle\n";
	my $dataOutFiltered = $dataOut;
	my $dataIn = "Fub\tFunction";

	foreach my $test (sort keys %$testsUsed)
	{
		$dataIn .= "\t$test";
	}
	$dataIn .= "\n";

	foreach my $fub (sort keys %$regressionResults)
	{
		my $results = $$regressionResults{$fub}{"Results"};
		$results =~ s/[\r\n]+/ /g;

		if (defined $$regressionResults{$fub}{"Finished"})
		{
			my $data = "";
			my $Rsquared = $$regressionResults{$fub}{"R squared"};
			my $idle = $$regressionResults{$fub}{"Idle Cost"};
			my $negEC = (defined $$regressionResults{$fub}{"Negetive Event Costs Exist"}) ? "Yes" : "No";

			$data .= "$fub\t$results\t$Rsquared\t$negEC\t$idle";
			foreach my $event (sort keys %{$$regressionResults{$fub}{"Event Costs"}})
			{
				my $eventCost = $$regressionResults{$fub}{"Event Costs"}{$event};
				$data .= "\t$event\t$eventCost";
				$numOfTotalECs++;
				if ($negEC eq "No") {$numOfTotalNotNegativeECs++;}
			}
			$dataOut .= "$data\n";
			if ($negEC eq "No") {$dataOutFiltered .= "$data\n";}
		}
		else
		{
			$dataOut .= "$fub\t$results\n";
		}

		if (defined $$regressionResults{$fub}{"Data"})
		{
			foreach my $func (sort keys %{$$regressionResults{$fub}{"FuncDefined"}})
			{
				my $tmpActivitySum = 0;

				$dataIn .= "$fub\t$func";
				foreach my $test (sort keys %{$$regressionResults{$fub}{"Data"}})
				{
					my $activity = $$regressionResults{$fub}{"Data"}{$test}{"Functions"}{$func};
					$dataIn .= "\t$activity";
					$tmpActivitySum += $activity;
				}
				$dataIn .= "\n";
				$numOfTotalFuncs++;
				if ($tmpActivitySum>0) {$numOfTotalToggledFuncs++;}
			}
			$dataIn .= "$fub\tPower";
			foreach my $test (sort keys %{$$regressionResults{$fub}{"Data"}})
			{
				my $power = $$regressionResults{$fub}{"Data"}{$test}{"Power"};
				$dataIn .= "\t$power";
			}
			$dataIn .= "\n";
		}
		else
		{
			$dataIn .= "$fub\n";
		}
	}


#	$data = Dumper($regressionResults);

	open (OUTFILE, ">$outputFile") or die_cmd("Can't open regression output file: \"$outputFile\".\n");
	print OUTFILE "$dataOut";
	close(OUTFILE);
	print_to_log("Regression results writen into $outputFile\n");

	open (OUTFILE, ">$outputFileFiltered") or die_cmd("Can't open regression output file: \"$outputFileFiltered\".\n");
	print OUTFILE "$dataOutFiltered";
	close(OUTFILE);
	print_to_log("Regression results (filtered) writen into $outputFileFiltered\n");

	open (OUTFILE, ">$inputFile") or die_cmd("Can't open regression input file: \"$inputFile\".\n");
	print OUTFILE "$dataIn";
	close(OUTFILE);
	print_to_log("Regression inputs writen into $inputFile\n");

	print_to_log("Total functions: $numOfTotalFuncs. Total toggled functions: $numOfTotalToggledFuncs.\n");
	print_to_log("Total event costs calculated: $numOfTotalECs. Total not negative event costs: $numOfTotalNotNegativeECs.\n");

	return 1;
}
#################


################# returns a time stamp of the current time
### usage: time_stamp()
sub time_stamp
{
	my @months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
	my @weekDays = qw(Sun Mon Tue Wed Thu Fri Sat Sun);
	my ($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
	my $year = 1900 + $yearOffset;
	if ($second < 10) {$second = "0" . $second;}
	if ($minute < 10) {$minute = "0" . $minute;}
	my $theTime = "$hour:$minute:$second, $weekDays[$dayOfWeek] $months[$month] $dayOfMonth, $year";

	return $theTime;

}
#################


################# open the log file
### usage: open_log(<log file name>)
sub open_log
{
	if (@_ != 1) {return 0;}
	my $logFile = $_[0];
	open ($logFileHandler, "| gzip >$logFile.gz") or return 0;
#print $logFileHandler "Using $logFile as log file\n";
	return 1;
}
#################


################# output a message into the log file
### usage: print_to_log(<message>)
sub print_to_log
{
	my $message = "";
	if (@_ != 1) {$message = "Error in message given to print to log file!\n";}
	else {$message = $_[0];}

	if (not defined $logFileHandler)
	{
		print STDERR "using STDERR for log messages\n";
		$logFileHandler = *STDERR;
	}
	print $logFileHandler $message;

	return 1;
}
#################


################# output a message into the log file and don't output it if it appeared before
### usage: print_to_log_only_once(<message>)
sub print_to_log_only_once
{
	my $message = "";
	if (@_ != 1) {$message = "Error in message given to print to log file!\n";}
	else {$message = $_[0];}

	if (not defined($printed_to_log{$message}))
	{
		$printed_to_log{$message} = 1;
		print_to_log($message);
	}
	else
	{
		$printed_to_log{$message} += 1;
	}

	return 1;
}
#################


################# output into the log file a summary of the repeated messages (how many times each one appeared)
### usage: print_to_log_the_repeated_messages_summary()
sub print_to_log_the_repeated_messages_summary
{
	print_to_log("***************************\nSummary of the repeated messages until now:\n");
	foreach my $message (keys(%printed_to_log))
	{
		my $reps = $printed_to_log{$message};
		if ($reps > 1)
		{
			my $msg = $message;
			$msg =~ s/\n$//;
			print_to_log("This message appeared $reps times: \"$msg\"\n");
		}
		undef $printed_to_log{$message};
	}
	print_to_log("***************************\n");

	return 1;
}
#################


################# close the log file
### usage: close_log()
sub close_log
{
	close($logFileHandler);

	return 1;
}
#################


################# die after an error
sub die_cmd {
	my ($error) = @_;
		
	system "echo 'FAILED running ALPS with configuration \"${experiment}\", at directory \"${outputDir}\"' | mail -s \"ALPS failed with ${experiment} job\" \$LOGNAME";
	die $error;
}
#################


1;
