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
my $k_media		 = shift;

my $num_rows	 = 0 ;
my $num_eu		 = 0 ;

my @eu_pln_opcodes = (90,92) ;
my @eu_mad_opcodes = (84 .. 89 , 91 , 67 .. 74) ;
my @eu_mul_opcodes = (65) ;
my @eu_add_opcodes = (4 .. 9 , 16, 17, 19, 20, 23..26, 75..79, 64 , 66) ;
my @eu_mov_opcodes = (1, 3) ;
my @eu_sel_opcodes = (2 , 32 .. 46 , 48 , 126, 80, 81) ;
my @eu_transc_opcodes = (56) ;

# open (STATFILE, $statfilename) || die ("Couldn't open GennySim stat file $statfilename");
# my $count = 1 ;
# my $cfg = "" ;
# while(my $line = <STATFILE>)
# {
	# if($count == 3)
	# {
		# chomp($line) ;
		# my @command = split/(-|\.)cfg/,$line ;
		# my @name = split/\//, $command[2] ;
		# $cfg = $name[$#name] ;
	# }
	# if($count > 3)
	# {
		# last ;
	# }
	# $count++ ;
# }
# close (STATFILE) ;

# $cfg =~ m/_c(\d+)_/ ;
# my $info = $1 ;
# $num_rows = length($info) ;
# $num_eu = chr ord $info ;

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
my $base_stat_tbl = {};
my $derived_stat_tbl   = {};
my @base_stat_names ;

my $num_base_stat = 0 ;
foreach my $SimDataListEntry (@$lrSimData){
	$base_stat_tbl->{$SimDataListEntry->{'Name'}} =  $SimDataListEntry->{'StatObj'}->GetThisRecord() ;
	$base_stat_names[$num_base_stat] = $SimDataListEntry->{'Name'} ;
	$num_base_stat++ ;
}

$base_stat_tbl->{"Num_EU"} =~ m/_(\d+)(\d)\./ ;
$num_rows = $1 + 1 ;
$num_eu = $2 + 1 ;

my $ToggleSimData = [];
ToggleDataStructure($ToggleSimData);

open (my $fhSTAT, $statfilename) || die ("Couldn't open GennySim stat file $statfilename");
FindSTATIColumnHdrs($fhSTAT, $ToggleSimData);
close ($fhSTAT);

open (my $fhSTAT, $statfilename) || die ("Couldn't open GennySim stat file $statfilename");
GetSTATIRecord($fhSTAT, $ToggleSimData);
close ($fhSTAT);

foreach my $SimDataListEntry (@$ToggleSimData){
	$base_stat_tbl->{$SimDataListEntry->{'Name'}} =  $SimDataListEntry->{'StatObj'}->GetThisRecord() ;
	$base_stat_names[$num_base_stat] = $SimDataListEntry->{'Name'} ;
	$num_base_stat++ ;
}

$base_stat_tbl->{"Total_FPU_Instructions"} = 0 ;
$base_stat_tbl->{"Total_FPU_Instructions"} = 0 ;

