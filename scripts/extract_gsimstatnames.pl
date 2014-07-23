#!/p/gat/tools/perl/perl5.14/bin/perl

die "USAGE: extract_gsimstatnames\n\t--i <Formula File List File>\n\t--o <Output File name>\n\t--d <Debug File name (stats that cannot be parsed)>\n" if ($ARGV[0] =~ /-h/i);

while ($param1 = shift)
{
    if ($param1 eq "--i")
    {
        $inputfilelist = shift(@ARGV);
        chomp($inputfilelist);
    }
    elsif ($param1 eq "--o")
    {
        $outputfile = shift(@ARGV);
        chomp($outputfile);
    }
    elsif ($param1 eq "--d")
    {
        $logfile = shift(@ARGV);
        chomp($logfile);
    }
    else
    {
        die "USAGE: extract_gsimstatnames\n\t--i <Formula File List File>\n\t--o <Output File name>\n\t--d <Debug File name (stats that cannot be parsed)>\n"
    }
}

open($INFILELIST, "<$inputfilelist") || die "Cannot open input file list $inputfilelist\n";
open($OUTFILE, ">$outputfile") || die "Cannot open output file\n";
open($LOGFILE, ">$logfile") || die "Cannot open log file\n";

my @inputfilearray = ();

while(<$INFILELIST>)
{
    chomp($_);
    push(@inputfilearray, $_);
}
close($INFILELIST);

my $total_gold_stats = 0;
my $total_log_stats = 0;

