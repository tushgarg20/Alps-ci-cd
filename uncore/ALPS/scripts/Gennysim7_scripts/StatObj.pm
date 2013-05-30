################################################################################
# package StatObject
# base class for STATIStatObject, IndigoStatObject, NOAStatObject...
# should just have two methods, and they're both purely virtual.
# ThisRecord() - gets the value for this "record" (50k clocks, possibly >1 
#                aggregated, maybe less if it hit a drawcall boundary)
# ThisState()  - gets the value for the whole state 
################################################################################

{
   package StatObj;
   use Carp;
   
   sub GetThisRecord {
      croak("Called ThisRecord() for a base StatObj - this function's pure virtual.");
   }

   sub GetThisState {
      croak("Called ThisState() for a base StatObj - this function's pure virtual.");
   }
   
   sub GetMaxVal {
      return(5000000);  # No stat may go up by more than this from one STATI record
                        # to the next. At least not if m_DoTestMaxVal is set.
   }

}

################################################################################
# package StatIStatObj
# A usable derived class from StatObj
# Use this one for data to be grabbed from a GennySim STATI(.gz) file
#
# As ever, m_PrevRecordVal is the number in the StatI file, while 
# m_ThisRecordVal is a difference between records in the StatI file.  We hide
# the cumulative nature of the StatI stats thusly (and we'd have to rewrite 
# this class if it changed.)
################################################################################

