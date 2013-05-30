#!/usr/bin/perl
################################################################################
use strict;
use FindBin qw($Bin);

use lib "$Bin";
use StatObj;
################################################################################

my $statfilename = shift;
my $vlv			 = shift;
my $gen			 = shift;
my $odir		 = shift;

my $factor = 1 ;
if($vlv == 1)
{
	$factor = 3 ;
}
if($vlv == 2)
{
	$factor = 3/2 ;
}

my $lrSimData = [];
InitSimDataStructure($lrSimData);

open (my $fhSTAT, $statfilename) || die ("Couldn't open GennySim stat file $statfilename");
FindSTATIColumnHdrs($fhSTAT, $lrSimData);
close ($fhSTAT);

open (my $fhSTAT, $statfilename) || die ("Couldn't open GennySim stat file $statfilename");
GetSTATIRecord($fhSTAT, $lrSimData);
close ($fhSTAT);

# PrintStats($lrSimData);

my $formulas = {};
my $base_stat_tbl = {} ;
my $derived_stat_tbl   = {};
my @base_stat_names ;

my $i = 0 ;
foreach my $SimDataListEntry (@$lrSimData){
	$base_stat_tbl->{$SimDataListEntry->{'Name'}} =  $SimDataListEntry->{'StatObj'}->GetThisRecord() ;
	$base_stat_names[$i] = $SimDataListEntry->{'Name'} ;
	$i++ ;
}

my @RATIO_TABLE = (
	["PS0_GAM",           "uGAM.idle_cycles"],
	["PS1_GAM",           "uGAM.active_stalled_cycles"],
	["PS2_GAM",           "uGAM.active_not_stalled_cycles"],
	["PS0_nonGAM",        "uGAP.idle_cycles"],
	["PS1_nonGAM",        "uGAP.active_stalled_cycles"],
	["PS2_nonGAM",        "uGAP.active_not_stalled_cycles"],
	["PS0_GTI_Glue",      "glue.idle_cycles "],
	["PS1_GTI_Glue",      "glue.active_stalled_cycles "],
	["PS2_GTI_Glue",      "glue.active_not_stalled_cycles"]
);
 

foreach my $f (@RATIO_TABLE){
	$formulas->{$f->[0]} = &CalcRatio($f->[1]);
}

my @derived_stat_names = sort keys %{$formulas};

foreach my $d (@derived_stat_names)
{
	$derived_stat_tbl->{$d} = $formulas->{$d} ;
}

#####################################################
# Printing out stats unit-wise
#####################################################
my $count = 0 ;
open(FP, '>' . $odir . 'gti_alps1_1.csv');
print FP"Power Stat,Residency\n";

foreach  my $unit ("GAM","nonGAM","GTI_Glue")
{
    for($count=0; $count <= $#derived_stat_names; $count++)
	{
        if($derived_stat_names[$count] =~ m/PS(.*?)\_$unit(.*)/i)
		{
            print FP"$derived_stat_names[$count],$derived_stat_tbl->{$derived_stat_names[$count]}\n";
        }
    }
}

close(FP);
print "\n";

# the end

################################################################################


################################################################################
# sub InitSimDataStructure
################################################################################
sub InitSimDataStructure {
	my $lrSimData = shift;

	push (@$lrSimData, {
	'Name' => 'GennysimStatClks',
	'StatObj' => StatIStatObj->new({'m_StatName' => 'GennySim.StatClocks',
								 'm_DoTestMaxVal' => 0})
	});
   
	push (@$lrSimData, {
	'Name' => 'uGAM.idle_cycles',
	'StatObj' => StatIStatObj->new({'m_StatName' => 'uGAM.power_fub.idle',
								 'm_DoTestMaxVal' => 0})
	});
	
	push (@$lrSimData, {
	'Name' => 'uGAM.active_stalled_cycles',
	'StatObj' => StatIStatObj->new({'m_StatName' => 'uGAM.power_fub.stalled',
								 'm_DoTestMaxVal' => 0})
	});
	
	push (@$lrSimData, {
	'Name' => 'uGAM.active_not_stalled_cycles',
	'StatObj' => StatIStatObj->new({'m_StatName' => 'uGAM.power_fub.active',
								 'm_DoTestMaxVal' => 0})
	});
	
	push (@$lrSimData, {
	'Name' => 'uGAP.idle_cycles',
	'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uGAP_\\d+\\.power_fub\\.idle',
									  'm_ReportDataAs' => 'AVERAGEDIV1',
									  'm_DoTestMaxVal' => 0})
	});
	push (@$lrSimData, {
	'Name' => 'uGAP.active_stalled_cycles',
	'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uGAP_\\d+\\.power_fub\\.stalled',
									  'm_ReportDataAs' => 'AVERAGEDIV1',
									  'm_DoTestMaxVal' => 0})
	});

	push (@$lrSimData, {
	'Name' => 'uGAP.active_not_stalled_cycles',
	'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uGAP_\\d+\\.power_fub\\.active',
										  'm_ReportDataAs' => 'AVERAGEDIV1',
										  'm_DoTestMaxVal' => 0})
	});
}

