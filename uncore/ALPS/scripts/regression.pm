package regression;

use diagnostics;
use strict;
use Data::Dumper;
use output_functions;


################# perform regression
### usage: regression_run(<experiment name>, <power file name>, <name mapping file name>, <functions activity hash>, <output dir>, <original formulas hash>, <final formula hash>)
sub regression_run
{
	if (@_ != 7) {return 0;}
	
	my ($experiment, $powerFile, $mappingFile, $funcActivity, $outputDir, $originalFinalHash, $finalHash) = @_;

	my %powerHash;
	my %newFuncActivity;
	my %mapping;
	my %regressionResults;
	my %testsUsed;
	my $numOfSuccessRegs = 0;
	my $numOfNegetiveRegs = 0;

	read_power_values($powerFile,\%powerHash);

	if ($mappingFile ne "")
	{
		if (map_activity_to_new_fub_names($mappingFile, \%mapping, $funcActivity, \%newFuncActivity) == 1)
		{
			$funcActivity = \%newFuncActivity;
		}
	}
	foreach my $fub (sort keys %powerHash)
	{
		if (fub_regression_run($fub, $funcActivity, \%powerHash, \%regressionResults, \%testsUsed, $outputDir))
		{
			output_functions::print_to_log("Successfuly regressed the fub $fub.");
			$numOfSuccessRegs++;
			if (defined $regressionResults{$fub}{"Negetive Event Costs Exist"})
			{
				output_functions::print_to_log(" But, some functions got negetive event costs!");
				$numOfNegetiveRegs++;
			}
			output_functions::print_to_log("\n");
		}
	}

	output_functions::print_to_log("Successfuly regressed $numOfSuccessRegs fubs, out of which " . ($numOfSuccessRegs-$numOfNegetiveRegs) . " fubs did not have negetive event costs.\n");
	output_functions::output_regression($experiment, \%regressionResults, \%testsUsed, $outputDir);

	foreach my $fub (sort keys %regressionResults)	### put the regression energy costs into the finalHash
	{
		if (defined $regressionResults{$fub}{"Finished"})
		{
			my $Rsquared = $regressionResults{$fub}{"R squared"};
			my $idle = $regressionResults{$fub}{"Idle Cost"};
			my $negEC = (defined $regressionResults{$fub}{"Negetive Event Costs Exist"}) ? "Yes" : "No";

			$$finalHash{"core"}{"cluster"}{"unit"}{$fub}{"Idle"} = $idle;
			$$finalHash{"core"}{"cluster"}{"unit"}{$fub}{"Leakage"} = 0;
			foreach my $event (sort keys %{$regressionResults{$fub}{"Event Costs"}})	### put the event costs in
			{
				my $eventCost = $regressionResults{$fub}{"Event Costs"}{$event};
				$$finalHash{"core"}{"cluster"}{"unit"}{$fub}{"Functions"}{$event}{"Power"} = $eventCost;
			}
			
			foreach my $location (keys %$originalFinalHash)	### put the formulas in
			{
				foreach my $cluster (keys %{$$originalFinalHash{$location}})
				{
					foreach my $unit (keys %{$$originalFinalHash{$location}{$cluster}})
					{
						foreach my $originalfub (keys %{$$originalFinalHash{$location}{$cluster}{$unit}})
						{
							foreach my $element (keys %{$$originalFinalHash{$location}{$cluster}{$unit}{$originalfub}})
							{
								if ($element eq "Functions")
								{
									foreach my $function (keys %{$$originalFinalHash{$location}{$cluster}{$unit}{$originalfub}{"Functions"}})
									{
										if ((defined $$finalHash{"core"}{"cluster"}{"unit"}{$mapping{$originalfub}}) and (defined $$finalHash{"core"}{"cluster"}{"unit"}{$mapping{$originalfub}}{"Functions"}{$function}))
										{
											$$finalHash{"core"}{"cluster"}{"unit"}{$mapping{$originalfub}}{"Functions"}{$function}{"Formula"} = $$originalFinalHash{$location}{$cluster}{$unit}{$originalfub}{"Functions"}{$function}{"Formula"};
										}
									}
								}
							}
						}
					}
				}
			}

		}
	}
#print STDERR Dumper($finalHash);
	return 1;
}
#################


