package DBIx::DBSchema;

use strict;
use vars qw(@ISA $VERSION $DEBUG);
#use Exporter;
use Storable;
use DBIx::DBSchema::_util qw(_load_driver _dbh);
use DBIx::DBSchema::Table;
use DBIx::DBSchema::Column;
use DBIx::DBSchema::ColGroup::Unique;
use DBIx::DBSchema::ColGroup::Index;

#@ISA = qw(Exporter);
@ISA = ();

$VERSION = "0.31";
$DEBUG = 0;

=head1 NAME

DBIx::DBSchema - Database-independent schema objects

=head1 SYNOPSIS

  use DBIx::DBSchema;

  $schema = new DBIx::DBSchema @dbix_dbschema_table_objects;
  $schema = new_odbc DBIx::DBSchema $dbh;
  $schema = new_odbc DBIx::DBSchema $dsn, $user, $pass;
  $schema = new_native DBIx::DBSchema $dbh;
  $schema = new_native DBIx::DBSchema $dsn, $user, $pass;

  $schema->save("filename");
  $schema = load DBIx::DBSchema "filename";

  $schema->addtable($dbix_dbschema_table_object);

  @table_names = $schema->tables;

  $DBIx_DBSchema_table_object = $schema->table("table_name");

  @sql = $schema->sql($dbh);
  @sql = $schema->sql($dsn, $username, $password);
  @sql = $schema->sql($dsn); #doesn't connect to database - less reliable

  $perl_code = $schema->pretty_print;
  %hash = eval $perl_code;
  use DBI qw(:sql_types); $schema = pretty_read DBIx::DBSchema \%hash;

=head1 DESCRIPTION

DBIx::DBSchema objects are collections of DBIx::DBSchema::Table objects and
represent a database schema.

This module implements an OO-interface to database schemas.  Using this module,
you can create a database schema with an OO Perl interface.  You can read the
schema from an existing database.  You can save the schema to disk and restore
it a different process.  Most importantly, DBIx::DBSchema can write SQL
CREATE statements statements for different databases from a single source.

Currently supported databases are MySQL and PostgreSQL.  Sybase support is
partially implemented.  DBIx::DBSchema will attempt to use generic SQL syntax
for other databases.  Assistance adding support for other databases is
welcomed.  See L<DBIx::DBSchema::DBD>, "Driver Writer's Guide and Base Class".

=head1 METHODS

=over 4

=item new TABLE_OBJECT, TABLE_OBJECT, ...

Creates a new DBIx::DBSchema object.

=cut

sub new {
  my($proto, @tables) = @_;
  my %tables = map  { $_->name, $_ } @tables; #check for duplicates?

  my $class = ref($proto) || $proto;
  my $self = {
    'tables' => \%tables,
  };

  bless ($self, $class);

}

=item new_odbc DATABASE_HANDLE | DATA_SOURCE USERNAME PASSWORD [ ATTR ]

Creates a new DBIx::DBSchema object from an existing data source, which can be
specified by passing an open DBI database handle, or by passing the DBI data
source name, username, and password.  This uses the experimental DBI type_info
method to create a schema with standard (ODBC) SQL column types that most
closely correspond to any non-portable column types.  Use this to import a
schema that you wish to use with many different database engines.  Although
primary key and (unique) index information will only be read from databases
with DBIx::DBSchema::DBD drivers (currently MySQL and PostgreSQL), import of
column names and attributes *should* work for any database.  Note that this
method only uses "ODBC" column types; it does not require or use an ODBC
driver.

=cut

sub new_odbc {
  my($proto, $dbh) = ( shift, _dbh(@_) );
  $proto->new(
    map { new_odbc DBIx::DBSchema::Table $dbh, $_ } _tables_from_dbh($dbh)
  );
}

=item new_native DATABASE_HANDLE | DATA_SOURCE USERNAME PASSWORD [ ATTR ]

Creates a new DBIx::DBSchema object from an existing data source, which can be
specified by passing an open DBI database handle, or by passing the DBI data
source name, username and password.  This uses database-native methods to read
the schema, and will preserve any non-portable column types.  The method is
only available if there is a DBIx::DBSchema::DBD for the corresponding database engine (currently, MySQL and PostgreSQL).

=cut

sub new_native {
  my($proto, $dbh) = (shift, _dbh(@_) );
  $proto->new(
    map { new_native DBIx::DBSchema::Table ( $dbh, $_ ) } _tables_from_dbh($dbh)
  );
}

=item load FILENAME

Loads a DBIx::DBSchema object from a file.

=cut

sub load {
  my($proto,$file)=@_; #use $proto ?

  my $self;

  #first try Storable
  eval { $self = Storable::retrieve($file); };

  if ( $@ && $@ =~ /not.*storable/i ) { #then try FreezeThaw
    eval "use FreezeThaw;";
    die $@ if $@;
    open(FILE,"<$file") or die "Can't open $file: $!";
    my $string = join('',<FILE>);
    close FILE or die "Can't close $file: $!";
    ($self) = FreezeThaw::thaw($string);
  }

  $self;

}

