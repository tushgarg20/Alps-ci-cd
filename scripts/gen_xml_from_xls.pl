#!/usr/intel/bin/perl5.20.1
use Getopt::Long;
use Cwd 'abs_path';
use File::Basename qw( dirname );
use strict;

BEGIN {
    push @INC, "/usr/intel/pkgs/perl/5.20.1/lib64/module/r1";
}
use Spreadsheet::XLSX;

&GetOptions("html=s",
            "xls=s",
            "csv=s",
            "help",
            "debug");

#my %cfg_list = (
#    'BDW gt2 1x3x8' =>             'Gen8_GT2',
#    'BDW gt3 2x3x8' =>             'Gen8_GT3',
#    'BXT 3x6(bxt_a.cfg)' =>        'BXT',
#    'CHV 2x8' =>                   'CHV',
 #   'CNL gt1 3x8' =>               'Gen10_GT2',
  #  'CNL gt2 5x8' =>               'Gen10_GT2p5',
   # 'CNL gt3 9x8' =>               'Gen10_GT4',
#    'CNL_H 2X4X4X8' =>             'Gen11_Halo',

    #'ICL 2X4X8' =>                 'Gen11_GT2',
    #'ICL 4X4X8' =>                 'Gen11_GT3',
#    'KBL Halo(5x3x8)' =>           'KBL_Halo',
    #'SKL gt2 1x3x8' =>             'Gen9_GT2',
    #'SKL gt3 2x3x8' =>             'Gen9_GT3',
    #'SKL gt3 2x3x8(W/O EDRAM)' =>  'Gen9_GT3_no_eDRAM',
#    'SKL gt4(3x3x8)' =>            'Gen9_GT4',
#    'SKL gt4(3x3x8)(W/O EDRAM)' => 'Gen9_GT4_no_eDRAM',
#);

my @cfg_rlist;
my %wkld_cr;



my %cfg_data;
# &read_csv    ($::opt_csv);
if ($::opt_html) { &read_html   ($::opt_html); }
if ($::opt_xls)  { &read_fot_xls($::opt_xls);  }
&print_xml ();

sub read_csv {
    my ($file) = @_;
    my $fh;
    open ($fh, $file) || die "could not open config csv $file";
    my $header = <$fh>;
    my $c;
    my %field;
    my @f_name;
    chomp $header;
    $header =~ s/
//;
    foreach my $item (split /,/, $header) {
        $field{$item} = $c;
        $f_name[$c] = $item;
        $c++;
    }

    while (<$fh>) {
        chomp;
        s/
//;
        my @item = split /,/, $_;

        # my $cfg = $cfg_list{$item[0]};
        my $cfg = $item[0];
        for (my $i=1; $i<=$#item; $i++) {
            $cfg_data{$cfg}{$f_name[$i]} = $item[$i]
        }
        print "";
    }
    close $fh;
}

sub read_html {
    my ($file) = @_;

    my $fh;

    open ($fh, $file) || die "could not open html file $file";
    while (<$fh>) {
        last if (/.h4.Version: WW38_2015..h4./);
    }
    while (<$fh>) {
        last if (/Correction Ratios/);
    }
    while (<$fh>) {
        last if (/<\/tr>/);
        if (/nbsp/) {
            s/\&nbsp//g;
            s/;//g;
            my ($cfg, $cmax, $freq) = (split)[0,2,4];
            print "";
            $cfg_data{$cfg}{cmax} = $cmax;
            $cfg_data{$cfg}{freq} = $freq;
            push @cfg_rlist, $cfg;
        }
    }
    while (<$fh>) {
        last if (/<tbody>/);
    }
    while (<$fh>) {
        last if (/<tr>/);
    }
    while (1) {
        my $line;
        $line = <$fh>; $line =~ />(.*)</;  my $api   = $1;
        $line = <$fh>; $line =~ />(.*)</;  my $title = $1;
        $line = <$fh>; $line =~ />(.*)</;  my $setting = $1;
        $line = <$fh>; $line =~ />(.*)</;  my $capture = $1;
        $line = <$fh>; $line =~ />(.*)</;  my $drv = $1;
        # $line = <$fh>; $line =~ />(.*)</;  my $cr_gen8 = $1;
        # $line = <$fh>; $line =~ />(.*)</;  my $cr_chv  = $1;
        $line = <$fh>; $line =~ />(.*)</;  my $cr_gen9 = $1;
        $line = <$fh>;
        my $wkld = join "=", ($api, $title, $setting, $capture, $drv);
        # $wkld_cr{$wkld}{gen8} = $cr_gen8;
        # $wkld_cr{$wkld}{chv}  = $cr_chv;
        $wkld_cr{$wkld}{gen9} = $cr_gen9;
        if ($line =~ /^$/) {
        } else {
            print "parsing error $line\n";
        }
        foreach my $cfg (@cfg_rlist) {
            $line = <$fh>; $line =~ />(.*)</; $cfg_data{$cfg}{som}{$wkld} = $1;
            $line = <$fh>; $line =~ />(.*)</; $cfg_data{$cfg}{fps}{$wkld} = $1;
            $line = <$fh>; $line =~ />(.*)</; $cfg_data{$cfg}{ar}{$wkld}  = $1;
            $line = <$fh>; $line =~ />(.*)</; $cfg_data{$cfg}{car}{$wkld} = $1;
        }

        while (<$fh>) {
            last if (/<tr>/);
        }
        print "";

        last if (eof($fh));
    }
    print "";
    close $fh;
}