################# read the power per fub per test from a file
### usage: read_power_values(<power file name>, <pointer to a power hash>)
sub read_power_values
{
	if (@_ != 2) {return 0;}
	
	my ($powerFile, $power_hash) = @_;

	if ($powerFile ne "")	# read the power file into a hash
	{
		my @lines;

		open (INFILE, $powerFile) or output_functions::die_cmd("Can't find power file: \"$powerFile\".\n");
		@lines = <INFILE>;
		close(INFILE);

		my @columns;
		my $line = "";

		while ((scalar(@lines) > 0) and (scalar(@columns) == 0))	# find the header row
		{
			$line = shift @lines;
			chomp $line;
			$line =~ s/\r$//;
			if ($line =~ /^Block name\t/)
			{
				@columns = split(/\t/, $line);
				shift @columns;
			}
		}
		if (scalar(@columns) == 0) {output_functions::die_cmd("Can't find header row in regression power file $powerFile!\n");}

		foreach my $line (@lines)
		{
			chomp $line;
			$line =~ s/\r$//;
			my @line = split(/\t/, $line);
			my $fub = shift @line;
			if ((defined $fub) and ($fub ne ""))
			{
				for (my $i = 0; $i < scalar(@line); $i++)
				{
					$$power_hash{$fub}{$columns[$i]} = $line[$i];
				}
			}
		}

		return 1;
	}

	return 0;
}
#################


################# perform regression on one fub
### usage: fub_regression_run(<fub name>, <functions activity hash of fub>, <power hash of fub>, <pointer to results hash>, <pointer to the testsUsed hash>, <output dir>)
sub fub_regression_run
{
	if (@_ != 6) {return 0;}
	
	my ($fub, $funcActivity, $powerHash, $results, $testsUsed, $outputDir) = @_;
	my $tmpOutputFile = "${outputDir}regression_tmp_file.txt";
	my $data;
	my @lines;
	my $mprCommand = "/nfs/iil/proj/mpgarch/proj_work_01/jhillel_work/statistics/linear_regression/tools/final_scripts/mpr -s";		

	if ((defined $$funcActivity{$fub}) and (defined $$powerHash{$fub}))
	{
		my $firstTest = 1;
		my $totalNumFuncs = 0;
		my $totalNumTests = 0;
		foreach my $test (sort keys(%{$$funcActivity{$fub}}))
		{
			if (defined $$powerHash{$fub}{$test})
			{
				my $numFuncs = 0;
				foreach my $func (sort keys(%{$$funcActivity{$fub}{$test}}))
				{
					if ($$funcActivity{$fub}{"Max activity"}{$func} > 0)	### The regression can't work on 0 activity functions in all tests -> so I'm taking them out
					{
						$data .= $$funcActivity{$fub}{$test}{$func} . "\t";
						$$results{$fub}{"FuncUsed"}{$func} = 1;
					}
					else
					{
						$$results{$fub}{"FuncSkipped"}{$func} = 1;
					}
					$$results{$fub}{"Data"}{$test}{"Functions"}{$func} = $$funcActivity{$fub}{$test}{$func};
					if ($firstTest)
					{
						$$results{$fub}{"FuncDefined"}{$func} = 1;
						$totalNumFuncs++;
					}
					elsif (not defined($$results{$fub}{"FuncDefined"}{$func}))
					{
						output_functions::print_to_log("Error regressing the fub $fub. Function $func is missing value in some tests!\n");
						return 0;
					}
					$numFuncs++;
				}
				$data .= $$powerHash{$fub}{$test} . "\n";
				$$results{$fub}{"Data"}{$test}{"Power"} = $$powerHash{$fub}{$test};
				$firstTest = 0;
				if ($numFuncs<$totalNumFuncs)
				{
					output_functions::print_to_log("Error regressing the fub $fub. Some functions are missing values in some tests!\n");
					return 0;
				}
				$totalNumTests++;
				$$testsUsed{$test} = 1;
			}
		}
		if ($totalNumTests==0)
		{
			output_functions::print_to_log("Error regressing the fub $fub. No test has both activity and power for it!\n");
			return 0;
		}
		if (not defined %{$$results{$fub}{"FuncUsed"}})
		{
			output_functions::print_to_log("Error regressing the fub $fub. Activity data is missing!\n");
			$$results{$fub}{"Results"} = "Error regressing the fub $fub. Activity data is missing!";
			return 0;
		}

		### Here I will run the regression
		open (OUTFILE, ">$tmpOutputFile") or output_functions::die_cmd("Can't open regression temporary output file: \"$tmpOutputFile\".\n");
		print OUTFILE "$data";
		close(OUTFILE);

		open (REGFILE, "$mprCommand $tmpOutputFile 2>&1 |") or output_functions::die_cmd("Can't run regression using the commandline: \"$mprCommand $tmpOutputFile\".\n");
		@lines = <REGFILE>;
		close(REGFILE);
		system("rm $tmpOutputFile");

		$data = "";
		foreach my $line (@lines)
		{
			$data .= $line . "\n";
		}
		$$results{$fub}{"Results"} = $data;

		if (parse_results(\@lines, \%{$$results{$fub}}) == 0)
		{
			output_functions::print_to_log("Error regressing the fub $fub. Regression didn't succeed!\n");
			return 0;
		}
		else
		{
			return 1;
		}
	}
	else
	{
		if (!defined $$funcActivity{$fub})
		{
			output_functions::print_to_log("Error regressing the fub $fub. Activity data is missing!\n");
		}
		if (!defined $$powerHash{$fub})
		{
			output_functions::print_to_log("Error regressing the fub $fub. Power data is missing!\n");
		}
	}

	return 0;
}
#################


