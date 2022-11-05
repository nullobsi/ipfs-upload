use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
  VERSION   => '0.01',
  PREREQ_PM => {
      'Mojolicious'                  => '9.27',
      'Mojolicious::Plugin::OpenAPI' => '5.07',
      'Mojo::Pg'                     => '4.27',
      'DateTime::Format::Pg'         => '0.16001'
  },
  test => {TESTS => 't/*.t'}
);
