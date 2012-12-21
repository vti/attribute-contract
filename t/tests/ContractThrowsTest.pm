package ContractThrowsTest;

use strict;
use warnings;

use base 'TestBase';

use Test::More;
use Test::Fatal;

use Attribute::Contract::Modifier::Throws;

sub require_at_least_one_class : Test {
    my $self = shift;

    like(
        exception {
            $self->_build_code_ref(sub { });
        },
        qr/At least one ISA is required/
    );
}

sub skip_no_exception : Test {
    my $self = shift;

    $self->_build_code_ref(sub { }, 'Foo');
}

sub rethrow_known_exception : Test {
    my $self = shift;

    {

        package Exception;
        sub new { bless {}, shift }
    }

    my $code_ref =
      $self->_build_code_ref(sub { die Exception->new }, 'Exception');

    like(exception { $code_ref->(undef) }, qr/Exception=HASH/);
}

sub throw_on_unknown_exception : Test {
    my $self = shift;

    {

        package UnknownException;
        sub new { bless {}, shift }
    }

    my $code_ref =
      $self->_build_code_ref(sub { die UnknownException->new }, 'Foo');

    like(
        exception { $code_ref->(undef) },
        qr/Unknown exception: UnknownException/
    );
}

sub _build_code_ref {
    my $self = shift;
    my ($cb, $arguments) = @_;

    return Attribute::Contract::Modifier::Throws->modify('package', 'name', $cb,
        $arguments);
}

1;
