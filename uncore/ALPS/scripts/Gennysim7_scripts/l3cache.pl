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
my $PS0 = -1 ;
my $PS2 = -1 ;
my $vlv_PS0 = 0 ;
my $vlv_PS2 = 0 ;

my $i = 0 ;
foreach my $SimDataListEntry (@$lrSimData){
	$base_stat_tbl->{$SimDataListEntry->{'Name'}} =  $SimDataListEntry->{'StatObj'}->GetThisRecord() ;
	$base_stat_names[$i] = $SimDataListEntry->{'Name'} ;
	$i++ ;
}

if(($vlv == 0) || ($vlv == 6))
{
	foreach my $bank ("L3Banks", "L3BanksSLM")
	{
		$base_stat_tbl->{$bank . ".num_requests_DC_writes"} = $base_stat_tbl->{$bank . ".num_requests_DC_writes"}/(2 * $base_stat_tbl->{"Num_L3"}) ;
		$base_stat_tbl->{$bank . ".num_requests_DC_urb_writes"} = $base_stat_tbl->{$bank . ".num_requests_DC_urb_writes"}/(2 * $base_stat_tbl->{"Num_L3"}) ;
		$base_stat_tbl->{$bank . ".num_requests_DC_State"} = $base_stat_tbl->{$bank . ".num_requests_DC_State"}/(2 * $base_stat_tbl->{"Num_L3"}) ;
		$base_stat_tbl->{$bank . ".num_requests_MT"} = $base_stat_tbl->{$bank . ".num_requests_MT"}/(2 * $base_stat_tbl->{"Num_L3"}) ;
		$base_stat_tbl->{$bank . ".num_requests_IC"} = $base_stat_tbl->{$bank . ".num_requests_IC"}/(2 * $base_stat_tbl->{"Num_L3"}) ;
		$base_stat_tbl->{$bank . ".num_requests_TDL"} = $base_stat_tbl->{$bank . ".num_requests_TDL"}/(2 * $base_stat_tbl->{"Num_L3"}) ;
		$base_stat_tbl->{$bank . ".num_requests_SVSM"} = $base_stat_tbl->{$bank . ".num_requests_SVSM"}/(2 * $base_stat_tbl->{"Num_L3"}) ;
		$base_stat_tbl->{$bank . ".num_requests_DAPR"} = $base_stat_tbl->{$bank . ".num_requests_DAPR"}/(2 * $base_stat_tbl->{"Num_L3"}) ;
		$base_stat_tbl->{$bank . ".num_requests_DC_reads"} = $base_stat_tbl->{$bank . ".num_requests_DC_reads"}/(2 * $base_stat_tbl->{"Num_L3"}) ;
		$base_stat_tbl->{$bank . ".num_requests_DC_urb_reads"} = $base_stat_tbl->{$bank . ".num_requests_DC_urb_reads"}/(2 * $base_stat_tbl->{"Num_L3"}) ;
	}
}

