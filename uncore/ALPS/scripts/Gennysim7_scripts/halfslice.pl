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
		["PS0_MA", 0],
		["PS1_MA", 0],
		["PS2_MA", 0],
		["PS0_MA_IN",  "MAI.idle_cycles"],
		["PS1_MA_IN",  "MAI.active_stalled_cycles"],
		["PS2_MA_IN",  "MAI.active_not_stalled_cycles"],
		["PS0_MA_OUT", "MAO.idle_cycles"],
		["PS1_MA_OUT", "MAO.active_stalled_cycles"],
		["PS2_MA_OUT", "MAO.active_not_stalled_cycles"],
		["PS0_HDC", "DC.idle_cycles"],
		["PS1_HDC", "DC.active_stalled_cycles"],
		["PS2_HDC", "DC.active_not_stalled_cycles"],
		["PS0_TDL", "TDL.idle_cycles"],
		["PS1_TDL", "TDL.active_stalled_cycles"],
		["PS2_TDL", "TDL.active_not_stalled_cycles"],
		["PS0_DAPRHS", "DAPHS.idle_cycles"],
		["PS1_DAPRHS", "DAPHS.active_stalled_cycles"],
		["PS2_DAPRHS", "DAPHS.active_not_stalled_cycles"],
		["PS0_BC", "BC.idle_cycles"],
		["PS1_BC", "BC.active_stalled_cycles"],
		["PS2_BC", "BC.active_not_stalled_cycles"],
		["PS0_PSD", "PSD.idle_cycles"],
		["PS1_PSD", "PSD.active_stalled_cycles"],
		["PS2_PSD", "PSD.active_not_stalled_cycles"],
		["PS0_IC", "GennysimStatClks"],
		["PS1_IC", 0],
		["PS2_IC", 0],
		["PS0_GW", "GennysimStatClks"],
		["PS1_GW", 0],
		["PS2_GW", 0],
		["PS0_HalfSlice1_Glue", "DC.idle_cycles"],
		["PS1_HalfSlice1_Glue", "DC.active_stalled_cycles"],
		["PS2_HalfSlice1_Glue", "DC.active_not_stalled_cycles"],
		["PS0_HalfSlice2_Glue", "si.idle_cycles"],
		["PS1_HalfSlice2_Glue", "si.active_stalled_cycles"],
		["PS2_HalfSlice2_Glue", "si.active_not_stalled_cycles"],
		["PS0_HalfSlice3_Glue", "so.idle_cycles"],
		["PS1_HalfSlice3_Glue", "so.active_stalled_cycles"],
		["PS2_HalfSlice3_Glue", "so.active_not_stalled_cycles"],
		["PS0_HalfSlice4_Glue", "DAPHS.idle_cycles"],
		["PS1_HalfSlice4_Glue", "DAPHS.active_stalled_cycles"],
		["PS2_HalfSlice4_Glue", "DAPHS.active_not_stalled_cycles"],
		["PS0_HalfSlice5_Glue", "PSD.idle_cycles"],
		["PS1_HalfSlice5_Glue", "PSD.active_stalled_cycles"],
		["PS2_HalfSlice5_Glue", "PSD.active_not_stalled_cycles"],
		["PS0_HalfSlice6_Glue", "dg.idle_cycles"],
		["PS1_HalfSlice6_Glue", "dg.active_stalled_cycles"],
		["PS2_HalfSlice6_Glue", "dg.active_not_stalled_cycles"],
		["PS0_HalfSlice7_Glue", "sc.idle_cycles"],
		["PS1_HalfSlice7_Glue", "sc.active_stalled_cycles"],
		["PS2_HalfSlice7_Glue", "sc.active_not_stalled_cycles"],
		["PS0_HalfSlice8_Glue", "si.idle_cycles"],
		["PS1_HalfSlice8_Glue", "si.active_stalled_cycles"],
		["PS2_HalfSlice8_Glue", "si.active_not_stalled_cycles"],
		["PS0_HalfSlice9_Glue", "si.idle_cycles"],
		["PS1_HalfSlice9_Glue", "si.active_stalled_cycles"],
		["PS2_HalfSlice9_Glue", "si.active_not_stalled_cycles"],
		["PS0_HalfSlice10_Glue", "GennysimStatClks"],
		["PS1_HalfSlice10_Glue", 0],
		["PS2_HalfSlice10_Glue", 0],
		["PS0_HalfSlice11_Glue", "GennysimStatClks"],
		["PS1_HalfSlice11_Glue", 0],
		["PS2_HalfSlice11_Glue", 0]
) ;
	 
foreach my $f (@RATIO_TABLE){
	$formulas->{$f->[0]} = &CalcRatio($f->[1]);
}