foreach (@eu_pln_opcodes)
{
	$base_stat_tbl->{"Total_FPU_Instructions"} += $base_stat_tbl->{"FPUOpCode_fp32[" . $_ . "]"} + $base_stat_tbl->{"FPUOpCode_fp16[" . $_ . "]"} ;
	$base_stat_tbl->{"Total_FPU_Instructions"} += $base_stat_tbl->{"FPUOpCode_int32[" . $_ . "]"} + $base_stat_tbl->{"FPUOpCode_int16[" . $_ . "]"} ;
	$base_stat_tbl->{"Total_EM_Instructions"} += $base_stat_tbl->{"HybridOpCode_fp32[" . $_ . "]"} + $base_stat_tbl->{"HybridOpCode_fp16[" . $_ . "]"} ;
	$base_stat_tbl->{"Total_EM_Instructions"} += $base_stat_tbl->{"HybridOpCode_int32[" . $_ . "]"} + $base_stat_tbl->{"HybridOpCode_int16[" . $_ . "]"} ;
	$base_stat_tbl->{"FPU_PLN_Instructions_FP32"} += $base_stat_tbl->{"FPUOpCode_fp32[" . $_ . "]"} ;
	$base_stat_tbl->{"FPU_PLN_Instructions_FP16"} += $base_stat_tbl->{"FPUOpCode_fp16[" . $_ . "]"} ;
	$base_stat_tbl->{"FPU_PLN_Instructions_INT32"} += $base_stat_tbl->{"FPUOpCode_int32[" . $_ . "]"} ;
	$base_stat_tbl->{"FPU_PLN_Instructions_INT16"} += $base_stat_tbl->{"FPUOpCode_int16[" . $_ . "]"} ;
	$base_stat_tbl->{"EM_PLN_Instructions_FP32"} += $base_stat_tbl->{"HybridOpCode_fp32[" . $_ . "]"} ;
	$base_stat_tbl->{"EM_PLN_Instructions_FP16"} += $base_stat_tbl->{"HybridOpCode_fp16[" . $_ . "]"} ;
	$base_stat_tbl->{"EM_PLN_Instructions_INT32"} += $base_stat_tbl->{"HybridOpCode_int32[" . $_ . "]"} ;
	$base_stat_tbl->{"EM_PLN_Instructions_INT16"} += $base_stat_tbl->{"HybridOpCode_int16[" . $_ . "]"} ;
}
foreach (@eu_mad_opcodes)
{
	$base_stat_tbl->{"Total_FPU_Instructions"} += $base_stat_tbl->{"FPUOpCode_fp32[" . $_ . "]"} + $base_stat_tbl->{"FPUOpCode_fp16[" . $_ . "]"} ;
	$base_stat_tbl->{"Total_FPU_Instructions"} += $base_stat_tbl->{"FPUOpCode_int32[" . $_ . "]"} + $base_stat_tbl->{"FPUOpCode_int16[" . $_ . "]"} ;
	$base_stat_tbl->{"Total_EM_Instructions"} += $base_stat_tbl->{"HybridOpCode_fp32[" . $_ . "]"} + $base_stat_tbl->{"HybridOpCode_fp16[" . $_ . "]"} ;
	$base_stat_tbl->{"Total_EM_Instructions"} += $base_stat_tbl->{"HybridOpCode_int32[" . $_ . "]"} + $base_stat_tbl->{"HybridOpCode_int16[" . $_ . "]"} ;
	$base_stat_tbl->{"FPU_MAD_Instructions_FP32"} += $base_stat_tbl->{"FPUOpCode_fp32[" . $_ . "]"} ;
	$base_stat_tbl->{"FPU_MAD_Instructions_FP16"} += $base_stat_tbl->{"FPUOpCode_fp16[" . $_ . "]"} ;
	$base_stat_tbl->{"FPU_MAD_Instructions_INT32"} += $base_stat_tbl->{"FPUOpCode_int32[" . $_ . "]"} ;
	$base_stat_tbl->{"FPU_MAD_Instructions_INT16"} += $base_stat_tbl->{"FPUOpCode_int16[" . $_ . "]"} ;
	$base_stat_tbl->{"EM_MAD_Instructions_FP32"} += $base_stat_tbl->{"HybridOpCode_fp32[" . $_ . "]"} ;
	$base_stat_tbl->{"EM_MAD_Instructions_FP16"} += $base_stat_tbl->{"HybridOpCode_fp16[" . $_ . "]"} ;
	$base_stat_tbl->{"EM_MAD_Instructions_INT32"} += $base_stat_tbl->{"HybridOpCode_int32[" . $_ . "]"} ;
	$base_stat_tbl->{"EM_MAD_Instructions_INT16"} += $base_stat_tbl->{"HybridOpCode_int16[" . $_ . "]"} ;
}
foreach (@eu_mul_opcodes)
{
	$base_stat_tbl->{"Total_FPU_Instructions"} += $base_stat_tbl->{"FPUOpCode_fp32[" . $_ . "]"} + $base_stat_tbl->{"FPUOpCode_fp16[" . $_ . "]"} ;
	$base_stat_tbl->{"Total_FPU_Instructions"} += $base_stat_tbl->{"FPUOpCode_int32[" . $_ . "]"} + $base_stat_tbl->{"FPUOpCode_int16[" . $_ . "]"} ;
	$base_stat_tbl->{"Total_EM_Instructions"} += $base_stat_tbl->{"HybridOpCode_fp32[" . $_ . "]"} + $base_stat_tbl->{"HybridOpCode_fp16[" . $_ . "]"} ;
	$base_stat_tbl->{"Total_EM_Instructions"} += $base_stat_tbl->{"HybridOpCode_int32[" . $_ . "]"} + $base_stat_tbl->{"HybridOpCode_int16[" . $_ . "]"} ;
	$base_stat_tbl->{"FPU_MUL_Instructions_FP32"} += $base_stat_tbl->{"FPUOpCode_fp32[" . $_ . "]"} ;
	$base_stat_tbl->{"FPU_MUL_Instructions_FP16"} += $base_stat_tbl->{"FPUOpCode_fp16[" . $_ . "]"} ;
	$base_stat_tbl->{"FPU_MUL_Instructions_INT32"} += $base_stat_tbl->{"FPUOpCode_int32[" . $_ . "]"} ;
	$base_stat_tbl->{"FPU_MUL_Instructions_INT16"} += $base_stat_tbl->{"FPUOpCode_int16[" . $_ . "]"} ;
	$base_stat_tbl->{"EM_MUL_Instructions_FP32"} += $base_stat_tbl->{"HybridOpCode_fp32[" . $_ . "]"} ;
	$base_stat_tbl->{"EM_MUL_Instructions_FP16"} += $base_stat_tbl->{"HybridOpCode_fp16[" . $_ . "]"} ;
	$base_stat_tbl->{"EM_MUL_Instructions_INT32"} += $base_stat_tbl->{"HybridOpCode_int32[" . $_ . "]"} ;
	$base_stat_tbl->{"EM_MUL_Instructions_INT16"} += $base_stat_tbl->{"HybridOpCode_int16[" . $_ . "]"} ;
}
foreach (@eu_add_opcodes)
{
	$base_stat_tbl->{"Total_FPU_Instructions"} += $base_stat_tbl->{"FPUOpCode_fp32[" . $_ . "]"} + $base_stat_tbl->{"FPUOpCode_fp16[" . $_ . "]"} ;
	$base_stat_tbl->{"Total_FPU_Instructions"} += $base_stat_tbl->{"FPUOpCode_int32[" . $_ . "]"} + $base_stat_tbl->{"FPUOpCode_int16[" . $_ . "]"} ;
	$base_stat_tbl->{"Total_EM_Instructions"} += $base_stat_tbl->{"HybridOpCode_fp32[" . $_ . "]"} + $base_stat_tbl->{"HybridOpCode_fp16[" . $_ . "]"} ;
	$base_stat_tbl->{"Total_EM_Instructions"} += $base_stat_tbl->{"HybridOpCode_int32[" . $_ . "]"} + $base_stat_tbl->{"HybridOpCode_int16[" . $_ . "]"} ;
	$base_stat_tbl->{"FPU_ADD_Instructions_FP32"} += $base_stat_tbl->{"FPUOpCode_fp32[" . $_ . "]"} ;
	$base_stat_tbl->{"FPU_ADD_Instructions_FP16"} += $base_stat_tbl->{"FPUOpCode_fp16[" . $_ . "]"} ;
	$base_stat_tbl->{"FPU_ADD_Instructions_INT32"} += $base_stat_tbl->{"FPUOpCode_int32[" . $_ . "]"} ;
	$base_stat_tbl->{"FPU_ADD_Instructions_INT16"} += $base_stat_tbl->{"FPUOpCode_int16[" . $_ . "]"} ;
	$base_stat_tbl->{"EM_ADD_Instructions_FP32"} += $base_stat_tbl->{"HybridOpCode_fp32[" . $_ . "]"} ;
	$base_stat_tbl->{"EM_ADD_Instructions_FP16"} += $base_stat_tbl->{"HybridOpCode_fp16[" . $_ . "]"} ;
	$base_stat_tbl->{"EM_ADD_Instructions_INT32"} += $base_stat_tbl->{"HybridOpCode_int32[" . $_ . "]"} ;
	$base_stat_tbl->{"EM_ADD_Instructions_INT16"} += $base_stat_tbl->{"HybridOpCode_int16[" . $_ . "]"} ;
}
foreach (@eu_mov_opcodes)
{
	$base_stat_tbl->{"Total_FPU_Instructions"} += $base_stat_tbl->{"FPUOpCode_fp32[" . $_ . "]"} + $base_stat_tbl->{"FPUOpCode_fp16[" . $_ . "]"} ;
	$base_stat_tbl->{"Total_FPU_Instructions"} += $base_stat_tbl->{"FPUOpCode_int32[" . $_ . "]"} + $base_stat_tbl->{"FPUOpCode_int16[" . $_ . "]"} ;
	$base_stat_tbl->{"Total_EM_Instructions"} += $base_stat_tbl->{"HybridOpCode_fp32[" . $_ . "]"} + $base_stat_tbl->{"HybridOpCode_fp16[" . $_ . "]"} ;
	$base_stat_tbl->{"Total_EM_Instructions"} += $base_stat_tbl->{"HybridOpCode_int32[" . $_ . "]"} + $base_stat_tbl->{"HybridOpCode_int16[" . $_ . "]"} ;
	$base_stat_tbl->{"FPU_MOV_Instructions_FP32"} += $base_stat_tbl->{"FPUOpCode_fp32[" . $_ . "]"} ;
	$base_stat_tbl->{"FPU_MOV_Instructions_FP16"} += $base_stat_tbl->{"FPUOpCode_fp16[" . $_ . "]"} ;
	$base_stat_tbl->{"FPU_MOV_Instructions_INT32"} += $base_stat_tbl->{"FPUOpCode_int32[" . $_ . "]"} ;
	$base_stat_tbl->{"FPU_MOV_Instructions_INT16"} += $base_stat_tbl->{"FPUOpCode_int16[" . $_ . "]"} ;
	$base_stat_tbl->{"EM_MOV_Instructions_FP32"} += $base_stat_tbl->{"HybridOpCode_fp32[" . $_ . "]"} ;
	$base_stat_tbl->{"EM_MOV_Instructions_FP16"} += $base_stat_tbl->{"HybridOpCode_fp16[" . $_ . "]"} ;
	$base_stat_tbl->{"EM_MOV_Instructions_INT32"} += $base_stat_tbl->{"HybridOpCode_int32[" . $_ . "]"} ;
	$base_stat_tbl->{"EM_MOV_Instructions_INT16"} += $base_stat_tbl->{"HybridOpCode_int16[" . $_ . "]"} ;
}
foreach (@eu_sel_opcodes)
{
	$base_stat_tbl->{"Total_FPU_Instructions"} += $base_stat_tbl->{"FPUOpCode_fp32[" . $_ . "]"} + $base_stat_tbl->{"FPUOpCode_fp16[" . $_ . "]"} ;
	$base_stat_tbl->{"Total_FPU_Instructions"} += $base_stat_tbl->{"FPUOpCode_int32[" . $_ . "]"} + $base_stat_tbl->{"FPUOpCode_int16[" . $_ . "]"} ;
	$base_stat_tbl->{"Total_EM_Instructions"} += $base_stat_tbl->{"HybridOpCode_fp32[" . $_ . "]"} + $base_stat_tbl->{"HybridOpCode_fp16[" . $_ . "]"} ;
	$base_stat_tbl->{"Total_EM_Instructions"} += $base_stat_tbl->{"HybridOpCode_int32[" . $_ . "]"} + $base_stat_tbl->{"HybridOpCode_int16[" . $_ . "]"} ;
	$base_stat_tbl->{"FPU_SEL_Instructions_FP32"} += $base_stat_tbl->{"FPUOpCode_fp32[" . $_ . "]"} ;
	$base_stat_tbl->{"FPU_SEL_Instructions_FP16"} += $base_stat_tbl->{"FPUOpCode_fp16[" . $_ . "]"} ;
	$base_stat_tbl->{"FPU_SEL_Instructions_INT32"} += $base_stat_tbl->{"FPUOpCode_int32[" . $_ . "]"} ;
	$base_stat_tbl->{"FPU_SEL_Instructions_INT16"} += $base_stat_tbl->{"FPUOpCode_int16[" . $_ . "]"} ;
	$base_stat_tbl->{"EM_SEL_Instructions_FP32"} += $base_stat_tbl->{"HybridOpCode_fp32[" . $_ . "]"} ;
	$base_stat_tbl->{"EM_SEL_Instructions_FP16"} += $base_stat_tbl->{"HybridOpCode_fp16[" . $_ . "]"} ;
	$base_stat_tbl->{"EM_SEL_Instructions_INT32"} += $base_stat_tbl->{"HybridOpCode_int32[" . $_ . "]"} ;
	$base_stat_tbl->{"EM_SEL_Instructions_INT16"} += $base_stat_tbl->{"HybridOpCode_int16[" . $_ . "]"} ;
}
foreach (@eu_transc_opcodes)
{
	$base_stat_tbl->{"Total_EM_Instructions"} += $base_stat_tbl->{"EMOpCode_fp32[" . $_ . "]"} + $base_stat_tbl->{"EMOpCode_fp16[" . $_ . "]"} ;
	$base_stat_tbl->{"Total_EM_Instructions"} += $base_stat_tbl->{"EMOpCode_int32[" . $_ . "]"} + $base_stat_tbl->{"EMOpCode_int16[" . $_ . "]"} ;
	$base_stat_tbl->{"EM_TRANSC_Instructions_FP32"} += $base_stat_tbl->{"EMOpCode_fp32[" . $_ . "]"} ;
	$base_stat_tbl->{"EM_TRANSC_Instructions_FP16"} += $base_stat_tbl->{"EMOpCode_fp16[" . $_ . "]"} ;
	$base_stat_tbl->{"EM_TRANSC_Instructions_INT32"} += $base_stat_tbl->{"EMOpCode_int32[" . $_ . "]"} ;
	$base_stat_tbl->{"EM_TRANSC_Instructions_INT16"} += $base_stat_tbl->{"EMOpCode_int16[" . $_ . "]"} ;
}

