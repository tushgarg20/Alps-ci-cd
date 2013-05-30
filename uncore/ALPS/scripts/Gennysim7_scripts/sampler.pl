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
        ["PS0_SVSM",              				"si_idle_cycles"],
        ["PS1_SVSM", 				            "si_active_stalled_cycles"],
        ["PS2_SVSM_ANYPIXELMODE",				"si_active_not_stalled_cycles"],
        ["PS0_SVSM_MTADAPTER",    				"si_idle_cycles"],
        ["PS1_SVSM_MTADAPTER",				    "si_active_stalled_cycles"],
        ["PS2_SVSM_MTADAPTER_ANYPIXELMODE",		"si_active_not_stalled_cycles"],
        ["PS0_SI",				                "si_idle_cycles"],
        ["PS1_SI",								"si_active_stalled_cycles"],
        ["PS2_SI_ANYPIXELMODE",					"si_active_not_stalled_cycles"],
		["PS0_PL",                				"pl_idle_cycles"],
        ["PS1_PL",            				    "pl_active_stalled_cycles"],
        ["PS0_DG",                				"dg_idle_cycles"],
        ["PS1_DG",								"dg_active_stalled_cycles"],
        ["PS0_SC",								"sc_idle_cycles"],
        ["PS1_SC",								"sc_active_stalled_cycles"],
		["PS2_SC_Unorm",						"sc_active_not_stalled_cycles_unorm"],
		["PS0_SC_DataRam_IDLE",					"sc.data_ram.idle_cycles"],
		["PS2_SC_DataRam_READ",					"sc.data_ram.read_cycles"],
		["PS2_SC_DataRam_READ&WRITE",			"sc.data_ram.rdwr_cycles"],
		["PS2_SC_DataRam_WRITE",				"sc.data_ram.write_cycles"],
		["PS0_SC_LatFifo_IDLE",					"sc.fifo.idle_cycles"],
		["PS2_SC_LatFifo_READ",					"sc.fifo.read_cycles"],
		["PS2_SC_LatFifo_WRITE",				"sc.fifo.write_cycles"],
		["PS2_SC_LatFifo_READ&WRITE",			"sc.fifo.rdwr_cycles"],
        ["PS0_FL",								"fl_idle_cycles"],
        ["PS1_FL",   				            "fl_active_stalled_cycles"],
        ["PS2_FL_FASTBILIN",					"fl_fastbilinear_cycles"],
        ["PS2_FL_FastTri", 					    "fl_FastTrilinear_subspans_cycles"],
        ["PS2_FL_FastAniso", 					"fl_FastAniso_subspans_cycles"],
        ["PS0_SO",    					        "so_idle_cycles"],
        ["PS1_SO",    					        "so_active_stalled_cycles"],
        ["PS2_SO_ANYPIXELMODE",                 "so_active_not_stalled_cycles"],
        ["PS0_so_row0_arb",   				    "so_idle_cycles"],
        ["PS1_so_row0_arb",  				    "so_active_stalled_cycles"],
        ["PS2_so_row0_arb", 				    "so_active_not_stalled_cycles"],
        ["PS0_so_row1_arb", 				    "so_idle_cycles"],
        ["PS1_so_row1_arb",  				    "so_active_stalled_cycles"],
        ["PS2_so_row1_arb",  				    "so_active_not_stalled_cycles"],
        ["PS0_FT",           				    "ft_idle_cycles"],
        ["PS1_FT",          				    "ft_active_stalled_cycles"],
		["PS2_FT_Unorm",					    "ft_active_not_stalled_cycles_unorm"],
		["PS0_MT",								"mt_idle_cycles"],
		["PS1_MT",								"mt_active_stalled_cycles"],
		["PS2_MT_Latqput",						"mt_tag_read_cycles"],
		["PS0_MT_DataRam_IDLE",					"mt.data_ram.idle_cycles"],
		["PS2_MT_DataRam_READ",					"mt.data_ram.read_cycles"],
		["PS2_MT_DataRam_WRITE",				"mt.data_ram.write_cycles"],
		["PS2_MT_DataRam_READ&WRITE",			"mt.data_ram.rdwr_cycles"],
		["PS0_MT_TagRam_IDLE",					"mt.tag_ram.idle_cycles"],
		["PS2_MT_TagRam _READ",					"mt.tag_ram.read_cycles"],
		["PS2_MT_TagRam_WRITE",					"mt.tag_ram.write_cycles"],
		["PS2_MT_TagRam_READ&WRITE",			"mt.tag_ram.rdwr_cycles"],
		["PS0_MT_CAM_IDLE",						"mt.cam.idle_cycles"],
		["PS2_MT_CAM_READ",						"mt.cam.read_cycles"],
		["PS2_MT_CAM_WRITE",					"mt.cam.write_cycles"],
		["PS2_MT_CAM_READ&WRITE",				"mt.cam.rdwr_cycles"],
		["PS0_DM",								"dm_idle_cycles"],
		["PS1_DM",								"dm_active_stalled_cycles"],
		["PS2_DM_NotGamma_NotComp",				"dm_active_NotGamma_NotCompressed"],
		["PS2_DM_NotGamma_Comp",				"dm_active_NotGamma_Compressed"],
		["PS2_DM_Gamma_NotComp",				"dm_active_Gamma_NotCompressed"],
		["PS2_DM_Gamma_Comp",					"dm_active_Gamma_Compressed"],
		["PS0_Sampler_Media",					"GennysimStatClks"],
		["PS1_Sampler_Media",					0],
		["PS2_Sampler_Media",					0],
		["PS0_Sampler_Glue",					"GennysimStatClks"],
		["PS1_Sampler_Glue",					0],
		["PS2_Sampler_Glue",					0]
);
	 
