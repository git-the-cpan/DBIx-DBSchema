package DBIx::DBSchema::Table;

use strict;
use vars qw(@ISA %create_params);
#use Carp;
use Exporter;
use DBIx::DBSchema::Column;
use DBIx::DBSchema::ColGroup::Unique;
use DBIx::DBSchema::ColGroup::Index;

#@ISA = qw(Exporter);
@ISA = qw();

=head1 NAME

DBIx::DBSchema::Table - Table objects

=head1 SYNOPSIS

  use DBIx::DBSchema::Table;

  $table = new DBIx::DBSchema::Table (
    "table_name",
    "primary_key",
    $dbix_dbschema_colgroup_unique_object,
    $dbix_dbschema_colgroup_index_object,
    @dbix_dbschema_column_objects,
  );

  $table->addcolumn ( $dbix_dbschema_column_object );

  $table_name = $table->name;
  $table->name("table_name");

  $primary_key = $table->primary_key;
  $table->primary_key("primary_key");

  $dbix_dbschema_colgroup_unique_object = $table->unique;
  $table->unique( $dbix_dbschema__colgroup_unique_object );

  $dbix_dbschema_colgroup_index_object = $table->index;
  $table->index( $dbix_dbschema_colgroup_index_object );

  @column_names = $table->columns;

  $dbix_dbschema_column_object = $table->column("column");

  @sql_statements = $table->sql_create_table;
  @sql_statements = $table->sql_create_table $datasrc;

=head1 DESCRIPTION

DBIx::DBSchema::Table objects represent a single database table.

=head1 METHODS

=over 4

=item new [ TABLE_NAME [ , PRIMARY_KEY [ , UNIQUE [ , INDEX [ , COLUMN... ] ] ] ] ]

Creates a new DBIx::DBSchema::Table object.  TABLE_NAME is the name of the
table.  PRIMARY_KEY is the primary key (may be empty).  UNIQUE is a
DBIx::DBSchema::ColGroup::Unique object (see
L<DBIx::DBSchema::ColGroup::Unique>).  INDEX is a
DBIx::DBSchema::ColGroup::Index object (see
L<DBIx::DBSchema::ColGroup::Index>).  The rest of the arguments should be
DBIx::DBSchema::Column objects (see L<DBIx::DBSchema::Column>).

=cut

sub new {
  my($proto,$name,$primary_key,$unique,$index,@columns)=@_;

  my(%columns) = map { $_->name, $_ } @columns;
  my(@column_order) = map { $_->name } @columns;

  #check $primary_key, $unique and $index to make sure they are $columns ?
  # (and sanity check?)

  my $class = ref($proto) || $proto;
  my $self = {
    'name'         => $name,
    'primary_key'  => $primary_key,
    'unique'       => $unique,
    'index'        => $index,
    'columns'      => \%columns,
    'column_order' => \@column_order,
  };

  bless ($self, $class);

}

=item new_odbc DATABASE_HANDLE TABLE_NAME

Creates a new DBIx::DBSchema::Table object from the supplied DBI database
handle for the specified table.  This uses the experimental DBI type_info
method to create a table with standard (ODBC) SQL column types that most
closely correspond to any non-portable column types.   Use this to import a
schema that you wish to use with many different database engines.  Although
primary key and (unique) index information will only be imported from databases
with DBIx::DBSchema::DBD drivers (currently MySQL and PostgreSQL), import of
column names and attributes *should* work for any database.

=cut

%create_params = (
#  undef             => sub { '' },
  ''                => sub { '' },
  'max length'      => sub { $_[0]->{PRECISION}->[$_[1]]; },
  'precision,scale' =>
    sub { $_[0]->{PRECISION}->[$_[1]]. ','. $_[0]->{SCALE}->[$_[1]]; }
);

sub new_odbc {
  my( $proto, $dbh, $name) = @_;
  my $driver = DBIx::DBSchema::_load_driver($dbh);
  my $sth = _null_sth($dbh, $name);
  my $sthpos = 0;
  $proto->new (
    $name,
    scalar(eval "DBIx::DBSchema::DBD::$driver->primary_key(\$dbh, \$name)"),
    DBIx::DBSchema::ColGroup::Unique->new(
      $driver
       ? [values %{eval "DBIx::DBSchema::DBD::$driver->unique(\$dbh, \$name)"}]
       : []
    ),
    DBIx::DBSchema::ColGroup::Index->new(
      $driver
      ? [ values %{eval "DBIx::DBSchema::DBD::$driver->index(\$dbh, \$name)"} ]
      : []
    ),
    map { 
      my $type_info = scalar($dbh->type_info($sth->{TYPE}->[$sthpos]))
        or die "DBI::type_info ". $dbh->{Driver}->{Name}. " driver ".
               "returned no results for type ".  $sth->{TYPE}->[$sthpos];
      new DBIx::DBSchema::Column
          $_,
          $type_info->{'TYPE_NAME'},
          $sth->{NULLABLE}->[$sthpos],
          &{
            $create_params{ $type_info->{CREATE_PARAMS} }
          }( $sth, $sthpos++ )
    } @{$sth->{NAME}}
  );
}

=item new_native DATABASE_HANDLE TABLE_NAME

Creates a new DBIx::DBSchema::Table object from the supplied DBI database
handle for the specified table.  This uses database-native methods to read the
schema, and will preserve any non-portable column types.  The method is only
available if there is a DBIx::DBSchema::DBD for the corresponding database
engine (currently, MySQL and PostgreSQL).