my @RATIO_TABLE = (
	["PS0_L3CBR_GAL3",					"L3.idle"],
	["PS1_L3CBR_GAL3",					"L3.stalled"],
	["PS2_L3CBR_GAL3",					"L3.active"],
	["PS0_L3CBR_LCBR",          		"L3Crossbar.idle"],
	["PS1_L3CBR_LCBR",          		"L3Crossbar.stalled"],
	["PS2_L3CBR_LCBR",          		"L3Crossbar.active"],
	["PS0_L3CBR_Other",         		"L3Crossbar.idle"],
	["PS1_L3CBR_Other",         		"L3Crossbar.stalled"],
	["PS2_L3CBR_Other",         		"L3Crossbar.active"],
	["PS0_L3CBR_Glue",          		"L3Crossbar.idle"],
	["PS1_L3CBR_Glue",					"L3Crossbar.stalled"],
	["PS2_L3CBR_Glue",					"L3Crossbar.active"],
	["PS0_L3Bank_LSQDB",				"L3Banks.idle"],
	["PS0_L3Bank_LTCD",					"L3Banks.idle"],
	["PS1_L3Bank_LTCD",					"L3Banks.stalled"],
	["PS2_L3Bank_LTCD",					"L3Banks.active"],
	["PS0_L3Bank_Other",				"L3Banks.idle"],
	["PS1_L3Bank_Other",				"L3Banks.stalled"],
	["PS2_L3Bank_Other",				"L3Banks.active"],
	["PS0_L3Bank_Glue",					"L3Banks.idle"],
	["PS1_L3Bank_Glue",					"L3Banks.stalled"],
	["PS2_L3Bank_Glue",					"L3Banks.active"],
	["PS0_L3SLMBank_LSQDB",				"L3BanksSLM.idle"],
	["PS0_L3SLMBank_LTCDSLM",			"L3BanksSLM.idle"],
	["PS1_L3SLMBank_LTCDSLM",			"L3BanksSLM.stalled"],
	["PS2_L3SLMBank_LTCDSLM",			"L3BanksSLM.active"],
	["PS0_L3SLMBank_Other",				"L3BanksSLM.idle"],
	["PS1_L3SLMBank_Other",				"L3BanksSLM.stalled"],
	["PS2_L3SLMBank_Other",				"L3BanksSLM.active"],
	["PS0_L3SLMBank_Glue",				"L3BanksSLM.idle"],
	["PS1_L3SLMBank_Glue",				"L3BanksSLM.stalled"],
	["PS2_L3SLMBank_Glue",				"L3BanksSLM.active"],
	["PS0_L3SLMBank_LSLM_ATOMIC",		"L3BanksSLM.idle"]
);
	 
foreach my $f (@RATIO_TABLE){
	$formulas->{$f->[0]} = &CalcRatio($f->[1]);
}

my $denominator = $base_stat_tbl->{"L3.idle"} + $base_stat_tbl->{"L3.stalled"} + $base_stat_tbl->{"L3.active"} ;

if($denominator == 0)
{
	$formulas->{"PS0_L3CBR_LSQC"} = 0 ;
}
else
{
	$formulas->{"PS0_L3CBR_LSQC"}				= $base_stat_tbl->{"L3.num_cycles_superQ_empty"}/($denominator) ;
}
$formulas->{"PS1_L3CBR_LSQC"}				= 0 ;
$formulas->{"PS2_L3CBR_LSQC"}				= 1 - $formulas->{"PS0_L3CBR_LSQC"} ;

$formulas->{"PS2_L3Bank_LSQDB"}			= &CalcPS2_L3Bank_LSQDB() ;
$formulas->{"PS1_L3Bank_LSQDB"}			= 1 - $formulas->{"PS0_L3Bank_LSQDB"} - $formulas->{"PS2_L3Bank_LSQDB"} ;
$formulas->{"PS2_L3SLMBank_LSQDB"}		= &CalcPS2_L3SLMBank_LSQDB() ;
$formulas->{"PS1_L3SLMBank_LSQDB"}		= 1 - $formulas->{"PS0_L3SLMBank_LSQDB"} - $formulas->{"PS2_L3SLMBank_LSQDB"} ;

$formulas->{"PS2_L3SLMBank_LSLM_ATOMIC"}		= &CalcPS2_L3SLMBank_LSLM_ATOMICS() ;
$formulas->{"PS1_L3SLMBank_LSLM_ATOMIC"}		= 1 - $formulas->{"PS0_L3SLMBank_LSLM_ATOMIC"} - $formulas->{"PS2_L3SLMBank_LSLM_ATOMIC"} ;

