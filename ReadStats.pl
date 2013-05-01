#!/usr/bin/perl
###############################################################
###############################################################
###                                                         ###
###   This script requires gunzip ( http://www.gzip.org )   ###
###                                                         ###
###############################################################
###############################################################
use strict;

my @input;
my @forml;
my $csv;
my $bad;
my $out;
my $err;
my $dbg;

while(@ARGV)
{ my $a=shift;
  if($a eq '-csv'){ $csv=1; next;}
  if($a eq '-o'){ $out=shift; next;}
  if($a eq '-e'){ $err=shift; next;}
  if($a eq '-d'){ $dbg=1; next;}
  if($a=~/^-/){ $bad=1; last;}
  if($a=~/\.stat$/ || $a=~/\.stats$/ || $a=~/\.stat\.gz$/ || $a=~/\.stats\.gz$/){ push @input, $a; next;}
  push @forml, $a;
}

if($err ne '')
{ open STDERR, ">$err" or die "Cannot open $err";
}
if($out ne '')
{ open STDOUT, ">$out" or die "Cannot open $out";
}

$bad=1 if !scalar @input;
$bad=1 if !scalar @forml;

die "USAGE:\tReadStats.pl [options] <gsim.stat> <formula.txt> [<formula1.txt> [<formula2.txt> ...]] \noptions:\t-csv\t-- output in csv format\n" if $bad;

my @list;
my %var;
my %unit;
my %mac;
my %bad;
my %eq;
my %eqfn; ### equation definition file
my %eqln; ### equation definition line
my %wc;
my %wcfn; ### regex first use file
my %wcln; ### regex first use line
my %data;

my $lineno=0;
my $equation;