sub print_xml {
    print "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n";
    print "<fot>\n";

    &print_xml_version();
    &print_xml_config();
    &print_xml_wkld();

    print "</fot>\n";

}

sub print_xml_version {
    print "  <version_info>\n";

    my $release = "ALPS-G Release";
    my $version = "WW11_2021";

    print "    <release_info>$release</release_info>\n";
    print "    <version>$version</version>\n";

    print "  </version_info>\n";
}

sub print_xml_config {

    print "  <config_info>\n";

    foreach my $cfg (@cfg_rlist) {
        print "    <config>\n";
        print "      <config_name>",               $cfg,                     "</config_name>\n";
        print "      <cdyn_max>",                  $cfg_data{$cfg}{cmax},    "</cdyn_max>\n";
        print "      <gt_frequency>",              $cfg_data{$cfg}{freq},    " MHz</gt_frequency>\n";
        print "      <voltage>",                   $cfg_data{$cfg}{volt},    "</voltage>\n";
        print "      <ring_frequency>",            $cfg_data{$cfg}{ring},    " MHz</ring_frequency>\n";
        print "      <memspeed>",                  $cfg_data{$cfg}{mem},     "</memspeed>\n";
        print "      <LLC>",                       $cfg_data{$cfg}{llc}/1024,     " MB</LLC>\n";
        my $edram = $cfg_data{$cfg}{edram};
        $edram =~ s/M$//;
        print "      <EDRAM>",                     $edram,  " MB</EDRAM>\n";
        print "      <unsliced_sliced_frequency>", $cfg_data{$cfg}{ratio},   "</unsliced_sliced_frequency>\n";
        print "    </config>\n";
    }
    print "  </config_info>\n";
}

