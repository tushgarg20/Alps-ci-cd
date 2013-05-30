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
		["PS0_WMFE",											"WMFE.idle_cycles"],
		["PS1_WMFE",											"WMFE.active_stalled_cycles"],
		["PS2_WMFE_NullTopSC",									"WMFE.active_not_stalled_cycles_null_topology"],
		["PS0_WMBE",											"WMBE.idle_cycles"],
		["PS1_WMBE",											"WMBE.active_stalled_cycles"],
		["PS2_WMBE_NullTopSC",									"WMBE.active_not_stalled_cycles_null_topology"],
		["PS2_WMBE_PixelPipe_Active",							"WMBE.active_not_stalled_cycles_urbportnotactive"],
		["PS2_WMBE_PixelPipe_Active_andURBport_is_active",		0],
		["PS0_HIZ",												"HZ.idle_cycles"],
		["PS1_HIZ",												"HZ.active_stalled_cycles"],
		["PS2_HIZ_NullTop_NoZ",									"HZ.active_not_stalled_cycles_null_topology"],
		["PS2_HIZ_AllDropped_atFastInterp_Check",				"HZ.active_not_stalled_cycles_AllDropped_atFastInterp_Check"],
		["PS2_HIZ_FastInterpCheck__DroppedbyZStencilTest",		"HZ.active_not_stalled_cycles_FastInterpCheck__DroppedbyZStencilTest"],
		["PS2_HIZ_FastInterpCheck__ZStencilTest",				"HZ.active_not_stalled_cycles_FastInterpCheck__ZStencilTest"],
		["PS0_HIZ_DataRam_IDLE",								"uHZC.dataram.idle"],
		["PS2_HIZ_DataRam_READ",								"uHZC.dataram.read"],
		["PS2_HIZ_DataRam_WRITE",								"uHZC.dataram.write"],
		["PS2_HIZ_DataRam_READ&WRITE",							"uHZC.dataram.readwrite"],
		["PS0_HIZ_TagRam_IDLE",									"uHZC.tagram.idle"],
		["PS2_HIZ_TagRam _READ",								"uHZC.tagram.read"],
		["PS2_HIZ_TagRam_WRITE",								"uHZC.tagram.write"],
		["PS2_HIZ_TagRam_READ&WRITE",							"uHZC.tagram.readwrite"],
		["PS0_IZ",												"IZ.idle_cycles"],
		["PS1_IZ",												"IZ.active_stalled_cycles"],
		["PS2_IZ_NullTop_NoZ",									"IZ.active_not_stalled_cycles_null_topology"],
		["PS2_IZ_Barypassthrough",								"IZ.active_not_stalled_cycles_Barypassthrough"],
		["PS2_IZ_BaryInterp",									"IZ.active_not_stalled_cycles_BaryInterp"],
		["PS0_IZ_DataRam_IDLE",									0],
		["PS2_IZ_DataRam_READ",									0],
		["PS2_IZ_DataRam_WRITE",								0],
		["PS2_IZ_DataRam_READ&WRITE",							0],
		["PS0_STC",												"STC.idle_cycles"],
		["PS1_STC",												"STC.active_stalled_cycles"],
		["PS2_STC",												"STC.active_not_stalled_cycles"],
		["PS0_STC_DataRam_IDLE",								"uSTC.dataram.idle"],
		["PS2_STC_DataRam _READ",								"uSTC.dataram.read"],
		["PS2_STC_DataRam_WRITE",								"uSTC.dataram.write"],
		["PS2_STC_DataRam_READ&WRITE",							"uSTC.dataram.readwrite"],
		["PS0_SBE",												"SBE.idle_cycles"],
		["PS1_SBE",        										"SBE.active_stalled_cycles"],
		["PS2_SBE",        										"SBE.active_not_stalled_cycles"],
		["PS0_SVGL",       										0],
		["PS1_SVGL",       										"GennysimStatClks"],
		["PS2_SVGL",       										0],
		["PS0_VSC",												"GennysimStatClks"],
		["PS1_VSC",												0],
		["PS2_VSC",												0],
		["PS0_IECP",											"GennysimStatClks"],
		["PS1_IECP",										   	0],
		["PS2_IECP",											0],
		["PS0_MSC",        										"RCC.idle_cycles"],
		["PS1_MSC",        										"RCC.active_stalled_cycles"], # MSC stats are not yet enabled in Gennysim
		["PS2_MSC",        										"RCC.active_not_stalled_cycles"], #Using RCC stats as proxy
		["PS2_MSC_MCSenabled",									0],
		["PS0_MSC_DataRam_IDLE",								"uMSC.dataram.idle"],
		["PS2_MSC_DataRam _READ",								"uMSC.dataram.read"],
		["PS2_MSC_DataRam_WRITE",								"uMSC.dataram.write"],
		["PS2_MSC_DataRam_READ&WRITE",							"uMSC.dataram.readwrite"],
		["PS0_DAPR_BE",											"DAPSC.idle_cycles"],
		["PS1_DAPR_BE",											"DAPSC.active_stalled_cycles"],
		["PS2_DAPR_BE",											"DAPSC.active_not_stalled_cycles"],
		["PS0_RCC",												"RCC.idle_cycles"],
		["PS1_RCC",												"RCC.active_stalled_cycles"],
		["PS2_RCC",												"RCC.active_not_stalled_cycles"],
		["PS2_RCC_Cache_misses",								"uRCC.cache.misses"],
		["PS2_RCC_Cache_hits",									"uRCC.cache.hits"],
		["PS2_RCC_Cache_Hits_clear",							"uRCC.cache.hitclear"],
		["PS0_RCC_DataRam_IDLE",								"uRCC.dataram.idle"],
		["PS2_RCC_DataRam_READ",								"uRCC.dataram.read"],
		["PS2_RCC_DataRam_WRITE",								"uRCC.dataram.write"],
		["PS2_RCC_DataRam_READ&WRITE",							"uRCC.dataram.readwrite"],
		["PS0_RCZ",												"RCZ.idle_cycles"],
		["PS1_RCZ",												"RCZ.active_stalled_cycles"],
		["PS2_RCZ",												"RCZ.active_not_stalled_cycles"],
		["PS0_RCZ_DataRam_IDLE",								"uRCZ.dataram.idle"],
		["PS2_RCZ_DataRam _READ",								"uRCZ.dataram.read"],
		["PS2_RCZ_DataRam_WRITE",								"uRCZ.dataram.write"],
		["PS2_RCZ_DataRam_READ&WRITE",							"uRCZ.dataram.readwrite"],
		["PS0_RCPB_FE",											"RCPBFE1.idle_cycles"],
		["PS1_RCPB_FE",											"RCPBFE1.active_stalled_cycles"],
		["PS2_RCPB_FE_nonpromotedz",							"RCPBFE1.active_not_stalled_cycles_nonpromotedz"],
		["PS0_RCPB_FE_DataRam_IDLE",							0],
		["PS2_RCPB_FE_DataRam _READ",							0],
		["PS2_RCPB_FE_DataRam_WRITE",							0],
		["PS2_RCPB_FE_DataRam_READ&WRITE",						0],
		["PS0_RCPB_BE",											"RCPBBE.idle_cycles"],
		["PS1_RCPB_BE",											"RCPBBE.active_stalled_cycles"],
		["PS2_RCPB_BE-BLEND",									"RCPBBE.active_not_stalled_cycles_blend"],
		["PS0_DAPB",											"DAPSC.idle_cycles"],
		["PS1_DAPB",											"DAPSC.active_stalled_cycles"],
		["PS2_DAPB",											"DAPSC.active_not_stalled_cycles"],
		["PS0_SC1_Glue",										"HZ.idle_cycles"],
		["PS1_SC1_Glue",										"HZ.active_stalled_cycles"],
		["PS2_SC1_Glue",										"HZ.active_not_stalled_cycles"],
		["PS0_SC2_Glue",										"IZ.idle_cycles"],
		["PS1_SC2_Glue",										"IZ.active_stalled_cycles"],
		["PS2_SC2_Glue",										"IZ.active_not_stalled_cycles"],
		["PS0_SC3_Glue",										"SBE.idle_cycles"],
		["PS1_SC3_Glue",										"SBE.active_stalled_cycles"],
		["PS2_SC3_Glue",										"SBE.active_not_stalled_cycles"],
		["PS0_SC5_Glue",										"RCC.idle_cycles"],
		["PS1_SC5_Glue", 										"RCC.active_stalled_cycles"],
		["PS2_SC5_Glue",										"RCC.active_not_stalled_cycles"],
		["PS0_SC6_Glue",										"RCC.idle_cycles"],
		["PS1_SC6_Glue",										"RCC.active_stalled_cycles"],
		["PS2_SC6_Glue",										"RCC.active_not_stalled_cycles"],
);
	 
