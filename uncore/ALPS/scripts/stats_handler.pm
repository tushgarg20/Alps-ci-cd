package stats_handler;

use diagnostics;
use strict;
use warnings;
use Data::Dumper;

use general;
use output_functions;
use general_config;


################# input the stats files list
sub input_stats_files_list {
	if (@_ != 5) {return "";}
	my ($logs, $loglist, $logdir, $grep, $final_logslist) = @_;

	output_functions::print_to_log("Getting the logs list\n");

	if ($logs ne "")
	{
		output_functions::print_to_log("Adding to the trace list: $logs.\n");
		$logs =~ s/\"//g;
		push @{$final_logslist}, glob($logs);
	}
	if ($loglist ne "")
	{
		$loglist = glob ($loglist);
		open(INFILE, $loglist) or die ("Can't open $loglist\n");
		output_functions::print_to_log("Adding to the trace list: $loglist.\n");
		my @raw_logslist = <INFILE>;
		foreach my $logline (@raw_logslist) {
			chomp $logline;
			push @{$final_logslist}, glob($logline);
		}
	}
	if (($logdir ne "") and ($grep ne ""))
	{
		($logdir =~ /\/$/) or ($logdir .= "/");
		output_functions::print_to_log("Adding to the trace list: $logdir, grepping $grep.\n");
		push @{$final_logslist}, glob($logdir . "*" . $grep . "*");
	}

	if (scalar(@$final_logslist) < 1)
	{
		output_functions::print_to_log("Couldn't generate logs list.\n");
		print STDERR "Warning: no stats files could be found!\n";
	}
}
#################


################# get the trace name from a stats file name
sub get_trace_name_from_stats_file_name
{
	if (@_ == 2)
	{
		my ($stats_file_name, $extension_to_remove) = @_;
		my $trace_name = $stats_file_name;

		chomp $trace_name;
		$trace_name =~ s/\r$//;
		$trace_name =~ s/\.gz$//;
		$trace_name =~ s/\.stat[s]?$//;

		if ($extension_to_remove ne "")
		{
			$trace_name =~ s/${extension_to_remove}$//;
		}

		$trace_name =~ s/.*\///g;

		return $trace_name;
	}
	else
	{
		die "Error in num of parameters of get_trace_name_from_stats_file_name function!";
	}
}
#################


