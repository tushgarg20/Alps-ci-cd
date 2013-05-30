#!/usr/intel/bin/perl
# name: diff_alps_keiko_power.pl
# date: 29-Jan-2009
# auth: Mosur Mohan
#
# ver:  0.1
# desc: diffs power between Keiko stat file and
#		power_txt_output_functions.*.xls produced by alps.pl
# proj: Haswell/Broadwell for initial deployment

# Explicitly force glob to execute this function because of a
# bug wherein the 1st call to glob within the 2nd invocation of a sub
# returns null (as happens within readFile below)
# use File::Glob "glob";

#### pragmas
use strict;
use warnings;

#### system vars
$| = 1;		   ## Flush after every write or print
			   ## Useful during debugging, turn off for production use

#### program vars and command-line args
our ($opt_man, $opt_help) = ();
my ($ref_file, $out_file, $summ_file, $new_file) = ();
my $ind_cols = 8;		  # Number of indicator columns (after hierarchy cols)
my $abs_diff_threshold = 0.001;	# Absolute diff that will trigger an
								# item being reported to big_diffs file
my $pct_diff_threshold = 0.5;	# Diff % that will trigger an
								# item being reported to big_diffs file
my $script_name = $0;
$script_name =~ s/(^.*\/)//;

#### constants
use constant UNKNOWN => 'UNKNOWN';
use constant UNCALC  => '';
use constant STAT_PREC => 6;	# digits of precision needed in results

#### modules
use Pod::Usage;
use Getopt::Long;
$Getopt::Long::ignorecase = 1;
$Getopt::Long::autoabbrev = 1;

GetOptions('ref=s'     => \$ref_file,
           'new=s'     => \$new_file,
           'ofile=s'   => \$out_file,
           'summary=s' => \$summ_file,
		   'indcols=s' => \$ind_cols,
		   'absdiff=s' => \$abs_diff_threshold,
		   'pctdiff=s' => \$pct_diff_threshold,
           'man',
           'help') || die "Try `perl $script_name -help' for more information.\n";

# Hash to hold all the event-level power data
# Structure:
# $events{$location}{$cluster}{$unit}{$fub}{$function}{new|ref}{$trace_name} = $power
my %events = ();

# Hash to store total file power at fub, unit, cluster and location levels
# Structure:
# 	$rollup{$location}{$cluster}{$unit}{$fub}{"~TOTAL~"}{new|ref}{$trace_name} = $power
# 	$rollup{$location}{$cluster}{$unit}{"~TOTAL~"}{new|ref}{$trace_name} = $power
# 	$rollup{$location}{$cluster}{"~TOTAL~"}{new|ref}{$trace_name} = $power
# 	$rollup{$location}{"~TOTAL~"}{new|ref}{$trace_name} = $power
my %rollup = ();

# Array of trace names from power_txt_output_functions.* file header line
# Same order is preserved in output showing diffs and deltas
my @trace_names = ();

my $out_file_header = "";		# Header for output file

my $start_time = time;

######################################################################
#### main
######################################################################

checkArgs();  # Check command-line arguments

# Read in ref and new power data files
readPowerDataFile ($ref_file, \%events, \%rollup, \@trace_names, $ind_cols, "ref");
readPowerDataFile ($new_file, \%events, \%rollup, \@trace_names, $ind_cols, "new");

# Compute diffs and write out results
if ((! defined $summ_file) || ($summ_file eq "")) {
	$summ_file = $out_file;
	$summ_file =~ s/\.xls$/_summ.xls/;
}

my $retval = writeDiffs($out_file, $summ_file, \%events, \%rollup, $ind_cols,
						$abs_diff_threshold, $pct_diff_threshold,
						\@trace_names);


exit $retval;

######################################################################
#### end_main
######################################################################


######################################################################
#### subroutines
######################################################################

