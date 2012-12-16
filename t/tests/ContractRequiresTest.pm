package ContractRequiresTest;

use strict;
use warnings;

use base 'TestBase';

use Test::More;
use Test::Fatal;

use Attribute::Contract::Modifier::Requires;

sub throw_no_params_allowed : Test {
    my $self = shift;

    my $code_ref = $self->_build_code_ref();

    like(exception { $code_ref->(undef, 1) }, qr/No params allowed/);
}

sub not_throw_when_optional_HASH : Test {
    my $self = shift;

    my $code_ref = $self->_build_code_ref('%ANY?');

    ok($code_ref->(undef));
}

sub not_throw_when_optional_HASH_complex : Test {
    my $self = shift;

    my $code_ref = $self->_build_code_ref('SCALAR, %ANY?');

    ok($code_ref->(undef, 1));
}

sub not_throw_when_optional_ARRAY : Test {
    my $self = shift;

    my $code_ref = $self->_build_code_ref('@ANY?');

    ok($code_ref->(undef));
}

sub throw_on_too_many : Test {
    my $self = shift;

    my $code_ref = $self->_build_code_ref('SCALAR');

    like(exception { $code_ref->(undef, 1, 2) }, qr/\Q2 param(s) passed, max 1 param(s) allowed\E/);
}

sub throw_on_not_enough : Test {
    my $self = shift;

    my $code_ref = $self->_build_code_ref('SCALAR');

    like(exception { $code_ref->(undef) }, qr/\Q0 param(s) passed, at least 1 param(s) required\E/);
}

sub not_throw_on_optional : Test {
    my $self = shift;

    my $code_ref = $self->_build_code_ref('SCALAR,SCALAR?');

    ok(!exception { $code_ref->(undef, 1) });
}

sub not_throw_on_several_optional : Test {
    my $self = shift;

    my $code_ref = $self->_build_code_ref('SCALAR,SCALAR?,SCALAR?');

    ok($code_ref->(undef, 1, 2));
}

sub throw_on_wrong_type : Test {
    my $self = shift;

    my $code_ref = $self->_build_code_ref('SCALAR');

    like(exception { $code_ref->(undef, \1) }, qr/Argument 0 must be of type SCALAR/);
}

sub handle_ANY : Test {
    my $self = shift;

    my $code_ref = $self->_build_code_ref('ANY');

    ok($code_ref->(undef, \1));
}

sub handle_at_least_required : Test {
    my $self = shift;

    my $code_ref = $self->_build_code_ref('SCALAR, @ANY');

    like(exception {$code_ref->(undef, 1)}, qr/\Q1 param(s) passed, at least 2 param(s) required\E/);
}

sub handle_ARRAY : Test {
    my $self = shift;

    my $code_ref = $self->_build_code_ref('SCALAR, @ANY');

    ok($code_ref->(undef, 1, 'foo', 'bar'));
}

sub handle_ARRAY_with_subtype : Test {
    my $self = shift;

    my $code_ref = $self->_build_code_ref('SCALAR, @SCALAR');

    ok($code_ref->(undef, 1, 'foo', 'bar'));
}

sub throw_on_wrong_subtype : Test {
    my $self = shift;

    my $code_ref = $self->_build_code_ref('SCALAR, @SCALAR');

    like(exception {$code_ref->(undef, 1, 'foo', 'bar', \1)}, qr/Array argument 3 must be of type SCALAR/);
}

sub handle_HASH : Test {
    my $self = shift;

    my $code_ref = $self->_build_code_ref('SCALAR, %ANY');

    ok($code_ref->(undef, 1, foo => 'bar'));
}

sub throw_when_odd_parameters : Test {
    my $self = shift;

    my $code_ref = $self->_build_code_ref('SCALAR, %ANY');

    like(exception {$code_ref->(undef, 1, 'bar')}, qr/\Q2 param(s) passed, at least 3 param(s) required\E/);
}

sub throw_on_wrong_HASH_subtype : Test {
    my $self = shift;

    my $code_ref = $self->_build_code_ref('SCALAR, %SCALAR');

    like(exception {$code_ref->(undef, 1, foo => 'bar', baz => \1)}, qr/Hash key 'baz' value must be of type SCALAR/);
}

sub handle_OBJECT : Test {
    my $self = shift;

    my $code_ref = $self->_build_code_ref('OBJECT');

    ok($code_ref->(undef, ContractRequiresTest->new));
}

sub handle_OBJECT_ISA : Test {
    my $self = shift;

    my $code_ref = $self->_build_code_ref('OBJECT(TestBase)');

    ok($code_ref->(undef, ContractRequiresTest->new));
}

sub handle_ref : Test {
    my $self = shift;

    my $code_ref = $self->_build_code_ref('HASHREF');

    ok($code_ref->(undef, {}));
}

sub handle_regexp : Test {
    my $self = shift;

    my $code_ref = $self->_build_code_ref('REGEXP');

    ok($code_ref->(undef, qr/1/));
}

sub _build_code_ref {
    my $self = shift;
    my ($arguments) = @_;

    return Attribute::Contract::Modifier::Requires->modify('package', 'name',
        sub { 1 }, $arguments);
}

1;