$formulas->{"PS2_IC_DataRam_READ"}				= &CalcPS2_IC_DataRam_READ() ;
$formulas->{"PS2_IC_DataRam_WRITE"}				= $base_stat_tbl->{"IC_Miss"}/$base_stat_tbl->{"GennysimStatClks"} ;
$formulas->{"PS2_IC_DataRam_READ&WRITE"}		= 0 ;
$formulas->{"PS0_IC_DataRam_IDLE"}				= 1 - $formulas->{"PS2_IC_DataRam_READ"} - $formulas->{"PS2_IC_DataRam_WRITE"} ;

$formulas->{"PS2_Other_HS_SmallUnits"} = &CalcPS2_Other_HS_SmallUnits() ;
$formulas->{"PS0_Other_HS_SmallUnits"} = (1 - $formulas->{"PS2_Other_HS_SmallUnits"})/2 ;
$formulas->{"PS1_Other_HS_SmallUnits"} = $formulas->{"PS0_Other_HS_SmallUnits"} ;

$formulas->{"PS0_BC_DataRam_IDLE"}						= 0 ;
$formulas->{"PS2_BC_DataRam_READ"}						= 0 ;
$formulas->{"PS2_BC_DataRam_WRITE"}						= 0 ;
$formulas->{"PS2_BC_DataRam_READ&WRITE"}				= 0 ;

$formulas->{"PS0_PSD_DataRam_IDLE"}						= 0 ;
$formulas->{"PS2_PSD_DataRam_READ"}						= 0 ;
$formulas->{"PS2_PSD_DataRam_WRITE"}					= 0 ;
$formulas->{"PS2_PSD_DataRam_READ&WRITE"}				= 0 ;
$formulas->{"PS0_DAPRHS_DataRam_IDLE"}					= 0 ;
$formulas->{"PS2_DAPRHS_DataRam_READ"}					= 0 ;
$formulas->{"PS2_DAPRHS_DataRam_WRITE"}					= 0 ;
$formulas->{"PS2_DAPRHS_DataRam_READ&WRITE"}			= 0 ;

my @derived_stat_names = sort keys %{$formulas};

foreach my $d (@derived_stat_names)
{
	$derived_stat_tbl->{$d} = $formulas->{$d} ;
}

#####################################################
# Printing out stats unit-wise
#####################################################
my $count = 0 ;

open(FP, '>' . $odir . 'halfslice_alps1_1.csv');
print FP"Power Stat,Residency\n";

