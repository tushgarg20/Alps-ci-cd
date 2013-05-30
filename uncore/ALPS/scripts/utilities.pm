#!/usr/intel/bin/perl -w
#
# I require this file in many scripts so I can use these utilities.
# File must end in 1 so that the require will not fail.
# These subroutines can be called if the following lines are added to
# any script:
#BEGIN {
#    ($JDM_HOME) = glob("~jdmorgan");
#    require "$JDM_HOME/bin/utilities.pl";
#}
#

#-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
# openl uses the same syntax as open, but it will properly open
# if the file is gzipped and specified as such, if the file is gzipped
# but the user didn't know that, or if the file is not gzipped.
# you can also send multiple places to look (i.e. staging and archive)
# and it will look in the later places if the first place fails.
# If the file sent is a directory, it does an opendir. Designed to work
# for all legal syntax of open, but also add lots of other features.
#
# On failure, it returns 0 so that you can still do "openl (FILE) or ..."
#
sub openl { # live on failure -- return 0 and print nothing
    my ($FH, $file, @other_locations) = (@_);
    return 0 unless $FH;
    $file ||= ${$FH}; # This makes it so openl (FILE); will work if $FILE holds the filename
    if    (not $file and not scalar @other_locations) { return 0; }
    elsif (not $file) { return openl($FH, @other_locations); } # so elements of the list can be undef or empty
    $file =~ s/^<\s*//; # strip off implied read mode if it is there
    chomp $file;
    if ($file =~ /\|/) { # if $file is a command, can't check for existence, just execute open
        open ($FH, $file) or return 0;
        return $file;
    }
    elsif (-d $file) { # file is a directory
        opendir ($FH, $file) or return 0;
        return $file;
    }
    elsif ($file =~ /^[>+]/) {
        # open is for write or append
        if ($file =~ /\.gz$/i) {
            open ($FH, "| gzip $file") or return 0;
        } else {
            open ($FH, $file) or return 0;
        }
        return $file;
    }
    else { ## Open for read, be smart about gzipped files.
        (my $file_nogz = $file) =~ s/\.gz$//;
        foreach my $test_file ($file, "$file.gz", $file_nogz) {
            next unless (-e $test_file);
            my $is_not_gzipped = `gzip -t $test_file 2>&1`;
            if ($is_not_gzipped =~ /unexpected end of file/) {
                $is_not_gzipped = ($test_file !~ /gz$/) ? 1 : 0;
            }
            if ($is_not_gzipped) {
                open ($FH, $test_file) or return 0;
            } else {
                open ($FH, "gzcat $test_file |") or return 0;
            }
            return $test_file;
        }
    }
    if (not scalar @other_locations) { return 0; }
    return openl($FH, @other_locations);
}

#-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
# Just like "sub openl" but it dies on failure and prints the standard message
use Carp;
sub opend { # die on failure -- print helpful message
    my @copy = grep { $_ } @_;
    shift @copy;
    unshift @copy, ${$_[0]} if (defined ${$_[0]});
    my $success = openl (@_) or croak "$! - @copy\n";
    return $success;
}

#-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
# This is like perl -e except it knows about gzippedness.
# Return the filename or "" if file doesn't exist
# USAGE: if (&dash_e($file)) {}
#          -OR-
#        $file = &dash_e($file) or die "File $file does not exist\n";
#
sub dash_e {
    my (@files) = (@_);
    my $file_nogz;
    foreach $file (@files) {
        next if (not defined $file);
        next if ($file =~ /\n/);
        $file_nogz = $file;
        $file_nogz =~ s/\.gz$//;
        if    (-e $file)      { return $file; }
        elsif (-e "$file.gz") { return "$file.gz"; }
        elsif (-e $file_nogz) { return $file_nogz; }
    }
    return "";
}

#-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
# Do the system call and check for errors.  Print if there's a second argument
# USAGE: &my_system("rm *", "print");
#        &my_system("rm *");
#
sub my_system {
    my ($cmd, $print) = (@_);
    if ($print) { print ("$cmd\n"); }
    system ("$cmd");
    if ($? >> 8) {
        croak ("-E- System call failed on following command:\n    $cmd\n");
    }
}

