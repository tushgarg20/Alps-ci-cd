###### Transforms a config txt file into a config hash table
## Usage: 
##	    initConfig("filename"):
##		Initialize the config's hash table
##	    
##	    getConfigHash():
##		Get the config hash. Make sure to use "initConfig" before using this function.
##
##	    getKnob("knob_name")
##		Get the knob value if exists. Otherwise returns "-1"
##
##	    getPlane("segment_name","block_name","f" or "v")
##		Returns block's freq or voltage if exists. Otherwise returns "-1"
##
package general_config;

use diagnostics;
use strict;
use Data::Dumper;
use output_functions;

### Static variable which is being used throughout the module
my %configHash = ();

sub initConfig
{
	if(@_ != 1) {return(-1);} ## Too much/not enough parameters  

	my ($inputFile) = @_;
	my $inputFilePath = glob ($inputFile);

	my $inputFileDir = "";
	if ($inputFile =~ /(.*\/).+/)	# get the config root path from the file name
	{
		$inputFileDir = $1;
	}

	output_functions::print_to_log("Implementing $inputFile config file\n");
	open(INPUT_FILE,"$inputFile") or output_functions::die_cmd("Can't open die config file: $inputFile\n");
	my @lines=<INPUT_FILE>;
	close(INPUT_FILE);

	foreach my $line (@lines)
	{
		chomp $line;
		$line =~ s/\r$//;
		$line =~ s/\#.*//;	### get rid of comments

		#	while( $line =~ s/^\s*\-([\_\-\[\]\.\w\d\\\/]+)\s+([\_\-\[\]\.\w\d\\\/]+)// )
		while( $line =~ s/^\s*\-(\S+)\s+(\S+)// )
		{
			my ($knob, $value) = ($1, $2);
			if ((($knob eq "cfg") or ($knob eq "planes_cfg") or ($knob eq "hashes_file") or ($knob eq "aliases_file")) and ($value !~ /^\//))	# need to add the path to the config file
			{
				$value = $inputFileDir . $value;
			}
			if($knob eq "cfg") {initConfig($value);}		### Use a new config file
			elsif($knob eq "planes_cfg") {initPlanes($value);}	### Update planes config data
			elsif($knob eq "hashes_file") {initHashes($value);}	### Adding hashes knobs
			else {$configHash{$knob} = $value;}			### Put the knob inside the hash
		}
	}
}


sub getConfigHash
{
    return \%configHash;
}


sub getKnob
{
    if(@_ != 1) {return(-1);} ## Too much/not enough parameters  
    my($knob) = @_;

    if(defined($configHash{$knob})) {return $configHash{$knob};}
    else {return(-1);}  
}


sub getPlane
{
    if(@_ != 3) {return(-1);} ## Too much/not enough parameters  
    my($segment,$block,$parameter) = @_;
    
    if( ($parameter ne "f") and ($parameter ne "v") ) {return(-1);}	    ### Ilegal parameter
    if(!defined($configHash{"planes_division"}{$segment})) {return (-1);}   ### Undefined segment

    foreach my $workingPoint (keys %{$configHash{"planes_division"}{$segment}})
    {
	foreach my $currBlock (keys %{$configHash{"planes_division"}{$segment}{$workingPoint}})
	{
	    if($block eq $currBlock)
	    {
		my @workingPoint = split(",",$workingPoint);
		if($parameter eq "v") {return $workingPoint[0];}
		else {return $workingPoint[1];}
	    }
	}
    }

    return (-1); ### Undefined Block
}


sub getPlanesHash
{
   if (@_ != 2) {return (-1);} ## Too much/not enough parameters  
   my ($segment, $planeHash) = @_;
	
	if (!defined($configHash{"planes_division"}{$segment})) {return (-1);}   ### Undefined segment

	foreach my $workingPoint (keys %{$configHash{"planes_division"}{$segment}})
   {
		my @workingPoint = split(",", $workingPoint);
		foreach my $currBlock (keys %{$configHash{"planes_division"}{$segment}{$workingPoint}})
		{
			$$planeHash{$currBlock}{"v"} = $workingPoint[0];
			$$planeHash{$currBlock}{"f"} = $workingPoint[1];
		}
	}

	return (1);
}


### Static function (used inside "initConfig")
sub initPlanes
{
	if(@_ != 1) {return(-1);} ## Too much/not enough parameters  

	my($inputFile) = @_;

	output_functions::print_to_log("Implementing $inputFile planes config file\n");
	open(INPUT_FILE,"$inputFile") or output_functions::die_cmd("Can't open planes config file: $inputFile\n");
	my @lines=<INPUT_FILE>;
	close(INPUT_FILE);

	my $segment = "";
	my ($voltage,$frequency) = ("","");

	foreach my $line (@lines)
	{
		chomp $line;
		$line =~ s/\r$//;
		$line =~ s/\#.*//;	### get rid of comments

		while( $line =~ s/^\s*([\_\-\[\]\.\w\d]+)// )
		{
			my $word = $1;

			if($word eq "segment") ### New segment
			{
				if( $line =~ s/^\s*([\_\-\[\]\.\w\d]+)// ) {$segment = $1;}
				($voltage,$frequency) = ("","");
			}

			elsif( ($word eq "voltage_frequency") and ($segment ne "") ) ### New work point
			{
				if( $line =~ s/^\s*([\_\-\[\]\.\w\d]+)\s+([\_\-\[\]\.\w\d]+)// ) {($voltage,$frequency) = ($1,$2);}
			}

			elsif ( ($voltage ne "") and ($frequency ne "") ) ### New component
			{
				$word =~ tr/A-Z/a-z/; # down-case all block names
				$configHash{"planes_division"}{$segment}{"$voltage,$frequency"}{$word}=1;
			}
		}
	}
}


### Static function (used inside "initConfig")
sub initHashes
{
	if(@_ != 1) {return(-1);} ## Too much/not enough parameters  

	my($inputFile) = @_;

	output_functions::print_to_log("Implementing $inputFile hashes file\n");
	open(INPUT_FILE,"$inputFile") or output_functions::die_cmd("Can't open hashes file: $inputFile\n");
	my @lines=<INPUT_FILE>;
	close(INPUT_FILE);

	my $previous_hierarchy = 0;
	my $current_hierarchy = 0;
	my @curr_location = ();
	my $spaces = "";
	my $value = "";

	foreach my $line (@lines)
	{
		chomp $line;
		$line =~ s/\r$//;
		$line =~ s/\#.*//;	### remove comments
		$line =~ s/\xa0//g;
		$line =~ s/\s*$//;

		if ($line =~ /^(\s*)(\S+.*)/)	# A valid line
		{
			$spaces = $1;
			$value = $2;
			$current_hierarchy = length($spaces);
			my $hierarchy_delta = $current_hierarchy-$previous_hierarchy;

			if($hierarchy_delta == 0)
			{
				if(@curr_location) 
				{
					addToHash([@curr_location],\%configHash);
				}

				pop(@curr_location);
				push(@curr_location,$value);
			}
			elsif($hierarchy_delta > 0)
			{
				push(@curr_location,$value);
			}
			elsif($hierarchy_delta < 0)
			{
				addToHash([@curr_location],\%configHash);

				for(my $i=$hierarchy_delta-1; $i<0; $i++)
				{
					pop(@curr_location);
				}
				push(@curr_location,$value);
			}

			$previous_hierarchy=$current_hierarchy;
		}
	}

	### Taking care of the last line
	if(@curr_location) 
	{
		addToHash([@curr_location],\%configHash);
	}
}


### Static recursive function (used inside "initHashes")
sub addToHash
{
	if(@_ !=2) 
	{
		return(-1);
	}

	my ($location, $hashPtr) = @_;

	if(!defined($$location[1])) 
	{
		$$hashPtr{$$location[0]} = 1;
		return;
	}
	my @location = @{$location}[1..@{$location}];
	addToHash([@location], \%{$hashPtr->{$$location[0]}});
}
#################
1;