foreach my $f (@RATIO_TABLE){
	$formulas->{$f->[0]} = &CalcRatio($f->[1]);
}

$formulas-> {"PS2_WMFE"} = &PS2_WMFE() ;
$formulas->{"PS2_WMBE"} = &PS2_WMBE() ;
$formulas->{"PS2_HIZ"} = &CalcPS2_HIZ() ;
$formulas->{"PS2_IZ"} = &PS2_IZ() ;

$formulas->{"PS2_ARB"} = &CalcPS2_ARB() ;
$formulas->{"PS1_ARB"} = &CalcPS1_ARB() ;
$formulas->{"PS0_ARB"} = 1 - $formulas->{"PS2_ARB"} - $formulas->{"PS1_ARB"}  ;

$formulas->{"PS2_RCPB_FE"} = &PS2_RCPB_FE() ;
$formulas->{"PS2_RCPB_BE"} = &PS2_RCPB_BE() ;

$formulas->{"PS2_Other_SC_SmallUnits"} = &CalcPS2_Other_SC_SmallUnits() ;
$formulas->{"PS1_Other_SC_SmallUnits"} = (1 - $formulas->{"PS2_Other_SC_SmallUnits"})/2 ;
$formulas->{"PS0_Other_SC_SmallUnits"} = (1 - $formulas->{"PS2_Other_SC_SmallUnits"})/2 ;