foreach(@inputfilearray)
{
    chomp($_);
    $inputfile = $_;
    open(my $INFILE, "<$inputfile") || die "Cannot open input file $inputfile\n";
    print("Parsing $inputfile for GSIM stats...\n");
    my %global_hash = ();
    my %replacement_hash = ();
    while(<$INFILE>)
    {
        chomp($_);
        #Remove comments
        #Search for "=" and print only those lines
        if($_ =~/=/)
        {
            #Replaces spaces at the beginning and comments at the end
            $_ =~ s/^\s+//;
            $_ =~ s/#.*//;
            #print $OUTFILE "$_\n";
            ($key, $rest) = split('=', $_);
            #remove the spaces in $key, $rest
            $key =~ s/\s*//g;
            $rest =~ s/\s*//g;
            $global_hash{$key} = $rest;
        }
    
    }

    #Search the @..@ variables  
    for my $localkey (keys %global_hash)
    {
        my $localvalue = $global_hash{$localkey};
        if($localkey =~ /^@/)
        {
            #print $OUTFILE "$localkey = $localvalue\n";
            $replacement_hash{$localkey} = $localvalue;
            #Remove the line from the global hash
            delete $global_hash{$localkey};
        }
        #Ignore the num_ instances
        if($localkey =~/^num_/)
        {
            delete $global_hash{$localkey}; 
        }
        #Ignore the ? : operator
        if($localvalue =~ /\?/)
        {
            ($tempkey, $temprest) = split('\?', $localvalue, 2);
            #Now Ignore the : operator
            ($tempkey2, $temprest2) = split('\:', $temprest, 2);
            $global_hash{$localkey} = $tempkey2; #Need a re-loop after replacing a Key/Value Pair
        }
    }

    #Find if there are any @..@ loops in replacement_hash first
    for my $localkey (keys %replacement_hash)
    {
        my $localvalue = $replacement_hash{$localkey};
        if($localvalue =~ /.*(@.*@).*/)
        {
            my $temp_value = $replacement_hash{$1};
            $localvalue =~ s/$1/$temp_value/g;
            $replacement_hash{$localkey} = $localvalue;
        }
    }
    #Replace the @..@ variables
    for my $localkey (keys %replacement_hash)
    {
        my $localvalue = $replacement_hash{$localkey};
        #print $OUTFILE "$localkey = $localvalue\n";
        for my $tempkey (keys %global_hash)
        {
            my $tempvalue = $global_hash{$tempkey};
            if ($tempvalue =~ /($localkey)/)
            {
            $tempvalue =~ s/$1/$localvalue/g;
            }
            $global_hash{$tempkey} = $tempvalue;
        }
    }

    ##More cleanup/beautification
    for my $localkey (keys %global_hash)
    {
        my $localvalue = $global_hash{$localkey};
        #Ignore the values that are 0 or 1
        if($localvalue =~/^[0,1]/)
        {
            delete $global_hash{$localkey};      
        }
        #Ignore the values that do not have a D( to indicate a regular expr search
        if($localvalue !~/D\(/)
        {
            delete $global_hash{$localkey};      
        }
        #Ignore everything in the denominator
        if($localvalue =~ /\//)
        {
            ($tempkey, $temprest) = split('\/', $localvalue);
            $global_hash{$localkey} = $tempkey; #Need a re-loop after replacing a Key/Value Pair
        }
    }   
    
    my @silver_stats = ();
    my @gold_stats = ();
    for my $localkey (keys %global_hash)
    {
        my $localvalue =$global_hash{$localkey};

        my @money_stats = split('\'', $localvalue);
        my $money_stats_length = @money_stats;
        if($money_stats_length == 1)
        {
            #No matches. Use D( to print the commands.
            if($localvalue =~ /D\((.*)\)/)
            {
                #Flag exceptions with MIN/MAX type statements
                if($localvalue =~ /MIN|MAX/)
                {
                    print $LOGFILE "#Warning! Cannot Parse $localvalue\n";
                    $total_log_stats++;
                }
                else
                {
                push(@silver_stats, $1);
                }
            }
        }
        for(my $i=1; $i<=$money_stats_length; $i=$i+2)
        {
            if($money_stats[$i])
            {
            push(@silver_stats, $money_stats[$i]);
            }
        }
        #print $OUTFILE "$localvalue\n";
    }

    foreach(@silver_stats)
    {
        my $temp_final_data = $_;
        $temp_final_data =~ s/\\d\+/0/g;
        $temp_final_data =~ s/\\\./\./g;
        #punt the stats that cannot be parsed.
        if($temp_final_data =~ /\\/)
        {
            print $LOGFILE "#Warning! Cannot Parse $temp_final_data\n";
            $total_log_stats++;
        }
        elsif($temp_final_data =~ /\{/)
        {
            print $LOGFILE "#Warning! Cannot Parse $temp_final_data\n";   
            $total_log_stats++;
        }
        elsif($temp_final_data =~ /.*\((.*)\).*/)
        {
            #parse the (|) structures
            my $temp_value = $1;
            if($temp_value =~ /\|/)
            {
               #update stats for each |
               my @temp_array = split('\|', $temp_value);
               foreach(@temp_array)
               {
                    chomp($_);
                    my $pipe_value = $temp_final_data;
                    $pipe_value =~ s/\(.*\)/$_/g;
                    push(@gold_stats, $pipe_value);
               }
            }
            elsif($temp_value =~ /[0-9a-zA-Z]/)
            {
                #For some weird reason, someone used () without |
                $temp_final_data =~ s/\(.*\)/$temp_value/g;
                push(@gold_stats, $temp_final_data);
            }
            else
            {
                #Give up!
                print $LOGFILE "#Warning! Cannot Parse $temp_final_data\n";
                $total_log_stats++;
            }
        }
        else
        {
            push(@gold_stats, $temp_final_data);
        }
    }
    
    my $temp_gold_stats_length = @gold_stats;
    print "Found $temp_gold_stats_length Stats in $inputfile\n";
    $total_gold_stats = $total_gold_stats + $temp_gold_stats_length;
    my $print_data = join("\n", @gold_stats);  
    print $OUTFILE "$print_data\n";


    close($INFILE);    
}

print "DONE...\n\nTOTAL GSIM STATS FOUND: $total_gold_stats\nSTATS THAT CANNOT BE PARSED: $total_log_stats\n";
if($total_log_stats != 0)
{
    print "Stats that cannot be parsed.. $logfile\n";
}
close($OUTFILE);
close($LOGFILE);