foreach my $f (@RATIO_TABLE){
	$formulas->{$f->[0]} = &CalcRatio($f->[1]);
}

$formulas->{"PS2_PL_NOT_ANISO"} = &CalcPS2_PL_NOT_ANISO() ;
$formulas->{"PS2_PL_ANISO"} = &CalcPS2_PL_ANISO() ;

$formulas->{"PS2_DG_FastTri"} = &CalcPS2_DG_FastTri() ;
$formulas->{"PS2_DG_FastAniso"} = &CalcPS2_DG_FastAniso() ;
$formulas->{"PS2_DG_not Aniso2+_FastTri_FastAniso"} = &CalcPS2_DG_not_Aniso2_FastTri_FastAniso() ;
$formulas->{"PS2_DG_Aniso2+way"} = &CalcPS2_DG_Aniso2_way() ;

$formulas->{"PS0_QC"} = &CalcPS0_QC() ;
$formulas->{"PS1_QC"} = &CalcPS1_QC() ;
$formulas->{"PS2_QC_FastTri"} = &CalcPS2_QC_FastTri() ;
$formulas->{"PS2_QC_FastAniso"} = &CalcPS2_QC_FastAniso() ;
$formulas->{"PS2_QC_Unorm"} = &CalcPS2_QC_Unorm() ;
$formulas->{"PS2_QC_Not_Unorm_FastTri_FastAniso"} = &CalcPS2_QC_Not_Unorm_FastTri_FastAniso() ;

$formulas->{"PS2_SC_FASTBILIN"} = &CalcPS2_SC_FastBilin() ;
$formulas->{"PS2_SC_FastTri"} = &CalcPS2_SC_FastTri() ;
$formulas->{"PS2_SC_FastAniso"} = &CalcPS2_SC_FastAniso() ;
$formulas->{"PS2_SC_Not_FASTBILIN_Unorm_FastTri_FastAniso"} = &CalcPS2_SC_Not_FASTBILIN_Unorm_FastTri_FastAniso() ;

$formulas->{"PS2_FL_Not_FASTBILIN_FastTri_FastAniso"} = &CalcPS2_FL_Not_FASTBILIN_FastTri_FastAniso() ;

$formulas->{"PS2_FT_FastTri"} = &CalcPS2_FT_FastTri() ;
$formulas->{"PS2_FT_FastAniso"} = &CalcPS2_FT_FastAniso() ;
$formulas->{"PS2_FT_Not_Unorm_FastTri_FastAniso"} = &CalcPS2_FT_Not_Unorm_FastTri_FastAniso() ;

$formulas->{"PS2_MT_Not_Latqput"} = &CalcMT_Not_Latqput() ;

my @derived_stat_names = sort keys %{$formulas};

foreach my $d (@derived_stat_names)
{
	$derived_stat_tbl->{$d} = $formulas->{$d} ;
}

#####################################################
# Printing out stats unit-wise
#####################################################
my $count = 0 ;

open(FP,' >' . $odir . 'sampler_alps1_1.csv');
print FP"Power Stat,Residency\n";

