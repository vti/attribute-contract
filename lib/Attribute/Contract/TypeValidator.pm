package Attribute::Contract::TypeValidator;

use strict;
use warnings;

use base 'Exporter';

our @EXPORT = qw(build);

use Scalar::Util qw(blessed);
require Carp;
use Digest::MD5 qw(md5_hex);

my %cache = ();

sub build {
    my ($attributes) = @_;

    $attributes = '' unless defined $attributes;

    $cache{$attributes} ||= do {
        my $code = _build($attributes);
        eval $code;
    };

    return $cache{$attributes};
}

sub _build {
    my ($attributes) = @_;

    my @types = split /\s*,\s*/, $attributes;

    my $package = __PACKAGE__ . md5_hex($attributes);
    my $code = "package $package;";
    $code .= 'sub {my $self = shift;require Scalar::Util;';
    $code .= '$Carp::Internal{(__PACKAGE__)}++;';

    my $min_required = grep { !/\?$/ } @types;
    my $max_allowed = scalar @types;

    if ($max_allowed == 0) {
        $code .= qq{Carp::confess("No params allowed") if \@_;};
    }
    elsif ($types[-1] =~ m/^%/) {
        $min_required++ unless $types[-1] =~ m/\?$/;
        $max_allowed = -1;
    }
    elsif ($types[-1] =~ m/^@/) {
        $max_allowed = -1;
    }

    if ($max_allowed) {
        $code .= qq{
            Carp::confess(
                sprintf("%d param(s) passed, at least %d param(s) required", scalar(\@_), $min_required))
              if \@_ < $min_required;
          };

        if ($max_allowed != -1) {
            $code .= qq{
            Carp::confess(
                sprintf(
                    "%d param(s) passed, max %d param(s) allowed",
                    scalar(\@_), $max_allowed
                )
            ) if \@_ > $max_allowed;
            };
        }

        my $pos = 0;
        foreach my $type (@types) {
            if ($type =~ m/^(?:\@|\%)/) {
                last;
            }

            $type =~ s{\?$}{};

            next if $type eq 'ANY';

            my $validator = _build_validator($type);

            $code .= qq{
                Carp::confess("Argument $pos must be of type $type") unless $validator;
            };
        }
        continue {
            $pos++;
        }

        if ($types[-1] =~ m/^\@(.*)/) {
            my $subtype = $1;

            $subtype =~ s{\?$}{};

            if ($subtype ne 'ANY') {
                my $validator = _build_validator($subtype, '$value');

                $code .= qq{
                    my \$subpos = $pos - 1;

                    foreach my \$value (\@_) {
                        Carp::confess(
                            "Array argument \$subpos must be of type $subtype") unless $validator;

                        \$subpos++;
                    }
                };
            }
        }
        elsif ($types[-1] =~ m/^\%(.*)/) {
            my $subtype = $1;

            $subtype =~ s{\?$}{};

            #Carp::confess("invoked with odd number of parameters")
            #if ($#{$values} - $pos) % 2 != 0;

            if ($subtype ne 'ANY') {
                my $validator = _build_validator($subtype, '$hash{$key}');

                $code .= qq{
                    my %hash = \@_[$pos .. \$#_];

                    foreach my \$key (keys %hash) {
                        Carp::confess(
                            "Hash key '\$key' value must be of type $subtype") unless $validator;
                    }
                };
            }
        }
    }

    $code .= '1;};';

    return $code;
}

sub _build_validator {
    my ($type, $var) = @_;

    $var ||= '$_[0]';

    my @validator = ();

    my @types = split /\|/, $type;

    for my $type (@types) {
        if ($type eq 'SCALAR') {
            push @validator, "!ref($var)";
        }
        elsif ($type =~ m/^(.*?)REF$/) {
            push @validator, "ref($var) eq '$1'";
        }
        elsif ($type =~ m/^OBJECT(?:\((.*?)\))?$/) {
            my $isa = $1;
            push @validator,
              $isa
              ? "Scalar::Util::blessed($var) && $var->isa('$isa')"
              : "Scalar::Util::blessed($var)";
        }
        elsif ($type eq 'REGEXP') {
            push @validator, qq{ref($var) eq 'Regexp'};
        }
        else {
            die "Unknown type $type";
        }
    }

    return join ' || ', @validator;
}

1;
