#!/usr/intel/bin/perl5.85


#require 5.001;
use diagnostics;
use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;


################# input parameters
my $file_to_compact = "";
my $output_file = "";

GetOptions(	"-file_to_compact=s" => \$file_to_compact,
				"-output_file=s" => \$output_file);

($file_to_compact ne "") or die "Please provide file_to_compact\n";
($output_file ne "") or die "Please provide output_file\n";
#################

my @original_data;

open(INFILE, "gzcat $file_to_compact |") or die ("Can't open $file_to_compact\n");
my @lines = <INFILE>;
my $line_num = 0;
foreach my $line (@lines) {
	chomp $line;
	my @line = split(/\t/, $line);
	push (@{$original_data[$line_num]}, (@line));
	$line_num++;
}
close(INFILE);
#print Dumper(\@original_data);
#exit 1;

my @columns_to_print;
my @rows_to_print;
$rows_to_print[0] = 1;
my $col = 0;
my $start_col_found = 0;
while ($col < scalar(@{$original_data[0]}))
{
	if (not $start_col_found)
	{
		$columns_to_print[$col] = 1;
		if ($original_data[0][$col] eq "Location")
		{
			$start_col_found = 1;
		}
		$col++;
	} else {
		my $print_data = 0;
		my $row = 1;
		while ($row < scalar(@original_data))
		{
			if (
					( (not defined($original_data[$row][$col + 3])) or ($original_data[$row][$col + 3] ne "0") )
					and
					(
						(not defined($original_data[$row][$col]))
						or
						(not defined($original_data[$row][$col + 1]))
						or
						( ($original_data[$row][$col]) ne ($original_data[$row][$col + 1]) )
					)
				)
			{
				$print_data = 1;
				$rows_to_print[$row] = 1;
			}
			$row++;
		}
		$columns_to_print[$col] = $print_data;
		$columns_to_print[$col + 1] = $print_data;
		$columns_to_print[$col + 2] = $print_data;
		$columns_to_print[$col + 3] = $print_data;

		$col = $col + 4;
	}
}


open (O, "| gzip >${output_file}.gz");
for (my $row = 0; $row < scalar(@original_data); $row++)
{
	if ( (defined($rows_to_print[$row])) and ($rows_to_print[$row] eq "1") )
	{
		for (my $col = 0; $col < scalar(@{$original_data[$row]}); $col++)
		{
			if ($columns_to_print[$col])
			{
				print O $original_data[$row][$col] . "\t";
			}
		}
		print O "\n";
	}
}
close(O);
