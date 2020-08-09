#!/usr/bin/env zsh
if [ -e "/Applications" ]; then
    PLAT=mac
else
    PLAT=linux
fi
if [ "$PLAT" = "linux" ]; then
    READLINK=readlink
else
    READLINK=greadlink
fi
SRC="$("$READLINK" -f "$(dirname "$0")"/..)"
BUILD="$("$READLINK" -f "$(dirname "$0")"/../build)"
set -xe
export PKG_CONFIG_PATH=/opt/obs/lib/pkgconfig:$PKG_CONFIG_PATH
if [ "$PLAT" = "mac" ]; then
    export PKG_CONFIG_PATH=/usr/local/opt/openssl/lib/pkgconfig:$PKG_CONFIG_PATH
fi

cd "$(dirname "$0")"

if [ "$PLAT" = "mac" ]; then
    mkdir -p /opt/obs/lib/pkgconfig
    sed 's@-L\${libdir}@-L/usr/local/opt/sdl2/lib@' /usr/local/lib/pkgconfig/sdl2.pc > /opt/obs/lib/pkgconfig/sdl2.pc
fi

SHARED_STATIC=(--enable-shared --disable-static)

if [ "$1" = "clean" ]; then
    rm -r "$BUILD/ffmpeg" "$BUILD/obs" "$BUILD/srt" "$BUILD/x264" "$BUILD/mpv" # /opt/obs/*
fi

if [ "$1" = "x264" ]; then
    mkdir -p "$BUILD/x264"
    cd "$BUILD/x264"
    "$SRC/x264/configure" --prefix=/opt/obs ${SHARED_STATIC[@]}
    make -j8 && make install
fi
if [ "$1" = "srt" ]; then
    mkdir -p "$BUILD/srt"
    cd "$BUILD/srt"
    "$SRC/srt/configure" --prefix=/opt/obs ${SHARED_STATIC[@]}
    make -j8 && make install
    if [ "$PLAT" = "mac" ]; then
        p="$("$READLINK" -f /opt/obs/lib/libsrt.dylib)"
        install_name_tool -id "$p" "$p"
    fi
fi
if [ "$1" = "ffmpeg" ]; then
    mkdir -p "$BUILD/ffmpeg"
    cd "$BUILD/ffmpeg"
    "$SRC/ffmpeg/configure" --prefix=/opt/obs --enable-gpl --enable-version3 --enable-nonfree --enable-libx264 --enable-libsrt --enable-openssl ${SHARED_STATIC[@]} --disable-stripping --enable-debug=2 # --pkg-config-flags=--static
    make -j8 && make install
fi
if [ "$1" = "obs" ]; then
    mkdir -p "$BUILD/obs"
    cd "$BUILD/obs"
    (
        CMAKE_FLAGS=()
        if [ "$PLAT" = "mac" ]; then
            export PATH=/usr/local/opt/gettext/bin:$PATH
            CMAKE_FLAGS+=(-DCMAKE_PREFIX_PATH=/usr/local/opt/qt/ -DCMAKE_OSX_DEPLOYMENT_TARGET=10.14)
        fi
        if [ "$PLAT" = "linux" ]; then
            CMAKE_FLAGS+=(-DCMAKE_INSTALL_PREFIX=/opt/obs)
        fi
        cmake "$SRC/obs-studio" -G Ninja -DENABLE_SCRIPTING=ON -DCMAKE_BUILD_TYPE=RelWithDebInfo "${CMAKE_FLAGS[@]}"
        ninja #&& FIXUP_BUNDLE=1 ninja package
        if [ "$PLAT" = "linux" ]; then
            ninja install
        fi
    )
fi
if [ "$1" = "mpv" ]; then
    mkdir -p "$BUILD/mpv"
    cd "$SRC/mpv"
    (
        export CFLAGS="-mmacosx-version-min=10.14"
        export LDFLAGS="-pagezero_size 10000 -image_base 100000000 -mmacosx-version-min=10.14"
        WAF=(python3 ./waf -o "$BUILD/mpv" -t .)
        "${WAF[@]}" configure
        "${WAF[@]}" build
    )
fi
