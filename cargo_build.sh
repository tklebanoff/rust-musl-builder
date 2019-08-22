#!/usr/bin/env bash
set +x

export RUST_BACKTRACE=full

export TOOLCHAIN_ROOT="${TOOLCHAIN_ROOT:-/usr/local/musl}"
echo "TOOLCHAIN_ROOT: $TOOLCHAIN_ROOT"

#export CARGO_TARGET_X86_64_UNKNOWN_LINUX_MUSL_LINKER=/tmp/custom_link.sh

export LTO_PLUGIN="${TOOLCHAIN_ROOT}/libexec/gcc/x86_64-linux-musl/8.3.0/liblto_plugin.so.0.0.0"
export LTO_WRAPPER=/usr/local/musl/libexec/gcc/x86_64-linux-musl/8.3.0/lto-wrapper

export PKG_CONFIG_ALLOW_CROSS=1
export RUSTFLAGS="-C link-arg=-v -C linker=/tmp/custom_link.sh "
export PATH=/usr/local/musl/bin:$PATH

export TARGET_AR=/usr/local/musl/bin/x86_64-linux-musl-ar
export TARGET_CC=/usr/local/musl/bin/x86_64-linux-musl-gcc
export TARGET_CXX=/usr/local/musl/bin/x86_64-linux-musl-g++
export TARGET_LD=/usr/local/musl/bin/x86_64-linux-musl-ld
export TARGET_NM=/usr/local/musl/bin/x86_64-linux-musl-nm

cargo build -vv --target=x86_64-unknown-linux-musl 
#cat strace_out