foreach  my $unit ("SVSM","SVSM_MTADAPTER","SI","PL","DG","QC","SC","SC_DataRam","SC_LatFifo","FL","SO", "so_row0_arb","so_row1_arb", "FT", "MT","MT_DataRam","MT_TagRam","MT_CAM","DM","Sampler_Media", "Sampler_Glue")
{
    for($count=0; $count <= $#derived_stat_names; $count++)
	{
		if($unit eq "so_row0_arb" || $unit eq "so_row1_arb" || $unit eq "Sampler_Media" || $unit eq "Sampler_Glue")
		{
            if($derived_stat_names[$count] =~ m/PS(.*?)\_$unit$/i)
			{
                print FP"$derived_stat_names[$count],$derived_stat_tbl->{$derived_stat_names[$count]}\n";
            }
        }
					
		elsif($unit eq "SVSM" || $unit eq "SVSM_MTADAPTER" || $unit eq "MT" || $unit eq "SO")
		{
            if( ($derived_stat_names[$count] =~ m/PS(.*?)\_$unit$/i) || ($derived_stat_names[$count] =~ m/PS(.*?)\_$unit\_ANYPIXELMODE$/i) || ($derived_stat_names[$count] =~ m/PS(.*?)\_$unit\_Latqput$/i) || ($derived_stat_names[$count] =~ m/PS(.*?)\_$unit\_Not\_Latqput$/i) )
			{
                print FP"$derived_stat_names[$count],$derived_stat_tbl->{$derived_stat_names[$count]}\n";
            }
        }
		elsif($unit eq "SC_DataRam" || $unit eq "SC_LatFifo" || $unit eq "MT_DataRam" || $unit eq "MT_TagRam" || $unit eq "MT_CAM")
		{
			if($derived_stat_names[$count] =~ m/PS(.*?)\_$unit(.*)/i)
			{
				print FP"$derived_stat_names[$count],$derived_stat_tbl->{$derived_stat_names[$count]}\n" ; 
			}
		}
        else
		{
			if($derived_stat_names[$count] =~ m/PS(.*?)\_$unit(.*)/i)
			{
				print FP"$derived_stat_names[$count],$derived_stat_tbl->{$derived_stat_names[$count]}\n" unless(($derived_stat_names[$count] =~ m/Ram/i) || ($derived_stat_names[$count] =~ m/LatFifo/i) || ($derived_stat_names[$count] =~ m/CAM/i)) ; 
			}
        }
    }
}

close(FP);
print "\n";

# map { print "$_,"; } @derived_stat_names;
# print "\n";

# foreach my $f (@derived_stat_names){
    # print $derived_stat_tbl->{$f} . ",";
# }
# print "\n" ;
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
   
   foreach  my $unit ("svsm","si", "pl", "dg", "qc", "sc", "so", "fl", "ft","alloc", "dm")
   {
		if($unit eq "alloc")
		{
			push (@$lrSimData, {
			'Name' => 'mt_idle_cycles',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uMT_\\d+\\.' . $unit . '_idle_cycles\.*',
                                              'm_ReportDataAs' => 'AVERAGEDIV1',
                                              'm_DoTestMaxVal' => 0})
			});
			
			push (@$lrSimData, {
			'Name' => 'mt_active_stalled_cycles',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uMT_\\d+\\.' . $unit . '_active_stalled_cycles\.*',
                                              'm_ReportDataAs' => 'AVERAGEDIV1',
                                              'm_DoTestMaxVal' => 0})
			});
			
			push (@$lrSimData, {
			'Name' => 'mt_active_not_stalled_cycles',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uMT_\\d+\\.' . $unit . '_active_not_stalled_cycles\.*',
                                              'm_ReportDataAs' => 'AVERAGEDIV1',
                                              'm_DoTestMaxVal' => 0})
			});
			
			push (@$lrSimData, {
			'Name' => 'mt_tag_read_cycles',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uMT_\\d+\\.tag_ram_read_cycles\.*',
                                              'm_ReportDataAs' => 'AVERAGEDIV1',
                                              'm_DoTestMaxVal' => 0})
			});
			
			push (@$lrSimData, {
			'Name' => 'mt.tag_ram.read_cycles',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uMT_\\d+\\.tag_ram_read_cycles\.*',
                                              'm_ReportDataAs' => 'AVERAGEDIV1',
                                              'm_DoTestMaxVal' => 0})
			});
			
			push (@$lrSimData, {
			'Name' => 'mt.tag_ram.write_cycles',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uMT_\\d+\\.tag_ram_write_cycles\.*',
                                              'm_ReportDataAs' => 'AVERAGEDIV1',
                                              'm_DoTestMaxVal' => 0})
			});
			
			push (@$lrSimData, {
			'Name' => 'mt.tag_ram.rdwr_cycles',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uMT_\\d+\\.tag_ram_read_write_cycles\.*',
                                              'm_ReportDataAs' => 'AVERAGEDIV1',
                                              'm_DoTestMaxVal' => 0})
			});
			
			push (@$lrSimData, {
			'Name' => 'mt.tag_ram.idle_cycles',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uMT_\\d+\\.tag_ram_idle_cycles\.*',
                                              'm_ReportDataAs' => 'AVERAGEDIV1',
                                              'm_DoTestMaxVal' => 0})
			});
			push (@$lrSimData, {
			'Name' => 'mt.data_ram.read_cycles',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uMT_\\d+\\.data_ram_read_cycles\.*',
                                              'm_ReportDataAs' => 'AVERAGEDIV1',
                                              'm_DoTestMaxVal' => 0})
			});
			
			push (@$lrSimData, {
			'Name' => 'mt.data_ram.write_cycles',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uMT_\\d+\\.data_ram_write_cycles\.*',
                                              'm_ReportDataAs' => 'AVERAGEDIV1',
                                              'm_DoTestMaxVal' => 0})
			});
			
			push (@$lrSimData, {
			'Name' => 'mt.data_ram.rdwr_cycles',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uMT_\\d+\\.data_ram_read_write_cycles\.*',
                                              'm_ReportDataAs' => 'AVERAGEDIV1',
                                              'm_DoTestMaxVal' => 0})
			});
			
			push (@$lrSimData, {
			'Name' => 'mt.data_ram.idle_cycles',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uMT_\\d+\\.data_ram_idle_cycles\.*',
                                              'm_ReportDataAs' => 'AVERAGEDIV1',
                                              'm_DoTestMaxVal' => 0})
			});
			
			push (@$lrSimData, {
			'Name' => 'mt.cam.read_cycles',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uMT_\\d+\\.cam_read_cycles\.*',
                                              'm_ReportDataAs' => 'AVERAGEDIV1',
                                              'm_DoTestMaxVal' => 0})
			});
			
			push (@$lrSimData, {
			'Name' => 'mt.cam.write_cycles',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uMT_\\d+\\.cam_write_cycles\.*',
                                              'm_ReportDataAs' => 'AVERAGEDIV1',
                                              'm_DoTestMaxVal' => 0})
			});
			
			push (@$lrSimData, {
			'Name' => 'mt.cam.rdwr_cycles',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uMT_\\d+\\.cam_read_write_cycles\.*',
                                              'm_ReportDataAs' => 'AVERAGEDIV1',
                                              'm_DoTestMaxVal' => 0})
			});
			
			push (@$lrSimData, {
			'Name' => 'mt.cam.idle_cycles',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uMT_\\d+\\.cam_idle_cycles\.*',
                                              'm_ReportDataAs' => 'AVERAGEDIV1',
                                              'm_DoTestMaxVal' => 0})
			});
		}
		
		else
		{
            push (@$lrSimData, {
			'Name' => $unit . '_idle_cycles',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uSampler_\\d+\\.' . $unit . '_idle_cycles',
                                              'm_ReportDataAs' => 'AVERAGEDIV1',
                                              'm_DoTestMaxVal' => 0})
			});
		    if($unit eq "qc")
            {
				push (@$lrSimData, {
				'Name' => $unit . '_ft_active_stalled_cycles',
				'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uSampler_\\d+\\.' . $unit . '_ft_active_stalled_cycles',
												'm_ReportDataAs' => 'AVERAGEDIV1',
												'm_DoTestMaxVal' => 0})
				});
				push (@$lrSimData, {
				'Name' => $unit . '_sc_active_stalled_cycles',
				'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uSampler_\\d+\\.' . $unit . '_sc_active_stalled_cycles',
												'm_ReportDataAs' => 'AVERAGEDIV1',
												'm_DoTestMaxVal' => 0})
				});
				push (@$lrSimData, {
				'Name' => $unit . '_active_not_stalled_cycles',
				'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uSampler_\\d+\\.' . $unit . '_active_not_stalled_cycles',
												'm_ReportDataAs' => 'AVERAGEDIV1',
												'm_DoTestMaxVal' => 0})
				});
				push (@$lrSimData, {
				'Name' => $unit . '_active_not_stalled_cycles_unorm',
				'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uSampler_\\d+\\.' . $unit . '_active_not_stalled_cycles_unorm_cycles',
												'm_ReportDataAs' => 'AVERAGEDIV1',
												'm_DoTestMaxVal' => 0})
				});
            }
            else
            {
				push (@$lrSimData, {
				'Name' => $unit . '_active_stalled_cycles',
				'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uSampler_\\d+\\.' . $unit . '_active_stalled_cycles',
												'm_ReportDataAs' => 'AVERAGEDIV1',
												'm_DoTestMaxVal' => 0})
				});	
				
				push (@$lrSimData, {
				'Name' => $unit . '_active_not_stalled_cycles',
				'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uSampler_\\d+\\.' . $unit . '_active_not_stalled_cycles',
												'm_ReportDataAs' => 'AVERAGEDIV1',
												'm_DoTestMaxVal' => 0})
				});
            }
        }
		
		if($unit eq "dm"){
			push (@$lrSimData, {
			'Name' => 'dm_active_NotGamma_Compressed',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uSampler_\\d+\\.dm_active_NotGamma_Compressed',
											'm_ReportDataAs' => 'AVERAGEDIV1',
											'm_DoTestMaxVal' => 0})
			});
			push (@$lrSimData, {
			'Name' => 'dm_active_Gamma_NotCompressed',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uSampler_\\d+\\.dm_active_Gamma_NotCompressed',
											'm_ReportDataAs' => 'AVERAGEDIV1',
											'm_DoTestMaxVal' => 0})
			});
			push (@$lrSimData, {
			'Name' => 'dm_active_NotGamma_NotCompressed',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uSampler_\\d+\\.dm_active_NotGamma_NotCompressed',
											'm_ReportDataAs' => 'AVERAGEDIV1',
											'm_DoTestMaxVal' => 0})
			});
			push (@$lrSimData, {
			'Name' => 'dm_active_Gamma_Compressed',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uSampler_\\d+\\.dm_active_Gamma_Compressed',
											'm_ReportDataAs' => 'AVERAGEDIV1',
											'm_DoTestMaxVal' => 0})
			});
		}
		
		if($unit eq "fl"){
			push (@$lrSimData, {
			'Name' => 'fl_SampleCAniso_subspans_cycles',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uSampler_\\d+\\.fl_SampleCAniso_subspans_cycles',
											'm_ReportDataAs' => 'AVERAGEDIV1',
											'm_DoTestMaxVal' => 0})
			});
			push (@$lrSimData, {
			'Name' => 'fl_Aniso_subspans_cycles',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uSampler_\\d+\\.fl_Aniso_subspans_cycles',
											'm_ReportDataAs' => 'AVERAGEDIV1',
											'm_DoTestMaxVal' => 0})
			});
			push (@$lrSimData, {
			'Name' => 'fl_FastTrilinear_subspans_cycles',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uSampler_\\d+\\.fl_FastTrilinear_subspans_cycles',
											'm_ReportDataAs' => 'AVERAGEDIV1',
											'm_DoTestMaxVal' => 0})
			});
			push (@$lrSimData, {
			'Name' => 'fl_FastAniso_subspans_cycles',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uSampler_\\d+\\.fl_FastAniso_subspans_cycles',
											'm_ReportDataAs' => 'AVERAGEDIV1',
											'm_DoTestMaxVal' => 0})
			});
			push (@$lrSimData, {
			'Name' => 'fl_fastbilinear_cycles',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uSampler_\\d+\\.fl_fastbilinear_cycles',
											'm_ReportDataAs' => 'AVERAGEDIV1',
											'm_DoTestMaxVal' => 0})
			});
		}
		
		if($unit eq "sc")
		{
			push (@$lrSimData, {
			'Name' => $unit . '_active_not_stalled_cycles_unorm',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uSampler_\\d+\\.' . $unit . '_active_not_stalled_cycles_unorm_cycles',
											'm_ReportDataAs' => 'AVERAGEDIV1',
											'm_DoTestMaxVal' => 0})
			});
			push (@$lrSimData, {
			'Name' => $unit . '.fifo.idle_cycles',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uSampler_\\d+\\.' . $unit . '_fifo_idle_cycles',
                                              'm_ReportDataAs' => 'AVERAGEDIV1',
                                              'm_DoTestMaxVal' => 0})
			});
			
			push (@$lrSimData, {
			'Name' => $unit . '.fifo.read_cycles',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uSampler_\\d+\\.' . $unit . '_fifo_read_cycles',
                                              'm_ReportDataAs' => 'AVERAGEDIV1',
                                              'm_DoTestMaxVal' => 0})
			});
			
			push (@$lrSimData, {
			'Name' => $unit . '.fifo.write_cycles',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uSampler_\\d+\\.' . $unit . '_fifo_write_cycles',
                                              'm_ReportDataAs' => 'AVERAGEDIV1',
                                              'm_DoTestMaxVal' => 0})
			});
			
			push (@$lrSimData, {
			'Name' => $unit . '.fifo.rdwr_cycles',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uSampler_\\d+\\.' . $unit . '_fifo_rdwr_cycles',
                                              'm_ReportDataAs' => 'AVERAGEDIV1',
                                              'm_DoTestMaxVal' => 0})
			});
			
			push (@$lrSimData, {
			'Name' => $unit . '.data_ram.idle_cycles',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uSampler_\\d+\\.SC_data_power\\.idle',
                                              'm_ReportDataAs' => 'AVERAGEDIV1',
                                              'm_DoTestMaxVal' => 0})
			});
			
			push (@$lrSimData, {
			'Name' => $unit . '.data_ram.read_cycles',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uSampler_\\d+\\.SC_data_power\\.read$',
                                              'm_ReportDataAs' => 'AVERAGEDIV1',
                                              'm_DoTestMaxVal' => 0})
			});
			
			push (@$lrSimData, {
			'Name' => $unit . '.data_ram.write_cycles',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uSampler_\\d+\\.SC_data_power\\.write',
                                              'm_ReportDataAs' => 'AVERAGEDIV1',
                                              'm_DoTestMaxVal' => 0})
			});
			
			push (@$lrSimData, {
			'Name' => $unit . '.data_ram.rdwr_cycles',
			'StatObj' => MultiStatIStatObj->new({'m_StatRegex' => 'uSampler_\\d+\\.SC_data_power\\.readwrite',
                                              'm_ReportDataAs' => 'AVERAGEDIV1',
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
	if($N =~ m/ram|cam|fifo/)
	{
		my @data = split/\./, $N ;
		my $unit = $data[0] . "." . $data[1] ;
		# my $denominator = $base_stat_tbl->{"GennysimStatClks"} ;
		my $denominator = $base_stat_tbl->{$unit . ".idle_cycles"} + $base_stat_tbl->{$unit . ".read_cycles"} + $base_stat_tbl->{$unit . ".write_cycles"} + $base_stat_tbl->{$unit . ".rdwr_cycles"} ;
		if($denominator == 0)
		{
			return 0 ;
		}
		return $numerator/$denominator ;
	}
	my @data = split/_/, $N ;
	my $unit = $data[0] ;
	my $denominator = $base_stat_tbl->{$unit . "_idle_cycles"} + $base_stat_tbl->{$unit . "_active_stalled_cycles"} + $base_stat_tbl->{$unit . "_active_not_stalled_cycles"} ;
	if($denominator == 0)
	{
		return 0 ;
	}
	return $numerator/$denominator ;
};

sub CalcPS2_PL_NOT_ANISO{
	my $numerator = $base_stat_tbl->{"pl_active_not_stalled_cycles"} - 
					$base_stat_tbl->{"fl_SampleCAniso_subspans_cycles"} -
					$base_stat_tbl->{"fl_Aniso_subspans_cycles"} -
					$base_stat_tbl->{"fl_FastAniso_subspans_cycles"} ;

	my $denominator = $base_stat_tbl->{"pl_idle_cycles"} + $base_stat_tbl->{"pl_active_stalled_cycles"} + $base_stat_tbl->{"pl_active_not_stalled_cycles"} ;
	if($denominator == 0)
	{
		return 0 ;
	}
	return $numerator/$denominator ;
};

sub CalcPS2_PL_ANISO{
	my $numerator = $base_stat_tbl->{"fl_SampleCAniso_subspans_cycles"} +
					$base_stat_tbl->{"fl_Aniso_subspans_cycles"} +
					$base_stat_tbl->{"fl_FastAniso_subspans_cycles"} ;

	my $denominator = $base_stat_tbl->{"pl_idle_cycles"} + $base_stat_tbl->{"pl_active_stalled_cycles"} + $base_stat_tbl->{"pl_active_not_stalled_cycles"} ;
	if($denominator == 0)
	{
		return 0 ;
	}
	return $numerator/$denominator ;
};

sub CalcPS2_DG_FastTri{
	my $numerator = $base_stat_tbl->{"fl_FastTrilinear_subspans_cycles"} ;
	my $denominator = $base_stat_tbl->{"dg_idle_cycles"} + $base_stat_tbl->{"dg_active_stalled_cycles"} + $base_stat_tbl->{"dg_active_not_stalled_cycles"} ;
	if($denominator == 0)
	{
		return 0 ;
	}
	return $numerator/$denominator ;
};

sub CalcPS2_DG_FastAniso{
	my $numerator = $base_stat_tbl->{"fl_FastAniso_subspans_cycles"} ;
	my $denominator = $base_stat_tbl->{"dg_idle_cycles"} + $base_stat_tbl->{"dg_active_stalled_cycles"} + $base_stat_tbl->{"dg_active_not_stalled_cycles"} ;
	if($denominator == 0)
	{
		return 0 ;
	}
	return $numerator/$denominator ;
};

sub CalcPS2_DG_not_Aniso2_FastTri_FastAniso{
	my $numerator = $base_stat_tbl->{"dg_active_not_stalled_cycles"} -
					$base_stat_tbl->{"fl_Aniso_subspans_cycles"} -
					$base_stat_tbl->{"fl_SampleCAniso_subspans_cycles"} -
					$base_stat_tbl->{"fl_FastTrilinear_subspans_cycles"}  -
					$base_stat_tbl->{"fl_FastAniso_subspans_cycles"} ;

	my $denominator = $base_stat_tbl->{"dg_idle_cycles"} + $base_stat_tbl->{"dg_active_stalled_cycles"} + $base_stat_tbl->{"dg_active_not_stalled_cycles"} ;
	if($denominator == 0)
	{
		return 0 ;
	}
	return $numerator/$denominator ;
};

sub CalcPS2_DG_Aniso2_way{
	my $numerator = $base_stat_tbl->{"fl_Aniso_subspans_cycles"} +
					$base_stat_tbl->{"fl_SampleCAniso_subspans_cycles"} ;
					
	my $denominator = $base_stat_tbl->{"dg_idle_cycles"} + $base_stat_tbl->{"dg_active_stalled_cycles"} + $base_stat_tbl->{"dg_active_not_stalled_cycles"} ;
	if($denominator == 0)
	{
		return 0 ;
	}
	return $numerator/$denominator ;
};

sub CalcPS0_QC{
	my $numerator = $base_stat_tbl->{"qc_idle_cycles"} ;
	my $denominator = $base_stat_tbl->{"qc_idle_cycles"} + $base_stat_tbl->{"qc_ft_active_stalled_cycles"} + $base_stat_tbl->{"qc_sc_active_stalled_cycles"} + $base_stat_tbl->{"qc_active_not_stalled_cycles"} ;
	if($denominator == 0)
	{
		return 0 ;
	}
	return $numerator/$denominator ;
};

sub CalcPS1_QC{
	my $numerator = $base_stat_tbl->{"qc_ft_active_stalled_cycles"} +
					$base_stat_tbl->{"qc_sc_active_stalled_cycles"} ;

	my $denominator = $base_stat_tbl->{"qc_idle_cycles"} + $base_stat_tbl->{"qc_ft_active_stalled_cycles"} + $base_stat_tbl->{"qc_sc_active_stalled_cycles"} + $base_stat_tbl->{"qc_active_not_stalled_cycles"} ;
	if($denominator == 0)
	{
		return 0 ;
	}
	return $numerator/$denominator ;
};

sub CalcPS2_QC_FastTri{
	my $numerator = $base_stat_tbl->{"fl_FastTrilinear_subspans_cycles"} ;
	my $denominator = $base_stat_tbl->{"qc_idle_cycles"} + $base_stat_tbl->{"qc_ft_active_stalled_cycles"} + $base_stat_tbl->{"qc_sc_active_stalled_cycles"} + $base_stat_tbl->{"qc_active_not_stalled_cycles"} ;
	if($denominator == 0)
	{
		return 0 ;
	}
	return $numerator/$denominator ;
};

sub CalcPS2_QC_FastAniso{
	my $numerator = $base_stat_tbl->{"fl_FastAniso_subspans_cycles"} ;
	my $denominator = $base_stat_tbl->{"qc_idle_cycles"} + $base_stat_tbl->{"qc_ft_active_stalled_cycles"} + $base_stat_tbl->{"qc_sc_active_stalled_cycles"} + $base_stat_tbl->{"qc_active_not_stalled_cycles"} ;
	if($denominator == 0)
	{
		return 0 ;
	}
	return $numerator/$denominator ;
};

sub CalcPS2_QC_Unorm{
	my $numerator = $base_stat_tbl->{"qc_active_not_stalled_cycles_unorm"} ;
	my $denominator = $base_stat_tbl->{"qc_idle_cycles"} + $base_stat_tbl->{"qc_ft_active_stalled_cycles"} + $base_stat_tbl->{"qc_sc_active_stalled_cycles"} + $base_stat_tbl->{"qc_active_not_stalled_cycles"} ;
	if($denominator == 0)
	{
		return 0 ;
	}
	return $numerator/$denominator ;
};

sub CalcPS2_QC_Not_Unorm_FastTri_FastAniso{
	my $numerator = $base_stat_tbl->{"qc_active_not_stalled_cycles"} -
					$base_stat_tbl->{"fl_FastTrilinear_subspans_cycles"} -
					$base_stat_tbl->{"fl_FastAniso_subspans_cycles"} -
					$base_stat_tbl->{"qc_active_not_stalled_cycles_unorm"} ;
				
	my $denominator = $base_stat_tbl->{"qc_idle_cycles"} + $base_stat_tbl->{"qc_ft_active_stalled_cycles"} + $base_stat_tbl->{"qc_sc_active_stalled_cycles"} + $base_stat_tbl->{"qc_active_not_stalled_cycles"} ;
	if($denominator == 0)
	{
		return 0 ;
	}
	return $numerator/$denominator ;
} ;

sub CalcPS2_SC_FastBilin{
	my $numerator = $base_stat_tbl->{"fl_fastbilinear_cycles"} ;
	my $denominator = $base_stat_tbl->{"sc_idle_cycles"} + $base_stat_tbl->{"sc_active_stalled_cycles"} + $base_stat_tbl->{"sc_active_not_stalled_cycles"} ;
	if($denominator == 0)
	{
		return 0 ;
	}
	return $numerator/$denominator ;
};

sub CalcPS2_SC_FastTri{
	my $numerator = $base_stat_tbl->{"fl_FastTrilinear_subspans_cycles"} ;
	my $denominator = $base_stat_tbl->{"sc_idle_cycles"} + $base_stat_tbl->{"sc_active_stalled_cycles"} + $base_stat_tbl->{"sc_active_not_stalled_cycles"} ;
	if($denominator == 0)
	{
		return 0 ;
	}
	return $numerator/$denominator ;
};

sub CalcPS2_SC_FastAniso{
	my $numerator = $base_stat_tbl->{"fl_FastAniso_subspans_cycles"} ;
	my $denominator = $base_stat_tbl->{"sc_idle_cycles"} + $base_stat_tbl->{"sc_active_stalled_cycles"} + $base_stat_tbl->{"sc_active_not_stalled_cycles"} ;
	if($denominator == 0)
	{
		return 0 ;
	}
	return $numerator/$denominator ;
};

sub CalcPS2_SC_Not_FASTBILIN_Unorm_FastTri_FastAniso{
	my $numerator = $base_stat_tbl->{"sc_active_not_stalled_cycles"} -
					$base_stat_tbl->{"fl_FastTrilinear_subspans_cycles"} -
					$base_stat_tbl->{"fl_FastAniso_subspans_cycles"} -
					$base_stat_tbl->{"fl_fastbilinear_cycles"} -
					$base_stat_tbl->{"sc_active_not_stalled_cycles_unorm"} ;
				
	my $denominator = $base_stat_tbl->{"sc_idle_cycles"} + $base_stat_tbl->{"sc_active_stalled_cycles"} + $base_stat_tbl->{"sc_active_not_stalled_cycles"} ;
	if($denominator == 0)
	{
		return 0 ;
	}
	return $numerator/$denominator ;
};

sub CalcPS2_FL_Not_FASTBILIN_FastTri_FastAniso{
	my $numerator = $base_stat_tbl->{"fl_active_not_stalled_cycles"} -
					$base_stat_tbl->{"fl_FastTrilinear_subspans_cycles"} -
					$base_stat_tbl->{"fl_FastAniso_subspans_cycles"} -
					$base_stat_tbl->{"fl_fastbilinear_cycles"} ;
				
	my $denominator = $base_stat_tbl->{"fl_idle_cycles"} + $base_stat_tbl->{"fl_active_stalled_cycles"} + $base_stat_tbl->{"fl_active_not_stalled_cycles"} ;
	if($denominator == 0)
	{
		return 0 ;
	}
	return $numerator/$denominator ;
};

sub CalcPS2_FT_FastTri{
	my $numerator = $base_stat_tbl->{"fl_FastTrilinear_subspans_cycles"} ;
	my $denominator = $base_stat_tbl->{"ft_idle_cycles"} + $base_stat_tbl->{"ft_active_stalled_cycles"} + $base_stat_tbl->{"ft_active_not_stalled_cycles"} ;
	if($denominator == 0)
	{
		return 0 ;
	}
	return $numerator/$denominator ;
};

sub CalcPS2_FT_FastAniso{
	my $numerator = $base_stat_tbl->{"fl_FastAniso_subspans_cycles"} ;
	my $denominator = $base_stat_tbl->{"ft_idle_cycles"} + $base_stat_tbl->{"ft_active_stalled_cycles"} + $base_stat_tbl->{"ft_active_not_stalled_cycles"} ;
	if($denominator == 0)
	{
		return 0 ;
	}
	return $numerator/$denominator ;
};

sub CalcPS2_FT_Not_Unorm_FastTri_FastAniso{
	my $numerator = $base_stat_tbl->{"ft_active_not_stalled_cycles"} -
					$base_stat_tbl->{"fl_FastTrilinear_subspans_cycles"} -
					$base_stat_tbl->{"fl_FastAniso_subspans_cycles"} -
					$base_stat_tbl->{"ft_active_not_stalled_cycles_unorm"} ;
				 
	my $denominator = $base_stat_tbl->{"ft_idle_cycles"} + $base_stat_tbl->{"ft_active_stalled_cycles"} + $base_stat_tbl->{"ft_active_not_stalled_cycles"} ;
	if($denominator == 0)
	{
		return 0 ;
	}
	return $numerator/$denominator ;
} ;

sub CalcMT_Not_Latqput{
	my $numerator = $base_stat_tbl->{"mt_active_not_stalled_cycles"} - $base_stat_tbl->{"mt_tag_read_cycles"} ;
	my $denominator = $base_stat_tbl->{"mt_idle_cycles"} + $base_stat_tbl->{"mt_active_stalled_cycles"} + $base_stat_tbl->{"mt_active_not_stalled_cycles"} ;
	if($denominator == 0)
	{
		return 0 ;
	}
	return $numerator/$denominator ;
};
