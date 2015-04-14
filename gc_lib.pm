sub read_gc_csv {
    my ($file, $type) = @_;
    my $fh;
    open ($fh, $file) || die "could not open gc csv to read $file";
    my $line = <$fh>;
    chomp $line;
    my @field = split ',', $line;
    while (<$fh>) {
        chomp;
        my ($unit, $cluster, @number) = split ',', $_;
        for (my $i=0; $i<=$#number; $i++) {
            my $gen = $field[$i+2];
            $count{$cluster}{$unit}{$gen}{$type} = $number[$i];
        }
    }
    close $fh;
    return sort @field[2..$#field];
}

sub by_gen {
    my ($an, $at, $bn, $bt);
    if ($a =~ /Gen(\d+(\.\d+)?)(\S+)/) {
        $an = $1;
        $at = $3;
    }
    if ($b =~ /Gen(\d+(\.\d+)?)(\S+)/) {
        $bn = $1;
        $bt = $3;
    }
    if ($an == $bn) {
        $at cmp $bt;
    } else {
        # $bn <=> $an;
        $an <=> $bn;
    }
}

1;

