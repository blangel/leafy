#!/usr/bin/env bash

# This file is a utility script intended to be imported into other scripts.  It is not meant to be run
# stand alone.

# sets decorators and date matchers for assistance in log clarity
exportLogDecorators() {
  UNDECORATE="\x1b[0m"
  SED_DATE_MATCH="^\([0-9]\{4\}\/[0-9]\{2\}\/[0-9]\{2\} [0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}\)\{0,1\}"

  SCRIPT_DECORATOR="\x1b[38;5;15m\x1b[48;5;8m"
  SETUP_DECORATOR="\x1b[38;5;15m\x1b[48;5;8m[ setup  ]$UNDECORATE"
  BUILD_DECORATOR="\x1b[38;5;15m\x1b[48;5;20m[ build  ]$UNDECORATE"
  RUN_DECORATOR="\x1b[38;5;15m\x1b[48;5;33m[  run   ]$UNDECORATE"
  TEST_DECORATOR="\x1b[38;5;8m\x1b[48;5;11m[  test  ]$UNDECORATE"
  TEARDOWN_DECORATOR="\x1b[38;5;8m\x1b[48;5;3m[teardown]$UNDECORATE"
  LINT_DECORATOR="\x1b[38;5;15m\x1b[48;5;100m[  lint  ]$UNDECORATE"
  FAIL_DECORATOR="\x1b[38;5;15m\x1b[48;5;160m FAIL $UNDECORATE"
  PASS_DECORATOR="\x1b[38;5;15m\x1b[48;5;2m PASS $UNDECORATE"
}

# ensures output directory for logs exists, creating if not.
logSetup() {
  OUTPUT_DIR="target"
  if [ ! -d "${OUTPUT_DIR}" ]; then
    mkdir "${OUTPUT_DIR}" > /dev/null 2>&1 || { echo -e "${RUN_DECORATOR} output dir create ${FAIL_DECORATOR}"; exit 1; }
  fi
  echo "${OUTPUT_DIR}/$1-$2_$(date +'%Y_%m_%dT%H_%M')"
}

# appends to the passed in argument 6 random alpha-characters
getDockerBuildTagSuffix() {
  echo "$1-$(head /dev/urandom | LC_ALL=C tr -cd a-z0-9 | head -c 6; echo'')"
}

# assists in tearing down docker containers
# the following variables need to be defined by the invoker
# DOCKER_BUILD_TAGS -> an array of docker container tags, these are what will be torn down
# TEARDOWN_SUBPROCESS_DIR -> directory from which the invoked subprocesses originate
#
# to ensure this function is invoked the caller must setup the trap: trap 'dockerTeardown' INT TERM EXIT
dockerTeardown() {
  set +e
  for dockerContainerTag in "${DOCKER_CONTAINER_TAGS[@]}"; do
    echo -e "${TEARDOWN_DECORATOR} docker containers $(docker ps --filter ancestor="${dockerContainerTag}" -q)"
    docker container stop "$(docker ps --filter ancestor="${dockerContainerTag}" -q)" > /dev/null 2>&1
  done
  pids=$(ps -afx | grep "${TEARDOWN_SUBPROCESS_DIR}" | grep -v grep | awk '{print $2}')
  if [ -n "${pids}" ]; then
    echo -e "${TEARDOWN_DECORATOR} background tail process ${pids}"
    kill -9 "${pids}" > /dev/null 2>&1
  fi
  jbs=$(jobs -pr)
  if [ -n "${jbs}" ]; then
    echo -e "${TEARDOWN_DECORATOR} subprocesses ${jbs}"
    kill -9 "${jbs}" > /dev/null 2>&1
  fi
}

# Trap and manually send a SIGINT to the mempool-api's node-js process for graceful shutdown
gracefulDockerComposeShutdown() {
  if [ "${BITCOIN_EXPLORER:-true}" == "true" ]; then
    MEMPOOL_API_CONTAINER_ID=$(docker ps -aqf "name=mempool-api")
    MEMPOOL_API_NODE_PID=$(docker exec "$MEMPOOL_API_CONTAINER_ID" pidof node | sed 's/[^0-9]*//g')
    docker exec "$MEMPOOL_API_CONTAINER_ID" sh -c "kill -INT $MEMPOOL_API_NODE_PID"
  fi

  gracefulDockerComposeWebShutdown
}
