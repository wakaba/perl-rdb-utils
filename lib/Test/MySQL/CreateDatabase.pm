package Test::MySQL::CreateDatabase;
use strict;
use warnings;
our $VERSION = '2.0';
use Test::mysqld;
use Test::More;
use DBI;
use Exporter::Lite;

our @EXPORT_OK;

our @MY_CNF_ARGS;

our $DEBUG;

my $mysqld;
push @EXPORT_OK, qw(mysqld);
sub mysqld () {
    return $mysqld if $mysqld;

    warn "Initializing Test::mysqld...\n" if $DEBUG;
    my $max = $ENV{TEST_MYSQL_CREATEDB_MAX_CONNECTIONS} || 1000;
    $mysqld = eval {
        Test::mysqld->new(
            mysqld => $ENV{MYSQLD} || Test::mysqld::_find_program(qw/mysqld bin libexec sbin/),
            mysql_install_db => $ENV{MYSQL_INSTALL_DB} || Test::mysqld::_find_program(qw/mysql_install_db bin scripts/) . ($^O eq 'darwin' ? '' : ' '),
            my_cnf => {
                'skip-networking' => '',
                'innodb_lock_wait_timeout' => 2,
                'max_connections' => $max,
                @MY_CNF_ARGS,
            },
        );
    } or BAIL_OUT($Test::mysqld::errstr || $@);
    my $dbh = DBI->connect($mysqld->dsn(dbname => 'mysql'))
        or BAIL_OUT($DBI::errstr);
    $dbh->do(sprintf 'SET GLOBAL max_connections = %d', $max)
        or BAIL_OUT($DBI::errstr);
    warn "done.\n" if $DEBUG;
    return $mysqld;
}

sub test_dbh_do ($) {
    my $dbh = DBI->connect(mysqld->dsn(dbname => 'mysql'))
        or BAIL_OUT($DBI::errstr);
    $dbh->do(shift || die) or BAIL_OUT($DBI::errstr);
    $dbh->disconnect;
}

our $DBNumber = 1;

push @EXPORT_OK, qw(reset_db_set);
sub reset_db_set () {
    $DBNumber++;
}

push @EXPORT_OK, qw(test_dsn);
sub test_dsn ($) {
    my $name = shift || die;
    $name .= '_' . $DBNumber . '_test';
    my $sql = sprintf 'CREATE DATABASE `%s`', $name;
    warn "$sql\n" if $DEBUG;
    test_dbh_do $sql;
    return mysqld->dsn(dbname => $name);
}

push @EXPORT_OK, qw(dsn2dbh);
sub dsn2dbh ($) {
    return DBI->connect($_[0], {RaiseError => 1});
}
push @EXPORT_OK, qw(copy_schema_from_test_db);

sub copy_schema_from_test_db ($$$$) {
    my ($orig_dsn, $user, $password, $new_dbh) = @_;
    my $dbname;
    if ($orig_dsn =~ /\bdbname=([0-9A-Za-z_]+?_test)\b/) {
        $dbname = $1;
    } else {
        warn "Can't copy schema from |$orig_dsn|\n";
        return;
    }

    my $old_dbh = DBI->connect($orig_dsn, $user, $password)
        or BAIL_OUT($DBI::errstr);

    my $sth_tables = $old_dbh->prepare('SHOW TABLES');
    $sth_tables->execute;
    while (my $row_table = $sth_tables->fetch) {
        my $table = $old_dbh->quote_identifier($row_table->[0]);
        my $sth_create = $old_dbh->prepare("SHOW CREATE TABLE $table");
        $sth_create->execute;
        my $create_statement = $sth_create->fetch->[1];
        $new_dbh->do($create_statement) or die $new_dbh->errstr;
    }
}

push @EXPORT_OK, qw(copy_schema_from_file);
sub copy_schema_from_file ($$) {
    my ($f, $new_dbh) = @_;
    my $schema = $f->slurp;
    while ($schema =~ /\b(CREATE TABLE.*?);/sgi) {
        my $sql = $1;
        warn "$sql\n" if $DEBUG;
        my $sth = $new_dbh->prepare($sql);
        $sth->execute;
    }
}

push @EXPORT_OK, qw(extract_schema_sql_from_file);
sub extract_schema_sql_from_file ($) {
    my ($f) = @_;
    my @result;
    my $schema = $f->slurp;
    $schema =~ s/-- .*$//m;
    while ($schema =~ /\b((?:CREATE (?:TABLE|DATABASE)|INSERT|ALTER TABLE).*?);/sgi) {
        push @result, $1;
    }
    return \@result;
}

push @EXPORT_OK, qw(execute_inserts_from_file);
sub execute_inserts_from_file ($$) {
    my ($f, $new_dbh) = @_;
    my $schema = $f->slurp;
    while ($schema =~ /\b(INSERT.*?);/sgi) {
        my $sql = $1;
        warn "$sql\n" if $DEBUG;
        my $sth = $new_dbh->prepare($sql);
        $sth->execute;
    }
}

push @EXPORT_OK, qw(execute_alter_tables_from_file);
sub execute_alter_tables_from_file ($$) {
    my ($f, $new_dbh) = @_;
    my $schema = $f->slurp;
    while ($schema =~ /\b(ALTER TABLE.*?);/sgi) {
        my $sql = $1;
        warn "$sql\n" if $DEBUG;
        my $sth = $new_dbh->prepare($sql);
        $sth->execute;
    }
}

1;

=head1 LICENSE

Copyright 2010-2011 Hatena <http://www.hatena.ne.jp/>.

Copyright 2014 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
