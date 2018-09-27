package Open311::Endpoint::Service::UKCouncil::Oxfordshire;
use Moo;
extends 'Open311::Endpoint::Service';
use Open311::Endpoint::Service::Attribute;

has '+attributes' => (
    is => 'ro',
    default => sub { [
        Open311::Endpoint::Service::Attribute->new(
            code => 'external_id',
            variable => 0, # set by server
            datatype => 'number',
            required => 0,
            automated => 'server_set',
            description => 'external_id',
        ),
        Open311::Endpoint::Service::Attribute->new(
            code => 'title',
            variable => 0, # set by server
            datatype => 'string',
            required => 0,
            automated => 'server_set',
            description => 'title',
        ),
        Open311::Endpoint::Service::Attribute->new(
            code => 'description',
            variable => 0, # set by server
            datatype => 'string',
            required => 0,
            automated => 'server_set',
            description => 'description',
        ),
        Open311::Endpoint::Service::Attribute->new(
            code => 'closest_address',
            variable => 0, # set by server
            datatype => 'string',
            required => 0,
            automated => 'server_set',
            description => 'closest_address',
        ),
        Open311::Endpoint::Service::Attribute->new(
            code => 'usrn',
            variable => 0, # set by server
            datatype => 'string',
            required => 0,
            automated => 'server_set',
            description => 'usrn',
        ),
        Open311::Endpoint::Service::Attribute->new(
            code => 'easting',
            variable => 0, # set by server
            datatype => 'string',
            required => 0,
            automated => 'server_set',
            description => 'easting',
        ),
        Open311::Endpoint::Service::Attribute->new(
            code => 'northing',
            variable => 0, # set by server
            datatype => 'string',
            required => 0,
            automated => 'server_set',
            description => 'northing',
        ),
        Open311::Endpoint::Service::Attribute->new(
            code => 'service_detail',
            variable => 0, # set by server
            datatype => 'string',
            required => 0,
            automated => 'server_set',
            description => 'service_detail',
        ),
        Open311::Endpoint::Service::Attribute->new(
            code => 'service_type',
            variable => 0, # set by server
            datatype => 'string',
            required => 0,
            automated => 'server_set',
            description => 'service_type',
        ),
    ] },
);

has internal_attributes => (
  is => 'ro',
  default => sub { {
      external_id => 1,
      title => 1,
      description => 1,
      closest_address => 1,
      usrn => 1,
      easting => 1,
      northing => 1,
      service_detail => 1,
      service_type => 1,
  } },
);

1;