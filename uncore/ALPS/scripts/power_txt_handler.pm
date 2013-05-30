package power_txt_handler;

use diagnostics -verbose;
use strict;
use Data::Dumper;

use output_functions;


my $last_column_b4_traces = "Max power";


################# read a power_txt file into a hash
### usage: read_power_txt($file, $main_hash)
sub read_power_txt
{
	if (@_ != 3) {return 0;}
	my ($file, $main_hash, $leakagefile) = @_;

	open (INFILE, "zgrep -v ^# $file |") or die "Can't find power file: \"$file\".\n";
	my @lines = <INFILE>;
	close(INFILE);
	
	my @columns;
	my %columnsNums;
	my $line = "";
	
	while ((scalar(@lines) > 0) and (scalar(@columns) == 0))	# find the header row
	{
		$line = shift @lines;
		chomp $line;
		$line =~ s/\r$//;
		$line =~ s/\#.*//;	### get rid of comments
		if ($line =~ /^Function\t/)
		{
			@columns = split(/\t/, $line);
			for (my $i = 0; $i < scalar(@columns); $i++)
			{
				$columnsNums{$columns[$i]} = $i;
			}
		}
	}
	if (scalar(@columns) == 0) {die "Can't find header row in file $file!\n";}
	if ((!defined $columnsNums{"Location"}) or (!defined $columnsNums{"Cluster"}) or (!defined $columnsNums{"Unit"}) or (!defined $columnsNums{"Fub"}))
	{
		die ("Error in power file: can't find hierarchy info.\n");
	}		
#	for (my $col = ($columnsNums{$last_column_b4_traces} + 1); $col < scalar(@columns); $col++)
#	{
#		push @{$$main_hash{"Tests"}}, $columns[$col];
#	}
	
	foreach my $line (@lines)	# read the data
	{
		my $location;
		my $cluster;
		my $unit;
		my $fub;
		my $function;
		my $Max;
		my $TDP;
		my $EC;

		chomp $line;
		$line =~ s/\r$//;
		$line =~ s/\#.*//;	### get rid of comments
		my @line = split(/\t/, $line);
		for (my $i = 0; $i <= scalar(@line); $i++)   ### get rid of spaces
		{
			if ((defined($line[$i])) and ($line[$i] ne ""))
			{
				$line[$i] =~ s/^\s+//;
				$line[$i] =~ s/\s+$//;
			}
		}
		$Max = $line[$columnsNums{"Max power"}];
		$TDP = $line[$columnsNums{"TDP power"}];
		$EC = $line[$columnsNums{"EC"}];
		$location = $line[$columnsNums{"Location"}];
		$cluster = $line[$columnsNums{"Cluster"}];
		$unit = $line[$columnsNums{"Unit"}];
		$fub = $line[$columnsNums{"Fub"}];
		$function = $line[$columnsNums{"Function"}];

		if (	((defined($function)) and ($function ne "")) and
				((defined($fub)) and ($fub ne "")) and
				((defined($unit)) and ($unit ne "")) and
				((defined($cluster)) and ($cluster ne "")) and
				((defined($location)) and ($location ne "")) and
				($location ne "uncore") )
		{

#			hierarchy::insert_hierarchy($fub, $unit, $cluster, $location);

			if ($function eq "Idle")
			{
				$$main_hash{"Fubs"}{$fub}{"Idle"} = $EC;
				$$main_hash{"Fubs"}{$fub}{"Unit"} = $unit;
				$$main_hash{"Fubs"}{$fub}{"Cluster"} = $cluster;
				$$main_hash{"Fubs"}{$fub}{"Location"} = $location;
			}
			elsif ($function eq "Leakage")
			{
				if ($leakagefile ne "") {$EC = 0;}
				$$main_hash{"Fubs"}{$fub}{"Leakage"} = $EC;
			}
			else
			{
#				$$main_hash{"Fubs"}{$fub}{"Functions"}{$function}{"EC"} = $EC;
#				$$main_hash{"Fubs"}{$fub}{"Functions"}{$function}{"TDP power"} = $TDP;
#				$$main_hash{"Fubs"}{$fub}{"Functions"}{$function}{"Max power"} = $Max;

				if (defined $$main_hash{"Fubs"}{$fub}{"TDP power"})
				{
					$$main_hash{"Fubs"}{$fub}{"TDP power"} += $TDP;
				}
				else
				{
					$$main_hash{"Fubs"}{$fub}{"TDP power"} = $TDP;
				}
				
				for (my $col = ($columnsNums{$last_column_b4_traces} + 1); $col < scalar(@columns); $col++)
				{
					if (defined($line[$col]))
					{
						my $val = $line[$col];
						(defined $val) or ($val = "");
						if ($val !~ /^\s*-?\d+\.?\d*(e-)?\d*\s*$/)
						{
							output_functions::print_to_log("Error: ($val) is not a numeric value at fub $fub at function $function at $columns[$col]\n");
							$val = 0;
						}
#						$$main_hash{"Fubs"}{$fub}{"Functions"}{$function}{"Tests"}{$columns[$col]} = $val;
						if (defined $$main_hash{"Fubs"}{$fub}{"Tests"}{$columns[$col]})
						{
							$$main_hash{"Fubs"}{$fub}{"Tests"}{$columns[$col]} += $val;
						}
						else
						{
							$$main_hash{"Fubs"}{$fub}{"Tests"}{$columns[$col]} = $val;
						}
						$$main_hash{"Tests"}{$columns[$col]} = 1;
					}
				}
			}
		}
		elsif ((defined($function)) and ($function eq "IPC"))
		{
			for (my $col = ($columnsNums{$last_column_b4_traces} + 1); $col < scalar(@columns); $col++)
			{
				if (defined($line[$col]))
				{
					my $val = $line[$col];
					(defined $val) or ($val = "");
					if ($val !~ /^\s*-?\d+\.?\d*(e-)?\d*\s*$/)
					{
						output_functions::print_to_log("Error: ($val) is not a numeric value at IPC at $columns[$col]\n");
						$val = 0;
					}
					$$main_hash{"IPC"}{"Tests"}{$columns[$col]} = $val;
				}
			}
		}
	}

	if ($leakagefile ne "")
	{
		input_manual_leakage($leakagefile, $main_hash);
	}

	summarize_hash($main_hash);

	return 1;
}
#################


