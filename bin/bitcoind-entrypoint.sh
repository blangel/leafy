#!/usr/bin/env bash
set -euo pipefail

# set to TRUE to not pipe bitcoind[btc-rpc-explorer electrumx] to /dev/null
VERBOSE_LOG=${VERBOSE:-FALSE}

source utility.sh
exportLogDecorators

# see https://github.com/jamesob/docker-bitcoind/pull/16
sudo /usr/bin/append-to-hosts "$(ip -4 route list match 0/0 | awk '{print $3 "\thost.docker.internal"}')"

BITCOIN_DIR=/bitcoin/data
BITCOIN_CONF=/bitcoin/bitcoin.conf

if [ -z "${BTC_RPC_PWD:-}" ]; then
    # create a random pwd
    BTC_RPC_PWD=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 24)
fi

umask 077


BITCOIN_CONF_TEMPLATE=/bitcoin/bitcoin.template.conf
if [ ! -e "${BITCOIN_CONF}" ]; then
  # this one weird trick lets you override the env vars with those provided to Docker
  curenv=$(declare -p -x)
  set -o allexport && source /bitcoin/bitcoin.default.env && set +o allexport
  eval "$curenv"

  envsubst < "${BITCOIN_CONF_TEMPLATE}" > "${BITCOIN_CONF}"
  unbuffer echo "$(date +'%Y/%m/%d %T') created new configuration at ${BITCOIN_CONF}" | sed -u "s/${SED_DATE_MATCH}/${SETUP_DECORATOR}/"
fi

chmod 0600 "${BITCOIN_CONF}"

BTC_ELECTRUMX_DIR=/usr/local/electrumx
if [ -e "$BTC_ELECTRUMX_DIR" -a "${BITCOIN_EXPLORER:-true}" == "true" ]; then
  BTC_ELECTRUMX_SERVER="tcp://0.0.0.0:50001"
  BTC_ELECTRUMX_DATA_DIR=${BTC_ELECTRUMX_DIR}/data
  mkdir -p ${BTC_ELECTRUMX_DATA_DIR}

  export COIN="Bitcoin"
  export DB_DIRECTORY="${BTC_ELECTRUMX_DATA_DIR}"
  export DAEMON_URL="${BTC_RPC_USER}:${BTC_RPC_PWD}@${BTC_RPC_HOST}:${BTC_RPC_PORT}"
  export NET="regtest"
  export SERVICES="${BTC_ELECTRUMX_SERVER}"

  unbuffer echo "$(date +'%Y/%m/%d %T') starting electrumx server" | sed -u "s/${SED_DATE_MATCH}/${SETUP_DECORATOR}/"
  if [[ ${VERBOSE_LOG} == "TRUE" ]]; then
    exec python3 ${BTC_ELECTRUMX_DIR}/electrumx_server &
  else
    exec python3 ${BTC_ELECTRUMX_DIR}/electrumx_server > /dev/null 2>&1 &
  fi
fi

if [ $# -eq 0 ]; then
  if [[ ${VERBOSE_LOG} == "TRUE" ]]; then
    exec bitcoind --version
    exec bitcoind -datadir=${BITCOIN_DIR} -conf=${BITCOIN_CONF}
  else
    exec bitcoind -datadir=${BITCOIN_DIR} -conf=${BITCOIN_CONF} > /dev/null 2>&1
  fi
else
  exec "$@"
fi