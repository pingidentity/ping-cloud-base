# CDDL HEADER START
#
# The contents of this file are subject to the terms of the
# Common Development and Distribution License, Version 1.0 only
# (the "License").  You may not use this file except in compliance
# with the License.
#
# You can obtain a copy of the license at
# trunk/unboundid/resource/legal-notices/cddl.txt
# or http://www.opensource.org/licenses/cddl1.php.
# See the License for the specific language governing permissions
# and limitations under the License.
#
# When distributing Covered Code, include this CDDL HEADER in each
# file and include the License file at
# trunk/unboundid/resource/legal-notices/cddl.txt.  If applicable,
# add the following below this CDDL HEADER, with the fields enclosed
# by brackets "[]" replaced with your own identifying information:
#      Portions Copyright [yyyy] [name of copyright owner]
#
# CDDL HEADER END
#
#      Portions Copyright 2007-2020 Ping Identity Corporation
#      Portions Copyright 2006-2008 Sun Microsystems, Inc.

# This is the unified starting script for each server type. It's invoked by
# the bin/start-* script on Linux and Unix systems.

# Capture the current working directory so that we can change to it later.
# Then capture the location of this script and the server instance
# root so that we can use them to create appropriate paths.
WORKING_DIR=`pwd`

cd "`dirname "${0}"`"
SCRIPT_DIR=`pwd`

cd ..
INSTANCE_ROOT=`pwd`
export INSTANCE_ROOT

# For the IBM JRE on AIX and Linux, setting IBM_JAVACOREDIR ensures any stack trace
# files are available in a predictable location for collect-support-data
#
IBM_JAVACOREDIR=${INSTANCE_ROOT}/bin
export IBM_JAVACOREDIR

# Since the server may be distributed without the JE jar file, make sure that
# it exists before continuing.  If it cannot be found, then instruct the user
# to download and install it.  Note that since the file name may vary, then
# we have to use a slightly awkward way of checking to see if it's there.
if test -f "${INSTANCE_ROOT}/lib/_require-je.sh"
then
  . "${INSTANCE_ROOT}/lib/_require-je.sh"
  if test ${MISSING_JE} -eq 1
  then
    exit 1
  fi
fi

cd "${WORKING_DIR}"

# Specify the locations of important files that may be used when the server
# is starting.
CONFIG_FILE=${INSTANCE_ROOT}/config/config.ldif
PID_FILE=${INSTANCE_ROOT}/logs/server.pid
LOG_FILE=${INSTANCE_ROOT}/logs/server.out
PREVIOUS_LOG_FILE=${INSTANCE_ROOT}/logs/server.out.previous
STARTING_FILE=${INSTANCE_ROOT}/logs/server.starting


# Check for NewRelic License Key (used by NewRelic Agent to push data)
if [ ${NEW_RELIC_LICENSE_KEY} != 'unused' ]; then
    if [ -z ${JAVA_AGENT_OPTS} ]; then
        JAVA_AGENT_OPTS="-javaagent:/opt/staging/newrelic.jar -Dnewrelic.config.file=${NEW_RELIC_CONFIG_FILE}"
    else
        JAVA_AGENT_OPTS="${JAVA_AGENT_OPTS} -javaagent:/opt/staging/newrelic.jar -Dnewrelic.config.file=${NEW_RELIC_CONFIG_FILE}"
    fi
fi

# Checks if there are any files matching pattern gc.log.[0-9]*
# If there are no such files the if fails. The if is necessary to be able to
# store the output of the search in a variable while also not having to output
# to the console if the search finds nothing.
if ls ${INSTANCE_ROOT}/logs/jvm/gc.log.[0-9]* 1> /dev/null 2>&1
then
  GC_LOG_FILE="ls -1t ${INSTANCE_ROOT}/logs/jvm/gc.log.[0-9]* | head -1"
  GC_LOG_FILE=`eval $GC_LOG_FILE`
  PREVIOUS_GC_LOG_FILE=${INSTANCE_ROOT}/logs/jvm/gc.log.atShutdown
fi

# Specify the script name so that it may be provided in command-line usage.
SCRIPT_NAME="start-server.precheck"
export SCRIPT_NAME