if(($base_stat_tbl->{"FPU_pln_bypass_cnt"} != 0) && (($gen >= 8) || ($vlv >= 5))){
	$base_stat_tbl->{"FPU_pln_bypass"} = $base_stat_tbl->{"FPUOpCode_fp32[90]"} * ($base_stat_tbl->{"FPU_pln_bypass"}/$base_stat_tbl->{"FPU_pln_bypass_cnt"});
}
else{
	$base_stat_tbl->{"FPU_pln_bypass"} = 0;
}
if(($base_stat_tbl->{"FPU_mul_bypass_cnt"} != 0) && (($gen >= 8) || ($vlv >= 5))){
	$base_stat_tbl->{"FPU_mul_bypass"} = $base_stat_tbl->{"FPUOpCode_fp32[65]"} * ($base_stat_tbl->{"FPU_mul_bypass"}/$base_stat_tbl->{"FPU_mul_bypass_cnt"});
}
else{
	$base_stat_tbl->{"FPU_mul_bypass"} = 0;
}
if(($base_stat_tbl->{"FPU_mad_bypass_cnt"} != 0) && (($gen >= 8) || ($vlv >= 5))){
	$base_stat_tbl->{"FPU_mad_bypass"} = $base_stat_tbl->{"FPUOpCode_fp32[91]"} * ($base_stat_tbl->{"FPU_mad_bypass"}/$base_stat_tbl->{"FPU_mad_bypass_cnt"});
}
else{
	$base_stat_tbl->{"FPU_mad_bypass"} = 0;
}
if(($base_stat_tbl->{"FPU_add_bypass_cnt"} != 0) && (($gen >= 8) || ($vlv >= 5))){
	$base_stat_tbl->{"FPU_add_bypass"} = ($base_stat_tbl->{"FPUOpCode_fp32[64]"} + $base_stat_tbl->{"FPUOpCode_fp32[16]"}) * ($base_stat_tbl->{"FPU_add_bypass"}/$base_stat_tbl->{"FPU_add_bypass_cnt"});
}
else{
	$base_stat_tbl->{"FPU_add_bypass"} = 0;
}

if(($base_stat_tbl->{"EM_pln_bypass_cnt"} != 0) && (($gen >= 8) || ($vlv >= 5))){
	$base_stat_tbl->{"EM_pln_bypass"} = $base_stat_tbl->{"HybridOpCode_fp32[90]"} * ($base_stat_tbl->{"EM_pln_bypass"}/$base_stat_tbl->{"EM_pln_bypass_cnt"});
}
else{
	$base_stat_tbl->{"EM_pln_bypass"} = 0;
}
if(($base_stat_tbl->{"EM_mul_bypass_cnt"} != 0) && (($gen >= 8) || ($vlv >= 5))){
	$base_stat_tbl->{"EM_mul_bypass"} = $base_stat_tbl->{"HybridOpCode_fp32[65]"} * ($base_stat_tbl->{"EM_mul_bypass"}/$base_stat_tbl->{"EM_mul_bypass_cnt"});
}
else{
	$base_stat_tbl->{"EM_mul_bypass"} = 0;
}
if(($base_stat_tbl->{"EM_mad_bypass_cnt"} != 0) && (($gen >= 8) || ($vlv >= 5))){
	$base_stat_tbl->{"EM_mad_bypass"} = $base_stat_tbl->{"HybridOpCode_fp32[91]"} * ($base_stat_tbl->{"EM_mad_bypass"}/$base_stat_tbl->{"EM_mad_bypass_cnt"});
}
else{
	$base_stat_tbl->{"EM_mad_bypass"} = 0;
}
if(($base_stat_tbl->{"EM_add_bypass_cnt"} != 0) && (($gen >= 8) || ($vlv >= 5))){
	$base_stat_tbl->{"EM_add_bypass"} = ($base_stat_tbl->{"HybridOpCode_fp32[64]"} + $base_stat_tbl->{"HybridOpCode_fp32[16]"}) * ($base_stat_tbl->{"EM_add_bypass"}/$base_stat_tbl->{"EM_add_bypass_cnt"});
}
else{
	$base_stat_tbl->{"EM_add_bypass"} = 0;
}
	
# $base_stat_tbl->{"Total_FPU_Instructions"} += $base_stat_tbl->{"FPU_pln_bypass"} + $base_stat_tbl->{"FPU_add_bypass"} + $base_stat_tbl->{"FPU_mul_bypass"} + $base_stat_tbl->{"FPU_mad_bypass"} ;
# $base_stat_tbl->{"Total_EM_Instructions"}  += $base_stat_tbl->{"EM_pln_bypass"} + $base_stat_tbl->{"EM_add_bypass"} + $base_stat_tbl->{"EM_mul_bypass"} + $base_stat_tbl->{"EM_mad_bypass"} ;

$formulas->{"FPU_Utilization"} 			= &CalcFPU_Util() ;
$formulas->{"EM_Utilization"} 			= &CalcEM_Util() ;
$formulas->{"EU_Idle"} 					= &CalcEU_Idle() ;

$formulas->{"PS0_EU"} 					= &CalcEU_Idle() ;
$formulas->{"PS2_EU"} 					= &CalcEU_Active() ;
$formulas->{"PS1_EU"} 					= 1 - $formulas->{"PS0_EU"} - $formulas->{"PS2_EU"} ;

$formulas->{"PS0_EU_FPU"} 				= $formulas->{"EU_Idle"} ;
$formulas->{"PS2_EU_FPU"} 				= $formulas->{"FPU_Utilization"} ;
$formulas->{"PS1_EU_FPU"} 				= 1 - $formulas->{"PS0_EU_FPU"} - $formulas->{"PS2_EU_FPU"}  ;

$formulas->{"PS0_EU_EM"} 				= $formulas->{"EU_Idle"} ;
$formulas->{"PS2_EU_EM"} 				= $formulas->{"EM_Utilization"} ;
$formulas->{"PS1_EU_EM"} 				= 1 - $formulas->{"PS0_EU_EM"} - $formulas->{"PS2_EU_EM"}  ;

$formulas->{"PS0_EU_GA"} 				= $formulas->{"PS0_EU"} ;
$formulas->{"PS1_EU_GA"} 				= $formulas->{"PS1_EU"} ;
$formulas->{"PS2_EU_GA"} 				= $formulas->{"PS2_EU"} ;

$formulas->{"PS0_EU_GRF"} 				= $formulas->{"PS0_EU"} ;
$formulas->{"PS1_EU_GRF"} 				= $formulas->{"PS1_EU"} ;
$formulas->{"PS2_EU_GRF"} 				= $formulas->{"PS2_EU"} ;