=item save FILENAME

Saves a DBIx::DBSchema object to a file.

=cut

sub save {
  #my($self, $file) = @_;
  Storable::nstore(@_);
}

=item addtable TABLE_OBJECT

Adds the given DBIx::DBSchema::Table object to this DBIx::DBSchema.

=cut

sub addtable {
  my($self,$table)=@_;
  $self->{'tables'}->{$table->name} = $table; #check for dupliates?
}

=item tables 

Returns a list of the names of all tables.

=cut

sub tables {
  my($self)=@_;
  keys %{$self->{'tables'}};
}

=item table TABLENAME

Returns the specified DBIx::DBSchema::Table object.

=cut

sub table {
  my($self,$table)=@_;
  $self->{'tables'}->{$table};
}

=item sql [ DATABASE_HANDLE | DATA_SOURCE [ USERNAME PASSWORD [ ATTR ] ] ]

Returns a list of SQL `CREATE' statements for this schema.

The data source can be specified by passing an open DBI database handle, or by
passing the DBI data source name, username and password.  

Although the username and password are optional, it is best to call this method
with a database handle or data source including a valid username and password -
a DBI connection will be opened and the quoting and type mapping will be more
reliable.

If passed a DBI data source (or handle) such as `DBI:mysql:database' or
`DBI:Pg:dbname=database', will use syntax specific to that database engine.
Currently supported databases are MySQL and PostgreSQL.

If not passed a data source (or handle), or if there is no driver for the
specified database, will attempt to use generic SQL syntax.

=cut

sub sql {
  my($self, $dbh) = ( shift, _dbh(@_) );
  map { $self->table($_)->sql_create_table($dbh); } $self->tables;
}

=item sql_update_schema PROTOTYPE_SCHEMA [ DATABASE_HANDLE | DATA_SOURCE [ USERNAME PASSWORD [ ATTR ] ] ]

Returns a list of SQL statements to update this schema so that it is idential
to the provided prototype schema, also a DBIx::DBSchema object.

 #Optionally, the data source can be specified by passing an open DBI database
 #handle, or by passing the DBI data source name, username and password.  
 #
 #If passed a DBI data source (or handle) such as `DBI:mysql:database' or
 #`DBI:Pg:dbname=database', will use syntax specific to that database engine.
 #Currently supported databases are MySQL and PostgreSQL.
 #
 #If not passed a data source (or handle), or if there is no driver for the
 #specified database, will attempt to use generic SQL syntax.

Right now this method knows how to add new tables and alter existing tables.
It doesn't know how to drop tables yet.

See L<DBIx::DBSchema::Table/sql_alter_table>,
L<DBIx::DBSchema::Column/sql_add_coumn> and
L<DBIx::DBSchema::Column/sql_alter_column> for additional specifics and
limitations.

=cut

#gosh, false laziness w/DBSchema::Table::sql_alter_schema

sub sql_update_schema {
  my($self, $new, $dbh) = ( shift, shift, _dbh(@_) );

  my @r = ();

  foreach my $table ( $new->tables ) {
  
    if ( $self->table($table) ) {
  
      warn "$table exists\n" if $DEBUG > 1;

      push @r,
        $self->table($table)->sql_alter_table( $new->table($table), $dbh );

    } else {
  
      warn "table $table does not exist.\n" if $DEBUG;

      push @r, 
        $new->table($table)->sql_create_table( $dbh );
  
    }
  
  }

  # should eventually drop tables not in $new

  warn join("\n", @r). "\n"
    if $DEBUG;

  @r;
  
}

=item update_schema PROTOTYPE_SCHEMA, DATABASE_HANDLE | DATA_SOURCE [ USERNAME PASSWORD [ ATTR ] ]

Same as sql_update_schema, except actually runs the SQL commands to update
the schema.  Throws a fatal error if any statement fails.

=cut

sub update_schema {
  my($self, $new, $dbh) = ( shift, shift, _dbh(@_) );

  foreach my $statement ( $self->sql_update_schema( $new, $dbh ) ) {
    $dbh->do( $statement )
      or die "Error: ". $dbh->errstr. "\n executing: $statement";
  }

}

=item pretty_print

Returns the data in this schema as Perl source, suitable for assigning to a
hash.

=cut

