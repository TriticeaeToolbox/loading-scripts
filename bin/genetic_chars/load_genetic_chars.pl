#! /usr/bin/perl

=head1 NAME

load_genetic_chars.pl

=head1 DESCRIPTION

Usage: perl load_genetic_chars.pl -H dbhost -D dbname [-t] -c chars -d values

-H = db host
-D = db name
-t = test, rollback any changes
-c = file of genetic characters (Character,Category,Chromosome,Arm,Description,Values)
-d = file of lines and allele values (Accession,Character,Value)

This script will load the file of T3 genetic characters.  Each character will be 
created as a Locus and each potential genetic character value will be loaded as 
an Allele for that Locus.

In addition, the script  will take the file of T3 lines and genetic character 
values and associate the value as an Allele for each Accession.

WARNING:  This will clear existing loci and alleles from the database!

=cut

use strict;

use CXGN::DB::InsertDBH;
use CXGN::Phenome::Locus;
use CXGN::Phenome::LocusSynonym;

use Text::CSV;

use Data::Dumper;

use Getopt::Std;


#### CHANGE THESE: ####
my $organism_common_name = 'Wheat';
my @chromosome_numbers = (1, 2, 3, 4, 5, 6, 7);
my @chromosome_genomes = ("A", "B", "D");
my @chromosome_arms = ("short", "long");
my $sp_person_id = 604;


our ($opt_H, $opt_D, $opt_c, $opt_d, $opt_t);

getopts('H:D:c:d:t');

my $dbhost = $opt_H;
my $dbname = $opt_D;
my $chars_file = $opt_c;
my $values_file = $opt_d;
my $test = $opt_t;




# Get DB Handle
my $dbh = CXGN::DB::InsertDBH->new({
    dbhost   => $dbhost,
    dbname   => $dbname
});
$dbh->add_search_path(qw/public phenome /);
print STDERR "Connected to database $dbname on host $dbhost.\n";
my ($q, $sth);


#### DATABASE FIXES ####

# Clear existing alleles and loci
$q = "DELETE FROM phenome.stock_allele;";
$sth = $dbh->prepare($q);
$sth->execute();
print STDERR "Removed stock / allele associations\n";

$q = "DELETE FROM phenome.allele;";
$sth = $dbh->prepare($q);
$sth->execute();
print STDERR "Removed alleles\n";

$q = "DELETE FROM phenome.locus_alias;";
$sth = $dbh->prepare($q);
$sth->execute();
print STDERR "Removed loci aliases\n";

$q = "DELETE FROM phenome.locus_dbxref_evidence;";
$sth = $dbh->prepare($q);
$sth->execute();
print STDERR "Removed locus dbxref evidence\n";

$q = "DELETE FROM phenome.locus_dbxref;";
$sth = $dbh->prepare($q);
$sth->execute();
print STDERR "Removed locus dbxrefs\n";

$q = "DELETE FROM phenome.locus;";
$sth = $dbh->prepare($q);
$sth->execute();
print STDERR "Removed loci\n";

# Update Common Name
$q = "UPDATE sgn.common_name SET common_name = ? WHERE common_name_id = 1;";
$sth = $dbh->prepare($q);
$sth->execute($organism_common_name);
print STDERR "Updated common name: $organism_common_name\n";


# # Add missing CV Term
# $q = "INSERT INTO public.cv (name) VALUES ('sgn') RETURNING cv_id;";
# $sth = $dbh->prepare($q);
# $sth->execute();
# my ($cv_id)= $sth->fetchrow_array();

# $q = "INSERT INTO public.dbxref (db_id, accession) SELECT db_id, 'sgn:allele_id' FROM public.db WHERE name = 'null' RETURNING dbxref_id;";
# $sth = $dbh->prepare($q);
# $sth->execute();
# my ($dbxref_id) = $sth->fetchrow_array();

