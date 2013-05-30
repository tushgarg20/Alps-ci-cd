package map_suit2trace;

use diagnostics -verbose;
use strict;
use Data::Dumper;

use output_functions;


my $studylist = "/nfs/iil/proj/mpgarch/proj_work_01/jhillel_work/willy-coho/coho/regress/IDC/study_06Q4ww41_ST.idc.tlist";
my @suits = ("server", "games", "multimedia", "DH", "productivity", "FSPEC00", "ISPEC00", "FSPEC06", "ISPEC06", "workstation", "office", "kernels", "all");
my %suits2traces;
my %traces2suits;


################# map suits to traces
### usage: map_suit2trace()
sub map_suit2trace
{
	foreach my $suit (@suits)	# add the "categories" suits including "all" suit
	{
		my $suit_grep = $suit;
		if ($suit eq "all") {$suit_grep = "";}
		add_traces2suit_from_file($suit, "trace_list -file $studylist -simple $suit_grep");
#		print "$suit " . @{$suits2traces{$suit}} . "\n";
	}

	add_traces2suit_from_file("shay_tracelist", "cat /nfs/iil/proj/mpgarch/proj_work_01/jhillel_work/ALPS/scripts/config/tracelist_shay.txt");	# add Shay's typical applications suit
	add_traces2suit_from_file("7TDP", "cat /nfs/iil/proj/mpgarch/proj_work_01/jhillel_work/ALPS/scripts/config/tracelist_7TDP_070114.txt");	# add TDP suit
	add_traces2suit_from_file("17TDP", "cat /nfs/iil/proj/mpgarch/proj_work_01/jhillel_work/ALPS/scripts/config/tracelist_17TDP_070111.txt");	# add TDP suit
	add_traces2suit_from_file("35TDP", "cat /nfs/iil/proj/mpgarch/proj_work_01/jhillel_work/ALPS/scripts/config/tracelist_35TDP_070111.txt");	# add TDP suit
	add_traces2suit_from_file("top350", "cat /nfs/iil/proj/mpgarch/proj_work_01/jhillel_work/ALPS/scripts/config/tracelist_350_070114.txt");	# add top 350 suit

	foreach my $suit ("DH", "games", "multimedia", "office", "productivity")
	{
		add_suit2suit($suit, "client_segment");
	}
	foreach my $suit ("server", "workstation", "FSPEC00", "ISPEC00", "FSPEC06", "ISPEC06")
	{
		add_suit2suit($suit, "server_segment");
	}


	foreach my $suit (@suits)
	{
		print "$suit " . @{$suits2traces{$suit}} . "\n";
	}

	return 1;
}
#################


################# get traces for suit
### usage: get_traces4suit($suit, \@traces)
sub get_traces4suit
{
	if (@_ != 2) {return 0;}
	my ($suit, $traces) = @_;

	if (defined $suits2traces{$suit})
	{
		foreach my $trace (@{$suits2traces{$suit}})
		{
			push @$traces, $trace;
		}
	}
	else
	{
		output_functions::print_to_log("Didn't find any traces for suit $suit\n");
		return 0;
	}
	return 1;
}
#################


################# return the suits
### usage: suits()
sub suits
{
	return @suits;
}
#################


################# add traces to a suit from file
### usage: add_traces2suit_from_file($suit, $cmd)
sub add_traces2suit_from_file
{
	if (@_ != 2) {return 0;}
	my ($suit, $cmd) = @_;

	my @traces;
	my @lines = `$cmd`;
	foreach my $line (@lines)
	{
		chomp $line;
		$line =~ s/\r$//;
		$line =~ s/.*\///;
#		print "$suit $line\n";
		push @traces, $line;
	}
	add_traces2suit($suit, \@traces);

	return 1;
}
#################


################# add traces to a suit
### usage: add_traces2suit($suit, \@traces)
sub add_traces2suit
{
	if (@_ != 2) {return 0;}
	my ($suit, $traces) = @_;

	my $new_suit = "yes";
	foreach my $s (@suits)
	{
		if ($s eq "$suit") {$new_suit = "no";}
	}
	if ($new_suit eq "yes") {push @suits, $suit;}

	foreach my $trace (@$traces)
	{
		push @{$suits2traces{$suit}}, $trace;
		push @{$traces2suits{$trace}}, $suit;
	}

	return 1;
}
#################


################# add suit to a suit
### usage: add_suit2suit($suit2add, $target_suit)
sub add_suit2suit
{
	if (@_ != 2) {return 0;}
	my ($suit2add, $target_suit) = @_;

	my $new_suit = "yes";
	foreach my $s (@suits)
	{
		if ($s eq "$target_suit") {$new_suit = "no";}
	}
	if ($new_suit eq "yes") {push @suits, $target_suit;}

	my @traces;
	get_traces4suit($suit2add, \@traces);
	foreach my $trace (@traces)
	{
		push @{$suits2traces{$target_suit}}, $trace;
		push @{$traces2suits{$trace}}, $target_suit;
	}

	return 1;
}
#################


1;
