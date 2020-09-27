#! /usr/bin/perl

=head1 NAME

categorize_genetic_chars.pl

=head1 DESCRIPTION

Usage: perl categorize_genetic_chars.pl -H dbhost -D dbname [-rt] -c chars

-H = db host
-D = db name
-r = remove existing associations to the locus category ontology
-t = test, rollback any changes
-c = file of genetic characters (Character,Category,Chromosome,Arm,Description,Values)

This script will associate each T3 genetic character (breedbase locus) with a category 
in the T3 Genetic Character Ontology (as specified in the file of genetic characters).  
Any locus that is NOT a T3 genetic character and has a name that starts with 'TraesCS' 
will be associated with the Ensembl Gene IDs category.  All other loci will be associated 
with the UniProt Proteins category.

NOTE: The T3 Locus Category ontology must be loaded before running this script!

=cut

use strict;

use CXGN::DB::InsertDBH;

use Text::CSV;
use Data::Dumper;
use Getopt::Std;


#### DATABASE VARIABLES ####
my $ONTO_NAME = "t3_locus_ontology";
my $ONTO_UNIPROT_NAME = "UniProt Proteins";
my $ONTO_ENSEMBL_NAME = "Ensembl Gene IDs";
my $SP_PERSON_ID = 604;


our ($opt_H, $opt_D, $opt_c, $opt_r, $opt_t);

getopts('H:D:c:rt');

my $dbhost = $opt_H;
my $dbname = $opt_D;
my $chars_file = $opt_c;
my $remove = $opt_r;
my $test = $opt_t;




# Get DB Handle
my $dbh = CXGN::DB::InsertDBH->new({
    dbhost   => $dbhost,
    dbname   => $dbname
});
$dbh->add_search_path(qw/public phenome /);
print STDERR "Connected to database $dbname on host $dbhost.\n";
my ($q, $sth);



# Get CV ID
$q = "SELECT cv_id FROM public.cv WHERE name = ?;";
$sth = $dbh->prepare($q);
$sth->execute($ONTO_NAME);
my ($CV_ID) = $sth->fetchrow_array();


#### REMOVE EXISTING ASSOCIATIONS ####

if ( $remove ) {
    print STDERR "Removing existing loci/ontology associations...\n";

    $q = "DELETE FROM phenome.locus_dbxref_evidence WHERE locus_dbxref_id IN (
            SELECT locus_dbxref_id FROM phenome.locus_dbxref WHERE dbxref_id IN (
                SELECT dbxref_id FROM cvterm WHERE cv_id = ?
            )
         );";
    $sth = $dbh->prepare($q);
    $sth->execute($CV_ID);

    $q = "DELETE FROM phenome.locus_dbxref WHERE dbxref_id IN (
            SELECT dbxref_id FROM cvterm WHERE cv_id = ?
         );";
    $sth = $dbh->prepare($q);
    $sth->execute($CV_ID);
}


#### ASSOCIATE GENETIC CHARS ####

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



#### ASSOCIATE REMAINING LOCI ####

# Find the loci that are not associated as T3 genetic characters
$q = "SELECT locus_id, locus_name FROM phenome.locus WHERE locus_id NOT IN (
            SELECT DISTINCT locus_id FROM phenome.locus_dbxref WHERE dbxref_id IN (
                SELECT dbxref_id FROM cvterm WHERE cv_id = ?
            )
         );";
$sth = $dbh->prepare($q);
$sth->execute($CV_ID);
my $rows = $sth->fetchall_arrayref();

# Get the category cvterm dbxref_id for uniprot
$q = "SELECT dbxref_id FROM public.cvterm WHERE cv_id = ? AND name = ?;";
$sth = $dbh->prepare($q);
$sth->execute($CV_ID, $ONTO_UNIPROT_NAME);
my ($uniprot_dbxref_id) = $sth->fetchrow_array();

# Get the category cvterm dbxref_id for ensembl
$q = "SELECT dbxref_id FROM public.cvterm WHERE cv_id = ? AND name = ?;";
$sth = $dbh->prepare($q);
$sth->execute($CV_ID, $ONTO_ENSEMBL_NAME);
my ($ensembl_dbxref_id) = $sth->fetchrow_array();

# Associate each locus with the UniProt or Ensembl Category
foreach my $row (@$rows) {
    my $locus_id = $row->[0];
    my $locus_name = $row->[1];
    my $locus_category_id = undef;

    # If the Locus name starts with 'TraesCS' -> Ensemble
    if ( $locus_name =~ m/^TraesCS/ ) {
        $locus_category_id = $ensembl_dbxref_id;
    }
    # All others -> UniProt
    else {
        $locus_category_id = $uniprot_dbxref_id;
    }
    
    # Associate the locus with the proper category
    if ( defined($locus_category_id) ) {
        $q = "INSERT INTO phenome.locus_dbxref (locus_id, dbxref_id, obsolete, sp_person_id) VALUES (?, ?, ?, ?) RETURNING locus_dbxref_id;";
        $sth = $dbh->prepare($q);
        $sth->execute($locus_id, $locus_category_id, 'FALSE', $SP_PERSON_ID);
        my ($locus_dbxref_id) = $sth->fetchrow_array();

        $q = "INSERT INTO phenome.locus_dbxref_evidence (locus_dbxref_id, relationship_type_id, evidence_code_id, sp_person_id, obsolete) SELECT ?, dbxref_id, ?, ?, ? FROM public.dbxref WHERE accession = 'is_a';";
        $sth = $dbh->prepare($q);
        $sth->execute($locus_dbxref_id, $locus_category_id, $SP_PERSON_ID, 'FALSE');

        print STDERR "Added Locus $locus_name to category $locus_category_id...\n";
    }
    else {
        print STDERR "ERROR: Locus $locus_name could not be associated with a category!\n";
    }
}
    


# Rollback or Commit the Changes
if ( $test ) {
    $dbh->rollback();
}
else {
    $dbh->commit();
}