sub print_xml_wkld {

    my @old_configs = ("LKF 1x8x8","RKL 1x2x16","SKL GT2 1x3x8","SKL GT3 2x3x8 w/ no eDRAM","SKL GT3 2x3x8","CNL GT2 3x8","CNL GT3 5x8","CNL GT4 9x8","ICLLP GT2 1x8x8","Gen12LP 1x6x16","Gen12LP DashG 1x6x16","ADL 1x6x16","DG2 8x4x16","Xe2 X4 (4x10x16)","Xe2 X2 (5x4x16)","Xe2 X3 (7x4x16)", "MTL-HP32-m10","MTL-HP64-m10", "MTL-HP96-m10", "MTL-HP128-m10", "MTL-HP192-m10", "MTL-HP144-m10 3x3x16", "MTL-HP144-m10 3x4x12", "MTL-HP160-m10 2x5x16", "MTL-HP160-m10 2x4x20","LNL 64 (1x4x16)","LNL 80 (1x4x20)","LNL 80 (1x5x16)","LNL 72 (1x6x12)","LNL 96 (1x6x16)","LNL 96 (2x3x16)","LNL 128 (2x4x16)","LNL 160 (2x4x20)","LNL 160 (2x5x16)","LNL 144 (2x6x12)","LNL 144 (3x3x16)","LNL 256 (4x4x16)","LNL 192 (3x4x16)", "LNL 64 2xSP (1x4x16)","LNL 80 2xSP (1x4x20)","LNL 80 2xSP (1x5x16)","LNL 72 2xSP (1x6x12)","LNL 96 2xSP (1x6x16)","LNL 96 2xSP (2x3x16)","LNL 128 2xSP (2x4x16)","LNL 160 2xSP (2x4x20)","LNL 160 2xSP (2x5x16)","LNL 144 2xSP (2x6x12)","LNL 144 2xSP (3x3x16)","LNL 256 2xSP (4x4x16)","LNL 192 2xSP (3x4x16)");
    my @gen11_configs = ("ICL GT2 2x4x8","ICL GT3 4x4x8");
    my @gen12hp_configs = ("TGLHP 8x4x16","TGLHP 6x4x16");
    my @pvc_configs = ("PVC 16x4x16","PVC_A21 14x4x16","PVC-DP 16x4x16", "PVC-DP-A21 14x4x16");
 
    foreach my $wkld (keys %wkld_cr) {
        my ($api, $title, $setting, $capture, $drv) = split '=', $wkld;
        next if ($setting =~ /rkrn-\d/ && $title =~ /video/);

        print "  <workload>\n";
        print "    <api>",     $api,     "</api>\n";
        print "    <title>",   $title,   "</title>\n";
        print "    <setting>", $setting, "</setting>\n";
        print "    <capture>", $capture, "</capture>\n";
        print "    <driver>",  $drv,     "</driver>\n";

        print "    <correction_ratio>\n";
        foreach my $gen (keys %{$wkld_cr{$wkld}}) {
            print "       <$gen>", $wkld_cr{$wkld}{$gen} ,"</$gen>\n";
        }
        print "    </correction_ratio>\n";
        
	
        foreach my $cfg (@cfg_rlist) {
            next if ($cfg_data{$cfg}{som}{$wkld} == 0);
	    if ($cfg ~~ @old_configs){
	        print "    <config>\n";
                print "      <cfg>",            $cfg,         "</cfg>\n";
                print "      <sum_of_weights>", $cfg_data{$cfg}{som}{$wkld}, "</sum_of_weights>\n";
                print "      <FPS>",            $cfg_data{$cfg}{fps}{$wkld}, "</FPS>\n";
                print "      <AR>",             $cfg_data{$cfg}{ar}{$wkld},  "</AR>\n";
                print "      <corrected_AR>",   $cfg_data{$cfg}{car}{$wkld}, "</corrected_AR>\n";
                print "    </config>\n";
                
		}
            elsif ($cfg ~~ @gen11_configs){
	        print "    <config>\n";
                print "      <cfg>",            $cfg,         "</cfg>\n";
                print "      <sum_of_weights>", $cfg_data{$cfg}{som}{$wkld}, "</sum_of_weights>\n";
                print "      <FPS>",            $cfg_data{$cfg}{fps}{$wkld}, "</FPS>\n";
		print "      <GT_AR>",             $cfg_data{$cfg}{gt_ar}{$wkld},  "</GT_AR>\n";
		print "      <Slice_AR>",             $cfg_data{$cfg}{slice_ar}{$wkld},  "</Slice_AR>\n";
		print "      <Unslice_AR>",             $cfg_data{$cfg}{unslice_ar}{$wkld},  "</Unslice_AR>\n";
		print "      <corrected_GT_AR>",   $cfg_data{$cfg}{cgtar}{$wkld}, "</corrected_GT_AR>\n";
		print "      <corrected_Slice_AR>",   $cfg_data{$cfg}{csar}{$wkld}, "</corrected_Slice_AR>\n";
                print "      <corrected_Unslice_AR>",   $cfg_data{$cfg}{cunsar}{$wkld}, "</corrected_Unslice_AR>\n";
                print "    </config>\n";
		}
	    elsif ($cfg ~~ @gen12hp_configs){
	        print "    <config>\n";
                print "      <cfg>",            $cfg,         "</cfg>\n";
                print "      <sum_of_weights>", $cfg_data{$cfg}{som}{$wkld}, "</sum_of_weights>\n";
                print "      <FPS>",            $cfg_data{$cfg}{fps}{$wkld}, "</FPS>\n";
		print "      <GT_AR>",             $cfg_data{$cfg}{gt_ar}{$wkld},  "</GT_AR>\n";
		print "      <EU_DSSM_AR>",             $cfg_data{$cfg}{eu_dssm_ar}{$wkld},  "</EU_DSSM_AR>\n";
		print "      <RO3D_AR>",             $cfg_data{$cfg}{ro3d_ar}{$wkld},  "</RO3D_AR>\n";
		print "      <corrected_GT_AR>",   $cfg_data{$cfg}{cgtar}{$wkld}, "</corrected_GT_AR>\n";
		print "      <corrected_EU_DSSM_AR>",   $cfg_data{$cfg}{cedar}{$wkld}, "</corrected_EU_DSSM_AR>\n";
                print "      <corrected_RO3D_AR>",   $cfg_data{$cfg}{crar}{$wkld}, "</corrected_RO3D_AR>\n";
                print "    </config>\n";
	    }
	    elsif ($cfg ~~ @pvc_configs){
	        print "    <config>\n";
                print "      <cfg>",            $cfg,         "</cfg>\n";
                print "      <sum_of_weights>", $cfg_data{$cfg}{som}{$wkld}, "</sum_of_weights>\n";
                print "      <FPS>",            $cfg_data{$cfg}{fps}{$wkld}, "</FPS>\n";
		print "      <Chiplet_AR>",             $cfg_data{$cfg}{chiplet_ar}{$wkld},  "</Chiplet_AR>\n";
		print "      <Rambo_Base_AR>",             $cfg_data{$cfg}{rambo_base_ar}{$wkld},  "</Rambo_Base_AR>\n";

		print "      <corrected_Chiplet_AR>",   $cfg_data{$cfg}{ccar}{$wkld}, "</corrected_Chiplet_AR>\n";
                print "      <corrected_Rambo_Base_AR>",   $cfg_data{$cfg}{crbar}{$wkld}, "</corrected_Rambo_Base_AR>\n";
                print "    </config>\n";
	    }
	    else{
	        print "    <config>\n";
                print "      <cfg>",            $cfg,         "</cfg>\n";
                print "      <sum_of_weights>", $cfg_data{$cfg}{som}{$wkld}, "</sum_of_weights>\n";
                print "      <FPS>",            $cfg_data{$cfg}{fps}{$wkld}, "</FPS>\n";
		print "      <GT_AR>",             $cfg_data{$cfg}{gt_ar}{$wkld},  "</GT_AR>\n";
	        print "      <EU_AR>",             $cfg_data{$cfg}{eu_ar}{$wkld},  "</EU_AR>\n";
                print "      <NonEU_AR>",             $cfg_data{$cfg}{noneu_ar}{$wkld},  "</NonEU_AR>\n";
		print "      <corrected_GT_AR>",   $cfg_data{$cfg}{cgtar}{$wkld}, "</corrected_GT_AR>\n";
		print "      <corrected_EU_AR>",   $cfg_data{$cfg}{ceuar}{$wkld}, "</corrected_EU_AR>\n";
		print "      <corrected_NonEU_AR>",   $cfg_data{$cfg}{cnoneuar}{$wkld}, "</corrected_NonEU_AR>\n";
                print "    </config>\n";
	    }
        }
        print "  </workload>\n";
    }


}

