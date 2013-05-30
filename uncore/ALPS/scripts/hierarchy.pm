package hierarchy;

use diagnostics;
use strict;
use output_functions;

my %hierarchy;


################# read the hierarchy file into the clusters/units defined hashes
### usage: read_hierarchy(<file name to read the hierarchy from>, <pointer to the blocks_defined hash>)
sub read_hierarchy
{
	if (@_ == 2)
	{
		my ($infile, $blocks_defined) = @_;
		#my ($infile, $c_defined, $u_defined) = @_;
		my @lines;
		my $cflag =0;
		my $uflag =0;
		my $item;

	#foreach my $key ("FE","MSID","OOO","EXE","MEU","CORE","UNCORE")
	#	{
	#		$c_defined{$key} = "";
	#	}
	#foreach my $key ("CHL","CSIDIG0","CSILL","DCU","DSB","FPU","GQ","IEU","IFU","ILQ","LLCTRL","LLDATA0C0","LLDATA1C0","LLDATA2C0","LLDATA3C0","MIU","MLC","MOB","PIG","PMH","RAT","ROB","RS","SIU","TTCH0","TTCH1","TTCH2","TTCH3","TTMAIN")
	#	{
	#		$u_defined{$key} = "";
	#	}
		
		if (not (open (INFILE, $infile)))
		{
			output_functions::print_to_log("Can't open hierarchy file: \"$infile\".\n");
			return 0;
		}
		@lines = <INFILE>;
		close(INFILE);
		
		foreach my $line (@lines)
		{
			chomp $line;
			$line =~ s/\r$//;

			if ($line =~ /\s*Clusters:(.*)/)
			{
				$line = $1;
				$cflag = 1;
				$uflag = 0;
			} elsif ($line =~ /\s*Units:(.*)/)
			{
				$line = $1;
				$cflag = 0;
				$uflag = 1;
			}
			foreach my $item (split (/\s+/,$line))
			{
				if ($item ne "") 
				{
					if ($cflag) {$$blocks_defined{"Clusters"}{$item} = "";}
					if ($uflag) {$$blocks_defined{"Units"}{$item} = "";}
				}
			}
		}
		if ((scalar(keys(%{$$blocks_defined{"Clusters"}})) == 0) or (scalar(keys(%{$$blocks_defined{"Units"}})) == 0))
		{
			output_functions::print_to_log("Bad hierarchy file.\n");
			return 0;
		}
		return 1;
	}
	output_functions::print_to_log("Bad parameter to read_hierarchy function.\n");
	return 0;
}
#################


################# insert a hierarchy link to the database
### usage: insert_hierarchy(<fub>, <unit>, <cluster>, <location>)
sub insert_hierarchy
{
	if (@_ == 4)
	{
		my ($fub, $unit, $cluster, $location) = @_;

		$hierarchy{"Fubs"}{$fub}{"Parent"} = $unit;
		$hierarchy{"Units"}{$unit}{"Parent"} = $cluster;
		$hierarchy{"Clusters"}{$cluster}{"Parent"} = $location;
		
		return 1;
	}

	return 0;
}
#################


################# return hierarchy of the block
### usage: return_hierarchy(<type of block>, <block name>)
sub return_hierarchy
{
	if (@_ == 2)
	{
		my ($type, $block) = @_;

		if (($type eq "Fub") or ($type eq "Unit") or ($type eq "Cluster"))
		{
			if (defined $hierarchy{$type . "s"}{$block}{"Parent"})
			{
				return $hierarchy{$type . "s"}{$block}{"Parent"};
			}
			else
			{
				output_functions::print_to_log("Error: undefined hierarchy for $block\n");
				return "";
			}
		}
		else
		{
			output_functions::print_to_log("Error: unknown block type in \"return_hierarchy\"\n");
			return "";
		}
	}

	output_functions::print_to_log("Error: bad parameters to return_hierarchy functions!\n");
	return "";
}
#################


1;
