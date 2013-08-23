package general;

use diagnostics;
use strict;
use warnings;
use Data::Dumper;

use general_config;
use output_functions;


################# small function to evaluate a numerical expression, check for errors and report them
### usage: evaluate_numerical_expression()
sub evaluate_numerical_expression
{
	if (@_ != 3) {return 0;}

	my ($expression, $error_msg_header, $formula) = @_;

	my $evalErrMsg = "";
	my $expression_before_eval = $expression;

	#(not ($expression =~ /STAT_ERROR/)) or ($err = 1); #could be error, but coho doesn't output 0-value stats :(
	$expression =~ s/STAT_ERROR\[*\d*\]*/0/eg;

	# Fix up exponentiation and equality operators
	$expression =~ s/\s*\^\s*/ ** /g;
	$expression =~ s/\s*=+\s*/ == /g;

	if ($expression =~ /\(\s*\)/) ### empty clauses exist
	{
		undef $expression;
	}
	else
	{
		$expression = eval($expression);
		$evalErrMsg = $@;
		chomp $evalErrMsg;
	}
	if ((not defined $expression) or ($expression !~ /^[\+\-]?\d+\.?\d*(e[\-\+]\d+)?$/) or ($evalErrMsg ne ""))	# Error has occured
	{
		if (($evalErrMsg =~ /^Illegal division by zero/) and ($formula =~ /p\d\.c[1-9]\./))
		{
			# Don't report an error since this formula is for a core number higher than 0 (not the first core)
		}
		else	# Report an error message
		{
			my $expression_msg = "";
			my $eval_msg = "";
			if (defined($expression)) {$expression_msg = "The calculated value is: $expression\n";}
			if ($evalErrMsg ne "") {$eval_msg = "The \"eval\" error message is: $evalErrMsg\n";}
			output_functions::print_to_log_only_once("$error_msg_header\nValue before evaluation is: $expression_before_eval\n$expression_msg$eval_msg" . "Setting expression value to 0\n");
		}
		$expression = 0;
	}

	return $expression;
}
#################



1;
