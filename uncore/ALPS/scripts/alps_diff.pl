#!/usr/intel/bin/perl
# name: alps_diff
# date: 15sep2008
# mod : 15sep2008  jecassis  1.0
# ver:  1.0
# auth: Jimmy Cassis
# desc: diffs energy costs (EC) and/or power between BDW and SNB
#       from the outputs of alps.pl
# proj: Haswell/Broadwell

# Explicitly force glob to execute this function because of a
# bug wherein the 1st call to glob within the 2nd invocation of a sub
# returns null (as happens within readFile below)
use File::Glob "glob";
use FindBin qw($Bin $Script $RealBin $RealScript $Dir $RealDir);

#### libraries
use lib $RealBin;
use lib (glob "~/Alps/trunk");
require 'utilities.pm';
require 'systemTime.pm';

#### pragmas
use strict;
use warnings;

#### system vars
$| = 1;

#### program vars
our ($opt_man, $opt_help) = ();
my ($bdw, $snb, $output, $max_diff, @include) = ();
my $leakage = 1;
my $active = 0;
my $ratio = 0;
my $script = $0;
$script =~ s/(^.*\/)//;
my $dir = $1 || ".";
my $proj = $ENV{PROJECT} || 'bdw';
my $ver = '1.0';
my $dataset = "";			  # track input file type (fubs/functions)

my %traces2rpt = ();
my @col_names = ();

#### constants
use constant UNKNOWN => 'UNKNOWN';
use constant UNAVAIL => '';
use constant UNCALC  => '';
use constant INF     => '';

#### modules
use Pod::Usage;
use Getopt::Long;
$Getopt::Long::ignorecase = 1;
$Getopt::Long::autoabbrev = 1;

GetOptions('new=s'     => \$bdw,
           'ref=s'     => \$snb,
           'output=s'  => \$output,
           'maxdiff=s' => \$max_diff,
           'include=s' => \@include,
           'leakage!'  => \$leakage,
           'active'    => \$active,
           'ratio'     => \$ratio,
           'man',
           'help') || die "Try `perl $script -help' for more information.\n";

