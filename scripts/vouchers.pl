#!/usr/bin/perl

# This file is copyright (C) 2007the LedgerSMB core team and licensed under 
# the GNU General Public License.  For more information please see the included
# LICENSE and COPYRIGHT files

# THIS FILE NEEDS POD

package LedgerSMB::Scripts::vouchers;
our $VERSION = '0.1';

$menufile = "menu.ini";
use LedgerSMB::Batch;
use LedgerSMB::Voucher;
use LedgerSMB::Template;
use strict;

sub create_batch {
    my ($request) = @_;
    $request->{hidden} = [
        {name => "batch_type", value => $request->{batch_type}},
    ];
    my $template = LedgerSMB::Template->new(
        user =>$request->{_user}, 
        locale => $request->{_locale},
        path => 'UI',
        template => 'create_batch',
        format => 'HTML'
    );
    $template->render($request);
}

sub create_vouchers {
    my ($request) = shift @_;
    my $batch = LedgerSMB::Batch->new({base => $request});
    $batch->{batch_class} = $request->{batch_type};
    $batch->create;
    add_vouchers($batch);
}

sub search_transactions {
}


sub add_vouchers {
    #  This function is not safe for caching as long as the scripts are in bin.
    #  This is because these scripts import all functions into the *current*
    #  namespace.  People using fastcgi and modperl should *not* cache this 
    #  module at the moment. -- CT
    #  Also-- request is in 'our' scope here due to the redirect logic.
    our ($request) = shift @_;
    use LedgerSMB::Form;
    my $batch = LedgerSMB::Batch->new({base => $request});
    our $vouchers_dispatch = 
    {
        payable    => {script => 'bin/ap.pl', function => sub {add()}},
        receivable => {script => 'bin/ar.pl', function => sub {add()}},
        gl         => {script => 'bin/gl.pl', function => sub {add()}},
        receipt   => {script => 'scripts/payment.pl', 
	             function => sub {
				my ($request) = @_;
				$request->{account_class} = 2;
				LedgerSMB::Scripts::payment::payments($request);
				}},
        payment   => {script => 'scripts/payment.pl', 
	             function => sub {
				my ($request) = @_;
				$request->{account_class} = 1;
				LedgerSMB::Scripts::payment::payments($request);
				}},
        payment_reversal => {
                      script => 'scripts/payment.pl',
                    function => sub {
				my ($request) = @_;
				$request->{account_class} = 1;
				LedgerSMB::Scripts::payment::get_search_criteria($request);
				}},
        receipt_reversal => {
                      script => 'scripts/payment.pl',
                    function => sub {
				my ($request) = @_;
				$request->{account_class} = 2;
				LedgerSMB::Scripts::payment::get_search_criteria($request);
				}},
     
	
    };

    our $form = new Form;
    our $locale = $request->{_locale};

    for (keys %$request){
        $form->{$_} = $request->{$_};
    }

    $form->{batch_id} = $batch->{id};
    $form->{approved} = 0;
    $form->{transdate} = $request->{batch_date};

    $request->{batch_id} = $batch->{id};
    $request->{approved} = 0;
    $request->{transdate} = $request->{batch_date};


    my $script = $vouchers_dispatch->{$request->{batch_type}}{script};
    $form->{script} = $script;
    $form->{script} =~ s|.*/||;
    if ($script =~ /^bin/){

        # Note that the line below is generally considered incredibly bad form. 
        # However, the code we are including is going to require it for now. 
        # -- CT
        { no strict; no warnings 'redefine'; do $script; }

    } elsif ($script =~ /scripts/) {
	# Maybe we should move this to a require statement?  --CT
         { do $script } 

    }

    $vouchers_dispatch->{$request->{batch_type}}{function}($request);
}

