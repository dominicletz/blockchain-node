#!/usr/bin/env bash

rm -rf data
rm -rf log
rm -rf _build/dev/rel
rm -rf *genesis.block
iex -S mix
