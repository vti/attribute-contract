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
        eval $code or Carp::croak("Cannot compile contract: $@");
    };

    return $cache{$attributes};
}

sub _build {
    my ($attributes) = @_;

    my @types = split /\s*,\s*/, $attributes;

    my $package = __PACKAGE__ . md5_hex($attributes);
    my $code    = "package $package;";
    $code .= 'sub {my $self = shift;require Scalar::Util;';
    $code .= qq/\$Carp::Internal{'$package'}++;/;
    $code .= q/$Carp::Internal{'Attribute::Contract::TypeValidator'}++;/;

    my $min_required = grep { !/\?$/ } @types;
    my $max_allowed = scalar @types;

    if (grep { m/^\@/ } @types[0 .. $#types - 1]) {
        Carp::confess('Array can be only the last element');
    }

    if (grep { m/^\%/ } @types[0 .. $#types - 1]) {
        Carp::confess('Hash can be only the last element');
    }

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
            last if $pos >= @_;

            if ($type =~ m/^(?:\@|\%)/) {
                last;
            }

            $type =~ s{\?$}{};

            my $validator = _build_validator($type, '$_[' . $pos . ']');

            $type = quotemeta $type;
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

    my @validator = ();

    my @types;
    while ($type =~ m/(?:\@|\%)?([a-z\*]+)(?:\((.*?)\))?/gci) {
        my $name        = $1;
        my $options     = $2;
        my $is_nullable = ($name =~ s{\*$}{}) ? 1 : 0;

        if ($options) {
            $options = [split /\|/, $options];
        }

        push @types,
          {
            name        => $name,
            options     => $options || [],
            is_nullable => $is_nullable
          };
    }

    for my $type (@types) {
        my $name        = $type->{name};
        my $options     = $type->{options};
        my $is_nullable = $type->{is_nullable};

        if ($name eq 'ANY') {
            push @validator, $is_nullable
              ? '1'
              : "defined($var)";
        }
        elsif ($name eq 'VALUE') {
            my $type_check = '';

            my @type_check;
            foreach my $option (@$options) {
                if ($option eq 'Str') {
                    next;
                }
                elsif ($option eq 'Int') {
                    push @type_check,
                        "Scalar::Util::looks_like_number($var) &&"
                      . " $var "
                      . '=~ m/^[+-]?\d+\z/';
                }
                elsif ($option eq 'Float') {
                    push @type_check,
                        "Scalar::Util::looks_like_number($var) &&"
                      . " $var "
                      . '=~ m/^[+-]?(?=\.?\d)\d*\.?\d*(?:e[+-]?\d+)?\z/i';
                }
                elsif ($option =~ m{^/(.*)/$}) {
                    my $re = qr/$1/;
                    push @type_check, "$var =~ m/$re/"
                }
                else {
                    Carp::croak("Unknown type '$option'");
                }
            }

            $type_check = ' && ' . join(' || ', map { "($_)" } @type_check)
              if @type_check;

            push @validator, $is_nullable
              ? "(defined($var) ? (!ref($var)$type_check) : 1)"
              : "defined($var) && (!ref($var)$type_check)";
        }
        elsif ($name eq 'REF') {
            my $condition = "ref($var) &&"
              . " (!Scalar::Util::blessed($var) || ref($var) eq 'Regexp')";

            if (@$options) {
                $condition .= ' && ('
                  . join(' || ', map { "ref($var) eq '$_'" } @$options) . ')';
            }

            if ($is_nullable) {
                $condition = "(defined($var) ? $condition : 1)";
            }

            push @validator, $condition;
        }
        elsif ($name eq 'OBJECT') {
            my ($isa) = @$options;
            my $condition =
              $isa
              ? "Scalar::Util::blessed($var) && $var->isa('$isa') && ref($var) ne 'Regexp'"
              : "Scalar::Util::blessed($var) && ref($var) ne 'Regexp'";

            if ($is_nullable) {
                $condition = "(defined($var) ? $condition : 1)";
            }

            push @validator, $condition;
        }
        else {
            Carp::confess("Unknown type '$name'");
        }
    }

    return join ' || ', map { "($_)" } @validator;
}

1;
