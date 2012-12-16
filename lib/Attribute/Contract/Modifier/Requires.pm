package Attribute::Contract::Modifier::Requires;

use strict;
use warnings;

require Carp;
use Scalar::Util qw(blessed);

$Carp::Internal{(__PACKAGE__)}++;

sub modify {
    my $class = shift;
    my ($package, $name, $code_ref, $attributes) = @_;

    $attributes = '' unless defined $attributes;

    my @types = split /\s*,\s*/, $attributes;
    my $min_required = grep { !/\?$/ } @types;
    my $max_allowed = scalar @types;

    if (@types && $types[-1] =~ m/^%/) {
        $min_required++ unless $types[-1] =~ m/\?$/;
        $max_allowed = -1;
    }
    elsif (@types && $types[-1] =~ m/^@/) {
        $max_allowed = -1;
    }

    return sub {
        my $self = shift;

        if (@types == 0 && @_) {
            Carp::confess("No params allowed");
        }

        if ($min_required == 0 && !@_) {
            return $code_ref->($self);
        }

        Carp::confess(
"@{[scalar(@_)]} param(s) passed, at least $min_required param(s) required"
        ) if @_ < $min_required;

        if ($max_allowed != -1) {
            Carp::confess(
"@{[scalar(@_)]} param(s) passed, max $max_allowed param(s) allowed"
            ) if @_ > $max_allowed;
        }

        my $error = 0;
        my $pos   = 0;
        foreach my $value (@_) {
            my $type = $types[$pos];

            if ($type =~ m/^(?:\@|\%)/) {
                $pos++;
                last;
            }

            my $check_code_ref = _check_code_ref($type);

            if (!$check_code_ref->($value)) {
                $error++;
                last;
            }
        }
        continue {
            $pos++;
        }

        if ($error) {
            Carp::confess("Argument $pos must be of type $types[$pos]");
        }

        if ($pos < @_ && $types[-1] =~ m/^\@(.*)/) {
            my $subtype = $1;

            my $check_code_ref = _check_code_ref($subtype);

            my $subpos = $pos - 1;
            foreach my $value (@_[$subpos .. $#_]) {
                if (!$check_code_ref->($value)) {
                    Carp::confess(
                        "Array argument $subpos must be of type $subtype");
                }

                $subpos++;
            }
        }
        elsif ($pos < @_ && $types[-1] =~ m/^\%(.*)/) {
            my $subtype = $1;

            my $check_code_ref = _check_code_ref($subtype);

            Carp::confess(
                "$package->$name: invoked with odd number of parameters")
              if ($#_ - $pos) % 2 != 0;

            my %hash = @_[($pos - 1) .. $#_];

            foreach my $key (keys %hash) {
                my $value = $hash{$key};

                if (!$check_code_ref->($value)) {
                    Carp::confess(
                        "Hash key '$key' value must be of type $subtype");
                }
            }
        }

        return $code_ref->($self, @_);
    };
}

sub _check_code_ref {
    my ($type) = @_;

    $type =~ s/\?$//;

    if ($type eq 'ANY') {
        sub { 1 }
    }
    elsif ($type eq 'SCALAR') {
        sub { !ref $_[0] }
    }
    elsif ($type =~ m/^(.*?)REF$/) {
        my $ref_type = $1;
        sub { $ref_type eq ref $_[0] }
    }
    elsif ($type =~ m/^OBJECT(?:\((.*?)\))?$/) {
        my $isa = $1;
        $isa ? sub { blessed $_[0] && $_[0]->isa($isa) } : sub { blessed $_[0] }
    }
    elsif ($type eq 'REGEXP') {
        sub { ref $_[0] eq 'Regexp' }
    }
    else {
        die "Unknown type $type";
    }
}

1;
