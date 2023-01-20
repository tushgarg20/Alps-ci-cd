use strict;
use Getopt::Long;
use Pod::Usage;
use POSIX;

##################################################
# Knobs and Cmdline Processing
##################################################
my $tracelist					= "";
my $odir						= "";
my $cmp							= '';
my $sdir						= "";
my $arch						= '';
my $method						= '';
my $pool						= '';
my $qslot						= '';
my $runLocal					= '';
my $annealing					= '';
my $cnl							= '';
my $icl							= '';
my $icllp						= '';
my $tgl							= '';
my $adl							= '';
my $reduced						= '';
my $tglhp_512					= '';
my $tglhp_384					= '';
my $tglhp						= '';
my $cam 						= '';
my $pvc							= '';
my $kaolin						= '';
my $tgldg						= '';
my $pvc_scaled					= '';
my $dg2			       			= '';
my $dg2p5						= '';
my $xe2_plan					= '';
my $xe2_bna4_plan				= '';
my $xe2							= '';
my $xe3							= '';
my $pvc_a21                     = '';
my $pvc2                        = ''; 
my $pvcdp                       = ''; 
my $pvcxt                       = ''; 
my $pvcxttrend                  = '';
my $rlt1                        = ''; 
my $rlt_plan                    = ''; 
my $xe3_xpc                     = ''; 
my $rltconcept                  = ''; 
my $rltb_ec_0_5                 = ''; 
my $pvck2xsa                    = ''; 
my $pvck2xeu                    = ''; 
my $mtl                         = ''; 
my $lnl                         = ''; 
my $ptl                         = ''; 
my $cpl                         = ''; 
my $xe3_fcs                     = ''; 
my $xe3_fcs_msc                 = ''; 
my $xe3_fcs_los                 = ''; 
my $xe3_fcs_sw                  = ''; 



Getopt::Long::GetOptions(
    "input|i=s"		=> \$tracelist,
	"sdir|s=s"		=> \$sdir,
	"odir|o=s"		=> \$odir,
	"compressed"	=> \$cmp,
	"arch|a=s"		=> \$arch,
	"method|m=s"	=> \$method,
	"pool|p=s"		=> \$pool,
	"qslot|q=s"		=> \$qslot,
	"runlocal"		=> \$runLocal,
	"annealing"		=> \$annealing,
	"cnl"			=> \$cnl,
	"icl"			=> \$icl,
	"icllp"			=> \$icllp,
	"tgl"			=> \$tgl,
	"adl"			=> \$adl,
    "reduced"		=> \$reduced,
	"tglhp"			=> \$tglhp,
    "pvc"			=> \$pvc,
	"cam"			=> \$cam,
	"kaolin"		=> \$kaolin,
	"tglhp_512"		=> \$tglhp_512,
	"tglhp_384"		=> \$tglhp_384,
	"tgldg"			=> \$tgldg,
	"dg2"			=> \$dg2,
	"dg2p5"			=> \$dg2p5,
	"xe2_plan"		=> \$xe2_plan,
	"xe2_bna4_plan"	=> \$xe2_bna4_plan,
	"xe2"			=> \$xe2,
	"xe3"			=> \$xe3,
	"xe3_fcs"		=> \$xe3_fcs,
	"xe3_fcs_msc"		=> \$xe3_fcs_msc,
	"xe3_fcs_los"		=> \$xe3_fcs_los,
	"xe3_fcs_sw"	=> \$xe3_fcs_sw,
	"mtl"			=> \$mtl,
	"lnl"			=> \$lnl,
	"ptl"			=> \$ptl,
	"cpl"			=> \$cpl,
	"pvc_scaled"	=> \$pvc_scaled,
	"pvc2"			=> \$pvc2,
	"pvcdp"			=> \$pvcdp,
	"pvcxt"			=> \$pvcxt,
	"pvcxttrend"	=> \$pvcxttrend,
    "rlt1"      	=> \$rlt1,
    "rlt_plan"  	=> \$rlt_plan,
    "xe3_xpc"   	=> \$xe3_xpc,
	"rltconcept"	=> \$rltconcept,
	"rltb_ec_0_5"	=> \$rltb_ec_0_5,
	"pvck2xsa"		=> \$pvck2xsa,
    "pvc_a21"       => \$pvc_a21 

) or Pod::Usage::pod2usage(-exitstatus => 1, -verbose =>1);

$sdir .= "/" if $sdir !~ /\/$/;
die "Illegal output directory specification: $sdir!!" unless -e $sdir and -d $sdir;

$odir .= "/" if $odir !~ /\/$/;
die "Illegal output directory specification: $odir!!" unless -e $odir and -d $odir;

if ($runLocal) {warn "--pool and --qslot options will be ignored\n";}

