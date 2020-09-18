#! /usr/bin/perl

=head1 NAME

categorize_genetic_chars.pl

=head1 DESCRIPTION

Usage: perl categorize_genetic_chars.pl -H dbhost -D dbname [-t] -c chars

-H = db host
-D = db name
-t = test, rollback any changes
-c = file of genetic characters (Character,Category,Chromosome,Arm,Description,Values)

This script will associate each T3 genetic character (breedbase locus) with a category 
in the T3 Genetic Character Ontology.

NOTE: The T3 Genetic Character Category ontology must be loaded before running this script!

=cut

use strict;

use CXGN::DB::InsertDBH;

use Text::CSV;
use Data::Dumper;
use Getopt::Std;


#### DATABASE VARIABLES ####
my $ONTO_NAME = "t3_locus_ontology";
my $SP_PERSON_ID = 604;


our ($opt_H, $opt_D, $opt_c, $opt_t);

getopts('H:D:c:t');

my $dbhost = $opt_H;
my $dbname = $opt_D;
my $chars_file = $opt_c;
my $test = $opt_t;




# Get DB Handle
my $dbh = CXGN::DB::InsertDBH->new({
    dbhost   => $dbhost,
    dbname   => $dbname
});
$dbh->add_search_path(qw/public phenome /);
print STDERR "Connected to database $dbname on host $dbhost.\n";
my ($q, $sth);


#### ASSOCIATE LOCI WITH CVTERMS ####

# Get CV ID
$q = "SELECT cv_id FROM public.cv WHERE name = ?;";
$sth = $dbh->prepare($q);
$sth->execute($ONTO_NAME);
my ($CV_ID) = $sth->fetchrow_array();

# Open genetic chars file
my $csv = Text::CSV->new({ sep_char => ',' });
open(my $data, '<', $chars_file) or die "Could not open chars file '$chars_file': $!\n";

# Loop through genetic characters
while ( my $line = <$data> ) {
    chomp $line;
    next if ($. == 1); # skip header line
    if ( $csv->parse($line) ) {
        my @fields = $csv->fields();
        my $locus_name = $fields[0];
        my $locus_category = $fields[1];


        # Get matching locus id
        $q = "SELECT locus_id FROM phenome.locus WHERE locus_name = ?;";
        $sth = $dbh->prepare($q);
        $sth->execute($locus_name);
        my ($locus_id) = $sth->fetchrow_array();

        # Found matching locus...
        if ( $locus_id ) {


            # Get matching cvterm dbxref_id
            $q = "SELECT dbxref_id FROM public.cvterm WHERE cv_id = ? AND name = ?;";
            $sth = $dbh->prepare($q);
            $sth->execute($CV_ID, $locus_category);
            my ($dbxref_id) = $sth->fetchrow_array();

            # Found matching category cvterm...
            if ( $dbxref_id ) {

                # Associate Locus and CV Term
                $q = "INSERT INTO phenome.locus_dbxref (locus_id, dbxref_id, obsolete, sp_person_id) VALUES (?, ?, ?, ?) RETURNING locus_dbxref_id;";
                $sth = $dbh->prepare($q);
                $sth->execute($locus_id, $dbxref_id, 'FALSE', $SP_PERSON_ID);
                my ($locus_dbxref_id) = $sth->fetchrow_array();

                $q = "INSERT INTO phenome.locus_dbxref_evidence (locus_dbxref_id, relationship_type_id, evidence_code_id, sp_person_id, obsolete) SELECT ?, dbxref_id, ?, ?, ? FROM public.dbxref WHERE accession = 'is_a';";
                $sth = $dbh->prepare($q);
                $sth->execute($locus_dbxref_id, $dbxref_id, $SP_PERSON_ID, 'FALSE');

                print STDERR "Added $locus_name to category $locus_category...\n";
            }

            # No matching cvterm
            else {
                print STDERR "ERROR: Could not find matching cvterm for locus category: $locus_category\n";
                $dbh->rollback();
                exit 1;
            }

        }

        else {
            print STDERR "ERROR: Could not find matching locus with name: $locus_name\n";
            $dbh->rollback();
            exit 1;
        }

    }
    else {
        print STDERR "ERROR: Could not parse line: $line\n";
    }
}





# Rollback or Commit the Changes
if ( $test ) {
    $dbh->rollback();
}
else {
    $dbh->commit();
}