################# insert the stats values from a file to the stats hash
### usage: read_stats_from_file(<pointer to the local stats hash>, <pointer to the global stats hash>, <pointer to the name of the trace>, <whether_designated_for_EC_stats>)
sub read_stats_from_file
{
	if (@_ != 7) {return 0;}
	my ($stats, $stats_hash, $stats_validity, $File, $histograms_to_exclude, $designated_for_ecstats, $trace_name) = @_;

	chomp $$File;
	$$File =~ s/\r$//;

	# Handle stats files differently for LRB3:
	# stat names are allowed to begin with "start"
	if (general_config::getKnob ("lrb3Mode")) {
		# Get only lines that are not comments and not histogram
		open(INFILE, "zgrep -v ^# $$File | zgrep -v ^StartHistogram | zgrep -v ^EndHistogram |") or output_functions::die_cmd("Can't open $$File.\n");
	} else {
		# Get only lines that are not comments, not histogram and not "start/end"
		open(INFILE, "zgrep -v ^# $$File | zgrep -v ^start | zgrep -v ^end | zgrep -v ^StartHistogram | zgrep -v ^EndHistogram |") or output_functions::die_cmd("Can't open $$File.\n");
	}
	my @lines = <INFILE>;
	close(INFILE);
	$$File =~ s/\.gz$//;
	$$File =~ s/\.stat[s]?$//;

	my $indigoFile = "";
	if (-e "$$File.indigo.txt.gz")
	{
		$indigoFile = "$$File.indigo.txt.gz";
	}
	elsif (-e "$$File.indigo.txt")
	{
		$indigoFile = "$$File.indigo.txt";
	}
	if ($indigoFile ne "")
	{
		open(INFILE, "zgrep -v ^# $indigoFile |") or output_functions::die_cmd("Can't open $indigoFile.\n");   ### get only uncommented lines
		my @indigo_lines = <INFILE>;
		close(INFILE);
		push @lines, @indigo_lines;
	}

	$$File =~ s/\.\w+$//;
	$$File =~ s/.*\///g;

	foreach my $line (@lines)
	{
		chomp $line;
		$line =~ s/\r$//;
		$line =~ s/^\s*//;

		if ($line =~ /^([\w\._\[\]:]+)\s+:?\s*(-?\d+\.?\d*)/)	#find the stats
		{
			my $s = $1;
			my $v = $2;

			### stats_validity counter value has 4 possible values:
			### non declared: need to check its validity
			### 0 - not valid
			### 1 - only valid for local hash
			### 2 - valid for local and global hash

			if (!exists($$stats_validity{$s})) {	# Have never checked this counter before. Check it now for validity.
				if ($s =~ /\.power$/)	# exclude the ALPS power output
				{
					$$stats_validity{$s} = 0;	# Counter is not valid.
				} elsif ((($s =~ /([\d\w\_:]+)(\[.+\]|BUCKETS|COUNT|MAX|MEAN|MEDIAN|MIN)$/) and (defined ($$histograms_to_exclude{$1}))))	# exclude large histograms
				{
					$$stats_validity{$s} = 1;	# Counter is valid only in local hash (not in global hash).
				} else {
					$$stats_validity{$s} = 1;	# Counter is at least valid for local hash.

					if (	($s !~ /^end\d\./) and
							($s !~ /^start\d\./) and
							($s !~ /^p\d\.c[1-9]\./) and
							($s !~ /^knob\./) and
							($s !~ /^\./) and
							($s !~ /^final\./) )
							# exclude redundant counters to save memory. This excludes only from the stats summary, not from the power calculation per trace.
					{
						if ($s =~ /(.*p\d\.c\d\.)t\d\.(.*)/)
						{
							if (!exists($$stats_hash{"${1}${2}"}))
							{
								$$stats_validity{$s} = 2;	# Counter is valid for global (and hence also local) hash
							}
						}
						elsif ($s =~ /(.*)p(\d)\.c(\d)\.(.+)/)
						{
							my $prefix = $1;
							my $pNum = $2;
							my $cNum = $3;
							my $counterName = $4;

							# This is a full counter name. Remove previous counters with shorter prefix (none or p0) or longer prefix (p0.c0.t0) from global hash.
							foreach my $counterFullName ("${prefix}${counterName}", "${prefix}p${pNum}.${counterName}", "${prefix}p${pNum}.c${cNum}.t0.${counterName}", "${prefix}p${pNum}.c${cNum}.t1.${counterName}")
							{
								if (exists($$stats_validity{$counterFullName}))
								{
									if ($$stats_validity{$counterFullName} == 2)
									{
										$$stats_validity{$counterFullName} = 1;
										delete($$stats_hash{$counterFullName});
									}
								}
							}

							$$stats_validity{$s} = 2;	# Counter is valid for global (and hence also local) hash
						}
						elsif ($s =~ /(.*p\d\.)(.*)/)
						{
							if (!exists($$stats_validity{"${1}c0.${2}"}))
							{
								$$stats_validity{$s} = 2;	# Counter is valid for global (and hence also local) hash
							}
						}
						elsif (!exists($$stats_validity{"p0.c0.$s"}))
						{
							$$stats_validity{$s} = 2;	# Counter is valid for global (and hence also local) hash
						}
					}
				}
			}

			my $validity = $$stats_validity{$s};
			if ($validity > 0) {	# Counter is at least valid locally.
				if (defined $$stats{$s})
				{
					if ($$stats{$s} !~ /^p0\.uncore\./)
					{
						output_functions::print_to_log("Error: counter $s exists more than once in the stats files for trace $trace_name! Value is not overwriten by the latest reference.\n");
					}
				}
				else
				{
					$$stats{$s} = $v;	# Insert the counter into the local hash

					if (($validity == 2) and ($v != 0)) {	# Counter is valid for global hash.
						$$stats_hash{$s}{$trace_name} = $v;	# Insert the counter into the global hash
					}
				}
			}
		}
	}

	return 1;
}
#################


