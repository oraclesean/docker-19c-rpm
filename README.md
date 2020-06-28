# Oracle 19c RPM-based installation on Docker
This installs Oracle 19c using the RPM-based installation method on a Docker container.
# Preparation
Create a directory on your host and pull this repository.

Additionally, download the following files:
Go to: https://www.oracle.com/database/technologies/oracle19c-linux-downloads.html
Download the 19c Linux x86-64 RPM: `oracle-database-ee-19c-1.0-1.x86_64.rpm`

From Oracle Metalink/My Oracle Support:
* The latest OPatch installer: `p6880880_190000_Linux-x86-64.zip`
* The latest RU patch (19.7): `p30869156_190000_Linux-x86-64.zip`

To install a different RU (e.g. 19.6) change the following lines in the `Dockerfile`:
```
ARG DBRU=p30869156_190000_Linux-x86-64.zip
ARG DBRU_ID=30869156
```

# Installation
## Build the image
```
docker build --force-rm=true --no-cache=true -t /oracle/databaseoracle:19.7.0-ee-rpm .
```
## Remove artifacts
```
docker rmi $(docker images -f "dangling=true" -q)
```
# Run a container
## Default values
This creates a 19.7.0 database with SID=ORCLCDB and one pluggable database, ORCLPDB1.
```
docker run -d --name <FRIENDLY_CONTAINER_NAME> /oracle/databaseoracle:19.7.0-ee-rpm
```
## Customizing container creation
Parameters passed to the `docker run` command will customize the database environment. Available options:
* ORACLE_SID - COntainer database name [ORCLCDB]
* ORACLE_PDB - Pluggable database name/prefix [ORCLPDB]
* PDB_COUNT - Number of pluggable databases; this value is appended to the ORACLE_PDB name when the count > 1 [1]
* ORACLE_PWD - The password for privileged Oracle database accounts [Randomly generated]
* ORACLE_CHARACTERSET - The characterset [AL32UTF8]

## Example
```
docker run -d --name 19c \
       -e ORACLE_SID=lab19c \
       -e ORACLE_PDB=labpdb \
       -e PDB_COUNT=2 \
       -v ~/oradata/rpmlab:/opt/oracle/oradata \
       -p 11521:1521 \
       /oracle/databaseoracle:19.7.0-ee-rpm
```
# Notes
ORACLE_SID and ORACLE_PDB are automatically converted to uppercase during inital database setup.

Startup parameters are set in the `Docker_Database.dbc` template. This file is embedded in the image and all containers will be created with identical values. Edit this file to change the configuration.
