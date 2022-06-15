###########################################
############# USAGE #######################
# perl collate_gsim_stat_files.pl <run_area> <Output_directory where files need to be copied to>
###########################################
###########################################

use strict;
use warnings;

my $dir = shift;
my $odir = shift;

$dir .= '/' if $dir !~ /\/$/;
$odir .= '/' if $odir !~ /\/$/;

my $summary = $dir . "data/summary.csv";
open(FILE,"< $summary") or die "Can't open $summary\n";

my %status;
my %header;
my $line = <FILE>; $line =~ s /\r//g; chomp($line);
my @headers = split/,/,$line;
my $count = 0;
foreach my $head (@headers){
	$header{$head} = $count;
	$count++;
}

while($line = <FILE>){
	$line =~ s/\r//g ;chomp($line);
	my @data = split/,/,$line;
	my $cfg = $data[$header{"level_name"}];
	my @cfg_data = split/\//,$cfg;
	$cfg = $cfg_data[3]; ##check your data/summary.csv file to check if this index(3) is right. Alter to suit otherwise.
	my $src_dir = $data[$header{"test_dir"}];
	my $dest_name = $data[$header{"test_args"}];
	my @des_data = split/ /,$dest_name;
	$dest_name = $des_data[0];
	$dest_name =~ s/\//\./g;
	my $chunked = $data[$header{"chunk_info"}];
	my $result = $data[$header{"result"}];
	
	if($result eq "failed" or $result eq "crashed" or $result eq "missing"){
		$status{$cfg}{$dest_name} = $result;
		next;
	}
	if($result eq "passed" or $result eq "ran"){
		my $stat_file =  $dir . "tests/" . $src_dir . "/" . "psim.stat.gz";
		my $dest_stat_file = $odir . $cfg ."/" . $dest_name . ".stat.gz";
        system("mkdir $odir$cfg") unless (-d $odir.$cfg);
        system("cp $stat_file $dest_stat_file");
		print "cp $stat_file $dest_stat_file\n";
		$status{$cfg}{$dest_name} = $result;
		next;
	}
	# if($result eq "running"){
		# my $log_file = $dir . "tests/" . $src_dir . "/" . "net_batch.txt";
		# my $res = qx(zgrep "Result:" $log_file);
		# chomp($res);
		# if($res eq ''){
			# $status{$cfg}{$dest_name} = "running";
			# next;
		# }
		# my @d = split/Result: /,$res;
		# my $final_res = $d[-1];
		# if($final_res eq "failed" or $final_res eq "crashed"){
			# $status{$cfg}{$dest_name} = $final_res;
			# next;
		# }
		# if($final_res eq "passed" or $final_res eq "ran"){
			# my $stat_file =  $dir . "tests/" . $src_dir . "/" . "psim.stat";
			# my $dest_stat_file = $odir . $cfg ."/" . $dest_name . ".stat";
			# system("mkdir $odir$cfg") unless (-d $odir.$cfg);
			# system("cp $stat_file $dest_stat_file");
			# #print "cp $stat_file $dest_stat_file\n";
			# $status{$cfg}{$dest_name} = $final_res;
			# next;
		# }
	# }
	if($result eq "running"){
		my $log_file = $dir . "tests/" . $src_dir . "/" . "runlog.txt";
		my @res = qx(grep "Result:" $log_file);
		if(scalar @res == 0){
			$status{$cfg}{$dest_name} = "running";
			next;
		}
		my $final_res = "passed";
		foreach my $r (@res){
			chomp($r);
			my @d = split/Result: /,$r;
			$r = $d[-1];
			if($r eq "failed" or $r eq "crashed" or $r eq "missing" or $r eq "ran"){
				$final_res = $r;
			}
		}

		if($final_res eq "failed" or $final_res eq "crashed" or $final_res eq "missing"){
			$status{$cfg}{$dest_name} = $final_res;
			next;
		}
		if($final_res eq "passed" or $final_res eq "ran"){
			my $stat_file =  $dir . "tests/" . $src_dir . "/" . "psim.stat.gz";
			my $dest_stat_file = $odir . $cfg ."/" . $dest_name . ".stat.gz";
            system("mkdir $odir$cfg") unless (-d $odir.$cfg);
			system("cp $stat_file $dest_stat_file");
			print "cp $stat_file $dest_stat_file\n";
			$status{$cfg}{$dest_name} = $final_res;
			next;
		}
	}
	
}
close(FILE);

my @cfgs = sort keys %status;

foreach my $c (@cfgs){
	my @frames = sort keys %{$status{$c}};
	print $c . "\n";
	foreach my $frame (@frames){
		print $frame . "\t" . $status{$c}{$frame} . "\n";
	}
	print "\n------------------------------------------------------\n";
}
