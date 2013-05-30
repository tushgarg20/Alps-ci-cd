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

# open (STATFILE, $statfilename) || die ("Couldn't open GennySim stat file $statfilename");
# my $config = "" ;
# my $line = "" ;
# for(my $count = 1 ; $count <= 5 ;$count++)
# {
	# $line = <STATFILE> ;
# }
# close (STATFILE) ;
# chomp($line) ;
# my @config = split(" ",$line) ;
# $config = $config[1] ;
# $base_stat_tbl->{"Gennysim Config"} = $config ;
# $base_stat_names[$i] = "Gennysim Config" ;
# $i++ ;

my @RATIO_TABLE = (
	["PS0_CS",                  	"uCS.idle_cycles"],
	["PS1_CS",                  	"uCS.active_stalled_cycles"],
	["PS2_CS",                  	"uCS.active_not_stalled_cycles"],
	["PS0_VF",                  	"uVF.idle_cycles"],
	["PS1_VF",                  	"uVF.active_stalled_cycles"],
	["PS2_VF",                  	"uVF.active_not_stalled_cycles"],
	["PS0_VF_DataRam_IDLE", 		"uVF.sram_data.idle"],
	["PS2_VF_DataRam_READ", 		"uVF.sram_data.read"],
	["PS2_VF_DataRam_WRITE", 		"uVF.sram_data.write"],
	["PS2_VF_DataRam_READ&WRITE", 	"uVF.sram_data.readwrite"],
	["PS0_VF_TagRam_IDLE", 			"uVF.sram_tag.idle"],
	["PS2_VF_TagRam _READ", 		"uVF.sram_tag.read"],
	["PS2_VF_TagRam_WRITE", 		"uVF.sram_tag.write"],
	["PS2_VF_TagRam_READ&WRITE", 	"uVF.sram_tag.readwrite"],
	["PS0_VS",                  	"uVS.idle_cycles"],
	["PS1_VS",                  	"uVS.active_stalled_cycles"],
	["PS2_VS",                  	"uVS.active_not_stalled_cycles"],
	["PS0_GS",                  	"uGS.idle_cycles"],
	["PS1_GS",                  	"uGS.active_stalled_cycles"],
	["PS2_GS_NullTopSC",           	"uGS.active_not_stalled_cycles_null_topology"],
	["PS2_GS_Thread",           	"uGS.active_not_stalled_cycles_thread"],
	["PS0_CL",                  	"uCL.idle_cycles"],
	["PS1_CL",                  	"uCL.active_stalled_cycles"],
	["PS2_CL",				       	0],
	["PS2_CL_MustClip",         	"uCL.active_not_stalled_cycles_MustClip"],
	["PS0_SF",                  	"uSF.idle_cycles"],
	["PS1_SF",                  	"uSF.active_stalled_cycles"],
	["PS2_SF_NullTopology",			"uSF.active_not_stalled_cycles_null_topology"],
	["PS2_SF_Culling",				"uSF.active_not_stalled_cycles_culing"],
	["PS2_SF_NoCulling_fastclipon", "uSF.active_not_stalled_cycles_noculling_fastclipon"],
	["PS2_SF_NoCulling FastClip Off","uSF.active_not_stalled_cycles_noculling_fastclipoff"],
	["PS0_HS",                  	"uHS.idle_cycles"],
	["PS1_HS",                  	"uHS.active_stalled_cycles"],
	["PS2_HS",			            0],
	["PS2_HS_Hollow",               "uHS.active_not_stalled_cycles_disabled"],
	["PS2_HS_Not_Hollow",           "uHS.active_not_stalled_cycles_enabled"],
	["PS0_DS",                  	"uDS.idle_cycles"],
	["PS1_DS",                  	"uDS.active_stalled_cycles"],
	["PS2_DS",			            0],
	["PS2_DS_Hollow",               "uDS.active_not_stalled_cycles_disabled"],
	["PS2_DS_Not_Hollow",           "uDS.active_not_stalled_cycles_enabled"],
	["PS0_TE",                  	"uTE.idle_cycles"],
	["PS1_TE",                  	"uTE.active_stalled_cycles"],
	["PS2_TE",			            0],
	["PS2_TE_Hollow",               "uTE.active_not_stalled_cycles_disabled"],
	["PS2_TE_Not_Hollow",           "uTE.active_not_stalled_cycles_enabled"],
	["PS0_TETG",                	"uTE.idle_cycles"],
	["PS1_TETG",                	"uTE.active_stalled_cycles"],
	["PS2_TETG",			        0],
	["PS2_TETG_Hollow",             "uTE.active_not_stalled_cycles_disabled"],
	["PS2_TETG_Not_Hollow",         "uTE.active_not_stalled_cycles_enabled"],
	["PS0_SOL",                 	"uSOL.idle_cycles"],
	["PS1_SOL",                 	"uSOL.active_stalled_cycles"],
	["PS2_SOL",			            0],
	["PS2_SOL_Hollow",              "uSOL.active_not_stalled_cycles_disabled"],
	["PS2_SOL_Not_Hollow",          "uSOL.active_not_stalled_cycles_enabled"],
	["PS0_TDG",                 	"uTDG.idle_cycles"],
	["PS1_TDG",                 	"uTDG.active_stalled_cycles"],
	["PS2_TDG",                 	"uTDG.active_not_stalled_cycles"],
	["PS0_URBM",                	"uURB.idle_cycles"],
	["PS1_URBM",                	"uURB.active_stalled_cycles"],
	["PS2_URBM",                	"uURB.active_not_stalled_cycles"],
	["PS0_SVG",                 	0],
	["PS1_SVG",                 	"GennysimStatClks"],
	["PS2_SVG",                 	0],
	["PS0_VFE",                 	"uVFE.idle_cycles"],
	["PS1_VFE",                 	"uVFE.active_stalled_cycles"],
	["PS2_VFE",                 	"uVFE.active_not_stalled_cycles"],
	["PS0_TSG",                 	"uTSG.idle_cycles"],
	["PS1_TSG",                 	"uTSG.active_stalled_cycles"],
	["PS2_TSG",                 	"uTSG.active_not_stalled_cycles"],
	["PS0_FIX1_Glue",           	"uSF.idle_cycles"],
	["PS1_FIX1_Glue",           	"uSF.active_stalled_cycles"],
	["PS2_FIX1_Glue",           	"uSF.active_not_stalled_cycles"],
	["PS0_FIX2_Glue",           	"uVS.idle_cycles"],
	["PS1_FIX2_Glue",           	"uVS.active_stalled_cycles"],
	["PS2_FIX2_Glue",           	"uVS.active_not_stalled_cycles"],
	["PS0_FIX3_Glue",           	"uVF.idle_cycles"],
	["PS1_FIX3_Glue",           	"uVF.active_stalled_cycles"],
	["PS2_FIX3_Glue",           	"uVF.active_not_stalled_cycles"],
	["PS0_FIX4_Glue",           	"uCL.idle_cycles"],
	["PS1_FIX4_Glue",           	"uCL.active_stalled_cycles"],
	["PS2_FIX4_Glue",           	"uCL.active_not_stalled_cycles"]
);
	 
