#!/bin/bash
p_CURDIR=${PWD}

rm -rf ./eoy-build || true
mkdir ./eoy-build

cp -r ./src ./eoy-build/app
cp -r ./requirements.txt ./eoy-build/requirements.txt
cp -r ./docker/** ./eoy-build

cd eoy-build

docker build --tag localhost/eoy -f Dockerfile .

cd $p_CURDIR