sub pretty_print {
  my($self) = @_;
  join("},\n\n",
    map {
      my $table = $_;
      "'$table' => {\n".
        "  'columns' => [\n".
          join("", map { 
                         #cant because -w complains about , in qw()
                         # (also biiiig problems with empty lengths)
                         #"    qw( $_ ".
                         #$self->table($table)->column($_)->type. " ".
                         #( $self->table($table)->column($_)->null ? 'NULL' : 0 ). " ".
                         #$self->table($table)->column($_)->length. " ),\n"
                         "    '$_', ".
                         "'". $self->table($table)->column($_)->type. "', ".
                         "'". $self->table($table)->column($_)->null. "', ". 
                         "'". $self->table($table)->column($_)->length. "', ".
                         "'". $self->table($table)->column($_)->default. "', ".
                         "'". $self->table($table)->column($_)->local. "',\n"
                       } $self->table($table)->columns
          ).
        "  ],\n".
        "  'primary_key' => '". $self->table($table)->primary_key. "',\n".
        "  'unique' => [ ". join(', ',
          map { "[ '". join("', '", @{$_}). "' ]" }
            @{$self->table($table)->unique->lol_ref}
          ).  " ],\n".
        "  'index' => [ ". join(', ',
          map { "[ '". join("', '", @{$_}). "' ]" }
            @{$self->table($table)->index->lol_ref}
          ). " ],\n"
        #"  'index' => [ ".    " ],\n"
    } $self->tables
  ). "}\n";
}

=cut

=item pretty_read HASHREF

Creates a schema as specified by a data structure such as that created by
B<pretty_print> method.

=cut

sub pretty_read {
  my($proto, $href) = @_;
  my $schema = $proto->new( map {  
    my(@columns);
    while ( @{$href->{$_}{'columns'}} ) {
      push @columns, DBIx::DBSchema::Column->new(
        splice @{$href->{$_}{'columns'}}, 0, 6
      );
    }
    DBIx::DBSchema::Table->new(
      $_,
      $href->{$_}{'primary_key'},
      DBIx::DBSchema::ColGroup::Unique->new($href->{$_}{'unique'}),
      DBIx::DBSchema::ColGroup::Index->new($href->{$_}{'index'}),
      @columns,
    );
  } (keys %{$href}) );
}

# private subroutines

sub _tables_from_dbh {
  my($dbh) = @_;
  my $driver = _load_driver($dbh);
  my $db_catalog =
    scalar(eval "DBIx::DBSchema::DBD::$driver->default_db_catalog");
  my $db_schema  =
    scalar(eval "DBIx::DBSchema::DBD::$driver->default_db_schema");
  my $sth = $dbh->table_info($db_catalog, $db_schema, '', 'TABLE')
    or die $dbh->errstr;
  #map { $_->{TABLE_NAME} } grep { $_->{TABLE_TYPE} eq 'TABLE' }
  #  @{ $sth->fetchall_arrayref({ TABLE_NAME=>1, TABLE_TYPE=>1}) };
  map { $_->[0] } grep { $_->[1] =~ /^TABLE$/i }
    @{ $sth->fetchall_arrayref([2,3]) };
}

=back

=head1 AUTHORS

Ivan Kohler <ivan-dbix-dbschema@420.am>

Charles Shapiro <charles.shapiro@numethods.com> and Mitchell Friedman
<mitchell.friedman@numethods.com> contributed the start of a Sybase driver.

Daniel Hanks <hanksdc@about-inc.com> contributed the Oracle driver.

Jesse Vincent contributed the SQLite driver.

=head1 CONTRIBUTIONS

Contributions are welcome!  I'm especially keen on any interest in the first
three items/projects below under BUGS.

=head1 COPYRIGHT

Copyright (c) 2000-2006 Ivan Kohler
Copyright (c) 2000 Mail Abuse Prevention System LLC
All rights reserved.
This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=head1 BUGS

Indices are not stored by name.  Index representation could use an overhaul.

Multiple primary keys are not yet supported.

Foreign keys and other constraints are not yet supported.

Eventually it would be nice to have additional transformations (deleted,
modified columns, added/modified/indices (probably need em named first),
added/deleted tables

Need to port and test with additional databases

Each DBIx::DBSchema object should have a name which corresponds to its name
within the SQL database engine (DBI data source).

pretty_print is actually pretty ugly.

Perhaps pretty_read should eval column types so that we can use DBI
qw(:sql_types) here instead of externally.

sql CREATE TABLE output should convert integers
(i.e. use DBI qw(:sql_types);) to local types using DBI->type_info plus a hash
to fudge things

sql_update_schema doesn't drop tables yet.

=head1 SEE ALSO

L<DBIx::DBSchema::Table>, L<DBIx::DBSchema::ColGroup>,
L<DBIx::DBSchema::ColGroup::Unique>, L<DBIx::DBSchema::ColGroup::Index>,
L<DBIx::DBSchema::Column>, L<DBIx::DBSchema::DBD>,
L<DBIx::DBSchema::DBD::mysql>, L<DBIx::DBSchema::DBD::Pg>, L<FS::Record>,
L<DBI>

=cut

1;

