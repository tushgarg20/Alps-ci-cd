package implement_updates_to_formulas;

use diagnostics;
use strict;
use Data::Dumper;
use output_functions;
use calc_leakage;
use hierarchy;
use general_config;


################# implement updates files on top of the coho formula file
### usage: implement_updates_to_formulas_from_update_files(<the type of the updates file>, <file name to read the updates from>, <pointer to the final_hash>, <pointer to the aliases_hash>, <pointer to the baseline_hash>)
sub implement_updates_to_formulas_from_update_files
{
	if (@_ != 5) {return 0;}

	my ($updatesfiletype, $updatesFile, $final_hash, $aliases_hash, $baseline_hash) = @_;

	if (not (scalar(keys(%$baseline_hash)) > 0))   ### There is no baseline hash. Use the final hash instead.
	{
		$baseline_hash = $final_hash;
	}
#	print STDERR Dumper($baseline_hash);
	my @formulaUpdatesFiles;
	my @aliasesUpdatesFiles;
	my @lines;

	if ($updatesfiletype eq "updatesfile")
	{
		push @formulaUpdatesFiles, glob($updatesFile);
	}
	elsif ($updatesfiletype eq "updatesfilelist")
	{
		getFormulasQueues($updatesFile, \@formulaUpdatesFiles, \@aliasesUpdatesFiles);
	}
	else
	{
		output_functions::die_cmd("Error in update file type! Type not recognized.\n");
	}

	foreach my $updatesFile (@aliasesUpdatesFiles)
	{
		output_functions::print_to_log("Implementing updates from: $updatesFile\n");
		implement_updates_to_aliases($updatesFile, $final_hash, $aliases_hash, $baseline_hash);
	}
	foreach my $updatesFile (@formulaUpdatesFiles)
	{
		output_functions::print_to_log("Implementing updates from: $updatesFile\n");
		implement_updates_to_formulas($updatesFile, $final_hash, $aliases_hash, $baseline_hash);
	}

	return 1;
}
#################


################# implement an aliases update file on top of the coho aliases file
### usage: implement_updates_to_aliases(<file name to read the updates from>, <pointer to the final_hash>, <pointer to the aliases_hash>, <pointer to the baseline_hash>)
sub implement_updates_to_aliases
{
	if (@_ != 4) {return 0;}

	my ($updatesFile, $final_hash, $aliases_hash, $baseline_hash) = @_;
	my @lines;

	open (INFILE, $updatesFile) or output_functions::die_cmd("Can't find Updates formula file: \"$updatesFile\".\n");
	@lines = <INFILE>;
	close(INFILE);

	foreach my $line (@lines)	# read the aliases and implement the updates
	{
		chomp $line;
		$line =~ s/\r$//;
		$line =~ s/\#.*//;	### get rid of comments
		if ($line =~ /^\s*(\S+)\s*:\s*(\S?.*\S)\s*$/)
		{
			my $alias = $1;
			my $formula = $2;

			if (defined($$aliases_hash{$alias}))
			{
				if ($$aliases_hash{$alias} eq $formula)	### there is no change
				{
					output_functions::print_to_log("Alias exists. No need to implement the alias value for \"$alias\" as \"$formula\"\n");
				}
				else	### change the alias in the aliases array and in the final hash per function
				{
					output_functions::print_to_log("Implementing new alias value for old alias \"$alias\" as \"$formula\"\n");
					$$aliases_hash{$alias} = $formula;
					foreach my $location (keys %$final_hash)
					{
						foreach my $cluster (keys %{$$final_hash{$location}})
						{
							foreach my $unit (keys %{$$final_hash{$location}{$cluster}})
							{
								foreach my $fub (keys %{$$final_hash{$location}{$cluster}{$unit}})
								{
									if (defined($$final_hash{$location}{$cluster}{$unit}{$fub}{"Functions"}))
									{
										foreach my $function (keys %{$$final_hash{$location}{$cluster}{$unit}{$fub}{"Functions"}})
										{
											if ($$final_hash{$location}{$cluster}{$unit}{$fub}{"Functions"}{$function}{"Alias"} eq $alias)
											{
												my $oldform = $$final_hash{$location}{$cluster}{$unit}{$fub}{"Functions"}{$function}{"Formula"};
												output_functions::print_to_log("Implementing the new \"$alias\" alias for fub \"$fub.$function\". Replacing it's formula \"$oldform\" with \"$formula\"\n");
												$$final_hash{$location}{$cluster}{$unit}{$fub}{"Functions"}{$function}{"Formula"} = $formula;
											}
										}
									}
								}
							}
						}
					}
				}
			}
			else	### just add it to the aliases hash
			{
				output_functions::print_to_log("Implementing new alias value for new alias \"$alias\" as \"$formula\"\n");
				$$aliases_hash{$alias} = $formula;
			}
		}
	}
	return 1;
}
#################


