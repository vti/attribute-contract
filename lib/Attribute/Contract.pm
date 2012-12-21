package Attribute::Contract;

use strict;
use warnings;

use attributes;

our $VERSION = '0.01';

use Scalar::Util qw(refaddr);

use constant NO_ATTRIBUTE_CONTRACT => $ENV{NO_ATTRIBUTE_CONTRACT};

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
    return if NO_ATTRIBUTE_CONTRACT;

    my ($package) = caller;
    $todo{$package}++;

    __PACKAGE__->export_to_level(1, @_);
}

sub CHECK {
    return if NO_ATTRIBUTE_CONTRACT;

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

    if (@attr) {
        no strict;
        my @isa = @{"$package\::ISA"};
        use strict;
        foreach my $isa (@isa) {
            my $key = "$isa\::$name";
            if (exists $modifiers{$key}) {

                my $base_contract = $modifiers{$key};
                my $contract = $modifiers{"$package\::$name"};

                if (@$base_contract == @$contract) {
                    next
                      if join(',', sort @$base_contract) eq
                          join(',', sort @$contract);
                }

                Carp::croak(qq{Changing contract of method '$name'}
                      . qq{ in $package is not allowed});
            }
        }
    }

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

    sub do_smth :ContractRequires(VALUE, @ANY?) :ContractEnsures(VALUE) {
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

    Implementaion->do_smth('hi', 'there'); # works

    Implementaion->do_smth();              # croaks!
    Implementaion->do_smth(sub {});        # croaks!

=head1 DESCRIPTION

L<Attribute::Contract> by using Perl attributes allows you to specify contract
(L<Design by Contract|http://en.wikipedia.org/wiki/Design_by_contract>) for
every method in your class. You can check incoming and outgoing values by
specifying C<ContractRequires> and C<ContractEnsures> attributes.

It's the most useful for interfaces or abstract classes when you want to control
whether your implementation follows the same interface and respects the Liskov
substitution principle.

This module does not check the actual types like C<Str>, C<Int> etc, but the
Perl data types like scalars, arrays, hashes, references and so on. When the type
does not match a L<Carp>'s C<confess> function will be called with detailed
information like:

    0 param(s) passed, at least 1 param(s) is required

Why attributes? They feel and look natural and are applied during compile time.

=head2 TYPES

=head3 Scalar types

=over

=item * ANY

Any scalar value is accepted.

=item * VALUE

Anything but not a reference.

=item * REF

A non blessed reference to anything.

=item * REF(SCALAR)

A reference to scalar.

=item * REF(ARRAY)

A reference to array.

=item * REF(HASH)

A reference to hash.

=item * REF(Regexp)

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

=over

=item * @ARRAY

    @VALUE

Which could mean something like:

    $object->method(1, 2, 3, 4);

=item * %HASH

    %ANY

Which could mean something like:

    $object->method(foo => 'bar', 'baz' => \123);

It also checks that the number of elements is even.

=back

=head2 MULTIPLE VALUES

Use C<,> when specifying several arguments.

    VALUE,ANY,REF(CODE),@VALUE

Which could mean something like:

    $object->method($foo, \@array, sub { ... }, 1, 2, 3);

=head2 ALTERNATIVES

Use C<|> when specifying an alternative type.

    VALUE|REF(VALUE)

Which could mean something like:

    $object->method($foo);

or

    $object->method(\$foo);

Alternatives can be really deep, like this one:

    @(REF(HASH|CODE)|VALUE)

Which is an array of references to hash or code or simple value.

=head2 OPTIONAL VALUES

Use C<?> when specifying an optional value.

    VALUE,VALUE?

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

=head2 SWITCHING OFF

You can switch off contract checking by specifying an environment variable
C<NO_ATTRIBUTE_CONTRACT>.

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
