FROM oraclelinux:7-slim as base
MAINTAINER Sean Scott <sean.scott@viscosityna.com>

# Set ARGs, keep the environment clean
ARG ORACLE_BASE=/opt/oracle
ARG ORACLE_HOME=/opt/oracle/product/19c/dbhome_1
ARG INSTALL_DIR=/opt/install
ARG ORACLE_SID=ORCLCDB

# ORACLE_DOCKER_INSTALL=true is required for the 19c RPM on Docker
ENV ORACLE_BASE=$ORACLE_BASE \
    ORACLE_HOME=$ORACLE_HOME \
    ORACLE_SID=$ORACLE_SID \
    ORACLE_VERSION=19c \
    PDB_NAME=ORCLPDB \
    PDB_COUNT=1 \
    ORACLE_DOCKER_INSTALL=true \
    SQLPATH=/home/oracle \
    SETUP_DB=setupDB.sh \
    RUN_FILE=runOracle.sh \
    CONFIG_FILE=oracledb_ORCLCDB-19c.conf \
    INIT_FILE=oracledb_ORCLCDB-19c \
    CHECK_DB_STATUS=checkDBStatus.sh

ENV PATH=$ORACLE_HOME/bin:$ORACLE_HOME/OPatch/:/usr/sbin:$PATH \
    CLASSPATH=$ORACLE_HOME/jlib:$ORACLE_HOME/rdbms/jlib \
    LD_LIBRARY_PATH=$ORACLE_HOME/lib:/usr/lib \
    TNS_ADMIN=$ORACLE_HOME/network/admin

COPY $CHECK_DB_STATUS $SETUP_DB $RUN_FILE $ORACLE_BASE/

# Build base image with 19c preinstall and Things I Like To Have (epel, git, less, rlwrap, strace, vi), all optional.
# file-5.11, openssl, sudo are necessary (file-5.11 = prereq for 19c RPM, sudo for startup via init.d)
RUN yum -y update; yum -y install oracle-database-preinstall-19c oracle-epel-release-el7 file-5.11-36.el7.x86_64 git less openssl strace sudo vi which && \
    # Create directories, replace OPatch, own things, permissions
    mkdir -p {$INSTALL_DIR,$ORACLE_HOME,$ORACLE_BASE/{scripts/{setup,startup},oradata/dbconfig/$ORACLE_SID}} && \
    chown -R oracle:oinstall $ORACLE_BASE $INSTALL_DIR && \
    chmod ug+x $ORACLE_BASE/*.sh && \
    sync && \
    yum -y install rlwrap && \
    # Create the entrypoint:
    ln -s $ORACLE_BASE/scripts /docker-entrypoint-initdb.d && \
    # Manage the oracle user:
    echo oracle:oracle | chpasswd && \
    # Let oracle run rpm config:
    echo "oracle ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/oracle && \
    chmod 0440 /etc/sudoers.d/oracle && \
    yum clean all && \
    rm -fr $INSTALL_DIR /tmp/* /var/cache/yum

FROM base as builder

ARG DBRPM=oracle-database-ee-19c-1.0-1.x86_64.rpm
ARG DBRU=p30869156_190000_Linux-x86-64.zip
ARG DBRU_ID=30869156
ARG OPATCH=p6880880_190000_Linux-x86-64.zip
ARG INSTALL_DIR=/opt/install

COPY --chown=oracle:oinstall $DBRPM $DBRU $OPATCH $INSTALL_DIR/

USER root
RUN yum -y localinstall $INSTALL_DIR/oracle-database-ee-19c-1.0-1.x86_64.rpm && \
    # Make the config file editable by oracle:
    chown root:oinstall /etc/sysconfig/$CONFIG_FILE /etc/init.d/$INIT_FILE && \
    chmod 664 /etc/sysconfig/$CONFIG_FILE

USER oracle
RUN unzip -oq -d $ORACLE_HOME $INSTALL_DIR/$OPATCH && \
    unzip -oq -d $INSTALL_DIR $INSTALL_DIR/$DBRU && \
    # Apply the RU
    $ORACLE_HOME/OPatch/opatch apply -silent $INSTALL_DIR/$DBRU_ID && \
    rm -fr $INSTALL_DIR/*

FROM base

ENV ORACLE_BASE=$ORACLE_BASE \
    ORACLE_HOME=$ORACLE_HOME \
    ORACLE_SID=$ORACLE_SID \
    ORACLE_VERSION=19c \
    PDB_NAME=ORCLPDB \
    PDB_COUNT=1 \
    ORACLE_DOCKER_INSTALL=true \
    INSTALL_TMP=Docker_Database.dbc \
    SETUP_DB=setupDB.sh \
    RUN_FILE=runOracle.sh \
    CONFIG_FILE=oracledb_ORCLCDB-19c.conf \
    INIT_FILE=oracledb_ORCLCDB-19c \
    CHECK_DB_STATUS=checkDBStatus.sh

ENV PATH=$ORACLE_HOME/bin:$ORACLE_HOME/OPatch/:/usr/sbin:$PATH \
    CLASSPATH=$ORACLE_HOME/jlib:$ORACLE_HOME/rdbms/jlib \
    LD_LIBRARY_PATH=$ORACLE_HOME/lib:/usr/lib \
    TNS_ADMIN=$ORACLE_HOME/network/admin

USER oracle
COPY --chown=oracle:oinstall --from=builder $ORACLE_BASE $ORACLE_BASE
COPY --from=builder /etc /etc
COPY --chown=oracle:oinstall $INSTALL_TMP $ORACLE_HOME/assistants/dbca/templates/

WORKDIR /home/oracle

VOLUME ["$ORACLE_BASE/oradata"]
EXPOSE 1521 5500
HEALTHCHECK --interval=1m --start-period=5m \
   CMD "$ORACLE_BASE/$CHECK_DB_STATUS" >/dev/null || exit 1

# Define default command to start Oracle Database.
CMD exec $ORACLE_BASE/$RUN_FILE
