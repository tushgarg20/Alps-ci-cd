#!/usr/intel/pkgs/perl/5.8.5/bin/perl

use strict;

use warnings;

use Getopt::Long;

my $input_file = "";
my $output_file = "";

my $help = "";

GetOptions ("input=s" => \$input_file,
#           "fub=s" => \$fub,
            "output=s" => \$output_file,
#           "hier=i" => \$hier,
#           "flatten" => \$flatten,
#           "ucasepi" => \$ucasepi,
#           "lcasepi" => \$lcasepi,
            "help" => \$help);

if ($help) {
  print "Usage: validate_residency.pl -input <file containing Gennysim residencies> [-output <validation output file>] [-help]\n";
  exit -1;
}

if ($input_file =~ /^$/) {
  print "-E-: input file with Gennysim residencies is compulsory\n";
  print "Usage: validate_residency.pl -input <file containing Gennysim residencies> [-output <validation output file>] [-help]\n";
  exit -1;
}

if ($output_file =~ /^$/) {
  $output_file = "residency_validation.csv";
  print "-I-: Output file not provided\n";
  print "-W-: Using $output_file as the output file...will be overwritten if exists\n";
}

if (!open(OPFILE, ">$output_file")) {
  print "-E- : Could not open $output_file for writing\n" ;
  exit -1;
}

open(IFILE,"$input_file") or die "Can't open input file $input_file:$!";

print OPFILE "$input_file\n\n";

print OPFILE "FUB, Total Residency\n";

my %unit_res_val;
my %multi_name_units;

#my $multi_name_unit_flag;

while(<IFILE>) {
  my $line = $_;
  chomp($line);
  if ($line =~ /Power State,Residency/) {next;}
  my @parts = split(/,/, $line);
  my $no_of_parts = scalar(@parts);
  if ($no_of_parts > 2) {
    print "-E-: Error in file syntax\n";
    exit -1;
  }
  my $state_unit = $parts[0];
  my $res_val = $parts[1];
  my @parts_of_unit;
  my $unit_name;
  if ($state_unit =~ /Cache|RAM|CAM|LatFifo/i) {next;}	
  if ($state_unit =~ /^PS0/) {
    @parts_of_unit = split(/_/, $state_unit);
    if (scalar(@parts_of_unit) > 2) {
      my $dummy = shift @parts_of_unit;	
      $unit_name = join("_", @parts_of_unit);
      $multi_name_units{"$unit_name"} = scalar(@parts_of_unit);	
    } else {
      $unit_name = $parts_of_unit[1];
      #$unit_res_val{"$unit_name"} = $res_val;
    }
    $unit_res_val{"$unit_name"} = $res_val;
  } elsif ($state_unit =~ /(^PS1)|(^PS2)/) {
    @parts_of_unit = split("_", $state_unit);
    my $unit_name_1;
    my $unit_name_2;
    $unit_name_1 = $parts_of_unit[1];
    my $dummy = shift @parts_of_unit;
    $unit_name_2 = join("_", @parts_of_unit);
    if (exists $unit_res_val{"$unit_name_2"}) 
    {
      #$unit_name = $unit_name_2; 
      $unit_res_val{"$unit_name_2"} += $res_val; 
      next;
    }
    if ($unit_name_2 eq "SVSM_ANYPIXELMODE") {$unit_name_1 = "SVSM";}
    if ($unit_name_2 eq "SVSM_MTADAPTER_ANYPIXELMODE") {$unit_name_1 = "SVSM_MTADAPTER";}
    if (exists $unit_res_val{"$unit_name_1"}) {$unit_res_val{"$unit_name_1"} += $res_val;}
  } elsif ($state_unit =~ /(^EM|^FPU)/) {
    if ($state_unit =~ /(Utilization|Idle)/) {next;}
    if ($state_unit =~ /^EM/) {$unit_name = "EM";}
    if ($state_unit =~ /^FPU/) {$unit_name = "FPU";}
    if (exists $unit_res_val{"$unit_name"}) 
    {
      $unit_res_val{"$unit_name"} += $res_val;
    } else {
      $unit_res_val{"$unit_name"} = $res_val;
    }
  } else {
    next;
  }
}

my $elem;

foreach $elem (keys %unit_res_val) {
  print OPFILE $elem.", ".$unit_res_val{"$elem"}."\n";
}

close IFILE;
close OPFILE;
