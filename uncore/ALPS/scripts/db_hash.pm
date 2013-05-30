package db_hash;

use diagnostics;
use strict;
use warnings;
use Data::Dumper;

use general;
use output_functions;


### the following function might be deleted. It should be edited to use the parameters as described

################# read the formulas from an excel file (txt tab delimited) into final_hash
### usage: read_formulas_from_excel_into_finalHash(<formula file name>, <pointer to the final_hash>, <pointer to the aliases_hash>, <pointer to the blocks_defined hash>)
sub read_formulas_from_excel_into_finalHash
{
	if (@_ != 4) {return 0;}
	
	my ($formulaFile, $final_hash, $aliases_hash, $blocks_defined) = @_;
	my @lines;
	my %fubsHash;
	my %unitsHash;
	my %clustersHash;

	open (INFILE, $formulaFile) or output_functions::die_cmd("Can't find formula file: \"$formulaFile\".\n");
	@lines = <INFILE>;
	close(INFILE);

	#system "dos2unix $File > /dev/null";

	foreach my $line (@lines)	# read the formulas into hashes
	{
		my %blockHash;
		chomp $line;
		$line =~ s/\r$//;

#		$line =~ s/p\d\.c\d\.([\w\.]*)\.power/p0\.power\.$1/g;	#### temporary convertion to old syntax
#		$line =~ s/uncore\d\.([\w\.]*)\.power/uncore\.power\.$1/g;	#### temporary convertion to old syntax
#		$line =~ s/(p0\.)c0\./$1/g;	#### temporary convertion to old syntax

		$line =~ s/[\w\.]*\.(voltage|frequency)/1/g;	#### converting to capacitance

#		if (($line =~ /^(\w+)\.power\.([\w\.]*)\s*:\s*(.*)$/) or ($line =~ /^(uncore1|p\d\.c\d)\.([\w\.]*)\.power\s*:\s*(.*)$/))  #find the formula
#		if ($line =~ /^(uncore\d|p\d\.c\d)\.?([\w\.]*)\.power\s*:\s*(.*)$/)  #find the formula
		if (parse_block_name($line, $blocks_defined, \%blockHash, "formula_file"))	# managed to parse the line
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
			}
			elsif ($type eq "Cluster")	# This is a Cluster type
			{
				$clustersHash{$cluster}{$parameter} = $value;
				$clustersHash{$cluster}{"Location"} = $location;
			}
			elsif ($type eq "Unit")	# This is a Unit type
			{
				$unitsHash{$unit}{$parameter} = $value;
				$unitsHash{$unit}{"Location"} = $location;
			}
			elsif ($type eq "Fub")	# This is a Fub type
			{
				if ($parameter eq "Formula")
				{
					$fubsHash{$fub}{"Functions"}{$formula_name} = $value;
				}
				else
				{
					$fubsHash{$fub}{$parameter} = $value;
					$fubsHash{$fub}{"Location"} = $location;
					$fubsHash{$fub}{"Unit"} = $unit;
				}
			}
			else
			{
				output_functions::print_to_log("Unknown block type at $line\n");
			}
		}
		elsif ($line =~ /\S+/)	# didn't manage to parse the line
		{
			output_functions::print_to_log("Error parsing this formula: \"$line\"\n");
		}
	}

	foreach my $cluster (keys %clustersHash)	# build up "final_Hash" that will hold all the data
	{
		my $location = $clustersHash{$cluster}{"Location"};

		my $tempc = $clustersHash{$cluster}{"Idle"};	# find the units in the cluster from it's idle formula
		(defined $tempc) or ($tempc = "");
		my @tempc = split(/\s*\+\s*/, $tempc);
		foreach my $unitForm (@tempc)
		{
#			if ($unitForm =~ /.*power\.(\w+)\.Idle/)
			if ($unitForm =~ /.*\.(\w+)\.Idle\.power/)
			{
				my $unit = $1;

				my $tempu = $unitsHash{$unit}{"Idle"};	# find the fubs in the unit from it's idle formula
				(defined $tempu) or ($tempu = "");
				my @tempu = split(/\s*\+\s*/, $tempu);
				foreach my $fubForm (@tempu)
				{
#					if ($fubForm =~ /.*power\.${unit}\.(\w+)\.Idle/)
					if ($fubForm =~ /.*\.${unit}\.(\w+)\.Idle\.power/)
					{
						my $fub = $1;
						my $idle = $fubsHash{$fub}{"Idle"};
						$idle =~ s/p\d\.c\d\.CORE.cycle_cnt/1/g;
						$idle = general::evaluate_numerical_expression($idle, "Error reading the idle of $location.$cluster.$unit.$fub from the formula file. Using 0!", $idle);
						$$final_hash{$location}{$cluster}{$unit}{$fub}{"Idle"} = $idle;
						my $leakage = $fubsHash{$fub}{"Leakage"};
						$leakage =~ s/p\d\.c\d\.CORE.cycle_cnt/1/g;
						$leakage = general::evaluate_numerical_expression($leakage, "Error reading the leakage of $location.$cluster.$unit.$fub from the formula file. Using 0!", $leakage);
						$$final_hash{$location}{$cluster}{$unit}{$fub}{"Leakage"} = $leakage;
						my $maxpower = $fubsHash{$fub}{"PCT_MAX"};
						(defined $maxpower) or ($maxpower = 0);
	#					if ($maxpower =~ /100\s*\*.*\/\s*\(?\s*([\d\.]+)/)
	#					{
	#						$maxpower = $1;
	#					}
	#					else
	#					{
	#						$maxpower = 0;
	#						output_functions::print_to_log("Could not find max power for $fub\n");
	#					}
						$maxpower =~ s/100\s*\*.*\/\s*//;
						$maxpower = general::evaluate_numerical_expression($maxpower, "Error reading the maxpower of $location.$cluster.$unit.$fub from the formula file. Using 0!", $maxpower);
						$$final_hash{$location}{$cluster}{$unit}{$fub}{"MaxPower"} = $maxpower;
						foreach my $function (keys %{$fubsHash{$fub}{"Functions"}})
						{
							my $form = "";
							my $alias = "";
							my $power = 0;
							if ($fubsHash{$fub}{"Functions"}{$function} =~ /^\s*\(\s*([\w\.]+)\s*\/\s*p\d\.c\d\.CORE\.cycle_cnt\s*\)(.*)/)
							{
								$form = $1;
								$power = $2;
								$power = "1" . $power;
								$power = general::evaluate_numerical_expression($power, "Error reading the power of $location.$cluster.$unit.$fub.$function from the formula file. Using 0!", $power);
								if (defined $$aliases_hash{$form})
								{
									$alias = $form;
									$form = $$aliases_hash{$alias};
								}
								$$final_hash{$location}{$cluster}{$unit}{$fub}{"Functions"}{$function}{"Alias"} = $alias;
								$$final_hash{$location}{$cluster}{$unit}{$fub}{"Functions"}{$function}{"Formula"} = $form;
								$$final_hash{$location}{$cluster}{$unit}{$fub}{"Functions"}{$function}{"Power"} = $power;
							}
							else
							{
								output_functions::print_to_log("error getting formula for: $location.$cluster.$unit.$fub.$function\n");
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


################# read the formulas into final_hash
### usage: read_formulas_into_finalHash(<formula file name>, <pointer to the final_hash>, <pointer to the blocks_defined hash>)
sub read_formulas_into_finalHash
{
	if (@_ != 4) {return 0;}
	
	my ($formulaFile, $final_hash, $aliases_hash, $blocks_defined) = @_;
	my @lines;
	my %fubsHash;
	my %unitsHash;
	my %clustersHash;

	$formulaFile = glob ($formulaFile);
	open (INFILE, $formulaFile) or output_functions::die_cmd("Can't find formula file: \"$formulaFile\".\n");
	@lines = <INFILE>;
	close(INFILE);

	#system "dos2unix $File > /dev/null";

	foreach my $line (@lines)	# read the formulas into hashes
	{
		my %blockHash;
		chomp $line;
		$line =~ s/\r$//;

#		$line =~ s/p\d\.c\d\.([\w\.]*)\.power/p0\.power\.$1/g;	#### temporary convertion to old syntax
#		$line =~ s/uncore\d\.([\w\.]*)\.power/uncore\.power\.$1/g;	#### temporary convertion to old syntax
#		$line =~ s/(p0\.)c0\./$1/g;	#### temporary convertion to old syntax

		$line =~ s/[\w\.]*\.(voltage|frequency)/1/g;	#### converting to capacitance

#		if (($line =~ /^(\w+)\.power\.([\w\.]*)\s*:\s*(.*)$/) or ($line =~ /^(uncore1|p\d\.c\d)\.([\w\.]*)\.power\s*:\s*(.*)$/))  #find the formula
#		if ($line =~ /^(uncore\d|p\d\.c\d)\.?([\w\.]*)\.power\s*:\s*(.*)$/)  #find the formula
		if (parse_block_name($line, $blocks_defined, \%blockHash, "formula_file"))	# managed to parse the line
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
			}
			elsif ($type eq "Cluster")	# This is a Cluster type
			{
				$clustersHash{$cluster}{$parameter} = $value;
				$clustersHash{$cluster}{"Location"} = $location;
			}
			elsif ($type eq "Unit")	# This is a Unit type
			{
				$unitsHash{$unit}{$parameter} = $value;
				$unitsHash{$unit}{"Location"} = $location;
			}
			elsif ($type eq "Fub")	# This is a Fub type
			{
				if ($parameter eq "Formula")
				{
					$fubsHash{$fub}{"Functions"}{$formula_name} = $value;
				}
				else
				{
					$fubsHash{$fub}{$parameter} = $value;
					$fubsHash{$fub}{"Location"} = $location;
					$fubsHash{$fub}{"Unit"} = $unit;
				}
			}
			else
			{
				output_functions::print_to_log("Unknown block type at $line\n");
			}
		}
		elsif ($line =~ /\S+/)	# didn't manage to parse the line
		{
			output_functions::print_to_log("Error parsing this formula: \"$line\"\n");
		}
	}

	foreach my $cluster (keys %clustersHash)	# build up "final_Hash" that will hold all the data
	{
		my $location = $clustersHash{$cluster}{"Location"};

		my $tempc = $clustersHash{$cluster}{"Idle"};	# find the units in the cluster from it's idle formula
		(defined $tempc) or ($tempc = "");
		my @tempc = split(/\s*\+\s*/, $tempc);
		foreach my $unitForm (@tempc)
		{
#			if ($unitForm =~ /.*power\.(\w+)\.Idle/)
			if ($unitForm =~ /.*\.(\w+)\.Idle\.power/)
			{
				my $unit = $1;

				my $tempu = $unitsHash{$unit}{"Idle"};	# find the fubs in the unit from it's idle formula
				(defined $tempu) or ($tempu = "");
				my @tempu = split(/\s*\+\s*/, $tempu);
				foreach my $fubForm (@tempu)
				{
#					if ($fubForm =~ /.*power\.${unit}\.(\w+)\.Idle/)
					if ($fubForm =~ /.*\.${unit}\.(\w+)\.Idle\.power/)
					{
						my $fub = $1;
						my $idle = $fubsHash{$fub}{"Idle"};
						$idle =~ s/p\d\.c\d\.CORE.cycle_cnt/1/g;
						$idle = general::evaluate_numerical_expression($idle, "Error reading the idle of $location.$cluster.$unit.$fub from the formula file. Using 0!", $idle);
						$$final_hash{$location}{$cluster}{$unit}{$fub}{"Idle"} = $idle;
						my $leakage = $fubsHash{$fub}{"Leakage"};
						$leakage =~ s/p\d\.c\d\.CORE.cycle_cnt/1/g;
						$leakage = general::evaluate_numerical_expression($leakage, "Error reading the leakage of $location.$cluster.$unit.$fub from the formula file. Using 0!", $leakage);
						$$final_hash{$location}{$cluster}{$unit}{$fub}{"Leakage"} = $leakage;
						my $maxpower = $fubsHash{$fub}{"PCT_MAX"};
						(defined $maxpower) or ($maxpower = 0);
	#					if ($maxpower =~ /100\s*\*.*\/\s*\(?\s*([\d\.]+)/)
	#					{
	#						$maxpower = $1;
	#					}
	#					else
	#					{
	#						$maxpower = 0;
	#						output_functions::print_to_log("Could not find max power for $fub\n");
	#					}
						$maxpower =~ s/100\s*\*.*\/\s*//;
						$maxpower = general::evaluate_numerical_expression($maxpower, "Error reading the maxpower of $location.$cluster.$unit.$fub from the formula file. Using 0!", $maxpower);
						$$final_hash{$location}{$cluster}{$unit}{$fub}{"MaxPower"} = $maxpower;
						foreach my $function (keys %{$fubsHash{$fub}{"Functions"}})
						{
							my $form = "";
							my $alias = "";
							my $power = 0;
							if ($fubsHash{$fub}{"Functions"}{$function} =~ /^\s*\(\s*([\w\.]+)\s*\/\s*p\d\.c\d\.CORE\.cycle_cnt\s*\)(.*)/)
							{
								$form = $1;
								$power = $2;
								$power = "1" . $power;
								$power = general::evaluate_numerical_expression($power, "Error reading the power of $location.$cluster.$unit.$fub.$function from the formula file. Using 0!", $power);
								if (defined $$aliases_hash{$form})
								{
									$alias = $form;
									$form = $$aliases_hash{$alias};
								}
								$$final_hash{$location}{$cluster}{$unit}{$fub}{"Functions"}{$function}{"Alias"} = $alias;
								$$final_hash{$location}{$cluster}{$unit}{$fub}{"Functions"}{$function}{"Formula"} = $form;
								$$final_hash{$location}{$cluster}{$unit}{$fub}{"Functions"}{$function}{"Power"} = $power;
							}
							else
							{
								output_functions::print_to_log("error getting formula for: $location.$cluster.$unit.$fub.$function\n");
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


################# read the aliases into aliases_hash
### usage: read_aliases_into_aliasesHash(<formula aliases file name>, <pointer to the aliases_hash>)
sub read_aliases_into_aliasesHash
{
	if (@_ != 2) {return 0;}
	
	my ($aliasesFile, $aliases_hash) = @_;

	$aliasesFile = glob($aliasesFile);
	open (AINFILE, $aliasesFile) or output_functions::die_cmd("Can't find aliases file: \"$aliasesFile\".\n");

	foreach my $line (<AINFILE>)	# read the aliases into hash
	  {
		  chomp $line;
		  $line =~ s/\r$//;

		  if ($line =~ /^\s*([\w\.]+)\s*:\s*(\S?.*\S)\s*$/)	#find the alias
			{
				my $alias = $1;
				my $value = $2;

				$$aliases_hash{$alias} = $value;
			}
	  }
	close(AINFILE);
}


################# parses the block's name and returns the hierarchy and value
### usage: parse_block_name(<the line to be parsed>, <pointer to the blocks_defined hash>, <block output hash>, <"formula_file"|"stats_file">)
sub parse_block_name
{
	if (@_ != 4) {return 0;}
	my ($line, $blocks_defined, $blockHash, $linetype) = @_;

	$line =~ s/power\.(\S+)/p0\.c0\.$1\.power/g;
	if ((($linetype eq "formula_file") and ($line =~ /^(uncore\d|p\d\.c\d|PLATFORM|)\.?([\w\.]*)\.?power\s*:\s*(.*)\s*$/))
#			or (($linetype eq "formula_file") and ($line =~ /^power\.(uncore\d?|p\d\.c\d|PLATFORM|)\.?([\w\.]*)\s*:\s*(.*)\s*$/))
			or (($linetype eq "stats_file") and ($line =~ /^(uncore\d|p\d\.c\d|PLATFORM|)\.?([\w\.]*)\.?power\s+(\d+\.?\d*)\s*$/)))  #find the formula
	{
		my $loc = $1;
		my @lineArray = split(/\./, $2);
		my $value = $3;
		my $type = "";
		my $parameter = "";
		my $location = "";
		my $cluster = "";
		my $unit = "";
		my $fub = "";
		my $formula_name = "";
		my $word = "";
		my $nextword = "";
		my $foundformula = 0;

		#find the location (core/uncore/none)
		if (($loc =~ /^p\d\.c\d/) or ($loc =~ /^CORE/)) {$location = "core";}
		elsif ($loc =~ /uncore/) {$location = "uncore";}
		elsif (($loc eq "") or ($loc eq "PLATFORM")) {$location = "platform";}
		else {$location = "none";}

		(defined ($word = shift @lineArray)) or ($word = "Total");
		if (($word eq "Idle") or ($word eq "Leakage") or ($word eq "Active") or ($word eq "Total"))	# This is a core/uncore type
		{
			$type = "core/uncore";
			$parameter = $word;
			$foundformula = 1;
		}
		else
		{
			(defined ($nextword = shift @lineArray)) or ($nextword = "Total");
			if (defined $$blocks_defined{"Clusters"}{$word})	# First word is a cluster name
			{
				$cluster = $word;

				if (($nextword eq "Idle") or ($nextword eq "Leakage") or ($nextword eq "Active") or ($nextword eq "Total"))	# This is a cluster type
				{
					$type = "Cluster";
					$parameter = $nextword;
					$foundformula = 1;
				}
				else
				{
					$word = $nextword;
					(defined ($nextword = shift @lineArray)) or ($nextword = "Total");
				}
			}
			if (not $foundformula)
			{
				if (defined $$blocks_defined{"Units"}{$word})	# Word is unit name
				{
					$unit = $word;

					if (($nextword eq "Idle") or ($nextword eq "Leakage") or ($nextword eq "Active") or ($nextword eq "Total"))	# This is a unit type
					{
						$type = "Unit";
						$parameter = $nextword;
						$foundformula = 1;
					}
					else	# probably a fub
					{
						$fub = $nextword;

						(defined ($nextword = shift @lineArray)) or ($nextword = "Total");
						if (($nextword eq "Idle") or ($nextword eq "Leakage") or ($nextword eq "Active") or ($nextword eq "Total") or ($nextword eq "PCT_MAX") or ($nextword eq "PCT_IL") or ($nextword eq "PCT_ACT"))	# This is a fub type
						{
							$type = "Fub";
							$parameter = $nextword;
							$foundformula = 1;
						}
						else	# probably a formula for a function of the fub
						{
							$formula_name = $nextword;

							(defined ($nextword = shift @lineArray)) or ($nextword = "");
							if ($nextword eq "")	# This is a formula for a function of the fub
							{
								$type = "Fub";
								$parameter = "Formula";
								$foundformula = 1;
							}
						}
					}
				}
			}
		}

		$$blockHash{"Value"} = $value;
		$$blockHash{"Type"} = $type;
		$$blockHash{"Parameter"} = $parameter;
		$$blockHash{"Location"} = $location;
		$$blockHash{"Cluster"} = $cluster;
		$$blockHash{"Unit"} = $unit;
		$$blockHash{"Fub"} = $fub;
		$$blockHash{"Formula_name"} = $formula_name;

		if (not $foundformula)	# didn't manage to parse
		{
			return 0;
		}
		return 1;
	}

	return 0;
}
#################


1;
