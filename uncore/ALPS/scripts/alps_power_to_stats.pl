#!/usr/bin/perl
#
# Script by Kevin Theobald
# Extracts power data from ALPS output and appends to Keiko stats files

$firsttracepos = 14;   # Column number of first trace
$space_margin = 25000; # Should have at least 25M of space before uncompressing
$helpstring =
  "\nalps_power_to_stats.pl -s S -e E [-c C] [-a A] [-n N] [-p] [-d] [-D]\n" .
  "   S: stats dir  E: exp  C: pwr config  A: ALPS dir  N: ALPS name\n"
  . "\nalps_power_to_stats.pl -h    for help\n\n";
@alps_globs = ("*_FOO.xls.gz", "*_FOO.txt.gz", "*.FOO.xls.gz",
               "power_formulas.FOO.*", "power_output.FOO.*",
               "power_txt_output_functions.FOO.*");

my $ind;
my $argcnt = @ARGV;
my $bad = $argcnt ? 0 : 1;  # Guarantee print short help msg
for ($ind = 0; $ind < $argcnt; $ind++) {
  $switch = $ARGV[$ind];
  if ($switch =~ /^-/) {
    if ($switch =~ /-h/) {
      print $helpstring;
      write;
      exit;
    } elsif ($switch =~ /^-p/) {
      $usepool = 1;
      next;
    } elsif ($switch =~ /^-d/) {
      $postdelete = 1;
      next;
    } elsif ($switch =~ /^-D/) {
      $postdelete = 2;
      next;
    } else {   # Assume 1 arg
      $arg = $ARGV[++$ind];
      if ($ind >= $argcnt || $arg =~ /^-/) {   # Missing arg?
        $bad = 1;
        redo;  # Go back to look at the switch
      }
      if ($switch =~ /^-s/) {
        $statsdir = $arg
      } elsif ($switch =~ /^-a/) {
        $alpsdir = $arg;
      } elsif ($switch =~ /^-e/) {
        $exp = $arg;
      } elsif ($switch =~ /^-c/) {
        $pwrconfig = $arg;
      } elsif ($switch =~ /^-n/) {
        $alpsexp = $arg;
      } else {
        $bad = 1;
      }
      next;
    }
  }
  $bad = 1;
}
if ($bad) {
  print $helpstring;
  exit;
}
if ($usepool) {
  $pooljobdir = "$statsdir/##COMPRESS##$alpsdir##$pwrconfig##$exp##";
  for ($ind = 1; (-e "$pooljobdir$cnt"); $ind++) {};
  $pooljobdir .= $ind;
  mkdir $pooljobdir || die "Can\'t create temp directory for file compression";
  $pooljobfile = $pooljobdir . '/##';
  $pool_cmd = 'nbq -P pdx_misc_short -C SLES_EM64T_1G -Q ';
  if ($ENV{'NBQSLOT'}) {
    $pool_cmd .= $ENV{'NBQSLOT'} . " -J$pooljobfile";
  } else {
    $pool_cmd .= "/arch/other -J$pooljobfile";
  }
}

$alpsexp = $exp unless ($alpsexp);
$alpsdir = $statsdir unless ($alpsdir);
die "No stats directory (-d) $dir" unless (-d $statsdir);
die "No alps directory (-a) $alpsdir" unless (-d $alpsdir);
my $alpspath = "$alpsdir/power_txt_output_fubs.$alpsexp.";
my $alpsname1 = $alpspath . 'capacitance.xls';
$traces = extract_stats($alpsname1, 'ALPS_POWER_Cdyn_');
print "WARNING: NO FILE $alpsname1\nNO Cdyn STATS GENERATED\n" unless ($traces);
@traces = split /\t/, $traces;
if ($pwrconfig) {
  my $alpsname2 = $alpspath . "$pwrconfig.xls";
  $traces2 = extract_stats($alpsname2, 'ALPS_POWER_mW_');
  if ($traces2) {
    die "Discrepency in trace names between $alpsname1 and $alpsname2"
      if ($traces && ($traces ne $traces2));
    @traces = split /\t/, $traces2;
  } else {
    print "WARNING: NO FILE $alpsname2\nNO pwr STATS GENERATED\n";
  }
}
unless ($traces || $traces2) {
  print "WARNING: NO ALPS STATS TO WORK WITH;\n" .
    "ANY PREVIOUS STATS IN FILES WILL NOT BE CHANGED\n";
  exit;
}