if($base_stat_tbl->{"Total_FPU_Instructions"} != 0)
{
	$formulas->{"FPU_pln_fp32"}			= ($base_stat_tbl->{"FPU_PLN_Instructions_FP32"} - $base_stat_tbl->{"FPU_pln_bypass"})/$base_stat_tbl->{"Total_FPU_Instructions"} ;
	$formulas->{"FPU_mad_fp32"}			= ($base_stat_tbl->{"FPU_MAD_Instructions_FP32"} - $base_stat_tbl->{"FPU_mad_bypass"})/$base_stat_tbl->{"Total_FPU_Instructions"} ;
	$formulas->{"FPU_mul_fp32"}			= ($base_stat_tbl->{"FPU_MUL_Instructions_FP32"} - $base_stat_tbl->{"FPU_mul_bypass"})/$base_stat_tbl->{"Total_FPU_Instructions"} ;
	$formulas->{"FPU_add_fp32"} 		= ($base_stat_tbl->{"FPU_ADD_Instructions_FP32"} - $base_stat_tbl->{"FPU_add_bypass"})/$base_stat_tbl->{"Total_FPU_Instructions"} ;
	$formulas->{"FPU_mov_fp32"}			= $base_stat_tbl->{"FPU_MOV_Instructions_FP32"}/$base_stat_tbl->{"Total_FPU_Instructions"} ;
	$formulas->{"FPU_sel_fp32"}			= $base_stat_tbl->{"FPU_SEL_Instructions_FP32"}/$base_stat_tbl->{"Total_FPU_Instructions"} ;
	
	$formulas->{"FPU_pln_fp16"}			= $base_stat_tbl->{"FPU_PLN_Instructions_FP16"}/$base_stat_tbl->{"Total_FPU_Instructions"} ;
	$formulas->{"FPU_mad_fp16"}			= $base_stat_tbl->{"FPU_MAD_Instructions_FP16"}/$base_stat_tbl->{"Total_FPU_Instructions"} ;
	$formulas->{"FPU_mul_fp16"}			= $base_stat_tbl->{"FPU_MUL_Instructions_FP16"}/$base_stat_tbl->{"Total_FPU_Instructions"} ;
	$formulas->{"FPU_add_fp16"} 		= $base_stat_tbl->{"FPU_ADD_Instructions_FP16"}/$base_stat_tbl->{"Total_FPU_Instructions"} ;
	$formulas->{"FPU_mov_fp16"}			= $base_stat_tbl->{"FPU_MOV_Instructions_FP16"}/$base_stat_tbl->{"Total_FPU_Instructions"} ;
	$formulas->{"FPU_sel_fp16"}			= $base_stat_tbl->{"FPU_SEL_Instructions_FP16"}/$base_stat_tbl->{"Total_FPU_Instructions"} ;
	
	$formulas->{"FPU_pln_int32"}		= $base_stat_tbl->{"FPU_PLN_Instructions_INT32"}/$base_stat_tbl->{"Total_FPU_Instructions"} ;
	$formulas->{"FPU_mad_int32"}		= $base_stat_tbl->{"FPU_MAD_Instructions_INT32"}/$base_stat_tbl->{"Total_FPU_Instructions"} ;
	$formulas->{"FPU_mul_int32"}		= $base_stat_tbl->{"FPU_MUL_Instructions_INT32"}/$base_stat_tbl->{"Total_FPU_Instructions"} ;
	$formulas->{"FPU_add_int32"}		= $base_stat_tbl->{"FPU_ADD_Instructions_INT32"}/$base_stat_tbl->{"Total_FPU_Instructions"} ;
	$formulas->{"FPU_mov_int32"}		= $base_stat_tbl->{"FPU_MOV_Instructions_INT32"}/$base_stat_tbl->{"Total_FPU_Instructions"} ;
	$formulas->{"FPU_sel_int32"}		= $base_stat_tbl->{"FPU_SEL_Instructions_INT32"}/$base_stat_tbl->{"Total_FPU_Instructions"} ;
	
	$formulas->{"FPU_pln_int16"}		= $base_stat_tbl->{"FPU_PLN_Instructions_INT16"}/$base_stat_tbl->{"Total_FPU_Instructions"} ;
	$formulas->{"FPU_mad_int16"}		= $base_stat_tbl->{"FPU_MAD_Instructions_INT16"}/$base_stat_tbl->{"Total_FPU_Instructions"} ;
	$formulas->{"FPU_mul_int16"}		= $base_stat_tbl->{"FPU_MUL_Instructions_INT16"}/$base_stat_tbl->{"Total_FPU_Instructions"} ;
	$formulas->{"FPU_add_int16"}		= $base_stat_tbl->{"FPU_ADD_Instructions_INT16"}/$base_stat_tbl->{"Total_FPU_Instructions"} ;
	$formulas->{"FPU_mov_int16"}		= $base_stat_tbl->{"FPU_MOV_Instructions_INT16"}/$base_stat_tbl->{"Total_FPU_Instructions"} ;
	$formulas->{"FPU_sel_int16"}		= $base_stat_tbl->{"FPU_SEL_Instructions_INT16"}/$base_stat_tbl->{"Total_FPU_Instructions"} ;
	
	$formulas->{"FPU_pln_bypass"}		= $base_stat_tbl->{"FPU_pln_bypass"}/$base_stat_tbl->{"Total_FPU_Instructions"} ;
	$formulas->{"FPU_add_bypass"}		= $base_stat_tbl->{"FPU_add_bypass"}/$base_stat_tbl->{"Total_FPU_Instructions"} ;
	$formulas->{"FPU_mul_bypass"}		= $base_stat_tbl->{"FPU_mul_bypass"}/$base_stat_tbl->{"Total_FPU_Instructions"} ;
	$formulas->{"FPU_mad_bypass"}		= $base_stat_tbl->{"FPU_mad_bypass"}/$base_stat_tbl->{"Total_FPU_Instructions"} ;
}
else
{
	$formulas->{"FPU_pln_fp32"}			= 0 ;
	$formulas->{"FPU_mad_fp32"}			= 0 ;
	$formulas->{"FPU_mul_fp32"}			= 0 ;
	$formulas->{"FPU_add_fp32"}			= 0 ;
	$formulas->{"FPU_mov_fp32"}			= 0 ;
	$formulas->{"FPU_sel_fp32"}			= 0 ;
	
	$formulas->{"FPU_pln_fp16"}			= 0 ;
	$formulas->{"FPU_mad_fp16"}			= 0 ;
	$formulas->{"FPU_mul_fp16"}			= 0 ;
	$formulas->{"FPU_add_fp16"}			= 0 ;
	$formulas->{"FPU_mov_fp16"}			= 0 ;
	$formulas->{"FPU_sel_fp16"}			= 0 ;
	
	$formulas->{"FPU_pln_int32"}		= 0 ;
	$formulas->{"FPU_mad_int32"}		= 0 ;
	$formulas->{"FPU_mul_int32"}		= 0 ;
	$formulas->{"FPU_add_int32"}		= 0 ;
	$formulas->{"FPU_mov_int32"}		= 0 ;
	$formulas->{"FPU_sel_int32"}		= 0 ;
	
	$formulas->{"FPU_pln_int16"}		= 0 ;
	$formulas->{"FPU_mad_int16"}		= 0 ;
	$formulas->{"FPU_mul_int16"}		= 0 ;
	$formulas->{"FPU_add_int16"}		= 0 ;
	$formulas->{"FPU_mov_int16"}		= 0 ;
	$formulas->{"FPU_sel_int16"}		= 0 ;
	
	$formulas->{"FPU_pln_bypass"}		= 0 ;
	$formulas->{"FPU_add_bypass"}		= 0 ;
	$formulas->{"FPU_mul_bypass"}		= 0 ;
	$formulas->{"FPU_mad_bypass"}		= 0 ;
}

$formulas->{"GA_pln"} 					= $formulas->{"FPU_pln_fp32"} + $formulas->{"FPU_pln_fp16"} + $formulas->{"FPU_pln_int32"} + $formulas->{"FPU_pln_int16"} + $formulas->{"FPU_pln_bypass"} ;
$formulas->{"GA_mad"} 					= $formulas->{"FPU_mad_fp32"} + $formulas->{"FPU_mad_fp16"} + $formulas->{"FPU_mad_int32"} + $formulas->{"FPU_mad_int16"} + $formulas->{"FPU_mad_bypass"} ;
$formulas->{"GA_mul"} 					= $formulas->{"FPU_mul_fp32"} + $formulas->{"FPU_mul_fp16"} + $formulas->{"FPU_mul_int32"} + $formulas->{"FPU_mul_int16"} + $formulas->{"FPU_mul_bypass"} ;
$formulas->{"GA_add"} 					= $formulas->{"FPU_add_fp32"} + $formulas->{"FPU_add_fp16"} + $formulas->{"FPU_add_int32"} + $formulas->{"FPU_add_int16"} + $formulas->{"FPU_add_bypass"} ;
$formulas->{"GA_mov"}			 		= $formulas->{"FPU_mov_fp32"} + $formulas->{"FPU_mov_fp16"} + $formulas->{"FPU_mov_int32"} + $formulas->{"FPU_mov_int16"} ;
$formulas->{"GA_sel"} 					= $formulas->{"FPU_sel_fp32"} + $formulas->{"FPU_sel_fp16"} + $formulas->{"FPU_sel_int32"} + $formulas->{"FPU_sel_int16"} ;
$formulas->{"GA_other"}					= $formulas->{"EM_Utilization"} ;

$formulas->{"PS2_EU_GRF_READ"} 			= ($base_stat_tbl->{"GRFReads"} +  $base_stat_tbl->{"MRFReads"})/$base_stat_tbl->{"GennysimStatClks"} ; 
$formulas->{"PS2_EU_GRF_WRITE"} 		= ($base_stat_tbl->{"GRFWrites"} + $base_stat_tbl->{"MRFWrites"})/$base_stat_tbl->{"GennysimStatClks"} ;