sub search_batch {
    my ($request) = @_;
    my $batch_request = LedgerSMB::Batch->new(base => $request);
    $batch_request->get_search_criteria();
    my $template = LedgerSMB::Template->new(
        user     => $request->{_user},
        locale   => $request->{_locale},
        path     => 'UI/batch',
        template => 'filter',
        format   => 'HTML', 
    );
    $template->render($batch_request);
}

sub list_batches {
    my ($request) = @_;
    my $batch = LedgerSMB::Batch->new(base => $request);
    my @search_results = $batch->get_search_results;
    $batch->{script} = "vouchers.pl";

    my @columns = 
        qw(select id control_code description transaction_total payment_total);

    my $base_href = "vouchers.pl";
    my $search_href = "$base_href?action=list_batches";
    my $batch_href = "$base_href?action=get_batch";

    for my $key (
       qw(class_id approved created_by description amount_gt amount_lt)
    ){
       $search_href .= "&$key=$batch->{key}";
    }

    my %column_heading = (
        'select'          => $batch->{_locale}->text('Select'),
        transaction_total => {
             text => $batch->{_locale}->text('AR/AP/GL Total'),
             href => "$search_href&order_by=transaction_total"
        },
        payment_total     => { 
             text => $batch->{_locale}->text('Paid/Received Total'),
             href => "$search_href&order_by=payment_total"
        },
        description       => {
             text => $batch->{_locale}->text('Description'),
             href => "$search_href&order_by=description"
        },
        control_code      => {
             text => $batch->{_locale}->text('Batch Number'),
             href => "$search_href&order_by=control_code"
        },
        id                => {
             text => $batch->{_locale}->text('ID'),
             href => "$search_href&order_by=control_code"
        },
    );
    my $count = 0;
    my @rows;
    for my $result (@search_results){
        ++$count;
        $batch->{"row_$count"} = $result->{id};
        push @rows, {
            'select'          => {
                                 input => {
                                           type  => 'checkbox',
                                           value => 1,
                                           name  => "batch_$result->{id}"
                                 }
            },
            transaction_total => $batch->format_amount(
                                     amount => $result->{transaction_total}
				),
            payment_total     => $batch->format_amount (
                                     amount => $result->{payment_total}
                                ),
            description => $result->{description},
            control_code => {
                             text  => $result->{control_code},
                             href  => "$batch_href&batch_id=$result->{id}",

            },
            id => $result->{id},
        };
    }
    $batch->{rowcount} = $count;
    my $template = LedgerSMB::Template->new(
        user     => $request->{_user},
        locale   => $request->{_locale},
        path     => 'UI',
        template => 'form-dynatable',
        format   => ($batch->{format}) ? $batch->{format} : 'HTML', 
    );

    my $hiddens = $batch->take_top_level();
    $batch->{rowcount} = "$count";
    delete $batch->{search_results};

    $template->render({ 
	form    => $batch,
	columns => \@columns,
	heading => \%column_heading,
        rows    => \@rows,
        hiddens => $hiddens,
        buttons => [{
                    name  => 'action',
                    type  => 'submit',
                    text  => $request->{_locale}->text('Post'),
                    value => 'batch_approve',
                    class => 'submit',
		},{
                    name  => 'action',
                    type  => 'submit',
                    text  => $request->{_locale}->text('Delete'),
                    value => 'batch_delete',
                    class => 'submit',
               }]
    });
        
}

