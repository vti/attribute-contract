package Attribute::Contract::Modifier::Requires;

use strict;
use warnings;

require Carp;

use Attribute::Contract::TypeValidator;

my %cache = ();

sub modify {
    my $class = shift;
    my ($package, $name, $code_ref, $attributes) = @_;

    my $sub_ref = build($attributes);

    sub {
        $sub_ref->(@_);

        $code_ref->(@_);
    };
}

1;
