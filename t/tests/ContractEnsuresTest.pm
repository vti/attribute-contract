package ContractEnsuresTest;

use strict;
use warnings;

use base 'TestBase';

use Test::More;
use Test::Fatal;

use Attribute::Contract::Modifier::Ensures;

sub no_params_is_useless : Test {
    my $self = shift;

    like(
        exception { $self->_build_code_ref() },
        qr/\QReturn type(s) are required\E/
    );
}

sub throw_on_error : Test {
    my $self = shift;

    my $code_ref = $self->_build_code_ref('SCALARREF');

    like(
        exception { $code_ref->(undef) },
        qr/Argument 0 must be of type SCALARREF/
    );
}

sub no_errors : Test {
    my $self = shift;

    my $code_ref = $self->_build_code_ref('SCALAR');

    ok($code_ref->(undef));
}

sub _build_code_ref {
    my $self = shift;
    my ($arguments) = @_;

    return Attribute::Contract::Modifier::Ensures->modify('package', 'name',
        sub { 1 }, $arguments);
}

1;
