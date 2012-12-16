package WithContract;

use strict;
use warnings;

use Attribute::Contract;

sub new {
    my $class = shift;

    my $self = {};
    bless $self, $class;

    return $self;
}

sub method :ContractRequires(SCALAR) {
    1;
}

1;