if($base_stat_tbl->{"Total_EM_Instructions"} != 0)
{
	$formulas->{"EM_pln_fp32"}			= ($base_stat_tbl->{"EM_PLN_Instructions_FP32"} - $base_stat_tbl->{"EM_pln_bypass"})/$base_stat_tbl->{"Total_EM_Instructions"} ;
	$formulas->{"EM_mad_fp32"}			= ($base_stat_tbl->{"EM_MAD_Instructions_FP32"} - $base_stat_tbl->{"EM_mad_bypass"})/$base_stat_tbl->{"Total_EM_Instructions"} ;
	$formulas->{"EM_mul_fp32"}			= ($base_stat_tbl->{"EM_MUL_Instructions_FP32"} - $base_stat_tbl->{"EM_mul_bypass"})/$base_stat_tbl->{"Total_EM_Instructions"} ;
	$formulas->{"EM_add_fp32"} 			= ($base_stat_tbl->{"EM_ADD_Instructions_FP32"} - $base_stat_tbl->{"EM_add_bypass"})/$base_stat_tbl->{"Total_EM_Instructions"} ;
	$formulas->{"EM_mov_fp32"}			= $base_stat_tbl->{"EM_MOV_Instructions_FP32"}/$base_stat_tbl->{"Total_EM_Instructions"} ;
	$formulas->{"EM_sel_fp32"}			= $base_stat_tbl->{"EM_SEL_Instructions_FP32"}/$base_stat_tbl->{"Total_EM_Instructions"} ;
	$formulas->{"EM_trans_fp32"}		= $base_stat_tbl->{"EM_TRANSC_Instructions_FP32"}/$base_stat_tbl->{"Total_EM_Instructions"} ;
	
	$formulas->{"EM_pln_fp16"}			= $base_stat_tbl->{"EM_PLN_Instructions_FP16"}/$base_stat_tbl->{"Total_EM_Instructions"} ;
	$formulas->{"EM_mad_fp16"}			= $base_stat_tbl->{"EM_MAD_Instructions_FP16"}/$base_stat_tbl->{"Total_EM_Instructions"} ;
	$formulas->{"EM_mul_fp16"}			= $base_stat_tbl->{"EM_MUL_Instructions_FP16"}/$base_stat_tbl->{"Total_EM_Instructions"} ;
	$formulas->{"EM_add_fp16"} 			= $base_stat_tbl->{"EM_ADD_Instructions_FP16"}/$base_stat_tbl->{"Total_EM_Instructions"} ;
	$formulas->{"EM_mov_fp16"}			= $base_stat_tbl->{"EM_MOV_Instructions_FP16"}/$base_stat_tbl->{"Total_EM_Instructions"} ;
	$formulas->{"EM_sel_fp16"}			= $base_stat_tbl->{"EM_SEL_Instructions_FP16"}/$base_stat_tbl->{"Total_EM_Instructions"} ;
	$formulas->{"EM_trans_fp16"}		= $base_stat_tbl->{"EM_TRANSC_Instructions_FP16"}/$base_stat_tbl->{"Total_EM_Instructions"} ;
	
	$formulas->{"EM_pln_int32"}			= $base_stat_tbl->{"EM_PLN_Instructions_INT32"}/$base_stat_tbl->{"Total_EM_Instructions"} ;
	$formulas->{"EM_mad_int32"}			= $base_stat_tbl->{"EM_MAD_Instructions_INT32"}/$base_stat_tbl->{"Total_EM_Instructions"} ;
	$formulas->{"EM_mul_int32"}			= $base_stat_tbl->{"EM_MUL_Instructions_INT32"}/$base_stat_tbl->{"Total_EM_Instructions"} ;
	$formulas->{"EM_add_int32"}			= $base_stat_tbl->{"EM_ADD_Instructions_INT32"}/$base_stat_tbl->{"Total_EM_Instructions"} ;
	$formulas->{"EM_mov_int32"}			= $base_stat_tbl->{"EM_MOV_Instructions_INT32"}/$base_stat_tbl->{"Total_EM_Instructions"} ;
	$formulas->{"EM_sel_int32"}			= $base_stat_tbl->{"EM_SEL_Instructions_INT32"}/$base_stat_tbl->{"Total_EM_Instructions"} ;
	$formulas->{"EM_trans_int32"}		= $base_stat_tbl->{"EM_TRANSC_Instructions_INT16"}/$base_stat_tbl->{"Total_EM_Instructions"} ;
	
	$formulas->{"EM_pln_int16"}			= $base_stat_tbl->{"EM_PLN_Instructions_INT16"}/$base_stat_tbl->{"Total_EM_Instructions"} ;
	$formulas->{"EM_mad_int16"}			= $base_stat_tbl->{"EM_MAD_Instructions_INT16"}/$base_stat_tbl->{"Total_EM_Instructions"} ;
	$formulas->{"EM_mul_int16"}			= $base_stat_tbl->{"EM_MUL_Instructions_INT16"}/$base_stat_tbl->{"Total_EM_Instructions"} ;
	$formulas->{"EM_add_int16"}			= $base_stat_tbl->{"EM_ADD_Instructions_INT16"}/$base_stat_tbl->{"Total_EM_Instructions"} ;
	$formulas->{"EM_mov_int16"}			= $base_stat_tbl->{"EM_MOV_Instructions_INT16"}/$base_stat_tbl->{"Total_EM_Instructions"} ;
	$formulas->{"EM_sel_int16"}			= $base_stat_tbl->{"EM_SEL_Instructions_INT16"}/$base_stat_tbl->{"Total_EM_Instructions"} ;
	$formulas->{"EM_trans_int16"}		= $base_stat_tbl->{"EM_TRANSC_Instructions_INT16"}/$base_stat_tbl->{"Total_EM_Instructions"} ;
	
	$formulas->{"EM_pln_bypass"}		= $base_stat_tbl->{"EM_pln_bypass"}/$base_stat_tbl->{"Total_EM_Instructions"} ;
	$formulas->{"EM_add_bypass"}		= $base_stat_tbl->{"EM_add_bypass"}/$base_stat_tbl->{"Total_EM_Instructions"} ;
	$formulas->{"EM_mul_bypass"}		= $base_stat_tbl->{"EM_mul_bypass"}/$base_stat_tbl->{"Total_EM_Instructions"} ;
	$formulas->{"EM_mad_bypass"}		= $base_stat_tbl->{"EM_mad_bypass"}/$base_stat_tbl->{"Total_EM_Instructions"} ;
}
else
{
	$formulas->{"EM_pln_fp32"}			= 0 ;
	$formulas->{"EM_mad_fp32"}			= 0 ;
	$formulas->{"EM_mul_fp32"}			= 0 ;
	$formulas->{"EM_add_fp32"}			= 0 ;
	$formulas->{"EM_mov_fp32"}			= 0 ;
	$formulas->{"EM_sel_fp32"}			= 0 ;
	$formulas->{"EM_trans_fp32"}		= 0 ;
	
	$formulas->{"EM_pln_fp16"}			= 0 ;
	$formulas->{"EM_mad_fp16"}			= 0 ;
	$formulas->{"EM_mul_fp16"}			= 0 ;
	$formulas->{"EM_add_fp16"}			= 0 ;
	$formulas->{"EM_mov_fp16"}			= 0 ;
	$formulas->{"EM_sel_fp16"}			= 0 ;
	$formulas->{"EM_trans_fp16"}		= 0 ;
	
	$formulas->{"EM_pln_int32"}			= 0 ;
	$formulas->{"EM_mad_int32"}			= 0 ;
	$formulas->{"EM_mul_int32"}			= 0 ;
	$formulas->{"EM_add_int32"}			= 0 ;
	$formulas->{"EM_mov_int32"}			= 0 ;
	$formulas->{"EM_sel_int32"}			= 0 ;
	$formulas->{"EM_trans_int32"}		= 0 ;
	
	$formulas->{"EM_pln_int16"}			= 0 ;
	$formulas->{"EM_mad_int16"}			= 0 ;
	$formulas->{"EM_mul_int16"}			= 0 ;
	$formulas->{"EM_add_int16"}			= 0 ;
	$formulas->{"EM_mov_int16"}			= 0 ;
	$formulas->{"EM_sel_int16"}			= 0 ;
	$formulas->{"EM_trans_int32"}		= 0 ;
	
	$formulas->{"EM_pln_bypass"}		= 0 ;
	$formulas->{"EM_add_bypass"}		= 0 ;
	$formulas->{"EM_mul_bypass"}		= 0 ;
	$formulas->{"EM_mad_bypass"}		= 0 ;
}

$formulas->{"PS0_EU_TC"} 				= $formulas->{"PS0_EU"} ;
$formulas->{"PS1_EU_TC"} 				= $formulas->{"PS1_EU"} ;
$formulas->{"PS2_EU_TC"} 				= $formulas->{"PS2_EU"} ;

$formulas->{"PS0_EU_Other"}				= $formulas->{"PS0_EU"} ;
$formulas->{"PS1_EU_Other"} 			= $formulas->{"PS1_EU"} ;
$formulas->{"PS2_EU_Other"} 			= $formulas->{"PS2_EU"} ;

$formulas->{"PS0_EU_Glue"} 				= $formulas->{"PS0_EU"} ;
$formulas->{"PS1_EU_Glue"} 				= $formulas->{"PS1_EU"} ;
$formulas->{"PS2_EU_Glue"} 				= $formulas->{"PS2_EU"} ;

$formulas->{"FPU_SRC_ToggleRate"}		= &CalcFPU_toggle() ;
$formulas->{"EM_SRC_ToggleRate"}		= &CalcEM_toggle() ;
$formulas->{"EU_SRC_ToggleRate"}		= &CalcEU_toggle() ;

my @derived_stat_names = sort keys %{$formulas};

foreach my $d (@derived_stat_names)
{
	$derived_stat_tbl->{$d} = $formulas->{$d} ;
}

if($derived_stat_tbl->{"EU_SRC_ToggleRate"} == 0)
{
	$derived_stat_tbl->{"FPU_SRC_ToggleRate"} = 0.25 ;
	$derived_stat_tbl->{"EM_SRC_ToggleRate"}  = 0.25 ;
	$derived_stat_tbl->{"EU_SRC_ToggleRate"}  = 0.25 ;
}

#####################################################
# Printing out stats unit-wise
#####################################################
my $count = 0 ;

open(FP, '>' . $odir . 'eu_alps1_1.csv');
print FP"Power Stat,Residency\n";

