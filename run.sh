#!/usr/bin/env bash

rm -rf data
rm -rf log
rm -rf _build/dev
rm -rf *genesis.block
mix clean && mix deps.get
make clean && make && make devrelease