# Set java home and args using the start-server.precheck SCRIPT_NAME
# precheck can have JVM arguments that are different from regular ones
SCRIPT_UTIL_CMD=set-java-home-and-args
export SCRIPT_UTIL_CMD
.  "${INSTANCE_ROOT}/lib/_script-util.sh"
RETURN_CODE=$?
if test ${RETURN_CODE} -ne 0
then
  exit ${RETURN_CODE}
fi

SCRIPT_NAME="start-server"
export SCRIPT_NAME

# Set environment variables, classpath and test java using non-precheck name
# Needed for printing the script name in help message correctly
SCRIPT_UTIL_CMD=set-environment-and-test-java
export SCRIPT_UTIL_CMD
.  "${INSTANCE_ROOT}/lib/_script-util.sh"
RETURN_CODE=$?
if test ${RETURN_CODE} -ne 0
then
  exit ${RETURN_CODE}
fi

# See if the provided set of arguments were sufficient for us to be able to
# start the server or perform the requested operation.  An exit code of 99
# means that it should be possible to start the server.  An exit code of 98
# means that the server is already running and we shouldn't try to start it.
# An exit code of anything else means that we're not trying to start the server
# and we can just exit with that exit code.
${PRIVATE_UNBOUNDID_JAVA_BIN} ${UNBOUNDID_NOVERIFY_ARG} \
  ${SCRIPT_NAME_ARG} "${UNBOUNDID_INVOKE_CLASS}" \
  --configClass com.unboundid.directory.server.extensions.ConfigFileHandler \
  --configFile "${CONFIG_FILE}" --checkStartability "${@}"
EC=${?}

# Check for help or version exit
if test ${EC} -eq 2
then
  exit 0
fi

# Set environment variables
SCRIPT_UTIL_CMD=set-full-environment-and-test-java
export SCRIPT_UTIL_CMD
.  "${INSTANCE_ROOT}/lib/_script-util.sh"
RETURN_CODE=$?
if test ${RETURN_CODE} -ne 0
then
  exit ${RETURN_CODE}
fi

# By default dry run is off and commands have an extra evaluation.
EVAL="eval"

# Dry run is a mostly internal debugging feature.
if test -z "${UNBOUNDID_DRY_RUN}"
then
  # Not a dry run. This is the normal case.
  DRY_RUN=""

  # Start collector helper
  nohup "${INSTANCE_ROOT}/lib/_start-collector-helper.sh" > /dev/null 2>&1 &

  # if we are running an embedded Postgres server, start it
  if [ ! -z "${START_PG}" ] && [ ! -z "${PG_DB_CTRL}" ] && [ -e "${PG_DB_CTRL}" ] ; then
    "${PG_DB_CTRL}" start
    DB_RC=$?
    if [ $DB_RC -ne 0 ] ; then
      echo "FATAL: Unable to start embedded PostgreSQL"
      exit 1
    fi
  fi

  # Backup the log files before starting the server.
  if test -f "${LOG_FILE}"
  then
    mv -f "${LOG_FILE}" "${PREVIOUS_LOG_FILE}"
  fi

  if test -f "${GC_LOG_FILE}"
  then
    mv -f "${GC_LOG_FILE}" "${PREVIOUS_GC_LOG_FILE}"
  fi
else
  # It is a dry run. Echo commands to stdout.
  DRY_RUN="echo"

  if [ "${UNBOUNDID_DRY_RUN}" == "low" ]
  then
    # Low level means to see the command run with the variables expanded.
    # This is close to what "ps" shows. LOG_FILE is changed to avoid
    # writing to that log file.
    LOG_FILE="/dev/stdout"
  elif [ "${UNBOUNDID_DRY_RUN}" == "high" ]
  then
    # High level means that the "eval" is suppressed so that the
    # unexpanded variables can be seen. If the variables are set then this
    # produces a runnable command.
    EVAL=""
  else
    echo "Unknown UNBOUNDID_DRY_RUN value \"${UNBOUNDID_DRY_RUN}\"." 1>&2
    echo "Valid values:" 1>&2
    echo "    low   Low level dry run. Expand all variables." 1>&2
    echo "    high  High level dry run. Leave variables unexpanded." 1>&2
    exit 1
  fi

  echo "Dry run ${UNBOUNDID_DRY_RUN} level with startability number ${EC}."
  echo
