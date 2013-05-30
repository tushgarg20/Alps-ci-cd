###### calculate the leakage after creating a constants hash table
## Usage: 
##	if type=1266: 
##		Create the constants hash: 
##			create_hash(1266,"1266_input_file_name.txt")
##		Calculate the leakage (per fub):
##			calc_leakage(1266, Vcc Gate, Temperature, Z Total, %LL, %UVT, %LLUVT, 
##				Subthreshold Stack Factor, Gate Stack Factor, Junction Stack Factor, 
##				Ldrawn, PN Ratio, Guard Band Factor (should be *1.7 for typical or 1 for Lmin))
##
##	if type=1264: 
##		Create the constants hash:
##			create_hash(1264,"1264_input_file_name.txt")
##		Calculate the leakage (per fub):
##			calc_leakage(1264, Vcc Gate, Temperature, Z Total, %LL, %HP, 
##				%LL long 0.045, %LL long above 0.05, Subthreshold Stack Factor, Ldrawn,
##				PN Ratio, Guard Band Factor (should be *1.7 for typical or 1 for Lmin))

package calc_leakage;


use diagnostics;
use strict;
use Data::Dumper;
use output_functions;


### Static variables to be used throughout the module
my %constantsHash;
my $hashType=0;


### Calculating the leakage after creating the constants hash. Usage appears above.
### Returns '-1' when an error has been detected and also prints an error message to the log file
sub createHash
{
	if(@_ != 2) 
	{
		output_functions::print_to_log("Error reading the parameters in calc_leakage::createHash (missing parameters?)\n");
		return(-1); ### Paramaters are missing
	}
	my ($type, $fileName) = @_;
	
	if($type != 1264 && $type != 1266) 
	{
		output_functions::print_to_log("Error reading the 'type' parameter in calc_leakage::createHash. Use only 1266 or 1264\n");
		return(-1); ### Wrong type used.
	}
	
	%constantsHash = ();  ### Remove all keyse from hash
	initConstHash($fileName); ### Put all the constants inside the hash (initializes the hash with the right values)
	
	if(scalar(keys(%constantsHash)) < 0) 
	{
		output_functions::print_to_log("Error building the constants hash in calc_leakage::createHash\n");		
		return(-1); ### Error while building the hash.
	} 
	
	$hashType=$type;
}


