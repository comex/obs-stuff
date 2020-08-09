#!/bin/zsh
set -xe
export PKG_CONFIG_PATH=/opt/obs/lib/pkgconfig:/usr/local/opt/openssl/lib/pkgconfig:$PKG_CONFIG_PATH

cd "$(dirname "$0")"

mkdir -p /opt/obs/lib/pkgconfig
sed 's@-L\${libdir}@-L/usr/local/opt/sdl2/lib@' /usr/local/lib/pkgconfig/sdl2.pc > /opt/obs/lib/pkgconfig/sdl2.pc

SHARED_STATIC=(--enable-shared --disable-static)

if [ "$1" = "clean" ]; then
    rm -r ffmpeg obs srt x264 mpv /opt/obs/*
fi

if [ "$1" = "x264" ]; then
    mkdir -p x264
    pushd x264
    ~/src/x264/configure --prefix=/opt/obs ${SHARED_STATIC[@]}
    make -j8 && make install
    popd
fi
if [ "$1" = "srt" ]; then
    mkdir -p srt
    pushd srt
    ~/src/srt/configure --prefix=/opt/obs ${SHARED_STATIC[@]}
    make -j8 && make install
    p="$(greadlink -f /opt/obs/lib/libsrt.dylib)"
    install_name_tool -id "$p" "$p"
    popd
fi
if [ "$1" = "ffmpeg" ]; then
    mkdir -p ffmpeg
    pushd ffmpeg
    ~/src/ffmpeg/configure --prefix=/opt/obs --enable-gpl --enable-version3 --enable-nonfree --enable-libx264 --enable-libsrt --enable-openssl ${SHARED_STATIC[@]} --disable-stripping --enable-debug=2 # --pkg-config-flags=--static
    make -j8 && make install
    popd
fi
if [ "$1" = "obs" ]; then
    mkdir -p obs
    pushd obs
    PATH=/usr/local/opt/gettext/bin:$PATH cmake ~/src/obs-studio -DCMAKE_PREFIX_PATH=/usr/local/opt/qt/ -G Ninja -DENABLE_SCRIPTING=ON -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_OSX_DEPLOYMENT_TARGET=10.14
    ninja #&& FIXUP_BUNDLE=1 ninja package
    popd
fi
if [ "$1" = "mpv" ]; then
    mkdir -p mpv
    build_mpv="$PWD/mpv"
    pushd ~/src/mpv
    export CFLAGS="-mmacosx-version-min=10.14"
    export LDFLAGS="-pagezero_size 10000 -image_base 100000000 -mmacosx-version-min=10.14"
    WAF=(python3 ./waf -o "$build_mpv" -t .)
    "${WAF[@]}" configure
    "${WAF[@]}" build
    export LDFLAGS=
    export CFLAGS=
    popd
fi
