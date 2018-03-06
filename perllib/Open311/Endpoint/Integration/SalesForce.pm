package Open311::Endpoint::Integration::SalesForce;

use Moo;
extends 'Open311::Endpoint';
with 'Open311::Endpoint::Role::mySociety';

use Open311::Endpoint::Service::UKCouncil::Rutland;
use Open311::Endpoint::Service::Request::SalesForce;
use Open311::Endpoint::Service::Attribute;
use Open311::Endpoint::Service::Request::Update::mySociety;

use Integrations::SalesForce;

use Digest::MD5 qw(md5_hex);
use DateTime::Format::Strptime;

has service_request_content => (
    is => 'ro',
    default => '/open311/service_request_extended'
);

sub parse_datetime {
    my ($self, $time) = @_;

    # salesforce times can look like
    # 2017-11-27T20:30:11.837838+00:00
    # or
    # 2017-11-27T20:30:11.837+0000
    # so unify them to
    # 2017-11-27T20:30:11+0000
    $time =~ s/\.\d+\+(\d\d):?(\d\d)$/+$1$2/;

    my $strp = new DateTime::Format::Strptime(
        pattern => '%Y-%m-%dT%H:%M:%S%z',
    );

    return $strp->parse_datetime($time);
}

sub reverse_status_mapping {}

sub get_integration {
    my $self = shift;
    return $self->integration_class->new;
}

sub post_service_request {
    my ($self, $service, $args) = @_;
    die "No such service" unless $service;

    my $integ = $self->get_integration;

    my $new_id = $integ->post_request($service, $args);

    my $request = $self->new_request(
        service_request_id => $new_id,
    );

    return $request;
}

sub post_service_request_update {
    my ($self, $args) = @_;

    my $response = $self->get_integration->post_update($args);

    return undef unless $response;

    my $digest = md5_hex($args->{description});
    my $update_id = $response . '_' . $digest;

    return Open311::Endpoint::Service::Request::Update::mySociety->new(
        status => lc $args->{status},
        update_id => $update_id,
    );
}

sub get_service_request_updates {
    my ($self, $args) = @_;

    my $integ = $self->get_integration;

    my $updates = $integ->get_updates();

    my @updates = ();

    # given we don't have an update time set a default of 20 seconds in the
    # past or the end date. The -20 seconds is because FMS checks that comments
    # aren't in the future WRT when it made the request so the -20 gets round
    # that.
    my $update_time = DateTime->now->add( seconds => -20 );
    if ($args->{end_date}) {
        my $w3c = DateTime::Format::W3CDTF->new;
        my $update_time = $w3c->parse_datetime($args->{end_date});
    }
    for my $update (@$updates) {
        my $request_id = $update->{id};
        my $comment = $update->{Comments};
        my $digest;
        if (not defined $comment) {
            $comment = '';
            $digest = md5_hex($update->{Status} . '_' . $update_time);
        } else {
            $digest = md5_hex($comment);
        }

        push @updates, Open311::Endpoint::Service::Request::Update::mySociety->new(
            status => $self->reverse_status_mapping($update->{Status}),
            # no update ids available so fake one
            update_id => $request_id . '_' . $digest,
            service_request_id => $request_id,
            description => $comment,
            updated_datetime => $update_time,
        );
    }
    return @updates;
}

sub get_service_requests {
    my ($self, $args) = @_;

    my $integ = $self->get_integration;

    my $requests = $integ->get_requests();

    my $w3c = DateTime::Format::W3CDTF->new;
    my @updates = ();

    for my $request (@$requests) {
        next unless
            $request->{lat__c} and
            $request->{long__c} and
            $request->{Status__c} and
            $request->{Service_Area__c};

        my $update_time = $self->parse_datetime($request->{LastModifiedDate});
        my $request_time = $self->parse_datetime($request->{requested_datetime__c});
        my $service = $self->service( $request->{Service_Area__c} );
        push @updates, Open311::Endpoint::Service::Request::SalesForce->new(
            service => $service,
            status => $self->reverse_status_mapping($request->{Status__c}),
            service_request_id => $request->{Id},
            title => $request->{title__c},
            description => $request->{detail__c},
            updated_datetime => $update_time,
            requested_datetime => $request_time,
            latlong => [ $request->{lat__c}, $request->{long__c}],
        );
    }
    return @updates;
}

sub get_service_request {
    my ($self, $id) = @_;

    my $response = $self->get_integration->GetEnquiry($id);

    return Open311::Endpoint::Service::Request->new();
}

sub services {
    my ($self, $args) = @_;

    my @services = $self->get_integration->get_services($args);

    my @service_types;
    for my $service (@services) {
        my $type = Open311::Endpoint::Service::UKCouncil::Rutland->new(
            service_name => $service->{name},
            service_code => $service->{serviceid},
            description => $service->{name},
            type => 'realtime',
            keywords => [qw/ /],
        );

        push @service_types, $type;
    }

    return @service_types;
}

sub service {
    my ($self, $id, $args) = @_;

    my $meta = $self->get_integration->get_service($id, $args);

    my $service = Open311::Endpoint::Service::UKCouncil::Rutland->new(
        service_name => $meta->{title},
        service_code => $id,
        description => $meta->{title},
        type => 'realtime',
        keywords => [qw/ /],
    );

    for my $meta (@{ $meta->{fieldInformation} }) {
        my %options = (
            code => $meta->{name},
            description => $meta->{label},
            required => 0,
        );
        if ($meta->{fieldType} eq 'text') {
            $options{datatype} = 'string';
        } else {
            my %values = map { $_ => $_ } @{ $meta->{optionsList} };
            $options{datatype} = 'singlevaluelist';
            $options{values} = \%values;
        }
        my $attrib = Open311::Endpoint::Service::Attribute->new(%options);
        push @{ $service->attributes }, $attrib;
    }

    return $service;
}

__PACKAGE__->run_if_script;
