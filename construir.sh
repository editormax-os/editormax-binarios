#!/bin/bash
# Compila los binarios propios del producto (ffmpeg, ffprobe, whisper-cli, faces): enlazados estáticos, para macOS 13.5 o posterior. Ni ffmpeg ni whisper-cli tienen
# versión oficial para Mac. No instala nada fuera de .editormax/binarios (ignorada por git) y no usa Homebrew: el PATH no lo lleva.
#   /bin/bash producto/binarios/construir.sh            para Mac con chip Apple (arm64), en .editormax/binarios/
#   /bin/bash producto/binarios/construir.sh x86_64     para Mac con Intel, desde este mismo Mac (compilación cruzada), en .editormax/binarios/x86_64/
# Los de Intel no se pueden ejecutar aquí sin Rosetta: sin ella, sus comprobaciones finales son las que no necesitan ejecutarlos.
set -euo pipefail
cd "$(dirname "$0")/../.."
ARQ="${1:-arm64}"; case "$ARQ" in arm64|x86_64) ;; *) echo "uso: construir.sh [arm64|x86_64]" >&2; exit 2;; esac
ROOT="$PWD"; W0="$ROOT/.editormax/binarios"; W="$W0"; [ "$ARQ" = arm64 ] || W="$W0/$ARQ"
# lo de cada chip, en su carpeta; las fuentes bajadas y cmake (una herramienta de este Mac) se comparten
P="$W/prefix"; F="$W0/fuentes"; B="$W/build"
mkdir -p "$P/bin" "$F" "$B" "$W/salida"
J=$(sysctl -n hw.ncpu)
export MACOSX_DEPLOYMENT_TARGET=13.5
export PATH="$P/bin:/usr/bin:/bin:/usr/sbin:/sbin"
FA="-arch $ARQ"
export CFLAGS="-O2 $FA -mmacosx-version-min=13.5" CXXFLAGS="-O2 $FA -mmacosx-version-min=13.5" LDFLAGS="$FA -mmacosx-version-min=13.5"
# para Intel desde un Mac con chip Apple: a cada configure se le dice para quién compila, y x264, libvpx y ffmpeg necesitan un ensamblador de x86 (nasm)
CRUZ=""; FF=(--cc=clang --enable-neon); METAL=ON
if [ "$ARQ" = x86_64 ]; then CRUZ="--host=x86_64-apple-darwin"; FF=("--cc=clang -arch x86_64" --arch=x86_64 --enable-cross-compile --target-os=darwin --x86asmexe=nasm); METAL=OFF; fi
NASM_URL=https://www.nasm.us/pub/nasm/releasebuilds/2.16.03/nasm-2.16.03.tar.xz; NASM_SHA=1412a1c760bbd05db026b6c0d1657affd6631cd0a63cddb6f73cc6d4aa616148
PKGCONF_URL=https://distfiles.ariadne.space/pkgconf/pkgconf-3.0.10.tar.xz; PKGCONF_SHA=9371b2f6372da574d4c6dc96fe9b1463037bcf6afcb6671c1555afde7b17e2de
LAME_URL=https://downloads.sourceforge.net/project/lame/lame/4.0/lame-4.0.tar.gz; LAME_SHA=3df5124d5ad3a98312ffd7ba6a9b36230e4f8a3e66d3ce0f425e336c32d216eb
OPUS_URL=https://ftp.osuosl.org/pub/xiph/releases/opus/opus-1.6.1.tar.gz; OPUS_SHA=6ffcb593207be92584df15b32466ed64bbec99109f007c82205f0194572411a1
# la misma 1.16.0 con la que se han hecho todos los vídeos aprobados
VPX_URL=https://github.com/webmproject/libvpx/archive/refs/tags/v1.16.0.tar.gz; VPX_SHA=7a479a3c66b9f5d5542a4c6a1b7d3768a983b1e5c14c60a9396edc9b649e015c
# cada fuente con su huella fijada: sin huella o con otra, no se usa
baja() {
  # (11/11) en dos órdenes: el bash de macOS (3.2) expande todas las palabras de un mismo `local` antes de asignar ninguna, y con `set -u` paraba en
  # «url: unbound variable» (o, sin él, bajaba cada fuente a la carpeta en vez de a su fichero)
  local n="$1" url="$2" sha="$3"
  local d="$F/${url##*/}"
  [ -n "$sha" ] || { echo "✗ $n: sin huella fijada" >&2; exit 1; }
  [ -f "$d" ] || curl -fsSL --retry 4 -o "$d" "$url"
  local h; h=$(shasum -a 256 "$d" | cut -d' ' -f1)
  if [ "$h" != "$sha" ]; then echo "✗ $n: huella distinta ($h)" >&2; exit 1; fi
  echo "$d"
}
abre() { dest="$B/$1"; if [ -e "$dest" ]; then mv "$dest" "$dest.$(date +%s)"; fi; mkdir -p "$dest"; tar -xf "$2" -C "$dest" --strip-components 1; cd "$dest"; }
hecho() { touch "$W/.hecho-$1"; echo "✓ $1 · $(date +%T)"; }
ya() { [ -f "$W/.hecho-$1" ]; }

