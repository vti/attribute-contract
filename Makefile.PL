#!/usr/bin/env perl

use 5.012;

use strict;
use warnings;

use ExtUtils::MakeMaker;

my ($mm) = $ExtUtils::MakeMaker::VERSION =~ /^([^_]+)/;

WriteMakefile(
    NAME         => 'Attribute::Contract',
    VERSION_FROM => 'lib/Attribute/Contract.pm',
    ABSTRACT     => 'Design by contract via attributes',
    AUTHOR       => 'Viacheslav Tykhanovskyi <vti@cpan.org>',

    ($mm < 6.3002 ? () : ('LICENSE' => 'artistic_2')),

    (
        $mm < 6.46
        ? ()
        : (
            META_MERGE => {
                requires  => {perl => '5.008007'},
                resources => {
                    license    => 'http://dev.perl.org/licenses/',
                    repository => 'http://github.com/vti/attribute-contract'
                },
                no_index => {directory => [qw/t/]}
            },
            META_ADD => {
                build_requires     => {},
                configure_requires => {}
            },
        )
    ),

    PREREQ_PM => {
        'Carp'         => '0',
        'Scalar::Util' => '0',
        'Exporter'     => '0',

        'Test::Class' => '0',
        'Test::Fatal' => '0',
    },
    test => {TESTS => 't/*.t t/*/*.t t/*/*/*.t t/*/*/*/*.t'}
);
