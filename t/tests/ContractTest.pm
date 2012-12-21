package ContractTest;

use strict;
use warnings;

use base 'TestBase';

use Test::More;
use Test::Fatal;

use lib 't/tests/ContractTest';

use WithContract;
use InheritContract;
use InheritContractWithOverride;

sub handle_contract : Test {
    my $self = shift;

    ok(exception { WithContract->new->method(\1) });
}

sub inherit_contract : Test {
    my $self = shift;

    ok(exception { InheritContract->new->method(\1) });
}

sub inherit_contract_with_override : Test {
    my $self = shift;

    ok(exception { InheritContractWithOverride->new->method(\1) });
}

sub inherit_contract_with_override_in_eval : Test {
    my $self = shift;

    my $object = eval { InheritContractWithOverride->new };

    like(exception { $object->method(\1) }, qr/must be of type VALUE/);
}

sub do_not_allow_contract_change : Test {
    my $self = shift;

    like(exception { require InheritContractButChange; },
        qr/Changing contract of method 'method' in InheritContractButChange is not allowed/);
}

1;
