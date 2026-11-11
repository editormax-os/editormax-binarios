# EditorMax OS · binarios

Los programas de vídeo que EditorMax OS instala en un Mac: `ffmpeg`, `ffprobe`, `whisper-cli` y `faces`. Enlazados de forma estática, para
macOS 13.5 o posterior. El instalador de EditorMax los baja de aquí y comprueba su huella; no hace falta bajarlos a mano.

| Archivo | Para | sha256 |
|---|---|---|
| `binarios-darwin-arm64.tgz` | Mac con chip Apple | `a61233bc7ca4cd3d8672ddf85f40d0cacf96e2bbf920104bda87b566b7353104` |
| `binarios-darwin-x64.tgz` | Mac con Intel | `aa13a18285e94338f4e7ffe153887f354303775495611ce7c79cfd1a3fd7ab4f` |

## Licencias y código fuente

`ffmpeg` y `ffprobe` se distribuyen bajo la **GNU General Public License, versión 3** ([COPYING.GPLv3](COPYING.GPLv3)): se compilan con
`--enable-gpl --enable-version3` e incluyen x264 (GPL), libvpx (BSD), Opus (BSD) y LAME (LGPL). Su código fuente completo y correspondiente va
en esta misma release: las tarballs exactas con las que se compilaron, sin modificar, y el guion que los compila con su configuración
([construir.sh](construir.sh)).

| Fuente | Versión | Licencia |
|---|---|---|
| `ffmpeg-8.1.2.tar.xz` | FFmpeg 8.1.2 | GPL v3 (con esta configuración) |
| `x264-b35605ace3ddf7c1a5d67a2eb553f034aef41d55.tar.bz2` | x264, commit b35605a | GPL v2 o posterior |
| `libvpx-1.16.0.tar.gz` | libvpx 1.16.0 | BSD de 3 cláusulas |
| `lame-4.0.tar.gz` | LAME 4.0 | LGPL |
| `opus-1.6.1.tar.gz` | Opus 1.6.1 | BSD de 3 cláusulas |
| `whisper.cpp-1.9.1.tar.gz` | whisper.cpp 1.9.1 | MIT |

`whisper-cli` es whisper.cpp sin modificar (MIT). `faces` es un programa propio de EditorMax (detecta caras con el framework Vision de Apple);
no deriva de código GPL y no se enlaza con ffmpeg.

Las huellas de todo, en [SHA256SUMS](SHA256SUMS).

## Cómo se compilan

```
/bin/bash construir.sh            # Mac con chip Apple (arm64)
/bin/bash construir.sh x86_64     # Mac con Intel, compilación cruzada desde un Mac con chip Apple
```

El guion baja cada fuente, comprueba su huella, compila sin Homebrew y sin instalar nada fuera de su carpeta, y comprueba el resultado: que
ningún binario enlaza una biblioteca de fuera del sistema y que ffmpeg trae los codificadores y los filtros que EditorMax usa. Herramientas
de compilación que usa y no se distribuyen: pkgconf 3.0.10, nasm 2.16.03 (para x86_64) y CMake 4.1.2.
