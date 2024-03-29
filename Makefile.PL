use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
  VERSION   => '0.01',
  PREREQ_PM => {
      'Mojolicious'                  => '9.27',
      'Mojolicious::Plugin::OpenAPI' => '5.07',
      'Mojo::Pg'                     => '4.27',
      'Mojo::SQLite'                 => '3.009',
      'Crypt::Random'                => '1.25',
      'Crypt::Argon2'                => '0.013',
      'Bytes::Random::Secure'        => '0.29',
      'Number::Bytes::Human'         => '0.11',
  },
  test => {TESTS => 't/*.t'}
);