sub read_fot_xls {
    my ($file) = @_;
    my @old_configs = ("LKF 1x8x8","RKL 1x2x16","SKL GT2 1x3x8","SKL GT3 2x3x8 w/ no eDRAM","SKL GT3 2x3x8","CNL GT2 3x8","CNL GT3 5x8","CNL GT4 9x8","ICLLP GT2 1x8x8","Gen12LP 1x6x16","Gen12LP DashG 1x6x16","ADL 1x6x16","DG2 8x4x16","Xe2 X4 (4x10x16)","Xe2 X2 (5x4x16)","Xe2 X3 (7x4x16)",  "MTL-HP32-m10","MTL-HP64-m10", "MTL-HP96-m10", "MTL-HP128-m10", "MTL-HP192-m10", "MTL-HP144-m10 3x3x16", "MTL-HP144-m10 3x4x12", "MTL-HP160-m10 2x5x16", "MTL-HP160-m10 2x4x20","LNL 64 (1x4x16)","LNL 80 (1x4x20)","LNL 80 (1x5x16)","LNL 72 (1x6x12)","LNL 96 (1x6x16)","LNL 96 (2x3x16)","LNL 128 (2x4x16)","LNL 160 (2x4x20)","LNL 160 (2x5x16)","LNL 144 (2x6x12)","LNL 144 (3x3x16)","LNL 256 (4x4x16)","LNL 192 (3x4x16)", "LNL 64 2xSP (1x4x16)","LNL 80 2xSP (1x4x20)","LNL 80 2xSP (1x5x16)","LNL 72 2xSP (1x6x12)","LNL 96 2xSP (1x6x16)","LNL 96 2xSP (2x3x16)","LNL 128 2xSP (2x4x16)","LNL 160 2xSP (2x4x20)","LNL 160 2xSP (2x5x16)","LNL 144 2xSP (2x6x12)","LNL 144 2xSP (3x3x16)","LNL 256 2xSP (4x4x16)","LNL 192 2xSP (3x4x16)");
    my @gen11_configs = ("ICL GT2 2x4x8","ICL GT3 4x4x8");
    my @gen12hp_configs = ("TGLHP 8x4x16","TGLHP 6x4x16");
    my @pvc_configs = ("PVC 16x4x16", "PVC_A21 14x4x16", "PVC-DP 16x4x16", "PVC-DP-A21 14x4x16");

    
    my $wb = Spreadsheet::XLSX->new($file);
    my $ws = $wb->worksheet('ALPS cfg');
    my $row_data = 0;
    for (my $row = 0; $row<=$ws->{MaxRow}; $row++) {
        my $cell  = $ws->get_cell($row, 0);
        my $value = $cell->value();
        if ($value eq "Configs") {
            $row_data = $row;
            last;
        }
    }
    my %header;
    for (my $col = $ws->{MinCol}; $col<= $ws->{MaxCol}; $col++) {
        my $cell = $ws->get_cell($row_data, $col);
        if (! $cell) { next; }
        my $value = $cell->value();
        if ($value eq "") {
            last;
        }
        $header{$value} = $col;
    }
    for (my $row = $row_data+1; $row<=$ws->{MaxRow}; $row++) {
        my $cell = $ws->get_cell($row, 0);
        if (! $cell) {
            next;
        }
        my $value = $cell->value();
        my $cfg = &gen_cfg_name($value);
        $cell  = $ws->get_cell($row, $header{"Voltage"});
        $value = $cell->value();
        $cfg_data{$cfg}{volt} = $value;
        $cell  = $ws->get_cell($row, $header{"Freq of crclk"});
        $value = $cell->value();
        $cfg_data{$cfg}{freq} = $value;
        $cell  = $ws->get_cell($row, $header{"Cdynmax"});
        $value = $cell->value();
        $cfg_data{$cfg}{cmax} = $value;
        $cell  = $ws->get_cell($row, $header{"Freq of ring"});
        $value = $cell->value();
        $cfg_data{$cfg}{ring} = $value;
        $cell  = $ws->get_cell($row, $header{"Memspeed"});
        $value = $cell->value();
        $cfg_data{$cfg}{mem} = $value;
        $cell  = $ws->get_cell($row, $header{"LLC Size"});
        $value = $cell->value();
        $cfg_data{$cfg}{llc} = $value;
        $cell  = $ws->get_cell($row, $header{"EDRAM"});
        $value = $cell->value();
        $cfg_data{$cfg}{edram} = $value;
        $cell  = $ws->get_cell($row, $header{"Unsliced frequency w.r.t. crclk"});
        $value = $cell->value();
        $cfg_data{$cfg}{ratio} = $value;

        push @cfg_rlist, $cfg;
    }
    print "";

    
    my $ws  = $wb->worksheet('fot_data');
    my $tab = chr(160);

    for (my $col = $ws->{MinCol}; $col<= $ws->{MaxCol}; $col++) {
        my $cell = $ws->get_cell(0, $col);
        if (! $cell) {
            next;
        }
        my $value = $cell->value();
        my $cfg   = &gen_cfg_name($value);
        next if (! $cfg);
        $cfg_data{$cfg}{col}  = $col;
    }
    my $row_data = 0;
    for (my $row=2; $row<=$ws->{MaxRow}; $row++) {
        my $cell  = $ws->get_cell($row, 0);
        my $value = $cell->value();
        if ($value eq "api") {
            $row_data = $row;
            last;
        }
    }

    for (my $row=$row_data+1; $row<=$ws->{MaxRow}; $row++) {
        my ($cell, $api, $title, $setting, $capture, $drv);
        $cell = $ws->get_cell($row, 0); if ($cell) { $api     = $cell->value(); }
        $cell = $ws->get_cell($row, 1); if ($cell) { $title   = $cell->value(); }
        $cell = $ws->get_cell($row, 2); if ($cell) { $setting = $cell->value(); }
        $cell = $ws->get_cell($row, 3); if ($cell) { $capture = $cell->value(); }
        $cell = $ws->get_cell($row, 4); if ($cell) { $drv     = $cell->value(); }
        # printf ("%-6s %-30s %-30s %-10s %-20s\n", $api, $title, $setting, $capture, $drv);
        my $idx = $api."=".$title."=".$setting."=".$capture."=".$drv;

        # $cell = $ws->get_cell($row, 5); if ($cell) { $wkld_cr{$idx}{gen8} = $cell->value(); }
        # $cell = $ws->get_cell($row, 6); if ($cell) { $wkld_cr{$idx}{chv}  = $cell->value(); }
        $cell = $ws->get_cell($row, 5); if ($cell) { $wkld_cr{$idx}{gen9} = $cell->value(); }

        foreach my $cfg (keys %cfg_data) {
	    if ($cfg ~~ @old_configs){
	        my $col = $cfg_data{$cfg}{col};
                my ($cell, $som, $fps, $ar, $car);
                $cell = $ws->get_cell($row, $col+0); if ($cell) { $som = $cell->{Val}; }
                $cell = $ws->get_cell($row, $col+1); if ($cell) { $fps = $cell->{Val}; }
                $cell = $ws->get_cell($row, $col+2); if ($cell) { $ar  = $cell->{Val}; }
                $cell = $ws->get_cell($row, $col+3); if ($cell) { $car = $cell->{Val}; }
                print "";
                next if ($som == 0);
                $cfg_data{$cfg}{som}{$idx} = sprintf("%.3f", $som);
                $cfg_data{$cfg}{fps}{$idx} = sprintf("%.3f", $fps);
                $cfg_data{$cfg}{ar}{$idx}  = sprintf("%.3f", $ar);
                $cfg_data{$cfg}{car}{$idx} = sprintf("%.3f", $car);
	    
                
		}
	   elsif ($cfg ~~ @gen11_configs){
	        my $col = $cfg_data{$cfg}{col};
                my ($cell, $som, $fps, $gt_ar, $slice_ar, $unslice_ar, $cgtar, $csar, $cunsar );
                $cell = $ws->get_cell($row, $col+0); if ($cell) { $som = $cell->{Val}; }
                $cell = $ws->get_cell($row, $col+1); if ($cell) { $fps = $cell->{Val}; }
		$cell = $ws->get_cell($row, $col+2); if ($cell) { $gt_ar  = $cell->{Val}; }
		$cell = $ws->get_cell($row, $col+3); if ($cell) { $slice_ar  = $cell->{Val}; }
		$cell = $ws->get_cell($row, $col+4); if ($cell) { $unslice_ar  = $cell->{Val}; }
		$cell = $ws->get_cell($row, $col+5); if ($cell) { $cgtar = $cell->{Val}; }
		$cell = $ws->get_cell($row, $col+6); if ($cell) { $csar = $cell->{Val}; }
		$cell = $ws->get_cell($row, $col+7); if ($cell) { $cunsar = $cell->{Val}; }
                print "";
                next if ($som == 0);
                $cfg_data{$cfg}{som}{$idx} = sprintf("%.3f", $som);
                $cfg_data{$cfg}{fps}{$idx} = sprintf("%.3f", $fps);
		$cfg_data{$cfg}{gt_ar}{$idx}  = sprintf("%.3f", $gt_ar);
		$cfg_data{$cfg}{slice_ar}{$idx}  = sprintf("%.3f", $slice_ar);
		$cfg_data{$cfg}{unslice_ar}{$idx}  = sprintf("%.3f", $unslice_ar);
		$cfg_data{$cfg}{cgtar}{$idx} = sprintf("%.3f", $cgtar);
		$cfg_data{$cfg}{csar}{$idx} = sprintf("%.3f", $csar);
		$cfg_data{$cfg}{cunsar}{$idx} = sprintf("%.3f", $cunsar);
		}
	    elsif ($cfg ~~ @gen12hp_configs){
	        my $col = $cfg_data{$cfg}{col};
                my ($cell, $som, $fps, $gt_ar, $eu_dssm_ar, $ro3d_ar, $cgtar, $cedar, $crar );
                $cell = $ws->get_cell($row, $col+0); if ($cell) { $som = $cell->{Val}; }
                $cell = $ws->get_cell($row, $col+1); if ($cell) { $fps = $cell->{Val}; }
		$cell = $ws->get_cell($row, $col+2); if ($cell) { $gt_ar  = $cell->{Val}; }
		$cell = $ws->get_cell($row, $col+3); if ($cell) { $eu_dssm_ar  = $cell->{Val}; }
		$cell = $ws->get_cell($row, $col+4); if ($cell) { $ro3d_ar  = $cell->{Val}; }
		$cell = $ws->get_cell($row, $col+5); if ($cell) { $cgtar = $cell->{Val}; }
		$cell = $ws->get_cell($row, $col+6); if ($cell) { $cedar = $cell->{Val}; }
		$cell = $ws->get_cell($row, $col+7); if ($cell) { $crar = $cell->{Val}; }
                print "";
                next if ($som == 0);
                $cfg_data{$cfg}{som}{$idx} = sprintf("%.3f", $som);
                $cfg_data{$cfg}{fps}{$idx} = sprintf("%.3f", $fps);
		$cfg_data{$cfg}{gt_ar}{$idx}  = sprintf("%.3f", $gt_ar);
		$cfg_data{$cfg}{eu_dssm_ar}{$idx}  = sprintf("%.3f", $eu_dssm_ar);
		$cfg_data{$cfg}{ro3d_ar}{$idx}  = sprintf("%.3f", $ro3d_ar);
		$cfg_data{$cfg}{cgtar}{$idx} = sprintf("%.3f", $cgtar);
		$cfg_data{$cfg}{cedar}{$idx} = sprintf("%.3f", $cedar);
		$cfg_data{$cfg}{crar}{$idx} = sprintf("%.3f", $crar);
		}
	    elsif ($cfg ~~ @pvc_configs){
	        my $col = $cfg_data{$cfg}{col};
                my ($cell, $som, $fps, $chiplet_ar, $rambo_base_ar, $ccar, $crbar );
                $cell = $ws->get_cell($row, $col+0); if ($cell) { $som = $cell->{Val}; }
                $cell = $ws->get_cell($row, $col+1); if ($cell) { $fps = $cell->{Val}; }
		$cell = $ws->get_cell($row, $col+2); if ($cell) { $chiplet_ar  = $cell->{Val}; }

		$cell = $ws->get_cell($row, $col+3); if ($cell) { $rambo_base_ar  = $cell->{Val}; }
		$cell = $ws->get_cell($row, $col+4); if ($cell) { $ccar = $cell->{Val}; }
		$cell = $ws->get_cell($row, $col+5); if ($cell) { $crbar = $cell->{Val}; }

                print "";
                next if ($som == 0);
                $cfg_data{$cfg}{som}{$idx} = sprintf("%.3f", $som);
                $cfg_data{$cfg}{fps}{$idx} = sprintf("%.3f", $fps);
		$cfg_data{$cfg}{chiplet_ar}{$idx}  = sprintf("%.3f", $chiplet_ar);
		$cfg_data{$cfg}{rambo_base_ar}{$idx}  = sprintf("%.3f", $rambo_base_ar);

		$cfg_data{$cfg}{ccar}{$idx} = sprintf("%.3f", $ccar);
		$cfg_data{$cfg}{crbar}{$idx} = sprintf("%.3f", $crbar);

		}
	    else{
	        my $col = $cfg_data{$cfg}{col};
                my ($cell, $som, $fps, $gt_ar, $eu_ar, $noneu_ar, $cgtar, $ceuar, $cnoneuar );
                $cell = $ws->get_cell($row, $col+0); if ($cell) { $som = $cell->{Val}; }
                $cell = $ws->get_cell($row, $col+1); if ($cell) { $fps = $cell->{Val}; }
		$cell = $ws->get_cell($row, $col+2); if ($cell) { $gt_ar  = $cell->{Val}; }
	        $cell = $ws->get_cell($row, $col+3); if ($cell) { $eu_ar  = $cell->{Val}; }
		$cell = $ws->get_cell($row, $col+4); if ($cell) { $noneu_ar  = $cell->{Val}; }
		$cell = $ws->get_cell($row, $col+5); if ($cell) { $cgtar = $cell->{Val}; }
		$cell = $ws->get_cell($row, $col+6); if ($cell) { $ceuar = $cell->{Val}; }
		$cell = $ws->get_cell($row, $col+7); if ($cell) { $cnoneuar = $cell->{Val}; }
                print "";
                next if ($som == 0);
                $cfg_data{$cfg}{som}{$idx} = sprintf("%.3f", $som);
                $cfg_data{$cfg}{fps}{$idx} = sprintf("%.3f", $fps);
		$cfg_data{$cfg}{gt_ar}{$idx}  = sprintf("%.3f", $gt_ar);
	        $cfg_data{$cfg}{eu_ar}{$idx}  = sprintf("%.3f", $eu_ar);
		$cfg_data{$cfg}{noneu_ar}{$idx}  = sprintf("%.3f", $noneu_ar);
		$cfg_data{$cfg}{cgtar}{$idx} = sprintf("%.3f", $cgtar);
		$cfg_data{$cfg}{ceuar}{$idx} = sprintf("%.3f", $ceuar);
		$cfg_data{$cfg}{cnoneuar}{$idx} = sprintf("%.3f", $cnoneuar);
	   }
        }
    }
    print "";
}

