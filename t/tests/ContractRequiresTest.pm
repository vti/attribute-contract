package ContractRequiresTest;

use strict;
use warnings;

use base 'TestBase';

use Test::More;
use Test::Fatal;

use Attribute::Contract::Modifier::Requires;

sub throw_on_error : Test {
    my $self = shift;

    my $code_ref = $self->_build_code_ref();

    like(exception { $code_ref->(undef, 1) }, qr/No params allowed/);
}

sub _build_code_ref {
    my $self = shift;
    my ($arguments) = @_;

    return Attribute::Contract::Modifier::Requires->modify('package', 'name',
        sub { 1 }, $arguments);
}

1;