################# read the manual leakage from a file into a hash
### usage: input_manual_leakage($file, $main_hash)
sub input_manual_leakage
{
	if (@_ != 2) {return 0;}
	my ($file, $main_hash) = @_;

	open (INFILE, "zgrep -v ^# $file |") or die "Can't find file: \"$file\".\n";
	my @lines = <INFILE>;
	close(INFILE);
	
	my @columns;
	my %columnsNums;
	my $line = "";
	
	while ((scalar(@lines) > 0) and (scalar(@columns) == 0))	# find the header row
	{
		$line = shift @lines;
		chomp $line;
		$line =~ s/\r$//;
		$line =~ s/\#.*//;	### get rid of comments
		if ($line =~ /^Fub\t/)
		{
			@columns = split(/\t/, $line);
			for (my $i = 0; $i < scalar(@columns); $i++)
			{
				$columnsNums{$columns[$i]} = $i;
			}
		}
	}
	if (scalar(@columns) == 0) {die "Can't find header row in file $file!\n";}
	if ((!defined $columnsNums{"Cluster"}) or (!defined $columnsNums{"Unit"}) or (!defined $columnsNums{"Fub"}))
	{
		die ("Error in file: can't find hierarchy info.\n");
	}		
	
	foreach my $line (@lines)	# read the data
	{
#		my $location;
		my $cluster;
		my $unit;
		my $fub;
#		my $function;
#		my $Max;
#		my $TDP;
		my $rollup;

		chomp $line;
		$line =~ s/\r$//;
		$line =~ s/\#.*//;	### get rid of comments
		my @line = split(/\t/, $line);
		for (my $i = 0; $i <= scalar(@line); $i++)   ### get rid of spaces
		{
			if ((defined($line[$i])) and ($line[$i] ne ""))
			{
				$line[$i] =~ s/^\s+//;
				$line[$i] =~ s/\s+$//;
			}
		}
#		$Max = $line[$columnsNums{"Max power"}];
#		$TDP = $line[$columnsNums{"TDP power"}];
		$rollup = $line[$columnsNums{"Rollup"}];
#		$location = $line[$columnsNums{"Location"}];
		$cluster = $line[$columnsNums{"Cluster"}];
		$unit = $line[$columnsNums{"Unit"}];
		$fub = $line[$columnsNums{"Fub"}];
#		$function = $line[$columnsNums{"Function"}];

		if (	((defined($rollup)) and ($rollup ne "")) and
				((defined($fub)) and ($fub ne "")) and
				((defined($unit)) and ($unit ne "")) and
				((defined($cluster)) and ($cluster ne "")) )
		{

			map_fub($fub, $unit, $cluster, \$fub, \$unit, \$cluster);
			$$main_hash{"Fubs"}{$fub}{"Leakage"} = $rollup * 1.7;
			if (!defined $$main_hash{"Fubs"}{$fub}{"Unit"})
			{
				$$main_hash{"Fubs"}{$fub}{"Unit"} = $unit;
				$$main_hash{"Fubs"}{$fub}{"Cluster"} = $cluster;
				$$main_hash{"Fubs"}{$fub}{"Location"} = "core";
			}

		}
	}

	return 1;
}
#################