# $q = "INSERT INTO public.cvterm (cv_id, name, definition, dbxref_id) VALUES (?, 'sgn allele_id', 'The association between a stock and an allele', ?) RETURNING cvterm_id;";
# $sth = $dbh->prepare($q);
# $sth->execute($cv_id, $dbxref_id);
# my ($cvterm_id) = $sth->fetchrow_array();

# print STDERR "Added CV: $cv_id, DBXREF: $dbxref_id, CVTERM: $cvterm_id\n";



#### ADD CHROMOSOMES AND ARMS ####

# Remove existing chromosomes
$q = "DELETE FROM sgn.common_nameprop WHERE type_id = (SELECT cvterm_id FROM public.cvterm WHERE name = 'linkage_group');";
$sth = $dbh->prepare($q);
$sth->execute();
print STDERR "Removed chromosomes\n";

# Add new chromosomes
foreach my $chromosome_number ( @chromosome_numbers ) {
    foreach my $chromosome_genome ( @chromosome_genomes ) {
        my $chromosome = '' . $chromosome_number . $chromosome_genome;
        
        $q = "INSERT INTO sgn.common_nameprop (common_name_id, type_id, value) SELECT 1, cvterm_id, ? FROM public.cvterm WHERE name = 'linkage_group';";
        $sth = $dbh->prepare($q);
        $sth->execute($chromosome);

        print STDERR "Added chromosome: $chromosome\n";
    }
}

# Remove existing chromosome arms
$q = "DELETE FROM sgn.common_nameprop WHERE type_id = (SELECT cvterm_id FROM public.cvterm WHERE name = 'chromosome_arm');";
$sth = $dbh->prepare($q);
$sth->execute();
print STDERR "Removed chromosome arms\n";

# Add new chromosome arms
foreach my $chromosome_arm ( @chromosome_arms ) {
    $q = "INSERT INTO sgn.common_nameprop (common_name_id, type_id, value) SELECT 1, cvterm_id, ? FROM public.cvterm WHERE name = 'chromosome_arm';";
    $sth = $dbh->prepare($q);
    $sth->execute($chromosome_arm);

    print STDERR "Added chromosome arm: $chromosome_arm\n";
}


#### ADD LOCI / GENETIC CHARACTERS ####

