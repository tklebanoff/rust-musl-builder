#!/bin/bash
export LTO_PLUGIN="/usr/local/musl/libexec/gcc/x86_64-linux-musl/8.3.0/liblto_plugin.so.0.0.0"
export GCC_ROOT="$TOOLCHAIN_ROOT/lib/gcc/x86_64-linux-musl/8.3.0"

args=()
for arg in "$@"; do
    if [[ $arg = *"Bdynamic"* ]]; then
        args+=() # we do not want this arg
    elif [[ $arg = *"crti.o"* ]]; then
        args+=("$arg" "$GCC_ROOT/crtbeginT.o" "-Bstatic")
    elif [[ $arg = *"crtn.o"* ]]; then
        args+=("-lgcc" "-lgcc_eh" "-lc" "$GCC_ROOT/crtend.o" "$arg")
    else
        args+=("$arg")
    fi
done
args+=("-use-linker-plugin" "-Wl,-plugin,${LTO_PLUGIN}")

echo "CUSTOM_LINK_WRAPPER, RUNNING WITH ARGS: ${args[@]}"

echo "fuck it im calling strace"
sudo strace -o strace_out ${CC} "${args[@]}" 
cat strace_out
echo "somewhy calling strace made the dang thing work"