#-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
# track is called with the following command from the script which
# requires this file and calls track:
# track($0);
# track writes the script name, user name, and time to a log file
#
# Notice that my own tracking file is hardcoded into this subroutine.  If you
# want to use this, put it in your own utilities file, change the tracking file,
# and make sure to create the tracking file with 777 permissions.
#
sub track {
    my ($message, $other_author) = (@_);
    my $username;
    my $date;
    $other_author ||= "jdmorgan";
    my ($home) = glob("~$other_author");
    my $tracking_file = "$home/bin/.script_track.txt";
    chomp($username = `whoami`);
    if ($username =~ /The user name is not recognized/ or $username =~ /Intruder/i) {
        $username = "Unknown";
    }
    $date = scalar localtime;
    $s = sprintf ("%-50s %-20s %-20s\n", $message, $username, $date);
    if (open(TRACK, ">>$tracking_file")) {
        print TRACK ("$s");
        close TRACK;
    }
}

#-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
# How to call alias_gotoward from a script
sub get_work_area {
    # Second arg is if you want to required a file to be present in work
    # area (if it finds a ward without this file it will keep looking).
    # Just send the part to tack onto the $WARD, for instance:
    # &get_work_area ("ifrepd", "pathmill/analysis/ifrepd.bvr")
    # will not return a work area for ifrepd unless it can find one with a bvr.
    my ($fub, $rf) = (@_);
    my $work_area;
    my $required_file = "";
    my ($JDM_HOME) = glob("~jdmorgan");
    if ($rf) { $required_file = "-required_file=$rf"; }
    chomp ($work_area = `$JDM_HOME/bin/alias_gotoward.pl $required_file $fub 2> /dev/null`);
    return "" if ($work_area eq ".");
    return $work_area;
}

#-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
# find work area root directory without requiring a setup
# USAGE: $ward = $opt_ward || $opt_ward || &get_ward || die "Please use -ward\n";
#          -OR-
#        &get_ward($path);
#
sub get_ward {
    my $path = shift;
    $UTILS = "$ENV{PROJ_UTILS}/dbin" if defined $ENV{PROJ_UTILS};
    if (not defined $UTILS or not -r "$UTILS/utilities.pm") {
        ($UTILS) = glob("~jdmorgan");
        $UTILS .= "/bin";
    }
    if (not $path) { $path = ""; }
    else { $path = "-initial_pwd=$path"; }
    my $ward;
    chomp ($ward = `$UTILS/alias_ward.pl $path 2> /dev/null`);
    $ward =~ s|/$||;
    return "" if ($ward eq ":");
    return $ward;
}

#-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
# find fub from within work area without requiring a setup
# USAGE: $fub = $opt_fub || $opt_fub || &get_fub || die "Please use -fub\n";
#
sub get_fub {
    my $path = shift;
    $UTILS = "$ENV{PROJ_UTILS}/dbin" if defined $ENV{PROJ_UTILS};
    if (not defined $UTILS or not -r "$UTILS/utilities.pm") {
        ($UTILS) = glob("~jdmorgan");
        $UTILS .= "/bin";
    }
    if (not $path) { $path = ""; }
    else { $path = "-initial_pwd=$path"; }
    my $fub;
    chomp ($fub = `$UTILS/alias_ward.pl -report_fub $path 2> /dev/null`);
    return "" if ($fub eq ":");
    return $fub;
}

#-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
# find the base directory of rollup from `apwd`
sub get_rollup {
    my $path = shift;
    $UTILS = "$ENV{PROJ_UTILS}/dbin" if defined $ENV{PROJ_UTILS};
    if (not defined $UTILS or not -r "$UTILS/utilities.pm") {
        ($UTILS) = glob("~jdmorgan");
        $UTILS .= "/bin";
    }
    if (not $path) { $path = ""; }
    else { $path = "-path=$path"; }
    my $rollup;
    chomp ($rollup = `$UTILS/alias_ward.pl -rollup $path 2> /dev/null`);
    $rollup =~ s|/$||;
    return "" if ($rollup eq ":");
    return $rollup;
}