################# map a fub to the name in ALPS
### usage: map_fub($fub, $unit, $cluster, \$fub, \$unit, \$cluster)
sub map_fub
{
	if (@_ != 6) {return 0;}
	my ($fub, $unit, $cluster, $nfub, $nunit, $ncluster) = @_;

	($$nfub, $$nunit, $$ncluster) = ($fub, $unit, $cluster);
	$$nfub =~ tr/A-Z/a-z/;
	$$nunit =~ tr/a-z/A-Z/;
	$$ncluster =~ tr/a-z/A-Z/;

	my $mapping = "fpdctlsp fpdctls
	misdbmp misdbm
	fparndhfdp fparndhfd
	fpdqremldp fpdqremld
	iemulhdp	iemulhd
	fpmwtreehsdp	fpmwtreehsd
	miictlsp	miictls
	fpmrndhsdp	fpmrndhsd
	fpactlssp	fpactlss
	fpmctlssp	fpmctlss
	mifctlsp	mifctls
	micrctlsp	micrctls
	fpaalglfdp	fpaalglfd
	fparndhsdp	fparndhsd
	siport1ctlsp	siport1ctls
fpromcmp	fpromcm
ieplasp	ieplas
fpromrctllsp	fpromrctlls
mihimxidp	mihimxid
sisttnidp	sisttnid
fpaaddlsdp	fpaaddlsd
iescratchdp	iescratchd
fpmwtreelfdp	fpmwtreelfd
fpmexplfdp	fpmexplfd
fpaalglsdp	fpaalglsd
iemuldp	iemuld
agsrfdp	agsrfd
fpmexphfdp	fpmexphfd
fpdposthsdp	fpdposthsd
fpdqremhsdp	fpdqremhsd
sishuf5hdp	sishuf5hd
agcrudp	agcrud
fpactlfsp	fpactlfs
fparndlfdp	fparndlfd
ieuni1ctsp	ieuni1cts
mihimxsdp	mihimxsd
sishuf5ldp	sishuf5ld
mihimxfdp	mihimxfd
fpaaddhsdp	fpaaddhsd
fpaaddlfdp	fpaaddlfd
ieslowuopsp	ieslowuops
fpromcvctlsp	fpromcvctls
fpromrhmp	fpromrhm
iecrudp	iecrud
fpaalghsdp	fpaalghsd
fpmrctlssp	fpmrctlss
fpdpostlsdp	fpdpostlsd
fpmexphsdp	fpmexphsd
fpmrndlsdp	fpmrndlsd
fpmwtreehfdp	fpmwtreehfd
sialu1hdp	sialu1hd
ieuni0ctsp	ieuni0cts
iealumx0cp	iealumx0c
fpromrctlhsp	fpromrctlhs
fpmrndlfdp	fpmrndlfd
milomxsdp	milomxsd
fpmrndhfdp	fpmrndhfd
agmuxdp	agmuxd
sialu0ldp	sialu0ld
misctlsp	misctls
fpaaddhfdp	fpaaddhfd
fpmgenlfdp	fpmgenlfd
milomxfdp	milomxfd
agaddercp	agadderc
sialu5ldp	sialu5ld
ieslowctsp	ieslowcts
fparndlsdp	fparndlsd
siport0ctlsp	siport0ctls
milomxidp	milomxid
ieleamxdp	ieleamxd
fpsctlsp	fpsctls
fpmgenhsdp	fpmgenhsd
agdecfltcp	agdecfltc
iealumx5cp	iealumx5c
ieshiftmx0dp	ieshiftmx0d
fpmwtreelsdp	fpmwtreelsd
fpmrctlfsp	fpmrctlfs
fpmgenlsdp	fpmgenlsd
ieshiftmx5dp	ieshiftmx5d
siport5ctlsp	siport5ctls
fpshufhdp	fpshufhd
sialu5hdp	sialu5hd
fpmctlfsp	fpmctlfs
fpmgenhfdp	fpmgenhfd
sishifthdp	sishifthd
dcabortsp	dcaborts
iealumx1cp	iealumx1c
fpmexplsdp	fpmexplsd
fpromrlmp	fpromrlm
fpaalghfdp	fpaalghfd
ieuni5ctsp	ieuni5cts
sishiftldp	sishiftld
";
	
	while ($mapping =~ /^(\w+)\s+(\w+)\s*([\w\s\r]*)/)
	{
		my $old = $1;
		my $new = $2;
		$mapping = $3;
#		print "in the mapping: $mapping\n";
		if ($$nfub eq $old)
		{
			$$nfub = $new;
			print "mapped $old to $new\n";
			$mapping = "";
		}
	}
#	print "the mapping after mapping: $mapping\n";

	return 1;
}
#################