{
   package StatIStatObj;
   @ISA = qw(StatObj);
   use Carp;
   
   ################################################################################
   # sub PeekRecord
   # Call this with a hashref to a StatI record to return the difference between
   # the previous value and the one in this StatI record, but NOT update
   # m_PrevRecordVal or m_ThisRecordVal
   ################################################################################
   sub PeekRecord {
      my $instance = shift;
      unless (ref $instance) {
         croak ("Called StatIStatObj->PeekRecord() on the class; must call on an instance");
      }   
      
      my $ColumnVals = shift; # must be a hashref;
      
      if ($instance->{'m_NULL'}) {return 0;}
      
      return ($ColumnVals->{$instance->{'m_StatName'}} - $instance->{'m_PrevRecordVal'});
   
   }

   ################################################################################
   # sub PeekState
   # Call this with a hashref to a StatI record to return the difference between
   # the previous state value and the one in this StatI record, but NOT update
   # m_PrevRecordVal or m_ThisRecordVal
   ################################################################################
   sub PeekState {
      my $instance = shift;
      unless (ref $instance) {
         croak ("Called StatIStatObj->PeekState() on the class; must call on an instance");
      }   
      
      my $ColumnVals = shift; # must be a hashref;
      
      if ($instance->{'m_NULL'}) {return 0;}

      return ($ColumnVals->{$instance->{'m_StatName'}} - $instance->{'m_PrevStateVal'});
   
   }


   ################################################################################
   # sub LatchRecord
   # Call this with a hashref to a StatI record to take the difference between
   # the previous value and the one in this StatI record, place that difference 
   # in m_ThisRecordVal, and subsequently update m_PrevRecordVal.  Also checks
   # m_ThisRecordVal against the class-wide GetMaxVal(), if appropriate.
   ################################################################################
   sub LatchRecord {
      my $instance = shift;
      unless (ref $instance) {
         croak ("Called StatIStatObj->LatchRecord() on the class; must call on an instance");
      }   
      
      my $ColumnVals = shift; # must be a hashref;
      
      if ($instance->{'m_NULL'}) {$instance->{'m_ThisRecordVal'} = 0;}
      else {$instance->{'m_ThisRecordVal'} = $ColumnVals->{$instance->{'m_StatName'}} - $instance->{'m_PrevRecordVal'};}
      
      if ($instance->{'m_DoTestMaxVal'}) {
         my $MaxVal = (ref $instance)->GetMaxVal();
         if (($instance->{'m_ThisRecordVal'} > $MaxVal) || (0 > $instance->{'m_ThisRecordVal'})) {
            my $m_StatName = $instance->{'m_StatName'};
            my $m_ThisRecordVal = $instance->{'m_ThisRecordVal'};
            my $ThisLine = $ColumnVals->{$instance->{'m_StatName'}};
            my $PrevLine = $instance->{'m_PrevRecordVal'};
            croak ("Something went wrong reading the STATI file; $m_StatName was set to $m_ThisRecordVal ($ThisLine - $PrevLine), which is greater than MaxVal $MaxVal");
         }
      }
      
      if ($instance->{'m_NULL'}) {$instance->{'m_PrevRecordVal'} = 0;}
      else {$instance->{'m_PrevRecordVal'} = $ColumnVals->{$instance->{'m_StatName'}};}
   
   }
   
   ################################################################################
   # sub LatchState
   # Call this with a hashref to a StatI record to take the difference between
   # the previous STATE's value and the one in this StatI record, place that difference 
   # in m_ThisStateVal, and subsequently update m_PrevStateVal.  Essentially, just
   # like LatchRecord, but only called on state changes.
   ################################################################################
   sub LatchState {
      my $instance = shift;
      unless (ref $instance) {
         croak ("Called StatIStatObj->LatchState() on the class; must call on an instance");
      }   
      
      my $ColumnVals = shift; # must be a hashref;
      
      if ($instance->{'m_NULL'}) {         
         $instance->{'m_ThisStateVal'} = 0;
         $instance->{'m_PrevStateVal'} = 0;
      }
      else {
         $instance->{'m_ThisStateVal'} = $ColumnVals->{$instance->{'m_StatName'}} - $instance->{'m_PrevStateVal'};
         $instance->{'m_PrevStateVal'} = $ColumnVals->{$instance->{'m_StatName'}};
      }   
   }
   
   ################################################################################
   # sub GetThisRecord
   # Returns m_ThisRecordVal
   ################################################################################
   sub GetThisRecord {
      my $instance = shift;
      unless (ref $instance) {
         croak ("Called StatIStatObj->ThisRecord() on the class; must call on an instance");
      }   
      
      return ($instance->{'m_ThisRecordVal'});
   }
   
   ################################################################################
   # sub GetThisState
   # Returns m_ThisRecordVal
   ################################################################################
   sub GetThisState {
      my $instance = shift;
      unless (ref $instance) {
         croak ("Called StatIStatObj->ThisState() on the class; must call on an instance");
      }   
      
      return ($instance->{'m_ThisStateVal'});
   }
    
   ################################################################################
   # sub new
   # Pass a hashref with one required and one optional key
   # Get a blessed StatIStatObj reference back
   ################################################################################
   sub new {
      
      my $defaultDoTestMaxVal = 1;
      my $defaultNULL = 0;
   
      my $class = shift;
      if (ref $class) {
         croak ("Called StatIStatObj->new() on an instance - what's that even mean?! Must call on the class");
      }
      my $ref_init_members = shift; # needs to be a hashref
      
      my @required_members = qw(m_StatName);
      my @optional_members = qw(m_DoTestMaxVal NULL);
      
      # generic test for required members
      foreach my $required_member (@required_members) {
         unless (grep $required_member eq $_, keys(%$ref_init_members)) {
            croak ("Called StatIStatObj->new without missing member $required_member in the hashref");
         }
      }
      
      # generic test for optional members
      foreach my $init_member (keys(%$ref_init_members)) {
         unless (grep $init_member eq $_, ((@optional_members), (@required_members))) {
            croak ("Called StatIStatObj->new with unrecognized member $init_member in the hashref");
         }
      }
      
      my $m_StatName = $ref_init_members->{'m_StatName'};
      my $m_DoTestMaxVal = $defaultDoTestMaxVal;
      if (defined($ref_init_members->{'m_DoTestMaxVal'})) {$m_DoTestMaxVal = $ref_init_members->{'m_DoTestMaxVal'};}
      
      my $m_NULL = $defaultNULL;
      if (defined($ref_init_members->{'NULL'})) {$m_NULL = $ref_init_members->{'NULL'};}
      
      my $self = {
                     'm_StatName' => $m_StatName,
                     'm_DoTestMaxVal' => $m_DoTestMaxVal,
                     'm_NULL' => $m_NULL,
                     'm_PrevRecordVal' => 0,
                     'm_PrevStateVal' => 0,
                     'm_ThisRecordVal' => 0,
                     'm_ThisStateVal' => 0,
                  };
      bless $self, $class; 
      return $self;
   }


}

