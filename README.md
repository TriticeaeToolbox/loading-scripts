
breeDBase loading scripts
=============

This repository contains general notes and scripts for loading data into T3 breeDBase instances. 

## Instance Setup

#### Docker Setup

1) Clone **SGN** and **instance** repositories for new instance

```bash
cd /opt/breedbase/repos

# Clone the repos
git clone git@github.com:TriticeaeToolbox/sgn ./sgn_avena
git clone git@github.com:TriticeaeToolbox/avena ./avena

# Switch to the SGN t3/master branch
cd sgn_avena
git checkout t3/master
```

2) Create instance config file and modify contents

```bash
cp /opt/breedbase/config/triticum.conf /opt/breedbase/config/avena.conf
```

  - Set `dbname` = `cxgn_avena`
  - Update path names `s/triticum/avena/g`
  - Set `main_production_site_url` = `https://oat.triticeaetoolbox.org`
  - Update ontology variables `onto_root_namespaces`, `trait_cv_name`, `trait_variable_onto_root_namespace`

3) Create docker mount points

```bash
cd /opt/breedbase/mnt
mkdir avena
mkdir avena/archive avena/prod avena/public
```

4) Add instance to `/opt/breedbase/bin/breedbase` script
    
  - Set instance-specific paths and variables

5) Setup NGINX configuration

```bash
cp /etc/nginx/sites-available/wheat /etc/nginx/sites-available/avena
ln -s /etc/nginx/sites-available/avena /etc/nginx/sites-enabled/avena
```

  - Set `server_name` = `https://oat.triticeaetoolbox.org`
  - Modify http redirect `return` URL
  - Modify port in `proxy_pass`
  - Remove `ssl_certificate` and `ssl_certificate_key` directives (added by `certbot`)

```bash
# Get SSL certificates via certbot and Let's Encrypt
certbot --nginx
```


#### Database Setup

1) Create database based off of the `breedbase` template

```postgres
CREATE DATABASE cxgn_avena WITH TEMPLATE breedbase;
```

2) Set permissions for `web_usr`

  - See `/sql/web_usr_grants.sql` for permissions

3) Run Database Patches

```bash
# From avena web docker container
cd /home/production/cxgn/sgn/db
export PERL_USE_UNSAFE_INC=1 # Allow the current directory in INC
./run_all_patches.pl -u postgres -p "postgres_pass" -e admin -h breedbase_db -d cxgn_avena
```


#### Web Instance Setup

**If the node JS modules don't install properly:**

Example: if there is a permission error during the build process when performing a `git clone`

1) Install NodeJS on the docker host machine, if not already
   The web docker container currently has node version 10 installed

```bash
# From the docker host
curl -sL https://deb.nodesource.com/setup_10.x | bash -
apt-get install nodejs
```

2) Install the node packages from the docker host machine
   These will get mounted to the SGN repo via Docker

```bash
# From the docker host, DO NOT RUN AS ROOT
cd {BB_HOME}/repos/{SGN_REPO}/js
rm -rf node_modules
npm cache clean -f
npm install
```

3) Restart the web container



## Load Trait Ontology

