package InheritContractButChange;

use strict;
use warnings;

use base 'WithContract';

use Attribute::Contract;

sub method :ContractRequires(ANY) {
}

1;