################# implement an update file on top of the coho formula file
### usage: implement_updates_to_formulas(<file name to read the updates from>, <pointer to the final_hash>, <pointer to the aliases_hash>, <pointer to the baseline_hash>)
sub implement_updates_to_formulas
{
	if (@_ != 4) {return 0;}

	my ($updatesFile, $final_hash, $aliases_hash, $baseline_hash) = @_;
	my @lines;

	open (INFILE, $updatesFile) or output_functions::die_cmd("Can't find Updates formula file: \"$updatesFile\".\n");
	@lines = <INFILE>;
	close(INFILE);

	my %columnsNums;
	number_the_columns_indexes_into_a_mapping_hash(\@lines, \%columnsNums, $updatesFile);

	# Handle Power_section column if present
	if (defined $columnsNums{"Power_section"}) {
		my $cfgHash = general_config::getConfigHash();
		$$cfgHash{powerSection} = 1;
	}

	foreach my $line (@lines)	# read the formulas and implement the updates
	{
		my $location;
		my $cluster;
		my $unit;
		my $fub;
		my $Idle;
		my $Leakage;
		my $MaxPower;
		my $power_section;
		my %LeakageData=();

		chomp $line;
		$line =~ s/\r$//;
		$line =~ s/\#.*//;	### get rid of comments
		$line =~ s/\xa0//g;	### get rid of the special char
		$line =~ s/\x0d//g;	### get rid of the special char
		my @line = split(/\t/, $line);
		for (my $i = 0; $i <= scalar(@line); $i++)   ### get rid of spaces
		{
			if ((defined($line[$i])) and ($line[$i] ne ""))
			{
				$line[$i] =~ s/^\s+//;
				$line[$i] =~ s/\s+$//;
			}
		}
		$location = (defined $columnsNums{"Location"}) ? $line[$columnsNums{"Location"}] : "core";
		$cluster = $line[$columnsNums{"Cluster"}];
		$unit = $line[$columnsNums{"Unit"}];
		$fub = $line[$columnsNums{"Fub"}];

		if (general_config::getKnob ("powerSection") == 1) {
			if (defined $columnsNums{"Power_section"}) {
				$power_section = $line[$columnsNums{"Power_section"}];
			} else {
				$power_section = $fub;
			}
		}

		# Down-case all names coming from input (formula and config) files
		(defined $location) and ($location =~ tr/A-Z/a-z/);
		(defined $cluster) and ($cluster =~ tr/A-Z/a-z/);
		(defined $unit) and ($unit =~ tr/A-Z/a-z/);
		(defined $fub) and ($fub =~ tr/A-Z/a-z/);
		(defined $power_section) and ($power_section =~ tr/A-Z/a-z/);

		if (	((defined($fub)) and ($fub ne "") and ($fub !~ /^---------/)) and
				((defined($unit)) and ($unit ne "")) and
				((defined($cluster)) and ($cluster ne "")) and
				((defined($location)) and ($location ne ""))
			)
		{
			########## overrides
			if ((($unit eq "dsb") and ($cluster eq "fe")) or ($unit eq "dsbfe")) {$unit = "dsb_fe";}
			if ($location eq "core0") {$location = "core";};
			hierarchy::insert_hierarchy($fub, $unit, $cluster, $location);

			######### taking care of Idle, leakage and MaxPower
			if ((defined($columnsNums{"Idle [pF]"})) and
				(defined($line[$columnsNums{"Idle [pF]"}]))) {
				$Idle = $line[$columnsNums{"Idle [pF]"}];
			} else {
				$Idle = "";
			}

			if ((defined($columnsNums{"Leakage_Override [mW]"})) and
				(defined($line[$columnsNums{"Leakage_Override [mW]"}]))) {
				$Leakage = $line[$columnsNums{"Leakage_Override [mW]"}];
			} else {
				$Leakage = "";
			}
			$LeakageData{"Leakage_Override [mW]"} = $Leakage;
			$MaxPower = "";

			my $designType = "";

			if (defined($columnsNums{"Design_Type"}) and
				defined($line[$columnsNums{"Design_Type"}]) ) {
				$designType = $line[$columnsNums{"Design_Type"}];
			}
			$designType =~ tr/a-z/A-Z/;

			if ($designType ne "") {
				calc_leakage::getDesignParameters(1266,$designType,\%LeakageData);
			}
			$LeakageData{"Design_Type"} = $designType;

			my %header_names_mapping_to_data_index = (
																		"Z_Total" => "zTotal",
																		"%LL" => "llPr",
																		"%UVT" => "uvtPr",
																		"%LLUVT" => "lluvtPr",
																		"PN_ratio" => "pnRatio",
																		"Subthreshold_Stack_Factor" => "subthresholdStackFactor",
																		"Gate_Stack_Factor" => "gateStackFactor",
																		"Junction_Stack_Factor" => "junctionStackFactor"
																	);
			foreach my $header (keys %header_names_mapping_to_data_index)
			{
				my $data_index = $header_names_mapping_to_data_index{$header};

				if (defined($columnsNums{$header}) and
					defined($line[$columnsNums{$header}]) and
					($line[$columnsNums{$header}] ne "")) {
					$LeakageData{$data_index} = $line[$columnsNums{$header}];
				} elsif ($designType eq "") {
					$LeakageData{$data_index}="";
				}
			}
			
			if ((defined $LeakageData{"llPr"}) and
				($LeakageData{"llPr"} =~ /\d/) and
				($LeakageData{"llPr"} > 1)) {
				output_functions::print_to_log("Error: LL percentage is higher than 1 at $fub. Dividing it by 100!\n");
				$LeakageData{"llPr"} /= 100;
			}

			my %tmp_hash;
			$tmp_hash{"Idle"} = $Idle;
			$tmp_hash{"Leakage"} = $Leakage;
			$tmp_hash{"MaxPower"} = $MaxPower;
			$tmp_hash{"LeakageData"} = \%LeakageData;

			foreach my $element (keys %tmp_hash)
			{
				if($element eq "LeakageData")
				{
 					foreach my $leakageElement (keys %{$tmp_hash{"LeakageData"}})
					{
						$tmp_hash{"LeakageData"}{$leakageElement} =~ s/^\s*[\*\/\+\-]\s*$//;   ### fix multipliers that don't have value
#						$tmp_hash{"LeakageData"}{$leakageElement} =~ s/([\w+\.]+\.power)/{evaluate_stat($1,$baseline_hash);}/eg;
						if ($tmp_hash{"LeakageData"}{$leakageElement} =~ /^\d+\.?\d*$/) {$tmp_hash{"LeakageData"}{$leakageElement} = eval($tmp_hash{"LeakageData"}{$leakageElement});}
						my $tmp_eval_return_val = $@;
						if (not (defined($tmp_hash{"LeakageData"}{$leakageElement}))) {$tmp_hash{"LeakageData"}{$leakageElement} = "";}

						if (not (($tmp_hash{"LeakageData"}{$leakageElement} eq "") or ($tmp_hash{"LeakageData"}{$leakageElement} =~ /^\s*$/)))
						{
							if ($tmp_hash{"LeakageData"}{$leakageElement} =~ /^\s*[\*\/\+\-]\s*\S+/) ### This is a multiplier/addition on top of existing
							{
								if (not defined $$final_hash{$location}{$cluster}{$unit}{$fub}{"LeakageData"}{$leakageElement})
								{
									output_functions::print_to_log("Error! Update tried to multiply the $leakageElement value for $fub by $tmp_hash{'LeakageData'}{$leakageElement}. But $leakageElement doesn't exist\n UPDATE NOT IMPLEMENTED! Using 0 to initialize the value.\n");
									$$final_hash{$location}{$cluster}{$unit}{$fub}{"LeakageData"}{$leakageElement} = "";
								}
								else
								{
									$$final_hash{$location}{$cluster}{$unit}{$fub}{"LeakageData"}{$leakageElement} = "\( ".$$final_hash{$location}{$cluster}{$unit}{$fub}{"LeakageData"}{$leakageElement}." \) ".$tmp_hash{"LeakageData"}{$leakageElement};
									output_functions::print_to_log("Multiplying/adding the $leakageElement value for $fub by $tmp_hash{'LeakageData'}{$leakageElement}\n");
								}
							}
							else ### This is not a multiplier
							{
								if (not defined $$final_hash{$location}{$cluster}{$unit}{$fub}{"LeakageData"}{$leakageElement}) ### This is a new value
								{
									output_functions::print_to_log("Implementing new $leakageElement value for $fub as $tmp_hash{'LeakageData'}{$leakageElement}\n");
									$$final_hash{$location}{$cluster}{$unit}{$fub}{"LeakageData"}{$leakageElement} = $tmp_hash{"LeakageData"}{$leakageElement};
								}
								elsif($$final_hash{$location}{$cluster}{$unit}{$fub}{"LeakageData"}{$leakageElement} ne $tmp_hash{"LeakageData"}{$leakageElement}) ### This is a new value instead of existing
								{
									output_functions::print_to_log("Replacing the $leakageElement value \"$$final_hash{$location}{$cluster}{$unit}{$fub}{'LeakageData'}{$leakageElement}\" for $fub with \"$tmp_hash{'LeakageData'}{$leakageElement}\"\n");
									$$final_hash{$location}{$cluster}{$unit}{$fub}{"LeakageData"}{$leakageElement} = $tmp_hash{"LeakageData"}{$leakageElement};
								}
							}
						}
						elsif (not defined $$final_hash{$location}{$cluster}{$unit}{$fub}{"LeakageData"}{$leakageElement}) ### This is a new fub, need to initialize the element's value
						{
							$$final_hash{$location}{$cluster}{$unit}{$fub}{"LeakageData"}{$leakageElement} = "";
						}
					}
				}
				else ### Element is different from "LeakageData"
				{

					$tmp_hash{$element} =~ s/^\s*[\*\/\+\-]\s*$//;   ### fix multipliers that don't have value
					$tmp_hash{$element} =~ s/([\w+\.]+\.power)/{evaluate_stat($1,$baseline_hash);}/eg;
					if ($tmp_hash{$element} =~ /^\d+\.?\d*$/) {$tmp_hash{$element} = eval($tmp_hash{$element});}
					my $tmp_eval_return_val = $@;
					if (not (defined($tmp_hash{$element}))) {$tmp_hash{$element} = "";}
					if (not (($tmp_hash{$element} eq "") or ($tmp_hash{$element} =~ /^\s*$/)))
					{
						if ($tmp_hash{$element} =~ /^\s*[\*\/\+\-]\s*\S+/) ### This is a multiplier/addition on top of existing
						{
							if (not defined $$final_hash{$location}{$cluster}{$unit}{$fub}{$element})
							{
								output_functions::print_to_log("Error! Update tried to multiply the $element value for $fub by $tmp_hash{$element}. But $element doesn't exist\n UPDATE NOT IMPLEMENTED! Using 0 to initialize the value.\n");
								$$final_hash{$location}{$cluster}{$unit}{$fub}{$element} = 0;
							}
							else
							{
								$$final_hash{$location}{$cluster}{$unit}{$fub}{$element} = "\( ".$$final_hash{$location}{$cluster}{$unit}{$fub}{$element}." \) ".$tmp_hash{$element};
								output_functions::print_to_log("Multiplying/adding the $element value for $fub by $tmp_hash{$element}\n");
							}
						}
						else ### This is not a multiplier
						{
							if (not defined $$final_hash{$location}{$cluster}{$unit}{$fub}{$element}) ### This is a new value
							{
								output_functions::print_to_log("Implementing new $element value for $fub as $tmp_hash{$element}\n");
								$$final_hash{$location}{$cluster}{$unit}{$fub}{$element} = $tmp_hash{$element};
							}
							elsif ($$final_hash{$location}{$cluster}{$unit}{$fub}{$element} ne $tmp_hash{$element}) ### This is a new value instead of existing
							{
								output_functions::print_to_log("Replacing the $element value \"$$final_hash{$location}{$cluster}{$unit}{$fub}{$element}\" for $fub with \"$tmp_hash{$element}\"\n");
								$$final_hash{$location}{$cluster}{$unit}{$fub}{$element} = $tmp_hash{$element};
							}
						}
					}
					elsif (not defined $$final_hash{$location}{$cluster}{$unit}{$fub}{$element}) ### This is a new fub, need to initialize the element's value
					{
						$$final_hash{$location}{$cluster}{$unit}{$fub}{$element} = 0;
					}
				}
			}
			#########

			######### taking care of active power and functions
			if ((defined($columnsNums{"Function"})) and (not defined($columnsNums{"Function1"}))) {$columnsNums{"Function1"} = $columnsNums{"Function"};}
			if ((defined($columnsNums{"EC"})) and (not defined($columnsNums{"EC1"}))) {$columnsNums{"EC1"} = $columnsNums{"EC"};}
			if ((defined($columnsNums{"Formula"})) and (not defined($columnsNums{"Formula1"}))) {$columnsNums{"Formula1"} = $columnsNums{"Formula"};}
			my $i = 1;
			while (defined($columnsNums{"Function$i"}) and defined($line[$columnsNums{"Function$i"}]) and ($line[$columnsNums{"Function$i"}] ne ""))
			{
#				if ($line[$columnsNums{"Function$i"}] ne "")
#				{
					my $alias = "";
					my $formula = "";
					my $power = "";
					my $function = $line[$columnsNums{"Function$i"}];
					my $comment = "";

					if (defined($columnsNums{"Formula Alias$i"}) and
						defined($line[$columnsNums{"Formula Alias$i"}]) and
						($line[$columnsNums{"Formula Alias$i"}] ne ""))
					{
						$alias = $line[$columnsNums{"Formula Alias$i"}];
					}
					if (defined($columnsNums{"Formula$i"}) and
						defined($line[$columnsNums{"Formula$i"}]) and
						($line[$columnsNums{"Formula$i"}] ne ""))
					{
						$formula = $line[$columnsNums{"Formula$i"}];
					}
					if ((defined($columnsNums{"Power$i"})) and
						(defined($line[$columnsNums{"Power$i"}])) and
						($line[$columnsNums{"Power$i"}] ne ""))
					{
						$power = $line[$columnsNums{"Power$i"}];
					}
					elsif ((defined($columnsNums{"Capacitance$i [pF]"})) and
						   (defined($line[$columnsNums{"Capacitance$i [pF]"}])) and
						   ($line[$columnsNums{"Capacitance$i [pF]"}] ne ""))
					{
						$power = $line[$columnsNums{"Capacitance$i [pF]"}];
					}
					elsif ((defined($columnsNums{"EC$i"})) and
						   (defined($line[$columnsNums{"EC$i"}])) and
						   ($line[$columnsNums{"EC$i"}] ne ""))
					{
						$power = $line[$columnsNums{"EC$i"}];
					}

					$power =~ s/([\w+\.]+\.power)/{evaluate_stat($1,$baseline_hash);}/eg;

					if (defined($columnsNums{"Comment"}) and defined($line[$columnsNums{"Comment"}]) and ($line[$columnsNums{"Comment"}] ne ""))
					{
						$comment = $line[$columnsNums{"Comment"}];
					}

					if (not (($alias =~ /^\s*$/) or ($alias eq "") or ($alias =~ /^\s*[\*\/\+\-]/)))   ### update the alias for the output formula file
					{
						if ($formula ne "")
						{
							if (defined($$aliases_hash{$alias}))
							{
								if ($$aliases_hash{$alias} ne $formula)
								{
	#								output_functions::print_to_log("Error! Alias for fub \"$fub.$function\" does not match it's formula!\n  Ignoring the alias, only implementing the new formula for this fub.\n  If you wish to update this alias, do so using the aliases updates files\n");
									$alias = "";
								}
							}
							else
							{
								$$aliases_hash{$alias} = $formula;
							}
						}
					}

					my $lowercaseFunction = $function;
					$lowercaseFunction =~ tr/A-Z/a-z/;
					if ($lowercaseFunction eq "idle")
					{
						my $element = "Idle";
						if (not defined $$final_hash{$location}{$cluster}{$unit}{$fub}{$element}) ### This is a new value
						{
							output_functions::print_to_log("Implementing new $element value for $fub as $power\n");
							$$final_hash{$location}{$cluster}{$unit}{$fub}{$element} = $power;
						}
						elsif ($$final_hash{$location}{$cluster}{$unit}{$fub}{$element} ne $power) ### This is a new value instead of existing
						{
							output_functions::print_to_log("Replacing the $element value \"$$final_hash{$location}{$cluster}{$unit}{$fub}{$element}\" for $fub with \"$power\"\n");
							$$final_hash{$location}{$cluster}{$unit}{$fub}{$element} = $power;
						}
						if ($comment ne "")
						{
							$$final_hash{$location}{$cluster}{$unit}{$fub}{"Idle_comment"} = $comment;
						}
					}
					else
					{
						my %tmp_hash;
						$tmp_hash{"Alias"} = $alias;
						$tmp_hash{"Formula"} = $formula;
						$tmp_hash{"Power"} = $power;
						$tmp_hash{"Comment"} = $comment;

						foreach my $element (keys %tmp_hash)
						{
							if (not (($tmp_hash{$element} =~ /^\s*$/) or ($tmp_hash{$element} eq "")))
							{
								if ($element eq "Comment")
								{
									$$final_hash{$location}{$cluster}{$unit}{$fub}{"Functions"}{$function}{$element} = $tmp_hash{$element};
								}
								elsif ($tmp_hash{$element} =~ /^\s*[\*\/\+\-]/) ### This is a multiplier/addition on top of existing
								{
									if (($element eq "Formula") or ($element eq "Alias"))
									{
										output_functions::print_to_log("Error! Update tried to multiply a $element for $fub by $tmp_hash{$element}\n UPDATE NOT IMPLEMENTED!\n");
									}
									elsif (not defined $$final_hash{$location}{$cluster}{$unit}{$fub}{"Functions"}{$function}{$element})
									{
										output_functions::print_to_log("Error! Update tried to multiply the $element value for $fub.$function by $tmp_hash{$element}. But $element doesn't exist\n UPDATE NOT IMPLEMENTED! Using 0 instead.\n");
										$$final_hash{$location}{$cluster}{$unit}{$fub}{"Functions"}{$function}{$element} = 0;
									}
									else
									{
										$$final_hash{$location}{$cluster}{$unit}{$fub}{"Functions"}{$function}{$element} = "\( ".$$final_hash{$location}{$cluster}{$unit}{$fub}{"Functions"}{$function}{$element}." \) ".$tmp_hash{$element};
										output_functions::print_to_log("Multiplying/adding the $element value for $fub.$function by $tmp_hash{$element}\n");
									}
								}
								else ### This is not a multiplier
								{
									if (not defined $$final_hash{$location}{$cluster}{$unit}{$fub}{"Functions"}{$function}{$element}) ### This is a new value
									{
										$$final_hash{$location}{$cluster}{$unit}{$fub}{"Functions"}{$function}{$element} = $tmp_hash{$element};
										output_functions::print_to_log("Implementing new $element value for $fub.$function as $tmp_hash{$element}\n");
									}
									elsif ($$final_hash{$location}{$cluster}{$unit}{$fub}{"Functions"}{$function}{$element} ne $tmp_hash{$element}) ### This is a new value instead of existing
									{
										$$final_hash{$location}{$cluster}{$unit}{$fub}{"Functions"}{$function}{$element} = $tmp_hash{$element};
										output_functions::print_to_log("Replacing the $element value for $fub.$function with $tmp_hash{$element}\n");
									}
								}
							}
							elsif (not defined $$final_hash{$location}{$cluster}{$unit}{$fub}{"Functions"}{$function}{$element}) ### Need to initialize the element's value
							{
								$$final_hash{$location}{$cluster}{$unit}{$fub}{"Functions"}{$function}{$element} = "";
							}
						}
					}

					# Set power_section field if present
					if (general_config::getKnob ("powerSection") == 1) {
						if (exists $$final_hash{$location}{$cluster}{$unit}{$fub}{"Power_section"}) {
							if ($$final_hash{$location}{$cluster}{$unit}{$fub}{"Power_section"} ne $power_section) {
								output_functions::print_to_log("Error: Power_section has conflicting values for fub $fub: \"$power_section\" vs. \"$$final_hash{$location}{$cluster}{$unit}{$fub}{'Power_section'}\"\n");
							}
						} else {
							$$final_hash{$location}{$cluster}{$unit}{$fub}{"Power_section"} = $power_section;
						}
					}

#				}

					$i++;
			}
			##########
		}
	}
	return 1;
}
#################


