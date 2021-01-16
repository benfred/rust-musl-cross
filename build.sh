#!/bin/bash
docker build -t benfred/rust-musl-cross:x86_64-musl .
docker build --build-arg TARGET=armv7-unknown-linux-musleabihf --build-arg OPENSSL_ARCH=linux-generic32 -t benfred/rust-musl-cross:armv7-musleabihf .
docker build --build-arg TARGET=aarch64-unknown-linux-musl --build-arg OPENSSL_ARCH=linux-aarch64 -t benfred/rust-musl-cross:aarch64-musl .
docker build --build-arg TARGET=i686-unknown-linux-musl --build-arg OPENSSL_ARCH=linux-generic32 -t benfred/rust-musl-cross:i686-musl .
docker build --build-arg TARGET=powerpc64-linux-musl --build-arg OPENSSL_ARCH=linux-powerpc64 -t benfred/rust-musl-cross:powerpc64-musl .
docker build --build-arg TARGET=powerpc64le-linux-musl --build-arg OPENSSL_ARCH=linux-powerpc64le -t benfred/rust-musl-cross:powerpc64le-musl .
