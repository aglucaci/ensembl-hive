=pod 

=head1 NAME

    Bio::EnsEMBL::Hive::Valley

=head1 DESCRIPTION

    A Valley represents a collection of available Meadows.

    Certain methods fit better with the concept of Valley -
    such as identifying all dead workers, or killing a particular one given worker_id.

=head1 LICENSE

    Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
    Copyright [2016-2017] EMBL-European Bioinformatics Institute

    Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

         http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software distributed under the License
    is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and limitations under the License.

=head1 CONTACT

    Please subscribe to the Hive mailing list:  http://listserver.ebi.ac.uk/mailman/listinfo/ehive-users  to discuss Hive-related questions or to be notified of our updates

=cut


package Bio::EnsEMBL::Hive::Valley;

use strict;
use warnings;
use List::Util ('sum');
use Sys::Hostname ('hostname');
use Bio::EnsEMBL::Hive::Utils ('find_submodules');
use Bio::EnsEMBL::Hive::Limiter;

use base ('Bio::EnsEMBL::Hive::Configurable');


sub meadow_class_path {

    return 'Bio::EnsEMBL::Hive::Meadow';
}


our $_loaded_meadow_drivers;

sub loaded_meadow_drivers {

    unless( $_loaded_meadow_drivers ) {
        foreach my $meadow_class (@{ $_loaded_meadow_drivers = Bio::EnsEMBL::Hive::Utils::find_submodules( meadow_class_path() ) }) {
            eval "require $meadow_class";
        }
    }
    return $_loaded_meadow_drivers;
}


sub new {
    my ($class, $config, $default_meadow_type, $pipeline_name) = @_;

    my $self = bless {}, $class;

    $self->config( $config );
    $self->context( [ 'Valley' ] );

    my $amh = $self->available_meadow_hash( {} );

        # make sure modules are loaded and available ones are checked prior to setting the current one:
    foreach my $meadow_class (@{ $self->loaded_meadow_drivers }) {

        if( $meadow_class->check_version_compatibility
        and $meadow_class->name) {      # the assumption is if we can get a name, it is available

            my $meadow_object            = $meadow_class->new( $config );

            $meadow_object->pipeline_name( $pipeline_name ) if($pipeline_name);

            $amh->{$meadow_class->type} = $meadow_object;
        }
    }

    $self->set_default_meadow_type($default_meadow_type);     # run this method even if $default_meadow_type was not specified

    return $self;
}


sub available_meadow_hash {
    my $self = shift @_;

    if(@_) {
        $self->{_available_meadow_hash} = shift @_;
    }   
    return $self->{_available_meadow_hash};
}


sub get_available_meadow_list {     # this beautiful one-liner pushes $local to the bottom of the list
    my $self = shift @_;

    my $local = $self->meadow_class_path . '::LOCAL';

    return [ sort { (ref($a) eq $local) or -(ref($b) eq $local) } values %{ $self->available_meadow_hash } ];
}


sub set_default_meadow_type {
    my ($self, $default_meadow_type) = @_;

    if($default_meadow_type) {
        if( my $default_meadow = $self->available_meadow_hash->{$default_meadow_type} ) {   # store if available
            $self->{_default_meadow} = $default_meadow;
        } else {
            die "Meadow '$default_meadow_type' does not seem to be available on this machine, please investigate";
        }
    } else {
        $self->{_default_meadow} = $self->get_available_meadow_list->[0];     # take the first from preference list
    }
}


sub get_default_meadow {
    my $self = shift @_;

    return $self->{_default_meadow};
}


sub find_available_meadow_responsible_for_worker {
    my ($self, $worker) = @_;

    if( my $meadow = $self->available_meadow_hash->{$worker->meadow_type} ) {
        if($meadow->cached_name eq $worker->meadow_name) {
            return $meadow;
        }
    }
    return undef;
}


sub whereami {
    my $self = shift @_;

    my $meadow_host = hostname();
    my $meadow_user = $ENV{'USER'} || getpwuid($<);

    foreach my $meadow (@{ $self->get_available_meadow_list }) {
        my $pid;
        eval {
            # get_current_worker_process_id() is expected to die if the pid
            # cannot be determined. With the eval{} and the unless{} it will
            # skip the meadow and try the next one.
            $pid = $meadow->get_current_worker_process_id();
        };
        unless($@) {
            return ($meadow, $pid, $meadow_host, $meadow_user);
        }
    }
    die "Could not determine the Meadow, please investigate";
}


