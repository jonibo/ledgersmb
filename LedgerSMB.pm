=head1 NAME

LedgerSMB  The Base class for many LedgerSMB objects, including DBObject.

=head1 SYOPSIS

This module creates a basic request handler with utility functions available
in database objects (LedgerSMB::DBObject)

=head1 METHODS

=item new ()
This method creates a new base request instance. 

=item date_to_number (user => $LedgerSMB::User, date => $string);
This function takes the date in the format provided and returns a numeric 
string in YYMMDD format.  This may be moved to User in the future.

=item debug (file => $path);

This dumps the current object to the file if that is defined and otherwise to 
standard output.

=item escape (string => $string);

This function returns the current string escaped using %hexhex notation.

=item unescape (string => $string);

This function returns the $string encoded using %hexhex using ordinary notation.

=item format_amount (user => $LedgerSMB::User::hash, amount => $string, precision => $integer, neg_format => (-|DRCR));

The function takes a monetary amount and formats it according to the user 
preferences, the negative format (- or DR/CR).  Note that it may move to
LedgerSMB::User at some point in the future.

=item parse_amount (user => $LedgerSMB::User::hash, amount => $variable);
If $amount is a Bigfloat, it is returned as is.  If it is a string, it is 
parsed according to the user preferences stored in the LedgerSMB::User object.

=item format_fields (fields => \@array);
This function converts fields to their appropriate representation in 
HTML/SGML/XML or LaTeX.

=item is_blank (msg=> $string, name => $string)
This function invokes self->error($msg) if the property contains no 
non-whitespace characters.

=item num_text_rows (string => $string, cols => $number, max => $number);

This function determines the likely number of rows needed to hold text in a 
textbox.  It returns either that number or max, which ever is lower.

=item merge ($hashref, keys => @list, index => $number);
This command merges the $hashref into the current object.  If keys are 
specified, only those keys are used.  Otherwise all keys are merged.

If an index is specified, the merged keys are given a form of 
"$key" . "_$index", otherwise the key is used on both sides.

=item redirect (msg => $string)

This function redirects to the script and argument set determined by 
$self->{callback}, and if this is not set, goes to an info screen and prints
$msg.

=item redo_rows (fields =>, new =>, count =>,  rows => $integer);
This function is undergoing serious redesign at the moment.

=head1 Copyright (C) 2006, The LedgerSMB core team.

# This work contains copyrighted information from a number of sources all used
# with permission.
#
# This file contains source code included with or based on SQL-Ledger which
# is Copyright Dieter Simader and DWS Systems Inc. 2000-2005 and licensed
# under the GNU General Public License version 2 or, at your option, any later
# version.  For a full list including contact information of contributors,
# maintainers, and copyright holders, see the CONTRIBUTORS file.
#
# Original Copyright Notice from SQL-Ledger 2.6.17 (before the fork):
# Copyright (C) 2000
#
#  Author: DWS Systems Inc.
#     Web: http://www.sql-ledger.org
#
# Contributors: Thomas Bayen <bayen@gmx.de>
#               Antti Kaihola <akaihola@siba.fi>
#               Moritz Bunkus (tex)
#               Jim Rawlings <jim@your-dba.com> (DB2)
#======================================================================
=cut

use Math::BigFloat lib=>'GMP';
use LedgerSMB::Sysconfig;
use Data::Dumper;
use strict;

package LedgerSMB;