foreach my $f (@RATIO_TABLE){
	$formulas->{$f->[0]} = &CalcRatio($f->[1]);
}

$formulas->{"Gennysim Stat Clocks"} = $base_stat_tbl->{"GennysimStatClks"} ;
# $formulas->{"Gennysim Config"} = $base_stat_tbl->{"Gennysim Config"} ;

$formulas->{"PS2_GS"} = &CalcPS2_GS() ;
$formulas->{"PS2_CL_NoMustClip"} = &CalcPS2_CL_NoMustClip() ;
$formulas->{"PS2_SF"} = &CalcPS2_SF() ;

$formulas->{"PS2_Other_FF_SmallUnits"} = &CalcPS2_Other_FF_SmallUnits() ;
$formulas->{"PS0_Other_FF_SmallUnits"} = (1 - $formulas->{"PS2_Other_FF_SmallUnits"})/2 ;
$formulas->{"PS1_Other_FF_SmallUnits"} = (1 - $formulas->{"PS2_Other_FF_SmallUnits"})/2 ;

$formulas->{"PS2_FIX5_Glue"} = &CalcPS2_FIX5_Glue() ;
$formulas->{"PS0_FIX5_Glue"} = (1 - $formulas->{"PS2_FIX5_Glue"})/2 ;
$formulas->{"PS1_FIX5_Glue"} = (1 - $formulas->{"PS2_FIX5_Glue"})/2 ;

my @derived_stat_names = sort keys %{$formulas};

foreach my $d (@derived_stat_names)
{
	$derived_stat_tbl->{$d} = $formulas->{$d} ;
}