### Creating the constants hash. Usage appears above.
### Returns '-1' when an error has been detected and also prints an error message to the log file
sub calcLeakage
{
	### Incase we need to do calculations for 1266 model
	if($hashType == 0)
	{
		output_functions::print_to_log("Error running calc_leakage::calcLekage. Create constants hash before running\n");
		return -1; ### Need to create a constants hash before runnning 'calcLeakage'
	} 
	if($_[0] == 1266) 
	{

		if(@_ != 13)
		{
			output_functions::print_to_log("Error reading the parameters in calc_leakage::calcLeakage (missing parameters?)\n");			
			return(-1); ### Parameters are missing
		} 
		my ($type,$vccGate, $temp, $zTotal, $llPr, $uvtPr, $lluvtPr, $subthresholdStackFactor,
			$gateStackFactor, $junction, $ldrawn, $pnRatio, $guardBand) = @_;
			
		if($hashType != $type)
		{
			output_functions::print_to_log("Error in parameter 'type' in calc_leakage::calcLeakage. Need to create a new hash for 1266?\n");
			return(-1); ### Need to create a new hash for '1266'
		} 
	    
	    	### Calculating %Nominal
		my $nominalPr = 1 - $llPr - $uvtPr - $lluvtPr;
	    
		### Calculating %N and %P
		my $pPer=$pnRatio/(1+$pnRatio);
		my $nPer=1-$pPer;
	
		### Calculating the junct
		my $junct= (
			$nPer * $zTotal * $llPr	     * calcFromHash($type, \%constantsHash, "IJUNC_NLL",   $temp,$vccGate,$ldrawn) +
			$nPer * $zTotal * $nominalPr * calcFromHash($type, \%constantsHash, "IJUNC_N",     $temp,$vccGate,$ldrawn) +
			$nPer * $zTotal * $uvtPr     * calcFromHash($type, \%constantsHash, "IJUNC_NUVT",  $temp,$vccGate,$ldrawn) +
			$nPer * $zTotal * $lluvtPr   * calcFromHash($type, \%constantsHash, "IJUNC_NLLUVT",$temp,$vccGate,$ldrawn) +  
			$pPer * $zTotal * $llPr	     * calcFromHash($type, \%constantsHash, "IJUNC_PLL",   $temp,$vccGate,$ldrawn) +
			$pPer * $zTotal * $nominalPr * calcFromHash($type, \%constantsHash, "IJUNC_P",     $temp,$vccGate,$ldrawn) +
			$pPer * $zTotal * $uvtPr     * calcFromHash($type, \%constantsHash, "IJUNC_PUVT",  $temp,$vccGate,$ldrawn) +
			$pPer * $zTotal * $lluvtPr   * calcFromHash($type, \%constantsHash, "IJUNC_PLLUVT",$temp,$vccGate,$ldrawn) ) * $junction;
	   
	
		return 
		(  

		   ( 	$nPer * $zTotal * $llPr      * calcFromHash($type, \%constantsHash, "ISB_NLL",   $temp,$vccGate,$ldrawn) +
		 	$nPer * $zTotal * $nominalPr * calcFromHash($type, \%constantsHash, "ISB_N",     $temp,$vccGate,$ldrawn) +
		 	$nPer * $zTotal * $uvtPr     * calcFromHash($type, \%constantsHash, "ISB_NUVT",  $temp,$vccGate,$ldrawn) +
		 	$nPer * $zTotal * $lluvtPr   * calcFromHash($type, \%constantsHash, "ISB_NLLUVT",$temp,$vccGate,$ldrawn) +
		 	$pPer * $zTotal * $llPr      * calcFromHash($type, \%constantsHash, "ISB_PLL",   $temp,$vccGate,$ldrawn) +
		 	$pPer * $zTotal * $nominalPr * calcFromHash($type, \%constantsHash, "ISB_P",     $temp,$vccGate,$ldrawn) +
		 	$pPer * $zTotal * $uvtPr     * calcFromHash($type, \%constantsHash, "ISB_PUVT",  $temp,$vccGate,$ldrawn) +
		 	$pPer * $zTotal * $lluvtPr   * calcFromHash($type, \%constantsHash, "ISB_PLLUVT",$temp,$vccGate,$ldrawn)
		   ) / $subthresholdStackFactor +
		
		   (	$nPer * $zTotal * $llPr      * calcFromHash($type, \%constantsHash, "IGATE_NLL",   $temp,$vccGate,$ldrawn) +
			$nPer * $zTotal * $nominalPr * calcFromHash($type, \%constantsHash, "IGATE_N",     $temp,$vccGate,$ldrawn) +
			$nPer * $zTotal * $uvtPr     * calcFromHash($type, \%constantsHash, "IGATE_NUVT",  $temp,$vccGate,$ldrawn) +
		 	$nPer * $zTotal * $lluvtPr   * calcFromHash($type, \%constantsHash, "IGATE_NLLUVT",$temp,$vccGate,$ldrawn) +
			$pPer * $zTotal * $llPr      * calcFromHash($type, \%constantsHash, "IGATE_PLL",   $temp,$vccGate,$ldrawn) +
			$pPer * $zTotal * $nominalPr * calcFromHash($type, \%constantsHash, "IGATE_P",     $temp,$vccGate,$ldrawn) +
			$pPer * $zTotal * $uvtPr     * calcFromHash($type, \%constantsHash, "IGATE_PUVT",  $temp,$vccGate,$ldrawn) +
			$pPer * $zTotal * $lluvtPr   * calcFromHash($type, \%constantsHash, "IGATE_PLLUVT",$temp,$vccGate,$ldrawn)	
		   ) * $gateStackFactor + $junct
		
		 ) * 1.15 * 1000 * $guardBand * $vccGate;	 
	 
	}
	### Incase we need to do calculations for 1264 model
	if($_[0] == 1264) 
	{
		if(@_ != 12)
		{
			output_functions::print_to_log("Error reading the parameters in calc_leakage::calcLeakage (missing parameters?)\n");			
			return(-1); ### Need to create a constants hash before runnning 'calcLeakage'
		} 
		
		my ($type, $vccGate, $temp, $zTotal, $llPr, $hpPr, $ll45Pr, $ll50Pr,
			$subthresholdStackFactor, $ldrawn, $pnRatio, $guardBand) = @_;
			
		if($hashType != $type)
		{
			output_functions::print_to_log("Error in parameter 'type' in calc_leakage::calcLeakage. Need to create a new hash for 1264?\n");
			return(-1); ### Need to create a new hash for '1264'
		} 
		    
		### Calculating %Nominal
		my $nominalPr = 1 - $llPr - $hpPr - $ll45Pr - $ll50Pr;
		
		### Calculating offsets
		my $offset45 = $ldrawn+0.0045;
		my $offset50 = $ldrawn+0.005;
	    
		### Calculating %N and %P
		my $pPer=$pnRatio/(1+$pnRatio);
		my $nPer=1-$pPer;
	
		### Calculating the junction
		my $junction = 
			(
			$nPer * $zTotal * ($llPr+$ll45Pr+$ll50Pr) * calcFromHash($type, \%constantsHash,"IJUNC_NLL",$temp,$vccGate,$ldrawn)+
			$nPer * $zTotal * $hpPr			  * calcFromHash($type, \%constantsHash,"IJUNC_NHP",$temp,$vccGate,$ldrawn)+
			$nPer * $zTotal * $nominalPr		  * calcFromHash($type, \%constantsHash,"IJUNC_N"  ,$temp,$vccGate,$ldrawn)+
			$pPer * $zTotal * ($llPr+$ll45Pr+$ll50Pr) * calcFromHash($type, \%constantsHash,"IJUNC_PLL",$temp,$vccGate,$ldrawn)+
			$pPer * $zTotal * $hpPr			  * calcFromHash($type, \%constantsHash,"IJUNC_PHP",$temp,$vccGate,$ldrawn)+
			$pPer * $zTotal * $nominalPr		  * calcFromHash($type, \%constantsHash,"IJUNC_P"  ,$temp,$vccGate,$ldrawn) 
			) / 2;
			
		### Calculating the long L
		my $longL = 
			(
			   (
			   $nPer * $zTotal * $ll45Pr * calcFromHash($type, \%constantsHash,"ISB_N",  $temp, $vccGate, $offset45) +
			   $pPer * $zTotal * $ll45Pr * calcFromHash($type, \%constantsHash,"ISB_P",  $temp, $vccGate, $offset45) +
			   $nPer * $zTotal * $ll50Pr * calcFromHash($type, \%constantsHash,"ISB_N",  $temp, $vccGate, $offset50) +
		 	   $pPer * $zTotal * $ll50Pr * calcFromHash($type, \%constantsHash,"ISB_P",  $temp, $vccGate, $offset50)
			   ) / $subthresholdStackFactor +
			    
			   (
			   $nPer * $zTotal * $ll45Pr * calcFromHash($type, \%constantsHash,"IGATE_N",$temp, $vccGate, $offset45) +
			   $pPer * $zTotal * $ll45Pr * calcFromHash($type, \%constantsHash,"IGATE_P",$temp, $vccGate, $offset45) +
			   $nPer * $zTotal * $ll50Pr * calcFromHash($type, \%constantsHash,"IGATE_N",$temp, $vccGate, $offset50) +
			   $pPer * $zTotal * $ll50Pr * calcFromHash($type, \%constantsHash,"IGATE_P",$temp, $vccGate, $offset50)
			   ) / 2 
			   
			) * 1;
			
		return 
		(  
		   (    $nPer * $zTotal * $llPr      * calcFromHash($type, \%constantsHash, "ISB_NLL",  $temp,$vccGate,$ldrawn) +
			$nPer * $zTotal * $hpPr      * calcFromHash($type, \%constantsHash, "ISB_NHP",  $temp,$vccGate,$ldrawn) +
			$nPer * $zTotal * $nominalPr * calcFromHash($type, \%constantsHash, "ISB_N",    $temp,$vccGate,$ldrawn) +
			$pPer * $zTotal * $llPr	     * calcFromHash($type, \%constantsHash, "ISB_PLL",  $temp,$vccGate,$ldrawn) +
			$pPer * $zTotal * $hpPr	     * calcFromHash($type, \%constantsHash, "ISB_PHP",  $temp,$vccGate,$ldrawn) +
			$pPer * $zTotal * $nominalPr * calcFromHash($type, \%constantsHash, "ISB_P",    $temp,$vccGate,$ldrawn)
		    ) / $subthresholdStackFactor +
		    
		    (	$nPer * $zTotal * $llPr	     * calcFromHash($type, \%constantsHash, "IGATE_NLL",$temp,$vccGate,$ldrawn) +
			$nPer * $zTotal * $hpPr	     * calcFromHash($type, \%constantsHash, "IGATE_NHP",$temp,$vccGate,$ldrawn) +
			$nPer * $zTotal * $nominalPr * calcFromHash($type, \%constantsHash, "IGATE_N",  $temp,$vccGate,$ldrawn) +
			$pPer * $zTotal * $llPr      * calcFromHash($type, \%constantsHash, "IGATE_PLL",$temp,$vccGate,$ldrawn) +
			$pPer * $zTotal * $hpPr      * calcFromHash($type, \%constantsHash, "IGATE_PHP",$temp,$vccGate,$ldrawn) +
			$pPer * $zTotal * $nominalPr * calcFromHash($type, \%constantsHash, "IGATE_P",  $temp,$vccGate,$ldrawn)
		    ) / 2 + $junction + $longL
		    
		) * 1.15 * 1000 * $guardBand * $vccGate;	
	}
	
	output_functions::print_to_log("Error in parameter 'type' in calc_leakage::calcLeakage. Parameter must be 1264 or 1266");
	return -1; ### Wrong type entered!
}


