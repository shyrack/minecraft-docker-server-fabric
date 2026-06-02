#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0

pass() { PASS=$((PASS+1)); echo "  ✓ $1"; }
fail() { FAIL=$((FAIL+1)); echo "  ✗ $1"; echo "    $2"; }

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then pass "$desc"; else fail "$desc" "expected: '$expected'  actual: '$actual'"; fi
}

assert_not_empty() {
    local desc="$1" value="$2"
    if [ -n "$value" ]; then pass "$desc"; else fail "$desc" "expected non-empty value"; fi
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROVIDERS="${SCRIPT_DIR}/../scripts/providers"
RUNTIME="${SCRIPT_DIR}/../scripts/runtime-functions.sh"

echo "=== Provider: fabric ==="

test_fabric_resolve() {
    local mc
    mc=$(MINECRAFT_VERSION=latest \
        FABRIC_LOADER=latest \
        FABRIC_INSTALLER=latest \
        bash -c '
            wget() {
                case "$*" in
                    *versions/game*)      echo "[{\"version\":\"1.25.0\",\"stable\":true},{\"version\":\"1.25.1-pre1\",\"stable\":false}]" ;;
                    *versions/loader/1.25.0*) echo "[{\"loader\":{\"version\":\"0.17.2\",\"stable\":true}},{\"loader\":{\"version\":\"0.17.3-beta\",\"stable\":false}}]" ;;
                    *versions/installer*) echo "[{\"version\":\"1.2.0\",\"stable\":true},{\"version\":\"2.0.0-beta\",\"stable\":false}]" ;;
                esac
            }
            export -f wget
            source "'"$RUNTIME"'" > /dev/null 2>&1
            source "'"$PROVIDERS"'/fabric.sh" > /dev/null 2>&1
            provider_resolve_version > /dev/null 2>&1
            echo "$MINECRAFT_VERSION $FABRIC_LOADER $FABRIC_INSTALLER"
        ')
    assert_eq "resolves MC version"     "1.25.0" "$(echo "$mc" | awk '{print $1}')"
    assert_eq "resolves Fabric loader"  "0.17.2" "$(echo "$mc" | awk '{print $2}')"
    assert_eq "resolves Fabric installer" "1.2.0" "$(echo "$mc" | awk '{print $3}')"
}

test_fabric_pinned() {
    local out
    out=$(MINECRAFT_VERSION=1.21.4 \
        FABRIC_LOADER=0.16.10 \
        FABRIC_INSTALLER=1.1.1 \
        bash -c '
            wget() { echo "UNEXPECTED_WGET_CALL"; }
            export -f wget
            source "'"$RUNTIME"'" > /dev/null 2>&1
            source "'"$PROVIDERS"'/fabric.sh" > /dev/null 2>&1
            provider_resolve_version > /dev/null 2>&1
            echo "$MINECRAFT_VERSION $FABRIC_LOADER $FABRIC_INSTALLER"
        ')
    assert_eq "pinned MC version kept"      "1.21.4" "$(echo "$out" | awk '{print $1}')"
    assert_eq "pinned Fabric loader kept"   "0.16.10" "$(echo "$out" | awk '{print $2}')"
    assert_eq "pinned Fabric installer kept" "1.1.1" "$(echo "$out" | awk '{print $3}')"
}

test_fabric_jar() {
    local jar
    jar=$(bash -c "source '${RUNTIME}' > /dev/null 2>&1; source '${PROVIDERS}/fabric.sh' > /dev/null 2>&1; provider_get_jar")
    assert_eq "JAR name is server.jar" "server.jar" "$jar"
}

test_fabric_launch_args() {
    local args
    args=$(bash -c "source '${RUNTIME}' > /dev/null 2>&1; source '${PROVIDERS}/fabric.sh' > /dev/null 2>&1; provider_get_launch_args")
    assert_eq "launch args include nogui" "nogui" "$args"
}

test_fabric_resolve
test_fabric_pinned
test_fabric_jar
test_fabric_launch_args
echo

echo "=== Provider: vanilla ==="

test_vanilla_resolve() {
    local mc
    mc=$(MINECRAFT_VERSION=latest bash -c '
        wget() {
            case "$*" in
                *version_manifest*)
                    echo "{\"latest\":{\"release\":\"1.25.0\",\"snapshot\":\"1.25.1-pre1\"}}"
                    ;;
                *) echo "UNEXPECTED_WGET: $*" ;;
            esac
        }
        export -f wget
        source "'"$RUNTIME"'" > /dev/null 2>&1
        source "'"$PROVIDERS"'/vanilla.sh" > /dev/null 2>&1
        provider_resolve_version > /dev/null 2>&1
        echo "$MINECRAFT_VERSION"
    ')
    assert_eq "resolves latest vanilla MC version" "1.25.0" "$mc"
}

