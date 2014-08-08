use strict;
use Getopt::Long;
use Pod::Usage;
use POSIX;

##################################################
# Knobs and Cmdline Processing
##################################################
my $tracelist			= "";
my $odir			= "";
my $sdir			= "";
my $arch			= '';
my $pool			= '';
my $qslot			= '';
my $annealing			= '';

Getopt::Long::GetOptions(
        "input|i=s"		=> \$tracelist,
	"sdir|s=s"		=> \$sdir,
	"odir|o=s"		=> \$odir,
	"arch|a=s"		=> \$arch,
	"pool|p=s"		=> \$pool,
	"qslot|q=s"		=> \$qslot,
	"annealing"		=> \$annealing
        
) or Pod::Usage::pod2usage(-exitstatus => 1, -verbose =>1);

$sdir .= "/" if $sdir !~ /\/$/;
die "Illegal output directory specification: $sdir!!" unless -e $sdir and -d $sdir;

$odir .= "/" if $odir !~ /\/$/;
die "Illegal output directory specification: $odir!!" unless -e $odir and -d $odir;

my $script = $sdir . "run_alps_nb.py";
my $cfg_file = ($annealing) ? $sdir . "alps_cfg_annealing.yaml" : $sdir . "alps_cfg.yaml"  ;

open(FILE,"<$tracelist") or die "Can't open $tracelist\n";
while(my $line = <FILE>){
	$line =~ s/\r//g; chomp($line);
	my $wl = (split/\.stat/,$line)[0];
	my $prefix = $wl;
	system("nbjob run --target $pool --qslot $qslot  python $script -w $wl -p $prefix -o $odir -c $cfg_file -a $arch -l -d $sdir");
	#print "python $script -w $wl -p $prefix -o $odir -c $cfg_file -a $arch -l -d $sdir\n";
}
close(FILE);