=cut

sub new_native {
  my( $proto, $dbh, $name) = @_;
  my $driver = DBIx::DBSchema::_load_driver($dbh);
  $proto->new (
    $name,
    scalar(eval "DBIx::DBSchema::DBD::$driver->primary_key(\$dbh, \$name)"),
    DBIx::DBSchema::ColGroup::Unique->new(
      [ values %{eval "DBIx::DBSchema::DBD::$driver->unique(\$dbh, \$name)"} ]
    ),
    DBIx::DBSchema::ColGroup::Index->new(
      [ values %{eval "DBIx::DBSchema::DBD::$driver->index(\$dbh, \$name)"} ]
    ),
    map {
      DBIx::DBSchema::Column->new( @{$_} )
    } eval "DBIx::DBSchema::DBD::$driver->columns(\$dbh, \$name)"
  );
}

=item addcolumn COLUMN

Adds this DBIx::DBSchema::Column object. 

=cut

sub addcolumn {
  my($self,$column)=@_;
  ${$self->{'columns'}}{$column->name}=$column; #sanity check?
  push @{$self->{'column_order'}}, $column->name;
}

=item name [ TABLE_NAME ]

Returns or sets the table name.

=cut

sub name {
  my($self,$value)=@_;
  if ( defined($value) ) {
    $self->{name} = $value;
  } else {
    $self->{name};
  }
}

=item primary_key [ PRIMARY_KEY ]

Returns or sets the primary key.

=cut

sub primary_key {
  my($self,$value)=@_;
  if ( defined($value) ) {
    $self->{primary_key} = $value;
  } else {
    #$self->{primary_key};
    #hmm.  maybe should untaint the entire structure when it comes off disk 
    # cause if you don't trust that, ?
    $self->{primary_key} =~ /^(\w*)$/ 
      #aah!
      or die "Illegal primary key: ", $self->{primary_key};
    $1;
  }
}

=item unique [ UNIQUE ]

Returns or sets the DBIx::DBSchema::ColGroup::Unique object.

=cut

sub unique { 
  my($self,$value)=@_;
  if ( defined($value) ) {
    $self->{unique} = $value;
  } else {
    $self->{unique};
  }
}

=item index [ INDEX ]

Returns or sets the DBIx::DBSchema::ColGroup::Index object.

=cut

sub index { 
  my($self,$value)=@_;
  if ( defined($value) ) {
    $self->{'index'} = $value;
  } else {
    $self->{'index'};
  }
}

=item columns

Returns a list consisting of the names of all columns.

=cut

sub columns {
  my($self)=@_;
  #keys %{$self->{'columns'}};
  #must preserve order
  @{ $self->{'column_order'} };
}

=item column COLUMN_NAME

Returns the column object (see L<DBIx::DBSchema::Column>) for the specified
COLUMN_NAME.

=cut

sub column {
  my($self,$column)=@_;
  $self->{'columns'}->{$column};
}

=item sql_create_table [ DATASRC ]

Returns a list of SQL statments to create this table.

If passed a DBI data source such as `DBI:mysql:database', will use
MySQL-specific syntax.  PostgreSQL is also supported (requires no special
syntax).  Non-standard syntax for other engines (if applicable) may also be
supported in the future.

=cut

sub sql_create_table { 
  my($self,$datasrc)=@_;
  my(@columns)=map { $self->column($_)->line($datasrc) } $self->columns;
  push @columns, "PRIMARY KEY (". $self->primary_key. ")"
    if $self->primary_key;
  if ( $datasrc =~ /^dbi:mysql:/i ) { #yucky mysql hack
    push @columns, map "UNIQUE ($_)", $self->unique->sql_list;
    push @columns, map "INDEX ($_)", $self->index->sql_list;
  }

  "CREATE TABLE ". $self->name. " (\n  ". join(",\n  ", @columns). "\n)\n",
  ( map {
    my($index) = $self->name. "__". $_ . "_index";
    $index =~ s/,\s*/_/g;
    "CREATE UNIQUE INDEX $index ON ". $self->name. " ($_)\n"
  } $self->unique->sql_list ),
  ( map {
    my($index) = $self->name. "__". $_ . "_index";
    $index =~ s/,\s*/_/g;
    "CREATE INDEX $index ON ". $self->name. " ($_)\n"
  } $self->index->sql_list ),
  ;  

}

#

sub _null_sth {
  my($dbh, $table) = @_;
  my $sth = $dbh->prepare("SELECT * FROM $table WHERE 1=0")
    or die $dbh->errstr;
  $sth->execute or die $sth->errstr;
  $sth;
}

=back

=head1 AUTHOR

Ivan Kohler <ivan-dbix-dbschema@420.am>

=head1 COPYRIGHT

Copyright (c) 2000 Ivan Kohler
Copyright (c) 2000 Mail Abuse Prevention System LLC
All rights reserved.
This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=head1 BUGS

sql_create_table() has database-specific foo that probably ought to be
abstracted into the DBIx::DBSchema::DBD:: modules.

Some of the logic in new_odbc might be better abstracted into Column.pm etc.

=head1 SEE ALSO

L<DBIx::DBSchema>, L<DBIx::DBSchema::ColGroup::Unique>,
L<DBIx::DBSchema::ColGroup::Index>, L<DBIx::DBSchema::Column>, L<DBI>

=cut

1;