sub new {
	# This will probably be the last to be revised.

	my $type = shift;

	my $argstr = shift;

	read(STDIN, $_, $ENV{CONTENT_LENGTH});

	if ($argstr){
		 $_ = $argstr;
	}
	elsif ($ENV{QUERY_STRING}) {
		$_ = $ENV{QUERY_STRING};
	}

	elsif ($ARGV[0]) {
		$_ = $ARGV[0];
	}
	
	my $self = {};
	%$self = split /[&=]/;
	for (keys %$self) { $self->{$_} = unescape("", $self->{$_}) }

	if (substr($self->{action}, 0, 1) !~ /( |\.)/) {
		$self->{action} = lc $self->{action};
		$self->{action} =~ s/( |-|,|\#|\/|\.$)/_/g;
	}

	$self->{menubar} = 1 if $self->{path} =~ /lynx/i;
	#menubar will be deprecated, replaced with below
	$self->{lynx} = 1 if $self->{path} =~ /lynx/i;

	$self->{version} = "1.3.0 Alpha 0 Pre";
	$self->{dbversion} = "1.2.0";

	bless $self, $type;

}


sub debug {
	my $self = shift @_;
	my %args = @_;
	my $file = $args{file};
	my $d = Data::Dumper->new([@_]);
	$d->Sortkeys(1);

	if ($file) {
		open(FH, '>', "$file") or die $!;
		print FH $d->Dump();
		close(FH);
	} else {
		print "\n";
		print $d->Dump();	
	}

} 


sub escape {
	my ($self) = @_;
	my %args = @_;
	my $str = $args{string};

	my $regex = qr/([^a-zA-Z0-9_.-])/;
	$str =~ s/$regex/sprintf("%%%02x", ord($1))/ge;
	$str;
}


sub unescape {
	my ($self) = @_;
	my %args = @_;
	my $str = $args{string};

	$str =~ tr/+/ /;
	$str =~ s/\\$//;

	$str =~ s/%([0-9a-fA-Z]{2})/pack("c",hex($1))/eg;
	$str =~ s/\r?\n/\n/g;

	$str;

}

sub is_blank {
	my $self = shift @_;
	my %args = @_;
	my $name = $args{name};
	my $msg = $args{msg};
	
	$self->error($msg) if $self->{$name} =~ /^\s*$/;
}

sub num_text_rows {
	my $self = shift @_;
	my %args = @_;
	my $string = $args{string};
	my $cols = $args{cols};
	my $maxrows = $args{max};
	
	my $rows = 0;

	for (split /\n/, $string) {
		my $line = $_;
		while (length($line) > $cols){
			my $fragment = substr($line, 0, $cols + 1);
			my $fragment = s/^(.*)\S*$/$1/;
			$line = s/$fragment//;
			if ($line eq $fragment){ # No word breaks!
				$line = "";
			}
			++$rows;
		}
		++$rows;
	}

	$maxrows = $rows unless defined $maxrows;

	return ($rows > $maxrows) ? $maxrows : $rows;

}


sub redirect {
	my $self = shift @_;
	my %args = @_;
	my $msg = $args{msg};

	if ($self->{callback} || !$msg) {

		main::redirect();
	} else {

		$self->info($msg);
	}
}

sub format_fields {
	# We should look at moving this into LedgerSMB::Template.
	# And cleaning it up......  Chris

	my $self = shift @_;
	my %args = @_;
	my @fields = @{$args{fields}};

	my $format = $self->{format};

	if ($self->{format} =~ /(postscript|pdf)/) {
		$format = 'tex';
	}

	my %replace = ( 
		'order' => { 
			html => [ '<', '>', '\n', '\r' ],
			txt  => [ '\n', '\r' ],
			tex  => [ quotemeta('\\'), '&', '\n','\r', 
				'\$', '%', '_', '#',
				quotemeta('^'), '{', '}', '<', '>', '£' 
				] },
		html => { '<'  => '&lt;', '>' => '&gt;','\n' => '<br />', 
			'\r' => '<br />' },
		txt  => { '\n' => "\n", '\r' => "\r" },
		tex  => {'&' => '\&', '$' => '\$', '%' => '\%', '_' => '\_',
			'#' => '\#', quotemeta('^') => '\^\\', '{' => '\{', 
			'}' => '\}', '<' => '$<$', '>' => '$>$',
			'\n' => '\newline ', '\r' => '\newline ', 
			'£' => '\pounds ', quotemeta('\\') => '/'} 
	);

	my $key;

	foreach $key (@{ $replace{order}{$format} }) {
		for (@fields) { $self->{$_} =~ s/$key/$replace{$format}{$key}/g }
	}

}


# TODO:  Either we should have an amount class with formats and such attached
# Or maybe we should move this into the user class...
sub format_amount {
	my $self = shift @_;
	my %args = @_;
	my $myconfig = $args{user};
	my $amount = $args{amount};
	my $places = $args{precision};
	my $dash = $args{neg_format};

	my $negative ;
	if ($amount){
		$amount = $self->parse_amount($myconfig, $amount);
		$negative = ($amount < 0);
		$amount =~ s/-//;
	}

	if ($places =~ /\d+/) {
		#$places = 4 if $places == 2;
		$amount = $self->round_amount($amount, $places);
	}

	# is the amount negative

	# Parse $myconfig->{numberformat}



	my ($ts, $ds) = ($1, $2);

	if ($amount) {

		if ($myconfig->{numberformat}) {

			my ($whole, $dec) = split /\./, "$amount";
			$amount = join '', reverse split //, $whole;

			if ($places) {
				$dec .= "0" x $places;
				$dec = substr($dec, 0, $places);
			}

			if ($myconfig->{numberformat} eq '1,000.00') {
				$amount =~ s/\d{3,}?/$&,/g;
				$amount =~ s/,$//;
				$amount = join '', reverse split //, $amount;
				$amount .= "\.$dec" if ($dec ne "");
			}

			if ($myconfig->{numberformat} eq '1 000.00') {
				$amount =~ s/\d{3,}?/$& /g;
				$amount =~ s/\s$//;
				$amount = join '', reverse split //, $amount;
				$amount .= "\.$dec" if ($dec ne "");
			}

			if ($myconfig->{numberformat} eq "1'000.00") {
				$amount =~ s/\d{3,}?/$&'/g;
				$amount =~ s/'$//;
				$amount = join '', reverse split //, $amount;
				$amount .= "\.$dec" if ($dec ne "");
			}

			if ($myconfig->{numberformat} eq '1.000,00') {
				$amount =~ s/\d{3,}?/$&./g;
				$amount =~ s/\.$//;
				$amount = join '', reverse split //, $amount;
				$amount .= ",$dec" if ($dec ne "");
			}

			if ($myconfig->{numberformat} eq '1000,00') {
				$amount = "$whole";
				$amount .= ",$dec" if ($dec ne "");
			}

			if ($myconfig->{numberformat} eq '1000.00') {
				$amount = "$whole";
				$amount .= ".$dec" if ($dec ne "");
			}

			if ($dash =~ /-/) {
				$amount = ($negative) ? "($amount)" : "$amount";
			} elsif ($dash =~ /DRCR/) {
				$amount = ($negative) ? "$amount DR" : "$amount CR";
			} else {
				$amount = ($negative) ? "-$amount" : "$amount";
			}
		}

	} else {

		if ($dash eq "0" && $places) {

			if ($myconfig->{numberformat} eq '1.000,00') {
				$amount = "0".","."0" x $places;
			} else {
				$amount = "0"."."."0" x $places;
			}

		} else {
			$amount = ($dash ne "") ? "$dash" : "";
		}
	}

	$amount;
}

# This should probably go to the User object too.
sub parse_amount {
	my $self = shift @_;
	my %args = @_;
	my $myconfig = $args{user};
	my $amount = $args{amount};

	if ($amount eq '' or $amount == undef){
		return 0;
	}

	if (UNIVERSAL::isa($amount, 'Math::BigFloat')){ # Amount may not be an object	
		return $amount;
	}
	my $numberformat = $myconfig->{numberformat};


	if (($numberformat eq '1.000,00') ||
		($numberformat eq '1000,00')) {

		$amount =~ s/\.//g;
		$amount =~ s/,/./;
	}
	if ($numberformat eq '1 000.00'){
		$amount =~ s/\s//g;
	}

	if ($numberformat eq "1'000.00") {
		$amount =~ s/'//g;
	}


	$amount =~ s/,//g;
	if ($amount =~ s/\((\d*\.?\d*)\)/$1/){
		$amount = $1 * -1;
	}
	if ($amount =~ s/(\d*\.?\d*)\s?DR/$1/){
		$amount = $1 * -1;
	}
	$amount =~ s/\s?CR//;
	$amount = new Math::BigFloat($amount);
	return ($amount * 1);
}


sub round_amount {

	my ($self, $amount, $places) = @_;

	# These rounding rules follow from the previous implementation.
	# They should be changed to allow different rules for different accounts.
	Math::BigFloat->round_mode('+inf') if $amount >= 0;
	Math::BigFloat->round_mode('-inf') if $amount < 0;

	$amount = Math::BigFloat->new($amount)->ffround(-$places) if $places >= 0;
	$amount = Math::BigFloat->new($amount)->ffround(-($places-1)) if $places < 0;

	return $amount;
}

sub call_procedure {
	my $self = shift @_;
	my %args = @_;
	my $procname = $args{procname};
	my @args = @{$args{args}};
	my $argstr = "";
	my @results;
	for (1 .. scalar @args){
		$argstr .= "?, ";
	}
	$argstr =~ s/\, $//;
	my $query = "SELECT * FROM $procname()";
	$query =~ s/\(\)/($argstr)/;
	my $sth = $self->{dbh}->prepare($query);
	$sth->execute(@args);
	while (my $ref = $sth->fetchrow_hashref('NAME_lc')){
		push @results, $ref;
	}
	@results;
}

# This should probably be moved to User too...
sub date_to_number {
	my $self = shift @_;
	my %args = @_;
	my $myconfig = $args{user};
	my $date = $args{date};

	my ($yy, $mm, $dd);
	if ($date && $date =~ /\D/) {

		if ($myconfig->{dateformat} =~ /^yy/) {
			($yy, $mm, $dd) = split /\D/, $date;
		}

		if ($myconfig->{dateformat} =~ /^mm/) {
			($mm, $dd, $yy) = split /\D/, $date;
		}

		if ($myconfig->{dateformat} =~ /^dd/) {
			($dd, $mm, $yy) = split /\D/, $date;
		}

		$dd *= 1;
		$mm *= 1;
		$yy += 2000 if length $yy == 2;

		$dd = substr("0$dd", -2);
		$mm = substr("0$mm", -2);

		$date = "$yy$mm$dd";
	}

	$date;
}


# Database routines used throughout

sub db_init {
	my $self = shift @_;
	my %args = @_;
	my $myconfig = $args{user};

	my $dbh = DBI->connect($myconfig->{dbconnect}, $myconfig->{dbuser}, 
		$myconfig->{dbpasswd}, {AutoCommit => 0}) or $self->dberror;

	if ($myconfig->{dboptions}) {
		$dbh->do($myconfig->{dboptions});
	}

	my $query = 
		"SELECT t.extends, 
			coalesce (t.table_name, 'custom_' || extends) 
			|| ':' || f.field_name as field_def
		FROM custom_table_catalog t
		JOIN custom_field_catalog f USING (table_id)";
	my $sth = $self->{dbh}->prepare($query);
	$sth->execute;
	my $ref;
	while ($ref = $sth->fetchrow_hashref('NAME_lc')){
		push @{$self->{custom_db_fields}{$ref->{extends}}},
			$ref->{field_def};
	}
}

# This needs some *real* work.
sub redo_rows {

	$self = shift @_;
	%args = @_;
	@flds = @{$args{fields}};
	$new = $args{new};
	$count = $args{count};
	$numrows = $args{rows};

	my @ndx = ();

	for (1 .. $count) { 
		push @ndx, { num => $new->[$_-1]->{runningnumber}, ndx => $_ } 
	}

	my $i = 0;
	my $j;
	# fill rows
	foreach my $item (sort { $a->{num} <=> $b->{num} } @ndx) {
		$i++;
		$j = $item->{ndx} - 1;
		for (@flds) { $self->{"${_}_$i"} = $new->[$j]->{$_} }
	}

	# delete empty rows
	for $i ($count + 1 .. $numrows) {
		for (@{$flds}) { delete $self->{"${_}_$i"} }
	}
}


sub merge {
	my ($self, $src) = @_;
	for my $arg ($self, $src){
		shift;
	}
	my %args = @_;
	my @keys = @{$args{keys}};
	my $index = $args{index};
	if (! scalar @keys){
		@keys = keys %{$src};
	}
	for my $arg (keys %$src){
		if ($index){
			$dst_arg = $arg . "_$index";
		} else {
			$dst_arg = $arg;
		}
		$self->{$dst_arg} = $src->{$arg};
	}
}

1;