################################################################################
# package StateStatIStatObj
# Mostly like a StatIStatObj, but use this one to track state.  It doesn't do the
# diff between records method of determining a value, and, upon latching record
# N's state value, the m_ThisRecordVal becomes record N-1's entry.
################################################################################

{
   package StateStatIStatObj;
   @ISA = qw(StatObj);
   use Carp;
   
   ################################################################################
   # sub PeekStateChange
   # Call this with a hashref to a StatI record to compare the state number in the
   # StatI record with the state number in the m_ThisRecordVal.
   # Returns 1 if they're different (and thus a state change), 0 otherwise.
   ################################################################################
   sub PeekStateChange {
      my $instance = shift;
      unless (ref $instance) {
         croak ("Called StateStatIStatObj->PeekStateChange() on the class; must call on an instance");
      }   
      
      my $ColumnVals = shift; # must be a hashref;
      
      # JMR 08/18/09 - GennySim appears to report the _old_ state in its stati record,
      # which is actually pretty helpful (and how I wish, in hindsight, Gen4sim would
      # have done things.)  So, if "2" is the value of the State field, then all 
      # the incrementing of stats leading up to the moment that stati record was 
      # written happened during state 2.  It's so simple, it's confusing.
      #
      # BUT - can't rely on the state field changing to indicate a state change
      # (it changes AFTER the state change happened and new data's been accumulated
      # under the new state), so must look at the trigger field to find state
      # changes.  That's okay. 
      #
      # JMR 10/25/10 - AHA does it the same way.
      
      if (-1 != index($ColumnVals->{$instance->{'m_TriggerName'}}, 'S')) {
         return (1);
      }
      elsif (-1 != index($ColumnVals->{$instance->{'m_TriggerName'}}, 'DRAW')) {
         return (1);
      }
      else {
         return (0);
      }
   
   }

   ################################################################################
   # sub LatchRecord
   # Call this with a hashref to a StatI record to take the difference between
   # the previous value and the one in this StatI record, place that difference 
   # in m_ThisRecordVal, and subsequently update m_PrevRecordVal.  Also checks
   # m_ThisRecordVal against the class-wide GetMaxVal(), if appropriate.
   ################################################################################
   sub LatchRecord {
      my $instance = shift;
      unless (ref $instance) {
         croak ("Called StateStatIStatObj->LatchRecord() on the class; must call on an instance");
      }   
      
      my $ColumnVals = shift; # must be a hashref;
      
      $instance->{'m_ThisRecordVal'} = $ColumnVals->{$instance->{'m_StatName'}};
   
   }
   
   ################################################################################
   # sub LatchState
   # Call this with a hashref to a StatI record to take the difference between
   # the previous STATE's value and the one in this StatI record, place that difference 
   # in m_ThisStateVal, and subsequently update m_PrevStateVal.  Essentially, just
   # like LatchRecord, but only called on state changes.
   ################################################################################
   sub LatchState {
      my $instance = shift;
      unless (ref $instance) {
         croak ("Called StateStatIStatObj->LatchState() on the class; must call on an instance");
      }   
      
      my $ColumnVals = shift; # must be a hashref;
      
      $instance->{'m_ThisStateVal'} = $ColumnVals->{$instance->{'m_StatName'}};
   
   }
   
   ################################################################################
   # sub GetThisRecord
   # Returns m_ThisRecordVal
   ################################################################################
   sub GetThisRecord {
      my $instance = shift;
      unless (ref $instance) {
         croak ("Called StatIStatObj->ThisRecord() on the class; must call on an instance");
      }   
      
      return ($instance->{'m_ThisRecordVal'} + $instance->{'m_Offset'});
   }
   
   ################################################################################
   # sub GetThisState
   # Returns m_ThisRecordVal
   ################################################################################
   sub GetThisState {
      my $instance = shift;
      unless (ref $instance) {
         croak ("Called StatIStatObj->ThisState() on the class; must call on an instance");
      }   
      
      return ($instance->{'m_ThisStateVal'} + $instance->{'m_Offset'});
   }
    
   ################################################################################
   # sub SetOffset
   # This is a stupid hack to work around an apparent GennySim behavior where the
   # first drawcall gets all its stats written to the StatI file under drawcall 2,
   # and so forth.
   # Don't want this hardcoded because we also do a warmup to skip to the start of
   # valid data in the StatI file, for which I want the un-fixed state numbers
   #
   # We apply the offset when returning data, NOT when latching it.
   # That's an arbitrary decision, but let's pick one and be consistent.
   ################################################################################
   sub SetOffset {
      my $instance = shift;
      unless (ref $instance) {
         croak ("Called StateStatIStatObj->SetOffset() on the class; must call on an instance");
      }   
      my $offset = shift;
      
      $instance->{'m_Offset'} = $offset;
   }
    
   ################################################################################
   # sub new
   # Pass a hashref with one required and one optional key
   # Get a blessed StatIStatObj reference back
   ################################################################################
   sub new {
      my $defaultDoTestMaxVal = 1;
      my $class = shift;
      if (ref $class) {
         croak ("Called StateStatIStatObj->new() on an instance - what's that even mean?! Must call on the class");
      }
      my $ref_init_members = shift; # needs to be a hashref
      
      my @required_members = qw(m_StatName m_TriggerName);
      my @optional_members = qw();
      
      # generic test for required members
      foreach my $required_member (@required_members) {
         unless (grep $required_member eq $_, keys(%$ref_init_members)) {
            croak ("Called StateStatIStatObj->new without missing member $required_member in the hashref");
         }
      }
      
      # generic test for optional members
      foreach my $init_member (keys(%$ref_init_members)) {
         unless (grep $init_member eq $_, ((@optional_members), (@required_members))) {
            croak ("Called StateStatIStatObj->new with unrecognized member $init_member in the hashref");
         }
      }
      
      my $m_StatName = $ref_init_members->{'m_StatName'};
      my $m_TriggerName = $ref_init_members->{'m_TriggerName'};
      my $m_DoTestMaxVal = $defaultDoTestMaxVal;
      if (defined($ref_init_members->{'m_DoTestMaxVal'})) {$m_DoTestMaxVal = $ref_init_members->{'m_DoTestMaxVal'};}
      
      my $self = {
                     'm_StatName' => $m_StatName,
                     'm_TriggerName' => $m_TriggerName,
                     'm_ThisRecordVal' => 0,
                     'm_ThisStateVal' => 0,
                     'm_Offset' => 0,
                  };
      bless $self, $class; 
      return $self;
   }


}