Follow the workflow described in [ontology-scripts/WORKFLOW.md](https://github.com/TriticeaeToolbox/ontology-scripts/blob/master/WORKFLOW.md)

  - If the CV `composable_cvtypes` is missing, make sure the DB patch `00073` has been run.


## Load Breeding Programs

There are two perl scripts to aid the bulk loading of breeding programs.

The first `./bin/breeding_programs/add_breeding_program.pl` script can be used to add a single Breeding Program 
to the specified database with a specified name and description.

```bash
# Add a single breeding program to the database
./bin/breeding_programs/add_breeding_program.pl -H localhost -D cxgn_avena -U postgres -P postgrespass -n "Test Breeding Program" -d "This is a Breeding Program used for testing"
```

The second `./bin/breeding_programs/add_breeding_programs_bulk.pl` script can be used to parse a CSV file containing 
Breeding Program information (designed to use the T3 contributing data programs table).  Each row of a breeding 
program's information will added to the database if the name does not yet exist.

Example CSV file:
```bash
# From ./data/breeding_programs/oat_breeding_programs.csv
Breeding Program,Code,Collaborator,Description,Institution
"AAES, Auburn University",AUB,Kathryn Glass,"Alabama Agricultural Experiment Station (AAES), Auburn University, AL-USA.",Auburn University
AAFC Agassiz,ABC,,"Agriculture and Agri-Food Canada (AAFC) Pacific Agri-Food Research Centre (PARC) in Agassiz, BC-CAN.",Agriculture and Agri-Food Canada
AAFC Brandon,MTB,Jennifer W. Mitchell-Fetch,"Agriculture and Agri-Food Canada (AAFC) Brandon Research Centre, MB-CAN.",Agriculture and Agri-Food Canada
```

```bash
# Parse a CSV file of breeding program information
./bin/breeding_programs/add_breeding_programs_bulk.pl -H localhost -D cxgn_avena -U postgres -P postgrespass -d ./data/breeding_programs/oat_breeding_programs.csv
```


## Load Accessions

Accessions can be bulk loaded using an Excel template through the web site (Manage > Accessions).  

The [breedbase R package](https://github.com/TriticeaeToolbox/breeDBase.R) has helper functions to help create 
a breedbase accession template.  The R script `./bin/accessions/add_accessions.R` contains the `createAccessions()` 
function which will read the T3 line information file and create a list of Accessions.  These Accessions can be 
passed to the `breedbase::writeAccessionTemplate()` function to create the breedbase accession template file(s).

```R
# Create Accessions from the T3 line information file
a <- createAccessions(lines="./data/accessions/oat_line_records.csv", programs="./data/breeding programs/oat_breeding_programs.csv", genus="Avena")
# Create a breedbase acccession template table
t <- buildAccessionTemplate(a)
# Write the breedbase accession template table to files
writeAccessionTemplate(t, output="./templates/accessions/oat_accessions.xls", chunk=6000)
```

Once created, the accession template file(s) can be uploaded to the breedbase website.


### Pedigrees

Pedigrees can be stored in two different ways:

  1) The **official Breedbase way** is to assign two parents to each Accession entry.  Each of the parents, in turn, need to be Accession entries themselves.  This method allows the interactive pedigree viewer to work.

  2) The **simplified T3 way** is to add a Purdy pedigree string as the pedigree property of the Accession.  The pedigree property is not parsed by the database and is displayed on the Stock detail page.  This method allows a user to search for Accessions on the text of the pedigree string.

**Add Pedigrees the Breedbase way:**

A pedigree file (a spreadsheet containing a table of Accessions and their parent names) can be uploaded through the website from the **Manage > Accessions** page.  The breedbase R package has helper functions to help create the spreadsheet template.

**Add Pedigrees the T3 way:**

Purdy Pedigree strings no longer have to be added to the database separately.  The T3 breedbase instances support 
the Accession properties of `purdy_pedigree` and `filial_generation` and can be added as an Accession property 
directly from the Accession upload template.  The breedbase R package has helper functions to help create the Accession 
upload template.

~~First, the pedigree stock property needs to be added to the database.  The `add_stockprop_term.pl` perl script can be used:~~

```bash
perl ./bin/accessions/add_stockprop_term.pl -H localhost -D cxgn_avena -n pedigree -d "Purdy pedigree string of an Accession"
```

~~Then, a file (following the T3 bulk line information format):~~

```
# pedigrees.csv
   Name         Species GRIN  Synonym Breeding Program Parent1 Parent2 Pedigree                        Description
 1 02-18228                                                            Pio25R26/ 9634-24437//95-4162
 2 02-194638-1                                                         Patton / Cardinal // 96-2550
 ```

~~can be used to define the pedigrees for each of the Accessions.  The `add_stock_pedigrees.pl` perl script can be used to add the pedigrees as stock properties of the Accessions:~~

```bash
perl ./bin/accessions/add_stock_pedigrees.pl -H localhost -D cxgn_avena -d pedigrees.csv
```

~~Finally, in order for the pedigree property to be displayed on the Stock detail page, the `editable_stock_props` configuration variable (`sgn_local.conf`) needs to have `pedigree` appended to it.~~