###### Return the desired parameters for the leakage when using "design type" instead of the explicit parameters
###### Remark: meanwhile this option works only for 1266 type
## usage: getDesignParameters(Type (1264 or 1266), Design Type, Output hash table)
sub getDesignParameters
{
    if(@_ !=3) {return -1;} ### Missing/not enough arguments. Returning error value ('-1')
    
    my ($type,$designType,$returnHash) = @_;

    $$returnHash{"ldrawn"}=0.04;

    if($designType eq "DP") 
    {
	$$returnHash{"zTotal"} = 58928.0685;
	$$returnHash{"llPr"} = 0.649;
	$$returnHash{"uvtPr"} = 0;
	$$returnHash{"lluvtPr"} = 0;
	$$returnHash{"pnRatio"} = 1.222;
	$$returnHash{"subthresholdStackFactor"} = 2.952;
	$$returnHash{"gateStackFactor"} = 0.519;
	$$returnHash{"junctionStackFactor"} = 1/1.809;
    }
    elsif($designType eq "RLS")
    {
	$$returnHash{"zTotal"} = 51441.281;
	$$returnHash{"llPr"} = 0.543;
	$$returnHash{"uvtPr"} = 0;
	$$returnHash{"lluvtPr"} = 0;
	$$returnHash{"pnRatio"} = 1.301;
	$$returnHash{"subthresholdStackFactor"} = 1/0.358;
	$$returnHash{"gateStackFactor"} = 0.464;
	$$returnHash{"junctionStackFactor"} = 1/2.329;
    }
    elsif($designType eq "RF")
    {
	$$returnHash{"zTotal"} = 48496.328;
	$$returnHash{"llPr"} = 0.642;
	$$returnHash{"uvtPr"} = 0;
	$$returnHash{"lluvtPr"} = 0;
	$$returnHash{"pnRatio"} = 0.8;
	$$returnHash{"subthresholdStackFactor"} = 1/0.305;
	$$returnHash{"gateStackFactor"} = 0.295;
	$$returnHash{"junctionStackFactor"} = 1/2.116;
    }
    elsif($designType eq "Repeaters")
    {
	$$returnHash{"zTotal"} = 14288.274;
	$$returnHash{"llPr"} = 0.747;
	$$returnHash{"uvtPr"} = 0;
	$$returnHash{"lluvtPr"} = 0;
	$$returnHash{"pnRatio"} = 1.654;
	$$returnHash{"subthresholdStackFactor"} = 2.105;
	$$returnHash{"gateStackFactor"} = 0.489;
	$$returnHash{"junctionStackFactor"} = 1/2.156;
    }
    elsif($designType eq "Gigacell")
    {
	$$returnHash{"zTotal"} = 26878.73;
	$$returnHash{"llPr"} = 0.3134;
	$$returnHash{"uvtPr"} = 0;
	$$returnHash{"lluvtPr"} = 0;
	$$returnHash{"pnRatio"} = 0.672;
	$$returnHash{"subthresholdStackFactor"} = 3.399;
	$$returnHash{"gateStackFactor"} = 0.320;
	$$returnHash{"junctionStackFactor"} = 1/1.473;
    }
    elsif($designType eq "fub")
    {
	$$returnHash{"zTotal"} = 40000.0;
	$$returnHash{"llPr"} = 0.7;
	$$returnHash{"uvtPr"} = 0;
	$$returnHash{"lluvtPr"} = 0;
	$$returnHash{"pnRatio"} = 1.03;
	$$returnHash{"subthresholdStackFactor"} = 3.11;
	$$returnHash{"gateStackFactor"} = 0.5;
	$$returnHash{"junctionStackFactor"} = 1/2;
    }
    elsif($designType eq "ROM")
    {
	$$returnHash{"zTotal"} = 40000.0;
	$$returnHash{"llPr"} = 0.7;
	$$returnHash{"uvtPr"} = 0;
	$$returnHash{"lluvtPr"} = 0;
	$$returnHash{"pnRatio"} = 1.2;
	$$returnHash{"subthresholdStackFactor"} = 1/0.380;
	$$returnHash{"gateStackFactor"} = 0.248;
	$$returnHash{"junctionStackFactor"} = 1/2;
    }
    elsif($designType eq "SDP")
    {
	$$returnHash{"zTotal"} = 40000.0;
	$$returnHash{"llPr"} = 0.7;
	$$returnHash{"uvtPr"} = 0;
	$$returnHash{"lluvtPr"} = 0;
	$$returnHash{"pnRatio"} = 1.2;
	$$returnHash{"subthresholdStackFactor"} = 1/0.424;
	$$returnHash{"gateStackFactor"} = 0.438;
	$$returnHash{"junctionStackFactor"} = 1/2;
    }
   
    else {output_functions::print_to_log("Unknwon design type: '$designType'\n");}
}

