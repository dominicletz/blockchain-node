#!/usr/bin/env bash
PROGNAME=$0

usage() {
  cat << EOF >&2
Usage: $PROGNAME [-e <env>]

-e <env>: ...
EOF
  exit 1
}

env=prod
while getopts e: o; do
  case $o in
    (e) env=$OPTARG;;
    (*) usage
  esac
done
shift "$((OPTIND - 1))"

_build/$env/rel/blockchain_node/bin/blockchain_node $@
