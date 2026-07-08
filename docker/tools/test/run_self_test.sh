#!/usr/bin/env bash
# Self-test for the deploy-time interface-admission gate (docker/tools/deploy_check.sh).
#
# It builds a dedicated ADMIT_TOOL_IMAGE that contains manifest_admit from
# autoware_component_interface_admission, builds a matrix of label-only fixture images (each
# carrying a fixture interface manifest as the OCI label org.autoware.interface_manifest), and
# asserts deploy_check.sh's exit code on four composed image sets:
#   compatible   -> 0 (accepted)
#   incompatible -> 1 (MAJOR mismatch)
#   no-provider  -> 1 (required interface with no provider in the set)
#   unlabeled    -> 2 (a present image lacks the conformance label)
#
# Admission-tool source — two modes:
#   * UNIVERSE_LOCAL_PATH=<dir>  build the package from a local checkout (the developer loop). The
#                                package is located under <dir>; the build runs in BUILD_BASE_IMAGE
#                                (default autoware:universe-devel-jazzy).
#   * otherwise (CI default)     git clone --depth 1 --branch "${UNIVERSE_REF}"
#                                "https://github.com/${UNIVERSE_REPO}" and build the package from it
#                                (BUILD_BASE_IMAGE default
#                                ghcr.io/autowarefoundation/autoware:universe-devel-jazzy).
#     UNIVERSE_REPO defaults to autowarefoundation/autoware_universe, UNIVERSE_REF to main. Until
#     the admission package merges into autoware_universe, the default clone will not contain it and
#     the run fails fast with a clear message — this job is advisory (non-required) for that reason.
#
# All images this script builds are tagged oss-if-gate-self-test-* and removed on exit (best effort).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEPLOY_CHECK="${TOOLS_DIR}/deploy_check.sh"
FIXTURES="${SCRIPT_DIR}/fixtures"

TAG_PREFIX="oss-if-gate-self-test-"
TOOL_IMAGE="${TAG_PREFIX}admit-tool"
export ADMIT_TOOL_IMAGE="${TOOL_IMAGE}"

UNIVERSE_REPO="${UNIVERSE_REPO:-autowarefoundation/autoware_universe}"
UNIVERSE_REF="${UNIVERSE_REF:-main}"
RUNTIME_BASE_IMAGE="${RUNTIME_BASE_IMAGE:-ros:jazzy-ros-base}"

workdir="$(mktemp -d)"
built_images=()

cleanup() {
    local st=$?
    for img in "${built_images[@]:-}"; do
        [ -n "${img}" ] || continue
        docker rmi -f "${img}" >/dev/null 2>&1 || true
    done
    rm -rf "${workdir}"
    exit "${st}"
}
trap cleanup EXIT

log() { echo "[self-test] $*"; }
fail() {
    echo "[self-test] FAIL: $*" >&2
    exit 1
}

# ---- 1. Resolve the admission-package source ------------------------------------------------
mkdir -p "${workdir}/src"
pkg_src="${workdir}/src/autoware_component_interface_admission"
if [ -n "${UNIVERSE_LOCAL_PATH:-}" ]; then
    log "using local admission source under ${UNIVERSE_LOCAL_PATH}"
    found="$(find "${UNIVERSE_LOCAL_PATH}" -type d -name autoware_component_interface_admission -print -quit)"
    [ -n "${found}" ] || fail "autoware_component_interface_admission not found under ${UNIVERSE_LOCAL_PATH}"
    cp -r "${found}" "${pkg_src}"
    BUILD_BASE_IMAGE="${BUILD_BASE_IMAGE:-autoware:universe-devel-jazzy}"
else
    log "cloning ${UNIVERSE_REPO}@${UNIVERSE_REF} (depth 1)"
    clone="${workdir}/universe"
    git clone --depth 1 --branch "${UNIVERSE_REF}" "https://github.com/${UNIVERSE_REPO}.git" "${clone}"
    found="$(find "${clone}" -type d -name autoware_component_interface_admission -print -quit)"
    [ -n "${found}" ] || fail "autoware_component_interface_admission not present in ${UNIVERSE_REPO}@${UNIVERSE_REF} (has the universe package merged yet?)"
    cp -r "${found}" "${pkg_src}"
    BUILD_BASE_IMAGE="${BUILD_BASE_IMAGE:-ghcr.io/autowarefoundation/autoware:universe-devel-jazzy}"
fi

# ---- 2. Build the dedicated ADMIT_TOOL_IMAGE ------------------------------------------------
cp "${SCRIPT_DIR}/admit-tool.Dockerfile" "${workdir}/Dockerfile"
cp "${SCRIPT_DIR}/admit-tool-entrypoint.sh" "${workdir}/entrypoint.sh"
log "building ${TOOL_IMAGE} (build base ${BUILD_BASE_IMAGE}, runtime base ${RUNTIME_BASE_IMAGE})"
DOCKER_BUILDKIT=1 docker build \
    --build-arg "BUILD_BASE_IMAGE=${BUILD_BASE_IMAGE}" \
    --build-arg "RUNTIME_BASE_IMAGE=${RUNTIME_BASE_IMAGE}" \
    -t "${TOOL_IMAGE}" "${workdir}"
built_images+=("${TOOL_IMAGE}")

# ---- 3. Build the label-only fixture images -------------------------------------------------
# Each labeled image carries its fixture manifest (minified + validated) as the OCI label; the
# unlabeled image carries none. FROM scratch keeps them empty — the gate only reads metadata.
build_labeled() {
    local tag="$1" manifest_json="$2" minified
    minified="$(python3 -c 'import json,sys; print(json.dumps(json.load(open(sys.argv[1]))))' "${manifest_json}")"
    echo "FROM scratch" | docker build --label "org.autoware.interface_manifest=${minified}" -t "${tag}" -
    built_images+=("${tag}")
}
build_unlabeled() {
    local tag="$1"
    echo "FROM scratch" | docker build -t "${tag}" -
    built_images+=("${tag}")
}

build_labeled "${TAG_PREFIX}provider" "${FIXTURES}/manifests/planning_trajectory_provider.json"
build_labeled "${TAG_PREFIX}consumer-compatible" "${FIXTURES}/manifests/consumer_compatible.json"
build_labeled "${TAG_PREFIX}consumer-incompatible" "${FIXTURES}/manifests/consumer_incompatible.json"
build_labeled "${TAG_PREFIX}consumer-no-provider" "${FIXTURES}/manifests/consumer_no_provider.json"
build_unlabeled "${TAG_PREFIX}unlabeled"

# ---- 4. Assert deploy_check.sh exit codes ---------------------------------------------------
assert_exit() {
    local expected="$1" compose="$2" name="$3" rc=0
    echo "---- ${name} (expect exit ${expected}) ----------------------------------------------"
    "${DEPLOY_CHECK}" "${compose}" || rc=$?
    [ "${rc}" -eq "${expected}" ] || fail "${name}: expected exit ${expected}, got ${rc}"
    log "OK ${name}: deploy_check exited ${rc} as expected"
}

assert_exit 0 "${FIXTURES}/compose/compose.compatible.yaml" "compatible-set"
assert_exit 1 "${FIXTURES}/compose/compose.incompatible.yaml" "incompatible-set"
assert_exit 1 "${FIXTURES}/compose/compose.no-provider.yaml" "no-provider-set"
assert_exit 2 "${FIXTURES}/compose/compose.unlabeled.yaml" "unlabeled-image"

log "ALL ASSERTIONS PASSED"