################# check_for_huge_histograms_and_remove_them
sub check_for_huge_histograms_and_remove_them
{
	if (@_ != 4) {return 0;}
	my ($stats_hash, $huge_histos, $histograms_to_exclude, $stats_validity) = @_;

	huge_histo_warn($stats_hash, $huge_histos);
	foreach my $histo (keys %$huge_histos)
	{
		my $histo_name = "";
		if ($histo =~ /([\d\w\_:]+)$/) {$histo_name = $1;}
		if (!defined($$histograms_to_exclude{$histo_name}))
		{
			print STDOUT "\nWarnning! Histogram $histo is very large. Please update the hashes file to ignore it.\n";
			if ($histo_name ne "")
			{
				print STDOUT "Ignoring $histo_name histogram in the flow to save memory.\n";
				$$histograms_to_exclude{$histo_name} = 1;

				foreach my $s (keys %$stats_validity) # Remove validity of histogram entries that have already been inserted into the validity hash as globaly valid.
				{
					if ( ($s =~ /([\d\w\_:]+)(\[.+\]|BUCKETS|COUNT|MAX|MEAN|MEDIAN|MIN)$/) and ($1 eq $histo_name) and ($$stats_validity{$s} == 2) )
					{
						$$stats_validity{$s} = 1;	# Now the validity will be only for the local hash and not the global hash.
						delete($$stats_hash{$s});	# Removing the instance in the global stats hash.
					}
				}
			}
			else
			{
				print STDOUT "Can't ignore it in the flow to save memory.\n";
			}
		}
	}

	return 1;
}
#################


