package TypeValidatorTest;

use strict;
use warnings;

use base 'TestBase';

use Test::More;
use Test::Fatal;

use Attribute::Contract::TypeValidator;

sub errors : Test(3) {
    my $self = shift;

    my $tests = [
        'AN'       => [1] => qr/Unknown type 'AN'/,
        '@ANY,ANY' => [1] => qr/Array can be only the last element/,
        '%ANY,ANY' => [1] => qr/Hash can be only the last element/,
    ];

    for (my $i = 0; $i < @$tests; $i += 3) {
        my $key   = $tests->[$i];
        my $value = $tests->[$i + 1];
        my $error = $tests->[$i + 2];

        my $e = exception { $self->_build_code_ref($key)->(undef, @{$value}) };
        like($e, $error, $key);
    }
}

sub number_of_params : Test(6) {
    my $self = shift;

    my $tests = [
        'ANY'     => [1],
        'ANY,ANY' => [1, 2],
        '@ANY'    => [1],
        '@ANY'    => [1, 2],
        '@ANY'    => [1, 2, 3],
        '%ANY' => [1, 2],
    ];

    $self->_run_tests($tests);
}

sub wrong_number_of_params : Test(5) {
    my $self = shift;

    my $tests = [
        'ANY'     => [],
        'ANY'     => [1, 2],
        'ANY,ANY' => [1],
        'ANY,ANY' => [1, 2, 3],
        '%ANY'    => [1],
    ];

    $self->_run_failed_tests($tests);
}

sub values : Test(8) {
    my $self = shift;

    my $tests = [
        'VALUE'        => [1],
        'VALUE(Int)'   => [1],
        'VALUE(Int)'   => [-1],
        'VALUE(Int)'   => [+1],
        'VALUE(Str)'   => ['hi'],
        'VALUE(Float)' => [1.2],
        'VALUE(Float)' => [1.2e1],
        'VALUE(/^\d+$/)' => [0123],
    ];

    $self->_run_tests($tests);
}

sub wrong_values : Test(4) {
    my $self = shift;

    my $tests = [
        'VALUE'        => [\1],
        'VALUE(Int)'   => [1.2],
        'VALUE(Float)' => ['what?'],
        'VALUE(/^\d+$/)' => ['012a3'],
    ];

    $self->_run_failed_tests($tests);
}

sub references : Test(7) {
    my $self = shift;

    my $tests = [
        'REF'         => [\1],
        'REF'         => [{}],
        'REF(SCALAR)' => [\1],
        'REF(ARRAY)'  => [[]],
        'REF(HASH)'   => [{}],
        'REF(CODE)'   => [sub { }],
        'REF(Regexp)' => [qr/123/],
    ];

    $self->_run_tests($tests);
}

sub wrong_references : Test(9) {
    my $self = shift;

    my $tests = [
        'REF'         => [undef],
        'REF'         => [1],
        'REF(SCALAR)' => [{}],
        'REF(ARRAY)'  => [\1],
        'REF(HASH)'   => [[]],
        'REF(CODE)'   => [{}],
        'REF(Regexp)' => [sub { }],
        'REF(HASH)'   => [TypeValidatorTest->new],
        'REF'         => [TypeValidatorTest->new],
    ];

    $self->_run_failed_tests($tests);
}

sub objects : Test(2) {
    my $self = shift;

    my $tests = [
        'OBJECT'           => [__PACKAGE__->new],
        'OBJECT(TestBase)' => [__PACKAGE__->new],
    ];

    $self->_run_tests($tests);
}

sub wrong_objects : Test(3) {
    my $self = shift;

    {

        package Foo;

        sub new {
            my $class = shift;
            bless {}, $class;
        }
    }

    my $tests = [
        'OBJECT'           => [\1],
        'OBJECT'           => [qr/123/],
        'OBJECT(TestBase)' => [Foo->new],
    ];

    $self->_run_failed_tests($tests);
}

sub arrays : Test(4) {
    my $self = shift;

    my $tests = [
        '@ANY'         => [1, 2, 3],
        '@VALUE'       => [1, 2, 3],
        '@REF(SCALAR)' => [\1],
        '@REF(ARRAY)' => [[], []],
    ];

    $self->_run_tests($tests);
}

