#!/bin/bash
set -e

DUMB_INIT_TAG=v1.0.0
GOSU_TAG=1.7

# Clear out the working folder and make the initial structure.
rm -rf pkg
mkdir -p pkg/build
mkdir -p pkg/rootfs/bin

# Create the Debian build box. We don't use this to package anything
# directly, but it's used as a scratch build environment.
docker build -t hashicorp/builder-debian images/builder-debian

# Build dumb-init.
git clone https://github.com/Yelp/dumb-init.git pkg/build/dumb-init
pushd pkg/build/dumb-init
git checkout -q "tags/$DUMB_INIT_TAG"
docker run --rm -v "$(pwd):/build" -w /build hashicorp/builder-debian make
popd
cp pkg/build/dumb-init/dumb-init pkg/rootfs/bin

# Build gosu.
git clone https://github.com/tianon/gosu.git pkg/build/gosu
pushd pkg/build/gosu
git checkout -q "tags/$GOSU_TAG"
docker build --pull -t gosu .
docker run --rm gosu bash -c 'cd /go/bin && tar -c gosu*' | tar -xv
popd
cp pkg/build/gosu/gosu-amd64 pkg/rootfs/bin/gosu

# SHA and optionally sign the rootfs contents that we provided. We
# sign each binary piece-wise since images might not contain all of
# them, so they can easily be verified separately.
pushd pkg/rootfs/bin
find . -type f -exec sh -c 'shasum -a256 $(basename $1) >$1.SHA256SUM' -- {} \;
if [ -z $NOSIGN ]; then
    gpg --default-key 348FFC4C --detach-sig *.SHA256SUM
fi
popd