######################################################################
# Check command-line arguments
######################################################################
sub checkArgs {
	if ($opt_help) {
		# Launch help and exit
		pod2usage(-exitval => 1, -verbose => 1, -output => \*STDOUT);
	}
	if ($opt_man) {
		# Launch man page and exit
		pod2usage(-exitval => 1, -verbose => 2, -output => \*STDOUT);
	}

    # Check that both required input files are given
    my $kill = 0;
    if (! defined $ref_file) {
        print STDERR "-E- Please specify a file with -afile switch.\n";
        $kill = 1;
    }
    if ($new_file eq "") {
        print STDERR "-E- Please specify stat files with -statfiles switch.\n";
        $kill = 1;
    }

    # If any of the checks failed, cannot continue
    if ($kill == 1) {
        die "-F- Could not proceed. Exiting.\n";
    }
}


######################################################################
# Based on input file name, figure out what kind of file it is
# and, accordingly, hand off to appropriate reader function to parse
######################################################################
sub readPowerDataFile {
	my ($infile, $events_p, $rollup_p, $trace_names_p, $indcols, $dtag) = @_;
	$infile =~ s/[\'\"]//g;

	my @infile_list = glob ($infile);

	# Is it Alps power output file, or Keiko stat file?
	if ($#infile_list < 0) {
		die "-F- No files matching $infile\n";
	} elsif (($#infile_list == 0) &&
		($infile_list[0] =~ /power_txt_output_functions/)) {
		# Read Alps power output file
		readFuncFile ($infile_list[0], $events_p, $rollup_p, $trace_names_p,
					  $indcols, $dtag);

		# Compute power rollup totals for upper hierarchy levels
		rollupFuncPower ($events_p, $rollup_p, $trace_names_p, $indcols, $dtag);
	} else {
		# Read Keiko stat files
		foreach my $sfile (@infile_list) {
			readStatFile($sfile, $events_p, $rollup_p, $dtag);
		}
	}
}



######################################################################
# Read the power_txt_output_functions.* file, and
# save the data into hash %event{...hierarchy...}{$dtag}{$trace_name}
######################################################################
sub readFuncFile {
    my ($ffile, $events_p, $rollup_p, $trace_names, $indcols, $dtag) = @_;
	my $power_section = 0;

    print STDOUT "-I- Reading $ffile\n";
	if ($ffile =~ /\.gz$/) {
		open ("FUNCFILE", "gzcat $ffile |") ||
		  die "-F- Cannot open $ffile: $!\n";
	} else {
		open ("FUNCFILE", "< $ffile") ||
		  die "-F- Cannot open $ffile: $!\n";
	}

    while (my $line = <FUNCFILE>) {
        next if ($line =~ /^\s*IPC/);
        chomp $line;

        # Separate the fields based on tabs
        my ($function, $fub, $unit, $cluster, $location, @fields) = split /\t/, $line;
		my ($EC_formula, $EC, $comment);

        # Parse first line to extract selected column titles and indices
        if ($line =~ /^\s*Function/i) {
			if ($fields[0] eq "Power_section") {
				# Extra Power_section column exists, need to skip it
				$power_section = 1;
				shift (@fields);
			}
			$EC_formula = shift (@fields);
			$EC = shift (@fields);
			$comment = shift (@fields);

			# Everything after Comment column = stat files
			if ($#trace_names < 0) {
				# trace_names not yet initialized;
				# save the array of trace names in title line
				@{$trace_names} = @fields;
			} else {
				# trace_names already populated; add only new traces if any 
				foreach my $new_trace (@fields) {
					my $add_trace = 1;
					foreach (my $colnum=0; $colnum <= $#fields; $colnum++) {
						if ($new_trace eq $fields[$colnum]) {
							$add_trace = 0;
							last;
						}
					}
					if ($add_trace) {
						push (@{$trace_names}, $new_trace);
					}
				}
			}
        } else {
			if ($power_section) {
				# Extra Power_section column exists, need to skip it
				shift (@fields);
			}
			$EC_formula = shift (@fields);
			$EC = shift (@fields);
			$comment = shift (@fields);

            for (my $colnum=0; $colnum <= $#trace_names; $colnum++) {
				my $col = $trace_names[$colnum];

				if ($function eq "Leakage") {
					# Filter out leakage events
					next;
				} elsif ($function eq "Idle") {
					# For Idle events, set all power columns to EC value
					$$events_p{$location}{$cluster}{$unit}{$fub}{$function}{$dtag}{$col} = $EC;
				} else {
					# All other (i.e., real) events
					$$events_p{$location}{$cluster}{$unit}{$fub}{$function}{$dtag}{$col} = $fields[$colnum];
				}
            }
        }
    }
    close FUNCFILE;
}


######################################################################
# Sum up rollup totals for power_txt_output_functions.* file
######################################################################
sub rollupFuncPower {
	my ($events_p, $rollup_p, $trace_names_p, $indcols, $dtag) = @_;

	foreach my $location (keys %{$events_p}) {
		foreach my $cluster (keys %{$$events_p{$location}}) {
			foreach my $unit (keys %{$$events_p{$location}{$cluster}}) {
				foreach my $fub (keys %{$$events_p{$location}{$cluster}{$unit}}) {
					foreach my $function (keys %{$$events_p{$location}{$cluster}{$unit}{$fub}}) {
						# Skip Leakage entries
						if ($function eq "Leakage") {
							next;
						}

						# Iterate over columns
						for (my $colnum=$indcols; $colnum <= $#{$trace_names_p}; $colnum++) {
							my $col = $$trace_names_p[$colnum];
							my $ev_p = \%{$$events_p{$location}{$cluster}{$unit}{$fub}};

							if (defined $$ev_p{$function}{$dtag}{$col}) {
								my $ev_power = $$ev_p{$function}{$dtag}{$col};
								$ev_power = roundoff ($ev_power, STAT_PREC);

								# Rollup total power up the hierarchy
								$$rollup_p{$location}{$cluster}{$unit}{$fub}{"~TOTAL~"}{$dtag}{$col} += $ev_power;
								$$rollup_p{$location}{$cluster}{$unit}{"~TOTAL~"}{$dtag}{$col} += $ev_power;
								$$rollup_p{$location}{$cluster}{"~TOTAL~"}{$dtag}{$col} += $ev_power;
								$$rollup_p{$location}{"~TOTAL~"}{$dtag}{$col} += $ev_power;
							}
						}
					}
				}
			}
		}
	}
}


######################################################################
# Read and parse the Coho stat file, extracting just the power data
######################################################################
sub readStatFile {
    my ($sfile, $event, $rollup, $dtag) = @_;
	my ($hier_head, $event_name, $power_type) = ();

    print STDOUT "-I- Reading $sfile\n";
	if ($sfile =~ /\.gz$/) {
		open ("STATFILE", "gzcat $sfile |") ||
		  die "-F- Cannot open $sfile: $!\n";
	} else {
		open ("STATFILE", "< $sfile") ||
		  die "-F- Cannot open $sfile: $!\n";
	}

	# Clean up filename, extract trace name for matching with trace titles
	$sfile =~ s/\.gz$//;
	$sfile =~ s/\.stat[s]?$//;
	$sfile =~ s/\.\w+$//;		# remove any remaining trailing filename extensions
	$sfile =~ s/.*\///g;		# remove path prefix

    while (my $line = <STATFILE>) {

		if ($line =~ /\.power\s/) {
			# Found a power result
			my ($hier_event, $power) = split (/\s+/, $line);

			# Parse the stat file line
			my ($p0, $location, $cluster, $unit, $fub, $function, $powstr) = ();
			my @rest = ();
			if ($hier_event =~ /^(.*)\.(Idle|Active|Total)\.power/) {
				$hier_head = $1;
				$power_type = $2;

				if ($hier_head =~ /^p0\./) {
					# Package p0 exists
					($p0, $location, $cluster, $unit, $fub) = split (/\./, $hier_head);
				} else {
					($location, $cluster, $unit, $fub) = split (/\./, $hier_head);
				}

				$location =~ s/c(\d)/core$1/;
				if ($power_type eq "Total") {
					# Record total power at every level
					if (defined $fub) {
						$$rollup{$location}{$cluster}{$unit}{$fub}{"~TOTAL~"}{$dtag}{$sfile} = $power;
					} elsif (defined $unit) {
						$$rollup{$location}{$cluster}{$unit}{"~TOTAL~"}{$dtag}{$sfile} = $power;
					} elsif (defined $cluster) {
						$$rollup{$location}{$cluster}{"~TOTAL~"}{$dtag}{$sfile} = $power;
					} elsif (defined $location) {
						$$rollup{$location}{"~TOTAL~"}{$dtag}{$sfile} = $power;
					}
				} elsif ($power_type eq "Idle") {
					# Record Idle power when it is given for complete
					# cluster/unit/fub hierarchy; ignore Idle numbers
					# rolled-up to unit level and higher
					if (defined $fub) {
						# Found complete hierarchy ==> contains fub-level data
						# Note that Idle is not measured per trace; only EC is available,
						# and stat file contains EC for Idle power
						$$event{$location}{$cluster}{$unit}{$fub}{"Idle"}{$dtag}{$sfile} = $power;
					}
				}
			} elsif ($hier_event =~ /^p\d\.c(\d)\.([^\.]+)\.([^\.]+)\.([^\.]+)\.(.*)\.power$/) {
				# Record event power for core FUB
				$location = "core" . $1;
				$cluster = $2;
				$unit = $3;
				$fub = $4;
				$function = $5;
				$$event{$location}{$cluster}{$unit}{$fub}{$function}{$dtag}{$sfile} = $power;
			} elsif ($hier_event =~ /^([^\.]+)\.([^\.]+)\.([^\.]+)\.([^\.]+)\.(.*)\.power$/) {
				# Record event power for uncore FUB
				$location = $1;
				$cluster = $2;
				$unit = $3;
				$fub = $4;
				$function = $5;
				$$event{$location}{$cluster}{$unit}{$fub}{$function}{$dtag}{$sfile} = $power;
			} else {
				print STDERR "-E- Couldn't parse line: $line";
			}
		}
	}
    close STATFILE;
}


######################################################################
# Print the full diffs to the output file, and rows with
# significant diffs (> abs or % threshold) to summary file
######################################################################
sub writeDiffs {
    my ($out_file, $summ_file, $events_p, $rollup, $indcols,
		$abs_diff_threshold, $pct_diff_threshold,
		$trace_names) = @_;

	my $of_header = "";
	my ($out_line, $line_hier) = ("", "");
	my ($max_abs, $max_pct);
	my ($loc_summ_flag, $clus_summ_flag, $unit_summ_flag, $fub_summ_flag, $summ_flag)
	  = (0, 0, 0, 0, 0);
	my ($out_count, $summ_count) = (0, 0); # count total and violating lines
	my $totals = ();

	$out_file = glob($out_file);
    print STDOUT "-I- Writing output to $out_file.\n";
    open(RESULT, "> $out_file") || die "-F- Cannot open $out_file: $!\n";

	$summ_file = glob ($summ_file);
	open(SUMMFILE, "> $summ_file") || die "-F- Cannot open $summ_file: $!\n";

	# Construct header for output
	$of_header = "Function\tFub\tUnit\tCluster\tLocation\tMax_delta\tMax_pct";

	# Loop over columns, starting after indicator columns
	for (my $colnum=$indcols; $colnum <= $#trace_names; $colnum++) {
		my $col = $trace_names[$colnum];
		$of_header .= "\tnew->${col}\tref->${col}\tdelta->${col}\t%diff->${col}";
	}
    print RESULT "$of_header\n";	# print header line
	print SUMMFILE "$of_header\n";	# ditto for summary file

    # Iterate through the %events hash hierarchy
	# Compare both function-level power numbers and rollup totals
    foreach my $location (sort keys %{$events_p}) {
		$loc_summ_flag = 0;

        foreach my $cluster (sort keys %{$$events_p{$location}}) {
			$clus_summ_flag = 0;

            foreach my $unit (sort keys %{$$events_p{$location}{$cluster}}) {
				$unit_summ_flag = 0;

                foreach my $fub (sort keys %{$$events_p{$location}{$cluster}{$unit}}) {
					$fub_summ_flag = 0;

                    foreach my $function (sort keys %{$$events_p{$location}{$cluster}{$unit}{$fub}}) {
						# Skip Leakage entries
						if ($function eq "Leakage") {
							next;
						}

						$line_hier = "$function\t$fub\t$unit\t$cluster\t$location";
						$out_line = "";
						$summ_flag = 0;
						($max_abs, $max_pct) = (0, 0);

                        # Iterate over columns in the right order
                        for (my $colnum=$indcols; $colnum <= $#{$trace_names}; $colnum++) {

							my $col = $$trace_names[$colnum];
                            my ($pwr_func, $pwr_stat) = ();
							my $evp = \%{$$events_p{$location}{$cluster}{$unit}{$fub}};

                            if ((defined $$evp{$function}{new}{$col}) &&
								(defined $$evp{$function}{ref}{$col})) {
								$pwr_stat = $$evp{$function}{ref}{$col};
                                $pwr_func = $$evp{$function}{new}{$col};

								# Adjust power data to eliminate rounding diffs
								$pwr_stat = roundoff ($pwr_stat, STAT_PREC);
								$pwr_func = roundoff ($pwr_func, STAT_PREC);
                            } else {
								$pwr_func = UNKNOWN;
								$pwr_stat = UNKNOWN;
                            }

							# Compute delta
							calcPowerDelta ($pwr_stat, $pwr_func,
											$abs_diff_threshold, $pct_diff_threshold,
											\$max_abs, \$max_pct,
											\$summ_flag, \$out_line);
                        }

						# Dump regular and (conditionally) summary output
                        writeOutLine (*RESULT, *SUMMFILE, $summ_flag,
									  $line_hier, $max_abs, $max_pct,
									  \$out_line, \$out_count, \$summ_count);
						$fub_summ_flag ||= $summ_flag;
					}

 					# Compare total power of this FUB in new and ref files
 					$out_line = "";
					$line_hier = "~TOTAL~\t$fub\t$unit\t$cluster\t$location";
 					$totals = \%{$$rollup{$location}{$cluster}{$unit}{$fub}{"~TOTAL~"}};
 					writeTotalDiffs ($totals, $trace_names, $indcols,
 									 $abs_diff_threshold, $pct_diff_threshold,
 									 $line_hier, \$out_line, \$out_count, \$summ_count,
									 $fub_summ_flag, *RESULT, *SUMMFILE);
					$unit_summ_flag ||= $fub_summ_flag;
                }

				# Compare total power of this unit in new and ref files
				$out_line = "";
				$line_hier = "~TOTAL~\t~TOTAL~\t$unit\t$cluster\t$location";
				$totals = \%{$$rollup{$location}{$cluster}{$unit}{"~TOTAL~"}};
				writeTotalDiffs ($totals, $trace_names, $indcols,
								 $abs_diff_threshold, $pct_diff_threshold,
								 $line_hier, \$out_line, \$out_count, \$summ_count,
								 $unit_summ_flag, *RESULT, *SUMMFILE);
				$clus_summ_flag ||= $unit_summ_flag;
            }

			# Compare total power of this cluster in new and ref files
			$out_line = "";
			$line_hier = "~TOTAL~\t~TOTAL~\t~TOTAL~\t$cluster\t$location";
			$totals = \%{$$rollup{$location}{$cluster}{"~TOTAL~"}};
			writeTotalDiffs ($totals, $trace_names, $indcols,
							 $abs_diff_threshold, $pct_diff_threshold,
							 $line_hier, \$out_line, \$out_count, \$summ_count,
							 $clus_summ_flag, *RESULT, *SUMMFILE);
			$loc_summ_flag ||= $clus_summ_flag;
        }

		# Compare total power of this location in new and ref files
		$out_line = "~TOTAL~\t~TOTAL~\t~TOTAL~\t~TOTAL~\t$location";
		$totals = \%{$$rollup{$location}{"~TOTAL~"}};
		writeTotalDiffs ($totals, $trace_names, $indcols,
						 $abs_diff_threshold, $pct_diff_threshold,
						 $line_hier, \$out_line, \$out_count, \$summ_count,
						 $loc_summ_flag, *RESULT, *SUMMFILE);
    }
	######################################################################

    close RESULT;
	close SUMMFILE;

    # system "gzip -f9 $out_file";  # gzip results
    print STDOUT "-I- Total entries written to $out_file: $out_count\n";
    print STDOUT "-I- Threshold violations written to $summ_file: $summ_count\n";

	return $summ_count;
}


######################################################################
# Round to N digits
######################################################################
sub roundoff {
	my ($indata, $digits) = @_;
	my $precision = 10 ** $digits;
	my $outdata = int ($indata * $precision + 0.5) / $precision;
	return $outdata;
}


######################################################################
# Compare totals from ref and new files
# Print the full diffs between totals to the output file, and rows
# with significant diffs (> abs or % threshold) to summary file
######################################################################
sub writeTotalDiffs {
	my ($totals, $trace_names, $indcols, 
		$abs_diff_threshold, $pct_diff_threshold,
		$line_hier, $out_line_p, $out_count_p, $summ_count_p,
		$summ_flag, $RES_p, $SUMM_p) = @_;

	my ($delta, $growth, $max_delta, $max_growth) = (0, 0, 0, 0);
	for (my $colnum=$indcols; $colnum <= $#{$trace_names}; $colnum++) {
		my $col = $$trace_names[$colnum];

		if ((defined $$totals{new}{$col}) &&
			(defined $$totals{ref}{$col})) {
			calcPowerDelta ($$totals{ref}{$col}, $$totals{new}{$col},
							$abs_diff_threshold, $pct_diff_threshold,
							\$max_delta, \$max_growth,
							\$summ_flag, $out_line_p);
		}
	}

	writeOutLine ($RES_p, $SUMM_p, $summ_flag,
				  $line_hier, $max_delta, $max_growth,
				  $out_line_p, $out_count_p, $summ_count_p);
}


######################################################################
# Compute delta (abs diff) and growth (pct diff) between new and
# ref power values
# Also, update max of delta and pct diffs if needed
######################################################################
sub calcPowerDelta {
	my ($pwr_stat, $pwr_func, $abs_diff_threshold, $pct_diff_threshold,
		$max_delta, $max_growth, $summ_flag_p, $out_line_p) = @_;

	my ($delta, $growth) = (0, 0);

	if (($pwr_func eq UNKNOWN) || ($pwr_stat eq UNKNOWN)) {
		$delta = UNCALC;
		$growth = UNCALC;
		$$out_line_p .= "\t$pwr_func\t$pwr_stat\t$delta\t$growth";
	} else {
		# Compute diffs, both abs and pct
		$delta = abs ($pwr_func - $pwr_stat);
		if ($pwr_stat == 0) {	# avoid zero-divide
			if ($delta == 0) {
				$growth = 0;	# exclude from summary
			} else {
				$growth = 100;	# trigger inclusion in summary
			}
		} else {
			# Calculate growth %
			$growth = $delta / $pwr_stat * 100;
		}

		# If thresholds violated, set summary flag
		if (($delta eq UNCALC) ||
			($delta > $abs_diff_threshold) ||
			($growth > $pct_diff_threshold)) {
			$$summ_flag_p = 1;
			if ($$max_delta < $delta) {
				$$max_delta = $delta;
			}
			if ($$max_growth < $growth) {
				$$max_growth = $growth;
			}
		}

		$$out_line_p .= sprintf ("\t%.6f\t%.6f\t%.6f\t%.6f",
								 $pwr_func, $pwr_stat, $delta, $growth);
	}
}


######################################################################
# Write out the given string to the result file
# If summ_flag != 0, write it out to the summary file
# Increment output and summary line counts
######################################################################
sub writeOutLine {
	my ($RES_p, $SUMM_p, $summ_flag, $line_hier, $max_delta, $max_growth,
		$out_line_p, $out_count_p, $summ_count_p) = @_;

	print $RES_p "$line_hier\t$max_delta\t$max_growth" . "$$out_line_p\n";
	$$out_count_p++;
	if ($summ_flag) {
		print $SUMM_p "$line_hier\t$max_delta\t$max_growth" . "$$out_line_p\n";
		$$summ_count_p++;
	}
}

__END__

=pod

=head1 NAME

diff_alps_keiko_power    diffs power between two sets of input files: Alps power_txt_output_functions*.xls, and list of Keiko stats files.  Note that it can also diff two Alps files, or two sets of Keiko stats files.

=head1 SYNOPSIS

perl B<diff_alps_keiko_power.pl> [I<options>] B<--new> I<NEW> B<--ref> I<REF> B<--ofile> I<OUTFILE> B<--summary> I<SUMMFILE> B<--indcols> I<NUMCOLS>  B<--absdiff> I<ABSDIFF_THRESHOLD>  B<--pctdiff> I<PCTDIFF_THRESHOLD>

=head1 DESCRIPTION

B<diff_alps_keiko_power> reads in the given I<NEW> file(s), matches the functions to the I<REF> file(s) and performs a diff.
Each input file argument could be either a single power_txt_output_functions*.xls file output by alps.pl, or a "glob" expression for a set of Keiko stats files.  In either case, the results show the absolute and % diffs between the I<NEW> and the I<REF> files per stats file.
Results are in a compressed tab separated file.

=head1 OPTIONS

=over 7

=item B<--new> I<NEW>

Path to I<NEW> file (e.g. ./power_txt_output_functions.ww35_bdw.capacitance.xls.gz)

=item B<--ref> I<REF>

Path to I<REF> file (e.g., "./hsw_client/*.stats.gz")
Note that the list of stats files must be enclosed in double quotes in order to avoid shell filename expansion that could result in "arg list too long" errors.

=item B<--ofile> I<OUTFILE>

Path to I<OUTFILE> file (e.g., ./alps_diff_func.xls)

=item B<--summary> I<SUMMFILE>

Path to I<SUMMFILE> file. If not specified, the default will be I<OUTFILE> with "-summ" appended to the basename (e.g., ./alps_diff_func_summ.xls)

=item B<--indcols> I<NUMCOLS>

Number of columns to ignore; these are the first few (left-most) columns of indicators in the Alps power_txt_output_functions*.xls file

=item B<--absdiff> I<ABSDIFF_THRESHOLD>

User-specified threshold for absolute difference in power numbers that triggers inclusion of a diff. Default threshold = 0.001 pF

=item B<--pctdiff_threshold> I<PCTDIFF_THRESHOLD>

User-specified threshold for percent difference in power numbers that triggers inclusion of a diff. Default threshold = 0.1%

=item B<--man>

Prints man page

=item B<--help>

Prints help

=back

=head1 AUTHOR

Mosur Mohan <mosur.mohan@intel.com>

=head1 DIAGNOSTICS

=over 4

=item -I-

Program status or information.

=item -E-

Program error. Script might not finish successfully.

=item -F-

Fatal error. Script cannot continue.

=back

=head1 BUGS

Report bugs to <B<mosur.mohan@intel.com>>.

=head1 COPYRIGHT

Copyright (C) Intel Corporation 2008  Mosur Mohan
Licensed material -- Program property of Intel Corporation
All Rights Reserved

This program comes with ABSOLUTELY NO WARRANTY.

=cut
