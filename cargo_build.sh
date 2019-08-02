#!/usr/bin/env bash

export RUST_BACKTRACE=full

export TOOLCHAIN_ROOT="${TOOLCHAIN_ROOT:-/usr/local/musl}"
echo "TOOLCHAIN_ROOT: $TOOLCHAIN_ROOT"

#export CARGO_TARGET_X86_64_UNKNOWN_LINUX_MUSL_LINKER=/tmp/custom_link.sh

export LTO_PLUGIN="${TOOLCHAIN_ROOT}/libexec/gcc/x86_64-linux-musl/8.3.0/liblto_plugin.so.0.0.0"
export LTO_WRAPPER=/usr/local/musl/libexec/gcc/x86_64-linux-musl/8.3.0/lto-wrapper

export TARGET_CC=$TOOLCHAIN_ROOT/bin/x86_64-linux-musl-gcc
export TARGET_LD=$TOOLCHAIN_ROOT/bin/x86_64-linux-musl-ld
export TARGET_CXX=$TOOLCHAIN_ROOT/bin/x86_64-linux-musl-g++
export TARGET_AR=$TOOLCHAIN_ROOT/bin/x86_64-linux-musl-ar

export CC="${TARGET_CC}"
export CXX="${TARGET_CXX}"

export LD="${TARGET_LD}"
export HOST_CC=cc

export PKG_CONFIG_ALLOW_CROSS=1
#export RUSTFLAGS="-C linker-plugin-lto=${LTO_PLUGIN} -C link-arg=-v -C linker=$CARGO_TARGET_X86_64_UNKNOWN_LINUX_MUSL_LINKER -C ar=$TARGET_AR"
#export RUSTFLAGS="-C linker-plugin-lto=${LTO_PLUGIN} -C link-arg=-v -C ar=$TARGET_AR"
#export RUSTFLAGS="-C linker-plugin-lto=${LTO_PLUGIN} -C link-arg=-v -C link-args -plugin ${LTO_PLUGIN} -C ar=$TARGET_AR"
#export RUSTFLAGS="-C linker-plugin-lto=${LTO_PLUGIN} -C link-arg=-v -C linker=${TARGET_CC}"
export RUSTFLAGS="-C link-arg=-v -C linker=/tmp/custom_link.sh -C linker-plugin-lto=${LTO_PLUGIN} -C link-arg=-static-pie"

export PATH=/usr/local/musl/bin:$PATH

cargo build -vv --release --target=x86_64-unknown-linux-musl --message-format=json
ls -l /home/rust/src/target/x86_64-unknown-linux-musl/release/
#cargo install --path deleter --target=x86_64-unknown-linux-musl 
