#!/usr/intel/bin/perl

##############################################################################
#                          FILE DESCRIPTION                                  #
#                                                                            #
#  ** Name        : convert_gt_sheet_format.pl                               #
#  ** Description : Convert GT alps sheet from                               #
#                   txt format to classic uncore format                      #    
#                   max/sum/averages                                         #
#  ** Author      : Suresh Srinivasan(ssrini2)                               #
#  ** Usage       :         #
##############################################################################

use strict;
use warnings;
use Getopt::Long;

my $gtInputFileName = "";
my $archScaleFileName = "";
my $outFormulaFileName = "";

my $result= GetOptions("inp=s" =>  \$gtInputFileName,
                        "arch_scale_file=s" => \$archScaleFileName, 
                        "out=s" => \$outFormulaFileName );

my $fubName             =  "";
my $unitName            = "";
my $clusterName         = "";
my $locName             = "";
my $funcName            = "";
my $formulaName         = "";
my $ec                  = "";
my $arch_scale_factor   = "";
my %arch_scale;

if($gtInputFileName eq "")
{
    print "convert_gt_sheet_format.pl usage: \n
            --inp: \t GT input file with cdyn weights for event \n
            --arch_scale_file: \t Architecture scaling file \n
            --out (optional): \t Output file of formula file you need \n";

    exit(1);        
}

if($archScaleFileName eq "")
{
    print "WARNING: You have not specified any arch scaling file!!\n";
}

if($outFormulaFileName eq "")
{
    $outFormulaFileName = "$gtInputFileName.formula.out"; 
}

&parseArchScalingFile();

open GTFILE, $gtInputFileName or die "Cannot Open Input file: $gtInputFileName \n" ;
open OFILE, ">$outFormulaFileName" or die "Cannot open output file for writing: $outFormulaFileName \n" ;
print OFILE "Fub\tUnit\tCluster\tLocation\tFunction\tFormula\tEC1\tSrc1\tComments\n";

my $line = <GTFILE>;
while($line)
{
    my @lineArgs = split(/\s+/, $line); 
 
    if($#lineArgs >= 1)
    {
        if($lineArgs[0] =~ /PS[0-2]/)
        {
        #Hack to fix the stat names since GT sheet has spaces in some stat names
            if(!($lineArgs[1] =~ /^[0-9]/))
            {
                #print " Something wrong with line $line Expecting a number at $lineArgs[1] \n";
                $lineArgs[0] = "$lineArgs[0] $lineArgs[1]";
                $lineArgs[1] = $lineArgs[2];
            }

            $fubName            = get_fub_name($lineArgs[0]);        
            $unitName           = get_unit_name($lineArgs[0]);        
            $clusterName        = "GT";        
            $locName            = "gt";
            $funcName           = get_func_name($lineArgs[0]);
            $formulaName        = get_formula_name($lineArgs[0]);
            $arch_scale_factor  = get_arch_scale_factor($lineArgs[0]);
            $ec                 = $lineArgs[1] * $arch_scale_factor;

            print OFILE "$fubName\t$unitName\t$clusterName\t$locName\t$funcName\t$formulaName\t$ec\n";
        }
        else
        {
            #Handle EU toggle stats seperately
        }
    }

    $line = <GTFILE>;
}

close (GTFILE);
close (OFILE);

###############END OF MAIN CODE##############################################################

sub parseArchScalingFile
{
    open AFILE, $archScaleFileName or die "Invalid arch scaling file name: $archScaleFileName \n";
    $line = <AFILE>;

    while ($line)
    {
        my @lineArgs = split(/\s+/, $line); 
#Hack to fix the stat names since GT sheet has spaces in some stat names
        if(!($lineArgs[1] =~ /^[0-9]/))
        {
#print " Something wrong with line $line Expecting a number at $lineArgs[1] \n";
            $lineArgs[0] = "$lineArgs[0] $lineArgs[1]";
            $lineArgs[1] = $lineArgs[2];
        }

        my $key = uc($lineArgs[0]);
        $arch_scale{$key} = $lineArgs[1];   
        $line = <AFILE>;
    }
    close AFILE;
}

sub get_formula_name
{
#for most formulas it just returns the same name
# e.g PS0_VF will return PS0_VF since that will be multiplied to the EC to get
# cdyn
# However for EUs we need to use the toggle rate as well
    my $inp = shift;   
    $inp =~ s#&#_#;

    return $inp;
}

sub get_func_name
{
#PS0_VF_RAM will return IDLE
#PS1 and PS2 will just return PS1_VF_RAM
    my $inp = shift;
    my @inpArgs = "";
    @inpArgs = split(/_/, $inp);

    if($inpArgs[0] eq "PS0")
    {
        return "Idle";
    }
    else
    {
        return $inpArgs[0];
    }
}

sub get_unit_name
{
#PS0_VF_RAM will return VF
    my $inp = shift;
    my @inpArgs = "";
    @inpArgs = split(/_/, $inp);
    return $inpArgs[1];
}

sub get_arch_scale_factor
{
#PS0_VF_RAM will return ArchScale_VF
    #hack Some Arch scale files have ArchScale_PS0_CS some have ArchScale_CS hceck before we proceed
    my $leavePS = 0;
    if(exists $arch_scale{"ARCHSCALE_PS0_CS"})
    { $leavePS = 1; }

    my $inp = shift;
    if($leavePS == 0) { $inp =~ s#_#:#; }
    my @inpArgs = "";
    @inpArgs = split(/:/, $inp);
    my $archName = "";
    if($leavePS == 0) { $archName = $inpArgs[1]; }
    else { $archName = $inp; }

##Deal with exceptions first####
    if($inp =~ /L3SLMBank_LTCDSLM_DataRam/)
    {
        
    }

    while(!($archName eq ""))
    {
        $archName =~ s# $## ;
        my $archName_UC = uc($archName);
#        print "$archName_UC\n" ;
        if(exists $arch_scale{"ARCHSCALE_$archName_UC"} )
        {
            my $archScale = $arch_scale{"ARCHSCALE_$archName_UC"} ;
#            print "Returning $archScale \n";
            return $arch_scale{"ARCHSCALE_$archName_UC"} ;
        }
        my $temp = $archName;
        $temp =~ s#(.*)-#$1:#;
        @inpArgs = "";
        @inpArgs = split(/:/, $temp);
        if($#inpArgs < 1)
        {
            $temp =~ s#(.*)_#$1:#;
            @inpArgs = "";
            @inpArgs = split(/:/, $temp);
        }    
        $archName = $inpArgs[0];
    }

    return 1;
}

sub get_fub_name
{
#PS0_VF_RAM will return VF_RAM
    my $inp = shift;
    $inp =~ s#_#:#;
    $inp =~ s#&#_#;
    my @inpArgs = "";
    @inpArgs = split(/:/, $inp);
    return $inpArgs[1];
}

