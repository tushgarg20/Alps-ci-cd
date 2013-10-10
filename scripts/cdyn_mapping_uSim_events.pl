#!/usr/bin/env perl

#########################################################################
# This file creates the Cdyn file for ALPS-U
#
# Author    :   Vinod George
# Contributors: Arijit Mukhopadhyay
# Date      :   Oct 01, 2012
#
# Usage: perl cdyn_mapping_uSim_events.pl -e eu_usim_power_stats_1.csv -i ../Inputs/cdyn.csv -o ../Inputs/cdyn_alps-u.csv
#########################################################################

use strict;
use Getopt::Long;
use Pod::Usage;
use POSIX;
use FindBin qw($Bin);
use cdyn_usim_event_map;

use lib "$Bin";

my $cdyn_uSim_event_map_gen8_pointer     = &cdyn_usim_event_map::get_cdyn_usim_event_map_gen8();
my %cdyn_uSim_event_mapping_gen8         = %$cdyn_uSim_event_map_gen8_pointer;
my $cdyn_uSim_event_map_gen9_pointer     = &cdyn_usim_event_map::get_cdyn_usim_event_map_gen9();
my %cdyn_uSim_event_mapping_gen9         = %$cdyn_uSim_event_map_gen9_pointer;

##################################################
# Knobs and Cmdline Processing
##################################################
my $k_help                 = "";
my $k_man                  = "";
my $k_eventfile               = "";
my $k_infile               = "";
my $k_outfile              = "";

Getopt::Long::GetOptions(
        "help|h"           => \$k_help,
        "man|m"            => \$k_man,
        "eventfile|e=s"    => \$k_eventfile,
        "infile|i=s"       => \$k_infile,
        "outfile|o=s"      => \$k_outfile
) or Pod::Usage::pod2usage(-exitstatus => 1, -verbose =>1);

Pod::Usage::pod2usage(-exitstatus => 0, -verbose => 1) if $k_help;
Pod::Usage::pod2usage(-exitstatus => 0, -verbose => 2) if $k_man;


die "No input file specified\n" if $k_infile eq "";
die "No event file specified\n" if $k_eventfile eq "";
open (INFILE, "<$k_infile") or die "Cannot Open File $k_infile : $!\n";
open (EVENTFILE, "<$k_eventfile") or die "Cannot Open File $k_eventfile : $!\n";
open (OUTFILE, ">$k_outfile") or die "Cannot Open File $k_outfile : $!\n";

my $line = <INFILE>;
my @header = split /,/, $line;
my $num_cols = $#header;

print OUTFILE $line;
close(INFILE);
while(<EVENTFILE>){
    $line = $_;
    if($line =~ /(.*)/){
        my $usim_event = $1;
        if(exists $cdyn_uSim_event_mapping_gen8{$1}){
            my $cdyn_event = $cdyn_uSim_event_mapping_gen8{$usim_event}; 
            open (INFILE, "<$k_infile") or die "Cannot Open File $k_infile : $!\n";
            $line = <INFILE>;
            @header = split /,/, $line;
            $num_cols = $#header;
           
            while(<INFILE>){
                $line = $_;
                if($line =~ /(.*),(.*),(.*),(.*),(.*),(.*),/){
                    my $arch = $2;
                    if($cdyn_event eq $1 && $arch eq "Gen8"){
                        #print STDOUT $cdyn_event . "==" . $1 . "\n";
                        print OUTFILE $usim_event . "," . $2  ."," . $3 ."," . $4 ."," . $5 ."," . $6 . ",\n"  ;
                        close(INFILE);
                        last;
                    }
                }
            }
        } 
        if(exists $cdyn_uSim_event_mapping_gen9{$1}){
            my $cdyn_event = $cdyn_uSim_event_mapping_gen9{$usim_event}; 
            open (INFILE, "<$k_infile") or die "Cannot Open File $k_infile : $!\n";
            $line = <INFILE>;
            @header = split /,/, $line;
            $num_cols = $#header;
           
            while(<INFILE>){
                $line = $_;
                if($line =~ /(.*),(.*),(.*),(.*),(.*),(.*),/){
                    my $arch = $2;
                    if($cdyn_event eq $1 && $arch eq "Gen9LPClient"){
                        #print STDOUT $cdyn_event . "==" . $1 . "\n";
                        print OUTFILE $usim_event . "," . $2  ."," . $3 ."," . $4 ."," . $5 ."," . $6 . ",\n"  ;
                        close(INFILE);
                        last;
                    }
                }
            }
        } 
    }
}
close(EVENTFILE);
close(OUTFILE);
