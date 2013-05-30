#!/usr/intel/bin/perl
# name: diff_alps_keiko_formulas.pl
# date: 10-Feb-2009
# auth: Mosur Mohan
#
# ver:  0.1
# desc: Check whether input power formulas (from ALPS/formulas/...)
#		match the Keiko power_formulas.*.formulas output by alps.pl
# proj: Haswell/Broadwell for initial deployment

#### pragmas
use strict;
use warnings;

#### system vars
$| = 1;		   ## Flush after every write or print
			   ## Useful during debugging, turn off for production use

#### constants
use constant UNKNOWN => 'UNKNOWN';
use constant UNCALC  => '';
use constant STAT_PREC => 0.000001; # precision of stat file numbers

#### modules
use Pod::Usage;
use Getopt::Long;
$Getopt::Long::ignorecase = 1;
$Getopt::Long::autoabbrev = 1;

#### program vars and command-line args
our ($opt_man, $opt_help) = ();
my ($keiko_formula_file, $alps_ffile_list, $out_file, $summ_file) = ();
my $script_name = $0;
$script_name =~ s/(^.*\/)//;

GetOptions('keikoffile=s'  => \$keiko_formula_file,
		   'alpsfflist=s' => \$alps_ffile_list,
           'ofile=s'   => \$out_file,
           'summary=s' => \$summ_file,
           'man',
           'help') || die "Try `perl $script_name -help' for more information.\n";


# Keiko and Alps formula files match list of event names when:
# 1. (flush-lines "\\.\\(idle\\|active\\|total\\)\\.power ")
# 2. Remove the "Template" column (no templates in Keiko file)
# 3. Remove columns beyond event name
# 4. Sort and uniquify (Alps file may have lines from multiple insts)

######################################################################
######################################################################
# Old stuff from func_stat_diff.pl, largely to be junked
######################################################################
######################################################################

# Hash to hold all the event-level power data, with structure looking like:
# $events{$location}{$cluster}{$unit}{$fub}{$function} = 1
my %events = ();


######################################################################
#### main
######################################################################

checkArgs();  # Check command-line arguments

# Read in both files
readKeikoFormulaFile ($keiko_formula_file, \%events);
readAlpsFFileList ($alps_ffile_list, \%events);

# Compute diffs and write out results
if ((! defined $summ_file) || ($summ_file eq "")) {
	$summ_file = $out_file;
	$summ_file =~ s/\.xls$/_summ.xls/;
}

my $retval = writeOutput ($out_file, $summ_file, \%events);


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
    if (! defined $keiko_formula_file) {
        print STDERR "-E- Please specify a file with -keikoffile switch.\n";
        $kill = 1;
    }
    if ($alps_ffile_list eq "") {
        print STDERR "-E- Please specify stat files with -alpsfflist switch.\n";
        $kill = 1;
    }

    # If any of the checks failed, cannot continue
    if ($kill == 1) {
        die "-F- Could not proceed. Exiting.\n";
    }
}


######################################################################
# Read in the formulas from the Keiko formula file
######################################################################
sub readKeikoFormulaFile {
    my ($cffile, $events_p) = @_;
    $cffile = glob($cffile);
    print STDOUT "-I- Reading $cffile\n";
	if ($cffile =~ /\.gz$/) {
		open ("KEIKOFILE", "gzcat $cffile |") ||
		  die "-F- Cannot open $cffile: $!\n";
	} else {
		open ("KEIKOFILE", "< $cffile") ||
		  die "-F- Cannot open $cffile: $!\n";
	}

    while (my $line = <KEIKOFILE>) {
        if ($line =~ /^(\s*)$|^(\S*\.(Idle|Active|Total)\.power\s*:)/) {
			# Skip non-event entries, or blank lines
			next;
		}
        chomp $line;
		$line =~ s/\.power\s*:.*$//; # Strip out everything after the function name

        # Separate the fields based on periods
        my ($p0, $location, $cluster, $unit, $fub, $function, @funclist) = ();

		# Special handling of p0.llcbo0 -> p0.llcbo0.uncore to sync with Alps
		$line =~ s/^p0\.llcbo0\./p0.llcbo0.uncore./i;

		my @fields = split (/\./, $line);
		if ($fields[0] =~ /p[0-9]/) {
			($p0, $location, $cluster, $unit, $fub, @funclist) = @fields;
		} else {
			($location, $cluster, $unit, $fub, @funclist) = @fields;
		}

		$function = join (".", @funclist);

		if ($location eq "c0") {
			$location = "core";
		}

        $$events_p{$location}{$cluster}{$unit}{$fub}{func}{$function} |= 1;
		if (! defined $$events_p{$location}{$cluster}{$unit}{$fub}{cfile}) {
			$$events_p{$location}{$cluster}{$unit}{$fub}{cfile} = $cffile;
		}
    }
    close KEIKOFILE;
}