#####################################################
# Printing out stats unit-wise
#####################################################
my $count = 0 ;

open(FP, '>' . $odir . 'fixfunction_alps1_1.csv');
print FP"Power Stat,Residency\n";

foreach  my $unit ("Gennysim Stat Clocks","Gennysim Config","CS","VF","VF_DataRam","VF_TagRam","VS","GS","CL","SF","HS","DS","TE","TETG","SOL","TDG","URBM","SVG","VFE","TSG","Other_FF_SmallUnits","FIX1_Glue","FIX2_Glue","FIX3_Glue","FIX4_Glue","FIX5_Glue")
{
	if($unit eq "SF" || $unit eq "CL" || $unit eq "HS" || $unit eq "DS" || $unit eq "TETG" || $unit eq "SOL" || $unit eq "GS" || $unit eq "CS" || $unit eq "VF_DataRam" || $unit eq "VF_TagRam")
	{
		for($count=0; $count <= $#derived_stat_names; $count++)
		{
			if($derived_stat_names[$count] =~ m/PS(.*?)\_$unit(.*)/i)
			{
				print FP"$derived_stat_names[$count],$derived_stat_tbl->{$derived_stat_names[$count]}\n";
			}
		}
	}
	elsif(($unit eq "Gennysim Stat Clocks")||($unit eq "Gennysim Config"))
	{
		for($count=0; $count <= $#derived_stat_names; $count++){
				 if($derived_stat_names[$count] =~ m/$unit/i){
					 print FP"$derived_stat_names[$count],$derived_stat_tbl->{$derived_stat_names[$count]}\n";
				 }
	   }
	}
	elsif($unit eq "TE")
	{
		for($count=0; $count <= $#derived_stat_names; $count++)
		{
			if(($derived_stat_names[$count] =~ m/PS(.*?)\_$unit$/i) || ($derived_stat_names[$count] =~ m/PS(.*?)\_$unit\_(.*)/i))
			{
				print FP"$derived_stat_names[$count],$derived_stat_tbl->{$derived_stat_names[$count]}\n";
			}
		}
	}
	else
	{
	   for($count=0; $count <= $#derived_stat_names; $count++){
				 if($derived_stat_names[$count] =~ m/PS(.*?)\_$unit$/i){
					 print FP"$derived_stat_names[$count],$derived_stat_tbl->{$derived_stat_names[$count]}\n";
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
   
	foreach  my $unit ("CS","VF","VS","GS","CL","SF","TDG","URB","HS","DS","TE","TETG","SOL","SVG","VFE","TSG")
	{
		if ( $unit eq "CS") 
		{
			push (@$lrSimData, {
			'Name' => 'u' . $unit . '.idle_cycles',
			'StatObj' => StatIStatObj->new({'m_StatName' => 'u' . $unit . '.power_fub.idle',
											'm_DoTestMaxVal' => 0})
			});
			
			push (@$lrSimData, {
			'Name' => 'u' . $unit . '.active_stalled_sync_wait_cycles',
			'StatObj' => StatIStatObj->new({'m_StatName' => 'u' . $unit . '.power_fub.stalled_sync_wait_cycles',
											'm_DoTestMaxVal' => 0})
			});
			
			push (@$lrSimData, {
			'Name' => 'u' . $unit . '.active_stalled_non_sync_wait_cycles',
			'StatObj' => StatIStatObj->new({'m_StatName' => 'u' . $unit . '.power_fub.stalled_non_sync_wait_cycles',
											'm_DoTestMaxVal' => 0})
			});
			
			push (@$lrSimData, {
			'Name' => 'u' . $unit . '.active_stalled_cycles',
			'StatObj' => StatIStatObj->new({'m_StatName' => 'u' . $unit . '.power_fub.stalled',
											'm_DoTestMaxVal' => 0})
			});
			
			push (@$lrSimData, {
			'Name' => 'u' . $unit . '.active_not_stalled_cycles',
			'StatObj' => StatIStatObj->new({'m_StatName' => 'u' . $unit . '.power_fub.active',
											'm_DoTestMaxVal' => 0})
			});            
        }
		elsif($unit eq "GS")
		{
			push (@$lrSimData, {
			 'Name' => 'u' . $unit . '.idle_cycles',
			 'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'u' . $unit . '\\.(enabled|disabled)_power_fub\\.idle',
												  'm_ReportDataAs' => 'SUM',
												  'm_DoTestMaxVal' => 0})
			});
			push (@$lrSimData, {
			 'Name' => 'u' . $unit . '.stalled_cycles',
			 'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'u' . $unit . '\\.(enabled|disabled)_power_fub\\.stalled',
												  'm_ReportDataAs' => 'SUM',
												  'm_DoTestMaxVal' => 0})
			});
			
			push (@$lrSimData, {
			'Name' => 'u' . $unit . '.active_not_stalled_cycles',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'u' . $unit . '\\.(enabled|disabled)_power_fub\\.active',
												  'm_ReportDataAs' => 'SUM',
												  'm_DoTestMaxVal' => 0})
			});
			
			push (@$lrSimData, {
			'Name' => 'u' . $unit . '.active_not_stalled_cycles_null_topology',
			'StatObj' => StatIStatObj->new({'m_StatName' => 'u' . $unit . '.power_fub.active_null_topology',
											'm_DoTestMaxVal' => 0})
			});
			
			push (@$lrSimData, {
			'Name' => 'u' . $unit . '.active_not_stalled_cycles_thread',
			'StatObj' => StatIStatObj->new({'m_StatName' => 'u' . $unit . '.stimulus.ActiveNotStalled_ThreadDispatch',
											'm_DoTestMaxVal' => 0})
			});
			
		}
        elsif($unit eq "CL")
		{
			push (@$lrSimData, {
			'Name' => 'u' . $unit . '.idle_cycles',
			'StatObj' => StatIStatObj->new({'m_StatName' => 'u' . $unit . '.power_fub.idle',
											'm_DoTestMaxVal' => 0})
			});
			
			push (@$lrSimData, {
			'Name' => 'u' . $unit . '.active_stalled_cycles',
			'StatObj' => StatIStatObj->new({'m_StatName' => 'u' . $unit . '.power_fub.stalled',
											'm_DoTestMaxVal' => 0})
			});
			
			push (@$lrSimData, {
			'Name' => 'u' . $unit . '.active_not_stalled_cycles',
			'StatObj' => StatIStatObj->new({'m_StatName' => 'u' . $unit . '.power_fub.active',
											'm_DoTestMaxVal' => 0})
			});
			
			push (@$lrSimData, {
			'Name' => 'u' . $unit . '.active_not_stalled_cycles_MustClip',
			'StatObj' => StatIStatObj->new({'m_StatName' => 'u' . $unit . '.power__mc_fub.active',
											'm_DoTestMaxVal' => 0})
			});
			
			# push (@$lrSimData, {
			# 'Name' => 'u' . $unit . '.active_not_stalled_cycles_NoMustClip',
			# 'StatObj' => StatIStatObj->new({'m_StatName' => 'u' . $unit . '.power_fub.active_NoMustClip',
											# 'm_DoTestMaxVal' => 0})
			# });
        }
		elsif($unit eq "SF")
		{
			push (@$lrSimData, {
			'Name' => 'u' . $unit . '.idle_cycles',
			'StatObj' => StatIStatObj->new({'m_StatName' => 'u' . $unit . '.power_fub.idle',
											'm_DoTestMaxVal' => 0})
			});
			
			push (@$lrSimData, {
			'Name' => 'u' . $unit . '.active_stalled_cycles',
			'StatObj' => StatIStatObj->new({'m_StatName' => 'u' . $unit . '.power_fub.stalled',
											'm_DoTestMaxVal' => 0})
			});
			
			push (@$lrSimData, {
			'Name' => 'u' . $unit . '.active_not_stalled_cycles',
			'StatObj' => StatIStatObj->new({'m_StatName' => 'u' . $unit . '.power_fub.active',
											'm_DoTestMaxVal' => 0})
			});
			
			push (@$lrSimData, {
			'Name' => 'u' . $unit . '.active_not_stalled_cycles_null_topology',
			'StatObj' => StatIStatObj->new({'m_StatName' => 'u' . $unit . '.power_fub.active_null_topology',
											'm_DoTestMaxVal' => 0})
			});
			
			push (@$lrSimData, {
			'Name' => 'u' . $unit . '.active_not_stalled_cycles_culling',
			'StatObj' => StatIStatObj->new({'m_StatName' => 'u' . $unit . '.power_fub.active_culling',
											'm_DoTestMaxVal' => 0})
			});
			push (@$lrSimData, {
			'Name' => 'u' . $unit . '.active_not_stalled_cycles_noculling_fastclipon',
			'StatObj' => StatIStatObj->new({'m_StatName' => 'u' . $unit . '.power_fub.active_noculling_fastclipon',
											'm_DoTestMaxVal' => 0})
			});
			push (@$lrSimData, {
			'Name' => 'u' . $unit . '.active_not_stalled_cycles_noculling_fastclipoff',
			'StatObj' => StatIStatObj->new({'m_StatName' => 'u' . $unit . '.power_fub.active_noculling_fastclipoff',
											'm_DoTestMaxVal' => 0})
			});
			
		}
		elsif($unit eq "HS" || $unit eq "DS" || $unit eq "TE" || $unit eq "TETG" || $unit eq "SOL")
		{
			push (@$lrSimData, {
			 'Name' => 'u' . $unit . '.idle_cycles',
			 'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'u' . $unit . '\\.(enabled|disabled)_power_fub\\.idle',
												  'm_ReportDataAs' => 'SUM',
												  'm_DoTestMaxVal' => 0})
			});
			push (@$lrSimData, {
			 'Name' => 'u' . $unit . '.stalled_cycles',
			 'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'u' . $unit . '\\.(enabled|disabled)_power_fub\\.stalled',
												  'm_ReportDataAs' => 'SUM',
												  'm_DoTestMaxVal' => 0})
			});
			
			push (@$lrSimData, {
			'Name' => 'u' . $unit . '.active_not_stalled_cycles',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'u' . $unit . '\\.(enabled|disabled)_power_fub\\.active',
												  'm_ReportDataAs' => 'SUM',
												  'm_DoTestMaxVal' => 0})
			});
			
			push (@$lrSimData, {
			'Name' => 'u' . $unit . '.active_not_stalled_cycles_enabled',
			'StatObj' => StatIStatObj->new({'m_StatName' => 'u' . $unit . '.enabled_power_fub.active',
											'm_DoTestMaxVal' => 0})
			});
			push (@$lrSimData, {
			'Name' => 'u' . $unit . '.active_not_stalled_cycles_disabled',
			'StatObj' => StatIStatObj->new({'m_StatName' => 'u' . $unit . '.disabled_power_fub.active',
											'm_DoTestMaxVal' => 0})
			});
		}
        else 
		{
			push (@$lrSimData, {
			'Name' => 'u' . $unit . '.idle_cycles',
			'StatObj' => StatIStatObj->new({'m_StatName' => 'u' . $unit . '.power_fub.idle',
											'm_DoTestMaxVal' => 0})
			});
			
			push (@$lrSimData, {
			'Name' => 'u' . $unit . '.active_stalled_cycles',
			'StatObj' => StatIStatObj->new({'m_StatName' => 'u' . $unit . '.power_fub.stalled',
											'm_DoTestMaxVal' => 0})
			});
			
			push (@$lrSimData, {
			'Name' => 'u' . $unit . '.active_not_stalled_cycles',
			'StatObj' => StatIStatObj->new({'m_StatName' => 'u' . $unit . '.power_fub.active',
											'm_DoTestMaxVal' => 0})
			});
        }
    }
	
	push (@$lrSimData, {
		'Name' => 'uVF.sram_tag.idle',
		'StatObj' => StatIStatObj->new({'m_StatName' => 'uVF.PerfStats.vf_tagfifo_idle',
										'm_DoTestMaxVal' => 0})
	});
	push (@$lrSimData, {
		'Name' => 'uVF.sram_tag.read',
		'StatObj' => StatIStatObj->new({'m_StatName' => 'uVF.PerfStats.vf_tagfifo_read',
										'm_DoTestMaxVal' => 0})
	});
	push (@$lrSimData, {
		'Name' => 'uVF.sram_tag.write',
		'StatObj' => StatIStatObj->new({'m_StatName' => 'uVF.PerfStats.vf_tagfifo_write',
										'm_DoTestMaxVal' => 0})
	});
	push (@$lrSimData, {
		'Name' => 'uVF.sram_tag.readwrite',
		'StatObj' => StatIStatObj->new({'m_StatName' => 'uVF.PerfStats.vf_tagfifo_readwrite',
										'm_DoTestMaxVal' => 0})
	});
	
	push (@$lrSimData, {
		'Name' => 'uVF.sram_data.idle',
		'StatObj' => StatIStatObj->new({'m_StatName' => 'uVF.PerfStats.vf_cache_idle',
										'm_DoTestMaxVal' => 0})
	});
	push (@$lrSimData, {
		'Name' => 'uVF.sram_data.read',
		'StatObj' => StatIStatObj->new({'m_StatName' => 'uVF.PerfStats.vf_cache_read',
										'm_DoTestMaxVal' => 0})
	});
	push (@$lrSimData, {
		'Name' => 'uVF.sram_data.write',
		'StatObj' => StatIStatObj->new({'m_StatName' => 'uVF.PerfStats.vf_cache_write',
										'm_DoTestMaxVal' => 0})
	});
	push (@$lrSimData, {
		'Name' => 'uVF.sram_data.readwrite',
		'StatObj' => StatIStatObj->new({'m_StatName' => 'uVF.PerfStats.vf_cache_readwrite',
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
		my @data = split/\./, $N ;
		my $unit = $data[0] . "." . $data[1] ;
		# my $denominator = $base_stat_tbl->{"GennysimStatClks"} ;
		my $denominator = $base_stat_tbl->{$unit . ".idle"} + $base_stat_tbl->{$unit . ".read"} + $base_stat_tbl->{$unit . ".write"} + $base_stat_tbl->{$unit . ".readwrite"} ;
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

sub CalcPS2_GS{
	my $denominator = ($base_stat_tbl->{"uGS.idle_cycles"} + $base_stat_tbl->{"uGS.active_stalled_cycles"} + $base_stat_tbl->{"uGS.active_not_stalled_cycles"}) ;
	if($denominator == 0)
	{
		return 0 ;
	}
	return ($base_stat_tbl->{"uGS.active_not_stalled_cycles"} - 
			$base_stat_tbl->{"uGS.active_not_stalled_cycles_null_topology"} -
			$base_stat_tbl->{"uGS.active_not_stalled_cycles_thread"})/
			$denominator;
};

sub CalcPS2_CL_NoMustClip{
	my $numerator = $base_stat_tbl->{"uCL.active_not_stalled_cycles"} -
					# $base_stat_tbl->{"uCL.active_not_stalled_cycles_NoMustClip"} -
					$base_stat_tbl->{"uCL.active_not_stalled_cycles_MustClip"} ;
					
	my $denominator = $base_stat_tbl->{"uCL.idle_cycles"} + $base_stat_tbl->{"uCL.active_stalled_cycles"} + $base_stat_tbl->{"uCL.active_not_stalled_cycles"} ;
	if($denominator == 0)
	{
		return 0 ;
	}
	return $numerator/$denominator ;
};

sub CalcPS2_SF{
	my $denominator = ($base_stat_tbl->{"uSF.idle_cycles"} + $base_stat_tbl->{"uSF.active_stalled_cycles"} + $base_stat_tbl->{"uSF.active_not_stalled_cycles"}) ;
	if($denominator == 0)
	{
		return 0 ;
	}
	return ($base_stat_tbl->{"uSF.active_not_stalled_cycles"} -
		$base_stat_tbl->{"uSF.active_not_stalled_cycles_null_topology"} -
		$base_stat_tbl->{"uSF.active_not_stalled_cycles_culling"} -
		$base_stat_tbl->{"uSF.active_not_stalled_cycles_noculling_fastclipon"} -
		$base_stat_tbl->{"uSF.active_not_stalled_cycles_noculling_fastclipoff"}) /
		$denominator;
};

sub CalcPS2_Other_FF_SmallUnits{
	my @arr = ( $formulas->{"PS2_TDG"},
				$formulas->{"PS2_VF"},
				$formulas->{"PS2_VS"},
				$formulas->{"PS2_SF"}+$formulas->{"PS2_SF_NullTopology"}+$formulas->{"PS2_SF_Culling"}+$formulas->{"PS2_SF_NoCulling_fastclipon"}+$formulas->{"PS2_SF_NoCulling FastClip Off"},
				$formulas->{"PS2_CL_NoMustClip"}+$formulas->{"PS2_CL_MustClip"}) ;
	@arr = sort @arr ;
	@arr = reverse @arr ;
	return $arr[0] ;
};

sub CalcPS2_FIX5_Glue{
	my $key1 = $formulas->{"PS2_SOL_Hollow"} + $formulas->{"PS2_SOL_Not_Hollow"} ;
	my $key2 = $formulas->{"PS2_TETG_Hollow"} + $formulas->{"PS2_TETG_Not_Hollow"} ; 
	
	if($key1 > $key2)
	{
		return $key1 ;
	}
	else
	{
		return $key2 ;
	}
};
