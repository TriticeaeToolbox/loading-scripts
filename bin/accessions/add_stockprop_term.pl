#! /usr/bin/env perl

=head1 NAME

add_stockprop_term.pl

=head1 DESCRIPTION

Usage: perl add_stockprop_term.pl -H dbhost -D dbname [-t] -n term_name [-d term_definition]

-H = db host
-D = db name
-t = test, rollback any changes
-n = name of the new stockprop term
-d = definition of the new stockprop term

This script will add a new CV Term to the stock_property CV.

=cut

use strict;

use CXGN::DB::InsertDBH;

use Text::CSV;
use Data::Dumper;
use Getopt::Std;


#### DATABASE VARIABLES ####
my $CV_NAME = "stock_property";
my $DB_NAME = "null";



our ($opt_H, $opt_D, $opt_t, $opt_n, $opt_d);

getopts('H:D:tn:d:');

my $dbhost = $opt_H;
my $dbname = $opt_D;
my $test = $opt_t;
my $term = $opt_n;
my $definition = $opt_d;




# Check if term is defined
if ( !defined($term) ) {
   die "ERROR: Term name is not defined!\n"
}



# Get DB Handle and Schema
my $dbh = CXGN::DB::InsertDBH->new({
    dbhost   => $dbhost,
    dbname   => $dbname
});
$dbh->add_search_path(qw/public/);
my ($q, $sth);
print STDERR "Connected to database $dbname on host $dbhost.\n";

print STDERR "==> Adding Term '$term' to stock_property CV\n";


# Add dbxref
my $a = "autocreated:$term";
$q = "INSERT INTO public.dbxref (db_id, accession) SELECT db_id, ? FROM public.db WHERE name = 'null' RETURNING dbxref_id";
$sth = $dbh->prepare($q);
$sth->execute($a);
my ($dbxref_id) = $sth->fetchrow_array();

# Add cvterm
$q = "INSERT INTO public.cvterm (cv_id, name, definition, dbxref_id, is_obsolete, is_relationshiptype) SELECT cv_id, ?, ?, ?, 0, 0 FROM public.cv WHERE name = ?";
$sth = $dbh->prepare($q);
$sth->execute($term, $definition, $dbxref_id, $CV_NAME);



# Rollback or Commit the Changes
if ( $test ) {
    $dbh->rollback();
}
else {
    $dbh->commit();
}