$formulas->{"PS2_L3Bank_LTCD_DataRam_READ&WRITE"} = 0 ;
$base_stat_tbl->{"L3Banks_DataRam_READ"}  = &CalcL3Banks_DataRam_READ() ;
$base_stat_tbl->{"L3Banks_DataRam_WRITE"} = &CalcL3Banks_DataRam_WRITE() ;
$denominator = $base_stat_tbl->{"L3Banks.idle"} +  $base_stat_tbl->{"L3Banks_DataRam_READ"} + $base_stat_tbl->{"L3Banks_DataRam_WRITE"} ;
if($denominator == 0)
{
	$formulas->{"PS0_L3Bank_LTCD_DataRam_IDLE"} = 0 ;
	$formulas->{"PS2_L3Bank_LTCD_DataRam_READ"} = 0 ;
	$formulas->{"PS2_L3Bank_LTCD_DataRam_WRITE"} = 0 ;
}
else
{
	$formulas->{"PS0_L3Bank_LTCD_DataRam_IDLE"} =  $base_stat_tbl->{"L3Banks.idle"}/$denominator ;
	$formulas->{"PS2_L3Bank_LTCD_DataRam_READ"} = $base_stat_tbl->{"L3Banks_DataRam_READ"}/$denominator ;
	$formulas->{"PS2_L3Bank_LTCD_DataRam_WRITE"} = $base_stat_tbl->{"L3Banks_DataRam_WRITE"}/$denominator ;
}

$formulas->{"PS2_L3SLMBank_LTCDSLM_DataRam_READ&WRITE"} = 0 ;
$base_stat_tbl->{"L3BanksSLM_DataRam_READ"}  = &CalcL3BanksSLM_DataRam_READ() ;
$base_stat_tbl->{"L3BanksSLM_DataRam_WRITE"} = &CalcL3BanksSLM_DataRam_WRITE() ;
$denominator = $base_stat_tbl->{"L3BanksSLM.idle"} +  $base_stat_tbl->{"L3BanksSLM_DataRam_READ"} + $base_stat_tbl->{"L3BanksSLM_DataRam_WRITE"} ;
if($denominator == 0)
{
	$formulas->{"PS0_L3SLMBank_LTCDSLM_DataRam_IDLE"} = 0 ;
	$formulas->{"PS2_L3SLMBank_LTCDSLM_DataRam_READ"} = 0 ;
	$formulas->{"PS2_L3SLMBank_LTCDSLM_DataRam_WRITE"} = 0 ;
}
else
{
	$formulas->{"PS0_L3SLMBank_LTCDSLM_DataRam_IDLE"} =  $base_stat_tbl->{"L3BanksSLM.idle"}/$denominator ;
	$formulas->{"PS2_L3SLMBank_LTCDSLM_DataRam_READ"} = $base_stat_tbl->{"L3BanksSLM_DataRam_READ"}/$denominator ;
	$formulas->{"PS2_L3SLMBank_LTCDSLM_DataRam_WRITE"} = $base_stat_tbl->{"L3BanksSLM_DataRam_WRITE"}/$denominator ;
}

my @derived_stat_names = sort keys %{$formulas};
foreach my $d (@derived_stat_names)
{
	$derived_stat_tbl->{$d} = $formulas->{$d} ;
}

if($vlv != 0)
{
	$derived_stat_tbl->{"PS1_L3Bank_LSQDB"} = 0 ;
}
#####################################################
# Printing out stats unit-wise
#####################################################
my $count = 0 ;
open(FP, '>' . $odir . 'l3cache_alps1_1.csv');
print FP"Power Stat,Residency\n";