# pkgconf y nasm son herramientas que corren en ESTE Mac: se compilan para él, no para el destino
if ! ya pkgconf; then d=$(baja pkgconf "$PKGCONF_URL" "$PKGCONF_SHA"); abre pkgconf "$d"; env CFLAGS=-O2 CXXFLAGS=-O2 LDFLAGS= ./configure --prefix="$P" --disable-shared --enable-static --with-system-libdir=/usr/lib --with-system-includedir=/usr/include >/dev/null; make -j"$J" >/dev/null; make install >/dev/null; ln -sf pkgconf "$P/bin/pkg-config"; cd "$ROOT"; hecho pkgconf; fi
if [ "$ARQ" = x86_64 ] && ! ya nasm; then d=$(baja nasm "$NASM_URL" "$NASM_SHA"); abre nasm "$d"; env CFLAGS=-O2 CXXFLAGS=-O2 LDFLAGS= ./configure --prefix="$P" >/dev/null; make -j"$J" >/dev/null 2>&1; cp nasm ndisasm "$P/bin/"; cd "$ROOT"; hecho nasm; fi
if ! ya lame; then d=$(baja lame "$LAME_URL" "$LAME_SHA"); abre lame "$d"; /usr/bin/sed -i '' '/lame_init_old/d' include/libmp3lame.sym; ./configure --prefix="$P" $CRUZ --disable-shared --enable-static --disable-frontend --disable-decoder --disable-debug >/dev/null; make -j"$J" >/dev/null 2>&1; make install >/dev/null; cd "$ROOT"; hecho lame; fi   # --disable-decoder (11/11): lame 4.0 pide libmpg123 para DEcodificar, y aquí solo codifica (ffmpeg trae su propio decodificador de MP3)
if ! ya opus; then d=$(baja opus "$OPUS_URL" "$OPUS_SHA"); abre opus "$d"; ./configure --prefix="$P" $CRUZ --disable-shared --enable-static --disable-doc --disable-extra-programs >/dev/null; make -j"$J" >/dev/null 2>&1; make install >/dev/null; cd "$ROOT"; hecho opus; fi
if ! ya libvpx; then d=$(baja libvpx "$VPX_URL" "$VPX_SHA"); abre libvpx "$d"; t=$( (./configure --help || true) | grep -oE "$ARQ-darwin[0-9]+-gcc" | sort -t n -k2 -V | tail -1); [ -n "$t" ] || { echo "✗ libvpx: no encuentro su destino $ARQ-darwin" >&2; exit 1; }; ./configure --prefix="$P" --target="$t" --disable-shared --enable-static --enable-pic --disable-examples --disable-tools --disable-docs --disable-unit-tests --enable-vp8 --enable-vp9 --enable-vp9-highbitdepth >/dev/null; make -j"$J" >/dev/null 2>&1; make install >/dev/null; cd "$ROOT"; hecho libvpx; fi
if ! ya x264; then c=b35605ace3ddf7c1a5d67a2eb553f034aef41d55; d=$(baja x264 "https://code.videolan.org/videolan/x264/-/archive/$c/x264-$c.tar.bz2" 6eeb82934e69fd51e043bd8c5b0d152839638d1ce7aa4eea65a3fedcf83ff224); abre x264 "$d"; ./configure --prefix="$P" $CRUZ --enable-static --disable-cli --enable-pic --bit-depth=all --chroma-format=all >/dev/null; make -j"$J" >/dev/null 2>&1; make install-lib-static >/dev/null; cd "$ROOT"; hecho x264; fi
# (11/11) --extra-libs=-liconv: con el SDK de hoy la sonda de configure enlaza iconv sin su biblioteca, y luego ffmpeg no enlaza (iconv_open sin definir). Es la del sistema (/usr/lib)
if ! ya ffmpeg; then d=$(baja ffmpeg https://ffmpeg.org/releases/ffmpeg-8.1.2.tar.xz 464beb5e7bf0c311e68b45ae2f04e9cc2af88851abb4082231742a74d97b524c); abre ffmpeg "$d"
  ./configure --prefix="$P" "${FF[@]}" --pkg-config="$P/bin/pkgconf" --pkg-config-flags=--static --disable-autodetect --disable-shared --enable-static --disable-ffplay --disable-doc --disable-debug --enable-gpl --enable-version3 --enable-pthreads --enable-videotoolbox --enable-audiotoolbox --enable-zlib --enable-bzlib --enable-iconv --extra-libs=-liconv --enable-libx264 --enable-libvpx --enable-libopus --enable-libmp3lame --extra-cflags="-I$P/include $FA -mmacosx-version-min=13.5" --extra-ldflags="-L$P/lib $FA -mmacosx-version-min=13.5" >/dev/null
  make -j"$J" >/dev/null 2>&1; make install >/dev/null; cd "$ROOT"; hecho ffmpeg; fi
if [ ! -f "$W0/.hecho-cmake" ]; then d=$(baja cmake https://github.com/Kitware/CMake/releases/download/v4.1.2/cmake-4.1.2-macos-universal.tar.gz 3be85f5b999e327b1ac7d804cbc9acd767059e9f603c42ec2765f6ab68fbd367); mkdir -p "$W0/cmake"; tar -xf "$d" -C "$W0/cmake" --strip-components 1; touch "$W0/.hecho-cmake"; echo "✓ cmake · $(date +%T)"; fi
if ! ya whisper; then d=$(baja whisper https://github.com/ggml-org/whisper.cpp/archive/refs/tags/v1.9.1.tar.gz 147267177eef7b22ec3d2476dd514d1b12e160e176230b740e3d1bd600118447); abre whisper "$d"
  # (en Intel, sin Metal: whisper va por CPU con Accelerate)
  CRUZ_CMAKE=(); [ "$ARQ" = arm64 ] || CRUZ_CMAKE=(-DCMAKE_SYSTEM_NAME=Darwin -DCMAKE_SYSTEM_PROCESSOR=x86_64)
  "$W0/cmake/CMake.app/Contents/bin/cmake" -B build -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DWHISPER_BUILD_EXAMPLES=ON -DWHISPER_SDL2=OFF -DWHISPER_BUILD_TESTS=OFF -DGGML_METAL=$METAL -DGGML_METAL_EMBED_LIBRARY=$METAL -DGGML_NATIVE=OFF -DCMAKE_OSX_DEPLOYMENT_TARGET=13.5 -DCMAKE_OSX_ARCHITECTURES=$ARQ ${CRUZ_CMAKE[@]+"${CRUZ_CMAKE[@]}"} >/dev/null
  "$W0/cmake/CMake.app/Contents/bin/cmake" --build build --target whisper-cli -j"$J" >/dev/null 2>&1; cp build/bin/whisper-cli "$P/bin/"; cd "$ROOT"; hecho whisper; fi
swiftc -O -target "$ARQ-apple-macos13.5" scripts/lib/faces.swift -o "$P/bin/faces"; hecho faces

# lo que hay que comprobar antes de darlos por buenos: sin bibliotecas de fuera, con todo lo que usa el motor
for b in ffmpeg ffprobe whisper-cli faces; do if otool -L "$P/bin/$b" | tail -n +2 | grep -vE '^\s+/(usr/lib|System/Library)/' ; then echo "✗ $b enlaza fuera del sistema"; exit 1; fi; done
for b in ffmpeg ffprobe whisper-cli faces; do [ "$(lipo -archs "$P/bin/$b")" = "$ARQ" ] || { echo "✗ $b no es de $ARQ: $(lipo -archs "$P/bin/$b")"; exit 1; }; done
CODS="libx264 libvpx libvpx-vp9 aac pcm_s16le pcm_f32le pcm_s24le png mjpeg prores_ks libopus libmp3lame h264_videotoolbox"
FILS="loudnorm ebur128 silencedetect sidechaincompress alimiter alphaextract alphamerge erosion signalstats psnr ssim xfade colorspace setparams amix afade atrim adelay volume overlay scale crop pad fps setpts format"
if [ "$ARQ" = arm64 ] || arch -x86_64 /usr/bin/true 2>/dev/null; then
E=$("$P/bin/ffmpeg" -hide_banner -encoders 2>/dev/null); Fi=$("$P/bin/ffmpeg" -hide_banner -filters 2>/dev/null)
for x in $CODS; do echo "$E" | grep -q " $x " || { echo "✗ falta el codificador $x"; exit 1; }; done
for x in $FILS; do echo "$Fi" | grep -q " $x " || { echo "✗ falta el filtro $x"; exit 1; }; done
else
  # este Mac no puede ejecutarlos (son de Intel y no hay Rosetta): se mira lo que ffmpeg dejó compilado, en su configuración
  CC="$B/ffmpeg/config_components.h"; [ -f "$CC" ] || { echo "✗ no está $CC: no puedo comprobar los de Intel sin ejecutarlos (borra $W/.hecho-ffmpeg y repite)"; exit 1; }
  for x in $CODS; do n=$(echo "$x" | tr 'a-z-' 'A-Z_'); [ "$n" = LIBVPX ] && n=LIBVPX_VP8; grep -q "^#define CONFIG_${n}_ENCODER 1" "$CC" || { echo "✗ falta el codificador $x"; exit 1; }; done
  for x in $FILS; do n=$(echo "$x" | tr 'a-z' 'A-Z'); grep -q "^#define CONFIG_${n}_FILTER 1" "$CC" || { echo "✗ falta el filtro $x"; exit 1; }; done
  echo "· de Intel, sin ejecutar: comprobados por su arquitectura, sus bibliotecas y la configuración con la que se compiló ffmpeg"
fi
S="$W/salida/binarios"; mkdir -p "$S"; cp "$P/bin/ffmpeg" "$P/bin/ffprobe" "$P/bin/whisper-cli" "$P/bin/faces" "$S/"
( cd "$S" && COPYFILE_DISABLE=1 tar -czf "$W/salida/binarios.tgz" ffmpeg ffprobe whisper-cli faces )
echo "✓ binarios.tgz ($ARQ) · $(du -h "$W/salida/binarios.tgz" | cut -f1) · $(shasum -a 256 "$W/salida/binarios.tgz" | cut -d' ' -f1)"