$i = 0;
$tracecnt = @traces;

# Post-process power stats
if ($traces) {
  accum('ALPS_POWER_Cdyn_uncore',
        'ALPS_POWER_Cdyn_sa_total', 'ALPS_POWER_Cdyn_llcbos');
  accum('ALPS_POWER_Cdyn_cpu',
        'ALPS_POWER_Cdyn_cores', 'ALPS_POWER_Cdyn_uncore',
        'ALPS_POWER_Cdyn_ddrio');
  delete $lists{'ALPS_POWER_Cdyn_ddrio_static'};
}
if ($traces2) {
  accum('ALPS_POWER_mW_uncore',
        'ALPS_POWER_mW_sa_total', 'ALPS_POWER_mW_llcbos');
  accum('ALPS_POWER_mW_cpu',
        'ALPS_POWER_mW_cores', 'ALPS_POWER_mW_uncore',
        'ALPS_POWER_mW_ddrio', 'ALPS_POWER_mW_ddrio_static');
}

@areanames = sort keys %lists;

foreach $trace (@traces) {
  if ($i >= $firsttracepos) {
    chomp $trace;
    $newstats = '';
    foreach $area (@areanames) {
      $newstats .= "p0.$area " . ${$lists{$area}}[$i] . "\n";
    }
    if (-e "$statsdir/$trace.$exp.gz") {
      $ungunzippable = system "gunzip -t $statsdir/$trace.$exp.gz";
      if ($ungunzippable) {
        print "Problems with stats file; skipping $statsdir/$trace.$exp.gz\n";
        $skipbad[$i] = 1;
      } else {
        has_room($statsdir);   # Wait until enough disk space available
        $ungunzippable = system
          "zgrep -v ALPS_POWER_ $statsdir/$trace.$exp.gz >$statsdir/$trace.$exp";
        if ($ungunzippable) {
          print "Problems uncompressing known good stats file (no disk space?)\n";
          print "Problem is with $statsdir/$trace.$exp.gz\n";
          print "Waiting and trying again...\n";
          sleep 30;
          redo;
        } else {
          open APP, ">> $statsdir/$trace.$exp";
          print APP $newstats;
          close APP;
          if ($usepool) {
            system "$pool_cmd$i gzip -9 -f $statsdir/$trace.$exp";
          } else {
            system "gzip -9 -f $statsdir/$trace.$exp";
          }
        }
      }
    } else {
      die "Can\'t find $statsdir/$trace.$exp.gz";
    }
  }
  $i++;
}
die "Discrepency" unless ($i == $tracecnt);

if ($usepool) {   # Check that the compression worked
  for ($i = $firsttracepos; $i < $tracecnt; $i++) {
    my $logfile = "$pooljobfile$i";
    next if ($skipbad[$i]);  # No log file expected
    while (!(-e $logfile)) {
      sleep 10;
    }
CLOSELOG: while (1) {
      open NBQLOG, $logfile;
      while (<NBQLOG>) {
        if (/\sExit\s+Status\s+:\s+(\d)\s/) {
          close NBQLOG;
          last CLOSELOG if ($1 == 0);
          print "Problems recompressing stats file:\n$traces[$i]\n";
          last CLOSELOG;
        }
      }
      close NBQLOG;
      sleep 10;
    }
    unlink $logfile;
  }
  rmdir $pooljobdir;
}

if ($postdelete) {   # Time to delete unneeded ALPS files
  chdir $alpsdir;
  foreach $globstr (@alps_globs) {
    $globstr =~ s/FOO/$alpsexp/;
    push @deletethese, glob($globstr);
  }
  if ($postdelete >= 2) {
    push @deletethese, glob("power_txt_output_fubs.$alpsexp.*");
  }
  foreach $globstr (@deletethese) {
    unlink $globstr;
  }
}