sub gen_cfg_name {
    my ($name) = @_;

    if (! $name || $name =~ /Version/ || $name =~ /Ratio/) {
        return 0;
    }

    $name =~ tr/A-Z/a-z/;

    if ($name =~ /bdw/i) {
        if ($name =~ /(1.3.8)/) { return "BDW GT2 $1"; }
        if ($name =~ /(2.3.8)/) { return "BDW GT3 $1"; }
		

    }
    if ($name =~ /skl/i) {
        my $edram = "";
        if ($name =~ /edram/i)  { $edram = " w/ no eDRAM"; }
        if ($name =~ /(1.3.8)/) { return "SKL GT2 $1$edram"; }
        if ($name =~ /(2.3.8)/) { return "SKL GT3 $1$edram"; }
        if ($name =~ /(3.3.8)/) { return "SKL GT4 $1$edram"; }
    }
    if ($name =~ /kbl/i) {
        if ($name =~ /(5.3.8)/) { return "KBL Halo $1"; }
    }
    if ($name =~ /cnl/i) {
        if ($name =~ /(3.8)/) { return "CNL GT2 $1"; }
        if ($name =~ /(5.8)/) { return "CNL GT3 $1"; }
        if ($name =~ /(9.8)/) { return "CNL GT4 $1"; }
    }
    if ($name =~ /icl/i) {
        if ($name =~ /2.4.8/) { return "ICL GT2 2x4x8"; }
        if ($name =~ /4.4.8/) { return "ICL GT3 4x4x8"; }
		
	}
    if ($name =~ /dashg/i){
        return "Gen12LP DashG 1x6x16";
	}
    if ($name =~ /adl/i){
        return "ADL 1x6x16";
	}
    if ($name =~ /dg2 8x4x16/i){
        return "DG2 8x4x16";
	}
    if ($name =~ /mtl-hp96/i){
        return "MTL-HP96-m10";
    }
    if ($name =~ /mtl-hp64/i){
        return "MTL-HP64-m10";
    }
    if ($name =~ /mtl-hp32/i){
        return "MTL-HP32-m10";
    }
    if ($name =~ /mtl-hp128/i){
        return "MTL-HP128-m10";
    }
    if ($name =~ /mtl-hp192/i){
        return "MTL-HP192-m10";
    }
    if ($name =~ /mtl-hp/i){
        if ($name =~ /3.3.16/) {return "MTL-HP144-m10 3x3x16";}
        if ($name =~ /3.4.12/) {return "MTL-HP144-m10 3x4x12";}
        if ($name =~ /2.5.16/) {return "MTL-HP160-m10 2x5x16";}
        if ($name =~ /2.4.20/) {return "MTL-HP160-m10 2x4x20";}
    }
    if ($name =~ /lnl/i){
        if ($name =~ /2xSP/i){
        if ($name =~ /1.4.16/) {return "LNL 64 2xSP (1x4x16)";}
        if ($name =~ /1.4.20/) {return "LNL 80 2xSP (1x4x20)";}
        if ($name =~ /1.5.16/) {return "LNL 80 2xSP (1x5x16)";}
        if ($name =~ /1.6.12/) {return "LNL 72 2xSP (1x6x12)";}
        if ($name =~ /1.6.16/) {return "LNL 96 2xSP (1x6x16)";}
        if ($name =~ /2.3.16/) {return "LNL 96 2xSP (2x3x16)";}
        if ($name =~ /2.4.16/) {return "LNL 128 2xSP (2x4x16)";}
        if ($name =~ /2.4.20/) {return "LNL 160 2xSP (2x4x20)";}
        if ($name =~ /2.5.16/) {return "LNL 160 2xSP (2x5x16)";}
        if ($name =~ /2.6.12/) {return "LNL 144 2xSP (2x6x12)";}
        if ($name =~ /3.3.16/) {return "LNL 144 2xSP (3x3x16)";}
        if ($name =~ /4.4.16/) {return "LNL 256 2xSP (4x4x16)";}
        if ($name =~ /3.4.16/) {return "LNL 192 2xSP (3x4x16)";}
        }else{
        if ($name =~ /1.4.16/) {return "LNL 64 (1x4x16)";}
        if ($name =~ /1.4.20/) {return "LNL 80 (1x4x20)";}
        if ($name =~ /1.5.16/) {return "LNL 80 (1x5x16)";}
        if ($name =~ /1.6.12/) {return "LNL 72 (1x6x12)";}
        if ($name =~ /1.6.16/) {return "LNL 96 (1x6x16)";}
        if ($name =~ /2.3.16/) {return "LNL 96 (2x3x16)";}
        if ($name =~ /2.4.16/) {return "LNL 128 (2x4x16)";}
        if ($name =~ /2.4.20/) {return "LNL 160 (2x4x20)";}
        if ($name =~ /2.5.16/) {return "LNL 160 (2x5x16)";}
        if ($name =~ /2.6.12/) {return "LNL 144 (2x6x12)";}
        if ($name =~ /3.3.16/) {return "LNL 144 (3x3x16)";}
        if ($name =~ /4.4.16/) {return "LNL 256 (4x4x16)";}
        if ($name =~ /3.4.16/) {return "LNL 192 (3x4x16)";}
        }
    }
    if ($name =~ /Xe2 x4/i){
        return "Xe2 X4 (4x10x16)";
    }
    if ($name =~ /Xe2 x2/i){
        return "Xe2 X2 (5x4x16)";
    }
    if ($name =~ /Xe2 x3/i){
        return "Xe2 X3 (7x4x16)";
    }
    if ($name =~ /gen12lp/i) {
        return "Gen12LP 1x6x16"; 
	}
    if ($name =~ /lkf/i) {
        return "LKF 1x8x8"; 
	}
    if ($name =~ /rkl/i) {
        return "RKL 1x2x16"; 
	}
   if($name =~ /gen12hp/i){
	if ($name =~ /8.4.16/) {return "TGLHP 8x4x16";}
	if ($name =~ /6.4.16/) {return "TGLHP 6x4x16";}
	    

	}
   if ($name =~ /pvc/i)
   {
    if ($name =~ /dp/i) 
    {
        if($name =~ /a21/i)
        {
            return "PVC-DP-A21 14x4x16";
        }
        else
        {
            return "PVC-DP 16x4x16";
        }
    }
    else
    {
        if($name =~ /a21/i) 
        {
            return "PVC_A21 14x4x16";
        }
        else
        {
            return "PVC 16x4x16";
        }
    }
   }

	       
    if ($name =~ /lp/i) {
	    	
		 return "ICLLP GT2 1x8x8";       
	}
	
     if ($name =~ /bxt/i) {
        return "BXT 3x6";
    }
    
	if ($name =~ /glv/i) {

        return "GLV 3x6"; 
	}
    return 0;
}
