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



## Load Trait Ontology

Follow the workflow described in [ontology-scripts/WORKFLOW.md](https://github.com/TriticeaeToolbox/ontology-scripts/blob/master/WORKFLOW.md)

  - If the CV `composable_cvtypes` is missing, make sure the DB patch `00073` has been run.