use strict;
use Getopt::Long;
use Pod::Usage;
use POSIX;

##################################################
# Knobs and Cmdline Processing
##################################################
my $tracelist		= "";
my $odir			= "";
my $sdir			= "";
my $arch			= '';
my $pool			= '';
my $qslot			= '';
my $annealing		= '';
my $cnl				= '';
my $icl				= '';
my $pby				= '';

Getopt::Long::GetOptions(
    "input|i=s"		=> \$tracelist,
	"sdir|s=s"		=> \$sdir,
	"odir|o=s"		=> \$odir,
	"arch|a=s"		=> \$arch,
	"pool|p=s"		=> \$pool,
	"qslot|q=s"		=> \$qslot,
	"annealing"		=> \$annealing,
	"cnl"			=> \$cnl,
	"icl"			=> \$icl,
	"pby"			=> \$pby
        
) or Pod::Usage::pod2usage(-exitstatus => 1, -verbose =>1);

$sdir .= "/" if $sdir !~ /\/$/;
die "Illegal output directory specification: $sdir!!" unless -e $sdir and -d $sdir;

$odir .= "/" if $odir !~ /\/$/;
die "Illegal output directory specification: $odir!!" unless -e $odir and -d $odir;

my $script = $sdir . "run_alps_nb.py";
my $cfg_file = ($annealing) ? $sdir . "alps_cfg_annealing.yaml" : $sdir . "alps_cfg.yaml";
$cfg_file = ($cnl) ? $sdir . "alps_cfg_cnl.yaml" : $cfg_file;
$cfg_file = ($icl) ? $sdir . "alps_cfg_icl.yaml" : $cfg_file;
$cfg_file = ($pby) ? $sdir . "alps_cfg_icllp.yaml" : $cfg_file;

my $class = '8G&&nosusp&&SLES11';

open(FILE,"<$tracelist") or die "Can't open $tracelist\n";
while(my $line = <FILE>){
	$line =~ s/\r//g; chomp($line);
	my $wl = (split/\.stat/,$line)[0];
	my $prefix = $wl;
	system("nbjob run --target $pool --qslot $qslot --class \'$class\'  python $script -w $wl -p $prefix -o $odir -c $cfg_file -a $arch -l -d $sdir");
	#print "python $script -w $wl -p $prefix -o $odir -c $cfg_file -a $arch -l -d $sdir\n";
}
close(FILE);