foreach  my $unit ("FPU_Utilization","EM_Utilization","EU_Idle","EU","FPU","GA","EM","GRF","FPU_pln_fp32","FPU_mad_fp32","FPU_mul_fp32","FPU_add_fp32","FPU_mov_fp32","FPU_sel_fp32","FPU_pln_fp16","FPU_mad_fp16","FPU_mul_fp16","FPU_add_fp16","FPU_mov_fp16","FPU_sel_fp16","FPU_pln_int32","FPU_mad_int32","FPU_mul_int32","FPU_add_int32","FPU_mov_int32","FPU_sel_int32","FPU_pln_int16","FPU_mad_int16","FPU_mul_int16","FPU_add_int16","FPU_mov_int16","FPU_sel_int16","FPU_pln_bypass","FPU_add_bypass","FPU_mul_bypass","FPU_mad_bypass","GA_pln","GA_mad","GA_mul","GA_add","GA_mov","GA_sel","GA_other","EM_trans_fp32","EM_pln_fp32","EM_mad_fp32","EM_mul_fp32","EM_add_fp32","EM_mov_fp32","EM_sel_fp32","EM_trans_fp16","EM_pln_fp16","EM_mad_fp16","EM_mul_fp16","EM_add_fp16","EM_mov_fp16","EM_sel_fp16","EM_trans_int32","EM_pln_int32","EM_mad_int32","EM_mul_int32","EM_add_int32","EM_mov_int32","EM_sel_int32","EM_trans_int16","EM_pln_int16","EM_mad_int16","EM_mul_int16","EM_add_int16","EM_mov_int16","EM_sel_int16","EM_pln_bypass","EM_add_bypass","EM_mul_bypass","EM_mad_bypass","PS2_EU_GRF_READ","PS2_EU_GRF_WRITE","TC","Other","Glue","EU_SRC_ToggleRate","FPU_SRC_ToggleRate","EM_SRC_ToggleRate")
{
    for($count=0; $count <= $#derived_stat_names; $count++)
	{
		if($unit eq "EU")
		{
			if($derived_stat_names[$count] =~ m/PS(.*?)\_$unit$/i)
			{
				print FP"$derived_stat_names[$count],$derived_stat_tbl->{$derived_stat_names[$count]}\n" ; 
			}
		}
		elsif($unit eq "FPU" || $unit eq "GA" || $unit eq "EM" || $unit eq "GRF" || $unit eq "TC" || $unit eq "Other" || $unit eq "Glue")
		{
			if($derived_stat_names[$count] =~ m/PS(.*?)\_EU\_$unit$/i)
			{
				print FP"$derived_stat_names[$count],$derived_stat_tbl->{$derived_stat_names[$count]}\n" ; 
			}
		}
		else
		{
			if($derived_stat_names[$count] =~ m/$unit$/i)
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
   
   # AVERAGEDIV1 averages the value across all the stats whose names match the regex.
   # (Should be the only average you need; the more general form was a hack for AMX
   # that I'd probably do differently, in hindsight.) 
   
   push (@$lrSimData, {
         'Name' => 'FPUBusyClksSum',
         'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.SIMD4_Executed_0',
                                              'm_ReportDataAs' => 'SUM',
                                              'm_DoTestMaxVal' => 0})
   });
   
   push (@$lrSimData, {
         'Name' => 'Num_EU',
         'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.SIMD4_Executed_0',
                                              'm_ReportDataAs' => 'LASTNAMENORMAL',
                                              'm_DoTestMaxVal' => 0})
   });
   
   push (@$lrSimData, {
         'Name' => 'FPUBusyClks',
         'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.SIMD4_Executed_0',
                                              'm_ReportDataAs' => 'AVERAGEDIV1',
                                              'm_DoTestMaxVal' => 0})
   });
   
   push (@$lrSimData, {
         'Name' => 'EMBusyClks',
         'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.SIMD4_Executed_1',
                                              'm_ReportDataAs' => 'AVERAGEDIV1',
                                              'm_DoTestMaxVal' => 0})
   });
   
   push (@$lrSimData, {
			 'Name' => 'uCore_idle',
			 'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.power_fub\.idle',
												  'm_ReportDataAs' => 'AVERAGEDIV1',
												  'm_DoTestMaxVal' => 0})
	   });
   
   my $media_int32 = '';
   my $media_int16 = '';
   if($k_media eq '')
   {
		$media_int32 = 'INT32';
		$media_int16 = 'INT(8|16)';
   }
   else
   {
		$media_int32 = 'INT_32' ;
		$media_int16 = 'INT_(8|16)';
   }
   
   foreach my $d (@eu_pln_opcodes)
   {
	   push (@$lrSimData, {
			 'Name' => 'FPUOpCode_fp32[' .$d . ']',
			 'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.Pipe_SIMD4_0_' . '(SP|DP)' . '_' . $d . '$',
												  'm_ReportDataAs' => 'SUM',
												  'm_DoTestMaxVal' => 0})
	   });
	   
	   push (@$lrSimData, {
			 'Name' => 'FPUOpCode_fp16[' .$d . ']',
			 'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.Pipe_SIMD4_0_' . '(SP|DP)' . '_(16|8)_' . $d . '$',
												  'm_ReportDataAs' => 'SUM',
												  'm_DoTestMaxVal' => 0})
	   });
	   
	   push (@$lrSimData, {
			 'Name' => 'FPUOpCode_int32[' .$d . ']',
			 'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.Pipe_SIMD4_0_' . $media_int32 . '_' . $d . '$',
												  'm_ReportDataAs' => 'SUM',
												  'm_DoTestMaxVal' => 0})
	   });
	   
	   push (@$lrSimData, {
			 'Name' => 'FPUOpCode_int16[' .$d . ']',
			 'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.Pipe_SIMD4_0_' . $media_int16 . '_' . $d . '$',
												  'm_ReportDataAs' => 'SUM',
												  'm_DoTestMaxVal' => 0})
	   });
	   
	   push (@$lrSimData, {
			 'Name' => 'HybridOpCode_fp32[' .$d . ']',
			 'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.Pipe_SIMD4_1_' . '(SP|DP)' . '_' . $d . '$',
												  'm_ReportDataAs' => 'SUM',
												  'm_DoTestMaxVal' => 0})
	   });
	   
	   push (@$lrSimData, {
			 'Name' => 'HybridOpCode_fp16[' .$d . ']',
			 'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.Pipe_SIMD4_1_' . '(SP|DP)' . '_(16|8)_' . $d . '$',
												  'm_ReportDataAs' => 'SUM',
												  'm_DoTestMaxVal' => 0})
	   });
	   
	   push (@$lrSimData, {
			 'Name' => 'HybridOpCode_int32[' .$d . ']',
			 'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.Pipe_SIMD4_1_' . $media_int32 . '_' . $d . '$',
												  'm_ReportDataAs' => 'SUM',
												  'm_DoTestMaxVal' => 0})
	   });
	   
	   push (@$lrSimData, {
			 'Name' => 'HybridOpCode_int16[' .$d . ']',
			 'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.Pipe_SIMD4_1_' . $media_int16 . '_' . $d . '$',
												  'm_ReportDataAs' => 'SUM',
												  'm_DoTestMaxVal' => 0})
	   });
   }

   foreach my $d (@eu_mad_opcodes)
   {
	   push (@$lrSimData, {
			 'Name' => 'FPUOpCode_fp32[' .$d . ']',
			 'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.Pipe_SIMD4_0_' . '(SP|DP)' . '_' . $d . '$',
												  'm_ReportDataAs' => 'SUM',
												  'm_DoTestMaxVal' => 0})
	   });
	   
	   push (@$lrSimData, {
			 'Name' => 'FPUOpCode_fp16[' .$d . ']',
			 'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.Pipe_SIMD4_0_' . '(SP|DP)' . '_(16|8)_' . $d . '$',
												  'm_ReportDataAs' => 'SUM',
												  'm_DoTestMaxVal' => 0})
	   });
	   
	   push (@$lrSimData, {
			 'Name' => 'FPUOpCode_int32[' .$d . ']',
			 'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.Pipe_SIMD4_0_' . $media_int32 . '_' . $d . '$',
												  'm_ReportDataAs' => 'SUM',
												  'm_DoTestMaxVal' => 0})
	   });
	   
	   push (@$lrSimData, {
			 'Name' => 'FPUOpCode_int16[' .$d . ']',
			 'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.Pipe_SIMD4_0_' . $media_int16 . '_' . $d . '$',
												  'm_ReportDataAs' => 'SUM',
												  'm_DoTestMaxVal' => 0})
	   });
	   
	   push (@$lrSimData, {
			 'Name' => 'HybridOpCode_fp32[' .$d . ']',
			 'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.Pipe_SIMD4_1_' . '(SP|DP)' . '_' . $d . '$',
												  'm_ReportDataAs' => 'SUM',
												  'm_DoTestMaxVal' => 0})
	   });
	   
	   push (@$lrSimData, {
			 'Name' => 'HybridOpCode_fp16[' .$d . ']',
			 'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.Pipe_SIMD4_1_' . '(SP|DP)' . '_(16|8)_' . $d . '$',
												  'm_ReportDataAs' => 'SUM',
												  'm_DoTestMaxVal' => 0})
	   });
	   
	   push (@$lrSimData, {
			 'Name' => 'HybridOpCode_int32[' .$d . ']',
			 'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.Pipe_SIMD4_1_' . $media_int32 . '_' . $d . '$',
												  'm_ReportDataAs' => 'SUM',
												  'm_DoTestMaxVal' => 0})
	   });
	   
	   push (@$lrSimData, {
			 'Name' => 'HybridOpCode_int16[' .$d . ']',
			 'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.Pipe_SIMD4_1_' . $media_int16 . '_' . $d . '$',
												  'm_ReportDataAs' => 'SUM',
												  'm_DoTestMaxVal' => 0})
	   });
   }
   
   foreach my $d (@eu_mul_opcodes)
   {
	   push (@$lrSimData, {
			 'Name' => 'FPUOpCode_fp32[' .$d . ']',
			 'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.Pipe_SIMD4_0_' . '(SP|DP)' . '_' . $d . '$',
												  'm_ReportDataAs' => 'SUM',
												  'm_DoTestMaxVal' => 0})
	   });
	   
	   push (@$lrSimData, {
			 'Name' => 'FPUOpCode_fp16[' .$d . ']',
			 'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.Pipe_SIMD4_0_' . '(SP|DP)' . '_(16|8)_' . $d . '$',
												  'm_ReportDataAs' => 'SUM',
												  'm_DoTestMaxVal' => 0})
	   });
	   
	   push (@$lrSimData, {
			 'Name' => 'FPUOpCode_int32[' .$d . ']',
			 'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.Pipe_SIMD4_0_' . $media_int32 . '_' . $d . '$',
												  'm_ReportDataAs' => 'SUM',
												  'm_DoTestMaxVal' => 0})
	   });
	   
	   push (@$lrSimData, {
			 'Name' => 'FPUOpCode_int16[' .$d . ']',
			 'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.Pipe_SIMD4_0_' . $media_int16 . '_' . $d . '$',
												  'm_ReportDataAs' => 'SUM',
												  'm_DoTestMaxVal' => 0})
	   });
	   
	   push (@$lrSimData, {
			 'Name' => 'HybridOpCode_fp32[' .$d . ']',
			 'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.Pipe_SIMD4_1_' . '(SP|DP)' . '_' . $d . '$',
												  'm_ReportDataAs' => 'SUM',
												  'm_DoTestMaxVal' => 0})
	   });
	   
	   push (@$lrSimData, {
			 'Name' => 'HybridOpCode_fp16[' .$d . ']',
			 'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.Pipe_SIMD4_1_' . '(SP|DP)' . '_(16|8)_' . $d . '$',
												  'm_ReportDataAs' => 'SUM',
												  'm_DoTestMaxVal' => 0})
	   });
	   
	   push (@$lrSimData, {
			 'Name' => 'HybridOpCode_int32[' .$d . ']',
			 'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.Pipe_SIMD4_1_' . $media_int32 . '_' . $d . '$',
												  'm_ReportDataAs' => 'SUM',
												  'm_DoTestMaxVal' => 0})
	   });
	   
	   push (@$lrSimData, {
			 'Name' => 'HybridOpCode_int16[' .$d . ']',
			 'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.Pipe_SIMD4_1_' . $media_int16 . '_' . $d . '$',
												  'm_ReportDataAs' => 'SUM',
												  'm_DoTestMaxVal' => 0})
	   });
   }
   
   foreach my $d (@eu_add_opcodes)
   {
	   push (@$lrSimData, {
			 'Name' => 'FPUOpCode_fp32[' .$d . ']',
			 'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.Pipe_SIMD4_0_' . '(SP|DP)' . '_' . $d . '$',
												  'm_ReportDataAs' => 'SUM',
												  'm_DoTestMaxVal' => 0})
	   });
	   
	   push (@$lrSimData, {
			 'Name' => 'FPUOpCode_fp16[' .$d . ']',
			 'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.Pipe_SIMD4_0_' . '(SP|DP)' . '_(16|8)_' . $d . '$',
												  'm_ReportDataAs' => 'SUM',
												  'm_DoTestMaxVal' => 0})
	   });
	   
	   push (@$lrSimData, {
			 'Name' => 'FPUOpCode_int32[' .$d . ']',
			 'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.Pipe_SIMD4_0_' . $media_int32 . '_' . $d . '$',
												  'm_ReportDataAs' => 'SUM',
												  'm_DoTestMaxVal' => 0})
	   });
	   
	   push (@$lrSimData, {
			 'Name' => 'FPUOpCode_int16[' .$d . ']',
			 'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.Pipe_SIMD4_0_' . $media_int16 . '_' . $d . '$',
												  'm_ReportDataAs' => 'SUM',
												  'm_DoTestMaxVal' => 0})
	   });
	   
	   push (@$lrSimData, {
			 'Name' => 'HybridOpCode_fp32[' .$d . ']',
			 'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.Pipe_SIMD4_1_' . '(SP|DP)' . '_' . $d . '$',
												  'm_ReportDataAs' => 'SUM',
												  'm_DoTestMaxVal' => 0})
	   });
	   
	   push (@$lrSimData, {
			 'Name' => 'HybridOpCode_fp16[' .$d . ']',
			 'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.Pipe_SIMD4_1_' . '(SP|DP)' . '_(16|8)_' . $d . '$',
												  'm_ReportDataAs' => 'SUM',
												  'm_DoTestMaxVal' => 0})
	   });
	   
	   push (@$lrSimData, {
			 'Name' => 'HybridOpCode_int32[' .$d . ']',
			 'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.Pipe_SIMD4_1_' . $media_int32 . '_' . $d . '$',
												  'm_ReportDataAs' => 'SUM',
												  'm_DoTestMaxVal' => 0})
	   });
	   
	   push (@$lrSimData, {
			 'Name' => 'HybridOpCode_int16[' .$d . ']',
			 'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.Pipe_SIMD4_1_' . $media_int16 . '_' . $d . '$',
												  'm_ReportDataAs' => 'SUM',
												  'm_DoTestMaxVal' => 0})
	   });
   }
   
   foreach my $d (@eu_mov_opcodes)
   {
	   push (@$lrSimData, {
			 'Name' => 'FPUOpCode_fp32[' .$d . ']',
			 'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.Pipe_SIMD4_0_' . '(SP|DP)' . '_' . $d . '$',
												  'm_ReportDataAs' => 'SUM',
												  'm_DoTestMaxVal' => 0})
	   });
	   
	   push (@$lrSimData, {
			 'Name' => 'FPUOpCode_fp16[' .$d . ']',
			 'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.Pipe_SIMD4_0_' . '(SP|DP)' . '_(16|8)_' . $d . '$',
												  'm_ReportDataAs' => 'SUM',
												  'm_DoTestMaxVal' => 0})
	   });
	   
	   push (@$lrSimData, {
			 'Name' => 'FPUOpCode_int32[' .$d . ']',
			 'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.Pipe_SIMD4_0_' . $media_int32 . '_' . $d . '$',
												  'm_ReportDataAs' => 'SUM',
												  'm_DoTestMaxVal' => 0})
	   });
	   
	   push (@$lrSimData, {
			 'Name' => 'FPUOpCode_int16[' .$d . ']',
			 'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.Pipe_SIMD4_0_' . $media_int16 . '_' . $d . '$',
												  'm_ReportDataAs' => 'SUM',
												  'm_DoTestMaxVal' => 0})
	   });
	   
	   push (@$lrSimData, {
			 'Name' => 'HybridOpCode_fp32[' .$d . ']',
			 'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.Pipe_SIMD4_1_' . '(SP|DP)' . '_' . $d . '$',
												  'm_ReportDataAs' => 'SUM',
												  'm_DoTestMaxVal' => 0})
	   });
	   
	   push (@$lrSimData, {
			 'Name' => 'HybridOpCode_fp16[' .$d . ']',
			 'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.Pipe_SIMD4_1_' . '(SP|DP)' . '_(16|8)_' . $d . '$',
												  'm_ReportDataAs' => 'SUM',
												  'm_DoTestMaxVal' => 0})
	   });
	   
	   push (@$lrSimData, {
			 'Name' => 'HybridOpCode_int32[' .$d . ']',
			 'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.Pipe_SIMD4_1_' . $media_int32 . '_' . $d . '$',
												  'm_ReportDataAs' => 'SUM',
												  'm_DoTestMaxVal' => 0})
	   });
	   
	   push (@$lrSimData, {
			 'Name' => 'HybridOpCode_int16[' .$d . ']',
			 'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.Pipe_SIMD4_1_' . $media_int16 . '_' . $d . '$',
												  'm_ReportDataAs' => 'SUM',
												  'm_DoTestMaxVal' => 0})
	   });
   }
   
   foreach my $d (@eu_sel_opcodes)
   {
	   push (@$lrSimData, {
			 'Name' => 'FPUOpCode_fp32[' .$d . ']',
			 'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.Pipe_SIMD4_0_' . '(SP|DP)' . '_' . $d . '$',
												  'm_ReportDataAs' => 'SUM',
												  'm_DoTestMaxVal' => 0})
	   });
	   
	   push (@$lrSimData, {
			 'Name' => 'FPUOpCode_fp16[' .$d . ']',
			 'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.Pipe_SIMD4_0_' . '(SP|DP)' . '_(16|8)_' . $d . '$',
												  'm_ReportDataAs' => 'SUM',
												  'm_DoTestMaxVal' => 0})
	   });
	   
	   push (@$lrSimData, {
			 'Name' => 'FPUOpCode_int32[' .$d . ']',
			 'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.Pipe_SIMD4_0_' . $media_int32 . '_' . $d . '$',
												  'm_ReportDataAs' => 'SUM',
												  'm_DoTestMaxVal' => 0})
	   });
	   
	   push (@$lrSimData, {
			 'Name' => 'FPUOpCode_int16[' .$d . ']',
			 'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.Pipe_SIMD4_0_' . $media_int16 . '_' . $d . '$',
												  'm_ReportDataAs' => 'SUM',
												  'm_DoTestMaxVal' => 0})
	   });
	   
	   push (@$lrSimData, {
			 'Name' => 'HybridOpCode_fp32[' .$d . ']',
			 'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.Pipe_SIMD4_1_' . '(SP|DP)' . '_' . $d . '$',
												  'm_ReportDataAs' => 'SUM',
												  'm_DoTestMaxVal' => 0})
	   });
	   
	   push (@$lrSimData, {
			 'Name' => 'HybridOpCode_fp16[' .$d . ']',
			 'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.Pipe_SIMD4_1_' . '(SP|DP)' . '_(16|8)_' . $d . '$',
												  'm_ReportDataAs' => 'SUM',
												  'm_DoTestMaxVal' => 0})
	   });
	   
	   push (@$lrSimData, {
			 'Name' => 'HybridOpCode_int32[' .$d . ']',
			 'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.Pipe_SIMD4_1_' . $media_int32 . '_' . $d . '$',
												  'm_ReportDataAs' => 'SUM',
												  'm_DoTestMaxVal' => 0})
	   });
	   
	   push (@$lrSimData, {
			 'Name' => 'HybridOpCode_int16[' .$d . ']',
			 'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.Pipe_SIMD4_1_' . $media_int16 . '_' . $d . '$',
												  'm_ReportDataAs' => 'SUM',
												  'm_DoTestMaxVal' => 0})
	   });
   }
   
   foreach my $d (@eu_transc_opcodes)
   {
	   push (@$lrSimData, {
			 'Name' => 'EMOpCode_fp32[' .$d . ']',
			 'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.Pipe_SIMD4_1_' . '(SP|DP)' . '_' . $d . '$',
												  'm_ReportDataAs' => 'SUM',
												  'm_DoTestMaxVal' => 0})
	   });
	   
	   push (@$lrSimData, {
			 'Name' => 'EMOpCode_fp16[' .$d . ']',
			 'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.Pipe_SIMD4_1_' . '(SP|DP)' . '_(16|8)_' . $d . '$',
												  'm_ReportDataAs' => 'SUM',
												  'm_DoTestMaxVal' => 0})
	   });
	   
	   push (@$lrSimData, {
			 'Name' => 'EMOpCode_int32[' .$d . ']',
			 'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.Pipe_SIMD4_1_' . $media_int32 . '_' . $d . '$',
												  'm_ReportDataAs' => 'SUM',
												  'm_DoTestMaxVal' => 0})
	   });
	   
	   push (@$lrSimData, {
			 'Name' => 'EMOpCode_int16[' .$d . ']',
			 'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.Pipe_SIMD4_1_' . $media_int16 . '_' . $d . '$',
												  'm_ReportDataAs' => 'SUM',
												  'm_DoTestMaxVal' => 0})
	   });
   }
   
   push (@$lrSimData, {
         'Name' => 'FPU_pln_bypass_cnt',
         'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.EU_BYPASS_PLN_CNT_0$',
                                              'm_ReportDataAs' => 'SUM',
                                              'm_DoTestMaxVal' => 0})
   });
   
   push (@$lrSimData, {
         'Name' => 'FPU_pln_bypass',
         'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.EU_BYPASS_PLN_(OP1_ZERO|OP2_ZERO|DENORM1|DENORM2|EXP49_1|EXP49_2|EXP25_1|EXP25_2|X1_1|X1_2)_0$',
                                              'm_ReportDataAs' => 'SUM',
                                              'm_DoTestMaxVal' => 0})
   });
   
   push (@$lrSimData, {
         'Name' => 'FPU_add_bypass_cnt',
         'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.EU_BYPASS_(ADD|CMP)_CNT_0$',
                                              'm_ReportDataAs' => 'SUM',
                                              'm_DoTestMaxVal' => 0})
   });
   
   push (@$lrSimData, {
         'Name' => 'FPU_add_bypass',
         'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.EU_BYPASS_(ADD|CMP)_(SIGN_DIFF|EXP_DIFF|OP_ZERO|DENORM|EXP25)_0$',
                                              'm_ReportDataAs' => 'SUM',
                                              'm_DoTestMaxVal' => 0})
   });
   
   push (@$lrSimData, {
         'Name' => 'FPU_mul_bypass_cnt',
         'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.EU_BYPASS_MUL_CNT_0$',
                                              'm_ReportDataAs' => 'SUM',
                                              'm_DoTestMaxVal' => 0})
   });
   
   push (@$lrSimData, {
         'Name' => 'FPU_mul_bypass',
         'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.EU_BYPASS_MUL_(OP_ZERO|DENORM|EXP127|X1)_0$',
                                              'm_ReportDataAs' => 'SUM',
                                              'm_DoTestMaxVal' => 0})
   });
   
   push (@$lrSimData, {
         'Name' => 'FPU_mad_bypass_cnt',
         'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.EU_BYPASS_MAD_CNT_0$',
                                              'm_ReportDataAs' => 'SUM',
                                              'm_DoTestMaxVal' => 0})
   });
   
   push (@$lrSimData, {
         'Name' => 'FPU_mad_bypass',
         'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.EU_BYPASS_MAD_(OP_ZERO|DENORM|EXP49|EXP25|X1)_0$',
                                              'm_ReportDataAs' => 'SUM',
                                              'm_DoTestMaxVal' => 0})
   });
   
   push (@$lrSimData, {
         'Name' => 'EM_pln_bypass_cnt',
         'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.EU_BYPASS_PLN_CNT_1$',
                                              'm_ReportDataAs' => 'SUM',
                                              'm_DoTestMaxVal' => 0})
   });
   
   push (@$lrSimData, {
         'Name' => 'EM_pln_bypass',
         'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.EU_BYPASS_PLN_(OP1_ZERO|OP2_ZERO|DENORM1|DENORM2|EXP49_1|EXP49_2|EXP25_1|EXP25_2|X1_1|X1_2)_1$',
                                              'm_ReportDataAs' => 'SUM',
                                              'm_DoTestMaxVal' => 0})
   });
   
   push (@$lrSimData, {
         'Name' => 'EM_add_bypass_cnt',
         'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.EU_BYPASS_(ADD|CMP)_CNT_1$',
                                              'm_ReportDataAs' => 'SUM',
                                              'm_DoTestMaxVal' => 0})
   });
   
   push (@$lrSimData, {
         'Name' => 'EM_add_bypass',
         'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.EU_BYPASS_(ADD|CMP)_(SIGN_DIFF|EXP_DIFF|OP_ZERO|DENORM|EXP25)_1$',
                                              'm_ReportDataAs' => 'SUM',
                                              'm_DoTestMaxVal' => 0})
   });
   
   push (@$lrSimData, {
         'Name' => 'EM_mul_bypass_cnt',
         'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.EU_BYPASS_MUL_CNT_1$',
                                              'm_ReportDataAs' => 'SUM',
                                              'm_DoTestMaxVal' => 0})
   });
   
   push (@$lrSimData, {
         'Name' => 'EM_mul_bypass',
         'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.EU_BYPASS_MUL_(OP_ZERO|DENORM|EXP127|X1)_1$',
                                              'm_ReportDataAs' => 'SUM',
                                              'm_DoTestMaxVal' => 0})
   });
   
   push (@$lrSimData, {
         'Name' => 'EM_mad_bypass_cnt',
         'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.EU_BYPASS_MAD_CNT_1$',
                                              'm_ReportDataAs' => 'SUM',
                                              'm_DoTestMaxVal' => 0})
   });
   
   push (@$lrSimData, {
         'Name' => 'EM_mad_bypass',
         'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.EU_BYPASS_MAD_(OP_ZERO|DENORM|EXP49|EXP25|X1)_1$',
                                              'm_ReportDataAs' => 'SUM',
                                              'm_DoTestMaxVal' => 0})
   });
   
   foreach my $d ("GRF","MRF")
   {
		push (@$lrSimData, {
			 'Name' => $d . 'Reads',
			 'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.' . $d . 'Read',
												  'm_ReportDataAs' => 'AVERAGEDIV1',
												  'm_DoTestMaxVal' => 0})
	   });
	   
	   push (@$lrSimData, {
			 'Name' => $d . 'Writes',
			 'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_\\d+\\.' . $d . 'Writes',
												  'm_ReportDataAs' => 'AVERAGEDIV1',
												  'm_DoTestMaxVal' => 0})
	   });
   }
}