################################################################################
# package MultiStatIStatObj
# A usable derived class from StatObj
# Use this one for data to be grabbed from a GennySim STATI(.gz) file, when
# more than one stat has to be somehow aggregated into a "logical stat".
#
# Instead of an m_StatName, this takes a m_StatRegex, which is matched against
# all the StatI column headers.  All the matches have StatIStatObj objects
# created, and those objects are thrown into a list in the MultiStatIStatObj.
# Most of the method calls, in turn, just get iterated over that list.  
# The Peek and Get calls are slightly more complex, but NOT MUCH.
#
# Requires:
#    m_StatRegex - a regular expression which matches all and only those stati
#                  column headers which are aggregated into the logical stat
#                  represented by this MultiStatIStatObj.
#    m_ReportDataAs - either SUM or AVERAGE the individual sub-stats to produce
#                     the logical stat value
#
# Optional:
#    m_DoTestMaxVal - gets passed to the included StatIStatObj objects
#    m_ExpectedStats - if it's known how many sub-stats there should be in this
#                      logical stat, can say so here and have error checking
#                      in the SetStatIColumnIndex call.                
#                      If it's not known, we set to a default 0, and don't 
#                      check in SetStatIColumnIndex
#
################################################################################

{
   package MultiStatIStatObj;
   @ISA = qw(StatObj);
   use Carp;
   
   ################################################################################
   # sub PeekRecord
   # Call this with a hashref to a StatI record to return the difference between
   # the previous value and the one in this StatI record, but NOT update
   # m_PrevRecordVal or m_ThisRecordVal
   ################################################################################
   sub PeekRecord {
      my $instance = shift;
      unless (ref $instance) {
         croak ("Called MultiStatIStatObj->PeekRecord() on the class; must call on an instance");
      }   

      my $ColumnVals = shift; # must be a hashref;

      my $total = 0;
      
      foreach (@{$instance->{'m_StatIStatObjListref'}}) {
         $total += $_->PeekRecord($ColumnVals);
      }
      
      if (-1 != index($instance->{'m_ReportDataAs'}, 'AVERAGE')) {
         $total /= (scalar(@{$instance->{'m_StatIStatObjListref'}}) / $instance->{'m_DivideByN'});
      }
      
      return ($total);
   
   }

   ################################################################################
   # sub PeekState
   # Call this with a hashref to a StatI record to return the difference between
   # the previous state value and the one in this StatI record, but NOT update
   # m_PrevRecordVal or m_ThisRecordVal
   ################################################################################
   sub PeekState {
      my $instance = shift;
      unless (ref $instance) {
         croak ("Called MultiStatIStatObj->PeekState() on the class; must call on an instance");
      }   
      
      my $total = 0;
      
      my $ColumnVals = shift; # must be a hashref;

      foreach (@{$instance->{'m_StatIStatObjListref'}}) {
         $total += $_->PeekState($ColumnVals);
      }
      
      if (-1 != index($instance->{'m_ReportDataAs'}, 'AVERAGE')) {
         $total /= (scalar(@{$instance->{'m_StatIStatObjListref'}}) / $instance->{'m_DivideByN'});
      }
      
      return ($total);
   
   }


   ################################################################################
   # sub LatchRecord
   # Call this with a hashref to a StatI record to take the difference between
   # the previous value and the one in this StatI record, place that difference 
   # in m_ThisRecordVal, and subsequently update m_PrevRecordVal.  Also checks
   # m_ThisRecordVal against the class-wide GetMaxVal(), if appropriate.
   ################################################################################
   sub LatchRecord {
      my $instance = shift;
      unless (ref $instance) {
         croak ("Called MultiStatIStatObj->LatchRecord() on the class; must call on an instance");
      }   
      
      my $ColumnVals = shift; # must be a hashref;
      
      foreach (@{$instance->{'m_StatIStatObjListref'}}) {
         $_->LatchRecord($ColumnVals);
      }
   
   }
   
   ################################################################################
   # sub LatchState
   # Call this with a hashref to a StatI record to take the difference between
   # the previous STATE's value and the one in this StatI record, place that difference 
   # in m_ThisStateVal, and subsequently update m_PrevStateVal.  Essentially, just
   # like LatchRecord, but only called on state changes.
   ################################################################################
   sub LatchState {
      my $instance = shift;
      unless (ref $instance) {
         croak ("Called MultiStatIStatObj->LatchState() on the class; must call on an instance");
      }   
      
      my $ColumnVals = shift; # must be a hashref;

      foreach (@{$instance->{'m_StatIStatObjListref'}}) {
         $_->LatchState($ColumnVals);
      }
   
   }
   
   ################################################################################
   # sub GetThisRecord
   # Returns m_ThisRecordVal
   ################################################################################
   sub GetThisRecord {
      my $instance = shift;
      unless (ref $instance) {
         croak ("Called MultiStatIStatObj->ThisRecord() on the class; must call on an instance");
      }   
      
      my $total = 0;
	  my $max = 0;
      my $last_name = "" ;
	  my @names ;
	  
      foreach my $d (@{$instance->{'m_StatIStatObjListref'}}) {
		 push(@names,$d->{'m_StatName'}) ;
		 my $val = $d->GetThisRecord();
		 $total += $val;
		 if($val > $max)
		 {
			$max = $val;
		 }
		 
      }
      
      if (-1 != index($instance->{'m_ReportDataAs'}, 'AVERAGE')) {
		 if($total != 0)
		 {
			$total /= (scalar(@{$instance->{'m_StatIStatObjListref'}}) / $instance->{'m_DivideByN'});
		 }
      }
	  
	  if (-1 != index($instance->{'m_ReportDataAs'}, 'MAX')) {
		 return ($max);
	  }
      
	  if (-1 != index($instance->{'m_ReportDataAs'}, 'COUNT')) {
		 return (scalar(@{$instance->{'m_StatIStatObjListref'}})) ;
	  }
	  
	  if (-1 != index($instance->{'m_ReportDataAs'}, 'LASTNAMENORMAL')) {
		 @names = sort{
                 $a =~ m/_(\d+)\./,$a ; my $key1 = $1 ;
                 $b =~ m/_(\d+)\./,$b ; my $key2 = $1 ;
                 $key1 <=> $key2
         } @names ;
		 return ($names[$#names]) ;
	  }
	  
	  if (-1 != index($instance->{'m_ReportDataAs'}, 'LASTNAME')) {
		 @names = sort (@names) ;
		 return ($names[$#names]) ;
	  }
	  	  
	  return ($total);
   }
   
   ################################################################################
   # sub GetThisState
   # Returns m_ThisRecordVal
   ################################################################################
   sub GetThisState {
      my $instance = shift;
      unless (ref $instance) {
         croak ("Called MultiStatIStatObj->ThisState() on the class; must call on an instance");
      }   
      
      my $total = 0;
      
      foreach (@{$instance->{'m_StatIStatObjListref'}}) {
         $total += $_->GetThisState();
      }
      
      if (-1 != index($instance->{'m_ReportDataAs'}, 'AVERAGE')) {
         $total /= (scalar(@{$instance->{'m_StatIStatObjListref'}}) / $instance->{'m_DivideByN'});
      }
      
      return ($total);
   }
    
   ################################################################################
   # sub SetupMultiStatIStats
   # Call this with a hashref to a GennySim-style StatI record hash.  Matches all the 
   # column headers against m_StatRegex.  Matches have StatIStatObj objects created
   # and stuffed in m_StatIStatObjListref.  If m_ExpectedStats is >0, we error-
   # check to see if the right number of matches were found.
   ################################################################################
   sub SetupMultiStatIStats {
      my $instance = shift;
      unless (ref $instance) {
         croak ("Called MultiStatIStatObj->SetStatIColumnIndex() on the class; must call on an instance");
      }   
      
      my $m_StatRegex = $instance->{'m_StatRegex'};
      unless (0 == scalar(@{$instance->{'m_StatIStatObjListref'}})) {
         croak ("Tried to reset ${m_StatRegex}'s list of StatIStatObj - called SetStatIColumnIndex more than once");
      }

      my $ColumnHeaders = shift;    # hashref
      my @MatchingColumnHeaders = grep /$m_StatRegex/, keys(%{$ColumnHeaders});
      
      my $foundthismany = scalar(@MatchingColumnHeaders);
      
      # if ((0 ==$foundthismany) && (0 == $instance->{'m_NULL'})) {
         # croak ("Got no StatI column header matches for ${m_StatRegex}");
      # }
      
      if ($instance->{'m_ExpectedStats'}) {
         my $expectedthismany = $instance->{'m_ExpectedStats'};
         unless ($foundthismany == $expectedthismany) {
            croak ("Got the wrong number of columns for ${m_StatRegex} - expected $expectedthismany matches, got $foundthismany");
         }
      }
      
      if ($instance->{'m_DivideByN'}) {
        my $dividebyn = $instance->{'m_DivideByN'};
        unless (0 == $foundthismany % $dividebyn) {
            croak ("Got the wrong number of columns for ${m_StatRegex} - expected matches divisible by $dividebyn, got $foundthismany");
        }
      }
      
      foreach (@MatchingColumnHeaders) {

         push (@{$instance->{'m_StatIStatObjListref'}}, StatIStatObj->new({'m_StatName' => $_,
                                                                           'm_DoTestMaxVal' => $instance->{'m_DoTestMaxVal'},
                                                                           'NULL' => $instance->{'m_NULL'}}));
         
      }
   }
   
   ################################################################################
   # sub new
   # See above for what's required and what's optional
   # Get a blessed MultiStatIStatObj reference back
   ################################################################################
   sub new {
   
      my $defaultDoTestMaxVal = 1;
      my $defaultExpectedStats = 0;
      my $defaultNULL = 0;
         
      my $class = shift;
      if (ref $class) {
         croak ("Called MultiStatIStatObj->new() on an instance - what's that even mean?! Must call on the class");
      }
      my $ref_init_members = shift; # needs to be a hashref
      
      my @required_members = qw(m_StatRegex m_ReportDataAs);
      my @optional_members = qw(m_DoTestMaxVal m_ExpectedStats NULL);
      
      # generic test for required members
      foreach my $required_member (@required_members) {
         unless (grep $required_member eq $_, keys(%$ref_init_members)) {
            croak ("Called MultiStatIStatObj->new without missing member $required_member in the hashref");
         }
      }
      
      # generic test for optional members
      foreach my $init_member (keys(%$ref_init_members)) {
         unless (grep $init_member eq $_, ((@optional_members), (@required_members))) {
            croak ("Called MultiStatIStatObj->new with unrecognized member $init_member in the hashref");
         }
      }
      
      my $m_StatRegex = $ref_init_members->{'m_StatRegex'};

      my @m_StatIStatObjList = ();

      my $m_DoTestMaxVal = $defaultDoTestMaxVal;
      if (defined($ref_init_members->{'m_DoTestMaxVal'})) {$m_DoTestMaxVal = $ref_init_members->{'m_DoTestMaxVal'};}

      my $m_ExpectedStats = $defaultExpectedStats;
      if (defined($ref_init_members->{'m_ExpectedStats'})) {$m_DoTestMaxVal = $ref_init_members->{'m_ExpectedStats'};}

      my $m_NULL = $defaultNULL;
      if (defined($ref_init_members->{'NULL'})) {$m_NULL = $ref_init_members->{'NULL'};}

      my $m_ReportDataAs = $ref_init_members->{'m_ReportDataAs'};
      unless (grep $m_ReportDataAs =~ /$_/ , qw(^SUM$ ^AVERAGEDIV\d+$ ^MAX$ ^COUNT$ ^LASTNAME$ ^LASTNAMENORMAL$)) {
         croak ("Called MultiStatIStatObj->new() with an invalid m_ReportDataAs ($m_ReportDataAs) - must be SUM or AVERAGEDIVn or COUNT or MAX or LASTNAME or LASTNAMENORMAL");
      }
      
      my $m_DivideByN = 0;
      if ($m_ReportDataAs =~ /^AVERAGEDIV(\d+)$/) {$m_DivideByN = $1;}
      
      my $self = {
                     'm_StatRegex' => $m_StatRegex,
                     'm_StatIStatObjListref' => \@m_StatIStatObjList,
                     'm_DoTestMaxVal' => $m_DoTestMaxVal,
                     'm_NULL' => $m_NULL,
                     'm_ExpectedStats' => $m_ExpectedStats,
                     'm_ReportDataAs' => $m_ReportDataAs,
                     'm_DivideByN' => $m_DivideByN,
                  };
      bless $self, $class; 
      return $self;
   }


}



1;