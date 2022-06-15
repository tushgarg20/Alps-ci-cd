#!/usr/intel/bin/perl5.14.1
use Getopt::Long;
use Cwd 'abs_path';
use File::Basename qw( dirname );
use FindBin '$Bin';
use strict;
require "$Bin/gc_lib.pm";

&GetOptions("ref=s",
            "new=s",
            "gen=s",
            "h",
            "help",
            "debug");

if ($::opt_h || $::opt_help || ! defined $::opt_ref || ! defined $::opt_new || ! defined $::opt_gen) {
    &print_help();
    exit();
}

our %count;
my @gen_list = sort split ',', $::opt_gen;

my @old_gen_list = &read_gc_csv ($::opt_ref, "old");
&read_gc_csv ($::opt_new, "new");

printf ("%s  | ", " "x30);
foreach my $gen (@gen_list) {
    printf (" %25s %-s | ", $gen, " "x20);
}
print "\n";
printf ("%-10s %-20s | ", "cluster", "unit");
foreach my $gen (@gen_list) {
    printf (" %10s %10s %12s  %10s | ", "old", "new", "new-old", "%age")
}
print "\n";

foreach my $cluster (sort keys %count) {
    foreach my $unit (sort keys %{$count{$cluster}}) {
        printf ("%-10s %-20s | ", $cluster, $unit);
        foreach my $gen (@gen_list) {
            my $flag = 1;
            if (defined $count{$cluster}{$unit}{$gen}{old}) {
                printf (" %10.2f", $count{$cluster}{$unit}{$gen}{old});
            } else {
                printf (" %-10s",   "-");
                $flag = 0;
            }
            if (defined $count{$cluster}{$unit}{$gen}{new}) {
                printf (" %10.2f", $count{$cluster}{$unit}{$gen}{new});
            } else {
                printf (" %10s",   "-");
                $flag = 0;
            }
            if ($flag && $count{$cluster}{$unit}{$gen}{old}>0) {
            } else {
                printf (" %12s  %10s | ",   "-", "-");
                next;
            }
            printf (" %12.2f %10.2f%% | ",
                    ($count{$cluster}{$unit}{$gen}{new} - $count{$cluster}{$unit}{$gen}{old}),
                    ($count{$cluster}{$unit}{$gen}{new} - $count{$cluster}{$unit}{$gen}{old}) * 100 / $count{$cluster}{$unit}{$gen}{old});
        }
        print "\n";
    }
}

sub print_help {
    my $path = abs_path($0);
    print "
$path -ref gc.csv_#1 -new gc.csv_#2 -gen Gen10LP,Gen11

    compare gate count numbers on specified Gen from two gc.csv files
";
}
