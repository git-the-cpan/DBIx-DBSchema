# internal utility subroutines used by multiple classes

package DBIx::DBSchema::_util;

use strict;
use vars qw(@ISA @EXPORT_OK);
use Exporter;
use Carp qw(confess);

@ISA = qw(Exporter);
@EXPORT_OK = qw( _load_driver );

sub _load_driver {
  my($dbh) = @_;
  my $driver;
  if ( ref($dbh) ) {
    $driver = $dbh->{Driver}->{Name};
  } else {
    $dbh =~ s/^dbi:(\w*?)(?:\((.*?)\))?://i #nicked from DBI->connect
                        or '' =~ /()/; # ensure $1 etc are empty if match fails
    $driver = $1 or confess "can't parse data source: $dbh";
  }

  #require "DBIx/DBSchema/DBD/$driver.pm";
  #$driver;
  eval 'require "DBIx/DBSchema/DBD/$driver.pm"' and $driver or die $@;
}

1;