################# summarize the hash
### usage: summarize_hash()
sub summarize_hash
{
	if (@_ != 1) {return 0;}
	my ($main_hash) = @_;

	foreach my $fub (keys %{$$main_hash{"Fubs"}})
	{
		my $unit = $$main_hash{"Fubs"}{$fub}{"Unit"};
		my $cluster = $$main_hash{"Fubs"}{$fub}{"Cluster"};
		my $location = $$main_hash{"Fubs"}{$fub}{"Location"};
		my $idle = $$main_hash{"Fubs"}{$fub}{"Idle"};
		(defined $idle) or ($idle = 0);
		my $leakage = $$main_hash{"Fubs"}{$fub}{"Leakage"};
		(defined $leakage) or ($leakage = 0);
		$$main_hash{"Fubs"}{$fub}{"TDP power"} += $idle;
		my $TDP = $$main_hash{"Fubs"}{$fub}{"TDP power"};
		(defined $TDP) or ($TDP = 0);
		foreach my $test (keys %{$$main_hash{"Tests"}})
		{
			if (defined $$main_hash{"Fubs"}{$fub}{"Tests"}{$test})
			{
				$$main_hash{"Fubs"}{$fub}{"Tests"}{$test} += $idle;
			}
			else
			{
				$$main_hash{"Fubs"}{$fub}{"Tests"}{$test} = $idle;
			}
		}
		
		foreach my $hierarchy ("Unit", "Cluster", "Location")
		{
			my $Hname = $$main_hash{"Fubs"}{$fub}{$hierarchy};
			
			if (defined $$main_hash{$hierarchy}{$Hname}{"Idle"})
			{
				$$main_hash{$hierarchy}{$Hname}{"Idle"} += $idle;
			}
			else
			{
				$$main_hash{$hierarchy}{$Hname}{"Idle"} = $idle;
			}
			if (defined $$main_hash{$hierarchy}{$Hname}{"Leakage"})
			{
				$$main_hash{$hierarchy}{$Hname}{"Leakage"} += $leakage;
			}
			else
			{
				$$main_hash{$hierarchy}{$Hname}{"Leakage"} = $leakage;
			}
			if (defined $$main_hash{$hierarchy}{$Hname}{"TDP power"})
			{
				$$main_hash{$hierarchy}{$Hname}{"TDP power"} += $TDP;
			}
			else
			{
				$$main_hash{$hierarchy}{$Hname}{"TDP power"} = $TDP;
			}
			
			foreach my $test (keys %{$$main_hash{"Fubs"}{$fub}{"Tests"}})
			{
				my $val = $$main_hash{"Fubs"}{$fub}{"Tests"}{$test};
				if (defined $$main_hash{$hierarchy}{$Hname}{"Tests"}{$test})
				{
					$$main_hash{$hierarchy}{$Hname}{"Tests"}{$test} += $val;
				}
				else
				{
					$$main_hash{$hierarchy}{$Hname}{"Tests"}{$test} = $val;
				}
			}
		}
	}

	return 1;
}
#################


1;