###
### Read formula files
###
foreach my $formula(@forml)
{ open FILE,"<$formula" or die "Cannot open $formula\n";
  $formula=$1 if $formula=~/[\/\\]([^\/\\]+)$/;
  my $linecount=0;
  foreach my $line(<FILE>)
  { $linecount++;
    chomp $line; $line=~s/#.*$//; $line=~s/^\s+//; $line=~s/\s+$//;
    next if $line eq '';
    $lineno=$linecount if $equation eq '';
    $equation.=$line;
    my $tmp=$equation;
    while($tmp=~s/.*?('[^']+')//){ if($wcfn{$1} eq ''){ $wcfn{$1}=$formula; $wcln{$1}=$linecount;}}
    next if $equation=~s/\\$//;
    read_formula($equation,$formula,$lineno);
    $equation='';
  }
  close FILE;
}

###
### Check dependencies (topological sort + strongly connected components)
###
my %dep;
my @vars=keys %var;
foreach my $v(keys %var){ $dep{$v}={};}
foreach my $v(keys %var)
{ foreach my $d(keys %{$var{$v}})
  { if($var{$d})
    { $dep{$d}{$v}=1;
      if($d eq $v)
      { print STDERR "##### $eqfn{$v} line $eqln{$v} - Circular dependency:\t$v <- $d\n";
        $bad{$v}=1;
      }
    }
    else { delete $var{$v}{$d};}
  }
}
my %dfs0; # node visited
my %dfs1; # node done
my $count=0;
foreach my $v(@vars)
{ next if $dfs0{$v};
  $dfs0{$v}=1;
  my @stack=($v);
  while(scalar @stack)
  { my $x=$stack[scalar @stack-1];
    foreach my $d(keys %{$dep{$x}})
    { delete $dep{$x}{$d} if $dfs0{$d};
    }
    if(scalar keys %{$dep{$x}})
    { my $d=(keys %{$dep{$x}})[0];
      $dfs0{$d}=1; push @stack,$d;
    }
    else
    { $count++;
      $dfs1{$x}=$count;
      pop @stack;
    }
  }
}
@vars = sort {$dfs1{$b}<=>$dfs1{$a}} @vars;

foreach my $v(keys %var)
{ foreach my $d(keys %{$var{$v}}){ $dep{$v}{$d}=1;}
}
%dfs0={};
foreach my $v(@vars)
{ next if $dfs0{$v};
  $dfs0{$v}=1;
  my @stack=($v);
  my @scc=($v);
  while(scalar @stack)
  { my $x=$stack[scalar @stack-1];
    foreach my $d(keys %{$dep{$x}})
    { delete $dep{$x}{$d} if $dfs0{$d};
    }
    if(scalar keys %{$dep{$x}})
    { my $d=(keys %{$dep{$x}})[0];
      $dfs0{$d}=1; push @stack,$d;
      push @scc,$d;
    }
    else
    { pop @stack;
    }
  }
  next if 1==scalar @scc;
  print STDERR "##### $eqfn{$v} line $eqln{$v} - Circular dependency:\t";
  foreach my $d(@scc)
  { $bad{$d}=1;
    print STDERR "$d <- ";
  }
  print STDERR "$v\n";
}

###
### Read stat file
###
foreach my $fname(@input)
{ open FILE, $fname=~/\.gz$/ ? "gunzip -c $fname|" : "<$fname" or die "Cannot open $fname\n";
  foreach my $line(<FILE>)
  { chomp $line; $line=~s/#.*$//; $line=~s/^\s+//; $line=~s/\s+$//;
    next unless $line=~/^(\S+)\s+(\S+)/;
    my $st=$1; my $val=$2;
    $data{$st}=$val;
    foreach my $x(keys %wc)
    { next unless $st=~/$wc{$x}/;
      $data{$x}=$data{$x}.',' if $data{$x} ne '';
      $data{$x}=$data{$x}.$data{$st};
    }
    if($var{$st})
    { print STDERR "##### $eqfn{$st} line $eqln{$st} - Name conflict:\t$st\n";
      $bad{$st}=1;
    }
  }
  close FILE;
}

foreach my $x(sort keys %wc)
{ next if $data{$x};
  print STDERR "##### $wcfn{$x} line $wcln{$x} - No matches found:\t$x\n";
}

###
### Evaluate
###
foreach my $st(@vars)
{ next if $bad{$st};
  foreach my $d(keys %{$var{$st}})
  { next unless $bad{$d};
    print STDERR "##### $eqfn{$st} line $eqln{$st} - Broken dependency:\t$st <- $d\n";
    $bad{$st}=1; last;
  }
  next if $bad{$st};
  my $val;
  my @eqq=split /\s*\?=\s*/, $eq{$st}; ### "?=" feature
  foreach my $eq(@eqq)
  { my $tmp;
    my $expr;
    $tmp=$eq;
    while($tmp=~s/(.*?)('[^']+')//)
    { my $x=$2; $expr.=$1;
      $expr.=$data{$x};
    }
    $tmp=$expr.$tmp; $expr='';
    while($tmp=~s/(.*?)([\w\.]+)//)
    { my $x=$2; $expr.=$1;
      $expr.=($data{$x} eq '')?$x:$data{$x};
    }
    $expr.=$tmp;

    $val=eval($expr);
    last if $val ne '';
    print STDERR "##### $eqfn{$st} line $eqln{$st} - Cannot evaluate:\t$st = $eq\n" if $dbg;
  }

  if($val eq '')
  { print STDERR "##### $eqfn{$st} line $eqln{$st} - Cannot evaluate:\t$st = $eq{$st}\n" unless $dbg;
    $bad{$st}=1;
    next;
  }
  $data{$st}=$val;
}

###
### Output
###
foreach my $st(@list)
{ next if $st=~/^\./ && !$dbg;
  my $val=$data{$st};
  next if $val eq '';
  $val=sprintf("%.6f",$val) unless $val eq int($val);
  if($csv)
  { print "$st,$val\n";
  }
  else
  { print "$st\t$val\n";
  }
}

sub read_formula
{ my $equation=shift;
  my $file=shift;
  my $line=shift;
  my $st; my $eq; my $un;
  if($equation=~/^(\S+)\s*\((\S*)\)\s*=\s*(.*)\s*$/)
  { $st=$1; $un=$2; $eq=$3;
  }
  elsif($equation=~/^(\S+)\s*=\s*(.*)\s*$/)
  { $st=$1; $eq=$2;
  }
  if($eq eq '' || !$st=~/^@\w+@$|^\.?[a-zA-Z_][\w\.]*$/)
  { print STDERR "##### $file line $line - Incorrect syntax, line ignored:\t$equation\n";
    return;
  }
  while($eq=~/^([^@]*)@([^@]*)@(.*)$/)
  { if($mac{$2} eq '')
    { print STDERR "##### $file line $line - Macro not defined, line ignored:\t@$2@\n";
      return;
    }
    $eq=$1.$mac{$2}.$3;
  }
  if($st=~/^@([\w]+)@$/)
  { $mac{$1}=$eq;
  }
  else ### if($st=~/^[\w\.]+$/)
  { if($var{$st})
    { print STDERR "##### $file line $line - Duplicated stat, line ignored:\t$st\n";
    }
    else
    { $var{$st}={}; push @list,$st;
      $eq{$st}=$eq; $unit{$st}=$un;
      $eqfn{$st}=$file; $eqln{$st}=$line;
      my $tmp=$eq;
      while($tmp=~s/'([^']*)'/ /)
      { $wc{"'$1'"}=$1;
        if($wcfn{"'$1'"} eq ''){ $wcfn{"'$1'"}=$file; $wcln{"'$1'"}=$line;}
      }
      while($tmp=~s/([\w\.]+)//)
      { $var{$st}{$1}=1;
      }
    }
  }
}

sub SUM
{ my $z=0;
  foreach my $x(@_){ $z+=$x if $x ne '';}
  return $z;
}

sub MIN
{ my $z;
  foreach my $x(@_)
  { next if $x eq '';
    next unless $z eq '' || $x<$z;
    $z=$x;
  }
  return $z;
}

sub MAX
{ my $z;
  foreach my $x(@_)
  { next if $x eq '';
    next unless $z eq '' || $x>$z;
    $z=$x;
  }
  return $z;
}

sub COUNT
{ my $z=0;
  foreach my $x(@_){ $z++ if $x ne '';}
  return $z;
}

sub AVG
{ my $s;
  my $n;
  foreach my $x(@_)
  { next if $x eq '';
    $s+=$x; $n++;
  }
  return unless $n;
  return $s/$n;
}

sub DEV
{ my $s;
  my $t;
  my $n;
  foreach my $x(@_)
  { next if $x eq '';
    $s+=$x; $t+=$x*$x; $n++;
  }
  return unless $n;
  $s/=$n; $t/=$n;
  return sqrt($t-$s*$s);
}

sub DIFF
{ return $_[0] if 1 == scalar @1;
}