################# number_the_columns_indexes_into_a_mapping_hash
sub number_the_columns_indexes_into_a_mapping_hash
{
	if (@_ != 3) {return 0;}

	my ($lines, $columnsNums, $updatesFile) = @_;
	my @columns;

	while ((scalar(@$lines) > 0) and (scalar(@columns) == 0))	# find the header row
	{
		my $line = shift @$lines;
		chomp $line;
		$line =~ s/\r$//;
		$line =~ s/\#.*//;	### get rid of comments
		$line =~ s/\xa0//g;	### get rid of the special char
		$line =~ s/\x0d//g;	### get rid of the special char
		if ($line =~ /^Fub\t/)
		{
			@columns = split(/\t/, $line);

			my %headers_mapping = (
											"leakage" => "Leakage_Override [mW]",
											"idle" => "Idle [pF]",
											"z_total (um)" => "Z_Total",
											"des_type" => "Design_Type",
											"des_typ" => "Design_Type",
											"sd_sf" => "Subthreshold_Stack_Factor",
											"g_sf" => "Gate_Stack_Factor",
											"j_sf" => "Junction_Stack_Factor",
											"leak_ovr" => "Leakage_Override [mW]",
											"unit" => "Unit",
											"cluster" => "Cluster"
											);

			for (my $i = 0; $i < scalar(@columns); $i++)
			{
				my $col = $columns[$i];
				my $col_lowercase = $col;
				$col_lowercase =~ tr/A-Z/a-z/;
				if (defined $headers_mapping{$col_lowercase}) {
					$col = $headers_mapping{$col_lowercase};
				}
				$$columnsNums{$col} = $i;
			}
		}
	}
	if (scalar(@columns) == 0) {
		output_functions::die_cmd("Can't find header row in updates formula file $updatesFile!\n");
	}
	if ((!defined $$columnsNums{"Cluster"}) or
		(!defined $$columnsNums{"Unit"}) or
		(!defined $$columnsNums{"Fub"})) # or (!defined $columnsNums{"Location"}))
	{
		die ("Error in updates file: can't find hierarchy info.\n");
	}

	return 1;
}
#################