#### main
my $start_time = time;
checkArgs();  # Check command-line arguments
map { s/[\'\"]//g } @include;		# Strip quotes from traces regexp
@include = map { qr/$_/i } split(/,/,join(',',@include));

# Extract experiment name from bdw and snb files
# -- disabled, doesn't work well for other (non-bdw/snb) diff situations
# $bdw =~ /^.*\/?.+\.(.+)\..+\.xls(\.gz)?$/;
my $bdw_exp = 'new';
# $snb =~ /^.*\/?.+\.(.+)\..+\.xls(\.gz)?$/;
my $snb_exp = 'ref';

my ($splitFcn, $writeFcn, %events, $title) = ();

# Verify both input file names of same type
# Assign the function pointers to parse the correct format
# Specify the default output file name
if ($bdw =~ /fubs/i && $snb =~ /fubs/i) {
	$dataset = "fubs";
    $output ||= "alps_diff_fubs.xls";
    $splitFcn = \&fubSplit;
    $writeFcn = \&evalResults;
} elsif ($bdw =~ /functions/i && $snb =~ /functions/i) {
	$dataset = "functions";
    $output ||= "alps_diff_func.xls";
    $splitFcn = \&funcSplit;
    $writeFcn = \&evalResults;
} else {
    die "-F- Could not proceed because input files are not of the same type (i.e. power_txt_output_[functions|fubs]). Exiting.\n";
}

# Assume only default columns if none specified
if (! @include) {
    push @include, 'ZYXW';
}

# Read in both files
readFile ($bdw, $bdw_exp, \%events, \@include, \@col_names, \%traces2rpt);
readFile ($snb, $snb_exp, \%events, \@include, \@col_names, \%traces2rpt);

# Gather list of traces common to both expts that are in the include list
getTracesToReport ($bdw_exp, $snb_exp, \%traces2rpt, \$title, $dataset);

# Write results
writeOutput ($output, $bdw_exp, $snb_exp, \%events, \%traces2rpt, \$title, $dataset);

exit 0;

#### end_main

#### subroutines

# Check command-line arguments
sub checkArgs {
	# Launch help and exit
    pod2usage(-exitval => 1, -verbose => 1, -output => \*STDOUT) if ($opt_help);

	# Launch man page and exit
    pod2usage(-exitval => 1, -verbose => 2, -output => \*STDOUT) if ($opt_man);

    # Check that both required input files are given
    my $kill = 0;
    if (! defined $bdw) {
        print STDERR "-E- Please specify a file with -new switch.\n";
        $kill = 1;
    }
    if (! defined $snb) {
        print STDERR "-E- Please specify a file with -ref switch.\n";
        $kill = 1;
    }

    # If any of the checks failed, cannot continue
    if ($kill == 1) {
        die "-F- Could not proceed without input files. Exiting.\n";
    }
}

# Wrapper for the type-specific parse function
# Opens the file to read and iterates through it
# Closes the file after parsing is completed
sub readFile {
    my ($file, $prj, $eventsref, $inc_regexp, $col_names, $traces2rpt) = @_;
	my %indices = ();

    my $afile = glob($file);
    print STDOUT "-I- Reading $afile\n";
    openl("FILE", "< $afile") || die "-F- Cannot open $afile: $!\n";
    while(<FILE>) {
        next if (/^\s*IPC/i);  # TODO: extract IPC here
        chomp;
        &$splitFcn($_, $prj, $eventsref, $inc_regexp, \%indices, $col_names, $traces2rpt);
    }
    close FILE;
}


# power_txt_output_fubs specific function to parse the files
sub fubSplit {
    my ($line, $expt, $event, $trace_regexp, $indicesp, $col_names, $traces2rpt) = @_;

    # Separate the fields based on tabs
	$line =~ s/\cM//g;			# remove pesky ctrl-Ms
    my ($fub, $unit, $cluster, $location, @columns) = split /\t/, $line;

	# Downcase all block names
	$fub =~ tr/A-Z/a-z/;
	$unit =~ tr/A-Z/a-z/;
	$cluster =~ tr/A-Z/a-z/;
	$location =~ tr/A-Z/a-z/;

    if ($line =~ /^\s*Fub/i) {
		# Save column names
		@{$col_names} = @columns;

		# search the columns for the indices in @trace of "--include" option
        traceSearch($expt, $trace_regexp, $col_names, $indicesp, $traces2rpt);
    }
	else {
		# extract idle by default
		# note: 'xyz' is file type marker for power_txt_output_fubs file type
        ####mkm $$event{$location}{$cluster}{$unit}{$fub}{'xyz'}{'-1'}{$expt} = $idle;

        foreach my $colnum (sort numerically keys %{$$indicesp{$expt}}) {
            # Check @traces array bounds before assignment
			if ($colnum <= $#{$col_names}) {
				my $col_name = $$col_names[$colnum];
				$$event{$location}{$cluster}{$unit}{$fub}{'__fubdata__'}{$col_name}{$expt} = $columns[$colnum];
			}
        }
    }
}


# power_txt_output_functions specific function to parse the files
sub funcSplit {
    my ($line, $expt, $event, $trace_regexp, $indicesp, $col_names, $traces2rpt) = @_;

    return if ($line =~ /^\s*Leakage/i && ! $leakage);  # skip leakage

    # Separate the fields based on tabs
	$line =~ s/\cM//g;			# remove pesky ctrl-Ms
    my ($function, $fub, $unit, $cluster, $location, @columns) = split /\t/, $line;

	# Downcase all block names
	$fub =~ tr/A-Z/a-z/;
	$unit =~ tr/A-Z/a-z/;
	$cluster =~ tr/A-Z/a-z/;
	$location =~ tr/A-Z/a-z/;

    if ($line =~ /^\s*Function/i) {
		# Save column names
		@{$col_names} = @columns;

		# search the columns for the indices in @trace of "--include" option
        traceSearch($expt, $trace_regexp, $col_names, $indicesp, $traces2rpt);
    }
	else {
		# extract EC by default
        ####mkm $$event{$location}{$cluster}{$unit}{$fub}{$function}{'-1'}{$expt} = $EC;

        foreach my $colnum (sort numerically keys %{$$indicesp{$expt}}) {
            # Check @traces array bounds before assignment
			if ($colnum <= $#{$col_names}) {
				my $col_name = $$col_names[$colnum];
				$$event{$location}{$cluster}{$unit}{$fub}{$function}{$col_name}{$expt} = $columns[$colnum];
			}
        }
    }
}


# Searches the column headers for the indices of the traces
# that match the regular expressions given through --include
sub traceSearch {
    my ($expt, $trace_regexp, $tracesref, $indicesref, $traces2rpt) = @_;

    if (@{$trace_regexp}) {
        my $counter = 0;  # keeps track of index number in tracesref array
        foreach my $trace (@{$tracesref}) {  # iterate through traces
			# First, apply the "--exclude" rule, it has priority over "--include"
			if ($trace !~ /ec|ec_formula|comment|power_section/i) {
				# Got past "--exclude"
				foreach (@{$trace_regexp}) {
					# iterate through command-line "--include" entries
					my $name_rex = qr/$_/i;
					if ($trace =~ /$name_rex/) {
						$$indicesref{$expt}{$counter} = $trace;
						$$traces2rpt{expt}{$expt}{$trace} = 1;
						last;
					}
				}
			}
			$counter++;
		}
	}

    # Fail if no indices found due to no column name matches
    unless (keys %{$$indicesref{$expt}} || $$trace_regexp[0] eq 'ZYXW') {
        print STDERR "-F- No columns matching the regular expressions: ";
        foreach (@{$trace_regexp}) {
            print STDERR "$_, ";
        }
        print STDERR "\b\b can be found.\n";
        exit 1;
    }
}


# Gather list of traces common to both expts that are in the include list
sub getTracesToReport {
	my ($expt1, $expt2, $traces2rpt, $titleref, $dataset) = @_;

	if ($dataset eq "fubs") {
		$$titleref = "Fub\tUnit\tCluster\tLocation";
	} else {
		$$titleref = "Function\tFub\tUnit\tCluster\tLocation";
	}

	# Collect list of traces common to both files
	foreach my $trace (keys %{$$traces2rpt{expt}{$expt1}}) {
		if (exists $$traces2rpt{expt}{$expt2}{$trace}) {
			$$traces2rpt{final}{$trace} = 1;
		}
	}

	# Sort trace names and add columns to title
	foreach my $trace (sort keys %{$$traces2rpt{final}}) {
		$$titleref .= "\tPower->${expt1}->${trace}\tPower->${expt2}->${trace}";

		if ($ratio) {			# ratio or growth
			$$titleref .= "\tdelta->${trace}\tratio->${trace}";
		} else {
			$$titleref .= "\tdelta->${trace}\tgrowth->${trace}";
		}
	}
	$$titleref .= "\n";
}


# Wrapper function to print the outputs
# Calls the function to print the results to the output file
# Calls the function to print the max and min differences
sub writeOutput {
    my ($output, $expt_bdw, $expt_snb, $eventsref, $traces2rpt, $titleref) = @_;

    # Initialize max_diff hash
    my %max_diff = ('max_delta'  => 0,
                    'max_growth' => 0,
                    'max_ratio'  => 0,
                    'min_delta'  => 0,
                    'min_growth' => 0,
                    'min_ratio'  => 0);

	$output = glob($output); 
    print STDOUT "-I- Writing output to $output and compressing.\n";
    open(RESULT, "> $output") || die "-F- Cannot open $output: $!\n";
    &$writeFcn($expt_bdw, $expt_snb, $eventsref, $traces2rpt, $titleref, \%max_diff);
    close RESULT;
    finalTime($start_time);  # calculate runtime
    system "gzip -f9 $output";  # gzip results
    print STDOUT "-I- Results written to $output.gz\n";
    printMaxDiff(\%max_diff);  # print %max_diff after updated in writeFcn
}


# Function that calculates the growth and deltas and print
# the results file
sub evalResults {
    my ($expt_bdw, $expt_snb, $event, $traces2rpt, $titles, $max_diffref) = @_;

    print RESULT $$titles;  # print title line

    # Iterate through the %event hash hierarchy
    foreach my $location (sort keys %{$event}) {
        foreach my $cluster (sort keys %{$$event{$location}}) {
            foreach my $unit (sort keys %{$$event{$location}{$cluster}}) {
                foreach my $fub (sort keys %{$$event{$location}{$cluster}{$unit}}) {
                    foreach my $function (sort keys %{$$event{$location}{$cluster}{$unit}{$fub}}) {

                        # '__fubdata__' in the function field is a marker for
						# power_txt_output_fubs file type
                        if ($function =~ /__fubdata__/) {
                            print RESULT "$fub\t$unit\t$cluster\t$location";
                        } else {
                            print RESULT "$function\t$fub\t$unit\t$cluster\t$location";
                        }

                        foreach my $colname (sort keys %{$$traces2rpt{final}}) {

                            my ($Pwr_bdw, $Pwr_snb, $delta, $growth,
								$fail_bdw, $fail_snb) = ();

                            if (defined $$event{$location}{$cluster}{$unit}{$fub}{$function}{$colname}{$expt_bdw}) {
                                $Pwr_bdw = $$event{$location}{$cluster}{$unit}{$fub}{$function}{$colname}{$expt_bdw};
                                if ($active && ($colname !~ /Idle/)) {
									# Active = Total - Idle
                                    $Pwr_bdw -= $$event{$location}{$cluster}{$unit}{$fub}{$function}{'Idle'}{$expt_bdw};
                                }
                            } else {
                                if ($function =~ /Idle/i || $function =~ /Leakage/i) {
									# Idle and Leakage no activity stats
                                    $Pwr_bdw = UNAVAIL;
                                } else {
                                    $Pwr_bdw = UNKNOWN;
                                }
                                $fail_bdw = 1;  # fail flag assert
                            }

                            if (defined $$event{$location}{$cluster}{$unit}{$fub}{$function}{$colname}{$expt_snb}) {
                                $Pwr_snb = $$event{$location}{$cluster}{$unit}{$fub}{$function}{$colname}{$expt_snb};
                                if ($active && ($colname !~ /Idle/)) {
									# Active = Total - Idle
                                    $Pwr_snb -= $$event{$location}{$cluster}{$unit}{$fub}{$function}{'Idle'}{$expt_snb};
                                }
                            } else {
                                if ($function =~ /Idle/i || $function =~ /Leakage/i) {
									# Idle and Leakage no activity stats
                                    $Pwr_snb = UNAVAIL;
                                } else {
                                    $Pwr_snb = UNKNOWN;
                                }
                                $fail_snb = 1;  # fail flag assert
                            }

                            if ($fail_bdw || $fail_snb) {  # check fail flags
                                $delta = UNCALC;
                                $growth = UNCALC;
                            } else {
                                $delta = abs ($Pwr_bdw - $Pwr_snb);  # delta calculation
                                if ($Pwr_snb == 0) {
                                    if ($delta == 0) {
                                        if ($ratio) {
                                            $growth = 1;  # define '0 / 0' as 1
                                        } else {
                                            $growth = 0;  # define '(0 - 0) / 0' as 0
                                        }
                                    } else {
                                        $growth = INF;  # infinity
                                    }
                                } else {
                                    if ($ratio) {  # ratio or growth
										# calculate ratio
                                        $growth = $Pwr_bdw / $Pwr_snb;

                                        # Compare against max and min ratios so far
                                        if ($growth > $$max_diffref{'max_ratio'}) {
                                            $$max_diffref{'max_ratio'} = $growth;
                                        } elsif ($growth < $$max_diffref{'min_ratio'}) {
                                            $$max_diffref{'min_ratio'} = $growth;
                                        }
                                    } else {
										# calculate growth %
                                        $growth = $delta / $Pwr_snb * 100;

                                        # Compare against max and min growth % so far
                                        if ($growth > $$max_diffref{'max_growth'}) {
                                            $$max_diffref{'max_growth'} = $growth;
                                        } elsif ($growth < $$max_diffref{'min_growth'}) {
                                            $$max_diffref{'min_growth'} = $growth;
                                        }
                                    }
                                }

                                # Compare against max and min delta so far
                                if ($delta > $$max_diffref{'max_delta'}) {
                                    $$max_diffref{'max_delta'} = $delta;
                                } elsif ($delta < $$max_diffref{'min_delta'}) {
                                    $$max_diffref{'min_delta'} = $delta;
                                }
                            }

                            print RESULT "\t$Pwr_bdw\t$Pwr_snb\t$delta\t$growth";
                        }
                        print RESULT "\n";
                    }
                }
            }
        }
    }
}

# Prints max and min differences
sub printMaxDiff {
    my $max_diffref = shift;

    # Select stream based on command-line option --maxdiff
    if (defined $max_diff) {
		$max_diff = glob ($max_diff); 
        openl("MAX_DIFF", "> $max_diff") || die "-F- Cannot open $max_diff: $!\n";
        select MAX_DIFF;
    } else {
        select STDOUT;
    }

    # Print information
    print "Summary of differences:\n";
    printf "o Max delta:\t%.3f\n", $$max_diffref{'max_delta'};
    if ($ratio) {
        printf "o Max ratio:\t%.3f\n", $$max_diffref{'max_ratio'};
    } else {
        printf "o Max growth:\t%.3f%%\n", $$max_diffref{'max_growth'};
    }
    printf "o Min delta:\t%.3f\n", $$max_diffref{'min_delta'};
    if ($ratio) {
        printf "o Min ratio:\t%.3f\n", $$max_diffref{'min_ratio'};
    } else {
        printf "o Min growth:\t%.3f%%\n", $$max_diffref{'min_growth'};
    }

    # Revert to STDOUT stream if changed and close file
    if (defined $max_diff) {
        close MAX_DIFF;
        select STDOUT;
        print STDOUT "-I- Differences summary written to $max_diff\n";
    }
}

__END__

=pod

=head1 NAME

alps_diff    diffs energy costs (EC) and/or power between BDW and SNB from the outputs of alps.pl

=head1 SYNOPSIS

perl B<alps_diff.pl> [I<options>] B<-new> I<NEW> B<-ref> I<REF>

=head1 DESCRIPTION

B<alps_diff> reads in the given I<NEW> file, matches the functions or fubs to the I<REF> file and performs a diff.
When running on 'power_txt_output_functions' files, the EC is extracted for each function as well as the total powers;
while, when running on 'power_txt_output_fubs' files, idle power for each fub is extracted as well as the total powers.
Results are in a compressed tab separated file.

=head1 OPTIONS

=over 7

=item B<--new>=I<NEW>

Path to I<NEW> file (e.g. ./power_txt_output_functions.ww35_bdw.capacitance.xls.gz)

=item B<--ref>=I<REF>

Path to I<REF> file (e.g. ./power_txt_output_functions.ww35_snb.capacitance.xls.gz)

=item B<--out>=I<OUT>

Path to I<OUT> file (e.g. ./alps_diff_func.xls)

=item B<--maxdiff>=I<MAX_DIFF>

Path to I<MAX_DIFF> file. If not specified, the default will be STDOUT

=item B<--include>='I<TRACE1,TRACE2,...,TRACEN>'

Names of the columns to diff, as a comma separated list of regular expressions inside tick marks. To select all columns use '.*' (do not forget the tick marks!). If nothing is specified, only Idle or EC will be diffed

=item B<--noleakage>

When running on a 'power_txt_output_functions' files, does not print the leakage lines in the results

=item B<--active>

When running on a 'power_txt_output_fubs' files, prints the active power ('total - idle') in the results (except in the Idle columns, of course)

=item B<--ratio>

Calculates and prints ratios of 'NEW / REF' values instead of the default '(NEW - REF) / REF * 100' growth percentage

=item B<--man>

Prints man page

=item B<--help>

Prints help

=back

=head1 REQUIRES

utilities.pm, systemTime.pm

=head1 AUTHOR

Jimmy Cassis <jimmy.e.cassis@intel.com>

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

Report bugs to <B<jimmy.e.cassis@intel.com>>.

=head1 COPYRIGHT

Copyright (C) Intel Corporation 2008  Jimmy Cassis
Licensed material -- Program property of Intel Corporation
All Rights Reserved

This program comes with ABSOLUTELY NO WARRANTY.

=cut
