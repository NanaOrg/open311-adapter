package Open311::Endpoint::Integration::Bartec;

use JSON::MaybeXS;
use Path::Tiny;
use YAML::XS qw(LoadFile);

use Integrations::Bartec;

use Moo;
extends 'Open311::Endpoint';
with 'Open311::Endpoint::Role::mySociety';
with 'Role::Logger';

has jurisdiction_id => (
    is => 'ro',
);

has bartec => (
    is => 'lazy',
    default => sub { Integrations::Bartec->new(config_filename => $_[0]->jurisdiction_id) }
);

has integration_class => (
    is => 'ro',
    default => 'Integrations::Bartec'
);

has allowed_services => (
    is => 'lazy',
    default => sub {
        my $self = shift;
        my %allowed = map { uc $_ => 1 } @{ $self->get_integration->config->{allowed_services} };
        return \%allowed;
    }
);

sub get_integration {
    my $self = shift;
    my $integ = $self->integration_class->new;
    $integ->config_filename($self->jurisdiction_id);
    return $integ;
}

sub services {
    my $self = shift;
    my $services = $self->get_integration->ServiceRequests_Types_Get;
    $services = ref $services->{ServiceType} eq 'ARRAY' ? $services->{ServiceType} : [ $services->{ServiceType} ];
    my @services = map {
        my $service = Open311::Endpoint::Service->new(
            service_name => $_->{Description},
            service_code => $_->{ID},
            description => $_->{Description},
            groups => [ $_->{ServiceClass}->{Description} ],
      );
    } grep { $self->allowed_services->{uc $_->{Description}} } @$services;
    return @services;
}

__PACKAGE__->run_if_script;