my $script = ($runLocal) ? $sdir . "run_alps.py" : $sdir . "run_alps_nb.py";
my $cfg_file = ($annealing) ? $sdir . "cfg/" ."alps_cfg_annealing.yaml" : $sdir . "cfg/" ."alps_cfg.yaml";
$cfg_file = ($cnl) ? $sdir . "cfg/" ."alps_cfg_cnl.yaml" : $cfg_file;
$cfg_file = ($icl) ? $sdir . "cfg/" ."alps_cfg_icl.yaml" : $cfg_file;
$cfg_file = ($icllp) ? $sdir . "cfg/" ."alps_cfg_icllp.yaml" : $cfg_file;
$cfg_file = ($tgl) ? $sdir . "cfg/" ."alps_cfg_tgl.yaml" : $cfg_file;
$cfg_file = ($adl) ? $sdir . "cfg/" ."alps_cfg_adl.yaml" : $cfg_file;
$cfg_file = ($reduced && $tgl) ? $sdir . "cfg/" ."alps_cfg_tgl_reduced.yaml" : $cfg_file;
$cfg_file = ($tglhp) ? $sdir . "cfg/" ."alps_cfg_tglhp.yaml" : $cfg_file;
$cfg_file = ($tglhp_512) ? $sdir . "cfg/" ."alps_cfg_tglhp_512.yaml" : $cfg_file;
$cfg_file = ($tglhp_384) ? $sdir . "cfg/" ."alps_cfg_tglhp_384.yaml" : $cfg_file;
$cfg_file = ($tgldg) ? $sdir . "cfg/" ."alps_cfg_tgldg.yaml" : $cfg_file;
$cfg_file = ($pvc_scaled) ? $sdir . "cfg/" ."alps_cfg_pvc_scaled.yaml" : $cfg_file;
$cfg_file = ($pvc) ? $sdir . "cfg/" ."alps_cfg_pvc.yaml" : $cfg_file;
$cfg_file = ($pvc_a21) ? $sdir . "cfg/" ."alps_cfg_pvc_a21.yaml" : $cfg_file;