sub get_batch {
    my ($request)  = @_;
    my $batch = LedgerSMB::Batch->new(base => $request);
    $batch->{script} = 'vouchers.pl';
    my $rows = [];

    $batch->{id} ||= $batch->{batch_id};
    # $batch->get;
    my @vouchers = $batch->list_vouchers;

    my $base_href = "vouchers.pl?action=get_batch&batch_id=$batch->{batch_id}";

    my @columns = qw(selected id description batch_class reference amount date);
    my $heading = {
        selected    => $request->{_locale}->text('Selected'),
        id          => {
                        text => $request->{_locale}->text('ID'),
                        href => "$base_href&order_by=id"
        },
        description => { 
                        href => "$base_href&order_by=description",
                        text => $request->{_locale}->text('Description'),
        },
        batch_class => {
                        text => $request->{_locale}->text('Class'),
                        href => "$base_href&order_by=class"
        },
        amount      => {
                        text => $request->{_locale}->text('Amount'),
                        href => "$base_href&order_by=amount"
        }, 
        reference   => {
                        text => $request->{_locale}->text('Source/Reference'),
                        href => "$base_href&order_by=reference"
        },
        date        => {
                        text => $request->{_locale}->text('Date'),
                        href => "$base_href&order_by=date"
        }
    };

    my $classcount;
    my $count = 1;
    for my $row (@vouchers) {
       $classcount = ($classcount + 1) % 2;
       $classcount ||= 0;
       push @$rows, {
           description => $row->{description},
           id          => $row->{id},
           batch_class => $row->{batch_class},
           amount      => $batch->format_amount(amount => $row->{amount}),
           date        => $row->{transaction_date},
           reference   => $row->{reference},
           i           => "$classcount",
           selected    => {
                           input => {
                                  type  => 'checkbox',
                                  name  => "voucher_$row->{id}",
                                  value => "1"
                                  }
                          }  
       };
       $batch->{"row_$count"} = $row->{id};
       ++$count;
    }

    $batch->{rowcount} = $count;

    $batch->{title} = "Batch ID: $batch->{batch_id}";
    my $template = LedgerSMB::Template->new(
        user     => $request->{_user},
        locale   => $request->{_locale},
        path     => 'UI',
        template => 'form-dynatable',
        format   => ($batch->{format}) ? $batch->{format} : 'HTML', 
    );
    my $hiddens = $batch->take_top_level();
    $template->render({ 
	form    => $batch,
	columns => \@columns,
	heading => $heading,
        rows    => $rows,
        hiddens => $hiddens,
        buttons => [{
                    name  => 'action',
                    type  => 'submit',
                    text  => $request->{_locale}->text('Post Batch'),
                    value => 'batch_approve',
                    class => 'submit',
		},{
                    name  => 'action',
                    type  => 'submit',
                    text  => $request->{_locale}->text('Delete Batch'),
                    value => 'batch_delete',
                    class => 'submit',
		},{
                    name  => 'action',
                    type  => 'submit',
                    text  => $request->{_locale}->text('Delete Vouchers'),
                    value => 'voucher_delete',
                    class => 'submit',
               }]
    });
        
    
}

sub list_batches_batch_delete {
    batch_delete(@_);
}

sub list_batches_batch_approve {
    batch_approve(@_);
}

sub get_batch__batch_approve {
    batch_approve(@_);
}

sub get_batch_voucher_delete {
    my ($request) = @_;
    my $batch = LedgerSMB::Batch->new(base => $request);
    for my $count (1 .. $batch->{rowcount}){
        my $voucher_id = $batch->{"row_$count"};
        next unless $batch->{"voucher_$voucher_id"};
        $batch->delete_voucher($voucher_id);
    }
    search_batch($request);
}

sub batch_approve {
    my ($request) = @_;
    my $batch = LedgerSMB::Batch->new(base => $request);
    for my $count (1 .. $batch->{rowcount}){
        next unless $batch->{"batch_" . $batch->{"row_$count"}};
        $batch->{batch_id} = $batch->{"row_$count"};
        $batch->post;
    }
    search_batch($request);
}

sub batch_delete {
    my ($request)  = @_;
    my $batch = LedgerSMB::Batch->new(base => $request);
    for my $count (1 .. $batch->{rowcount}){
        next unless $batch->{"batch_" . $batch->{"row_$count"}};
        $batch->{batch_id} = $batch->{"row_$count"};
        $batch->delete;
    }
    search_batch($request);
}

eval { do "scripts/custom/vouchers.pl"};
1;