###### Static function for doing the calculation needed from constants hash
## usage: calcFromHash(Type (1264 or 1266), Constants hash table, Part Type (as a string), Temperature, Vcc Gate, Ldrawn)
sub calcFromHash
{
	if(@_ != 6) {return -1;} ### Missing/not enough arguments. Returning error value ('-1')

	my ($type, $constantsHash, $keyValue, $T, $vcc, $L) = @_;
	my @v;
	my $itv;
		
	### building the parameters for the formula
	for(my $i=0; $i<3; $i++) 
	{
		for(my $j=0; $j<5; $j++)
		{
			if(	!defined($constantsHash{$keyValue}{$i}{$j}{0}) ||
				!defined($constantsHash{$keyValue}{$i}{$j}{1}) ||
				!defined($constantsHash{$keyValue}{$i}{$j}{2}) ||
				!defined($constantsHash{$keyValue}{$i}{$j}{3})	) 
			{
				output_functions::print_to_log("Error reading constants hash in calc_leakage::calcFromHash. Missing constant in constantsHash{$keyValue}{$i}{$j}\n");
				return(-1); ### Missing constant in constants hash
			}
			
			$v[$i][$j]=$constantsHash{$keyValue}{$i}{$j}{0} + $constantsHash{$keyValue}{$i}{$j}{1} * $L +
				       $constantsHash{$keyValue}{$i}{$j}{2} * ($L*$L) + $constantsHash{$keyValue}{$i}{$j}{3} *
				       ($L*$L*$L);

### Print the keys values (for debugging!)
# 			print STDERR "$keyValue: v[$i][$j] = $v[$i][$j]\n";
		}
	}
	
	$itv=exp( ($v[0][0] + $v[0][1]*$T + $v[0][2]*($T*$T) + $v[0][3]*($T*$T*$T) + $v[0][4]*($T*$T*$T*$T))+ 
		  ($v[1][0] + $v[1][1]*$T + $v[1][2]*($T*$T) + $v[1][3]*($T*$T*$T) + $v[1][4]*($T*$T*$T*$T))*$vcc +
		  ($v[2][0] + $v[2][1]*$T + $v[2][2]*($T*$T) + $v[2][3]*($T*$T*$T) + $v[2][4]*($T*$T*$T*$T))*$vcc*$vcc );
	
	if($type == 1266) {return (1/0.5)  * $itv;}
	if($type == 1264) {return (1/0.55) * $itv;}
	return -1; ### Wrong type!
}


