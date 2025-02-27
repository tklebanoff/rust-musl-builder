# Use Ubuntu 18.04 LTS as our base image.
FROM ubuntu:18.04

# The Rust toolchain to use when building our image.  Set by `hooks/build`.
ARG TOOLCHAIN=nightly

# The OpenSSL version to use. We parameterize this because many Rust
# projects will fail to build with 1.1.
#ARG OPENSSL_VERSION=1.0.2r
ARG OPENSSL_VERSION=1.1.1c

# Make sure we have basic dev tools for building C libraries.  Our goal
# here is to support the musl-libc builds and Cargo builds needed for a
# large selection of the most popular crates.
#
# We also set up a `rust` user by default, in whose account we'll install
# the Rust toolchain.  This user has sudo privileges if you need to install
# any more software.
#
# `mdbook` is the standard Rust tool for making searchable HTML manuals.
RUN apt-get update && \
    apt-get install -y \
        build-essential \
        cmake \
        golang-go \
        curl \
        file \
        git \
        #musl-dev \
        #musl-tools \
        libpq-dev \
        libsqlite-dev \
        libssl-dev \
        wget \
        m4 \
        linux-libc-dev \
        pkgconf \
        sudo \
        strace \
        xutils-dev \
        gcc-multilib-arm-linux-gnueabihf \
        && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && \
    useradd rust --user-group --create-home --shell /bin/bash --groups sudo && \
    MDBOOK_VERSION=0.2.1 && \
    curl -LO https://github.com/rust-lang-nursery/mdBook/releases/download/v$MDBOOK_VERSION/mdbook-v$MDBOOK_VERSION-x86_64-unknown-linux-musl.tar.gz && \
    tar xf mdbook-v$MDBOOK_VERSION-x86_64-unknown-linux-musl.tar.gz && \
    mv mdbook /usr/local/bin/ && \
    rm -f mdbook-v$MDBOOK_VERSION-x86_64-unknown-linux-musl.tar.gz


ENV \
    MUSL_INCLUDE=/usr/local/musl/include \
    MUSL_BIN=/usr/local/musl/bin         \
    MUSL_LIB=/usr/local/musl/lib         \
    MUSL_PREFIX=/usr/local/musl          \
    MUSL_TARGET=x86_64-linux-musl        \
    MUSL_GCC=/usr/local/musl/bin/x86_64-linux-musl-gcc

WORKDIR /tmp
RUN git clone https://github.com/richfelker/musl-cross-make 
WORKDIR /tmp/musl-cross-make
RUN env TARGET=${MUSL_TARGET} make all
RUN make TARGET=${MUSL_TARGET} OUTPUT=${MUSL_PREFIX} install

# Static linking for C++ code
#RUN sudo ln -s "/usr/bin/g++" "/usr/bin/musl-g++"

# Allow sudo without a password.
ADD sudoers /etc/sudoers.d/nopasswd

# Run all further code as user `rust`, and create our working directories
# as the appropriate user.
USER rust
RUN mkdir -p /home/rust/libs /home/rust/src

# Set up our path with all our binary directories, including those for the
# musl-gcc toolchain and for our Rust toolchain.
#ENV PATH=/home/rust/.cargo/bin:/usr/local/musl/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV PATH=/home/rust/.cargo/bin:${MUSL_BIN}:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Install our Rust toolchain and the `musl` target.  We patch the
# command-line we pass to the installer so that it won't attempt to
# interact with the user or fool around with TTYs.  We also set the default
# `--target` to musl so that our users don't need to keep overriding it
# manually.
RUN curl https://sh.rustup.rs -sSf | \
    sh -s -- -y --default-toolchain $TOOLCHAIN && \
    rustup target add x86_64-unknown-linux-musl && \
    rustup target add armv7-unknown-linux-musleabihf
ADD cargo-config.toml /home/rust/.cargo/config

# Set up a `git credentials` helper for using GH_USER and GH_TOKEN to access
# private repositories if desired.
ADD git-credential-ghtoken /usr/local/bin
RUN git config --global credential.https://github.com.helper ghtoken


# Build a static library version of OpenSSL using musl-libc.  This is needed by
# the popular Rust `hyper` crate.
#
# We point ${MUSL_INCLUDE}/linux at some Linux kernel headers (not
# necessarily the right ones) in an effort to compile OpenSSL 1.1's "engine"
# component. It's possible that this will cause bizarre and terrible things to
# happen. There may be "sanitized" header
RUN echo "Building OpenSSL" && \
    ls /usr/include/linux && \
    sudo mkdir -p ${MUSL_INCLUDE} && \
    sudo ln -s /usr/include/linux ${MUSL_INCLUDE}/linux && \
    sudo ln -s /usr/include/x86_64-linux-gnu/asm ${MUSL_INCLUDE}/asm && \
    sudo ln -s /usr/include/asm-generic ${MUSL_INCLUDE}/asm-generic && \
    cd /tmp && \
    curl -LO "https://www.openssl.org/source/openssl-$OPENSSL_VERSION.tar.gz" && \
    tar xvzf "openssl-$OPENSSL_VERSION.tar.gz" && cd "openssl-$OPENSSL_VERSION" && \
    env CC=${MUSL_GCC} ./Configure no-shared no-zlib -fPIC --prefix=${MUSL_PREFIX} -DOPENSSL_NO_SECURE_MEMORY linux-x86_64 && \
    env C_INCLUDE_PATH=${MUSL_INCLUDE}/ make depend && \
    env C_INCLUDE_PATH=${MUSL_INCLUDE}/ make && \
    sudo make install && \
    echo "done"
    #sudo rm ${MUSL_INCLUDE}/linux ${MUSL_INCLUDE}/asm ${MUSL_INCLUDE}/asm-generic && \
    #rm -r /tmp/*