test_vanilla_pinned() {
    local mc
    mc=$(MINECRAFT_VERSION=1.21.4 bash -c '
        wget() { echo "UNEXPECTED_WGET: $*"; }
        export -f wget
        source "'"$RUNTIME"'" > /dev/null 2>&1
        source "'"$PROVIDERS"'/vanilla.sh" > /dev/null 2>&1
        provider_resolve_version > /dev/null 2>&1
        echo "$MINECRAFT_VERSION"
    ')
    assert_eq "pinned vanilla MC version kept" "1.21.4" "$mc"
}

test_vanilla_jar() {
    local jar
    jar=$(bash -c "source '${RUNTIME}' > /dev/null 2>&1; source '${PROVIDERS}/vanilla.sh' > /dev/null 2>&1; provider_get_jar")
    assert_eq "JAR name is server.jar" "server.jar" "$jar"
}

test_vanilla_launch_args() {
    local args
    args=$(bash -c "source '${RUNTIME}' > /dev/null 2>&1; source '${PROVIDERS}/vanilla.sh' > /dev/null 2>&1; provider_get_launch_args")
    assert_eq "launch args include nogui" "nogui" "$args"
}

test_vanilla_download_url() {
    local url
    url=$(MINECRAFT_VERSION=1.25.0 bash -c '
        wget() {
            case "$*" in
                *version_manifest*)
                    echo "{\"versions\":[{\"id\":\"1.25.0\",\"url\":\"https://example.com/1.25.0.json\"}]}"
                    ;;
                *1.25.0.json*)
                    echo "{\"downloads\":{\"server\":{\"url\":\"https://example.com/server.jar\"}}}"
                    ;;
                *server.jar*)
                    printf "PK\x03\x04" > server.jar
                    echo "downloaded"
                    ;;
                *) echo "UNEXPECTED_WGET: $*" ;;
            esac
        }
        export -f wget
        source "'"$RUNTIME"'" > /dev/null 2>&1
        source "'"$PROVIDERS"'/vanilla.sh" > /dev/null 2>&1
        provider_download_server > /dev/null 2>&1
        [ -f server.jar ] && echo "OK" || echo "FAIL"
    ')
    assert_eq "vanilla download creates server.jar" "OK" "$url"
}

test_vanilla_resolve
test_vanilla_pinned
test_vanilla_jar
test_vanilla_launch_args
test_vanilla_download_url
echo

echo "=== Provider: paper ==="

test_paper_resolve() {
    local result
    result=$(MINECRAFT_VERSION=latest PAPER_BUILD=latest bash -c '
        wget() {
            case "$*" in
                */builds*) echo "{\"builds\":[{\"build\":100,\"version\":\"1.25.0\"},{\"build\":200,\"version\":\"1.25.0\"},{\"build\":300,\"version\":\"1.25.0\"}]}" ;;
                *projects/paper) echo "{\"project_id\":\"paper\",\"versions\":[\"1.20.4\",\"1.21.4\",\"1.25.0\"]}" ;;
                *) echo "UNEXPECTED_WGET: $*" ;;
            esac
        }
        export -f wget
        source "'"$RUNTIME"'" > /dev/null 2>&1
        source "'"$PROVIDERS"'/paper.sh" > /dev/null 2>&1
        provider_resolve_version > /dev/null 2>&1
        echo "$MINECRAFT_VERSION $PAPER_BUILD"
    ')
    assert_eq "resolves paper MC version" "1.25.0" "$(echo "$result" | awk '{print $1}')"
    assert_eq "resolves paper latest build" "300" "$(echo "$result" | awk '{print $2}')"
}

test_paper_pinned() {
    local result
    result=$(MINECRAFT_VERSION=1.21.4 PAPER_BUILD=150 bash -c '
        wget() { echo "UNEXPECTED_WGET: $*"; }
        export -f wget
        source "'"$RUNTIME"'" > /dev/null 2>&1
        source "'"$PROVIDERS"'/paper.sh" > /dev/null 2>&1
        provider_resolve_version > /dev/null 2>&1
        echo "$MINECRAFT_VERSION $PAPER_BUILD"
    ')
    assert_eq "pinned paper MC version" "1.21.4" "$(echo "$result" | awk '{print $1}')"
    assert_eq "pinned paper build" "150" "$(echo "$result" | awk '{print $2}')"
}

test_paper_jar() {
    local jar
    jar=$(bash -c "source '${RUNTIME}' > /dev/null 2>&1; source '${PROVIDERS}/paper.sh' > /dev/null 2>&1; provider_get_jar")
    assert_eq "JAR name is paper.jar" "paper.jar" "$jar"
}

test_paper_launch_args() {
    local args
    args=$(bash -c "source '${RUNTIME}' > /dev/null 2>&1; source '${PROVIDERS}/paper.sh' > /dev/null 2>&1; provider_get_launch_args")
    assert_eq "launch args include nogui" "nogui" "$args"
}

test_paper_resolve
test_paper_pinned
test_paper_jar
test_paper_launch_args
echo

echo "=== Provider: spigot ==="

test_spigot_resolve() {
    local mc
    mc=$(MINECRAFT_VERSION=latest bash -c '
        wget() {
            case "$*" in
                *version_manifest*)
                    echo "{\"latest\":{\"release\":\"1.25.0\",\"snapshot\":\"1.25.1-pre1\"}}"
                    ;;
                *) echo "UNEXPECTED_WGET: $*" ;;
            esac
        }
        export -f wget
        source "'"$RUNTIME"'" > /dev/null 2>&1
        source "'"$PROVIDERS"'/spigot.sh" > /dev/null 2>&1
        provider_resolve_version > /dev/null 2>&1
        echo "$MINECRAFT_VERSION"
    ')
    assert_eq "resolves spigot MC version" "1.25.0" "$mc"
}

test_spigot_pinned() {
    local mc
    mc=$(MINECRAFT_VERSION=1.21.4 bash -c '
        wget() { echo "UNEXPECTED_WGET: $*"; }
        export -f wget
        source "'"$RUNTIME"'" > /dev/null 2>&1
        source "'"$PROVIDERS"'/spigot.sh" > /dev/null 2>&1
        provider_resolve_version > /dev/null 2>&1
        echo "$MINECRAFT_VERSION"
    ')
    assert_eq "pinned spigot MC version" "1.21.4" "$mc"
}

test_spigot_jar() {
    local jar
    jar=$(bash -c "source '${RUNTIME}' > /dev/null 2>&1; source '${PROVIDERS}/spigot.sh' > /dev/null 2>&1; provider_get_jar")
    assert_eq "JAR name is spigot.jar" "spigot.jar" "$jar"
}

test_spigot_launch_args() {
    local args
    args=$(bash -c "source '${RUNTIME}' > /dev/null 2>&1; source '${PROVIDERS}/spigot.sh' > /dev/null 2>&1; provider_get_launch_args")
    assert_eq "launch args include nogui" "nogui" "$args"
}

test_spigot_resolve
test_spigot_pinned
test_spigot_jar
test_spigot_launch_args
echo

echo "=== Provider: forge ==="

test_forge_resolve() {
    local result
    result=$(MINECRAFT_VERSION=latest FORGE_VERSION=latest bash -c '
        wget() {
            case "$*" in
                *version_manifest*)
                    echo "{\"latest\":{\"release\":\"1.25.0\",\"snapshot\":\"1.25.1-pre1\"}}"
                    ;;
                *promotions_slim.json*)
                    echo "{\"promos\":{\"1.25.0-recommended\":\"54.0.0\",\"1.25.0-latest\":\"54.0.0\",\"1.24.0-recommended\":\"53.5.0\"}}"
                    ;;
                *) echo "UNEXPECTED_WGET: $*" ;;
            esac
        }
        export -f wget
        source "'"$RUNTIME"'" > /dev/null 2>&1
        source "'"$PROVIDERS"'/forge.sh" > /dev/null 2>&1
        provider_resolve_version > /dev/null 2>&1
        echo "$MINECRAFT_VERSION $FORGE_VERSION $FORGE_COMBINED"
    ')
    assert_eq "resolves forge MC version" "1.25.0" "$(echo "$result" | awk '{print $1}')"
    assert_eq "resolves forge version" "54.0.0" "$(echo "$result" | awk '{print $2}')"
    assert_eq "combined forge version" "1.25.0-54.0.0" "$(echo "$result" | awk '{print $3}')"
}

test_forge_pinned() {
    local result
    result=$(MINECRAFT_VERSION=1.21.4 FORGE_VERSION=53.5.0 bash -c '
        wget() { echo "UNEXPECTED_WGET: $*"; }
        export -f wget
        source "'"$RUNTIME"'" > /dev/null 2>&1
        source "'"$PROVIDERS"'/forge.sh" > /dev/null 2>&1
        provider_resolve_version > /dev/null 2>&1
        echo "$MINECRAFT_VERSION $FORGE_VERSION $FORGE_COMBINED"
    ')
    assert_eq "pinned forge MC version" "1.21.4" "$(echo "$result" | awk '{print $1}')"
    assert_eq "pinned forge version" "53.5.0" "$(echo "$result" | awk '{print $2}')"
    assert_eq "pinned combined forge" "1.21.4-53.5.0" "$(echo "$result" | awk '{print $3}')"
}

test_forge_jar() {
    local jar
    jar=$(bash -c "source '${RUNTIME}' > /dev/null 2>&1; source '${PROVIDERS}/forge.sh' > /dev/null 2>&1; provider_get_jar")
    assert_eq "forge JAR name is empty" "" "$jar"
}

test_forge_launch_args() {
    local args
    args=$(FORGE_COMBINED=1.25.0-54.0.0 bash -c "
        source '${RUNTIME}' > /dev/null 2>&1
        source '${PROVIDERS}/forge.sh' > /dev/null 2>&1
        provider_get_launch_args
    ")
    assert_eq "forge launch args contain unix_args.txt" \
        "@libraries/net/minecraftforge/forge/1.25.0-54.0.0/unix_args.txt nogui" "$args"
}

test_forge_resolve
test_forge_pinned
test_forge_jar
test_forge_launch_args
echo

echo "=== Provider: neoforge ==="

test_neoforge_resolve() {
    local result
    result=$(MINECRAFT_VERSION=latest NEOFORGE_VERSION=latest bash -c '
        wget() {
            case "$*" in
                *maven-metadata.xml*)
                    echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?><metadata><groupId>net.neoforged</groupId><artifactId>neoforge</artifactId><versioning><release>1.25.0-3.5.18</release><versions><version>1.25.0-3.5.16</version><version>1.25.0-3.5.17</version><version>1.25.0-3.5.18</version></versions></versioning></metadata>"
                    ;;
                *) echo "UNEXPECTED_WGET: $*" ;;
            esac
        }
        export -f wget
        source "'"$RUNTIME"'" > /dev/null 2>&1
        source "'"$PROVIDERS"'/neoforge.sh" > /dev/null 2>&1
        provider_resolve_version > /dev/null 2>&1
        echo "$MINECRAFT_VERSION $NEOFORGE_VERSION"
    ')
    assert_eq "resolves neoforge MC version" "1.25.0" "$(echo "$result" | awk '{print $1}')"
    assert_eq "resolves neoforge version" "1.25.0-3.5.18" "$(echo "$result" | awk '{print $2}')"
}

test_neoforge_pinned() {
    local result
    result=$(MINECRAFT_VERSION=1.21.4 NEOFORGE_VERSION=1.21.4-3.0.16 bash -c '
        wget() { echo "UNEXPECTED_WGET: $*"; }
        export -f wget
        source "'"$RUNTIME"'" > /dev/null 2>&1
        source "'"$PROVIDERS"'/neoforge.sh" > /dev/null 2>&1
        provider_resolve_version > /dev/null 2>&1
        echo "$MINECRAFT_VERSION $NEOFORGE_VERSION"
    ')
    assert_eq "pinned neoforge MC version" "1.21.4" "$(echo "$result" | awk '{print $1}')"
    assert_eq "pinned neoforge version" "1.21.4-3.0.16" "$(echo "$result" | awk '{print $2}')"
}

test_neoforge_pinned_mc_with_latest_neoforge() {
    local result
    result=$(MINECRAFT_VERSION=1.21.4 NEOFORGE_VERSION=latest bash -c '
        wget() {
            case "$*" in
                *maven-metadata.xml*)
                    echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?><metadata><groupId>net.neoforged</groupId><artifactId>neoforge</artifactId><versioning><release>1.25.0-3.5.18</release><versions><version>1.21.4-3.0.16</version><version>1.21.4-3.0.17</version><version>1.25.0-3.5.16</version><version>1.25.0-3.5.18</version></versions></versioning></metadata>"
                    ;;
                *) echo "UNEXPECTED_WGET: $*" ;;
            esac
        }
        export -f wget
        source "'"$RUNTIME"'" > /dev/null 2>&1
        source "'"$PROVIDERS"'/neoforge.sh" > /dev/null 2>&1
        provider_resolve_version > /dev/null 2>&1
        echo "$MINECRAFT_VERSION $NEOFORGE_VERSION"
    ')
    assert_eq "pinned MC with latest NEOFORGE keeps MC version" "1.21.4" "$(echo "$result" | awk '{print $1}')"
    assert_eq "pinned MC with latest NEOFORGE resolves correct neoforge" "1.21.4-3.0.17" "$(echo "$result" | awk '{print $2}')"
}

test_neoforge_jar() {
    local jar
    jar=$(bash -c "source '${RUNTIME}' > /dev/null 2>&1; source '${PROVIDERS}/neoforge.sh' > /dev/null 2>&1; provider_get_jar")
    assert_eq "neoforge JAR name is empty" "" "$jar"
}

test_neoforge_launch_args() {
    local args
    args=$(NEOFORGE_VERSION=1.25.0-3.5.18 bash -c "
        source '${RUNTIME}' > /dev/null 2>&1
        source '${PROVIDERS}/neoforge.sh' > /dev/null 2>&1
        provider_get_launch_args
    ")
    assert_eq "neoforge launch args contain unix_args.txt" \
        "@libraries/net/neoforged/neoforge/1.25.0-3.5.18/unix_args.txt nogui" "$args"
}

test_neoforge_resolve
test_neoforge_pinned
test_neoforge_pinned_mc_with_latest_neoforge
test_neoforge_jar
test_neoforge_launch_args
echo

echo "============================="
printf "Results: %d passed, %d failed\n" "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
    echo "SOME TESTS FAILED"
    exit 1
else
    echo "ALL PROVIDER TESTS PASSED"
fi
