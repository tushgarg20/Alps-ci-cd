#!/usr/intel/bin/perl
# name: convert_formulas_to_1funcperline.pl
# date: 8-Apr-2009
# auth: Mosur Mohan
#
# ver:  0.1
# desc: Alps formula files come in two flavors: one with a
#       single function per line, and the other with multipe
#       functions per line, listed in tuples of
#       <Function_i, Formula_i, Power_i>.
#       This script converts the second format into the first.
# proj: Haswell/Broadwell for initial deployment

#### pragmas
use strict;
use warnings;

#### system vars
$| = 1;		   ## Flush after every write or print
			   ## Useful during debugging, turn off for production use

#### modules
use File::Glob "glob";
use Pod::Usage;
use Getopt::Long;
$Getopt::Long::ignorecase = 1;
$Getopt::Long::autoabbrev = 1;


#### program vars and command-line args
our ($opt_man, $opt_help) = ();
my ($ffile, $ffile_list, $outfile_dir) = ("", "", "");
my @ffiles = ();
my $script_name = $0;
my $retval = 0;

$script_name =~ s/(^.*\/)//;

GetOptions('ffile=s'	=> \$ffile,
		   'fflist=s'	=> \$ffile_list,
           'odir=s'     => \$outfile_dir,
           'man',
           'help') || die "Try `perl $script_name -help' for more information.\n";


######################################################################
#### main
######################################################################

checkArgs();  # Check command-line arguments

$outfile_dir = glob ($outfile_dir);
(-d $outfile_dir) || (system "mkdir -p $outfile_dir");

if ($ffile ne "") {
	@ffiles = glob ($ffile);
}
if ($ffile_list ne "") {
    # Read in file list and write out corresponding files into
    # $outfile_dir with EC column
    readAlpsFFileList ($ffile_list, \@ffiles);
}

# Convert each formula file
foreach my $ffile (@ffiles) {
	convertTo1FuncPerLine ($ffile, $outfile_dir);
}

exit;


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
    if (($ffile_list eq "") and ($ffile eq "")) {
        print STDERR "-E- Please specify either a formula file with --ffile, or a formula_file_list file with --fflist switch.\n";
        $kill = 1;
    }

    # If any of the checks failed, cannot continue
    if ($kill == 1) {
        die "-F- Could not proceed. Exiting.\n";
    }
}


######################################################################
# Read in formulas from the list of formula files
######################################################################
sub readAlpsFFileList {
	my ($alps_ffile_list, $ffiles_p) = @_;

	# Read filenames from formula_file_list
	$alps_ffile_list = glob ($alps_ffile_list);
	open (FFLIST, $alps_ffile_list) ||
	  die ("Can't open formula file list \"$alps_ffile_list\": $!\n");
    print STDOUT "-I- Reading $alps_ffile_list\n";

	my $affile_dir = $alps_ffile_list;
	if ($affile_dir =~ /(.+)\/[^\/]+$/) {
		$affile_dir = $1;
	}

	# Collect all filenames contained in the formulas_file_list file
	while (my $ffname = <FFLIST>) {
		chomp $ffname;

		$ffname =~ s/\r$//;
		$ffname = glob ($ffname);
		if ($ffname !~ /^[\/~]/) {
			$ffname = $affile_dir . "/" . $ffname;
		}

		# Check file existence
		if (! -e $ffname) {
			die ("Can't find formula file \"$ffname\".\n");
		}

		# Append formulas file name to ffiles_p
		push (@$ffiles_p, $ffname);
	}

	close (FFLIST);
}


######################################################################
# Convert formula file to 1-function-per-line format
######################################################################
sub convertTo1FuncPerLine {
	my ($ffile, $outfile_dir) = @_;

	my @colNames = ();
	my @funcList = ();
	my %colNameMap = ();
	my $outfile = $ffile;
	my ($colHdr, $out_str) = ("", "");

	$outfile =~ s/.*\/([^\/]+)$/$1/;
	$outfile = "$outfile_dir/$outfile";

	open (FFILE, $ffile) || die ("Can't open formula file \"$ffile\": $!\n");
	open (OUTF, "> $outfile") || die "-F- Cannot open $outfile: $!\n";
    print STDOUT "-I- Reading $ffile\n";

	while (my $fline = <FFILE>) {
		chomp $fline;

		if ($fline =~ /^Fub\t/) {

			# Header line: grab column names
			@colNames = split (/\t/, $fline);

			# Map out the relevant columns, and
			# assemble a list of function columns, including Idle
			for (my $i=0; $i <= $#colNames; $i++) {
				$colHdr = $colNames[$i];
				if ($colHdr =~ /Fub|Unit|Cluster|Location|Idle|Function|Formula|Power/) {
					$colNameMap{$colHdr} = $i;
					if ($colHdr =~ /Idle|Function/) {
						push (@funcList, $colHdr);
					}
				}
			}

			# Create header line
			print OUTF "Fub\tUnit\tCluster\tLocation\tFunction\tFormula1\tEC1\tSource1\tComment\n";
		} else {
			# Data line
			my @fields = split (/\t/, $fline);

			# Construct hierarchy columns in output line
			$out_str = "";
			foreach $colHdr ("Fub", "Unit", "Cluster", "Location") {
				$out_str .= "$fields[$colNameMap{$colHdr}]\t";
			}

			# Tack on Idle or Function_i info, and print one output line for each
			foreach my $func (@funcList) {
				if ($func eq "Idle") {
					print OUTF "$out_str", "Idle\t\t", "$fields[$colNameMap{'Idle'}]\t\t\n";
				} elsif (($colNameMap{$func} + 2) <= $#fields) {
					# There are still more functions to print out
					my ($formula, $EC) = ($func, $func);
					$formula =~ s/Function/Formula/;
					$EC =~ s/Function/Power/;
					print OUTF "$out_str";
					foreach $colHdr ($func, $formula, $EC) {
						print OUTF "$fields[$colNameMap{$colHdr}]\t";
					}
					print OUTF "\t\n"; # Empty Source and Comment columns
				} else {
					# Done with all functions in this input line
					last;
				}
			}
		}
	}

	close (FFILE);
	close (OUTF);
}


__END__

=pod

=head1 NAME

convert_formulas_to_1funcperline.pl    Converts formula files from the multi-function-per-line format into the single-function-per-line format.

=head1 SYNOPSIS

perl B<convert_formulas_to_1funcperline.pl> [ B<--ffile> I<FORMULA_FILE> | B<--fflist> I<FORMULA_FILE_LIST> ] B<--odir> I<OUTPUT_DIR>

=head1 DESCRIPTION

B<convert_formulas_to_1funcperline.pl> Alps formula files come in two flavors: one with a single function per line, and the other with multipe functions per line, listed in tuples of <Function_i, Formula_i, Power_i>. This script converts the second format into the first.  It reads in either a single I<FORMULA_FILE> or a I<FORMULA_FILE_LIST> file containing pathnames of formula files, and converts each formula file into the formula file format of 1 function per line; converted formula files are written into I<OUTPUT_DIR>.

=head1 OPTIONS

=over 7

=item B<--ffile> I<FORMULA_FILE>

Path to I<FORMULA_FILE> (e.g., ./uncore.formula.latest.hsw_golden.xls)

=item B<--fflist> I<FORMULA_FILE_LIST>

Path to I<FORMULA_FILE_LIST> file (e.g., ./formulas_file_list.txt)

=item B<--odir> I<OUTPUT_DIR>

Path to I<OUTPUT_DIR> directory; default = ./

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

=cut
