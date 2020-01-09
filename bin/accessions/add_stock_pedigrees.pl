#! /usr/bin/env perl

=head1 NAME

add_stock_pedigrees.pl

=head1 DESCRIPTION

Usage: perl add_stock_pedigrees.pl -H dbhost -D dbname [-t] -d lines

-H = db host
-D = db name 
-t = test, rollback any changes
-d = file of T3 lines with pedigrees (Name, Species, GRIN, Synonym, Breeding Program, Parent1, Parent2, Pedigree, Description)

This script will load the pedigrees for lines from T3.  The input file is the line records 
file from T3's Bulk Download.  The purdy pedigree string will be loaded as a 'pedigree' stock 
prop for a matching Accession.

=cut

use strict;

use CXGN::DB::InsertDBH;

use Text::CSV;
use Data::Dumper;
use Getopt::Std;


## DATABASE VARIABLES ##
my $STOCK_PROP_CV_NAME = 'stock_property';
my $STOCK_PROP_PEDIGREE_CVTERM_NAME = 'pedigree';




our ($opt_H, $opt_D, $opt_t, $opt_d);

getopts('H:D:td:');

my $dbhost = $opt_H;
my $dbname = $opt_D;
my $test = $opt_t;
my $lines_file = $opt_d;




# Get DB Handle
my $dbh = CXGN::DB::InsertDBH->new({
    dbhost   => $dbhost,
    dbname   => $dbname
});
$dbh->add_search_path(qw/public phenome /);
print STDERR "Connected to database $dbname on host $dbhost.\n";
my ($q, $sth);






# Get pedigree cv term
$q = "SELECT cvterm_id FROM public.cvterm WHERE name = ? AND cv_id = (SELECT cv_id FROM public.cv WHERE name = ?)";
$sth = $dbh->prepare($q);
$sth->execute($STOCK_PROP_PEDIGREE_CVTERM_NAME, $STOCK_PROP_CV_NAME);
my ($pedigree_cvterm_id) = $sth->fetchrow_array();


# Open lines file
my $csv = Text::CSV->new({ sep_char => ',' });
open(my $data, '<', $lines_file) or die "Could not open lines file '$lines_file': $!\n";

# Loop through each line
while ( my $line = <$data> ) {
    chomp $line;
    next if ($. == 1); # skip header line
    if ( $csv->parse($line) ) {
        my @fields = $csv->fields();
        my $line_name = $fields[0];
        my $pedigree = $fields[7];

        # Line has a pedigree...
        if ( !($pedigree eq '') ) {

            # Fix line name
            $line_name =~ tr/&/_/;
            
            # Find matching stock...
            $q = "SELECT stock_id FROM public.stock WHERE name = ?";
            $sth = $dbh->prepare($q);
            $sth->execute($line_name);
            my ($stock_id) = $sth->fetchrow_array();

            # Stock not found...
            if ( !defined($stock_id) ) {
                print STDERR "WARNING: Line $line_name not found in database!  ...skipping\n";
            }

            # Add pedigree to stock prop
            else {
                print STDOUT "UPDATING: Line $line_name = ID $stock_id | $pedigree\n";
                $q = "INSERT INTO public.stockprop (stock_id, type_id, value, rank) VALUES (?, ?, ?, 0)";
                $sth = $dbh->prepare($q);
                $sth->execute($stock_id, $pedigree_cvterm_id, $pedigree);
            }

        }
    }
}



# Rollback or Commit the Changes
if ( $test ) {
    $dbh->rollback();
}
else {
    $dbh->commit();
}
