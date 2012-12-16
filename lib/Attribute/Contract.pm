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

        if ($check eq 'Inherit') {
            no strict 'refs';
            my @isa = @{"$package\::ISA"};
            foreach my $isa (reverse @isa) {
                if (exists $modifiers{"$isa\::$name"}) {
                    my @attr_list = @{$modifiers{"$isa\::$name"}};

                    if (@attr_list) {
                        attributes::->import($package, $package->can($name), $_)
                          for @attr_list;
                        last;
                    }
                }
            }
        }
        else {
            my $class = __PACKAGE__ . '::Modifier::' . $check;

            *{$sym} = $class->modify($package, $name, $code_ref, $arguments);
        }
    }

    return ();
}

# From Attribute::Handlers
my %symcache;

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
}

1;