sub ToggleDataStructure
{
	for(my $i = 0 ; $i < $num_rows ; $i++)
	{
		for(my $j = 0 ; $j < $num_eu ; $j++)
		{
			push (@$ToggleSimData, {
			 'Name' => 'uCore_'. $i . $j . '_GRF_FPU_toggle',
			 'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_' . $i . $j . '\.m_GRF_SIMD4_0_toggles_\d' ,
												  'm_ReportDataAs' => 'MAX',
												  'm_DoTestMaxVal' => 0})
			});
	   
			push (@$ToggleSimData, {
			 'Name' => 'uCore_'. $i . $j . '_GRF_EM_toggle',
			 'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uCore_' . $i . $j . '\.m_GRF_SIMD4_1_toggles_\d' ,
												  'm_ReportDataAs' => 'MAX',
												  'm_DoTestMaxVal' => 0})
			});
		}
	}
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

sub CalcFPU_Util{
	return $base_stat_tbl->{"FPUBusyClks"}/$base_stat_tbl->{"GennysimStatClks"} ;
} ;

sub CalcEM_Util{
	return $base_stat_tbl->{"EMBusyClks"}/$base_stat_tbl->{"GennysimStatClks"} ;
} ;

sub CalcEU_Idle{
	my $numerator = 0 ;
	my $denominator = $base_stat_tbl->{"GennysimStatClks"} ;
	$numerator = $base_stat_tbl->{"uCore_idle"} ;
	return $numerator/$denominator ;
} ;

