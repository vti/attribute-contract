package Attribute::Contract::Modifier::Ensures;

use strict;
use warnings;

require Carp;

use Attribute::Contract::TypeValidator;

my %cache = ();

sub modify {
    my $class = shift;
    my ($package, $name, $code_ref, $attributes) = @_;

    Carp::croak('Return type(s) are required') unless $attributes;

    my $sub_ref = build($attributes);

    sub {
        my @return = $code_ref->(@_);

        $sub_ref->(undef, @return);

        @return;
    };
}

1;
