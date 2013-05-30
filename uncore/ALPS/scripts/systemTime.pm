#! /usr/intel/bin/perl
# name: system time
# date: 07aug2006
# mod:  04sep2008
# auth: Jimmy Cassis
# desc: calculates runtime and displays system time
# use:  require "<path to this file>/systemTime.pm"

# marker for start index
sub startTime {
    my $startTime = time;
    return $startTime;
}

# prints a final time report in Intel format
sub intelTime {
    my ($startTime, $endTime, $timeTaken1, $timeTaken2, $date);
    my ($script, $start) = @_;    # passing $0 displays the script's name

    print "\n################################################################################################";
    print "\n##";
    $date = &dateTime(0);
    print "\n## $script finished at $date"; # format -> Mon Aug  7 11:51:40 PDT 2006";
    if (defined $start) {
        $startTime = $start;
    } else {
        $startTime = 0;
    }
    $endTime = time;
    print "\n## $endTime (seconds since 00:00:00 UTC, January 1, 1970)";
    $timeTaken1 = $endTime - $startTime;
    $timeTaken2 = &elapsedTime($timeTaken1);
    print "\n## Elapsed time $timeTaken1 secs ($timeTaken2)";
    print "\n##";
    print "\n################################################################################################\n\n";
}

# prints a final time report
sub finalTime {
    my ($startTime, $endTime, $timeTaken1, $timeTaken2);
    my ($start, $script) = @_;

    if (defined $script) {
        my $date = &dateTime(0);
        print "-I- $script finished at $date\n";
    }

    if (defined $start) {
        $startTime = $start;
    } else {
        $startTime = 0;
    }

    $endTime = time;
    print "-I- $endTime (seconds since 00:00:00 UTC, January 1, 1970)\n";
    $timeTaken1 = $endTime - $startTime;
    $timeTaken2 = &elapsedTime($timeTaken1);
    print "-I- Elapsed time $timeTaken1 secs ($timeTaken2)\n";
}

# dateTime formats the output for the current date and time.
# does not include the newline in the return string.
# mode 0 -> 24hr (default), mode 1 -> am pm, other mode -> locale's date and time
# uses date from gnu_coreutils
sub dateTime {
    my ($mode) = shift;

    if (! defined $mode || $mode == 0) {
        my $date = `date "+%a %b %e %T %Z %Y"`;
        chomp $date;
        return $date;
    } elsif ($mode == 1) {
        my $date = `date "+%a %b %e %r %Z %Y"`;
        chomp $date;
        return $date;
    } else {
        my $date = `date "+%c"`;
        chomp $date;
        return $date;
    }
}

# intelDateTime formats the output for the current date and time.
# does not include the newline in the return string.
# mode 0 -> 24hr (default), mode 1 -> am pm
sub intelDateTime {
    my ($mode) = shift;
    my (@monthName, @wkName, $code, $sec, $min, $hrs, $day, $mon, $yr, $wk, $yrday, $isdst) = ();

    @monthName = ('Jan', 'Feb', 'Mar', 'Apr',
                  'May', 'Jun', 'Jul', 'Aug', 'Sep',
                  'Oct', 'Nov', 'Dec');
    @wkName = ('Sun', 'Mon', 'Tue', 'Wed',
               'Thu', 'Fri', 'Sat');

    ($sec, $min, $hrs, $day, $mon, $yr, $wk, $yrday, $isdst) = localtime;

    $yr += 1900;
    $mon = $monthName[$mon];
    $wk = $wkName[$wk];
    $day = sprintf "%2d", $day;
    $min = sprintf "%02d", $min;
    $sec = sprintf "%02d", $sec;

    my $tz = $ENV{TZ};
    if ($isdst) {
        $tz =~ m/[A-Z]{3}\d+([A-Z]{3})/;
        $tz = $1;
    } else {
        $tz =~ m/([A-Z]{3})\d+[A-Z]{3}/;
        $tz = $1;
    }

    if (! $mode) {
        $code = '';
        return "$wk $mon $day $hrs:$min:$sec $tz $yr";
    }

    if ($hrs >= 12) {
        $code = "PM";
    } else {
        $code = "AM";
    }

    if ($hrs > 12) {
        $hrs -= 12;    # hours in range 0..11
    }

    if (! $hrs) {
        $hrs = 12;    # hours in range 1..12
    }

    return "$wk $mon $day $hrs:$min:$sec $code $tz $yr";
}

# breaks the elapsed time in seconds into hr, min, sec
sub elapsedTime {
    my ($hr, $min, $sec);
    my ($timeTaken) = shift;

    $min = $timeTaken / 60;
    $sec = $timeTaken % 60;

    $hr = int $min / 60;
    $min = $min % 60;

    if ($hr == 1) {
        return return "$hr hour $min min $sec sec";
    }

    return "$hr hours $min min $sec sec";
}

1;        # module termination