################# calculate the IPC using the stats and put in into the IPC hash
### usage: calc_IPC(\%ipc_hash, $File, \%stats)
sub calc_IPC
{
	if (@_ != 3) {return 0;}
	my ($ipc_hash, $File, $stats) = @_;

	my ($p0c0, $p0c1, $p0c0t1) = ("p0.c0.", "p0.c1.", "p0.c0.t1.");
	if (general_config::getKnob("lrb3Mode")) {
		($p0c0, $p0c1, $p0c0t1) = ("", "", "");
	}

	if (exists($$ipc_hash{$File}) and defined($$ipc_hash{$File}))
	{
		die "Error: Trace name \"$File\" exists more than once in the statistics files list. Don't want the last instance to overwrite the previous instances, so killing the script.\n";
	}

	$$ipc_hash{$File}{"Instructions"} = $$stats{$p0c0 . "instrs_retired"};
	if (!defined($$ipc_hash{$File}{"Instructions"}))
	{
		$$ipc_hash{$File}{"Instructions"} = $$stats{$p0c0 . "instr_retire"};
	}
	$$ipc_hash{$File}{"Expected Instructions"} = $$stats{$p0c0 . "expected_instrs"};
	if ((!defined($$ipc_hash{$File}{"Expected Instructions"})) or
		((defined($$stats{$p0c1 . "instrs_retired"})) or
		 (defined($$stats{$p0c0t1 . "instrs_retired"}))
		) ) # this is a multi thread run
	{
		$$ipc_hash{$File}{"Expected Instructions"} = $$ipc_hash{$File}{"Instructions"}; # don't enforce checking the number of retired insts is equal to expected
	}
	if ((defined($$ipc_hash{$File}{"Instructions"})) and ($$ipc_hash{$File}{"Instructions"} > 0))
	{
		#$$ipc_hash{$File}{"Instructions Ratio"} = int(($$ipc_hash{$File}{"Expected Instructions"}/$$ipc_hash{$File}{"Instructions"}*100)+0.5)/100;
		$$ipc_hash{$File}{"Instructions Delta"} = abs($$ipc_hash{$File}{"Expected Instructions"} - $$ipc_hash{$File}{"Instructions"});
	}
	else
	{
		$$ipc_hash{$File}{"Instructions Delta"} = 0;
	}
	if (general_config::getKnob("lrb3Mode"))
	{
		if (defined $$stats{"p0.cycles"}) {
			$$ipc_hash{$File}{"Cycles"} = $$stats{"p0.cycles"};
		} else {
			$$ipc_hash{$File}{"Cycles"} = 0;
		}
	}
	else
	{
		if (defined $$stats{"cycles"}) {
			$$ipc_hash{$File}{"Cycles"} = ($$stats{"cycles"}/2);
		} else {
			$$ipc_hash{$File}{"Cycles"} = 0;
		}
	}

	$$ipc_hash{$File}{"IPC"} = 0;
	if ((defined $$ipc_hash{$File}{"Instructions"}) and
		(defined $$ipc_hash{$File}{"Cycles"}) and
		($$ipc_hash{$File}{"Cycles"} > 0) and
		(($$ipc_hash{$File}{"Instructions Delta"} < 50) or
		 (($$ipc_hash{$File}{"Instructions Delta"}/$$ipc_hash{$File}{"Instructions"}) < 0.01)
		))	# calculate IPC
	{
		$$ipc_hash{$File}{"IPC"} = $$ipc_hash{$File}{"Instructions"}/$$ipc_hash{$File}{"Cycles"};
	}
	else
	{
		output_functions::print_to_log("Error calculating IPC for $File. Using 0.\n");
		output_functions::print_to_log("The IPC hash values are:\n" . Dumper(\%{$$ipc_hash{$File}}));
	}

#	my %empty_hash = ();
#	my $statistics = general_config::getKnob("statistics_for_IPC_sheet");
#	($statistics ne "-1") or $statistics = \%empty_hash;

#	foreach my $statistic (keys %$statistics)
#	{
#		if ($$statistics{$statistic}{"counter_type"} eq "multi_inst")
#		{

#		}
#		elsif ($$statistics{$statistic}{"counter_type"} eq "regular")
#		{
#		my @k = keys(%{$$statistics{$statistic}{"counter"}});
#		$cycles_counter_local = $k[0];
#		(defined $cycles_counter_local) or output_functions::die_cmd("Error: bad cycles counter for block $block.\n");
#			my $s = $$statistics{$statistic}{"counter_type"};
#		}
#	}

	my @uncore_stats = ("llc_lookup", "llc_miss", "llc_hit");
	my @mc_stats = ("mc_num_reads", "mc_num_writes");
	$$ipc_hash{$File}{"mc_cycles"} = $$stats{"p0.uncore.hom0.gsr_mc.mc_channel0.total_cycles"};
	$$ipc_hash{$File}{"simtime"} = $$stats{"nanoseconds"};
	foreach my $stat ("mc_num_reads", "mc_num_writes", "mc_cycles", "simtime")
	{
		(defined ($$ipc_hash{$File}{$stat})) or ($$ipc_hash{$File}{$stat} = 0);
	}

	if ((defined $$ipc_hash{$File}{"Cycles"}) and ($$ipc_hash{$File}{"Cycles"} > 0) and (defined $$ipc_hash{$File}{"simtime"}) and ($$ipc_hash{$File}{"simtime"} > 0))
	{
		foreach my $cbo ("cbo0", "cbo1", "cbo2")
		{
			$$ipc_hash{$File}{$cbo . ".llc_lookup"} = $$stats{"p0.uncore.$cbo.cpipe.llc_lookup"};
			$$ipc_hash{$File}{$cbo . ".llc_miss"} = $$stats{"p0.uncore.$cbo.cpipe.llc_miss"};
			$$ipc_hash{$File}{$cbo . ".llc_hit"} = $$stats{"p0.uncore.$cbo.cpipe.llc_hit"};
			foreach my $stat_base (@uncore_stats)
			{
				my $stat = $cbo . "." . $stat_base;
				if (defined $$ipc_hash{$File}{$stat})
				{
					$$ipc_hash{$File}{$stat . "_per_cycle"} = $$ipc_hash{$File}{$stat}/$$ipc_hash{$File}{"Cycles"};
				}
			}
		}
		foreach my $stat_base (@uncore_stats)
		{
			$$ipc_hash{$File}{"cbo." . $stat_base} = 0;
			$$ipc_hash{$File}{"cbo." . $stat_base . "_per_cycle"} = 0;
			foreach my $cbo ("cbo0", "cbo1", "cbo2")
			{
				my $stat = $cbo . "." . $stat_base;
				if (defined $$ipc_hash{$File}{$stat})
				{
					$$ipc_hash{$File}{"cbo." . $stat_base} += $$ipc_hash{$File}{$stat};
					$$ipc_hash{$File}{"cbo." . $stat_base . "_per_cycle"} += $$ipc_hash{$File}{$stat}/$$ipc_hash{$File}{"Cycles"};
				}
			}
		}
		$$ipc_hash{$File}{"cbo_BW"} = $$ipc_hash{$File}{"cbo.llc_lookup"} * 64 / $$ipc_hash{$File}{"simtime"};
	}
	if ((defined $$ipc_hash{$File}{"mc_cycles"}) and ($$ipc_hash{$File}{"mc_cycles"} > 0) and (defined $$ipc_hash{$File}{"simtime"}) and ($$ipc_hash{$File}{"simtime"} > 0))
	{
		foreach my $mc ("mc_channel0", "mc_channel1", "mc_channel2")
		{
			$$ipc_hash{$File}{$mc . ".mc_num_reads"} = $$stats{"p0.uncore.hom0.gsr_mc.$mc.num_reads"};
			$$ipc_hash{$File}{$mc . ".mc_num_writes"} = $$stats{"p0.uncore.hom0.gsr_mc.$mc.num_writes"};
			foreach my $stat_base (@mc_stats)
			{
				my $stat = $mc . "." . $stat_base;
				if (defined $$ipc_hash{$File}{$stat})
				{
					$$ipc_hash{$File}{$stat . "_per_cycle"} = $$ipc_hash{$File}{$stat}/$$ipc_hash{$File}{"mc_cycles"};
				}
			}
		}
		foreach my $stat_base (@mc_stats)
		{
			$$ipc_hash{$File}{"mc." . $stat_base} = 0;
			$$ipc_hash{$File}{"mc." . $stat_base . "_per_cycle"} = 0;
			foreach my $mc ("mc_channel0", "mc_channel1", "mc_channel2")
			{
				my $stat = $mc . "." . $stat_base;
				if (defined $$ipc_hash{$File}{$stat})
				{
					$$ipc_hash{$File}{"mc." . $stat_base} += $$ipc_hash{$File}{$stat};
					$$ipc_hash{$File}{"mc." . $stat_base . "_per_cycle"} += $$ipc_hash{$File}{$stat}/$$ipc_hash{$File}{"mc_cycles"};
				}
			}
		}
		$$ipc_hash{$File}{"mc_BW"} = ($$ipc_hash{$File}{"mc.mc_num_reads"} + $$ipc_hash{$File}{"mc.mc_num_writes"}) * 64 / $$ipc_hash{$File}{"simtime"};
	}

	return 1;
}
#################