#-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
# find top level hierarchy of rollup (foster_oth, iec, etc.) from `pwd`
# USAGE: $top = $opt_top || $opt_top || &get_top($rollup) || die "Please use -top <foster_oth, iec, etc.>\n";
#
sub get_top {
    my $path = shift;
    $UTILS = "$ENV{PROJ_UTILS}/dbin" if defined $ENV{PROJ_UTILS};
    if (not defined $UTILS or not -r "$UTILS/utilities.pm") {
        ($UTILS) = glob("~jdmorgan");
        $UTILS .= "/bin";
    }
    if (not $path) { $path = ""; }
    else { $path = "-path=$path"; }
    my $fub;
    chomp ($fub = `$UTILS/alias_ward.pl -report_top $path 2> /dev/null`);
    return "" if ($fub eq ":");
    return $fub;
}

#-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
# like -s on the commandline, but it doesn't stop at first non ^- argument
# USAGE: &dash_s_parse_opts;
#
sub dash_s_parse_opts {
    my @whats_left;
    foreach (@ARGV) {
        if (/^\-(.+)=(.+)/) { /{/; ${$1} = $2; }
        elsif (/^\-(.+)/)   { /{/; ${$1} = $1; }
        else { push @whats_left, $_; }
    }
    @ARGV = @whats_left;
}

#-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
# Just what it says.  Use when supplying a default PROJ_ARCHIVE
# USAGE: &check_stepping_and_warn_if_old;
#
sub check_stepping_and_warn_if_old {
    if ($ENV{PROJ_ARCHIVE} =~ /(\w\d)_archive/) {
        my $stepping = lc($1);
        if ($stepping ne "a0") {
            print STDERR ("**** Running on $stepping stepping ****\n");
            return 1;
        }
    }
    return 0;
}

#-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
# Resolve an arbitrary path (possibly including links or ./ or .. or ~) to a hard path
# USAGE: $file_resolved = resolve($file);
#
sub resolve {
    my $path = shift;
    my ($pwd, $resolve);
    my $file = "";
    my $success = 0;
    return "" if (not defined $path);
    $path = `echo $path`; # resolve the ~ manually since bash doesn't do it for you like tcsh does
    chomp $path;
    chomp($pwd = `apwd`);
#    if (-l $path) { $path = readlink $path; }
    if (not -d $path) {
        if ($path =~ m|/|) {
            $path =~ s|(/[^/]+)$||;
            $file = $1; # FYI: file includes leading /
        } else { # called on a file in the current directory
            $file = "/$path";
            $path  = ".";
        }
    }
    $success = chdir $path;
    if ($success) {
        chomp ($resolve = `apwd`);
        chdir "$pwd"; # go back
        return "$resolve$file";
    }
    else {
        return "$path$file";
    }
}
# Travis's implementation
#  # Resolve an arbitrary path (possibly including links or ./ or .. or ~) # to a hard path. # USAGE: $file_resolved = resolve($file); sub resolve($) {
#  my($path) = @_;
#  my($resolve,$link);
#  my($file) = "";
#  my($success) = 0;
#  my($result) = "";
#  my($apwd) = my_chomp(`apwd`);

#  $path = my_chomp($path);
#  ($path) = glob($path) if ($path =~ /^~/) ;
#  if ($path !~ m|/|) {
#      $path = $apwd."/".$path;
#  }
#  return($path) if (! -e $path); # Bail out without doing anything
#  # if path does not exist.
#  while (-l $path) {
#      ($path,$file) = split_filename($path);
#      $link = readlink($path.$file);
#      if ($link =~ /^\//) {
#          $path = $link;
#      } else {
#          $path .= '/'.$link;
#      }
#  }
#  if (not -d $path) {
#      ($path,$file) = split_filename($path);
#  }
#  $success = chdir $path;
#  if ($success) {
#      $resolve = my_chomp(`apwd`);
#      chdir $apwd; # go back
#      $result = "$resolve$file";
#  } else {
#      $result = "$path$file";
#  }
#  return $result;
#  }

#  # Separates and returns the path and filename.
#  sub split_filename($) {
#      my($path) = @_;
#      my($file);
#      if ($path =~ m|/|) {
#          $path =~ s|(/[^/]+)$||;
#          $file = $1; # file includes leading /
#      } else { # called on a file in the current directory
#          $file = "/$path";
#          $path = ".";
#      }
#      return($path,$file);
#  }

#  # Alternate implementation of chomp that prevents subtle bugs
#  # due to accidental changes to $/, etc.
#  sub my_chomp($) {
#      my($str) = @_;
#      $str =~ s/\n$//;
#      return($str);
#  }


#-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
# Mail me
sub mail_me {
    my ($body) = (@_);
    my $user_name = `whoami`;
    my $subject = "Message from $0";
    my $mail;
    # if (`sys` =~ /linux/) { $mail = "mail"; }
    # else                  { $mail = "mailx"; }
    $mail = "/bin/mail";
    $body = "User: ${user_name}Script: $0\n\nMessage:\n$body";
    my $cmd = "echo \"$body\" | $mail -s \"$subject\" jdmorgan\@ichips.intel.com";
    system ("$cmd");
}

#-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
# Only print if it is me
sub me_print {
    my ($msg) = (@_);
    if (`whoami` =~ /^jdmorgan$/) {
        print $msg;
    }
}

#-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
# sort routine
sub numerically {
    $a <=> $b;
}

#-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
# like -i in commandline perl
#
# Examples:
#
#   The following will create /my/file.bak and then replace "oi" with "polloi" in /my/file
#   &edit_file_in_place("/my/file");
#   while (<>) {
#       s/oi/polloi/;
#       print;
#   }
#   select STDOUT;
#
sub edit_file_in_place {
    my ($file, $bak, $out_handle, $in_handle) = @_;
    my $restore = $^W;
    $^W = 0;
    close $in_handle if $in_handle;
    close $out_handle if $out_handle;
    close EDIT_IN_PLACE_OUT_HANDLE;
    $^W = $restore;
    if ($in_handle) { opend ($in_handle, $file); }
    else            { opend (STDIN,      $file); }
    # For some reason, this rename makes it ok to open the file for input and output
    # If you take out the rename (backup), it won't work.
    $bak ||= ".bak";
    rename($file, "$file$bak");
    if ($out_handle) {
        opend ($out_handle, ">$file");
    }
    else {
        # Don't open STDOUT because later the calling script may want to quit editing the
        # file in place by using: select STDOUT;
        open (EDIT_IN_PLACE_OUT_HANDLE, ">$file") or croak "Couldn't open $file in write mode: $!\n";
        select(EDIT_IN_PLACE_OUT_HANDLE); $| = 1;
    }
}

#-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
# Make proj_info work from outside of a setup by setting the necessary
# environment variables and finding the executable.
#
# Example:
#   @fubinfo = &proj_info("-headers block site");
#
sub proj_info {
    my ($proj_info);
    $ENV{PROJECT} ||= "pscf";
    $ENV{PROJ_UTILS} ||= "/prj/$ENV{PROJECT}/utils_white";
    $ENV{MOUNTS} ||= "/prj";
    $ENV{STEPPING} ||= "WHITE";
    $proj_info = "/prj/$ENV{PROJECT}/utils_white/bin/proj_info.pl";
    if (-x $proj_info) {
        my @moad = `$proj_info @_`;
        return @moad;
    }
    else {
        return ();
    }
}

#-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
# Make blocks_info work from outside of a setup by setting the necessary
# environment variables and finding the executable.
#
# Example:
#   @fubinfo = &blocks_info("-headers block,site");
#
sub blocks_info {
    my ($blocks_info);
    $ENV{PROJECT} ||= "nhm";
    $ENV{MY_PROJECT} ||= "nhm";
    $ENV{PROJ_UTILS} ||= "/nfs/site/proj/dpg/unified/da_projects/prd/nhm/utils";
    $ENV{MOUNTS} ||= "/nfs/site/proj/dpg";
    $ENV{STEPPING} ||= "A0";
    $ENV{SETUP_REV_NUMBER} ||= "d05q1ww12b";
    $ENV{SETUP_REV} ||= "/nfs/site/proj/dpg/unified/proliferable/setup/$ENV{SETUP_REV_NUMBER}";
    $ENV{PROJ_ARCHIVE} ||= "/p/nhm/archive";
    $ENV{DA_PROJECTS} ||= "/nfs/site/proj/dpg/unified/da_projects/prd";
    $ENV{SETUP_HOSTYPE} ||= "i386_linux24";
    $ENV{PROJ_TOOLS} ||= "/nfs/site/proj/dpg/unified/da_projects/prd/nhm/$ENV{SETUP_REV_NUMBER}/proj_tools";
    $blocks_info = "/nfs/site/proj/dpg/unified/da_projects/prd/nhm/utils/bin/blocks_info.pl";
    if (-x $blocks_info) {
        my @moad = `$blocks_info @_`;
        return @moad;
    }
    else {
        return ();
    }
}

#-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
# perlwhich - just like a unix which, only in perl. This is a subroutine to
#             search your ENV PATH variable for a particular script or
#             command and then returns the full path name if it finds it.
#
#       $filelocation = &perlwhich('<some file>');
#
sub which {
    my ($filetofind) = @_;
    my $path = $ENV{'PATH'};
    my @paths = split /:/, $path;
    foreach $path (@paths) {
        if (not -d "$path/$filetofind" and -e "$path/$filetofind" and -x "$path/$filetofind") {
            return "$path/$filetofind";
        }
    }
    return "";
}

#-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
# converts a date in the format 05/21/2004 into the number of days since 0/0/00
# this is the format of dates in tibet, and you can get today's date in that
# format with: chomp($tibet_date = `date "+%m/%d/%Y"`);
#
sub convert_to_days {
    my ($date) = @_;
    my %month_day = (1,0, 2,31, 3,59, 4,90, 5,120, 6,151, 7,181, 8,212, 9,243, 10,273, 11,304, 12,334);
    if ($date =~ m|(\d+)/(\d+)/(\d+)|) {
        my ($month, $day, $year) = ((sprintf "%d", $1), $2, $3);
        return ($day + $month_day{$month} + $year*366);
    } else { return 0; }
}

## Got this from Travis (tcfurrer).  It does an alphanumeric sort, but it does the right thing when
## what you are sorting has both numbers and letters (like vectored signal names for instance)
sub alphanumeric {
  my(@ia) = split(/(\d+)/,$a);
  my(@ib) = split(/(\d+)/,$b);
  my($i);
 
  return($a cmp $b) if (scalar @ia != scalar @ib);
 
  for ($i=0; $i<scalar @ia; $i++) {
    if ($ia[$i] ne $ib[$i]) {
      if (($ia[$i] !~ /\d+/) &&
          ($ib[$i] !~ /\d+/)) {
        return($ia[$i] cmp $ib[$i]);
      } elsif (($ia[$i] =~ /\d+/) &&
               ($ib[$i] =~ /\d+/)) {
        return($ia[$i] <=> $ib[$i]);
      } else {
        return($a cmp $b);
      }
    }
  }
  return(0);
}

sub d {
    return 0 if (not defined $_[0]);
    return $_[0];
}

# Written by Eric Becker (ebecker):
#----------------------------------
## Returns a Hash with FUB information from blocks_info.pl
##
##        Usage variable                            blocks_info field
##        -----------------------------------------------------------
##        $blocks_info{$fubp}{physical_template} => physical_template
##        $blocks_info{$fubp}{unit}              => unit
##        $blocks_info{$fubp}{section}           => section
##        $blocks_info{$fubp}{cluster}           => cluster
##        $blocks_info{$fubp}{rfteam}            => rfteam assigned (defaults to "no" for no value)
##        $blocks_info{$fubp}{design_style}      => design_style
##        $blocks_info{$fubp}{MilestoneTag}      => MilestoneTag
##        $blocks_info{$fubp}{schsite}           => schsite         (defaults to "pdx" for no value)
##        $blocks_info{$fubp}{pvsite}            => pvsite          (defaults to "pdx" for no value)
##        $blocks_info{$fubp}{laysite}           => laysite         (defaults to "pdx" for no value)
##        $blocks_info{$fubp}{type}              => type            (My own calculated field that is rls for rls and cdr for all other design styles)
##
##
##        Note:  IDV FUBs stored only by template
##
##
## example call and use:
##
## %blocks_info = &blocks_info_fub;
##
## print "Section for $fubp is $blocks_info{$fubp}{section}\n";
##
sub blocks_info_fub () {
    
    my(%blocks_info);
    my($fubp, $templatep, $unit, $section, $cluster, $rfteam, $design_style);
    my($type);
    
    ## Grab blocks_info FUB information for catagorizing data
    ##
    foreach (`/nfs/site/proj/dpg/unified/da_projects/dev/nhm/utils/bin/blocks_info.pl -csv -noheaders -fval type=fub -headers physical_name,physical_template,unit,section,cluster,rfteam,MilestoneTag,design_style,schsite,pvsite,laysite`) {
        
        ($fubp, $templatep, $unit, $section, $cluster, $rfteam, $milestone_tag, $design_style, $schsite, $pvsite, $laysite) = split(/:/);
        
        # Set defaults
        $rfteam  = "no"  if (!($rfteam));
        $schsite = "pdx" if (!($schsite));
        $pvsite  = "pdx" if (!($pvsite));
        $laysite = "pdx" if (!($laysite));
        
        if (!($design_style)) { $design_style = "unknown"; } else { chomp($design_style); }
        if ($design_style eq "rls") { $type = "rls"; } else { $type = "cdr"; }
        
        #print "FUBp: $fubp \tTemplatep: $templatep \tUnit: $unit \tSection: $section \tCluster: $cluster \tRFTeam: $rfteam \tStyle: $design_style\n"; # DEBUG
        
        $blocks_info{$fubp}{physical_template}           = $templatep;
        $blocks_info{$fubp}{unit}                        = $unit;
        $blocks_info{$fubp}{section}                     = $section;
        $blocks_info{$fubp}{cluster}                     = $cluster;
        $blocks_info{$fubp}{rfteam}                      = $rfteam;
        $blocks_info{$fubp}{MilestoneTag}                = $milestone_tag;
        $blocks_info{$fubp}{design_style}                = $design_style;
        $blocks_info{$fubp}{type}                        = $type;
        $blocks_info{$fubp}{schsite}                     = $schsite;
        $blocks_info{$fubp}{pvsite}                      = $pvsite;
        $blocks_info{$fubp}{laysite}                     = $laysite;
        
        # Added every template as fub since not every template has an entry in blocks_info as it is supposed to
        #
        $blocks_info{$templatep}{physical_template}     = $templatep;
        $blocks_info{$templatep}{unit}                  = $unit;
        $blocks_info{$templatep}{section}               = $section;
        $blocks_info{$templatep}{cluster}               = $cluster;
        $blocks_info{$templatep}{rfteam}                = $rfteam;
        $blocks_info{$templatep}{MilestoneTag}          = $milestone_tag;
        $blocks_info{$templatep}{design_style}          = $design_style;
        $blocks_info{$templatep}{type}                  = $type;
        $blocks_info{$templatep}{schsite}               = $schsite;
        $blocks_info{$templatep}{pvsite}                = $pvsite;
        $blocks_info{$templatep}{laysite}               = $laysite;
        
        # If the block is an IDV fublet assign to analog
        #
        if ($templatep =~ /^idv/) {
            # Record only templates for IDV and change style to idv
            #
            $blocks_info{$fubp}{section}      = "analog";
            $blocks_info{$templatep}{section} = "analog";
            $blocks_info{$fubp}{design_style}        = "idv";
            $blocks_info{$templatep}{design_style}   = "idv";
            
        } elsif ($cluster eq "uncore") {
            # Any uncore analog FUB is assigned to analog
            #
            if ($design_style eq "analog") {
                
                $blocks_info{$fubp}{section}     = "analog";
                $blocks_info{$templatep}{section} = "analog";
                
            } elsif ($unit eq "cgb") {
                # Any cgb unit assigned block is assigned to analog
                #
                $blocks_info{$fubp}{section}    = "analog";
                $blocks_info{$templatep}{secton} = "analog";
                
            } else {
                # else most uncore blocks can be assigned to the Unit for section indicators
                #
                $blocks_info{$fubp}{section}     = $unit;
                $blocks_info{$templatep}{section} = $unit;
            }
            
        }
        # Find the pieces of the uncore that snuck out and send their ownership back :-)
        #
        elsif (($unit eq "mlc") and (grep /btrs/,$section)) {
            $blocks_info{$fubp}{section}     = "ptlc";
            $blocks_info{$templatep}{section} = "ptlc";
        } 
        
    }
    
    # Map any unusual FUB section issues to correct section
    #
    $blocks_info{"perfcntdp"}{section}        = "bat";     # Because they own it:-)
    $blocks_info{"perfcntdp"}{unit}           = "ifu";     
    $blocks_info_fub{"ptpcromarymp"}{section} = "ptlc";    # ptpcromarymp doesn't follow the rules
    $blocks_info{"ttsmiscdp"}{section}        = "analog";  # Because ttsmiscd also doesn't follow any rules
    $blocks_info{"ttnmiscdp"}{section}        = "analog";  # Because ttnmiscd also doesn't follow any rules
    
    
    return %blocks_info;
}

1

