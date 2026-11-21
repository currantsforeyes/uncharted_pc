#!/usr/bin/env bash
# Builds and runs the C tests (tests/test_*.c) for the current platform, so the Windows path is
# covered as well as Linux:
#
#   bash tests/build.sh          # Windows (MSYS2 CLANG64) or Linux
#   bash tests/build.sh --minimal  # without SDL3/FFmpeg: skips the pad test
#
# Each test is self-contained where it can be: test_pad.c includes runtime_pad.c and carries its
# own gpu stubs, test_file_mods.c includes runtime_file.c. The runtime tests link the runtime
# sources and tests/stubs.c (the GPU entry points runtime.c calls).
set -uo pipefail
cd -- "$(dirname -- "$0")/.."
mkdir -p out/tests

windows=0
case "${OSTYPE:-}:${MSYSTEM:-}" in
*msys*|*cygwin*|*mingw*|*MSYS*|*MINGW*) windows=1;;
esac
echo "C tests: uname=$(uname -s 2>&1) OSTYPE=${OSTYPE:-} MSYSTEM=${MSYSTEM:-}"
echo "C tests: PATH=$PATH"
if [[ $windows == 1 ]]; then
    # shellcheck source=../msys2-env.sh
    source ./msys2-env.sh
    CC=${CC:-clang}
    libs="-lonecore -lbcrypt -lws2_32 -lpthread"
    # SDL3 must be linked with -mwindows: as a console binary the dummy video driver leaves SDL's
    # virtual gamepad unrecognised and test_pad fails.
    extra="-mwindows"
    nohigh="-Wl,--disable-high-entropy-va"
    minimal=${1:-${BB_TEST_MINIMAL:-0}}
else
    CC=${CC:-$(command -v cc || command -v gcc)}
    libs="-lm -pthread"
    extra=
    nohigh=
    minimal=${1:-${BB_TEST_MINIMAL:-0}}
fi
if [[ $minimal == --minimal ]]; then minimal=1; else minimal=0; fi
echo "C tests: windows=$windows, CC=$CC, pkg-config=$(command -v pkg-config || echo none), minimal=$minimal"

if [[ ! -f third_party/LibAtrac9/C/src/libatrac9.h ]]; then
    echo 'LibAtrac9 is missing: git submodule update --init --recursive' >&2
    exit 1
fi

# Third-party decoders, without this project's -Werror policy.
atrac9=()
shopt -u nullglob
for source in third_party/LibAtrac9/C/src/*.c; do
    object=out/tests/atrac9-$(basename "${source%.c}").o
    "$CC" -std=c99 -O1 -w -c "$source" -o "$object" || exit 1
    atrac9+=("$object")
done
echo "C tests: Atrac9 objects: ${#atrac9[@]} (from $(printf '%s ' third_party/LibAtrac9/C/src/*.c | wc -w) sources)"

runtime=(src/runtime.c src/runtime_memory.c src/runtime_thread.c src/runtime_fiber.c
         src/runtime_mutex.c src/runtime_sema.c src/runtime_rwlock.c src/runtime_kernel.c
         src/runtime_file.c src/runtime_savedata.c src/runtime_rtc.c src/runtime_time.c
         src/runtime_content.c src/runtime_services.c src/runtime_trophy.c src/compat_win.c tests/stubs.c)
pkg_includes=()
if [[ $minimal != 1 ]] && { ! command -v pkg-config >/dev/null ||
        ! pkg-config --exists sdl3 libavcodec libavutil libavformat; }; then
    echo 'SDL3/FFmpeg are not available through pkg-config: building the subset that does not need them.' >&2
    echo 'Install the SDL3 and FFmpeg development packages (MSYS2: SDL3, ffmpeg) for the full set.' >&2
    minimal=1
fi
if [[ $minimal == 1 ]]; then
    runtime+=(out/tests/audio-stub.c "${atrac9[@]}")
    cat > out/tests/audio-stub.c <<'STUB'
/* Stand-ins for the modules dropped in minimal mode: runtime.c calls every subsystem's
 * resolve/report unconditionally, so they must exist. */
#include "../src/runtime.h"
uintptr_t runtime_ajm_resolve(const char *name) { (void)name; return 0; }
void runtime_ajm_report(void) {}
void runtime_ajm_configure(void) {}
uintptr_t runtime_audio_resolve(const char *name) { (void)name; return 0; }
void runtime_audio_report(void) {}
void runtime_audio_configure(void) {}
uintptr_t runtime_pad_resolve(const char *name) { (void)name; return 0; }
void runtime_pad_report(void) {}
void runtime_pad_configure(void) {}
STUB
else
    runtime+=(src/runtime_ajm.c src/runtime_audio.c src/runtime_pad.c "${atrac9[@]}")
    read -r -a pkg_includes <<< "$(pkg-config --cflags libavcodec libavutil libavformat sdl3)"
    read -r -a pkg_libs <<< "$(pkg-config --libs libavcodec libavutil libavformat sdl3)"
    libs="$libs ${pkg_libs[*]}"
    echo "C tests: pkg-config flags: ${pkg_libs[*]}"
fi
echo "C tests: runtime sources: ${#runtime[@]}, libs: $libs"

failed=0

run() {
    local name=$1; shift
    local exe="out/tests/$name"
    [[ -x $exe.exe ]] && exe+=.exe
    if ./"$exe" "$@" > "out/tests/$name.log" 2>&1; then
        printf 'PASS  %s %s\n' "$name" "$*"
    else
        local code=$?
        printf 'FAIL  %s %s (exit %d)\n' "$name" "$*" "$code" >&2
        tail -5 "out/tests/$name.log" >&2
        failed=1
    fi
}

build() {
    local name=$1; shift
    "$CC" -std=c11 -O1 -g -Wall -Wextra -pthread -I. -Isrc \
        "${pkg_includes[@]+"${pkg_includes[@]}"}" \
        "$@" $libs $extra $nohigh -o "out/tests/$name" 2> "out/tests/$name.build.log"
    local code=$?
    if [[ $code -ne 0 ]]; then
        printf 'BUILD FAILED  %s (exit %d, log out/tests/%s.build.log)\n' "$name" "$code" "$name" >&2
        if [[ -f out/tests/$name.build.log ]]; then
            while IFS= read -r line || [[ -n $line ]]; do printf '%s\n' "$line"; done \
                < "out/tests/$name.build.log" >&2
        else
            printf 'no build log written\n' >&2
        fi
        failed=1
        return 1
    fi
}

# test_pad.c includes runtime_pad.c and defines the gpu stubs itself, so stubs.c is not linked.
if [[ $minimal != 1 ]] && build pad-test tests/test_pad.c src/compat_win.c; then
    run pad-test
fi
if build sema-test tests/test_sema.c "${runtime[@]}"; then
    run sema-test
    run sema-test --concurrency
    run sema-test --cancel-delete
    run sema-test --priority
fi
if build runtime-test tests/test_runtime.c "${runtime[@]}"; then
    run runtime-test
fi
if build content-test tests/test_content.c src/runtime_content.c tests/stubs.c; then
    run content-test
fi
# test_file_mods.c uses mkdtemp and symlink: POSIX only.
if [[ $windows == 0 ]]; then
    if build file-mods-test tests/test_file_mods.c src/compat_win.c; then
        run file-mods-test
    fi
fi

if [[ $failed -ne 0 ]]; then
    echo 'C tests failed.' >&2
    exit 1
fi
echo 'C tests: all passed'
