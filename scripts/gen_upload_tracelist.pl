#!/usr/intel/bin/perl5.14.1
use Getopt::Long;
use Cwd 'abs_path';
use File::Basename qw( dirname );
use strict;

BEGIN {
    push @INC, "/usr/intel/pkgs/perl/5.14.1/lib64/module/r2";
}
use Spreadsheet::XLSX;

# print "#\$Header:  2006/05/04 16:10:08 sfu Exp $ \ ";
# print "\n\n";

&GetOptions("yaml_list=s",
            "yaml_dir=s",
            "out_file=s",
            "help",
            "debug");

my $out_file = $::opt_out_file || "files.tracelist";
my $ofh;
open ($ofh, "> $out_file") || die "could not create $out_file";

our %yaml_list;
if (defined $::opt_yaml_list) {
    &read_yaml_list($::opt_yaml_list);
}
if (defined $::opt_yaml_dir) {
    &read_yaml_dir($::opt_yaml_dir);
}
if ($::opt_debug) {
    printf ("%-10s | %-45s | %-35s | %-25s | %-20s | %s\n",
            qw(api title setting capture num driver));
}
foreach my $file (sort keys %yaml_list) {
    my @data;
    my $suffix;
    $file =~ s/alps_//;
    if($file =~ m/memtrace.aub.gz.yaml/){
        @data = split/\.memtrace\.aub\.gz\.yaml/,$file;
        $suffix = 'memtrace.aub.gz.yaml';
    } elsif($file =~ m/\.memtrace\.yaml/){
        @data = split/\.memtrace\.yaml/,$file;
        $suffix = 'stat.gz.yaml';
    } elsif($file =~ m/stat.gz.yaml/){
        @data = split/\.stat\.gz\.yaml/,$file;
        $suffix = 'stat.gz.yaml';
    } else{
        @data = split/\.yaml/,$file;
        $suffix = 'yaml';
    }
    if ($data[0] =~ s/GPGPU_apps_//) {
        $data[0] =~ s/_throughput_/-throughput-/;
        $data[0] =~ s/_video_/-video-/;
        $data[0] =~ s/_(\d+(-bdw)?)_(rkrn.*)_/_$3_$1_/;
        $data[0] =~ s/_(win-skl)_(rkrn.*)_/_$2_$1_/;
        $data[0] =~ s/(ci-main)/1_$1/;
    }
    if ($data[0] =~ /^apple/ || $data[0] =~ /bf3_p4/ || $data[0] =~ /fishie.25/ ||
        $data[0] =~ /bioshock/) {
        $data[0] =~ s/__/_/;
    }
    if ($data[0] =~ /win-bdw/ || $data[0] =~ /and-..wu/ || $data[0] =~ /hswm/) {
        $data[0] =~ s/__/_/;
    }
    if ($data[0] =~ s/_(250fish)-/-$1_/) {
    }
    if ($data[0] =~ s/(3dmk..)_(perf)_(gt\d)/$1-$3_$2/) {
    }
    if ($data[0] =~ s/_(firestrike)_/-$1-/) {
    }
    if ($data[0] =~ s/_(ice-storm)_/-$1-/) {
    }
    if ($data[0] =~ s/(glbench2p7)_(t-rex)/$1-$2/) {
        $data[0] =~ s/(19x10)_(24c16z)/$1-$2/;
    }
    if ($data[0] =~ s/(gfxbench27)_(ab-t-rex)/$1-$2_/) {
    }
    if ($data[0] !~ /-g2/ && $data[0] =~ s/(3-0-6)_(manhattan)/$1-$2_/) {
    }


    my ($api, $title, $setting, $capture, $num, $driver) = split (/_/, $data[0]);
    if ($num == /^f\d+/) {
        # next;
    }
    $num     =~ s/f0*//;
    $title   =~ s/2p7-t-rex/2p7_t-rex/;
    $setting =  $setting || "19x10";
    if ($::opt_debug) {
        print $data[0], "\n";
        printf ("%-10s | %-45s | %-35s | %-25s | %-20s | %s\n",
                $api, $title, $setting, $capture, $num, $driver);
    } else {
        printf $ofh ("%s,%s,%s,%s,%s,%s,%s\n",$api,$title,$setting,$num,$capture,$driver,"alps_".$file);
    }
}
close $ofh;
if ($::opt_debug) {
} else {
    print "\n-I- $out_file is created for ALICE upload\n";
}

## --------------------------------------------------------------------------------
##
## --------------------------------------------------------------------------------


sub read_yaml_dir {
    my ($dir) = @_;
    my $dh;
    opendir ($dh, $dir) || die "Could not read directory $dir";
    foreach my $file (readdir $dh) {
        if ($file =~ /^alps_.*.yaml$/) {
            $yaml_list{$file} = 1;
        }
    }
}


sub read_yaml_list {
    my ($file) = @_;

    my $fh;
    open ($fh, $file) || die "Could not read file $file";
    while  (<$fh>) {
        chomp;
        $yaml_list{$_};
    }
    close $fh;
}
