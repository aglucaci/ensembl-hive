=pod 

=head1 NAME

Bio::EnsEMBL::Hive::RunnableDB::JobFactory

=head1 DESCRIPTION

A generic module for creating batches of similar jobs using dataflow mechanism
(a fan of jobs is created in one branch and the funnel in another).
Make sure you wire this buliding block properly from outside.

There are 4 ways the batches are generated, depending on the source of ids:

    * inputlist.  The list is explicitly given in the parameters, can be abbreviated: 'inputlist' => ['a'..'z']

    * inputfile.  The list is contained in a file whose name is supplied as parameter: 'inputfile' => 'myfile.txt'

    * inputquery. The list is generated by an SQL query (against the production database by default) : 'inputquery' => 'SELECT object_id FROM object WHERE x=y'

    * inputcmd.   The list is generated by running a system command: 'inputcmd' => 'find /tmp/big_directory -type f'

If 'sema_funnel_branch_code' is defined, it becomes the destination branch for a semaphored funnel job,
whose count is automatically set to the number of fan jobs that it will be waiting for.


=head1 USAGE EXAMPLES

(to be added)

=cut

package Bio::EnsEMBL::Hive::RunnableDB::JobFactory;

use strict;
use DBI;
use Bio::EnsEMBL::Hive::Utils 'stringify';  # import 'stringify()'
use base ('Bio::EnsEMBL::Hive::ProcessWithParams');

sub fetch_input {   # we have nothing to fetch, really
    my $self = shift @_;

    return 1;
}

sub run {
    my $self = shift @_;

    my $template_hash   = $self->param('input_id')      || die "'input_id' is an obligatory parameter";
    my $numeric         = $self->param('numeric')       || 0;
    my $step            = $self->param('step')          || 1;
    my $randomize       = $self->param('randomize')     || 0;

    my $inputlist       = $self->param('inputlist');
    my $inputfile       = $self->param('inputfile');
    my $inputquery      = $self->param('inputquery');
    my $inputcmd        = $self->param('inputcmd');

    my $list = $inputlist
        || ($inputfile  && $self->make_list_from_file($inputfile))
        || ($inputquery && $self->make_list_from_query($inputquery))
        || ($inputcmd   && $self->make_list_from_cmd($inputcmd))
        || die "range of values should be defined by setting 'inputlist', 'inputfile' or 'inputquery'";

    if($randomize) {
        fisher_yates_shuffle_in_place($list);
    }

    my $output_ids = $self->split_list_into_ranges($template_hash, $numeric, $list, $step);
    $self->param('output_ids', $output_ids);
}

sub write_output {  # nothing to write out, but some dataflow to perform:
    my $self = shift @_;

    my $output_ids              = $self->param('output_ids');
    my $fan_branch_code         = $self->param('fan_branch_code') || 2;
    my $sema_funnel_branch_code = $self->param('sema_funnel_branch_code');  # if set, it is a request for a semaphored funnel

    if($sema_funnel_branch_code) {

            # first flow into the sema_funnel_branch
        my ($funnel_job_id) = @{ $self->dataflow_output_id($self->input_id, $sema_funnel_branch_code, { -semaphore_count => scalar(@$output_ids) })  };

            # then "fan out" into fan_branch, and pass the $funnel_job_id to all of them
        my $fan_job_ids = $self->dataflow_output_id($output_ids, $fan_branch_code, { -semaphored_job_id => $funnel_job_id } );

    } else {

            # simply "fan out" into fan_branch_code:
        $self->dataflow_output_id($output_ids, $fan_branch_code);
    }

    return 1;
}

################################### main functionality starts here ###################

sub make_list_from_file {
    my ($self, $inputfile) = @_;

    open(FILE, $inputfile) or die $!;
    my @lines = <FILE>;
    chomp @lines;
    close(FILE);

    return \@lines;
}

sub make_list_from_query {
    my ($self, $inputquery) = @_;

    my $dbc;
    if(my $db_conn = $self->param('db_conn')) {
        $dbc = DBI->connect("DBI:mysql:$db_conn->{-dbname}:$db_conn->{-host}:$db_conn->{-port}", $db_conn->{-user}, $db_conn->{-pass}, { RaiseError => 1 });
    } else {
        $dbc = $self->db->dbc;
    }

    my @ids = ();
    my $sth = $dbc->prepare($inputquery);
    $sth->execute();
    while (my ($id)=$sth->fetchrow_array()) {
        push @ids, $id;
    }
    $sth->finish();

    return \@ids;
}

sub make_list_from_cmd {
    my ($self, $inputcmd) = @_;

    my @lines = `$inputcmd`;
    chomp @lines;

    return \@lines;
}

sub split_list_into_ranges {
    my ($self, $template_hash, $numeric, $list, $step) = @_;

    my @ranges = ();

    while(@$list) {
        my $range_start = shift @$list;
        my $range_end   = $range_start;
        my $range_count = 1;
        while($range_count<$step && @$list) {
            my $next_value     = shift @$list;
            my $predicted_next = $range_end;
            if(++$predicted_next eq $next_value) {
                $range_end = $next_value;
                $range_count++;
            } else {
                unshift @$list, $next_value;
                last;
            }
        }

        push @ranges, $self->create_one_range_hash($template_hash, $numeric, $range_start, $range_end, $range_count);
    }
    return \@ranges;
}

sub create_one_range_hash {
    my ($self, $template_hash, $numeric, $range_start, $range_end, $range_count) = @_;

    my %range_hash = (); # has to be a fresh hash every time

    while( my ($key,$value) = each %$template_hash) {

            # evaluate Perl-expressions after substitutions:
        if($value=~/\$Range/) {
            $value=~s/\$RangeStart/$range_start/g; 
            $value=~s/\$RangeEnd/$range_end/g; 
            $value=~s/\$RangeCount/$range_count/g; 

            if($numeric) {
                $value = eval($value);
            }
        }
        $range_hash{$key} = $value;
    }
    return \%range_hash;
}

sub fisher_yates_shuffle_in_place {
    my $array = shift @_;

    for(my $upper=scalar(@$array);--$upper;) {
        my $lower=int(rand($upper+1));
        next if $lower == $upper;
        @$array[$lower,$upper] = @$array[$upper,$lower];
    }
}

1;
