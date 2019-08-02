#!/bin/bash
export GCC_ROOT="$TOOLCHAIN_ROOT/lib/gcc/x86_64-linux-musl/8.3.0"

args=()
args+=("-v" "-Wl,-plugin=${LTO_PLUGIN}")
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

echo "CUSTOM_LINK_WRAPPER, RUNNING WITH ARGS: ${args[@]}"

set +x 
${CC} "${args[@]}"
set -x 