$formulas->{"PS0_SC4_Glue"} = $formulas->{"PS0_ARB"} ;
$formulas->{"PS1_SC4_Glue"} = $formulas->{"PS1_ARB"} ;
$formulas->{"PS2_SC4_Glue"} = $formulas->{"PS2_ARB"} ;
  
my @derived_stat_names = sort keys %{$formulas};

foreach my $d (@derived_stat_names)
{
	$derived_stat_tbl->{$d} = $formulas->{$d} ;
}

#####################################################
# Printing out stats unit-wise
#####################################################
my $count = 0 ;
open(FP, '>' . $odir . 'slice_alps1_1.csv');
print FP"Power Stat,Residency\n";

foreach  my $unit ("WMFE","WMBE","HIZ","HIZ_DataRam","HIZ_TagRam","IZ","IZ_DataRam","STC","STC_DataRam","SBE","ARB","SVGL","VSC","IECP","MSC","MSC_DataRam","DAPR_BE","RCC","RCC_Cache","RCC_DataRam","RCZ","RCZ_DataRam","RCPB_FE","RCPB_FE_DataRam","RCPB_BE","DAPB","Other_SC_SmallUnits","SC1_Glue","SC2_Glue","SC3_Glue","SC4_Glue","SC5_Glue","SC6_Glue")
{
	if($unit eq "HIZ_DataRam" || $unit eq "HIZ_TagRam" || $unit eq "IZ_DataRam" || $unit eq "STC_DataRam" || $unit eq "MSC_DataRam" || $unit eq "RCC_Cache" || $unit eq "RCC_DataRam" || $unit eq "RCZ_DataRam" || $unit eq "RCPB_FE_DataRam")
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
			if($derived_stat_names[$count] =~ m/PS(.*?)\_$unit(.*)/i)
			{
				print FP"$derived_stat_names[$count],$derived_stat_tbl->{$derived_stat_names[$count]}\n" unless(($derived_stat_names[$count] =~ m/Ram/i) || ($derived_stat_names[$count] =~ m/Cache/i));
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
   
	foreach my $unit ("HZ","IZ","STC","SBE","MSC","RCC","RCZ","DAPSC")
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
		if($unit eq "HZ")
		{
			push (@$lrSimData, {
			'Name' => $unit . '.active_not_stalled_cycles_null_topology',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'u' .$unit . '_\\d+\\.power_fub\\.active_null_topology',
											  'm_ReportDataAs' => 'AVERAGEDIV1',
											  'm_DoTestMaxVal' => 0})
			});
			push (@$lrSimData, {
			'Name' => $unit . '.active_not_stalled_cycles_AllDropped_atFastInterp_Check',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'u' .$unit . '_\\d+\\.power_fub\\.active_AllDropped_atFastInterp_Check',
											  'm_ReportDataAs' => 'AVERAGEDIV1',
											  'm_DoTestMaxVal' => 0})
			});
			push (@$lrSimData, {
			'Name' => $unit . '.active_not_stalled_cycles_FastInterpCheck__DroppedbyZStencilTest',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'u' .$unit . '_\\d+\\.power_fub\\.active_FastInterpCheck__DroppedbyZStencilTest',
											  'm_ReportDataAs' => 'AVERAGEDIV1',
											  'm_DoTestMaxVal' => 0})
			});
			push (@$lrSimData, {
			'Name' => $unit . '.active_not_stalled_cycles_FastInterpCheck__ZStencilTest',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'u' .$unit . '_\\d+\\.power_fub\\.active_FastInterpCheck__ZStencilTest',
											  'm_ReportDataAs' => 'AVERAGEDIV1',
											  'm_DoTestMaxVal' => 0})
			});
		}
		if($unit eq "IZ")
		{
			push (@$lrSimData, {
			'Name' => $unit . '.active_not_stalled_cycles_null_topology',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'u' .$unit . '_\\d+\\.power_fub\\.active_null_topology',
											  'm_ReportDataAs' => 'AVERAGEDIV1',
											  'm_DoTestMaxVal' => 0})
			});
			push (@$lrSimData, {
			'Name' => $unit . '.active_not_stalled_cycles_AllDropped_Barypassthrough',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'u' .$unit . '_\\d+\\.power_fub\\.active_Barypassthrough',
											  'm_ReportDataAs' => 'AVERAGEDIV1',
											  'm_DoTestMaxVal' => 0})
			});
			push (@$lrSimData, {
			'Name' => $unit . '.active_not_stalled_cycles_BaryInterp',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'u' .$unit . '_\\d+\\.power_fub\\.active_BaryInterp',
											  'm_ReportDataAs' => 'AVERAGEDIV1',
											  'm_DoTestMaxVal' => 0})
			});
		}
		if($unit eq "MCS")
		{
			push (@$lrSimData, {
			'Name' => $unit . '.active_not_stalled_cycles_mcs_enabled',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'u' .$unit . '_\\d+\\.power_fub\\.active_mcsenabled',
											  'm_ReportDataAs' => 'AVERAGEDIV1',
											  'm_DoTestMaxVal' => 0})
			});
		}
	}
	
	foreach my $unit ("WMFE","WMBE")
	{
		push (@$lrSimData, {
			'Name' => $unit . '.idle_cycles',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uWM_\\d+\\.WIZ_WM\\.' . $unit . '_Idle',
                                              'm_ReportDataAs' => 'AVERAGEDIV1',
                                              'm_DoTestMaxVal' => 0})
			});
			
		push (@$lrSimData, {
		'Name' => $unit . '.active_stalled_cycles',
		'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uWM_\\d+\\.WIZ_WM\\.' . $unit . '_Stalled',
										  'm_ReportDataAs' => 'AVERAGEDIV1',
										  'm_DoTestMaxVal' => 0})
		});
		
		push (@$lrSimData, {
		'Name' => $unit . '.active_not_stalled_cycles',
		'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uWM_\\d+\\.WIZ_WM\\.' . $unit . '_Active',
										  'm_ReportDataAs' => 'AVERAGEDIV1',
										  'm_DoTestMaxVal' => 0})
		});
		
		push (@$lrSimData, {
		'Name' => $unit . '.active_not_stalled_cycles_null_topology',
		'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uWM_\\d+\\.WIZ_WM\\.' . $unit . '_Active_null_topology',
										  'm_ReportDataAs' => 'AVERAGEDIV1',
										  'm_DoTestMaxVal' => 0})
		});
		if($unit eq "WMBE")
		{
			push (@$lrSimData, {
			'Name' => $unit . '.active_not_stalled_cycles_urbportnotactive',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uWM_\\d+\\.WIZ_WM\\.' . $unit . '_Active_urbportnotactive',
											  'm_ReportDataAs' => 'AVERAGEDIV1',
											  'm_DoTestMaxVal' => 0})
			});
			
			push (@$lrSimData, {
			'Name' => $unit . '.active_not_stalled_cycles_urbportactive',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uWM_\\d+\\.WIZ_WM\\.' . $unit . '_Active_urbportactive',
											  'm_ReportDataAs' => 'AVERAGEDIV1',
											  'm_DoTestMaxVal' => 0})
			});
		}
	}
	
	foreach my $unit ("RCPBFE1","RCPBBE")
	{
		push (@$lrSimData, {
			'Name' => $unit . '.idle_cycles',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uPB_\\d+\\.' . $unit . '\\.power_fub\\.idle',
                                              'm_ReportDataAs' => 'AVERAGEDIV1',
                                              'm_DoTestMaxVal' => 0})
			});
			
		push (@$lrSimData, {
		'Name' => $unit . '.active_stalled_cycles',
		'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uPB_\\d+\\.' . $unit . '\\.power_fub\\.stalled',
										  'm_ReportDataAs' => 'AVERAGEDIV1',
										  'm_DoTestMaxVal' => 0})
		});
		
		push (@$lrSimData, {
		'Name' => $unit . '.active_not_stalled_cycles',
		'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uPB_\\d+\\.' . $unit . '\\.power_fub\\.active',
										  'm_ReportDataAs' => 'AVERAGEDIV1',
										  'm_DoTestMaxVal' => 0})
		});
		if($unit eq "RCPBBE")
		{
			push (@$lrSimData, {
			'Name' => $unit . '.active_not_stalled_cycles_blend',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uPB_\\d+\\.' . $unit . '\\.power_fub\\.PbActiveBlend',
											  'm_ReportDataAs' => 'AVERAGEDIV1',
											  'm_DoTestMaxVal' => 0})
			});
		}
		if($unit eq "RCPBFE1")
		{
			push (@$lrSimData, {
			'Name' => $unit . '.active_not_stalled_cycles_nonpromotedz',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uPB_\\d+\\.' . $unit . '\\.power_fub\\.active_nonpromotedz',
											  'm_ReportDataAs' => 'AVERAGEDIV1',
											  'm_DoTestMaxVal' => 0})
			});
			push (@$lrSimData, {
				'Name' => 'u' . $unit . '.dataram.idle',
				'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uPB_\\d+\\.' . $unit . '_\\d+\\.sram_data_power_fub\\.idle$',
												'm_ReportDataAs' => 'AVERAGEDIV1',
												'm_DoTestMaxVal' => 0})
			});
			push (@$lrSimData, {
				'Name' => 'u' . $unit . '.dataram.read',
				'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uPB_\\d+\\.' . $unit . '_\\d+\\.sram_data_power_fub\\.read$',
												'm_ReportDataAs' => 'AVERAGEDIV1',
												'm_DoTestMaxVal' => 0})
			});
			push (@$lrSimData, {
				'Name' => 'u' . $unit . '.dataram.write',
				'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uPB_\\d+\\.' . $unit . '_\\d+\\.sram_data_power_fub\\.write$',
												'm_ReportDataAs' => 'AVERAGEDIV1',
												'm_DoTestMaxVal' => 0})
			});
			push (@$lrSimData, {
				'Name' => 'u' . $unit . '.dataram.readwrite',
				'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uPB_\\d+\\.' . $unit . '_\\d+\\.sram_data_power_fub\\.readwrite$',
												'm_ReportDataAs' => 'AVERAGEDIV1',
												'm_DoTestMaxVal' => 0})
			});
		}
	}
	foreach my $unit("HZC","STC","MSC","RCC","RCZ")
	{
		push (@$lrSimData, {
			'Name' => 'u' . $unit . '.dataram.idle',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'u' .$unit . '_\\d+\\.sram_data_power_fub\\.idle$',
											'm_ReportDataAs' => 'AVERAGEDIV1',
											'm_DoTestMaxVal' => 0})
		});
		push (@$lrSimData, {
			'Name' => 'u' . $unit . '.dataram.read',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'u' .$unit . '_\\d+\\.sram_data_power_fub\\.read$',
											'm_ReportDataAs' => 'AVERAGEDIV1',
											'm_DoTestMaxVal' => 0})
		});
		push (@$lrSimData, {
			'Name' => 'u' . $unit . '.dataram.write',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'u' .$unit . '_\\d+\\.sram_data_power_fub\\.write$',
											'm_ReportDataAs' => 'AVERAGEDIV1',
											'm_DoTestMaxVal' => 0})
		});
		push (@$lrSimData, {
			'Name' => 'u' . $unit . '.dataram.readwrite',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'u' .$unit . '_\\d+\\.sram_data_power_fub\\.readwrite$',
											'm_ReportDataAs' => 'AVERAGEDIV1',
											'm_DoTestMaxVal' => 0})
		});
	}
	foreach my $unit("HZC")
	{
		push (@$lrSimData, {
			'Name' => 'u' . $unit . '.tagram.idle',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'u' .$unit . '_\\d+\\.sram_tag_power_fub\\.idle$',
											'm_ReportDataAs' => 'AVERAGEDIV1',
											'm_DoTestMaxVal' => 0})
		});
		push (@$lrSimData, {
			'Name' => 'u' . $unit . '.tagram.read',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'u' .$unit . '_\\d+\\.sram_tag_power_fub\\.read$',
											'm_ReportDataAs' => 'AVERAGEDIV1',
											'm_DoTestMaxVal' => 0})
		});
		push (@$lrSimData, {
			'Name' => 'u' . $unit . '.tagram.write',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'u' .$unit . '_\\d+\\.sram_tag_power_fub\\.write$',
											'm_ReportDataAs' => 'AVERAGEDIV1',
											'm_DoTestMaxVal' => 0})
		});
		push (@$lrSimData, {
			'Name' => 'u' . $unit . '.tagram.readwrite',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'u' .$unit . '_\\d+\\.sram_tag_power_fub\\.readwrite$',
											'm_ReportDataAs' => 'AVERAGEDIV1',
											'm_DoTestMaxVal' => 0})
		});
	}
	push (@$lrSimData, {
		'Name' => 'uRCC.cache.hits',
		'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uRCC_\\d+\\.AllocHits$',
										'm_ReportDataAs' => 'AVERAGEDIV1',
										'm_DoTestMaxVal' => 0})
	});
	push (@$lrSimData, {
		'Name' => 'uRCC.cache.misses',
		'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uRCC_\\d+\\.AllocMiss$',
										'm_ReportDataAs' => 'AVERAGEDIV1',
										'm_DoTestMaxVal' => 0})
	});
	push (@$lrSimData, {
		'Name' => 'uRCC.cache.hitsclear',
		'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uRCC_\\d+\\.AllocHitsClassicClear$',
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
	if($N =~ m/ram/)
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
	if($N =~ m/cache/)
	{
		my @data = split/\./, $N ;
		my $unit = $data[0] . "." . $data[1] ;
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

sub PS2_WMFE{
	my $numerator = $base_stat_tbl->{"WMFE.active_not_stalled_cycles"} - $base_stat_tbl->{"WMFE.active_not_stalled_cycles_null_topology"} ;
	my $denominator= $base_stat_tbl->{"WMFE.idle_cycles"} + $base_stat_tbl->{"WMFE.active_stalled_cycles"} + $base_stat_tbl->{"WMFE.active_not_stalled_cycles"};
	if($denominator == 0)
	{
		return 0 ;
	}
	return ($numerator)/($denominator);
};

sub PS2_WMBE{
	my $numerator = $base_stat_tbl->{"WMBE.active_not_stalled_cycles"} -
					$base_stat_tbl->{"WMBE.active_not_stalled_cycles_null_topology"} -
					$base_stat_tbl->{"WMBE.active_not_stalled_cycles_urbportnotactive"} -
					$base_stat_tbl->{"WMBE.active_not_stalled_cycles_urbportactive"} ;
	my $denominator= $base_stat_tbl->{"WMBE.idle_cycles"} + $base_stat_tbl->{"WMBE.active_stalled_cycles"} + $base_stat_tbl->{"WMBE.active_not_stalled_cycles"};
	if($denominator == 0)
	{
		return 0 ;
	}
	return ($numerator)/($denominator) ;
};

sub CalcPS2_HIZ{
	my $denominator = $base_stat_tbl->{"HZ.idle_cycles"} + $base_stat_tbl->{"HZ.active_stalled_cycles"} + $base_stat_tbl->{"HZ.active_not_stalled_cycles"} ;
	my $numerator = $base_stat_tbl->{"HZ.active_not_stalled_cycles"} - 
					$base_stat_tbl->{"HZ.active_not_stalled_cycles_NullTop_NoZ"} -
					$base_stat_tbl->{"HZ.active_not_stalled_cycles_AllDropped_atFastInterp_Check"} -
					$base_stat_tbl->{"HZ.active_not_stalled_cycles_FastInterpCheck__DroppedbyZStencilTest"} -
					$base_stat_tbl->{"HZ.active_not_stalled_cycles_FastInterpCheck__DroppedbyZStencilTest"} ;
	
	if($denominator == 0)
	{
		return 0 ;
	}
	return $numerator/$denominator ;
};

sub PS2_IZ{
	my $numerator = $base_stat_tbl->{"IZ.active_not_stalled_cycles"} ;
	my $denominator= $base_stat_tbl->{"IZ.idle_cycles"} + $base_stat_tbl->{"IZ.active_stalled_cycles"} + $base_stat_tbl->{"IZ.active_not_stalled_cycles"};
	if($denominator == 0)
	{
		return 0 ;
	}
	return ($numerator)/($denominator);
};

sub CalcPS2_ARB{
	my $numerator;
	my $denominator ;
	$denominator =  $base_stat_tbl->{"RCZ.idle_cycles"} + $base_stat_tbl->{"RCZ.active_stalled_cycles"} + $base_stat_tbl->{"RCZ.active_not_stalled_cycles"} +
					$base_stat_tbl->{"RCC.idle_cycles"} + $base_stat_tbl->{"RCC.active_stalled_cycles"} + $base_stat_tbl->{"RCC.active_not_stalled_cycles"} +
					$base_stat_tbl->{"STC.idle_cycles"} + $base_stat_tbl->{"STC.active_stalled_cycles"} + $base_stat_tbl->{"STC.active_not_stalled_cycles"} +
					$base_stat_tbl->{"HZ.idle_cycles"} + $base_stat_tbl->{"HZ.active_stalled_cycles"} + $base_stat_tbl->{"HZ.active_not_stalled_cycles"} ;
					
	$numerator=$base_stat_tbl->{"HZ.active_not_stalled_cycles"} + $base_stat_tbl->{"STC.active_not_stalled_cycles"} + $base_stat_tbl->{"RCC.active_not_stalled_cycles"} +  $base_stat_tbl->{"RCZ.active_not_stalled_cycles"};
	if($denominator == 0)
	{
		return 0 ;
	}
	return ($numerator)/($denominator);
};

sub CalcPS1_ARB{
	my $numerator ;
	my $denominator ;
	$denominator =  $base_stat_tbl->{"RCZ.idle_cycles"} + $base_stat_tbl->{"RCZ.active_stalled_cycles"} + $base_stat_tbl->{"RCZ.active_not_stalled_cycles"} +
					$base_stat_tbl->{"RCC.idle_cycles"} + $base_stat_tbl->{"RCC.active_stalled_cycles"} + $base_stat_tbl->{"RCC.active_not_stalled_cycles"} +
					$base_stat_tbl->{"STC.idle_cycles"} + $base_stat_tbl->{"STC.active_stalled_cycles"} + $base_stat_tbl->{"STC.active_not_stalled_cycles"} +
					$base_stat_tbl->{"HZ.idle_cycles"} + $base_stat_tbl->{"HZ.active_stalled_cycles"} + $base_stat_tbl->{"HZ.active_not_stalled_cycles"} ;
					
	$numerator=$base_stat_tbl->{"HZ.active_stalled_cycles"} + $base_stat_tbl->{"STC.active_stalled_cycles"}+ $base_stat_tbl->{"RCC.active_stalled_cycles"} +  $base_stat_tbl->{"RCZ.active_stalled_cycles"};
	if($denominator == 0)
	{
		return 0 ;
	}
	return ($numerator)/($denominator);
};

sub PS2_RCPB_FE{
	my $numerator = $base_stat_tbl->{"RCPBFE1.active_not_stalled_cycles"} - $base_stat_tbl->{"RCPBFE1.active_not_stalled_cycles_nonpromotedz"} ;
	my $denominator= $base_stat_tbl->{"RCPBFE1.idle_cycles"} + $base_stat_tbl->{"RCPBFE1.active_stalled_cycles"} + $base_stat_tbl->{"RCPBFE1.active_not_stalled_cycles"};
	if($denominator == 0)
	{
		return 0 ;
	}

	return ($numerator)/($denominator) ;
};

sub PS2_RCPB_BE{
	my $numerator = $base_stat_tbl->{"RCPBBE.active_not_stalled_cycles"} - $base_stat_tbl->{"RCPBBE.active_not_stalled_cycles_blend"} ;
	my $denominator= $base_stat_tbl->{"RCPBBE.idle_cycles"} + $base_stat_tbl->{"RCPBBE.active_stalled_cycles"} + $base_stat_tbl->{"RCPBBE.active_not_stalled_cycles"};
	if($denominator == 0)
	{
		return 0 ;
	}
	return ($numerator)/($denominator) ;
};

sub CalcPS2_Other_SC_SmallUnits{
	my $wmbe = $formulas->{"PS2_WMBE"} + $formulas->{"PS2_WMBE_NullTopSC"} + $formulas->{"PS2_WMBE_PixelPipe_Active_andURBport_is_active"} + $formulas->{"PS2_WMBE_PixelPipe_Active_andURBport_not_active"} ;
	my @arr = ($formulas->{"PS2_DAPB"},$wmbe,$formulas->{"PS2_RCC"},$formulas->{"PS2_RCZ"}) ;
	@arr = sort @arr;
	@arr = reverse @arr;
	return $arr[0] ;
};
