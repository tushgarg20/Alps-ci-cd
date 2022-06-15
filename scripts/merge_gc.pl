#!/usr/intel/bin/perl5.14.1
use Getopt::Long;
use Cwd 'abs_path';
use File::Basename qw( dirname );
use FindBin '$Bin';
use strict;
require "$Bin/gc_lib.pm";

my $bin = "/nfs/fm/disks/fm_cse_04449/sfu/perl";
require "$bin/gc_lib.pm";

&GetOptions("ref=s",
            "new=s",
            "gen=s",
            "out=s",
            "debug");

if ($::opt_h || $::opt_help || ! defined $::opt_ref || ! defined $::opt_new || ! defined $::opt_gen) {
    &print_help();
    exit();
}

our %count;
my @gen_list = sort split ',', $::opt_gen;

my @orig_gen_list = &read_gc_csv ($::opt_ref, "old");
my @new_gen_list  = &read_gc_csv ($::opt_new, "new");

my %out_gen = ();
splice (@orig_gen_list, 0, 0, @gen_list);
foreach my $gen (sort @orig_gen_list) {
    $out_gen{$gen} = 1;
}
my %new_gen;
foreach my $gen (sort @gen_list) {
    $new_gen{$gen} = 1;
}
my @out_gen_list = sort by_gen keys %out_gen;

my $fo;
if (defined $::opt_out) {
    open ($fo, "> $::opt_out") || die "could not create output $::opt_out";
} else {
    $fo = *STDOUT;
}
print $fo "Unit,Cluster,";
foreach my $gen (@out_gen_list) {
    print $fo "$gen,";
}
print $fo "\n";
print "";
foreach my $cluster (sort keys %count) {
    foreach my $unit (sort keys %{$count{$cluster}}) {
        print $fo "$unit,$cluster,";
        foreach my $gen (@out_gen_list) {
            my $type = "old";
            my $out_num;
            if (@new_gen{$gen}) {
                $type = "new";
            }
            if (defined $count{$cluster}{$unit}{$gen}{$type}) {
                $out_num = $count{$cluster}{$unit}{$gen}{$type};
            } else {
                $out_num = 1;
            }
            print $fo "$out_num,";
        }
        print $fo "\n";
    }
}


sub print_help {
    my $path = abs_path($0);
    print "
$path -ref gc.csv_#1 -new gc.csv_#2 -gen Gen10LP,Gen11

    merge gate count numbers on specified Gen from new gc.csv to ref gc.csv
";
}