# Create a metadata entry
$q = "INSERT INTO metadata.md_metadata (create_person_id, modification_note) VALUES (?, ?) RETURNING metadata_id;";
$sth = $dbh->prepare($q);
$sth->execute($sp_person_id, 'Bulk addition of genetic characters and associated accessions.');
my ($metadata_id) = $sth->fetchrow_array();

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
        my $locus_symbol = uc $fields[0];
        $locus_symbol =~ s/[^a-zA-Z0-9]+//g;
        my $chromosome = $fields[2];
        my $arm = $fields[3];
        my $locus_description = $fields[4];
        my @values = split(',', $fields[5]);

        $q = "INSERT INTO phenome.locus (locus_name, locus_symbol, description, linkage_group, lg_arm, common_name_id) VALUES (?, ?, ?, ?, ?, ?) RETURNING locus_id;";
        $sth = $dbh->prepare($q);
        $sth->execute($locus_name, $locus_symbol, $locus_description, $chromosome, $arm, 1);
        my ($locus_id) = $sth->fetchrow_array();

        $q = "INSERT INTO phenome.locus_alias (alias, locus_id) VALUES (?, ?);";
        $sth = $dbh->prepare($q);
        $sth->execute($locus_symbol, $locus_id);

        $q = "INSERT INTO phenome.locus_owner (locus_id, sp_person_id) VALUES (?, ?);";
        $sth = $dbh->prepare($q);
        $sth->execute($locus_id, $sp_person_id);

        print STDERR "Added Locus #$locus_id: $locus_name, $locus_symbol, $chromosome $arm\n";


        #### ADD ALLELES FOR LOCUS ####
        foreach my $value ( @values ) {
            my $allele_symbol = $locus_symbol . '_' . uc $value;
            my $allele_name = $value;

            if ($value) {
                if ( $locus_name eq 'Growth habit' ) {
                    if ( $value eq 'S' ) {
                        $allele_name = 'Spring';
                    }
                    elsif ( $value eq 'W' ) {
                        $allele_name = "Winter";
                    }
                    elsif ( $value eq 'F' ) {
                        $allele_name = "Faculative";
                    }
                }
                elsif ( $locus_name eq 'Awned' ) {
                    if ( $value eq 'A' ) {
                        $allele_name = "Awned";
                    }
                    elsif ( $value eq 'N' ) {
                        $allele_name = "Awnless";
                    }
                }
                elsif ( $locus_name eq 'Color' ) {
                    if ( $value eq 'R' ) {
                        $allele_name = "Red";
                    }
                    elsif ( $value eq 'W' ) {
                        $allele_name = "White";
                    }
                }
                elsif ( $locus_name eq 'Hardness' ) {
                    if ( $value eq 'H' ) {
                        $allele_name = "Hard";
                    }
                    elsif ( $value eq 'S' ) {
                        $allele_name = "Soft";
                    }
                }
                elsif ( $value eq 'P' ) {
                    $allele_name = "Present";
                }
                elsif ( $value eq 'A' ) {
                    $allele_name = "Absent";
                }
                elsif ( $value eq 'H' ) {
                    $allele_name = "Heterozygous";
                }
            }

            # Add Allele
            $q = "INSERT INTO phenome.allele (locus_id, allele_symbol, allele_name, sp_person_id, is_default) VALUES (?, ?, ?, ?, ?) RETURNING allele_id;";
            $sth = $dbh->prepare($q);
            $sth->execute($locus_id, $allele_symbol, $allele_name, $sp_person_id, 0);
            my ($allele_id) = $sth->fetchrow_array();

            print STDERR "Added Allele $value: $allele_name, $allele_symbol\n";


            #### ADD ASSOCIATED ACCESSIONS ####

            # Loop through accession list
            open(my $data2, '<', $values_file) or die "Could not open values file '$values_file': $!\n";
            while ( my $line2 = <$data2> ) {
                next if ($. == 1); # skip header line

                my @fields2 = split(',', $line2);
                my $accession_name = $fields2[0];
                my $character_name = $fields2[1];
                my $character_value = $fields2[2];
                $character_value =~ s/\R*//g;

                # GC name and value match locus name and allele value
                if ( $character_name eq $locus_name ) {
                    if ( $character_value eq $value) {
                        
                        # Get Stock ID
                        $q = "SELECT stock_id FROM public.stock WHERE name = ?;";
                        $sth = $dbh->prepare($q);
                        $sth->execute($accession_name);
                        my ($stock_id) = $sth->fetchrow_array();

                        if ( $stock_id ) {

                            # Set rank for stocks with already associated alleles
                            my $rank = $allele_id;

                            # Add Accession Association
                            $q = "INSERT INTO public.stockprop (stock_id, type_id, value, rank) SELECT ?, cvterm_id, ?, ? FROM public.cvterm WHERE name = 'sgn allele_id';";
                            $sth = $dbh->prepare($q);
                            $sth->execute($stock_id, $allele_id, $rank);

                            $q = "INSERT INTO phenome.stock_allele (stock_id, allele_id, metadata_id) VALUES (?, ?, ?);";
                            $sth = $dbh->prepare($q);
                            $sth->execute($stock_id, $allele_id, $metadata_id);

                            print STDERR "Added Stock/Allele Association ($rank): Accession $accession_name / $stock_id and Allele $allele_name / $allele_id\n";
                            
                        }

                        # Stock ID Not Found
                        else {
                            print STDERR "WARNING: Stock ID not found for accession $accession_name!\n";
                        }

                    }
                }
            }


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