foreach  my $unit ("MA","MA_IN","MA_OUT","IC","IC_DataRam","HDC","TDL","BC","BC_DataRam","PSD","PSD_DataRam","DAPRHS","DAPRHS_DataRam","GW","Other_HS_SmallUnits","HalfSlice1_Glue","HalfSlice2_Glue","HalfSlice3_Glue","HalfSlice4_Glue","HalfSlice5_Glue","HalfSlice6_Glue","HalfSlice7_Glue","HalfSlice8_Glue","HalfSlice9_Glue","HalfSlice10_Glue","HalfSlice11_Glue")
{
    if($unit eq "IC_DataRam" || $unit eq "BC_DataRam" || $unit eq "PSD_DataRam" || $unit eq "DAPRHS_DataRam")
	{
		for($count=0; $count <= $#derived_stat_names; $count++)
		{
			if($derived_stat_names[$count] =~ m/PS(.*?)\_$unit(.*)/i) 
			{
				print FP"$derived_stat_names[$count],$derived_stat_tbl->{$derived_stat_names[$count]}\n";
			}
		}
	}
	else
	{
		for($count=0; $count <= $#derived_stat_names; $count++)
		{
			if($derived_stat_names[$count] =~ m/PS(.*?)\_$unit$/i)
			{
				print FP"$derived_stat_names[$count],$derived_stat_tbl->{$derived_stat_names[$count]}\n" ;
			}
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
   
   # AVERAGEDIV1 averages the value across all the stats whose names match the regex.
   # (Should be the only average you need; the more general form was a hack for AMX
   # that I'd probably do differently, in hindsight.) 
   # my $unit = "alloc" ;
   
	foreach my $unit ("DC","TDL","si","so","dg","sc","alloc","PSD","BC","DAPHS","MAI","MAO")
	{
		if ( $unit eq "DC" || $unit eq "PSD" || $unit eq "BC" || $unit eq "DAPHS" || $unit eq "TDL" || $unit eq "MAI" || $unit eq "MAO")
		{
			push (@$lrSimData, {
			'Name' => $unit . '.idle_cycles',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'u' .$unit . '_\\d+\\.power_fub\\.idle',
                                              'm_ReportDataAs' => 'AVERAGEDIV1',
                                              'm_DoTestMaxVal' => 0})
			});
			
			push (@$lrSimData, {
			'Name' => $unit . '.active_stalled_cycles',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'u' .$unit . '_\\d+\\.power_fub\\.stalled',
                                              'm_ReportDataAs' => 'AVERAGEDIV1',
                                              'm_DoTestMaxVal' => 0})
			});
			
			push (@$lrSimData, {
			'Name' => $unit . '.active_not_stalled_cycles',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'u' .$unit . '_\\d+\\.power_fub\\.active',
                                              'm_ReportDataAs' => 'AVERAGEDIV1',
                                              'm_DoTestMaxVal' => 0})
			});
		}
		elsif ($unit eq "alloc")
		{
			push (@$lrSimData, {
			'Name' => 'mt.idle_cycles',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uMT_\\d+\\.' . $unit . '_idle_cycles_\\d',
                                              'm_ReportDataAs' => 'AVERAGEDIV1',
                                              'm_DoTestMaxVal' => 0})
			});
			
			push (@$lrSimData, {
			'Name' => 'mt.active_stalled_cycles',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uMT_\\d+\\.' . $unit . '_active_stalled_cycles_\\d',
                                              'm_ReportDataAs' => 'AVERAGEDIV1',
                                              'm_DoTestMaxVal' => 0})
			});
			
			push (@$lrSimData, {
			'Name' => 'mt.active_not_stalled_cycles',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uMT_\\d+\\.' . $unit . '_active_not_stalled_cycles_\\d',
                                              'm_ReportDataAs' => 'AVERAGEDIV1',
                                              'm_DoTestMaxVal' => 0})
			});
		}
		else
		{
			push (@$lrSimData, {
			'Name' => $unit . '.idle_cycles',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uSampler_\\d+\\.' .$unit . '_idle_cycles',
                                              'm_ReportDataAs' => 'AVERAGEDIV1',
                                              'm_DoTestMaxVal' => 0})
			});
			
			push (@$lrSimData, {
			'Name' => $unit . '.active_stalled_cycles',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uSampler_\\d+\\.' .$unit . '_active_stalled_cycles',
                                              'm_ReportDataAs' => 'AVERAGEDIV1',
                                              'm_DoTestMaxVal' => 0})
			});
			
			push (@$lrSimData, {
			'Name' => $unit . '.active_not_stalled_cycles',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uSampler_\\d+\\.' .$unit . '_active_not_stalled_cycles',
                                              'm_ReportDataAs' => 'AVERAGEDIV1',
                                              'm_DoTestMaxVal' => 0})
			});
		}
	}
	
	push (@$lrSimData, {
	'Name' => 'IC_Hit',
	'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uICache_\\d+\\.ICHitBank\\d+',
									  'm_ReportDataAs' => 'AVERAGEDIV1',
									  'm_DoTestMaxVal' => 0})
	});
	
	push (@$lrSimData, {
	'Name' => 'IC_Miss',
	'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uICache_\\d+\\.ICMissBank\\d+',
									  'm_ReportDataAs' => 'AVERAGEDIV1',
									  'm_DoTestMaxVal' => 0})
	});
	
	push (@$lrSimData, {
	'Name' => 'IC_HitOnMiss',
	'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uICache_\\d+\\.ICHitOnMissBank\\d+',
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
# sub CalcRatio
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

sub CalcPS2_IC_DataRam_READ{
	my $denominator = $base_stat_tbl->{"GennysimStatClks"} ;
	my $numerator = $base_stat_tbl->{"IC_Hit"} + $base_stat_tbl->{"IC_Miss"} + $base_stat_tbl->{"IC_HitOnMiss"} ;
	return $numerator/$denominator ;
};

sub CalcPS2_Other_HS_SmallUnits{
	my $mt_residency = $base_stat_tbl->{"mt.active_not_stalled_cycles"}/($base_stat_tbl->{"mt.idle_cycles"}+$base_stat_tbl->{"mt.active_stalled_cycles"}+$base_stat_tbl->{"mt.active_not_stalled_cycles"}) ;
	
	my @arr = ( $formulas->{"PS2_PSD"}, 
				$formulas->{"PS2_HalfSlice2_Glue"}, 
				$formulas->{"PS2_HalfSlice3_Glue"},
				$mt_residency);
				
	@arr = sort @arr;
	@arr = reverse @arr;
	return $arr[0] ;
};

# sub CalcPS0_Other_HS_SmallUnits{
	# my @array1 = ($base_stat_tbl->{"PSD.active_not_stalled_cycles"}, $base_stat_tbl->{"si_active_not_stalled_cycles"}, $base_stat_tbl->{"so_active_not_stalled_cycles"},  $base_stat_tbl->{"mt_active_not_stalled_cycles"});
	# @array1 = sort @array1;
	# @array1 = reverse @array1;
	# my $num1 ;
	# if($vlv == 0)
	# {
		# $num1 = $array1[0] / $base_stat_tbl->{"GennysimStatClks"};
	# }
	# else
	# {
		# $num1 = $array1[0] / ($base_stat_tbl->{"GennysimStatClks"}/$factor);
	# }

	# my $ret = $num1 ;
	# return (1 - $ret)/2 ;
# };