sub extract_stats {
  my $powerfile, $prefix, $area, $sum;
  ($powerfile, $prefix) = @_;
  $powerfile .= '.gz' unless (-e $powerfile);
  return '' unless (-e $powerfile);
  if ($powerfile =~ /\.gz$/) {
    open POWF, "gzcat $powerfile |" || die "Can\'t read $powerfile";
  } else {
    open POWF, $powerfile || die "Can\'t read $powerfile";
  }
  my $traceline = (<POWF>);
  $traceline = "\n" unless ($traceline);   # Guarantee not empty
  my @traces = split /\t/, $traceline;
  my $junk = (<POWF>);             # IPC
  while (<POWF>) {
    my @values = split /\t/;
    my $i = 0;
    if ($values[3] eq 'sa') {  # Break sa down by FIVR domain
      $area = $prefix . $values[1];
      $sum = $prefix . 'sa_total';
    } elsif ($values[3]) {     # Otherwise, use this domain
      $area = $prefix . $values[3];
      if ($area =~ /\D\d+$/) {
        $sum = $area;
        $sum =~ s/(\D)\d+/\1s/;
      } else {
        $sum = '';
      }
    } else {
      next;    # Skip blank lines
    }
    $lists{$area} = [0] unless ($lists{$area});
    $lists{$sum} = [0] unless (!$sum || $lists{$sum});
    foreach $value (@values) {
      if ($i >= $firsttracepos) {
        ${$lists{$area}}[$i] += $value;
        ${$lists{$sum}}[$i] += $value if ($sum);
      }
      ++$i;
    }
  }
  close POWF;
  return $traceline;
}


sub accum {
  my @froms, $to;
  ($to, @froms) = @_;
  $lists{$to} = [0] unless ($lists{$to});
  foreach $from (@froms) {
    my $i = 0;
    my $size = @{$lists{$from}};
    for ($i = 0; $i < $size; $i++) {
      ${$lists{$to}}[$i] += ${$lists{$from}}[$i];
    }
  }
}

sub has_room {
  my $dir;
  ($dir) = @_;
  while (1) {
    $space = 0;
    open CHECKSPACE, "df -k $dir |";
    while (<CHECKSPACE>) {
      if (/^\s*\d+\s+\d+\s+(\d+)\s/) {
        $space = $1;
        last;
      }
    }
    close CHECKSPACE;
    return if ($space > $space_margin);
    print "Not enough space to work with files safely -- waiting\n";
    sleep 10;
  }
}


format =
This tool extracts power data from ALPS output files, and adds stats (names
starting with ALPS_POWER) to Keiko stats files (replacing any stats made by
this tool previously).  These stats may then be used in rollups or Patriot.

Switches can be in any order.  Upper case letters refer to values in the cmd
line above.  Values cannot start with a - sign.

It is assumed that ALPS has already run, taking Keiko stats files with
experiment name E in directory S (all files S/*.E.gz) and generating power
stats files in directory A (or S if -a not used) with experiment name N (or
E if -n not used), using one or more configs (voltage/frequency segments
defined in the planes file).  If A/power_txt_output_fubs.N.capacitance.xls
exists, these are assumed to be pure Cdyn values, and stats starting with
ALPS_POWER_Cdyn are made.  These are aggregates of individual fubs in the
ALPS file.  Note that the broader aggregates (such as ALPS_POWER_Cdyn_cpu)
span multiple frequency domains, so take Cdyn numbers with a grain of salt.

If -c is specified, then the numbers in A/power_txt_output_fubs.N.C.xls are
used to generate additional stats starting with ALPS_POWER_mW, which are
real dynamic power numbers, using a specific voltage/frequency config.

Using -p will speed things up by using the vlinux5 netbatch pool to recompress
the stats files.  Be sure there are at least 10-20 slots free before using -p.

-d deletes all files in A related to experiment N, except for those needed by
this tool (power_txt_output_fubs*).  Use -D to delete the latter as well.
.