######################################################################
# Read in formulas from the list of formula files
######################################################################
sub readAlpsFFileList {
	my ($alps_ffile_list, $events_p) = @_;

	# Read filenames from formula_file_list
	$alps_ffile_list = glob ($alps_ffile_list);
	open (FFLIST, $alps_ffile_list) ||
	  die ("Can't open formula file list \"$alps_ffile_list\": $!\n");
    print STDOUT "-I- Reading $alps_ffile_list\n";

	my $affile_dir = $alps_ffile_list;
	if ($affile_dir =~ /(.+)\/[^\/]+$/) {
		$affile_dir = $1;
	}

	# Open each filename contained in the formulas_file_list file
	while (my $ffname = <FFLIST>) {
		chomp $ffname;

		if ($ffname =~ /\.leakage\./) {
			# Skip leakage files
			next;
		}

		$ffname =~ s/\r$//;
		if ($ffname !~ /^[\/~]/) {
			$ffname = $affile_dir . "/" . $ffname;
		}

		# Load all events from formulas file
		readAlpsFormulaFile ($ffname, $events_p);
	}

	close (FFLIST);
}


######################################################################
# Read in the formulas from one formulas file
######################################################################
sub readAlpsFormulaFile {
	my ($ffname, $events_p) = @_;

	my (@colNames, @funcIndices, %colNameMap) = ();

	open (FFILE, $ffname) || die ("Can't open formula file \"$ffname\": $!\n");
    print STDOUT "-I- Reading $ffname\n";

	while (my $fline = <FFILE>) {
		chomp $fline;

		if ($fline =~ /^Fub\t/) {
			# Header line: grab column names
			@colNames = split (/\t/, $fline);

			# Get indices of function name columns, remembering that
			# +  core formula files have 1 function column per line
			# +  uncore files have multiple <Function_i> columns
			# Also, get indices of hierarchy columns
			for (my $i = 0; $i < $#colNames; $i++) {
				my $col = $colNames[$i];
				$col =~ tr/A-Z/a-z/;
				$colNameMap{$col} = $i;
				if ($col =~ /^function/) {
					push (@funcIndices, $i);
				}
			}

			# Check that hierarchy properly present, else die
			if (! ((defined $colNameMap{fub}) &&
				   (defined $colNameMap{unit}) &&
				   (defined $colNameMap{cluster}) &&
				   (defined $colNameMap{location}) &&
				   ($#funcIndices >= 0))) {
				die ("Hierarchy elements or function missing from formula file \"$ffname\".\n");
			}
		} else {
			# Data line
			my @fields = split (/\t/, $fline);

			# Mimic alps.pl behavior per implement_updates_to_formulas
			# Remove spaces (matching what alps.pl does)
			for (my $i = 0; $i <= $#fields; $i++) {
				$fields[$i] =~ s/^\s+//;
				$fields[$i] =~ s/\s+$//;
			}

			my $fub = lc ($fields[$colNameMap{fub}]);
			my $unit = lc ($fields[$colNameMap{unit}]);
			my $cluster = lc ($fields[$colNameMap{cluster}]);
			my $location = lc ($fields[$colNameMap{location}]);

			if (! ((defined($fub)) and ($fub ne "")) and
				((defined($unit)) and ($unit ne "")) and
				((defined($cluster)) and ($cluster ne "")) and
				((defined($location)) and ($location ne ""))) {
				# Skip this line, not well formed
				print STDOUT "-W- Skipping badly formed input line in $ffname: \"$fline\"\n";
				next;
			}

			# Mimic alps.pl behavior per output_Tomer_style

			# Strip trailing 0 from core location
			if ($location eq "core0") {
				$location = "core";
			}

			# Change uncore.uncore -> llcbo0.uncore to sync with Alps
			if ((lc($location) eq "uncore") && (lc($cluster) eq "uncore")) {
				$location = "llcbo0";
			}
			# Mimic alps.pl behavior per implement_updates_to_formulas
			# Change cluster==dsbfe or cluster/unit==dsb/fe to unit=dsb_fe 
			if ((($unit eq "dsb") and ($cluster eq "fe")) or
				($unit eq "dsbfe")) {
				$unit = "dsb_fe";
			}
			# Mimic alps.pl behavior per implement_updates_to_formulas
			# Handle spaces, special chars
			for my $vptr (\$location, \$cluster, \$unit, \$fub) {
				$$vptr =~ s/[\'\",\s\xa0]//g;
				$$vptr =~ s/-/_/g;
				$$vptr =~ s/[\(\)\[\]:]/_/g;
			}

			if (! defined $$events_p{$location}{$cluster}{$unit}{$fub}{afile}) {
				$$events_p{$location}{$cluster}{$unit}{$fub}{afile} = $ffname;
			}

			# Stuff each non-Idle function into hash
			for my $indx (@funcIndices) {
				my $func = $fields[$indx];
				if ((defined $func) && ($func ne "") && (lc($func) ne "idle")) {
					$func =~ s/[\'\",\s\xa0]//g;
					$func =~ s/-/_/g;
					$func =~ s/[\(\)\[\]:]/_/g;
					$$events_p{$location}{$cluster}{$unit}{$fub}{func}{$func} |= 2;
				}
			}
		}
	}

	close (FFILE);
}


######################################################################
# Spit out all mismatches between Alps and Keiko (Tomer) formula files
######################################################################
sub writeOutput {
	my ($out_file, $summ_file, $events_p) = @_;

	my $outStr = "Location\tCluster\tUnit\tFub\tKeiko_func\tAlps_func\tSource\n";
	my $fname = "";
	my ($missingAlpsFunc, $missingKeikoFunc) = (0, 0);

	foreach my $location (sort keys %$events_p) {
		foreach my $cluster (sort keys %{$$events_p{$location}}) {
			foreach my $unit (sort keys %{$$events_p{$location}{$cluster}}) {
				foreach my $fub (sort keys %{$$events_p{$location}{$cluster}{$unit}}) {
					foreach my $function (sort keys %{$$events_p{$location}{$cluster}{$unit}{$fub}{func}}) {
						my $funcVal = $$events_p{$location}{$cluster}{$unit}{$fub}{func}{$function};
						if ($funcVal != 3) {
							# Something missing
							$outStr .= "$location\t$cluster\t$unit\t$fub\t";
							if ($funcVal & 1) { # Valid Keiko function
								$fname = $$events_p{$location}{$cluster}{$unit}{$fub}{cfile};
								$outStr .= "$function\t\t$fname\n";
								$missingAlpsFunc++;
							} else { # Valid Alps function
								$fname = $$events_p{$location}{$cluster}{$unit}{$fub}{afile};
								$outStr .= "\t$function\t$fname\t\n";
								$missingKeikoFunc++;
							}
						}
					}
				}
			}
		}
	}

	if ($missingAlpsFunc + $missingKeikoFunc > 0) {
		print STDOUT "-I- Writing $missingAlpsFunc missing Alps functions + $missingKeikoFunc missing Keiko functions to $out_file, and summary to $summ_file\n";

		$out_file = glob ($out_file);
		open (OUTF, "> $out_file") || die "-F- Cannot open $out_file: $!\n";
		print OUTF $outStr;
		close (OUTF);

		$summ_file = glob ($summ_file);
		open (SUMM, "> $summ_file") || die "-F- Cannot open $summ_file: $!\n";
		print SUMM "Missing Alps functions = $missingAlpsFunc\n";
		print SUMM "Missing Keiko functions = $missingKeikoFunc\n";
		close (SUMM);
	} else {
		print STDOUT "-I- All Alps and Keiko formulas matched.\n";
	}

	return ($missingAlpsFunc + $missingKeikoFunc);
}


__END__

=pod

=head1 NAME

diff_alps_keiko_formulas    diffs power fevent energy cost (EC) and/or power between  BDW and SNB from the outputs of alps.pl

=head1 SYNOPSIS

perl B<diff_alps_keiko_formulas.pl> [I<options>] B<--alpsfflist> I<ALPSFILELIST> B<--keikoffile> I<KEIKOFILE> B<--ofile> I<OUTPUTFILE> B<--summary> I<SUMMARYFILE>

=head1 DESCRIPTION

B<diff_alps_keiko_formulas> reads in the given I<ALPSFILELIST> file, matches the event names to those in the I<KEIKOFILE> formula file, and reports mismatches.
Results are in a tab separated file.

=head1 OPTIONS

=over 7

=item B<--alpsfflist> I<ALPSFILELIST>

Path to I<ALPSFILELIST> file (e.g., ./formulas_file_list.txt)

=item B<--keikoffile> I<KEIKOFILE>

Path to I<KEIKOFILE> file (e.g., ./power_formulas.haswell.formulas)

=item B<--ofile>=I<OUTPUTFILE>

Path to I<OUTPUTFILE> file (e.g. ./alps_formulas_diffs.xls)

=item B<--summary>=I<SUMMARYFILE>

Path to I<SUMMARYFILE> file. If not specified, the default will be I<OUTPUTFILE> with _summ appended to basename (e.g., ./alps_formulas_diffs_summ.xls)

=item B<--man>

Prints man page

=item B<--help>

Prints help

=back

=head1 REQUIRES

utilities.pm, systemTime.pm

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

=cut