if ($method){
    if ($method eq "cam"){
	$cfg_file = ($pvc) ? $sdir . "cfg/" ."alps_cfg_pvc_cam.yaml" : $cfg_file;
	$cfg_file = ($pvc2) ? $sdir . "cfg/" ."alps_cfg_pvc2_cam.yaml" : $cfg_file;
	$cfg_file = ($pvcdp) ? $sdir . "cfg/" ."alps_cfg_pvcdp_cam.yaml" : $cfg_file;
	$cfg_file = ($pvcxt) ? $sdir . "cfg/" ."alps_cfg_pvcxt_cam.yaml" : $cfg_file;
	$cfg_file = ($pvcxttrend) ? $sdir . "cfg/" ."alps_cfg_pvcxttrend_cam.yaml" : $cfg_file;
	$cfg_file = ($rlt1) ? $sdir . "cfg/" ."alps_cfg_rlt1_cam.yaml" : $cfg_file;
	$cfg_file = ($rlt_plan) ? $sdir . "cfg/" ."alps_cfg_rlt1_cam.yaml" : $cfg_file;
	$cfg_file = ($xe3_fcs) ? $sdir . "cfg/" ."alps_cfg_xe3_fcs_cam.yaml" : $cfg_file;
	$cfg_file = ($xe3_fcs_msc) ? $sdir . "cfg/" ."alps_cfg_xe3_fcs_msc_cam.yaml" : $cfg_file;
	$cfg_file = ($xe3_fcs_los) ? $sdir . "cfg/" ."alps_cfg_xe3_fcs_los_cam.yaml" : $cfg_file;
	$cfg_file = ($xe3_fcs_sw) ? $sdir . "cfg/" ."alps_cfg_xe3_fcs_sw_cam.yaml" : $cfg_file;
	$cfg_file = ($xe3_xpc) ? $sdir . "cfg/" ."alps_cfg_xe3_xpc_cam.yaml" : $cfg_file;
	$cfg_file = ($cpl) ? $sdir . "cfg/" ."alps_cfg_cpl_cam.yaml" : $cfg_file;
	$cfg_file = ($rltconcept) ? $sdir . "cfg/" ."alps_cfg_rltconcept_cam.yaml" : $cfg_file;
	$cfg_file = ($rltb_ec_0_5) ? $sdir . "cfg/" ."alps_cfg_rltb_ec_0_5_cam.yaml" : $cfg_file;
	$cfg_file = ($pvck2xsa) ? $sdir . "cfg/" ."alps_cfg_pvck2xsa_cam.yaml" : $cfg_file;
	$cfg_file = ($mtl) ? $sdir . "cfg/" ."alps_cfg_mtl_cam.yaml" : $cfg_file;
	$cfg_file = ($lnl) ? $sdir . "cfg/" ."alps_cfg_lnl_cam.yaml" : $cfg_file;
	$cfg_file = ($ptl) ? $sdir . "cfg/" ."alps_cfg_ptl_cam.yaml" : $cfg_file;
	$cfg_file = ($pvc_a21) ? $sdir . "cfg/" ."alps_cfg_pvc_cam.yaml" : $cfg_file;
	$cfg_file = ($dg2) ? $sdir . "cfg/" ."alps_cfg_tgldg2_cam.yaml" : $cfg_file;
	$cfg_file = ( $tglhp) ? $sdir . "cfg/" ."alps_cfg_tglhp_cam.yaml" : $cfg_file;
	$cfg_file = ($dg2p5) ? $sdir . "cfg/" ."alps_cfg_dg2p5_cam.yaml" : $cfg_file;
	$cfg_file = ($tgl) ? $sdir . "cfg/" ."alps_cfg_tgl_cam.yaml" : $cfg_file;
	$cfg_file = ($adl) ? $sdir . "cfg/" ."alps_cfg_adl_cam.yaml" : $cfg_file;
	$cfg_file = ($xe3) ? $sdir . "cfg/" ."alps_cfg_xe3_cam.yaml" : $cfg_file;
	$cfg_file = ($xe2_plan) ? $sdir . "cfg/" ."alps_cfg_xe2_cam.yaml" : $cfg_file;
	$cfg_file = ($xe2_bna4_plan) ? $sdir . "cfg/" ."alps_cfg_xe2_cam.yaml" : $cfg_file;
	$cfg_file = ($xe2) ? $sdir . "cfg/" ."alps_cfg_xe2_cam.yaml" : $cfg_file;
    }else{
	$cfg_file = ($tglhp) ? $sdir . "cfg/" ."alps_cfg_tglhp_kaolin.yaml" : $cfg_file;
	$cfg_file = ($tgl) ? $sdir . "cfg/" ."alps_cfg_tgl_kaolin.yaml" : $cfg_file;
	$cfg_file = ($pvc) ? $sdir . "cfg/" ."alps_cfg_pvc_kaolin.yaml" : $cfg_file;
	$cfg_file = ($dg2) ? $sdir . "cfg/" ."alps_cfg_dg2_kaolin.yaml" : $cfg_file;
	$cfg_file = ($xe2) ? $sdir . "cfg/" ."alps_cfg_xe2_kaolin.yaml" : $cfg_file;
    $cfg_file = ($mtl) ? $sdir . "cfg/" ."alps_cfg_mtl_kaolin.yaml" : $cfg_file;
	$cfg_file = ($xe3) ? $sdir . "cfg/" ."alps_cfg_xe3_kaolin.yaml" : $cfg_file;
	$cfg_file = ($pvcdp) ? $sdir . "cfg/" ."alps_cfg_pvcdp_kaolin.yaml" : $cfg_file;
	$cfg_file = ($pvcxt) ? $sdir . "cfg/" ."alps_cfg_pvcxt_kaolin.yaml" : $cfg_file;
	$cfg_file = ($pvcxttrend) ? $sdir . "cfg/" ."alps_cfg_pvcxt_kaolin.yaml" : $cfg_file;
	$cfg_file = ($rltconcept) ? $sdir . "cfg/" ."alps_cfg_pvck2xeu_kaolin.yaml" : $cfg_file;
	$cfg_file = ($rltb_ec_0_5) ? $sdir . "cfg/" ."alps_cfg_rltb_ec_0_5_kaolin.yaml" : $cfg_file;
	$cfg_file = ($lnl) ? $sdir . "cfg/" ."alps_cfg_lnl_kaolin.yaml" : $cfg_file;
	$cfg_file = ($xe3_fcs) ? $sdir . "cfg/" ."alps_cfg_xe3_fcs_kaolin.yaml" : $cfg_file;
    }
}

my $class = '8G&&nosusp&&SLES11';

open(FILE,"<$tracelist") or die "Can't open $tracelist\n";



while(my $line = <FILE>){
        if (rindex($line, ".stat.gz") > -1){
	    $line =~ s/\r//g; chomp($line);
	    my $wl = ($cmp) ? (split/\.stat\.gz/,$line)[0] : (split/\.stat/,$line)[0];
	    my $prefix = $wl;
	    if ($runLocal) {
		    print "python $script -w $wl -p $prefix -o $odir -c $cfg_file -a $arch -l -d $sdir"."\n";
                    if ($method) {
			    system("python $script -w $wl -p $prefix -o $odir -c $cfg_file -a $arch -l -d $sdir -m $method");
		    }#else  {
			    #system("python $script -w $wl -p $prefix -o $odir -c $cfg_file -a $arch -l -d $sdir");
                    #}
	    } else {
        	 if ($method)  {	
				    system("nbjob run --target $pool --qslot $qslot --class \'$class\'  python $script -w $wl -p $prefix -o $odir -c $cfg_file -a $arch -l -d $sdir -m $method");
        	  } #else {
				    #system("nbjob run --target $pool --qslot $qslot --class \'$class\'  python $script -w $wl -p $prefix -o $odir -c $cfg_file -a $arch -l -d $sdir");
                    #}
	       } 
	} else{
		die "tracelist file doesn't contain *stat.gz files"
	}
	#print "python $script -w $wl -p $prefix -o $odir -c $cfg_file -a $arch -l -d $sdir\n";
}
close(FILE);
