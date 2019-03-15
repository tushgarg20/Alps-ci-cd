use strict;
use Getopt::Long;
use Pod::Usage;
use POSIX;

##################################################
# Knobs and Cmdline Processing
##################################################
my $tracelist		= "";
my $odir			= "";
my $cmp				= '';
my $sdir			= "";
my $arch			= '';
my $pool			= '';
my $qslot			= '';
my $runLocal			= '';
my $annealing		= '';
my $cnl				= '';
my $icl				= '';
my $icllp			= '';
my $tgl				= '';
my $reduced			= '';
my $tglhp_512			= '';
my $tglhp_384			= '';
my $tglhp			= '';
my $cam 			= '';
my $tgldg			= '';
my $pvc_scaled			= '';
my $pvc				= '';



Getopt::Long::GetOptions(
    "input|i=s"		=> \$tracelist,
	"sdir|s=s"		=> \$sdir,
	"odir|o=s"		=> \$odir,
	"compressed"		=> \$cmp,
	"arch|a=s"		=> \$arch,
	"pool|p=s"		=> \$pool,
	"qslot|q=s"		=> \$qslot,
	"runlocal"		=> \$runLocal,
	"annealing"		=> \$annealing,
	"cnl"			=> \$cnl,
	"icl"			=> \$icl,
	"icllp"			=> \$icllp,
	"tgl"			=> \$tgl,
        "reduced"		=> \$reduced,
	"tglhp"			=> \$tglhp,
	"cam|m=s"		=> \$cam,
	"tglhp_512"		=> \$tglhp_512,
	"tglhp_384"		=> \$tglhp_384,
	"tgldg"			=> \$tgldg,
	"pvc_scaled"		=> \$pvc_scaled,
	"pvc"		=> \$pvc

        
        
) or Pod::Usage::pod2usage(-exitstatus => 1, -verbose =>1);

$sdir .= "/" if $sdir !~ /\/$/;
die "Illegal output directory specification: $sdir!!" unless -e $sdir and -d $sdir;

$odir .= "/" if $odir !~ /\/$/;
die "Illegal output directory specification: $odir!!" unless -e $odir and -d $odir;

if ($runLocal) {warn "--pool and --qslot options will be ignored\n";}

my $script = ($runLocal) ? $sdir . "run_alps.py" : $sdir . "run_alps_nb.py";
my $cfg_file = ($annealing) ? $sdir . "alps_cfg_annealing.yaml" : $sdir . "alps_cfg.yaml";
$cfg_file = ($cnl) ? $sdir . "alps_cfg_cnl.yaml" : $cfg_file;
$cfg_file = ($icl) ? $sdir . "alps_cfg_icl.yaml" : $cfg_file;
$cfg_file = ($icllp) ? $sdir . "alps_cfg_icllp.yaml" : $cfg_file;
$cfg_file = ($tgl) ? $sdir . "alps_cfg_tgl.yaml" : $cfg_file;
$cfg_file = ($reduced && $tgl) ? $sdir . "alps_cfg_tgl_reduced.yaml" : $cfg_file;
$cfg_file = ($tglhp) ? $sdir . "alps_cfg_tglhp.yaml" : $cfg_file;
$cfg_file = ($cam && $tglhp) ? $sdir . "alps_cfg_tglhp_cam.yaml" : $cfg_file;
$cfg_file = ($tglhp_512) ? $sdir . "alps_cfg_tglhp_512.yaml" : $cfg_file;
$cfg_file = ($tglhp_384) ? $sdir . "alps_cfg_tglhp_384.yaml" : $cfg_file;
$cfg_file = ($tgldg) ? $sdir . "alps_cfg_tgldg.yaml" : $cfg_file;
$cfg_file = ($pvc_scaled) ? $sdir . "alps_cfg_pvc_scaled.yaml" : $cfg_file;
$cfg_file = ($pvc) ? $sdir . "alps_cfg_pvc.yaml" : $cfg_file;






my $class = '8G&&nosusp&&SLES11';

open(FILE,"<$tracelist") or die "Can't open $tracelist\n";
while(my $line = <FILE>){
	$line =~ s/\r//g; chomp($line);
	my $wl = ($cmp) ? (split/\.stat\.gz/,$line)[0] : (split/\.stat/,$line)[0];
	my $prefix = $wl;
	if ($runLocal) {
		print "python $script -w $wl -p $prefix -o $odir -c $cfg_file -a $arch -l -d $sdir"."\n";
                if ($cam) {
			system("python $script -w $wl -p $prefix -o $odir -c $cfg_file -a $arch -l -d $sdir -m $cam");
                } else  {
			system("python $script -w $wl -p $prefix -o $odir -c $cfg_file -a $arch -l -d $sdir");
                }
	} else {
                if ($cam)  {	
		system("nbjob run --target $pool --qslot $qslot --class \'$class\'  python $script -w $wl -p $prefix -o $odir -c $cfg_file -a $arch -l -d $sdir -m $cam");
                } else {
		system("nbjob run --target $pool --qslot $qslot --class \'$class\'  python $script -w $wl -p $prefix -o $odir -c $cfg_file -a $arch -l -d $sdir");
                }
	}
	#print "python $script -w $wl -p $prefix -o $odir -c $cfg_file -a $arch -l -d $sdir\n";
}
close(FILE);
