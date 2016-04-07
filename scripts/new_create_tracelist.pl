use strict;

my $list_file = shift;
open(INFILE,"<$list_file") or die "Can't open $list_file\n";
my $tracefile = $list_file . ".tracelist";
open(OUTFILE,">$tracefile") or die "Can't open $tracefile\n";

while(my $line = <INFILE>)
{
	$line =~ s/\r//g ;chomp($line);
	my @data = ();
	my $suffix = '';

	if($line =~ m/memtrace.aub.gz.yaml/){
		@data = split/\.memtrace\.aub\.gz\.yaml/,$line;
		$suffix = 'memtrace.aub.gz.yaml';
	}
	elsif($line =~ m/stat.gz.yaml/){
		@data = split/\.stat\.gz\.yaml/,$line;
		$suffix = 'stat.gz.yaml';
	}
	else{
		@data = split/\.yaml/,$line;
		$suffix = 'yaml';
	}
	#my @data = split/\.yaml/,$line;
	my @imp = split/_/,$data[0];
	my @api_title = split/\./,$imp[0];
	my $api = $api_title[0];
	my ($title,$setting,$capture,$frame,$driver) = '','','','','';

	if($line =~ /^GPGPU/)
	{
		$api = $api_title[2];
		$driver = $imp[$#imp];
		$setting = $imp[$#imp-1];
		$capture = $imp[$#imp-2];
		$title = $api_title[3] . "-" . $api_title[4] . "-" . $imp[1];
		$frame = 1;
	}
	elsif($line =~ m/3dmk06/)
	{
		$title = $api_title[1] . "-" . $api_title[2];
		$setting = 'null';
		$capture = $imp[2];
		$imp[3] = reverse($imp[3]);
		chop($imp[3]);
		$imp[3] = reverse($imp[3]);
		$frame = $imp[3];
		$driver = $imp[4];
	}
	elsif($line =~ m/3dmkva/ || $line =~ m/3dmk11/)
	{
		$title = $api_title[1] . "-" . $imp[1];
		$setting = $api_title[2];
		$capture = $imp[2];
		$driver = $imp[4];
		$imp[3] = reverse($imp[3]);
		chop($imp[3]);
		$imp[3] = reverse($imp[3]);
		$frame = $imp[3];
	}
	elsif($line =~ m/dx11_3dmk/){
		$api = $imp[0];
		$title = $imp[1];
		$title =~s/\./-/g;
		$setting = $imp[2];
		$capture = $imp[3];
		$imp[4] = reverse($imp[4]);
		chop($imp[4]);
		$frame = reverse($imp[4]);
		$driver = $imp[5];
	}
	elsif($line =~ m/epic-citadel/ || $line =~ m/unigine/){
		$title = $api_title[1];
		$setting = $api_title[2];
		$capture = $imp[2];
		$imp[3] = reverse($imp[3]);
		chop($imp[3]);
		$imp[3] = reverse($imp[3]);
		$frame = $imp[3];
		$driver = $imp[4];
	}
	elsif($line =~ m/ie-fishie/){
		$title = $api_title[1];
		$setting = $api_title[2];
		$capture = $imp[$#imp-2];
		my @stuff = split/-/,$capture;
		$capture = $stuff[1];
		$setting = $setting . "-" . $stuff[0];
		$imp[$#imp-1] = reverse($imp[$#imp-1]);
		chop($imp[$#imp-1]);
		$imp[$#imp-1] = reverse($imp[$#imp-1]);
		$frame = $imp[$#imp-1];
		$driver = $imp[$#imp];
	}
	elsif($line =~ m/ogles_.*glbench27/){
		$title = $imp[1] . "_" . $imp[2];
		$capture = $imp[$#imp-2];
		my @stuff = split/-/,$capture;
		$capture = $stuff[0];
		$setting = $stuff[1];
		$imp[$#imp-1] = reverse($imp[$#imp-1]);
		chop($imp[$#imp-1]);
		$imp[$#imp-1] = reverse($imp[$#imp-1]);
		$frame = $imp[$#imp-1];
		$driver = $imp[$#imp];
	}
	elsif($line =~ m/glbench2p7/){
		@api_title = split/\./,$imp[1];
		$title = $api_title[0] . "_" . $api_title[1];
		$setting = $api_title[2] . "-" . $imp[2];
		$capture = $imp[3];
		$imp[4] = reverse($imp[4]);
		chop($imp[4]);
		$imp[4] = reverse($imp[4]);
		$frame = $imp[4];
		$driver = $imp[5];
	}
	elsif($line =~ m/glbenchmark-2-5-1.*v4\.yaml/){
		my @stuff = split/-/,$api_title[$#api_title];
		$setting = $stuff[$#stuff];
		pop(@stuff);
		my $astr = join("-",@stuff);
		$title = $api_title[1] . "_" . $astr;
		$capture = $imp[$#imp-2];
		$imp[$#imp-1] = reverse($imp[$#imp-1]);
		chop($imp[$#imp-1]);
		$imp[$#imp-1] = reverse($imp[$#imp-1]);
		$frame = $imp[$#imp-1];
		$driver = $imp[$#imp];
	}
	elsif($line =~ m/glbenchmark-2-5-1/){
		my @stuff = split/-/,$imp[2];
		$setting = $stuff[$#stuff];
		pop(@stuff);
		my $astr = join("-",@stuff);
		$title = $imp[1] . "_" . $astr;
		$capture = $imp[$#imp-2];
		$imp[$#imp-1] = reverse($imp[$#imp-1]);
		chop($imp[$#imp-1]);
		$imp[$#imp-1] = reverse($imp[$#imp-1]);
		$frame = $imp[$#imp-1];
		$driver = $imp[$#imp];
	}
	elsif($line =~ m/ogles2p0_.*glbench/){
		$title = $imp[1] . "_" . $imp[2];
		$setting = $imp[3] . "-" . $imp[4];
		$capture = $imp[$#imp-2];
		$imp[$#imp-1] = reverse($imp[$#imp-1]);
		chop($imp[$#imp-1]);
		$imp[$#imp-1] = reverse($imp[$#imp-1]);
		$frame = $imp[$#imp-1];
		$driver = $imp[$#imp];
	}
	elsif($line =~ m/ogles2p0\..*glbench/)
	{
		@api_title = split/\./,$line;
		@imp = split/_/,$api_title[2];
		$title = $api_title[1];
		$setting = $imp[0] . "-" . $imp[1];
		$capture = $imp[2];
		$imp[3] = reverse($imp[3]);
		chop($imp[3]);
		$imp[3] = reverse($imp[3]);
		$frame = $imp[3];
		my @d = split/_/,$line;
		my @dr = split/\.yaml/,$d[$#d];
		$driver = $dr[0];
	}
	elsif($line =~ m/ogles_gfxbench3-0-6_manhattan25x16/){
		$title = $imp[1] . "-manhattan";
		$setting = "25x16";
		$capture = $imp[$#imp-2];
		$imp[$#imp-1] = reverse($imp[$#imp-1]);
		chop($imp[$#imp-1]);
		$imp[$#imp-1] = reverse($imp[$#imp-1]);
		$frame = $imp[$#imp-1];
		$driver = $imp[$#imp];
	}
	elsif($line =~ m/gfxbench3-0-6\.manhattan25x16/){
		$title = $api_title[1] . "-manhattan";
		$setting = "25x16";
		$capture = $imp[$#imp-2];
		$imp[$#imp-1] = reverse($imp[$#imp-1]);
		chop($imp[$#imp-1]);
		$imp[$#imp-1] = reverse($imp[$#imp-1]);
		$frame = $imp[$#imp-1];
		$driver = $imp[$#imp];
	}
	elsif($line =~ m/gfxbench3-0-6\.manhattan/){
		$title = $api_title[1] . "-" . $api_title[2];
		$setting = "19x10";
		$capture = $imp[$#imp-2];
		$imp[$#imp-1] = reverse($imp[$#imp-1]);
		chop($imp[$#imp-1]);
		$imp[$#imp-1] = reverse($imp[$#imp-1]);
		$frame = $imp[$#imp-1];
		$driver = $imp[$#imp];
	}
	elsif($line =~ m/gfxbench3-0-6_manhattan/ || $line =~ m/_gfxbench27_/){
		$title = $imp[1] . "-" . $imp[2];
		$setting = "19x10";
		$capture = $imp[$#imp-2];
		$imp[$#imp-1] = reverse($imp[$#imp-1]);
		chop($imp[$#imp-1]);
		$imp[$#imp-1] = reverse($imp[$#imp-1]);
		$frame = $imp[$#imp-1];
		$driver = $imp[$#imp];
	}
	elsif($line =~ m/\.gfxbench27\./){
		$title = $title = $api_title[1] . "-" . $api_title[2];
		$setting = "19x10";
		$capture = $imp[$#imp-2];
		$imp[$#imp-1] = reverse($imp[$#imp-1]);
		chop($imp[$#imp-1]);
		$imp[$#imp-1] = reverse($imp[$#imp-1]);
		$frame = $imp[$#imp-1];
		$driver = $imp[$#imp];
	}
	else
	{
		$title = $api_title[1];
		$setting = $api_title[2];
		$capture = $imp[$#imp-2];
		$imp[$#imp-1] = reverse($imp[$#imp-1]);
		chop($imp[$#imp-1]);
		$imp[$#imp-1] = reverse($imp[$#imp-1]);
		$frame = $imp[$#imp-1];
		$driver = $imp[$#imp];
	}
	$driver =~ s/\.$//g;
	$driver =~ s/\./-/g;
	print OUTFILE "$api,$title,$setting,$frame,$capture,$driver," . $data[0] . ".$suffix\n";
}
close(INFILE);
close(OUTFILE);
