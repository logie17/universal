#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 17;

use FindBin ();
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/lib";

{
  package DynamicUser;

  sub dumper_class { 'Data::Dumper' }
  sub dump_it {
    my $class = shift;
    use universal::dynamic_use;
    return $class->dynamic_use->dumper_class->Dump(\@_);
  }
}

# basic usage
{

  my $dump = eval {
    DynamicUser->dump_it('hello');
  };
  is( $@, '', 'no exceptions' );
  like( $dump, qr/\$VAR1 .* = .* 'hello'/x, 'We got a data::dumper output' );
}

# pragmatic behavior
{
  local $@;
  my $ok = eval {
    use universal::dynamic_use;
    DynamicUser->dynamic_use->dumper_class->Dump([1]);
  };
  is( $@, '', 'no exception' );
  like( $ok, qr/\$VAR1 .* = .* 1/x, 'got expected output' );

  local $@;
  my $not_set_up_yet = eval<<'EVAL';
#line 19490201
    DynamicUser->dynamic_use->dumper_class->Dump([2]);
EVAL
  like( $@, qr/Can't locate object method "dynamic_use" via package "DynamicUser" at .* line 19490201/, 'got expected error' );
  is( $not_set_up_yet, undef, 'no unexpected output' );

  local $@;
  my $unimported = eval<<'EVAL';
    use universal::dynamic_use;
    my $ok = DynamicUser->dynamic_use->dumper_class->Dump([3]);
    like( $ok, qr/\$VAR1 .* = .* 3/x, 'first call succeeds' );

    no universal::dynamic_use;
#line 19490201
    DynamicUser->dynamic_use->dumper_class->Dump([4]);
EVAL
  like( $@, qr/Can't locate object method "dynamic_use" via package "DynamicUser" at .* line 19490201/, 'got expected error after unimport' );
  is( $unimported, undef, 'no unexpected output' );
}

# imports
{
  {
    package mumble;
    use strict;
    use warnings;

    sub simple_exporter_class { 'SimpleExporter' }

    sub load_em_up {
      my ($class, @args) = @_;
      use universal::dynamic_use;
      $class->dynamic_use(@args)->simple_exporter_class;
    }

    sub try_calling {
      my ($class, $method_or_function) = @_;
      return $class->$method_or_function;
    }
  }

  my $try = sub {
    my ($target) = @_;
    local $@;
    my $out = eval { mumble->try_calling($target) };
    return ($out, $@);
  };

  my ($got, $error);

  ($got, $error) = $try->('default_export');
  is( $got, undef, 'no unexpected values' );
  like( $error, qr/Can't locate object method "default_export" via package "mumble"/ );

  mumble->load_em_up;
  ($got, $error) = $try->('default_export');
  is( $got, 'default_export output', 'ran default_export' );
  is( $error, '', 'no exceptions' );
  ($got, $error) = $try->('optional_export');
  is( $got, undef, 'no output for optional_export yet' );
  like( $error, qr/Can't locate object method "optional_export" via package "mumble"/, 'and an error' );

  mumble->load_em_up('optional_export');
  ($got, $error) = $try->('optional_export');
  is( $got, 'optional_export output', 'got optional_export output' );
  is( $error, '', 'no exceptions for optional_export' );
}