sub wrong_arrays : Test(3) {
    my $self = shift;

    my $tests = [
        '@VALUE'       => [1,  \2, 3],
        '@REF(SCALAR)' => [\1, {}],
        '@REF(ARRAY)'  => [[], 1],
    ];

    $self->_run_failed_tests($tests);
}

sub hashes : Test(4) {
    my $self = shift;

    my $tests = [
        '%ANY'         => [foo => 'bar'],
        '%VALUE'       => [foo => 'bar'],
        '%REF(SCALAR)' => [foo => \1],
        '%REF(ARRAY)'  => [foo => []],
    ];

    $self->_run_tests($tests);
}

sub wrong_hashes : Test(3) {
    my $self = shift;

    my $tests = [
        '%VALUE'       => [foo => \1],
        '%REF(SCALAR)' => [foo => 1],
        '%REF(ARRAY)'  => [foo => sub { }],
    ];

    $self->_run_failed_tests($tests);
}

sub multiple_arguments : Test(3) {
    my $self = shift;

    my $tests = [
        'ANY,VALUE,REF(SCALAR)' => [{}, 'hi', \1],
        'ANY,@ANY'              => [{}, 1,    2, 3],
        'ANY,%ANY' => [{}, foo => 'bar'],
    ];

    $self->_run_tests($tests);
}

sub optional_arguments : Test(6) {
    my $self = shift;

    my $tests = [
        'ANY,VALUE?'           => [{}, 'hi'],
        'VALUE?,VALUE?,VALUE?' => [1],
        'VALUE?,VALUE?,VALUE?' => [1,  2],
        'VALUE?,VALUE?,VALUE?' => [1, 2, 3],
        'VALUE,@ANY?'          => [1],
        'VALUE,%ANY?'          => [1],
    ];

    $self->_run_tests($tests);
}

sub alternatives : Test(7) {
    my $self = shift;

    my $tests = [
        'VALUE|REF'         => ['hi'],
        'VALUE|REF'         => [\'hi'],
        'REF(SCALAR|ARRAY)' => [\'hi'],
        'REF(SCALAR|ARRAY)' => [[]],
        '@(VALUE|REF)'      => [[], 1, \1],
        '@(REF(SCALAR)|REF(ARRAY))'      => [[], \1],
        '@(REF(SCALAR|ARRAY)|REF(HASH))' => [[], \1, {}],
    ];

    $self->_run_tests($tests);
}

sub undefs : Test(7) {
    my $self = shift;

    my $tests = [
        'ANY*'         => [undef],
        'VALUE*'       => [undef],
        'REF*'         => [undef],
        'REF*(SCALAR)' => [undef],
        'OBJECT*'      => [undef],
        '@VALUE*'      => [undef, undef],
        '%VALUE*'      => [foo => undef],
    ];

    $self->_run_tests($tests);
}

sub wrong_undefs : Test(7) {
    my $self = shift;

    my $tests = [
        'ANY'         => [undef],
        'VALUE'       => [undef],
        'REF'         => [undef],
        'REF(SCALAR)' => [undef],
        'OBJECT'      => [undef],
        '@VALUE'      => [undef, undef],
        '%VALUE'      => [foo => undef],
    ];

    $self->_run_failed_tests($tests);
}

sub _run_tests {
    my $self = shift;
    my ($tests) = @_;

    for (my $i = 0; $i < @$tests; $i += 2) {
        my $key   = $tests->[$i];
        my $value = $tests->[$i + 1];

        my $e = exception { $self->_build_code_ref($key)->(undef, @{$value}) };
        ok(!$e, $key) or diag($e);
    }
}

sub _run_failed_tests {
    my $self = shift;
    my ($tests) = @_;

    for (my $i = 0; $i < @$tests; $i += 2) {
        my $key   = $tests->[$i];
        my $value = $tests->[$i + 1];

        my $e = exception { $self->_build_code_ref($key)->(undef, @{$value}) };
        ok($e, $key);
    }
}

sub _build_code_ref {
    my $self = shift;
    my ($arguments) = @_;

    return build($arguments);
}

1;
