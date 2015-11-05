#!/usr/intel/bin/perl5.14.1
use Getopt::Long;
use Cwd 'abs_path';
use File::Basename qw( dirname );
use FindBin '$Bin';
use strict;
require "$Bin/gc_lib.pm";

print "#\$Header:  2006/05/04 16:10:08 sfu Exp $ \ ";
print "\n\n";

&GetOptions("gc=s",
            "csv=s",
            "gen=s",
            "help",
            "d",
            "debug");

our %count;
my %inst_cnt;
my %infra = (
    "CLKGLUE"    => 1,
    "NONCLKGLUE" => 1,
    "DFX"        => 1,
    "DOP"        => 1,
    "SMALL"      => 1,
    "Assign"     => 1,
    );

&read_gc_csv ($::opt_gc, "ref");
&read_inst_cnt($::opt_csv);
my $gen = $::opt_gen;
print "";
my %total;
foreach my $cluster (sort keys %count) {
    foreach my $unit (sort keys %{$count{$cluster}}) {
        if (defined $inst_cnt{$cluster}{$unit}) {
            $total{$cluster} += $inst_cnt{$cluster}{$unit} * $count{$cluster}{$unit}{$gen}{ref};
        } else {
            if ($infra{$unit}) {
                $total{$cluster} += $count{$cluster}{$unit}{$gen}{ref};
            } else {
                if ($count{$cluster}{$unit}{$::opt_gen}{ref}>1) {
                    printf("bad %-10s %-10s %10.2f\n", $cluster, $unit, $count{$cluster}{$unit}{$::opt_gen}{ref});
                } else {
                    printf("ok  %-10s %-10s %10.2f\n", $cluster, $unit, $count{$cluster}{$unit}{$::opt_gen}{ref});
                }
            }
        }
    }
}
print "\n"x2;
my $total;
foreach my $cluster (sort keys %total) {
    printf ("%-10s %20s %10.3f\n", $cluster, "", $total{$cluster}/1000);
    $total += $total{$cluster};

    next if (! $::opt_d);
    foreach my $unit (sort keys %{$count{$cluster}}) {
        printf ("%-10s %-20s %10.3f %3d\n", "", $unit, $count{$cluster}{$unit}{$gen}{ref}/1000, $inst_cnt{$cluster}{$unit});
    }
}
printf ("%-10s %10.3f\n", "total" , $total/1000000);


sub read_inst_cnt {
    my ($file) = @_;

    my $fh;
    open ($fh, $file) || die "could not open residency file for instance count $file";
    while (<$fh>) {
        if (/^num/) {
            my ($temp, $cnt) = (split /,/, $_)[0,1];
            $temp =~ s/^num_?//;
            $temp =~ s/L3_Bank/L3.Bank/;
            my ($cluster, $unit) = (split /_/, $temp, 2);
            $cluster =~ s/L3.Bank/L3_Bank/;
            if (! $unit) { $unit = $cluster; }
            $inst_cnt{$cluster}{$unit} = $cnt;
        }
    }
    close $fh;
}
