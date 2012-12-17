package Attribute::Contract;

use strict;
use warnings;

use attributes;

our $VERSION = '0.01';

use Scalar::Util qw(refaddr);

use Attribute::Contract::Modifier::Requires;

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
