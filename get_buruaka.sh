#!/usr/bin/env bash

set -Eeuo pipefail

git clone https://github.com/jiyuzh/buruaka
cd ./buruaka

pushd ./bin
git clone https://github.com/jiyuzh/kernel-compile
popd

pushd ./lib
git clone https://github.com/jiyuzh/bandori
popd
