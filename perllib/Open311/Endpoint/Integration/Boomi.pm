package Open311::Endpoint::Integration::Boomi;

use Moo;
extends 'Open311::Endpoint';
with 'Open311::Endpoint::Role::mySociety';
with 'Role::EndpointConfig';
with 'Role::Logger';

use POSIX qw(strftime);
use MIME::Base64 qw(encode_base64);
use Open311::Endpoint::Service::UKCouncil::Boomi;
use Open311::Endpoint::Service::Request::Update::mySociety;
use Integrations::Surrey::Boomi;
use JSON::MaybeXS;
use DateTime::Format::W3CDTF;
use Path::Tiny;
use Try::Tiny;

has jurisdiction_id => (
    is => 'ro',
    required => 1,
);

has boomi => (
    is => 'lazy',
    default => sub { $_[0]->integration_class->new(config_filename => $_[0]->jurisdiction_id) }
);

has integration_class => (
    is => 'ro',
    default => 'Integrations::Surrey::Boomi',
);



sub service {
    my ($self, $id, $args) = @_;

    my $service = Open311::Endpoint::Service::UKCouncil::Boomi->new(
        service_name => $id,
        service_code => $id,
        description => $id,
        type => 'realtime',
        keywords => [qw/ /],
        allow_any_attributes => 1,
    );

    return $service;
}


sub services {
    my ($self) = @_;

    # Boomi doesn't provide a list of services; they're just created as
    # contacts in the FMS admin.

    return ();
}

sub post_service_request {
    my ($self, $service, $args) = @_;

    die "Args must be a hashref" unless ref $args eq 'HASH';

    $self->logger->info("[Boomi] Creating issue");
    $self->logger->debug("[Boomi] POST service request args: " . encode_json($args));

    my $ticket = {
        integrationId => $self->endpoint_config->{integration_ids}->{upsertHighwaysTicket},
        subject => $args->{attributes}->{title},
        status => 'open',
        description => $args->{attributes}->{description},
        location => {
            latitude => $args->{lat},
            longitude => $args->{long},
            easting => $args->{attributes}->{easting},
            northing => $args->{attributes}->{northing},
        },
        requester => {
            fullName => $args->{first_name} . " " . $args->{last_name},
            email => $args->{email},
            phone => $args->{attributes}->{phone},
        },
        customFields => [
            {
                id => 'category',
                values => [ $args->{attributes}->{group} ],
            },
            {
                id => 'subCategory',
                values => [ $args->{attributes}->{category} ],
            },
            {
                id => 'fixmystreet_id',
                values => [ $args->{attributes}->{fixmystreet_id} ],
            },
        ],
    };
    my $service_request_id = $self->boomi->upsertHighwaysTicket($ticket);

    return $self->new_request(
        service_request_id => $service_request_id,
    )
}



sub get_service_request_updates {
    my ($self, $args) = @_;

    my $start = DateTime::Format::W3CDTF->parse_datetime($args->{start_date});
    my $end = DateTime::Format::W3CDTF->parse_datetime($args->{end_date});

    my $results = $self->boomi->getHighwaysTicketUpdates($start, $end);
    my $w3c = DateTime::Format::W3CDTF->new;

    my @updates;

    for my $update (@$results) {
        my $log = $update->{confirmEnquiryStatusLog};
        my $fms = $update->{fmsReport};

        my $id = $log->{enquiry}->{externalSystemReference} . "_" . $log->{logNumber};
        my $status = lc $fms->{status}->{state};
        $status =~ s/ /_/g;

        push @updates, Open311::Endpoint::Service::Request::Update::mySociety->new(
            status => $status,
            update_id => $id,
            service_request_id => "Zendesk_" . $log->{enquiry}->{externalSystemReference},
            description => $fms->{status}->{label},
            updated_datetime => $w3c->parse_datetime( $log->{loggedDate} )->truncate( to => 'second' ),
        );
    }

    return @updates;
}



1;