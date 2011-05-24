package NSMF::Model::Agent;

use strict;
use NSMF::Driver;

use base qw(Data::ObjectDriver::BaseObject);
__PACKAGE__->install_properties({
    columns => [
	    'agent_id', 
	    'agent_name', 
	    'agent_password',
	    'agent_description',
	    'agent_ip',
	    'agent_active',
	    'agent_network',
    ],
    datasource => 'nsmf_agent',
    primary_key => 'agent_id',
    driver => NSMF::Driver->driver,
});

1;