sub CalcEU_Active{
	if($formulas->{"FPU_Utilization"} > $formulas->{"EM_Utilization"})
	{
		return  $formulas->{"FPU_Utilization"} ;
	}
	return $formulas->{"EM_Utilization"} ;
} ;

sub CalcFPU_toggle{
	my $total = 0 ;
	for(my $i = 0 ; $i < $num_rows ; $i++)
	{
		for(my $j = 0 ; $j < $num_eu ; $j++)
		{
			$total += $base_stat_tbl->{"uCore_" . $i . $j . "_GRF_FPU_toggle"} ;
		}
	}
	
	my $numerator = $total/($num_rows * $num_eu) ;
	my $denominator = $base_stat_tbl->{"FPUBusyClks"} * 128 ;
	return ($numerator/$denominator) ;
} ;

sub CalcEM_toggle{
	my $total = 0 ;
	for(my $i = 0 ; $i < $num_rows ; $i++)
	{
		for(my $j = 0 ; $j < $num_eu ; $j++)
		{
			$total += $base_stat_tbl->{"uCore_" . $i . $j . "_GRF_EM_toggle"} ;
		}
	}
	
	my $numerator = $total/($num_rows * $num_eu) ;
	my $denominator = $base_stat_tbl->{"EMBusyClks"} * 128 ;
	return ($numerator/$denominator) ;
} ;

sub CalcEU_toggle{
	if($formulas->{"FPU_SRC_ToggleRate"} > $formulas->{"EM_SRC_ToggleRate"})
	{
		return $formulas->{"FPU_SRC_ToggleRate"} ;
	}
	return $formulas->{"EM_SRC_ToggleRate"} ;
} ;
	
