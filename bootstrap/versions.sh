#!/usr/bin/env bash
set -Eeuo pipefail

# Central release defaults. Git-based scientific projects intentionally track
# their configured upstream branch; release-only dependencies remain explicit.
: "${JULIA_VERSION:=1.12.6}"
: "${GMP_VERSION:=6.3.0}"
: "${NTL_VERSION:=11.6.0}"
: "${MPFR_VERSION:=4.2.2}"
: "${FLINT_VERSION:=3.4.0}"
: "${GFAN_VERSION:=0.7}"
: "${CDDLIB_VERSION:=094i}"
: "${SINGULAR_TAG:=Release-4-4-1}"
: "${GO_TOOLCHAIN_VERSION:=1.26.5}"
: "${GIT_LFS_VERSION:=3.7.1}"
: "${LEAF_VERSION:=1.28.2}"
: "${CLANGD_TARBALL_VERSION:=21.1.6}"
: "${NVM_VERSION:=v0.40.4}"
: "${KRITA_VERSION:=5.2.11}"
: "${CLANGD_INSTALL_METHOD_DEFAULT:=tar}"
: "${GIT_LFS_INSTALL_METHOD_DEFAULT:=git}"
: "${NOTMUCH_VERSION:=0.40}"
: "${ISYNC_VERSION:=1.5.1}"
: "${MSMTP_VERSION:=1.8.32}"
: "${NEOMUTT_VERSION:=20260504}"
: "${POLYMAKE_VERSION:=4.15}"
: "${CLANGD_GIT_REF:=llvmorg-21.1.6}"
