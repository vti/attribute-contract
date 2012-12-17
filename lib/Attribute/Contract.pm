package Attribute::Contract;

use strict;
use warnings;

use attributes;

our $VERSION = '0.01';

use Scalar::Util qw(refaddr);

use Attribute::Contract::Modifier::Requires;
use Attribute::Contract::Modifier::Ensures;

BEGIN {
    use Exporter ();
    our (@ISA, @EXPORT);

    @ISA    = qw(Exporter);
    @EXPORT = qw(&MODIFY_CODE_ATTRIBUTES &FETCH_CODE_ATTRIBUTES);
}

my %attrs;
my %modifiers;
my %symcache;
my %todo;

sub import {

    my ($package) = caller;
    $todo{$package}++;

    __PACKAGE__->export_to_level(1, @_);
}

sub CHECK {

    foreach my $package (keys %todo) {
        foreach my $key (keys %modifiers) {
            my ($class, $method) = split /::/, $key;
            next unless $package->isa($class);

            next unless my $code_ref = $package->can($method);

            my $attrs = $modifiers{$key};

            foreach my $attr (@$attrs) {
                next unless $attr =~ m/^Contract/;

                attributes::->import($package, $code_ref, $attr);
            }
        }
    }
}

sub FETCH_CODE_ATTRIBUTES {
    my ($package, $subref) = @_;

    my $attrs = $attrs{refaddr $subref };

    return @$attrs;
}

sub MODIFY_CODE_ATTRIBUTES {
    my ($package, $code_ref, @attr) = @_;

    my $sym = findsym($package, $code_ref);
    my $name = *{$sym}{NAME};

    $attrs{refaddr $code_ref } = \@attr;
    $modifiers{"$package\::$name"} = \@attr;

    no warnings 'redefine';
    foreach my $attr (@attr) {
        next unless $attr =~ m/^Contract([^\(]+)(?:\((.*?)\))?/;

        my $check     = $1;
        my $arguments = $2;

        my $class = __PACKAGE__ . '::Modifier::' . $check;

        *{$sym} = $class->modify($package, $name, $code_ref, $arguments);
    }

    return ();
}

# From Attribute::Handlers
sub findsym {
    my ($package, $ref) = @_;

    return $symcache{$package, $ref} if $symcache{$package, $ref};

    my $type = ref($ref);

    no strict 'refs';
    foreach my $sym (values %{$package . "::"}) {
        use strict;
        next unless ref(\$sym) eq 'GLOB';

        return $symcache{$package, $ref} = \$sym
          if *{$sym}{$type} && *{$sym}{$type} == $ref;
    }

    return;
}

1;
__END__

=head1 NAME

Attribute::Contract - Design by contract via Perl attributes

=head1 SYNOPSIS

    package Interface;
    use AttributeContract;

    sub do_smth :ContractRequires(SCALAR, @ANY?) :ContractEnsures(SCALAR) {
        ...;
    }

    package Implementation;
    use base 'Interface';
    use AttributeContract;

    sub do_smth {
        my $self = shift;
        my ($foo, @rest) = @_;

        return 1;
    }

=head1 DESCRIPTION

L<Attribute::Contract> by using Perl attributes allows you to specify contract
(L<Design by Contract|http://en.wikipedia.org/wiki/Design_by_contract>) for
every method in your class. You can check incoming and outgoing values by
specifying C<ContractRequires> and C<ContractEnsures> attributes.

It's the most useful for interfaces or abstract classes when you want to control
whether your implementation follows the same interface and respects the Liskov
substitution principle.

This module does not check the actual types like C<Str>, C<Int> etc, but the
Perl data types like C<SCALAR>, C<ARRAY>, references and so on. When the type
does not match a L<Carp>'s C<confess> function will be called with detailed
information like:

    0 param(s) passed, at least 1 param(s) is required

Why attributes? They feel and look natural and are applied during compile time.

=head2 TYPES

=head3 Scalar types

=over

=item * ANY

Any scalar value is accepted.

=item * SCALAR

Anything but not a reference.

=item * SCALARREF

A reference to scalar.

=item * ARRAYREF

A reference to array.

=item * HASHREF

A reference to hash.

=item * REGEXP

A reference to regular expression.

=item * OBJECT

A blessed reference.

=item * OBJECT(ISA)

A blessed reference with specified isa.

=back

=head3 Greedy types

Types that eat all the elements. Can be specified at the end of the elements
list for manual unpacking. C<@> stands for arrays and C<%> stands for hashes.
All the scalar types can be used to specify the types of the elements.

=item * @ARRAY

    @SCALAR

Which could mean something like:

    $object->method(1, 2, 3, 4);

=item * %HASH

    %ANY

Which could mean something like:

    $object->method(foo => 'bar', 'baz' => \123);

It also checks that the number of elements is even.

=head2 MULTIPLE VALUES

Use C<,> when specifying several arguments.

    SCALAR,ANY,CODEREF,@SCALAR

Which could mean something like:

    $object->method($foo, \@array, sub { ... }, 1, 2, 3);

=head2 ALTERNATIVES

Use C<|> when specifying an alternative type.

    SCALAR|SCALARREF

Which could mean something like:

    $object->method($foo);

or

    $object->method(\$foo);

=head2 OPTIONAL VALUES

Use C<?> when specifying an optional value.

    SCALAR,SCALAR?

Which could mean something like:

    $object->method('foo');

or

    $object->method('foo', 'bar');

=head2 IMPLEMENTATION

=head3 Inheritance

By default all the contracts are inherited. Just don't forget to C<use>
L<Attribute::Contract> in the derived class. But if no methods are override then
even C<using> this module is not needed.

=head3 Caching

During the compile time for every contract a Perl subroutine is built and
evaled. If the methods share the same contract they use the same checking code
reference. This speeds up the checking and saves some memory.

=head3 Error reporting

Errors are as specific as possible. On error you will get a meaningful message
and a stack trace.

=head1 DEVELOPMENT

=head2 Repository

    http://github.com/vti/attribute-contract

=head1 AUTHOR

Viacheslav Tykhanovskyi, C<vti@cpan.org>.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012, Viacheslav Tykhanovskyi

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut
