#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
CORES_DIR="${AIOS_CORES_DIR:-$REPO_ROOT/.memory/cores}"
GEODATA_DIR="$CORES_DIR/geodata"
XRAY_SRC="${XRAY_SRC:-$REPO_ROOT/../Xray-core}"
V2RAY_SRC="${V2RAY_SRC:-$REPO_ROOT/../v2ray-core}"
LUCI_CORES="${LUCI_CORES:-$REPO_ROOT/../luci-app-aios/.memory/cores}"

XRAY_VERSIONS=( v25.9.11 v26.5.3 v26.5.9 v26.6.22 v26.6.27 v26.11.9 )
V2RAY_VERSIONS=( v5.18.0 v5.56.0 )

mkdir -p "$CORES_DIR/xray" "$CORES_DIR/v2ray" "$GEODATA_DIR"

detect_arch()
{
    local core="$1"
    local os_name arch_name
    os_name=$(uname -s | tr '[:upper:]' '[:lower:]')
    arch_name=$(uname -m)
    if [ "$os_name" == "darwin" ]
    then
        case "$arch_name" in
            arm64|aarch64) echo "macos-arm64-v8a" ;;
            x86_64|amd64) echo "macos-64" ;;
            *) return 1 ;;
        esac
    elif [ "$os_name" == "linux" ]
    then
        case "$arch_name" in
            x86_64|amd64) echo "linux-64" ;;
            aarch64|arm64) echo "linux-arm64-v8a" ;;
            armv7l) echo "linux-arm32-v7a" ;;
            *) return 1 ;;
        esac
    else
        return 1
    fi
}

verify_dgst()
{
    local f="$1" dgst="$2"
    local expected actual
    expected=$(awk 'toupper($0) ~ /SHA2-?256/ {print tolower($NF); exit}' "$dgst" 2> /dev/null || true)
    [ -z "$expected" ] && expected=$(awk '{print tolower($1); exit}' "$dgst" 2> /dev/null || true)
    [[ "$expected" =~ ^[0-9a-f]{64}$ ]] || return 1
    if command -v sha256sum > /dev/null 2>&1
    then
        actual=$(sha256sum "$f" | awk '{print tolower($1)}')
    else
        actual=$(shasum -a 256 "$f" | awk '{print tolower($1)}')
    fi
    [ "$actual" == "$expected" ]
}

build_from_source()
{
    local core="$1" tag="$2" dst="$3"
    local src_repo="$XRAY_SRC" pkg="./main"
    [ "$core" == "v2ray" ] && src_repo="$V2RAY_SRC"

    if [ ! -d "$src_repo/.git" ] || ! command -v go > /dev/null 2>&1
    then
        return 1
    fi

    local wt
    wt=$(mktemp -d "${TMPDIR:-/tmp}/aios-wt-${core}-${tag}.XXXXXX")
    if git -C "$src_repo" worktree add --detach "$wt" "$tag" > /dev/null 2>&1
    then
        (
            cd "$wt"
            CGO_ENABLED=0 go build -trimpath -buildvcs=false -ldflags "-s -w" -o "$dst" "$pkg"
        )
        local rc=$?
        git -C "$src_repo" worktree remove --force "$wt" > /dev/null 2>&1 || true
        rm -rf "$wt"
        return "$rc"
    fi
    rm -rf "$wt"
    return 1
}

fetch_core()
{
    local core="$1" tag="$2"
    local dst_dir="$CORES_DIR/$core/$tag"
    local dst_bin="$dst_dir/$core"

    if [ -x "$dst_bin" ]
    then
        printf '[OK] %s %s already present\n' "$core" "$tag"
        return 0
    fi

    mkdir -p "$dst_dir"

    if [ -x "$LUCI_CORES/$core/$tag/$core" ]
    then
        cp "$LUCI_CORES/$core/$tag/$core" "$dst_bin"
        chmod 755 "$dst_bin"
        printf '[COPY] %s %s from luci-app-aios/.memory/cores\n' "$core" "$tag"
        return 0
    fi

    local arch repo prefix
    arch=$(detect_arch "$core")
    if [ "$core" == "xray" ]
    then
        repo="XTLS/Xray-core"
        prefix="Xray"
    else
        repo="v2fly/v2ray-core"
        prefix="v2ray"
    fi

    local tmpd
    tmpd=$(mktemp -d "${TMPDIR:-/tmp}/aios-fetch-${core}.XXXXXX")
    local url="https://github.com/${repo}/releases/download/${tag}/${prefix}-${arch}.zip"
    if curl -fsSL -m 60 "$url" -o "$tmpd/pkg.zip" && curl -fsSL -m 30 "${url}.dgst" -o "$tmpd/pkg.zip.dgst" && verify_dgst "$tmpd/pkg.zip" "$tmpd/pkg.zip.dgst"
    then
        unzip -qo "$tmpd/pkg.zip" "$core" -d "$tmpd/out"
        mv -f "$tmpd/out/$core" "$dst_bin"
        chmod 755 "$dst_bin"
        rm -rf "$tmpd"
        printf '[DL] %s %s verified\n' "$core" "$tag"
        return 0
    fi
    rm -rf "$tmpd"

    if build_from_source "$core" "$tag" "$dst_bin"
    then
        chmod 755 "$dst_bin"
        printf '[BUILD] %s %s built from local source\n' "$core" "$tag"
        return 0
    fi

    printf '[FAIL] unable to obtain %s %s\n' "$core" "$tag" >&2
    return 1
}

fetch_geodata()
{
    if [ -s "$GEODATA_DIR/geoip.dat" ] && [ -s "$GEODATA_DIR/geosite.dat" ]
    then
        printf '[OK] geodata already present\n'
        return 0
    fi

    if [ -s "$LUCI_CORES/geodata/geoip.dat" ] && [ -s "$LUCI_CORES/geodata/geosite.dat" ]
    then
        cp "$LUCI_CORES/geodata/geoip.dat" "$GEODATA_DIR/geoip.dat"
        cp "$LUCI_CORES/geodata/geosite.dat" "$GEODATA_DIR/geosite.dat"
        printf '[COPY] geodata from luci-app-aios/.memory/cores\n'
        return 0
    fi

    local tag="202611222203"
    local base="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/download/${tag}"
    local tmpd
    tmpd=$(mktemp -d "${TMPDIR:-/tmp}/aios-geo.XXXXXX")
    for f in geoip.dat geosite.dat
    do
        curl -fsSL -m 60 "${base}/${f}" -o "$tmpd/${f}"
        curl -fsSL -m 30 "${base}/${f}.sha256sum" -o "$tmpd/${f}.sha256sum"
        verify_dgst "$tmpd/${f}" "$tmpd/${f}.sha256sum"
        mv -f "$tmpd/${f}" "$GEODATA_DIR/${f}"
    done
    rm -rf "$tmpd"
    printf '[DL] geodata %s verified\n' "$tag"
}

sha256_of()
{
    if command -v sha256sum > /dev/null 2>&1
    then
        sha256sum "$1" | awk '{print tolower($1)}'
    else
        shasum -a 256 "$1" | awk '{print tolower($1)}'
    fi
}

verify_pinned_sha()
{
    local key="$1" file="$2"
    local sha_file="${AIOS_CORES_SHA256_FILE:-$SCRIPT_DIR/test_cores.sha256}"
    local actual="" expected="" pinned_found=0
    actual=$(sha256_of "$file")
    if [ -n "$sha_file" ] && [ -s "$sha_file" ]
    then
        expected=$(awk -v k="$key" '!/^#/ && $2 == k {print tolower($1); exit}' "$sha_file" 2> /dev/null || true)
        if [ -n "$expected" ]
        then
            pinned_found=1
            if [ "$actual" != "$expected" ]
            then
                printf '[FAIL] pinned SHA256 mismatch for %s (expected=%s actual=%s)\n' "$key" "$expected" "$actual" >&2
                return 1
            fi
        elif [ "${AIOS_REQUIRE_PINNED_SHA256:-0}" == "1" ]
        then
            printf '[FAIL] missing pinned SHA256 entry for %s in %s\n' "$key" "$sha_file" >&2
            return 1
        fi
    fi

    if [ -s "${file}.sha256" ]
    then
        expected=$(awk '{print tolower($1); exit}' "${file}.sha256" 2> /dev/null || true)
        if [ -n "$expected" ] && [ "$actual" != "$expected" ]
        then
            printf '[FAIL] sidecar SHA256 mismatch for %s (expected=%s actual=%s)\n' "$key" "$expected" "$actual" >&2
            return 1
        fi
    elif [ "$pinned_found" -eq 1 ] || [ "${AIOS_REQUIRE_PINNED_SHA256:-0}" != "1" ]
    then
        printf '%s  %s\n' "$actual" "$key" > "${file}.sha256"
    fi
    return 0
}

fetch_geodata
verify_pinned_sha "geodata/geoip.dat" "$GEODATA_DIR/geoip.dat"
verify_pinned_sha "geodata/geosite.dat" "$GEODATA_DIR/geosite.dat"

HOST_ARCH=$(detect_arch xray)
for v in "${XRAY_VERSIONS[@]}"
do
    fetch_core xray "$v"
    verify_pinned_sha "xray/${v}/${HOST_ARCH}/xray" "$CORES_DIR/xray/${v}/xray"
done
for v in "${V2RAY_VERSIONS[@]}"
do
    fetch_core v2ray "$v"
    verify_pinned_sha "v2ray/${v}/${HOST_ARCH}/v2ray" "$CORES_DIR/v2ray/${v}/v2ray"
done
