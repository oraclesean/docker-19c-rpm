export ORACLE_SID=${ORACLE_SID^^} # Make uppercase
export ORACLE_PDB=${ORACLE_PDB^^} # Make uppercase

########### SIGINT handler ############
function _int() {
   echo "Stopping container."
   echo "SIGINT received, shutting down database!"
   sudo $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/$INIT_FILE stop
}

########### SIGTERM handler ############
function _term() {
   echo "Stopping container."
   echo "SIGTERM received, shutting down database!"
   sudo $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/$INIT_FILE stop
}

########### SIGKILL handler ############
function _kill() {
   echo "SIGKILL received, shutting down database!"
   sudo $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/$INIT_FILE stop
}

# Set SIGINT handler
trap _int SIGINT

# Set SIGTERM handler
trap _term SIGTERM

# Set SIGKILL handler
trap _kill SIGKILL

# Verify the configuration directory exists:
  if [ ! -d $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID ]
then mkdir -p $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/
fi

# Verify the INIT file exists:
  if [ ! -f $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/$INIT_FILE ]
then cp /etc/init.d/$INIT_FILE $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/
fi

# Verify the CONFIG file exists:
  if [ ! -f $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/$CONFIG_FILE ]
then cp /etc/sysconfig/$CONFIG_FILE $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/
fi

# Start the database; if the database isn't configured, run the configuration:
config_check=$(sudo $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/$INIT_FILE start)
  if [[ $config_check =~ "The Oracle Database is not configured" ]]
then $ORACLE_BASE/$SETUP_DB
fi

# Check whether database is up and running
$ORACLE_BASE/$CHECK_DB_STATUS
  if [ $? -eq 0 ]
then echo "#########################"
     echo "DATABASE IS READY TO USE!"
     echo "#########################"
fi;

# Tail on alert log and wait (otherwise container will exit)
echo "The following output is now a tail of the alert.log:"
tail -f $ORACLE_BASE/diag/rdbms/*/*/trace/alert*.log &
childPID=$!
wait $childPID
