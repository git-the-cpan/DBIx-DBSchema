package DBIx::DBSchema::DBD::Sybase;

use strict;
use vars qw($VERSION @ISA %typemap);
use DBIx::DBSchema::DBD;

$VERSION = '0.02';
@ISA = qw(DBIx::DBSchema::DBD);

%typemap = (
#  'empty' => 'empty'
);

#
# Return this from uncompleted driver calls.
#

=head1 NAME

DBIx::DBSchema::DBD::Sybase - Sybase database driver for DBIx::DBSchema

=head1 SYNOPSIS

use DBI;
use DBIx::DBSchema;

$dbh = DBI->connect('dbi:Sybase:dbname=database', 'user', 'pass');
$schema = new_native DBIx::DBSchema $dbh;

=head1 DESCRIPTION

This module implements a Sybase driver for DBIx::DBSchema. 

=cut

sub columns {

  my($proto, $dbh, $table) = @_;

  my $sth = $dbh->prepare("sp_columns \@table_name=$table") 
  or die $dbh->errstr;

  $sth->execute or die $sth->errstr;
  map {
    [
      $_->{'COLUMN_NAME'},
      $_->{'TYPE_NAME'},
      ($_->{'NULLABLE'} ? 1 : ''),
      $_->{'LENGTH'},
      '', #default
      ''  #local
    ]
  } @{ $sth->fetchall_arrayref({}) };

}

sub primary_key {
    return("StubbedPrimaryKey");
}


sub unique {

    my %stubList = (
	  'stubfirstUniqueIndex' => ['stubfirstUniqueIndex'],
	  'stubtwostUniqueIndex' => ['stubtwostUniqueIndex']
			);

   return ( { %stubList } );

}

sub index {

    my %stubList = (
	  'stubfirstIndex' => ['stubfirstUniqueIndex'],
	  'stubtwostIndex' => ['stubtwostUniqueIndex']
			);

    return ( { %stubList } );

}

=head1 AUTHOR

Charles Shapiro <charles.shapiro@numethods.com>
(courtesy of Ivan Kohler <ivan-dbix-dbschema@420.am>)

Mitchell Friedman <mitchell.friedman@numethods.com>

=head1 COPYRIGHT

Copyright (c) 2001 Charles Shapiro, Mitchell J. Friedman
Copyright (c) 2001 nuMethods LLC.
All rights reserved.
This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=head1 BUGS

Yes.

Most of this is not implemented.

the "columns" method works; primary key, unique and index do not yet.  Please
send any patches to all three addresses listed above.

=head1 SEE ALSO

L<DBIx::DBSchema>, L<DBIx::DBSchema::DBD>, L<DBI>, L<DBI::DBD>

=cut 

1;