sub get_pending_worker_counts_by_meadow_type_rc_name {
    my ($self, $statuses) = @_;

    my %pending_counts = ();
    my $total_pending_all_meadows = 0;

    foreach my $meadow (@{ $self->get_available_meadow_list }) {
        my $pending_workers_per_rc_name = $statuses->{ $meadow->type }->{ 'PEND' } || {};

        $pending_counts{ $meadow->type } = {};
        while (my ($rc_name,$process_ids) = each %$pending_workers_per_rc_name) {
            my $n_pending = scalar(@$process_ids);
            $pending_counts{ $meadow->type }->{ $rc_name } = $n_pending;
            $total_pending_all_meadows += $n_pending;
        }
    }

    return (\%pending_counts, $total_pending_all_meadows);
}


sub generate_limiters {
    my ($self, $statuses) = @_;

    my $valley_running_worker_count             = 0;
    my %meadow_capacity_limiter_hashed_by_type  = ();

    foreach my $meadow (@{ $self->get_available_meadow_list }) {
        my $this_worker_count   = sum(0, (map {scalar(@$_)} values( %{ $statuses->{ $meadow->type }->{ 'RUN' } } )));

        $valley_running_worker_count                           += $this_worker_count;

        my $available_worker_slots = defined($meadow->config_get('TotalRunningWorkersMax'))
            ? $meadow->config_get('TotalRunningWorkersMax') - $this_worker_count
            : undef;

            # so the hash will contain limiters for every meadow_type, but not all of them active:
        $meadow_capacity_limiter_hashed_by_type{ $meadow->type } = Bio::EnsEMBL::Hive::Limiter->new( "Number of workers in '".$meadow->signature."' meadow", $available_worker_slots );
    }

    return ($valley_running_worker_count, \%meadow_capacity_limiter_hashed_by_type);
}

sub query_worker_statuses {
    my ($self, $all_registered_running_workers) = @_;

    my %statuses            = ();

    foreach my $meadow (@{ $self->get_available_meadow_list }) {
        my $process_ids_by_meadow_user      = $all_registered_running_workers->{$meadow->type}{$meadow->cached_name};
        my $this_status_list                = $meadow->status_of_all_our_workers( [keys %$process_ids_by_meadow_user] );
        $statuses{ $meadow->type }          = {};
        foreach my $ra (@$this_status_list) {
            my ($worker_pid, $meadow_user, $status, $rc_name) = @$ra;
            # Workers that are not properly named and are not in the
            # database are likely not ours. Let's skip them.
            if (($rc_name eq '__unknown_rc_name__') and !$process_ids_by_meadow_user->{$meadow_user}->{$worker_pid}) {
                next;
            }
            # Workers that are in RUN state but not yet in the database probably
            # have a hard time registering (db too busy ? registry too big ?).
            # Let's mark them as PENDing for the time being.
            if (($status eq 'RUN') and !$process_ids_by_meadow_user->{$meadow_user}->{$worker_pid}) {
                $status = 'PEND';
            }
            push @{ $statuses{ $meadow->type }->{ $status }->{ $rc_name } }, $worker_pid;
        }
    }
    return \%statuses;
}

sub status_of_all_our_workers_by_meadow_signature {
    my ($self, $statuses) = @_;

    my %worker_statuses = ();
    foreach my $meadow (@{ $self->get_available_meadow_list }) {
        my $meadow_signature = $meadow->type.'/'.$meadow->cached_name;
        my $statuses_rc_name = $statuses->{ $meadow->type };
        $worker_statuses{$meadow_signature} = {};
        foreach my $status (keys %$statuses_rc_name) {
            foreach my $pid_list (values %{ $statuses_rc_name->{$status} }) {
                $worker_statuses{$meadow_signature}{$_} = $status for @$pid_list;
            }
        }
    }
    return \%worker_statuses;
}

sub cleanup_left_temp_directory {
    my ($self, $worker) = @_;

    # cleanup_left_temp_directory is called when garbage-collecting dead-workers,
    # which is only possible for reachable meadows.
    # This guarantees that $meadow is defined.
    my $meadow = $self->available_meadow_hash->{$worker->meadow_type};

    if ($meadow->config_get('CleanupTempDirectoryKilledWorkers')) {
        warn "GarbageCollector:\tCleaning-up /tmp\n";
        my $rc = $meadow->run_on_host($worker->meadow_host, $worker->meadow_user, ['rm', '-rf', $worker->temp_directory_name]);
        $worker->worker_say(sprintf("Error: could not clean %s's temp directory '%s': %s\n", $worker->meadow_host, $worker->temp_directory_name, $@)) if $rc;
    }
}


1;