################# get all the formula files names into queues to implement
### usage: getFormulasQueues(<file name to read the formulas list from>, <\@formulaFiles queue>, <\@aliasesFiles queue>)
sub getFormulasQueues
{
	if (@_ != 3) {return 0;}

	my ($listFile, $formulaFiles, $aliasesFiles) = @_;
	my @lines;
	my $formulas_path = "";
	my $formulas_path2 = "";

	output_functions::print_to_log("Implementing updates from: $listFile\n");
	if ($listFile =~ /(.+)\/formulas\/\w+\/formulas\//)
	{
		$formulas_path = $1;
	}
	else
	{
		output_functions::print_to_log("Warning: can't find the formulas root for: $listFile. If it has links to \$ALPS_DIR\$ then they won't be found!\nIgnore this warnning if not using any ALPS_DIR links in formula file.\n");
	}

	if ($listFile =~ /(.+)\//)
	{
		$formulas_path2 = $1;
	}

	open (INFILE, glob($listFile)) or output_functions::die_cmd("Can't find Updates formula file: \"$listFile\".\n");
	@lines = <INFILE>;
	close(INFILE);

	$formulas_path = glob($formulas_path);
	$formulas_path2 = glob($formulas_path2);
	foreach my $line (@lines)
	{
		chomp $line;
		$line =~ s/\r$//;
		$line =~ s/\#.*//;	### get rid of comments
### ALPS_DIR doesn't exist anymore. Make sure to use the "RealBin" parameter incase this syntax is used again.
#		$line =~ s/\$ALPS_DIR\$/$ENV{"ALPS_DIR"}/g;

#		if (($line !~ /\$ALPS_DIR\$/) and ($line !~ /^\//) and ($formulas_path2 ne ""))
#		{
#			$line = $formulas_path2 . "/" . $line;
#		}
		my $dont_change_path = 0;
		if (($line =~ /\$ALPS_DIR\$/) or ($line =~ /\$\(CDIR\)/)) {$dont_change_path = 1;}
		$line =~ s/\$ALPS_DIR\$/$formulas_path/g;
		$line =~ s/\$\(CDIR\)/$formulas_path2/g;

		if ($line =~ /-a\s+(\S.*\S)/)
		{
			my $file = $1;
			if (($dont_change_path eq 0) and ($formulas_path2 ne "")) {$file = $formulas_path2 . "/" . $file;}
			push @$aliasesFiles, $file;
		}
		elsif ($line =~ /-l\s+(\S.*\S)/)
		{
			my $file = $1;
			if (($dont_change_path eq 0) and ($formulas_path2 ne "")) {$file = $formulas_path2 . "/" . $file;}
			getFormulasQueues($file, $formulaFiles, $aliasesFiles);
		}
		elsif (($line =~ /-f\s+(\S.*\S)/) or
			   (($line =~ /^(\S.*\S)/) and ($line !~ /^[\/~]/)))
		{
			my $file = $1;
			if (($dont_change_path eq 0) and ($formulas_path2 ne "")) {$file = $formulas_path2 . "/" . $file;}
			push @$formulaFiles, $file;
		}
		elsif ($line =~ /^([\/~]\S+)/)
		{
			# Absolute path provided
			my $file = $1;
			push @$formulaFiles, $file;
		}
		elsif ($line ne "")
		{
			output_functions::print_to_log("Error reading this line in the updates list file:\"$line\"\n");
		}
	}

	return 1;
}
#################


################# evaluate a statistic using "$final_hash"
sub evaluate_stat
{
	my $params = $_[0];
	if (@_ == 2)
	{
		my ($stat, $final_hash) = @_;

		if ($stat =~ /^(uncore\d|p\d\.c\d)\.(\w+)\.(\w+)\.(\w+)\.(\w+)\.power$/)
		{
			my $location = $1;
			my $cluster = $2;
			my $unit = $3;
			my $fub = $4;
			my $index = $5;
			if ($location =~ /^p\d/) {$location = "core";}
			elsif ($location =~ /uncore/) {$location = "uncore";}
			else {$location = "none";}
			if (($index eq "Idle") or ($index eq "Leakage") or ($index eq "MaxPower"))
			{
				if (defined($$final_hash{$location}{$cluster}{$unit}{$fub}{$index}))
				{
					return $$final_hash{$location}{$cluster}{$unit}{$fub}{$index};
				}
			}
			else
			{
				if (defined($$final_hash{$location}{$cluster}{$unit}{$fub}{"Functions"}{$index}{"Power"}))
				{
					return $$final_hash{$location}{$cluster}{$unit}{$fub}{"Functions"}{$index}{"Power"};
				}
			}
		}
	}
	else
	{
		output_functions::print_to_log("Error! Bad parameters to function evaluate_stat!\nError evaluating statistic \"$params\"! using 0.\n");
	}
	output_functions::print_to_log("Error evaluating statistic \"$params\"! using 0.\n");
	return 0;
}
#################


1;
