package DBIx::DBSchema::DBD;

use strict;
use vars qw($VERSION);

$VERSION = '0.01';

=head1 NAME

DBIx::DBSchema::DBD - DBIx::DBSchema Driver Writer's Guide

=head1 SYNOPSIS

  perldoc DBIx::DBSchema::DBD

=head1 DESCRIPTION

Drivers should be named DBIx::DBSchema::DBD::DatabaseName, where DatabaseName
is the same as the DBD:: driver for this database.  Drivers should implement the
following class methods:

=over 4

=item columns CLASS DBI_DBH TABLE

Given an active DBI database handle, return a listref of listrefs (see
L<perllol>), each containing five elements: column name, column type,
nullability, column length, and a field reserved for driver-specific use.

=item primary_key CLASS DBI_DBH TABLE

Given an active DBI database handle, return the primary key for the specified
table.

=item unique CLASS DBI_DBH TABLE

Given an active DBI database handle, return a hashref of unique indices.  The
keys of the hashref are index names, and the values are arrayrefs which point
a list of column names for each.  See L<perldsc/"HASHES OF LISTS"> and
L<DBIx::DBSchema::ColGroup>.

=item index CLASS DBI_DBH TABLE

Given an active DBI database handle, return a hashref of (non-unique) indices.
The keys of the hashref are index names, and the values are arrayrefs which
point a list of column names for each.  See L<perldsc/"HASHES OF LISTS"> and
L<DBIx::DBSchema::ColGroup>.

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

=head1 SEE ALSO

L<DBIx::DBSchema>, L<DBIx::DBSchema::DBD::mysql>, L<DBIx::DBSchema::DBD::Pg>,
L<DBIx::DBSchema::ColGroup>, L<DBI>, L<DBI::DBD>, L<perllol>,
L<perldsc/"HASHES OF LISTS">

=cut 

1;

