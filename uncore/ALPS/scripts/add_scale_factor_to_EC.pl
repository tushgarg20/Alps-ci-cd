#!/usr/intel/bin/perl
# name: add_scale_factor_to_EC.pl
# date: 30-Mar-2009
# auth: Mosur Mohan
#
# ver:  0.1
# desc: Inserts a scale factor variable into each EC column
#		in the input formula files
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
my ($ffile_list, $outfile_dir) = ("", "", "");
my $scale_expr = "cdyn_scaling_1268_to_1270";
my @ffiles = ();
my $script_name = $0;
my $retval = 0;

$script_name =~ s/(^.*\/)//;

GetOptions('fflist=s'	=> \$ffile_list,
           'odir=s'     => \$outfile_dir,
           'scale=s'    => \$scale_expr,
           'man',
           'help') || die "Try `perl $script_name -help' for more information.\n";

######################################################################
#### main
######################################################################

checkArgs();  # Check command-line arguments

$scale_expr =~ s/\'\"//g;         # strip quotes
$outfile_dir = glob ($outfile_dir);
(-d $outfile_dir) || (system "mkdir -p $outfile_dir");

# Read in file list and write out corresponding files into
# $outfile_dir with EC column
readAlpsFFileList ($ffile_list, \@ffiles);

# Convert each formula file
foreach my $ffile (@ffiles) {
	convertFormulaFile ($ffile, $outfile_dir, $scale_expr);
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
    if ($ffile_list eq "") {
        print STDERR "-E- Please specify stat files with --fflist switch.\n";
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
# Convert formula file with scale factor variable
######################################################################
sub convertFormulaFile {
	my ($ffile, $outfile_dir, $scale_expr) = @_;

	my @ECColIndices = ();
	my @colNames = ();
	my %colNameMap = ();
	my $scaled_line = "";
	my $outfile = $ffile;

	$outfile =~ s/.*\/([^\/]+)$/$1/;
	$outfile = "$outfile_dir/$outfile";

	# Copy leakage files unchanged, and exit
	if ($ffile =~ /\.leakage\./) {
		system ("cp -f $ffile $outfile");
		return;
	}

	open (FFILE, $ffile) || die ("Can't open formula file \"$ffile\": $!\n");
	open (OUTF, "> $outfile") || die "-F- Cannot open $outfile: $!\n";
    print STDOUT "-I- Reading $ffile\n";

	while (my $fline = <FFILE>) {
		chomp $fline;

		if ($fline =~ /^Fub\t/) {
			$scaled_line = $fline;

			# Header line: grab column names
			@colNames = split (/\t/, $fline);

			# Get indices of EC columns, remembering that
			# +  core formula files have 1 function column per line
			# +  uncore files have multiple <Function_i>/<Formula_i><EC_i> columns
			# Also, get indices of hierarchy columns
			for (my $i = 0; $i <= $#colNames; $i++) {
				my $col = $colNames[$i];
				$col =~ tr/A-Z/a-z/;
				$colNameMap{$col} = $i;
				if ($col =~ /^(power|capacitance|ec)(\d+)?$/) {
					push (@ECColIndices, $i);
				}
			}

		} else {
			# Data line
			my @fields = split (/\t/, $fline);

			# Insert scale factor into the EC columns
			foreach my $i (@ECColIndices) {
				if (defined($fields[$i]) and ($fields[$i] ne "")) {
					$fields[$i] = "$scale_expr * ( $fields[$i] )";
				}
			}

			# Reconstruct the line with the scaled EC fields
			$scaled_line = join ("\t", @fields);
		}

		print OUTF "$scaled_line\n";
	}

	close (FFILE);
	close (OUTF);
}


__END__

=pod

=head1 NAME

add_scale_factor_to_EC.pl    Inserts a scale factor variable into each EC column in the input formula files

=head1 SYNOPSIS

perl B<add_scale_factor_to_EC.pl> [I<options>] B<--fflist> I<FORMULA_FILE_LIST> B<--odir> I<OUTPUT_DIR> B<--scale> I<SCALE_EXPR>

=head1 DESCRIPTION

B<add_scale_factor_to_EC> reads in the given I<FORMULA_FILE_LIST> file, inserts a scale factor variable into each EC field in the input formula files, and outputs the converted data into I<OUTPUT_DIR>.

=head1 OPTIONS

=over 7

=item B<--fflist> I<FORMULA_FILE_LIST>

Path to I<FORMULA_FILE_LIST> file (e.g., ./formulas_file_list.txt)

=item B<--odir> I<OUTPUT_DIR>

Path to I<OUTPUT_DIR> directory

=item B<--scale> I<SCALE_EXPR>

Expression to be inserted as a scale factor into the EC fields; default= "cdyn_scaling_1268_to_1270".

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
