FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

# Make sure we have basic dev tools for building C libraries.  Our goal
# here is to support the musl-libc builds and Cargo builds needed for a
# large selection of the most popular crates.
#
RUN apt-get update && \
    apt-get install -y \
        build-essential \
        cmake \
        curl \
        file \
        git \
        sudo \
        xutils-dev \
        unzip \
        ca-certificates \
        python3 \
        python3-pip \
        autoconf \
        autoconf-archive \
        automake \
        flex \
        bison \
        llvm-dev \
        libclang-dev \
        clang \
        && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Let's Encrypt R3 CA certificate from https://letsencrypt.org/certificates/
COPY lets-encrypt-r3.crt /usr/local/share/ca-certificates
RUN update-ca-certificates

ARG TARGET=x86_64-unknown-linux-musl
ENV RUST_MUSL_CROSS_TARGET=$TARGET
ARG RUST_MUSL_MAKE_VER=0.9.9
ARG RUST_MUSL_MAKE_CONFIG=config.mak

COPY $RUST_MUSL_MAKE_CONFIG /tmp/config.mak
RUN cd /tmp && curl -Lsq -o musl-cross-make.zip https://github.com/richfelker/musl-cross-make/archive/v$RUST_MUSL_MAKE_VER.zip && \
    unzip -q musl-cross-make.zip && \
    rm musl-cross-make.zip && \
    mv musl-cross-make-$RUST_MUSL_MAKE_VER musl-cross-make && \
    cp /tmp/config.mak /tmp/musl-cross-make/config.mak && \
    cd /tmp/musl-cross-make && \
    export TARGET=$TARGET && \
    make -j$(nproc) > /tmp/musl-cross-make.log && \
    make install >> /tmp/musl-cross-make.log && \
    ln -s /usr/local/musl/bin/$TARGET-strip /usr/local/musl/bin/musl-strip && \
    cd /tmp && \
    rm -rf /tmp/musl-cross-make /tmp/musl-cross-make.log

RUN mkdir -p /home/rust/libs /home/rust/src

# Set up our path with all our binary directories, including those for the
# musl-gcc toolchain and for our Rust toolchain.
ENV PATH=/root/.cargo/bin:/usr/local/musl/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV TARGET_CC=$TARGET-gcc
ENV TARGET_CXX=$TARGET-g++
ENV TARGET_HOME=/usr/local/musl/$TARGET
ENV TARGET_C_INCLUDE_PATH=$TARGET_HOME/include/

# We'll build our libraries in subdirectories of /home/rust/libs.  Please
# clean up when you're done.
WORKDIR /home/rust/libs

RUN export CC=$TARGET_CC && \
    export C_INCLUDE_PATH=$TARGET_C_INCLUDE_PATH && \
    echo "Building zlib" && \
    VERS=1.2.11 && \
    CHECKSUM=c3e5e9fdd5004dcb542feda5ee4f0ff0744628baf8ed2dd5d66f8ca1197cb1a1 && \
    cd /home/rust/libs && \
    curl -sqLO https://zlib.net/zlib-$VERS.tar.gz && \
    echo "$CHECKSUM zlib-$VERS.tar.gz" > checksums.txt && \
    sha256sum -c checksums.txt && \
    tar xzf zlib-$VERS.tar.gz && cd zlib-$VERS && \
    ./configure --static --archs="-fPIC" --prefix=$TARGET_HOME && \
    make -j$(nproc) && make install && \
    cd .. && rm -rf zlib-$VERS.tar.gz zlib-$VERS checksums.txt

# we also need libunwind / libunwind-ptrace built in addition
COPY libunwind.patch /home/rust/libs
RUN export CC=$TARGET_CC && \
    export C_INCLUDE_PATH=$TARGET_C_INCLUDE_PATH && \
    export LDFLAGS="-fPIE" && \
    export CFLAGS="-fPIE" && \
    echo "Building libunwind" && \
    VERS=1.5.0 && DOWNLOAD_VERS=1.5 && \
    CHECKSUM=90337653d92d4a13de590781371c604f9031cdb50520366aa1e3a91e1efb1017 && \
    cd /home/rust/libs && \
    curl -sqLO https://github.com/libunwind/libunwind/releases/download/v$DOWNLOAD_VERS/libunwind-$VERS.tar.gz && \
    echo "$CHECKSUM libunwind-$VERS.tar.gz" > checksums.txt && \
    sha256sum -c checksums.txt && \
    tar xzf libunwind-$VERS.tar.gz && cd libunwind-$VERS && \
    patch -p1 -i ../libunwind.patch && \
    ./configure --prefix=$TARGET_HOME --disable-minidebuginfo --enable-ptrace --disable-tests --disable-documentation --host $TARGET --enable-shared=no  && \
    make && make install && \
    cd .. && rm -rf libunwind-$VERS.tar.gz libunwind-$VERS checksums.txt libunwind.patch

# The Rust toolchain to use when building our image
ARG TOOLCHAIN=stable
# Install our Rust toolchain and the `musl` target.  We patch the
# command-line we pass to the installer so that it won't attempt to
# interact with the user or fool around with TTYs.  We also set the default
# `--target` to musl so that our users don't need to keep overriding it
# manually.
# Chmod 755 is set for root directory to allow access execute binaries in /root/.cargo/bin (azure piplines create own user).
#
# Remove docs and more stuff not needed in this images to make them smaller
RUN chmod 755 /root/ && \
    curl https://sh.rustup.rs -sqSf | \
    sh -s -- -y --profile minimal --default-toolchain $TOOLCHAIN && \
    rustup target add $TARGET || rustup component add --toolchain $TOOLCHAIN rust-src && \
    rustup component add --toolchain $TOOLCHAIN rustfmt clippy && \
    rm -rf /root/.rustup/toolchains/$TOOLCHAIN-$(uname -m)-unknown-linux-gnu/share/

RUN echo "[target.$TARGET]\nlinker = \"$TARGET-gcc\"\n" > /root/.cargo/config

# Build std sysroot for targets that doesn't have official std release
ADD Xargo.toml /tmp/Xargo.toml
ADD build-std.sh .
COPY compile-libunwind /tmp/compile-libunwind
RUN bash build-std.sh

ENV RUSTUP_HOME=/root/.rustup
ENV CARGO_HOME=/root/.cargo
ENV CARGO_BUILD_TARGET=$TARGET

ENV CFLAGS_armv7_unknown_linux_musleabihf='-mfpu=vfpv3-d16'

# Build statically linked binaries for MIPS targets
ENV CARGO_TARGET_MIPS_UNKNOWN_LINUX_MUSL_RUSTFLAGS='-C target-feature=+crt-static'
ENV CARGO_TARGET_MIPSEL_UNKNOWN_LINUX_MUSL_RUSTFLAGS='-C target-feature=+crt-static'
ENV CARGO_TARGET_MIPS64_UNKNOWN_LINUX_MUSLABI64_RUSTFLAGS='-C target-feature=+crt-static'
ENV CARGO_TARGET_MIPS64EL_UNKNOWN_LINUX_MUSLABI64_RUSTFLAGS='-C target-feature=+crt-static'

# Expect our source code to live in /home/rust/src
WORKDIR /home/rust/src