################# read fub mapping and create new activity factors hash according to "new names"
### usage: map_activity_to_new_fub_names(<mapping file name>, <mapping hash>, <functions activity hash>, <pointer to new activity hash>)
sub map_activity_to_new_fub_names
{
	if (@_ != 4) {return 0;}
	
	my ($mappingFile, $mapping, $funcActivity, $newFuncActivity) = @_;
	my @lines;
#	my %mapping;
	my %commonBlocks;

	open (INFILE, $mappingFile) or output_functions::die_cmd("Can't find mapping file: \"$mappingFile\".\n");
	@lines = <INFILE>;
	close(INFILE);

	foreach my $line (@lines)
	{
		chomp $line;
		$line =~ s/\r$//;
		if ($line =~ /^(\S+)\t\S*\t\S*\t(\S+)$/)
		{
			$$mapping{$1} = $2;
			$commonBlocks{$2} = 1;
		}
	}
	if (scalar(keys %$mapping) == 0) {output_functions::die_cmd("Can't find mapping data in file $mappingFile!\n");}
	output_functions::print_to_log((scalar(keys %commonBlocks)) . " common blocks counted in NHM mapping.\n");

	foreach my $fub (sort keys %$funcActivity)
	{
		if (!defined $$mapping{$fub})
		{
			output_functions::print_to_log("Error in regression of fub $fub. Mapping of \"common blocks\" for this fub is missing! Using its original naming.\n");
			$$mapping{$fub} = $fub;
		}
		foreach my $file (keys %{$$funcActivity{$fub}})
		{
			foreach my $function (keys %{$$funcActivity{$fub}{$file}})
			{
				if ((defined $$newFuncActivity{$$mapping{$fub}}{$file}{$function}) and ($$newFuncActivity{$$mapping{$fub}}{$file}{$function} ne $$funcActivity{$fub}{$file}{$function}))
				{
					output_functions::print_to_log("Error in regression of fub $fub. Function $function is overwritten due to the \"common blocks\" mapping!\n");
				}
				$$newFuncActivity{$$mapping{$fub}}{$file}{$function} = $$funcActivity{$fub}{$file}{$function};
			}
		}
	}

	return 1;
}
#################


################# parse the results of the regression of the fub
### usage: parse_results(<pointer to the regression output>, <results hash>)
sub parse_results
{
	if (@_ != 2) {return 0;}
	
	my ($lines, $results) = @_;

	my @eventCosts;
	
#print STDERR Dumper(\$lines);

	my $equation = join (" ", @$lines);
	$equation =~ s/\r//g;
	$equation =~ s/\n//g;
#print STDERR $equation . "\n";
	if ($equation =~ /y\s*=\s*(.+)sum of squared errors/)	### get the event costs from the formula
	{
		$equation = $1;
		my $equation = $1;
#print STDERR $equation. "\n";
		$equation =~ s/\s+/ /g;
#print STDERR $equation. "\n";
		$equation =~ s/^\s+//;
		$equation =~ s/\s+$//;
#print STDERR $equation. "\n";
		my @tmpcosts = split(" ", $equation);
		my $x = 1;
		foreach my $func (sort keys %{$$results{"FuncUsed"}})
		{
			if ((scalar(@tmpcosts)>1) and (($tmpcosts[1] =~ /x_${x}/) or (($tmpcosts[1] =~ /x$/) and (scalar(keys %{$$results{"FuncUsed"}}) == 1))))
			{
				$$results{"Event Costs"}{$func} = shift(@tmpcosts);
				shift(@tmpcosts);
				if ($$results{"Event Costs"}{$func} < 0)
				{
					$$results{"Negetive Event Costs Exist"} = 1;
				}
			}
			else
			{
				$$results{"Event Costs"}{$func} = 0;
			}
			$x++;
		}
		if (scalar(@tmpcosts) == 1)
		{
			$$results{"Idle Cost"} = shift(@tmpcosts);
			if ($$results{"Idle Cost"} < 0)
			{
				$$results{"Negetive Event Costs Exist"} = 1;
			}
			$$results{"Finished"} = 1;
		}
	}
	
	foreach my $line (@$lines)
	{
		chomp $line;
		$line =~ s/\r$//;
#print STDERR $line. "\n";
		if ($line =~ /^R squared: (.+)/)
		{
			$$results{"R squared"} = $1;
		}
#		elsif ($line =~ /regression failed (equation system unsolvable)/)
#		{
#			return 0;
#		}
	}
	if (defined $$results{"Finished"})
	{
		return 1;
	}

	return 0;
}
#################

#print STDERR Dumper(\%powerHash);

1;
