# Set defaults if not passed:
export ORACLE_BASE=${ORACLE_BASE:-/opt/oracle}
export ORACLE_SID=${ORACLE_SID:-ORCLCDB}
export ORACLE_SID=${ORACLE_SID^^} # Make uppercase
export ORACLE_PDB=${ORACLE_PDB:-ORCLPDB}
export ORACLE_PDB=${ORACLE_PDB^^} # Make uppercase
export PDB_COUNT=${PDB_COUNT:-1}
export ORACLE_PWD=${ORACLE_PWD:-"`openssl rand -base64 8`1"}
echo "ORACLE PASSWORD FOR SYS, SYSTEM AND PDBADMIN: $ORACLE_PWD";
export ORACLE_CHARACTERSET=${ORACLE_CHARACTERSET:-AL32UTF8}
export ORACLE_NLS_CHARACTERSET=${ORACLE_NLS_CHARACTERSET:-UTF8}

# Update the configuration:
sed -i -e "s|export ORACLE_SID=ORCLCDB|export ORACLE_SID=$ORACLE_SID|g" \
       -e "s|General_Purpose.dbc|$INSTALL_TMP|g" \
       -e "s|export CHARSET=AL32UTF8|export CHARSET=$ORACLE_CHARACTERSET|g" \
       -e "s|export PDB_NAME=ORCLPDB1|export PDB_NAME=$ORACLE_PDB|g" \
       -e "s|export NUMBER_OF_PDBS=1|export NUMBER_OF_PDBS=$PDB_COUNT|g" \
       -e "s|oracledb_\$ORACLE_SID-\$ORACLE_VERSION.conf|$CONFIG_FILE|g" \
       -e "s|/etc/sysconfig/\$CONFIG_NAME|$ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/$CONFIG_FILE|g" $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/$INIT_FILE

# Run configuration:
sudo $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/$INIT_FILE configure

# Create the base entry for TNS:
cat << EOF > $ORACLE_HOME/network/admin/tnsnames.ora
$ORACLE_SID =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = 0.0.0.0)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = $ORACLE_SID)
    )
  )

LISTENER_$ORACLE_SID =
  (ADDRESS = (PROTOCOL = TCP)(HOST = 0.0.0.0)(PORT = 1521))
EOF

# Add TNS entries for each PDB:
PDB_COUNT=${PDB_COUNT:-1}

for ((PDB_NUM=1; PDB_NUM<=PDB_COUNT; PDB_NUM++))
do
cat << EOF >> $ORACLE_HOME/network/admin/tnsnames.ora

${ORACLE_PDB}${PDB_NUM} =
(DESCRIPTION = 
  (ADDRESS = (PROTOCOL = TCP)(HOST = 0.0.0.0)(PORT = 1521))
  (CONNECT_DATA =
    (SERVER = DEDICATED)
    (SERVICE_NAME = ${ORACLE_PDB}${PDB_NUM})
  )
)
EOF
done

# Stop the listener, correct the host, start:
$ORACLE_HOME/bin/lsnrctl stop
sed -i -re "s|\(HOST = [a-zA-Z0-9]{1,}\)|(HOST = 0.0.0.0)|g" $TNS_ADMIN/listener.ora
$ORACLE_HOME/bin/lsnrctl start

# Move Oracle configuration files to $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID:
mv $ORACLE_HOME/dbs/spfile$ORACLE_SID.ora $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/
ln -s $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/spfile$ORACLE_SID.ora $ORACLE_HOME/dbs/spfile$ORACLE_SID.ora

mv $ORACLE_HOME/dbs/orapw$ORACLE_SID $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/
ln -s $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/orapw$ORACLE_SID $ORACLE_HOME/dbs/orapw$ORACLE_SID

mv $ORACLE_HOME/network/admin/sqlnet.ora $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/
ln -s $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/sqlnet.ora $ORACLE_HOME/network/admin/sqlnet.ora

mv $ORACLE_HOME/network/admin/listener.ora $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/
ln -s $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/listener.ora $ORACLE_HOME/network/admin/listener.ora

mv $ORACLE_HOME/network/admin/tnsnames.ora $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/
ln -s $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/tnsnames.ora $ORACLE_HOME/network/admin/tnsnames.ora

cp /etc/oratab $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/

# Add aliases
cat << EOF >> $HOME/.bashrc

export ORACLE_SID=${ORACLE_SID^^}
export ORACLE_PDB=${ORACLE_PDB^^}

alias sqlplus="rlwrap \$ORACLE_HOME/bin/sqlplus"
alias rman="rlwrap \$ORACLE_HOME/bin/rman"
alias startdb="sudo $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/$INIT_FILE start"
alias stopdb="sudo $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/$INIT_FILE stop"
EOF

# Fix display
echo "set pages 9999 lines 200" > /home/oracle/login.sql

# Fix the pluggable databases
$ORACLE_HOME/bin/sqlplus -S / as sysdba << EOF
alter pluggable database all open;
alter pluggable database all save state;
alter system register;
EOF