################# evaluate a formula using the stats hash and return the value
### usage: eval_stat(<the formula>, <pointer to the stats hash>, <optional pointer to the aliases hash>)
sub eval_stat
{
	if (@_ >= 2)
	{
		my ($formula, $stats, $aliases) = @_;
        my $formula_0 = $formula."_0";
        my $formula_1 = $formula."_1";

		if (not ($formula =~ /[a-zA-Z_]/))	 ### is a number
		{
			return $formula;
		}
		elsif (defined($$stats{$formula}))
		{
			return "( $$stats{$formula} )";
		}
		elsif (defined($$stats{$formula_0}))
		{
			return "( $$stats{$formula_0} )";
		}
		elsif (defined($$stats{$formula_1}))
		{
			return "( $$stats{$formula_1} )";
		}
		elsif (defined($aliases) && defined($$aliases{$formula}))
		{
			my $aliased_formula = "( $$aliases{$formula} )";
			$aliased_formula =~ s/([\w\.\[\d\]:]+)/{eval_stat($1, $stats, $aliases);}/eg;
			return $aliased_formula;
		}
		elsif ($formula =~ /^\d+\.\d+e/)   ### is a begining of a scientific number
		{
			return $formula;
		}
	}

	return "(STAT_ERROR)";
}
#################