foreach  my $unit ("L3Bank_LTCD_DataRam","L3Bank_LTCD","L3Bank_LSQDB","L3Bank_Other","L3Bank_Glue","L3SLMBank_LTCDSLM_DataRam","L3SLMBank_LTCDSLM","L3SLMBank_LSQDB","L3SLMBank_LSLM_ATOMIC","L3SLMBank_Other","L3SLMBank_Glue","L3CBR_GAL3","L3CBR_LSQC","L3CBR_LCBR","L3CBR_Other","L3CBR_Glue")
{
    for($count=0; $count <= $#derived_stat_names; $count++)
	{
        if($derived_stat_names[$count] =~ m/PS(.?)_$unit$/i)
		{
            print FP"$derived_stat_names[$count],$derived_stat_tbl->{$derived_stat_names[$count]}\n" ;
        }
		if(($unit eq "L3Bank_LTCD_DataRam") || ($unit eq "L3SLMBank_LTCDSLM_DataRam"))
		{
			if($derived_stat_names[$count] =~ m/$unit/i)
			{
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
	
	my $unit ;
	my $l3bank ;
	my $l3bankslm ;
	
	if($vlv > 0 && $vlv <= 5)
	{
		$unit = 'L3Bank0' ;
		$l3bank = '' ;
		$l3bankslm = 'L3Bank0' ;
	}
	elsif($vlv == 6)
	{
		$unit = 'L3Bank(0|1)' ;
		$l3bank = '' ;
		$l3bankslm = 'L3Bank(0|1)' ;
	}
	else
	{
		$unit = 'L3Bank\\d+' ;
		$l3bank = 'L3Bank(0|2)' ;
		$l3bankslm = 'L3Bank(1|3)' ;
	}
	
	push (@$lrSimData, { 
		'Name' => 'L3.idle',
		'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uL3_\\d+\\.' . $unit . '\\.power_fub\\.idle',
											'm_ReportDataAs' => 'AVERAGEDIV1',
											'm_DoTestMaxVal' => 0})
	});
		
	push (@$lrSimData, { 
		'Name' => 'L3.stalled',
		'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uL3_\\d+\\.' . $unit . '\\.power_fub\\.stalled',
											'm_ReportDataAs' => 'AVERAGEDIV1',
											'm_DoTestMaxVal' => 0})
	});
	
	push (@$lrSimData, { 
		'Name' => 'L3.active',
		'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uL3_\\d+\\.' . $unit . '\\.power_fub\\.active',
											'm_ReportDataAs' => 'AVERAGEDIV1',
											'm_DoTestMaxVal' => 0})
	});
	
	push (@$lrSimData, {
		'Name' => 'L3.num_cycles_superQ_empty',
		'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uL3_\\d+\\.' . $unit . '\\.num_cycles_superQ_empty',
										'm_ReportDataAs' => 'AVERAGEDIV1',
										'm_DoTestMaxVal' => 0})
	});
	
	foreach my $d ("L3Banks","L3BanksSLM")
	{
		if($d eq "L3Banks")
		{
			$unit = $l3bank ;
		}
		else
		{
			$unit = $l3bankslm ;
		}
		
		push (@$lrSimData, { 
			'Name' => $d . '.idle',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uL3_\\d+\\.' . $unit . '\\.power_fub\\.idle',
												'm_ReportDataAs' => 'AVERAGEDIV1',
												'm_DoTestMaxVal' => 0})
		});
			
		push (@$lrSimData, { 
			'Name' => $d . '.stalled',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uL3_\\d+\\.' . $unit . '\\.power_fub\\.stalled',
												'm_ReportDataAs' => 'AVERAGEDIV1',
												'm_DoTestMaxVal' => 0})
		});
		
		push (@$lrSimData, { 
			'Name' => $d . '.active',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uL3_\\d+\\.' . $unit . '\\.power_fub\\.active',
												'm_ReportDataAs' => 'AVERAGEDIV1',
												'm_DoTestMaxVal' => 0})
		});
		
		push (@$lrSimData, {
			'Name' => $d . '.num_requests_VF',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uL3_\\d+\\.' . $unit . '\\.num_requests_VF',
											'm_ReportDataAs' => 'AVERAGEDIV1',
											'm_DoTestMaxVal' => 0})
		});
		push (@$lrSimData, {
			'Name' => $d . '.num_requests_MT',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uL3_\\d+\\.' . $unit . '\\.num_requests_MT\\d+',
											'm_ReportDataAs' => 'SUM',
											'm_DoTestMaxVal' => 0})
		});
		push (@$lrSimData, {
			'Name' => $d . '.num_requests_IC',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uL3_\\d+\\.' . $unit . '\\.num_requests_IC\\d+',
											'm_ReportDataAs' => 'SUM',
											'm_DoTestMaxVal' => 0})
		});
		push (@$lrSimData, {
			'Name' => $d . '.num_requests_TDL',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uL3_\\d+\\.' . $unit . '\\.num_requests_TDL\\d+',
											'm_ReportDataAs' => 'SUM',
											'm_DoTestMaxVal' => 0})
		});
		push (@$lrSimData, {
			'Name' => $d . '.num_requests_DC_reads',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uL3_\\d+\\.' . $unit . '\\.num_requests_DC\\d+_reads',
											'm_ReportDataAs' => 'SUM',
											'm_DoTestMaxVal' => 0})
		});
		push (@$lrSimData, {
			'Name' => $d . '.num_requests_DC_urb_reads',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uL3_\\d+\\.' . $unit . '\\.num_requests_DC\\d+_urb_reads',
											'm_ReportDataAs' => 'SUM',
											'm_DoTestMaxVal' => 0})
		});
		push (@$lrSimData, {
			'Name' => $d . '.num_requests_SVSM',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uL3_\\d+\\.' . $unit . '\\.num_requests_SVSM\\d+',
											'm_ReportDataAs' => 'SUM',
											'm_DoTestMaxVal' => 0})
		});
		push (@$lrSimData, {
			'Name' => $d . '.num_requests_DAPR',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uL3_\\d+\\.' . $unit . '\\.num_requests_DAPR\\d+',
											'm_ReportDataAs' => 'SUM',
											'm_DoTestMaxVal' => 0})
		});
		push (@$lrSimData, {
			'Name' => $d . '.num_requests_DC_State',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uL3_\\d+\\.' . $unit . '\\.num_requests_DC\\d+_State',
											'm_ReportDataAs' => 'SUM',
											'm_DoTestMaxVal' => 0})
		});
		push (@$lrSimData, {
			'Name' => $d . '.num_requests_RCPFE',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uL3_\\d+\\.' . $unit . '\\.num_requests_RCPFE',
											'm_ReportDataAs' => 'AVERAGEDIV1',
											'm_DoTestMaxVal' => 0})
		});
		push (@$lrSimData, {
			'Name' => $d . '.num_requests_RCPBE',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uL3_\\d+\\.' . $unit . '\\.num_requests_RCPBE',
											'm_ReportDataAs' => 'AVERAGEDIV1',
											'm_DoTestMaxVal' => 0})
		});
		push (@$lrSimData, {
			'Name' => $d . '.num_requests_WMFE',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uL3_\\d+\\.' . $unit . '\\.num_requests_WMFE',
											'm_ReportDataAs' => 'AVERAGEDIV1',
											'm_DoTestMaxVal' => 0})
		});
		push (@$lrSimData, {
			'Name' => $d . '.num_requests_IECP',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uL3_\\d+\\.' . $unit . '\\.num_requests_IECP',
											'm_ReportDataAs' => 'AVERAGEDIV1',
											'm_DoTestMaxVal' => 0})
		});
		push (@$lrSimData, {
			'Name' => $d . '.num_requests_RCC',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uL3_\\d+\\.' . $unit . '\\.num_requests_RCC',
											'm_ReportDataAs' => 'AVERAGEDIV1',
											'm_DoTestMaxVal' => 0})
		});
		push (@$lrSimData, {
			'Name' => $d . '.num_requests_SVL',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uL3_\\d+\\.' . $unit . '\\.num_requests_SVL',
											'm_ReportDataAs' => 'AVERAGEDIV1',
											'm_DoTestMaxVal' => 0})
		});
		push (@$lrSimData, {
			'Name' => $d . '.num_requests_GAFS',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uL3_\\d+\\.' . $unit . '\\.num_requests_GAFS',
											'm_ReportDataAs' => 'AVERAGEDIV1',
											'm_DoTestMaxVal' => 0})
		});
		push (@$lrSimData, {
			'Name' => $d . '.num_requests_SBE',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uL3_\\d+\\.' . $unit . '\\.num_requests_SBE',
											'm_ReportDataAs' => 'AVERAGEDIV1',
											'm_DoTestMaxVal' => 0})
		});
		push (@$lrSimData, {
			'Name' => $d . '.num_SLM_reads',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uL3_\\d+\\.' . $unit . '\\.num_SLM_reads',
											'm_ReportDataAs' => 'AVERAGEDIV1',
											'm_DoTestMaxVal' => 0})
		});
		push (@$lrSimData, {
			'Name' => $d . '.num_SLM_atomics',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uL3_\\d+\\.' . $unit . '\\.num_SLM_atomics',
											'm_ReportDataAs' => 'AVERAGEDIV1',
											'm_DoTestMaxVal' => 0})
		});
		push (@$lrSimData, {
			'Name' => $d . '.num_L3_atomics',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uL3_\\d+\\.' . $unit . '\\.num_L3_atomics',
											'm_ReportDataAs' => 'AVERAGEDIV1',
											'm_DoTestMaxVal' => 0})
		});
		push (@$lrSimData, {
			'Name' => $d . '.num_URB_atomics',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uL3_\\d+\\.' . $unit . '\\.num_URB_atomics',
											'm_ReportDataAs' => 'AVERAGEDIV1',
											'm_DoTestMaxVal' => 0})
		});
		push (@$lrSimData, {
			'Name' => $d . '.num_SLM_writes',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uL3_\\d+\\.' . $unit . '\\.num_SLM_writes',
											'm_ReportDataAs' => 'AVERAGEDIV1',
											'm_DoTestMaxVal' => 0})
		});
		
		push (@$lrSimData, {
			'Name' => $d . '.num_SLM_atomics',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uL3_\\d+\\.' . $unit . '\\.num_SLM_atomics',
											'm_ReportDataAs' => 'AVERAGEDIV1',
											'm_DoTestMaxVal' => 0})
		});
		
		push (@$lrSimData, {
			'Name' => $d . '.num_L3_atomics',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uL3_\\d+\\.' . $unit . '\\.num_L3_atomics',
											'm_ReportDataAs' => 'AVERAGEDIV1',
											'm_DoTestMaxVal' => 0})
		});
		
		push (@$lrSimData, {
			'Name' => $d . '.num_URB_atomics',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uL3_\\d+\\.' . $unit . '\\.num_URB_atomics',
											'm_ReportDataAs' => 'AVERAGEDIV1',
											'm_DoTestMaxVal' => 0})
		});
		
		push (@$lrSimData, {
			'Name' => $d . '.num_requests_DC_writes',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uL3_\\d+\\.' . $unit . '\\.num_requests_DC\\d+_writes',
											'm_ReportDataAs' => 'SUM',
											'm_DoTestMaxVal' => 0})
		});
		
		push (@$lrSimData, {
			'Name' => $d . '.num_requests_DC_urb_writes',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uL3_\\d+\\.' . $unit . '\\.num_requests_DC\\d+_urb_writes',
											'm_ReportDataAs' => 'SUM',
											'm_DoTestMaxVal' => 0})
		});
		
		push (@$lrSimData, {
			'Name' => $d . '.num_responses_GAM',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uL3_\\d+\\.' . $unit . '\\.num_responses_GAM',
											'm_ReportDataAs' => 'AVERAGEDIV1',
											'm_DoTestMaxVal' => 0})
		});
		
		push (@$lrSimData, {
			'Name' => $d . '.num_tag_hits',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uL3_\\d+\\.' . $unit . '\\.num_tag_hits',
											'm_ReportDataAs' => 'AVERAGEDIV1',
											'm_DoTestMaxVal' => 0})
		});
	}
	
	push (@$lrSimData, { 
		'Name' => 'Num_L3',
		'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uL3_\\d+\\.L3Crossbar\\.power_fub\\.idle',
											'm_ReportDataAs' => 'COUNT',
											'm_DoTestMaxVal' => 0})
	});
	
	push (@$lrSimData, { 
		'Name' => 'L3Crossbar.idle',
		'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uL3_\\d+\\.L3Crossbar\\.power_fub\\.idle',
											'm_ReportDataAs' => 'AVERAGEDIV1',
											'm_DoTestMaxVal' => 0})
	});
		
	push (@$lrSimData, { 
		'Name' => 'L3Crossbar.stalled',
		'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uL3_\\d+\\.L3Crossbar\\.power_fub\\.stalled',
											'm_ReportDataAs' => 'AVERAGEDIV1',
											'm_DoTestMaxVal' => 0})
	});
	
	push (@$lrSimData, { 
		'Name' => 'L3Crossbar.active',
		'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uL3_\\d+\\.L3Crossbar\\.power_fub\\.active',
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
	  if(/^knob/) {next;} #Skipping knobs in new Gennysim stat files
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
	  if(/^knob/) {next;} #Skipping knobs in new Gennysim stat files
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
	my @data = split/\./, $N ;
	my $unit = $data[0] ;
	my $denominator = $base_stat_tbl->{$unit . ".idle"} + $base_stat_tbl->{$unit . ".stalled"} + $base_stat_tbl->{$unit . ".active"} ;
	if($denominator == 0)
	{
		return 0 ;
	}
	return $numerator/$denominator ;
};

sub CalcPS2_L3Bank_LSQDB{
	my $numerator = $base_stat_tbl->{"L3Banks.num_requests_DC_urb_reads"} +
					$base_stat_tbl->{"L3Banks.num_requests_DC_urb_writes"} +
					$base_stat_tbl->{"L3Banks.num_responses_GAM"} +
					$base_stat_tbl->{"L3Banks.num_tag_hits"} ;
					
	my $denominator = $base_stat_tbl->{"L3.idle"} + $base_stat_tbl->{"L3.stalled"} + $base_stat_tbl->{"L3.active"};
	if($denominator == 0)
	{
		return 0 ;
	}
	return $numerator/$denominator ;
}

sub CalcPS2_L3SLMBank_LSQDB{
	my $numerator = $base_stat_tbl->{"L3BanksSLM.num_requests_DC_urb_reads"} +
					$base_stat_tbl->{"L3BanksSLM.num_requests_DC_urb_writes"} +
					$base_stat_tbl->{"L3BanksSLM.num_responses_GAM"} +
					$base_stat_tbl->{"L3BanksSLM.num_tag_hits"} ;
					
	my $denominator = $base_stat_tbl->{"L3.idle"} + $base_stat_tbl->{"L3.stalled"} + $base_stat_tbl->{"L3.active"};
	if($denominator == 0)
	{
		return 0 ;
	}
	return $numerator/$denominator ;
}

sub CalcPS2_L3SLMBank_LSLM_ATOMICS{
	my $numerator = $base_stat_tbl->{"L3BanksSLM.num_SLM_atomics"} +
					$base_stat_tbl->{"L3BanksSLM.num_L3_atomics"} +
					$base_stat_tbl->{"L3BanksSLM.num_URB_atomics"} ;
					
	my $denominator = $base_stat_tbl->{"L3.idle"} + $base_stat_tbl->{"L3.stalled"} + $base_stat_tbl->{"L3.active"};
	if($denominator == 0)
	{
		return 0 ;
	}
	return $numerator/$denominator ;
}

sub CalcL3Banks_DataRam_READ{
	my $numerator = $base_stat_tbl->{"L3Banks.num_requests_VF"} +
					$base_stat_tbl->{"L3Banks.num_requests_MT"} +
					$base_stat_tbl->{"L3Banks.num_requests_IC"} +
					$base_stat_tbl->{"L3Banks.num_requests_TDL"} +
					$base_stat_tbl->{"L3Banks.num_requests_DC_reads"} +
					$base_stat_tbl->{"L3Banks.num_requests_DC_urb_reads"} +
					$base_stat_tbl->{"L3Banks.num_requests_SVSM"} +
					$base_stat_tbl->{"L3Banks.num_requests_DAPR"} +
					$base_stat_tbl->{"L3Banks.num_requests_DC_State"} +
					$base_stat_tbl->{"L3Banks.num_requests_RCPFE"} +
					$base_stat_tbl->{"L3Banks.num_requests_RCPBE"} +
					$base_stat_tbl->{"L3Banks.num_requests_WMFE"} +
					$base_stat_tbl->{"L3Banks.num_requests_IECP"} +
					$base_stat_tbl->{"L3Banks.num_requests_RCC"} +
					$base_stat_tbl->{"L3Banks.num_requests_SVL"} +
					$base_stat_tbl->{"L3Banks.num_requests_GAFS"} +
					$base_stat_tbl->{"L3Banks.num_requests_SBE"} +
					$base_stat_tbl->{"L3Banks.num_SLM_reads"} +
					$base_stat_tbl->{"L3Banks.num_SLM_atomics"} +
					$base_stat_tbl->{"L3Banks.num_L3_atomics"} +
					$base_stat_tbl->{"L3Banks.num_URB_atomics"} ;
	return $numerator ;
}

sub CalcL3Banks_DataRam_WRITE{
	my $numerator = $base_stat_tbl->{"L3Banks.num_SLM_writes"} +
					$base_stat_tbl->{"L3Banks.num_SLM_atomics"} +
					$base_stat_tbl->{"L3Banks.num_L3_atomics"} +
					$base_stat_tbl->{"L3Banks.num_URB_atomics"} +
					$base_stat_tbl->{"L3Banks.num_requests_DC_writes"} +
					$base_stat_tbl->{"L3Banks.num_requests_DC_urb_writes"} +
					$base_stat_tbl->{"L3Banks.num_responses_GAM"} ;	
	return $numerator ;
}

sub CalcL3BanksSLM_DataRam_READ{
	my $numerator = $base_stat_tbl->{"L3BanksSLM.num_requests_VF"} +
					$base_stat_tbl->{"L3BanksSLM.num_requests_MT"} +
					$base_stat_tbl->{"L3BanksSLM.num_requests_IC"} +
					$base_stat_tbl->{"L3BanksSLM.num_requests_TDL"} +
					$base_stat_tbl->{"L3BanksSLM.num_requests_DC_reads"} +
					$base_stat_tbl->{"L3BanksSLM.num_requests_DC_urb_reads"} +
					$base_stat_tbl->{"L3BanksSLM.num_requests_SVSM"} +
					$base_stat_tbl->{"L3BanksSLM.num_requests_DAPR"} +
					$base_stat_tbl->{"L3BanksSLM.num_requests_DC_State"} +
					$base_stat_tbl->{"L3BanksSLM.num_requests_RCPFE"} +
					$base_stat_tbl->{"L3BanksSLM.num_requests_RCPBE"} +
					$base_stat_tbl->{"L3BanksSLM.num_requests_WMFE"} +
					$base_stat_tbl->{"L3BanksSLM.num_requests_IECP"} +
					$base_stat_tbl->{"L3BanksSLM.num_requests_RCC"} +
					$base_stat_tbl->{"L3BanksSLM.num_requests_SVL"} +
					$base_stat_tbl->{"L3BanksSLM.num_requests_GAFS"} +
					$base_stat_tbl->{"L3BanksSLM.num_requests_SBE"} +
					$base_stat_tbl->{"L3BanksSLM.num_SLM_reads"} +
					$base_stat_tbl->{"L3BanksSLM.num_SLM_atomics"} +
					$base_stat_tbl->{"L3BanksSLM.num_L3_atomics"} +
					$base_stat_tbl->{"L3BanksSLM.num_URB_atomics"} ;
	return $numerator ;
}

sub CalcL3BanksSLM_DataRam_WRITE{
	my $numerator = $base_stat_tbl->{"L3BanksSLM.num_SLM_writes"} +
					$base_stat_tbl->{"L3BanksSLM.num_SLM_atomics"} +
					$base_stat_tbl->{"L3BanksSLM.num_L3_atomics"} +
					$base_stat_tbl->{"L3BanksSLM.num_URB_atomics"} +
					$base_stat_tbl->{"L3BanksSLM.num_requests_DC_writes"} +
					$base_stat_tbl->{"L3BanksSLM.num_requests_DC_urb_writes"} +
					$base_stat_tbl->{"L3BanksSLM.num_responses_GAM"} ;	
	return $numerator ;
}