################################################################################
# sub FindSTATIColumnHdrs
################################################################################
sub FindSTATIColumnHdrs() {

   my $fhSTATI = shift;
   my $lrSimData = shift;
   
   my $hrStatIColumnNames = {};
   while (<$fhSTATI>) {
      if (/^\s*$/) {next;} # Skipping blank lines
      if (/^\s*#/) {next;} # comments get skipped
      if (/^---+/) {next;} # visual delimiters get skipped
	  if (/^=+/) {next;} # visual delimiters get skipped
	  if (/^\s.*/) {next;} # Skipping extra stuff in new Gennysim files
	  if (/^\s*\w+$/) {next;} # Skipping extra stuff in new Gennysim files
	  if (/^knob/) {next;} # Skipping knobs in new Gennysim files
	  if (/^\S+:\S+\s:/) {next;} # Skipping knobs in media Gennysim files
      if (/(begin|end)_histogram\s*$/) {next;}  # histogram delimiters get skipped
	  if (/(begin|end)_utilization\s*$/) {next;}  # utilization delimiters get skipped
	if (/_sz $/) {next;} #Skipping new stats    
	unless (/^(\S+)\s+(\S+)\s*(#.*)?$/) {chomp; die ("Badly formatted STATI line $.: $_");}
      
      my $name = $1;
      my $value = $2;
      # Comment would be $3...
      
      if (exists($hrStatIColumnNames->{$1})) {
		 print "It fails at: " . $name . "\n" ;
         die ("STATI repeats data name $1 on line $.");
      }
      $hrStatIColumnNames->{$1} = $2;
   }

   foreach my $SimDataListEntry (@$lrSimData) {
      if (grep $SimDataListEntry->{'StatObj'}->isa($_), qw(MultiStatIStatObj)) { 
         $SimDataListEntry->{'StatObj'}->SetupMultiStatIStats($hrStatIColumnNames);
      }
   }   
}


################################################################################
# sub GetSTATIRecord
################################################################################
sub GetSTATIRecord() {

   my $fhSTATI = shift;
   my $lrSimData = shift;

   my $hrStatIRecord = {};

   while (<$fhSTATI>) {
      if (/^\s*$/) {next;} # Skipping blank lines
      if (/^\s*#/) {next;} # comments get skipped
      if (/^---+/) {next;} # visual delimiters get skipped
	  if (/^=+/) {next;} # visual delimiters get skipped
	  if (/^\s.*/) {next;} # Skipping extra stuff in new Gennysim files
	  if (/^\s*\w+$/) {next;} # Skipping extra stuff in new Gennysim files
	  if (/^knob/) {next;} # Skipping knobs in new Gennysim files
	  if (/^\S+:\S+\s:/) {next;} # Skipping knobs in media Gennysim files
      if (/(begin|end)_histogram\s*$/) {next;}  # histogram delimiters get skipped
	  if (/(begin|end)_utilization\s*$/) {next;}  # utilization delimiters get skipped
	if (/_sz $/) {next;} #Skipping new stats    
      unless (/^(\S+)\s+(\S+)\s*(#.*)?$/) {chomp; die ("Badly formatted STATI line $.: $_");}
      
      my $name = $1;
      my $value = $2;
      # Comment would be $3...
      
      if (exists($hrStatIRecord->{$1})) {
         die ("STATI repeats data name $1 on line $.");
      }
      $hrStatIRecord->{$1} = $2;
   }

   foreach my $SimDataListEntry (@$lrSimData) {
      if (grep $SimDataListEntry->{'StatObj'}->isa($_), qw(StatIStatObj StateStatIStatObj MultiStatIStatObj)) { 
         $SimDataListEntry->{'StatObj'}->LatchRecord($hrStatIRecord);
      }
   }            
}

################################################################################
# sub PrintStats
################################################################################
sub PrintStats {

   my $lrSimData = shift;
   
   foreach my $SimDataListEntry (@$lrSimData) {
   
      print ($SimDataListEntry->{'Name'} . "," . $SimDataListEntry->{'StatObj'}->GetThisRecord() . "\n");
   
   }

}

################################################################################
# sub CalcValues
################################################################################

sub CalcRatio{
	my $N = shift;
	if($N eq "0")
	{
		return 0 ;
	}
	if($N eq "GennysimStatClks")
	{
		return 1 ;
	}
	my $numerator = $base_stat_tbl->{$N} ;
	if($N =~ m/sram/)
	{
		# my @data = split/\./, $N ;
		# my $unit = $data[0] . "." . $data[1] ;
		my $denominator = $base_stat_tbl->{"GennysimStatClks"} ;
		if($denominator == 0)
		{
			return 0 ;
		}
		return $numerator/$denominator ;
	}
	my @data = split/\./, $N ;
	my $unit = $data[0] ;
	my $denominator = $base_stat_tbl->{$unit . ".idle_cycles"} + $base_stat_tbl->{$unit . ".active_stalled_cycles"} + $base_stat_tbl->{$unit . ".active_not_stalled_cycles"} ;
	if($denominator == 0)
	{
		return 0 ;
	}
	return $numerator/$denominator ;
};