################# Look for huge histograms - dump summary
### usage: huge_histo_dump()
sub huge_histo_dump
{
	if (@_ == 3)
	{
		my ($outputDir, $experiment, $stats_hash) = @_;
		my %histo_count_per_template;

		foreach my $s (keys %$stats_hash)
		{
			if ($s =~ /(.*)\[.+\]$/)
			{
				if (defined($histo_count_per_template{$1})) {$histo_count_per_template{$1}++;} else {$histo_count_per_template{$1} = 1;}
			}
		}
		open (O, "| sort | gzip >${outputDir}histograms_count_${experiment}.xls.gz");
		foreach my $i (keys %histo_count_per_template)
		{
			my $pval = $histo_count_per_template{$i} + 10000000;
			print O "$pval - $i\n";
		}
		close(O);
	}
}
#################


################# Look for huge histograms - warn about them
sub huge_histo_warn
{
	if (@_ == 2)
	{
		my ($stats_hash, $huge_histos) = @_;
		my %histo_count_per_template;

		foreach my $s (keys %$stats_hash)
		{
			if ($s =~ /(.*)\[.+\]$/)
			{
				if (defined($histo_count_per_template{$1}))
				{
					$histo_count_per_template{$1}++;
					if ($histo_count_per_template{$1} == 50) {$$huge_histos{$1} = 1;}
				}
				else
				{
					$histo_count_per_template{$1} = 1;
				}
			}
		}
	}
}
#################


################# get the stats that are used in the formulas files
sub get_used_stats_in_formulas {
	if (@_ != 2) {return 0;}
	my ($fullformulasHash, $stats) = @_;

	foreach my $location (keys %$fullformulasHash)
	{
		foreach my $cluster (keys %{$$fullformulasHash{$location}})
		{
			foreach my $unit (keys %{$$fullformulasHash{$location}{$cluster}})
			{
				foreach my $fub (keys %{$$fullformulasHash{$location}{$cluster}{$unit}})
				{
					foreach my $function (keys %{$$fullformulasHash{$location}{$cluster}{$unit}{$fub}{"Functions"}})
					{
						my $formula = $$fullformulasHash{$location}{$cluster}{$unit}{$fub}{"Functions"}{$function}{"Formula"};
						my $EC = $$fullformulasHash{$location}{$cluster}{$unit}{$fub}{"Functions"}{$function}{"Power"};

                        $formula =~ s/([\w\.\[\d\]:]+)/{insert_stat($1, $EC, "$location, $cluster, $unit, $fub, $function.", $stats);}/eg;
					}
				}
			}
		}
	}

	return 1;
}
#################


################# insert the stat into the used stats hash
sub insert_stat {
	if (@_ == 4)
	{
		my ($stat, $EC, $info, $stats) = @_;

		($EC ne "") or ($EC = 0);
		$EC = general::evaluate_numerical_expression($EC, "Error in the flow of finding the used stats in formulas and total EC per stat. Can't evaluate the EC of $info. Using 0!\nThis affects the stat: $stat", $EC);

		if (defined $$stats{$stat})
		{
			$$stats{$stat}{"EC"} += $EC;
			$$stats{$stat}{"Info"} .= "\t$info";
			return 1;
		}
		else
		{
			$$stats{$stat}{"EC"} = $EC;
			$$stats{$stat}{"Info"} = "$info";
			return 1;
		}
	}

	return "(STAT_ERROR)";
}
#################



1;
