package DBIx::DBSchema::Column;

use strict;
use vars qw(@ISA);
#use Carp;
#use Exporter;

#@ISA = qw(Exporter);
@ISA = qw();

=head1 NAME

DBIx::DBSchema::Column - Column objects

=head1 SYNOPSIS

  use DBIx::DBSchema::Column;

  $column = new DBIx::DBSchema::Column ( $name, $sql_type, '' );
  $column = new DBIx::DBSchema::Column ( $name, $sql_type, 'NULL' );
  $column = new DBIx::DBSchema::Column ( $name, $sql_type, '', $length );
  $column = new DBIx::DBSchema::Column ( $name, $sql_type, 'NULL', $length );
  $column = new DBIx::DBSchema::Column ( $name, $sql_type, 'NULL', $length, $local );

  $name = $column->name;
  $column->name( 'name' );

  $sql_type = $column->type;
  $column->sql_type( 'sql_type' );

  $null = $column->null;
  $column->null( 'NULL' );
  $column->null( 'NOT NULL' );
  $column->null( '' );

  $length = $column->length;
  $column->length( '10' );
  $column->length( '8,2' );

  $sql_line = $column->line;
  $sql_line = $column->line($datasrc);

=head1 DESCRIPTION

DBIx::DBSchema::Column objects represent columns in tables (see
L<DBIx::DBSchema::Table>).

=head1 METHODS

=over 4

=item new [ NAME [ , SQL_TYPE [ , NULL [ , LENGTH  [ , LOCAL ] ] ] ] ]

Creates a new DBIx::DBSchema::Column object.  NAME is the name of the column.
SQL_TYPE is the SQL data type.  NULL is the nullability of the column (the
empty string is equivalent to `NOT NULL').  LENGTH is the SQL length of the
column.  LOCAL is reserved for database-specific information.

=cut

sub new {
  my($proto,$name,$type,$null,$length,$local)=@_;

  #croak "Illegal name: $name" if grep $name eq $_, @reserved_words;

  $null =~ s/^NOT NULL$//i;
  $null = 'NULL' if $null;

  my $class = ref($proto) || $proto;
  my $self = {
    'name'   => $name,
    'type'   => $type,
    'null'   => $null,
    'length' => $length,
    'local'  => $local,
  };

  bless ($self, $class);

}

=item name [ NAME ]

Returns or sets the column name.

=cut

sub name {
  my($self,$value)=@_;
  if ( defined($value) ) {
  #croak "Illegal name: $name" if grep $name eq $_, @reserved_words;
    $self->{'name'} = $value;
  } else {
    $self->{'name'};
  }
}

=item type [ TYPE ]

Returns or sets the column type.

=cut

sub type {
  my($self,$value)=@_;
  if ( defined($value) ) {
    $self->{'type'} = $value;
  } else {
    $self->{'type'};
  }
}

=item null [ NULL ]

Returns or sets the column null flag (the empty string is equivalent to
`NOT NULL')

=cut

sub null {
  my($self,$value)=@_;
  if ( defined($value) ) {
    $value =~ s/^NOT NULL$//i;
    $value = 'NULL' if $value;
    $self->{'null'} = $value;
  } else {
    $self->{'null'};
  }
}

=item length [ LENGTH ]

Returns or sets the column length.

=cut

sub length {
  my($self,$value)=@_;
  if ( defined($value) ) {
    $self->{'length'} = $value;
  } else {
    $self->{'length'};
  }
}

=item local [ LOCAL ]

Returns or sets the database-specific field.

=cut

sub local {
  my($self,$value)=@_;
  if ( defined($value) ) {
    $self->{'local'} = $value;
  } else {
    $self->{'local'};
  }
}

=item line [ $datasrc ]

Returns an SQL column definition.

If passed a DBI data source such as `DBI:mysql:database' or
`DBI:Pg:dbname=database', will use syntax specific to that database engine.
Currently supported databases are MySQL and PostgreSQL.  Non-standard syntax
for other engines (if applicable) may also be supported in the future.

=cut

sub line {
  my($self,$datasrc)=@_;
  my($null)=$self->null;
  if ( $datasrc =~ /^dbi:mysql:/i ) { #yucky mysql hack
    $null ||= "NOT NULL"
  }
  if ( $datasrc =~ /^dbi:pg/i ) { #yucky Pg hack
    $null ||= "NOT NULL";
    $null =~ s/^NULL$//;
  }
  join(' ',
    $self->name,
    $self->type. ( $self->length ? '('.$self->length.')' : '' ),
    $null,
    ( ( $datasrc =~ /^dbi:mysql:/i )
      ? $self->local
      : ''
    ),
  );
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

line() has database-specific foo that probably ought to be abstracted into
the DBIx::DBSchema:DBD:: modules.

=head1 SEE ALSO

L<DBIx::DBSchema::Table>, L<DBIx::DBSchema>, L<DBIx::DBSchema::DBD>, L<DBI>

=cut

1;

