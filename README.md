# fftw2_arm64

CI check that FFTW 2.1.5 still builds on Apple Silicon (M-series) Macs.

FFTW 2.1.5 (1999) ships `config.sub` / `config.guess` scripts that
predate arm64, so on an M-series Mac `./configure` dies with:

```
configure: error: /bin/sh ./config.sub arm64-apple-darwinXX.X.X failed
```

## Fix

Swapping in a newer `config.sub` alone doesn't work — `configure.in`
uses pre-autoconf-2.68 `AC_DEFINE(SYMBOL)` syntax, which modern
autoconf rejects. The Debian `fftw` package has carried a patch for
this for years as `05_ac_define_syntax.diff`. Applying that and then
running `autoreconf -fvi` regenerates everything (configure,
config.sub, config.guess, Makefile.ins) using the host's current
autotools, which recognize `arm64-apple-darwin`.

[build.sh](build.sh) does the whole thing:

```sh
brew install autoconf automake libtool   # macOS prerequisites
./build.sh              # double precision (default)
./build.sh --single     # single precision
```

Under the hood the script:

1. Downloads `fftw-2.1.5.tar.gz` from fftw.org and unpacks it.
2. Applies [patches/05_ac_define_syntax.diff](patches/05_ac_define_syntax.diff)
   (vendored from [sources.debian.org/patches/fftw/2.1.5-6/](https://sources.debian.org/patches/fftw/2.1.5-6/))
   so `configure.in` uses autoconf-2.68+ compatible `AC_DEFINE` syntax.
3. Runs `autoreconf -fvi`, which regenerates `configure`, `config.sub`,
   `config.guess`, and the Makefile infrastructure using the host's
   current autotools — the new `config.sub`/`config.guess` recognize
   `arm64-apple-darwin`.
4. `./configure --disable-fortran`, `make -j`, and runs `fftw_test -s 64`.

## CI

[.github/workflows/build.yml](.github/workflows/build.yml) runs
`build.sh` on `macos-14` and `macos-15` runners (both Apple Silicon)
in a 2×2 matrix of OS × precision.

## References

- [Stack Overflow: How to install FFTW 2.1.5 on an M1 MacBook Pro](https://stackoverflow.com/questions/73030706/how-to-install-fftw-2-1-5-on-an-m1-macbook-pro)
- [pemsley/coot#33 (comment)](https://github.com/pemsley/coot/issues/33#issuecomment-1086901325) — where the answer points
- [MacPorts ticket #63527](https://trac.macports.org/ticket/63527) and the [fix commit](https://github.com/macports/macports-ports/commit/6ba320a2057eba4375c6f1fd135e7b38192bc0ac)
