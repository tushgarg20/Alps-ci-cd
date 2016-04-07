#!/usr/intel/bin/perl5.14.1
use Getopt::Long;
use Cwd 'abs_path';
use File::Basename qw( dirname );
use strict;

print "#\$Header:  2006/05/04 16:10:08 sfu Exp $ \ ";
print "\n\n";

&GetOptions("dir=s",
            "help",
            "debug");

my $dh;
if (! -e "$::opt_dir/data/summary.csv.json") {
    print "could not find $::opt_dir/data/summary.csv.json\n";
    exit (-1);
}


my $fh;
open ($fh, "$::opt_dir/data/summary.csv.json") || die "could not open";
my $line = <$fh>;
chomp $line;
my @hash = split /[\[\]]/, $line;

print "";

$hash[$#hash-1] =~  s/\"//g;
my $field_line = $hash[$#hash-1];
my $cnt_stop   = $#hash;
if ($field_line =~ /^level_name/) {
} else {
    $field_line = 'level_name,test,test_index,path,frame_weight,category,device,sim_type,psim_config,indigo,build_type,result,run_time,max_chunk_time,time_cpu_user,start_time,end_time,stats,misscorrelation,clocks,error_info,error_percent,test_args,override_args,test_dir,chunk_info,chunk_split';
    $cnt_stop += 1;
}

my @field = split /,/, $field_line;
our %result_type = ();

my @data_hash;
for (my $i=0; $i/2<$cnt_stop; $i++) {
    my $temp = $hash[$i*2+1];
    next if ($temp =~ /level_name/);
    $temp =~ s/\"//g;
    my @item = split /,/, $temp;
    for (my $j=0; $j<=$#item; $j++) {
        $data_hash[$i]{$field[$j]} = $item[$j];
    }
}
my %data_stat;
for (my $i=0; $i<=$#data_hash; $i++) {
    my $data   = $data_hash[$i];
    my $level  = $data->{level_name};
    my $result = $data->{result};
    my $test   = $data->{test_args};
    my $cfg    = $data->{psim_config};

    $level = join '/', (split /\//, $level)[-2,-1];
    $data_stat{$level}{$cfg}{$result}{$test} = $i;
    $result_type{$result} = 1;
}

print "";
printf ("%-20s", "");
foreach my $level (sort keys %data_stat) {
    foreach my $cfg (sort keys %{$data_stat{$level}}) {
        printf (" %-15s", $level);
    }
}
print "\n";
printf ("%-20s", "");
foreach my $level (sort keys %data_stat) {
    foreach my $cfg (sort keys %{$data_stat{$level}}) {
        printf (" %-15s", $cfg);
    }
}
print "\n";
print "-"x20;
foreach my $level (sort keys %data_stat) {
    foreach my $cfg (sort keys %{$data_stat{$level}}) {
        print "-"x16;
    }
}
print "\n";
foreach my $type (sort keys %result_type) {
    printf ("%-8s", $type);
    foreach my $level (sort keys %data_stat) {
        foreach my $cfg (sort keys %{$data_stat{$level}}) {
            if ($data_stat{$level}{$cfg}{$type}) {
                printf (" %15d", scalar keys %{$data_stat{$level}{$cfg}{$type}});
            } else {
                printf (" %15s", "-");
            }
        }
    }
    print "\n";
}
print "\n";

foreach my $type ( qw(crashed failed missing ran passed running) ) {
    print "-- $type --\n";
    foreach my $level (sort keys %data_stat) {
        foreach my $cfg (sort keys %{$data_stat{$level}}) {
            foreach my $frame (sort keys %{$data_stat{$level}{$cfg}{$type}}) {
                my $idx = $data_stat{$level}{$cfg}{$type}{$frame};
                printf ("%-20s %-20s %-50s %-70s",
                        $cfg, $level,
                        $data_hash[$idx]->{'path'},
                        $data_hash[$idx]->{'test'});
                if ($type eq "passed" || $type eq "running") { print "\n"; next;}
                printf ("%s\n", $data_hash[$idx]->{'error_info'});
            }
        }
    }
}