###### Static function for creating the constants hash (pattern matching from input file)
### usage: initConstHash(filename)
sub initConstHash
{
	if(@_ != 1) {return(-1);} ## Too much/not enough parametrs
	
	my ($fileName) = @_;
	my @lines;

	$fileName = glob($fileName);
	open(INPUTFILE,"$fileName") or output_functions::die_cmd("Can't open $fileName\n");
	@lines=<INPUTFILE>;
	close(INPUTFILE);
	
	foreach my $line (@lines) ### Read the input file into the constants hash
	{
		chomp $line;
		$line =~ s/\r$//;
		
		### Get the string at the beggining of the line, and then the 4 constants numbers (of the array)
		if($line =~
/^\s*(\w+)\s+=\s+Array\(\s*(-?\d+\.\d+E?-?\d*)\s*,\s*(-?\d+\.\d+E?-?\d*)\s*,\s*(-?\d+\.\d+E?-?\d*)\s*,\s*(-?\d+\.\d+E?-?\d*)\s*\)/)
		{
			my @name = split(//,$1); ### Containts the word at the beggining of the line (as an array)
			my $key = "";            ### Will contain the key name (the string until the 2nd underscore)


			### Initialize the key (to contain the string until the 2nd underscore)
			for(my $index=0, my $foundTwice=0;$foundTwice<2;$index++)
			{
				$key.=$name[$index];
				if($name[$index+1] eq "_")
				{						
					$foundTwice++;
				}
				if($index>255)
				{
					output_functions::print_to_log("Error in calc_leakage::initConstHash while retrieving key value from \"$1\"\n");					
					last;
				}
			}
			
			
			### Create the hash table and put the constants numbers in their right place inside of it
			$constantsHash{$key}{$name[-3]}{$name[-1]}{0}=$2;
			$constantsHash{$key}{$name[-3]}{$name[-1]}{1}=$3;
			$constantsHash{$key}{$name[-3]}{$name[-1]}{2}=$4;
			$constantsHash{$key}{$name[-3]}{$name[-1]}{3}=$5;
		}
	}
	
	### Print the hashes (for DEBUGGING!)
#	print STDERR Dumper(\%constantsHash);
}

#################
1;