RUN echo "Building zlib" && \
    cd /tmp && \
    ZLIB_VERSION=1.2.11 && \
    curl -LO "http://zlib.net/zlib-$ZLIB_VERSION.tar.gz" && \
    tar xzf "zlib-$ZLIB_VERSION.tar.gz" && cd "zlib-$ZLIB_VERSION" && \
    CC=${MUSL_GCC} ./configure --static --prefix=${MUSL_PREFIX} && \
    make && sudo make install && \
    echo "done"
    #rm -r /tmp/*

#RUN echo "Building libpq" && \
#    cd /tmp && \
#    POSTGRESQL_VERSION=11.2 && \
#    curl -LO "https://ftp.postgresql.org/pub/source/v$POSTGRESQL_VERSION/postgresql-$POSTGRESQL_VERSION.tar.gz" && \
#    tar xzf "postgresql-$POSTGRESQL_VERSION.tar.gz" && cd "postgresql-$POSTGRESQL_VERSION" && \
#    CC=${MUSL_GCC} CPPFLAGS=-I${MUSL_INCLUDE} LDFLAGS=-L${MUSL_LIB} ./configure --with-openssl --without-readline --prefix=${MUSL_PREFIX} && \
#    cd src/interfaces/libpq && make all-static-lib && sudo make install-lib-static && \
#    cd ../../bin/pg_config && make && sudo make install && \
#    echo "done"
#    #rm -r /tmp/*

ENV OPENSSL_DIR=${MUSL_PREFIX}/ \ 
    RUSTFLAGS="-C target-feature=+crt-static"\
    OPENSSL_INCLUDE_DIR=${MUSL_INCLUDE}/ \
    DEP_OPENSSL_INCLUDE=${MUSL_INCLUDE}/ \
    OPENSSL_LIB_DIR=${MUSL_LIB}/ \
    OPENSSL_STATIC=1 \
    PQ_LIB_STATIC_X86_64_UNKNOWN_LINUX_MUSL=1 \
    PG_CONFIG_X86_64_UNKNOWN_LINUX_GNU=/usr/bin/pg_config \
    PKG_CONFIG_ALLOW_CROSS=true \
    PKG_CONFIG_ALL_STATIC=true \
    LIBZ_SYS_STATIC=1 \
    TARGET=${MUSL_TARGET}

USER rust
ENV CC=${MUSL_GCC}
# (Please feel free to submit pull requests for musl-libc builds of other C
# libraries needed by the most popular and common Rust crates, to avoid
# everybody needing to build them manually.)

# Install some useful Rust tools from source. This will use the static linking
# toolchain, but that should be OK.
RUN cargo install -f cargo-audit && \
    rm -rf /home/rust/.cargo/registry/

WORKDIR /tmp
USER root
ADD cargo_build.sh cargo_build.sh
ADD custom_link.sh custom_link.sh
RUN chmod +x cargo_build.sh
RUN chmod +x custom_link.sh
RUN chown rust cargo_build.sh
RUN chown rust custom_link.sh
RUN pwd && ls -l 
USER rust

# Expect our source code to live in /home/rust/src.  We'll run the build as
# user `rust`, which will be uid 1000, gid 1000 outside the container.
WORKDIR /home/rust/src

USER root
RUN mv /usr/local/musl/bin/x86_64-linux-musl-gcc /usr/local/musl/bin/x86_64-linux-musl-gcc-real
ADD gcc_wrapper /usr/local/musl/bin/x86_64-linux-musl-gcc
RUN chmod +x /usr/local/musl/bin/x86_64-linux-musl-gcc 
RUN chown rust /usr/local/musl/bin/x86_64-linux-musl-gcc 
USER rust

USER root
RUN mv /usr/local/musl/bin/x86_64-linux-musl-ar /usr/local/musl/bin/x86_64-linux-musl-ar-real
ADD ar_wrapper /usr/local/musl/bin/x86_64-linux-musl-ar
RUN chmod +x /usr/local/musl/bin/x86_64-linux-musl-ar 
RUN chown rust /usr/local/musl/bin/x86_64-linux-musl-ar 
USER rust

USER root
RUN mv /usr/local/musl/bin/x86_64-linux-musl-ld /usr/local/musl/bin/x86_64-linux-musl-ld-real
ADD ld_wrapper /usr/local/musl/bin/x86_64-linux-musl-ld
RUN chmod +x /usr/local/musl/bin/x86_64-linux-musl-ld 
RUN chown rust /usr/local/musl/bin/x86_64-linux-musl-ld 
USER rust

USER root
RUN mv /usr/local/musl/bin/x86_64-linux-musl-g++ /usr/local/musl/bin/x86_64-linux-musl-g++-real
ADD g++_wrapper /usr/local/musl/bin/x86_64-linux-musl-g++
RUN chmod +x /usr/local/musl/bin/x86_64-linux-musl-g++ 
RUN chown rust /usr/local/musl/bin/x86_64-linux-musl-g++ 
USER rust

USER root
RUN ln /usr/local/musl/bin/x86_64-linux-musl-g++ /usr/local/musl/bin/g++
RUN ln /usr/local/musl/bin/x86_64-linux-musl-ar /usr/local/musl/bin/ar
RUN ln /usr/local/musl/bin/x86_64-linux-musl-gcc /usr/local/musl/bin/gcc
RUN ln /usr/local/musl/bin/x86_64-linux-musl-ld /usr/local/musl/bin/ld
RUN ln /usr/local/musl/bin/x86_64-linux-musl-g++ /usr/local/musl/bin/musl-g++
USER rust

ENTRYPOINT [ "/tmp/cargo_build.sh" ]
