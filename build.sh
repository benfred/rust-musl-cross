#!/bin/bash
set -ex

# x86_64-unknown-linux-musl
docker build -t benfred/rust-musl-cross:x86_64-musl .
# aarch64-unknown-linux-musl
docker build --build-arg TARGET=aarch64-unknown-linux-musl --build-arg RUST_MUSL_MAKE_CONFIG=config.mak -t benfred/rust-musl-cross:aarch64-musl .
# armv7-unknown-linux-musleabihf
docker build --build-arg TARGET=armv7-unknown-linux-musleabihf --build-arg RUST_MUSL_MAKE_CONFIG=config.mak -t benfred/rust-musl-cross:armv7-musleabihf .
# i686-unknown-linux-musl
docker build --build-arg TARGET=i686-unknown-linux-musl --build-arg RUST_MUSL_MAKE_CONFIG=config.mak -t benfred/rust-musl-cross:i686-musl .
# powerpc64le-unknown-linux-musl
docker build --build-arg TARGET=powerpc64le-unknown-linux-musl --build-arg RUST_MUSL_MAKE_CONFIG=config.mak --build-arg TOOLCHAIN=nightly -t benfred/rust-musl-cross:powerpc64le-musl .
