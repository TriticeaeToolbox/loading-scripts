#! /usr/bin/env perl

=head1 NAME

add_breeding_program.pl

=head1 DESCRIPTION

Usage: perl add_breeding_program.pl -H dbhost -D dbname -U dbuser -P dbpass -n name -d description

-H = db host
-D = db name 
-U = db user
-P = db pass
-n = breeding program name
-d = breeding program description

This script will create a new Breeding Program with the specified name and description, if a breeding 
program with the same does not yet exist in the database.

=cut

use strict;

use Getopt::Std;
use Data::Dumper;

use CXGN::BreedersToolbox::Projects;




# PARSE CLI ARGS
our ($opt_H, $opt_D, $opt_U, $opt_P, $opt_t, $opt_n, $opt_d);

getopts('H:D:U:P:n:d:');

my $dbhost = $opt_H;
my $dbname = $opt_D;
my $dbuser = $opt_U;
my $dbpass = $opt_P;
my $bp_name = $opt_n;
my $bp_desc = $opt_d;



# SET UP DB CONNECTION
print STDOUT "Connecting to database...\n";
my $dbh = CXGN::DB::Connection->new({ 
    dbhost=>$dbhost,
    dbname=>$dbname,
    dbpass=>$dbpass,
    dbuser=>$dbuser,
    dbargs => {
        AutoCommit => 1,
        RaiseError => 1
    }
});
my $chado_schema= Bio::Chado::Schema->connect(  sub { $dbh->get_actual_dbh() } );



# ADD BREEDING PROGRAM
my $p = CXGN::BreedersToolbox::Projects->new( { schema => $chado_schema });
my $new_program = $p->new_breeding_program($bp_name, $bp_desc);

# Check for error
if ( exists $new_program->{'error'} ) {
    print STDERR "ERROR: Could not add breeding program $bp_name:\n";
    print STDERR $new_program->{'error'} . "\n";
}
elsif ( exists $new_program->{'success'} ) {
    print STDOUT $new_program->{'success'} . "\n";
}
else {
    print STDERR "ERROR: Unknown return value from new_breeding_program():\n";
    print STDERR Dumper $new_program;
}