fi

if test ${EC} -eq 99 -o ${EC} -eq 103
then
  #
  # run detach
  #

  # For detached nohup is used to protect the server from signals.
  RUN="nohup"
  LOG_REDIRECT_ARG="> \"\${LOG_FILE}\" 2>&1"
  BG="&"

  if test -z "${DRY_RUN}"
  then
    # For detached mode this file being deleted indicates that the server has
    # started.
    touch "${STARTING_FILE}"
  fi
elif test ${EC} -eq 100 -o ${EC} -eq 104
then
  #
  # run no detach
  #

  # For no detach "exec" is used to replace this script process with the server.
  RUN="exec"
  BG=""

  if ! test -z "${DRY_RUN}"
  then
    # The server will have the same PID as this script.
    echo $$ > "${PID_FILE}"
  fi

  if test ${EC} -eq 100
  then
    #
    # run no detach with output
    #
    LOG_REDIRECT_ARG=""
  elif test ${EC} -eq 104
  then
    #
    # run no detach quiet
    #
    LOG_REDIRECT_ARG="> /dev/null"
  fi
else
  #
  # an error or the server is already started. Just return the code provided
  # by checkstartability
  #
  exit ${EC}
fi

# Since PRIVATE_UNBOUNDID_LOGGC_ARG must be quoted, but is optional, another
# variable is set with the quoted value.
if test -z "${PRIVATE_UNBOUNDID_LOGGC_ARG}"
then
  LOGGC_ARG=""
else
  LOGGC_ARG="\"\${PRIVATE_UNBOUNDID_LOGGC_ARG}\""
fi

# Start the server. If this is exec (no detach) then this script ends here.
$EVAL "$DRY_RUN" "$RUN" \"\${PRIVATE_UNBOUNDID_JAVA_BIN}\" \
  \${PRIVATE_UNBOUNDID_JAVA_ARGS} "${LOGGC_ARG}" \${SCRIPT_NAME_ARG} "${JAVA_AGENT_OPTS}" \
  "${UNBOUNDID_INVOKE_CLASS}" \
  --configClass com.unboundid.directory.server.extensions.ConfigFileHandler \
  --configFile \"\${CONFIG_FILE}\" \"\${@}\" "$LOG_REDIRECT_ARG" "$BG"

if ! test -z "${DRY_RUN}"
then
    # Dry run has finished showing the command.
    exit 0
fi

# If this point has been reached then the server has been started in detached
# mode. The rest of this script has to do with waiting for the server to start.

echo $! > "${PID_FILE}"

if test ${EC} -eq 99
then
  LOG_FILE_ARG="--logFile \"\${LOG_FILE}\""
else
  LOG_FILE_ARG=""
fi
eval \"\${PRIVATE_UNBOUNDID_JAVA_BIN}\" \${UNBOUNDID_NOVERIFY_ARG} -Xms32M \
  -Xmx32M com.unboundid.directory.server.tools.WaitForFileDelete \
  --targetFile \"\${STARTING_FILE}\" "$LOG_FILE_ARG"
EC=${?}

if test ${EC} -eq 0
then
  # An exit code of 98 means that the server is already running.
  ${PRIVATE_UNBOUNDID_JAVA_BIN} ${UNBOUNDID_NOVERIFY_ARG} ${SCRIPT_NAME_ARG} \
    "${UNBOUNDID_INVOKE_CLASS}" \
    --configClass com.unboundid.directory.server.extensions.ConfigFileHandler \
    --configFile "${CONFIG_FILE}" --checkStartability > /dev/null 2>&1
  EC=${?}
  if test ${EC} -eq 98
  then
    exit 0
  else
    # Could not start the server
    exit 1
  fi
else
  echo "WARNING:  Timeout encountered while waiting for the server to start."
  echo "          The server may still be starting, or it may have encountered an"
  echo "          error that caused it to be terminated abruptly."
fi
exit ${?}
