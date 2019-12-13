#! /usr/bin/env perl

=head1 NAME

add_breeding_programs_bulk.pl

=head1 DESCRIPTION

Usage: perl add_breeding_programs_bulk.pl -H dbhost -D dbname -U dbuser -P dbpass -d programs

-H = db host
-D = db name 
-U = db user
-P = db pass
-d = CSV file of T3 breeding programs (Breeding Program,Code,Collaborator,Description,Institution)

This script will load the Breeding Programs found in the programs CSV file.  It will ignore a breeding 
program if one with the same name already exists in the database.

=cut

use strict;

use Getopt::Std;
use File::Basename;
use Text::CSV;
use Data::Dumper;



# NAME OF ADD BREEDING PROGRAM SCRIPT
my $ADD_BREEDING_PROGRAM_SCRIPT_NAME = "add_breeding_program.pl";


# PARSE CLI ARGS
our ($opt_H, $opt_D, $opt_U, $opt_P, $opt_d);

getopts('H:D:U:P:d:');

my $dbhost = $opt_H;
my $dbname = $opt_D;
my $dbuser = $opt_U;
my $dbpass = $opt_P;
my $programs_file = $opt_d;




# READ CSV FILE
my $csv = Text::CSV->new({ sep_char => ',' });
open(my $data, '<', $programs_file) or die "Could not open breeding programs file '$programs_file': $!\n";

# Loop through the breeding programs
while ( my $line = <$data> ) {
    chomp $line;
    next if ($. == 1); # skip header line
    if ( $csv->parse($line) ) {
        my @fields = $csv->fields();
        my $name = $fields[0];
        my $desc = $fields[3];
        my $inst = $fields[4];
        my $coll = $fields[2];
        if ( $inst ne "" ) {
            $desc = $desc . " Institution: " . $inst . ".";
        }
        if ( $coll ne "" ) {
            $desc = $desc . " Collaborator: " . $coll . ".";
        }

        # Build command for adding the breeding program
        my $cmd = dirname(__FILE__) . "/" . $ADD_BREEDING_PROGRAM_SCRIPT_NAME;
        $cmd = "$cmd -H $dbhost -D $dbname -U $dbuser -P $dbpass -n \"$name\" -d \"$desc\"";

        # Run system command
        system($cmd);
    }
    else {
        print STDERR "ERROR: Could not parse line: $line\n";
    }
}