#!/usr/intel/pkgs/perl/5.8.5/bin/perl
use strict;
use warnings;



if (grep /help/,@ARGV) {
print STDERR " 
    This script let you add or delete stats name 
    that are used in ALPS and are checked in the 
    fast regression.
    If you have further questions. Please email:
    vijay.s.r.degalahal\@intel.com or
    jonathan.hillel\@intel.com

\n"; exit (0);
    }


our $filename = "../indigo/regression/xml/alps_regress.xml";
our $filename2 = "../indigo/regression/xml/alps_test.xml";
our @mod_stats ;
our @add_stats ;
our $error = 0; 
    print STDERR " \t\tUpdate the ALPS Stats Checking Scripts with updated stats.\n Select one of the following actions\n\n\n"; 
    print STDERR " Type 1 : For removing existing stats\n Type 2 : For updating the list with new stats\n Type 0 : To exit.\n\n>> "; 
while (<STDIN>)
{
   chop;
   if ($_ eq "1")
    { 
       $error= &remove_stats( );
        last;
    }elsif($_ eq "2") 
        {
         $error= &update_stats();
        last;
        }elsif($_ eq "0")
            {
               last;
            }else
            {
                print STDERR "*** Wrong option try again.\n" ;
                print STDERR " Type 1 : For removing existing stats\n Type 2 : For updating the list with new stats\n Type 0 : To exit.\n\n>> "; 
            }

}
if ($error<=0)
{     
    system "mv $filename2 $filename";
    my $summary = "Alps Stats updated.  The following stats were removed : \n >> @mod_stats\n\n The following stats were added to the checking script: \n >>  @add_stats \n\n  .... Exit Status = $error\n";
    print STDERR "$summary";  
    &send_report($summary);
 }else
      {  
        print STDERR "  Alps Stats update aborted .... Exit Status = $error\n";
        system "rm $filename2";
        }

sub send_report()
{
my @message = @_;    
my $title = "Add/Delete Stats to ALPS regression";   
my $user_name = getpwuid($<);
my $mailto = $ENV{USER};
my $site = `hostname -y`;
chomp ($site);
if ($site eq 'idc') {
   $site = "iil";
 }
$mailto .="\@$site.intel.com";
my $subject = "Subject\:Add\/Delete Stats to ALPS regression"; 
#$mailto .= "vijay.s.r.degalahal\@intel.com";
my $sendmail = "\/usr\/sbin\/sendmail -t "; 
open(SENDMAIL, "|$sendmail") or die "Cannot open $sendmail: $!";
print SENDMAIL "To: $mailto \n"; 
print SENDMAIL  "CC: vijay.s.r.degalahal\@intel.com\n";
print SENDMAIL  "CC: jonathan.hillel\@intel.com\n";
print SENDMAIL "Content-type: text/plain\n"; 
print SENDMAIL "Subject: $subject \n\n"; 
print SENDMAIL "FYI: @message \n"; 
close(SENDMAIL);
}

sub update_stats()
{
my $num_stats = 0;
print STDERR " Enter the stats that you want to be add for checking, one at a time\n Enter 0 to finish\n\n>> "; 
while (<STDIN>)
{
   chop;
   if ($_ eq "0")
    { 
        last ; 
    } else
        {
            $add_stats[$num_stats] = $_;
            $add_stats[$num_stats] =~ s/^\s+//;#removing space 
            $add_stats[$num_stats] =~ s/\s+$//;
            if ($add_stats[$num_stats] =~/^[A-Za-z0-9\.\[\]\_\-]+$/)
            { 
                 print STDERR "Enter next stat you want to add or Enter 0 to finish\n\n>> ";
                $num_stats++;
            }else
                {
                    print STDERR "Please enter again, the name has invalid characters\n\n>> ";
                }

           }
}
            
open (FILE, "< $filename") || die "Cannot open file $filename\n";
my @file_data = <FILE>;
close(FILE);
my $count = 0;
open (OUTFILE, "> $filename2") || die "Cannot open $filename\n";  
my $line;
my $stat;
my $error = 0;
   foreach $stat(@add_stats)
   {  
    print STDERR "$stat\n";
     foreach $line(@file_data) 
     {
         if ($line =~/$stat/)
         {

           $count ++;
         }
        }   
     if ($count <=0)
     {
       foreach $line(@file_data) 
             {
                chomp ($line);
                if ($line =~/<stats>/)
                {
                    print OUTFILE "$line\n";
                    print OUTFILE "\t\t<stat><name>$stat</name></stat>\n";
                }
                else
                 {
                     print OUTFILE "$line\n";

                 }
             }
       }elsif ($count>=1)
            {
                $error = 1;
                print STDERR " ERROR: Please give unique name. Stat :$stat already present \n"; 
            }

       $count= 0;
    }
close(OUTFILE);
return $error;
}




sub remove_stats (){
my $num_stats = 0;
print STDERR " Enter the stats that you want to be removed from checking, one at a time\n Enter 0 to finish\n\n>> "; 
while (<STDIN>)
{
   chop;
   if ($_ eq "0")
    { 
        last ; 
    } else
        {
            $mod_stats[$num_stats] = $_;
            $mod_stats[$num_stats] =~ s/^\s+//;#removing space 
            $mod_stats[$num_stats] =~ s/\s+$//;
            if ($mod_stats[$num_stats] =~/^[A-Za-z0-9\.\[\]\_\-]+$/)
            { 
                 print STDERR "Enter next stat you want to remove or Enter 0 to finish\n\n>> ";
                $num_stats++;
            }else
                {
                    print STDERR "Please enter again, the name has invalid characters\n\n>> ";
                }
        }
           } 
open (FILE, "< $filename") || die "Cannot open file $filename\n";
my @file_data = <FILE>;
close(FILE);
my $count = 0;
open (OUTFILE, "> $filename2") || die "Cannot open $filename\n";  
my $line;
my $stat;
my $error = 0;
my $linenumber = 0;
   foreach $stat(@mod_stats)
   {  
     foreach $line(@file_data) 
     {
        chomp ($line);
         if ($line =~/$stat/)
         {
          $count ++;
          $file_data[$linenumber] = "DUPLICATE_STAT";
          }elsif($line eq "DUPLICATE_STAT")
             {  
                $count = 2;    
             }else  
                 {
                  print OUTFILE "$line\n";
                 }
            $linenumber++   
        }   
        if ($count <=0)
            {
                $error = 1;
                print STDERR " The stat given is not a part of ALPS Stats Checking regression or duplicate;\n Or please check for possible typo. \n"
                }elsif ($count>1)
                    {
                        $error = 1;
                        print STDERR " ERROR: Please give unique name. Multiple Match for stat: $stat \n"; 
                    }else
                        {
                        print STDERR "Removing the stat: $stat from the ALPS Stats Checking\n"; 
                        }

       $count= 0;
    }
close(OUTFILE);
return $error;
}
1;
