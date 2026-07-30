#!/usr/bin/env bash
# Self-test for the deploy-time interface-admission gate (docker/tools/deploy_check.sh).
#
# It builds a dedicated ADMIT_TOOL_IMAGE that contains manifest_admit from
# autoware_component_interface_admission, builds a matrix of label-only fixture images (each
# carrying a fixture interface manifest as the OCI label org.autoware.interface_manifest), and
# asserts deploy_check.sh's exit code (and, for broken-config, its diagnostic message) on seven
# composed image sets:
#   compatible    -> 0 (accepted)
#   incompatible  -> 1 (MAJOR mismatch)
#   no-provider   -> 1 (required interface with no provider in the set)
#   unlabeled     -> 2 (a present image lacks the conformance label AND carries no installed
#                    interface manifest fragment)
#   broken-config -> 2 (`docker compose config` itself fails, e.g. a missing env_file — must be
#                    reported as a compose failure, not misreported as "no images")
#   fragments     -> 0 (a label-less image falls back to its installed
#                    interface_manifest_fragment.json and is still admitted)
#   qos-reject    -> 1 (a provider's offered QoS ranks below the pivot registered in the fixture
#                    spec manifest baked into the tool image)
#
# Admission-tool source — two modes:
#   * CORE_LOCAL_PATH=<dir>  build the package from a local checkout (the developer loop). The
#                            package is located under <dir>; the build runs in BUILD_BASE_IMAGE
#                            (default autoware:core-devel-jazzy).
#   * otherwise (CI default) git clone --depth 1 --branch "${CORE_REF}"
#                            "https://github.com/${CORE_REPO}" and build the package from it
#                            (BUILD_BASE_IMAGE default
#                            ghcr.io/autowarefoundation/autoware:core-devel-jazzy).
#     CORE_REPO defaults to autowarefoundation/autoware_core, CORE_REF to main. Until the admission
#     package merges into autoware_core, the default clone will not contain it and the run fails
#     fast with a clear message — this job is advisory (non-required) for that reason.
#
# All images this script builds are tagged autoware-admission-self-test-* and removed on exit (best effort).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEPLOY_CHECK="${TOOLS_DIR}/deploy_check.sh"
FIXTURES="${SCRIPT_DIR}/fixtures"

TAG_PREFIX="autoware-admission-self-test-"
TOOL_IMAGE="${TAG_PREFIX}admit-tool"
export ADMIT_TOOL_IMAGE="${TOOL_IMAGE}"

CORE_REPO="${CORE_REPO:-autowarefoundation/autoware_core}"
CORE_REF="${CORE_REF:-main}"
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
if [ -n "${CORE_LOCAL_PATH:-}" ]; then
    log "using local admission source under ${CORE_LOCAL_PATH}"
    found="$(find "${CORE_LOCAL_PATH}" -type d -name autoware_component_interface_admission -print -quit)"
    [ -n "${found}" ] || fail "autoware_component_interface_admission not found under ${CORE_LOCAL_PATH}"
    cp -r "${found}" "${pkg_src}"
    BUILD_BASE_IMAGE="${BUILD_BASE_IMAGE:-autoware:core-devel-jazzy}"
else
    log "cloning ${CORE_REPO}@${CORE_REF} (depth 1)"
    clone="${workdir}/core"
    git clone --depth 1 --branch "${CORE_REF}" "https://github.com/${CORE_REPO}.git" "${clone}"
    found="$(find "${clone}" -type d -name autoware_component_interface_admission -print -quit)"
    [ -n "${found}" ] || fail "autoware_component_interface_admission not present in ${CORE_REPO}@${CORE_REF} (has the core package merged yet?)"
    cp -r "${found}" "${pkg_src}"
    BUILD_BASE_IMAGE="${BUILD_BASE_IMAGE:-ghcr.io/autowarefoundation/autoware:core-devel-jazzy}"
fi

# ---- 2. Build the dedicated ADMIT_TOOL_IMAGE ------------------------------------------------
cp "${SCRIPT_DIR}/admit-tool.Dockerfile" "${workdir}/Dockerfile"
cp "${SCRIPT_DIR}/admit-tool-entrypoint.sh" "${workdir}/entrypoint.sh"
# The fixture spec manifest is baked into every self-test tool image (see admit-tool.Dockerfile),
# which is safe for the pre-existing cases: none of their fixtures carry a `qos` block, so the
# pivot it registers cannot affect them.
cp "${FIXTURES}/manifests/spec_manifest.json" "${workdir}/interface_manifest.json"
log "building ${TOOL_IMAGE} (build base ${BUILD_BASE_IMAGE}, runtime base ${RUNTIME_BASE_IMAGE})"
DOCKER_BUILDKIT=1 docker build \
    --build-arg "BUILD_BASE_IMAGE=${BUILD_BASE_IMAGE}" \
    --build-arg "RUNTIME_BASE_IMAGE=${RUNTIME_BASE_IMAGE}" \
    -t "${TOOL_IMAGE}" "${workdir}"
built_images+=("${TOOL_IMAGE}")

# ---- 3. Build the label-only and fragment-only fixture images -------------------------------
# Each labeled image carries its fixture manifest (minified + validated) as the OCI label; the
# unlabeled image carries neither a label nor a fragment. FROM scratch keeps them empty — the gate
# only reads metadata (or, for the fragment fallback, files installed under /opt/autoware/share).
# Every fixture Dockerfile sets a placeholder CMD: `docker create` refuses an image with no command
# at all ("no command specified"), and deploy_check.sh's fragment fallback creates (never starts)
# the container to run `docker cp` against it, so a real conformant image (which always carries a
# process entrypoint) would never hit that problem, but these empty fixtures otherwise would.
build_labeled() {
    local tag="$1" manifest_json="$2" minified
    minified="$(python3 -c 'import json,sys; print(json.dumps(json.load(open(sys.argv[1]))))' "${manifest_json}")"
    printf 'FROM scratch\nCMD ["true"]\n' | docker build --label "org.autoware.interface_manifest=${minified}" -t "${tag}" -
    built_images+=("${tag}")
}
build_unlabeled() {
    local tag="$1"
    printf 'FROM scratch\nCMD ["true"]\n' | docker build -t "${tag}" -
    built_images+=("${tag}")
}
# Builds an image that carries NO org.autoware.interface_manifest label, only one
# interface_manifest_fragment.json per given manifest file, installed under its own
# /opt/autoware/share/<pkg>/ directory -- the on-disk layout deploy_check.sh's fallback discovers
# when a label is absent. A real build context (not a stdin-only Dockerfile) is needed here because,
# unlike build_labeled(), files must be copied into the image.
build_fragments_image() {
    local tag="$1"
    shift
    local ctx
    ctx="$(mktemp -d "${workdir}/fragments_ctx.XXXXXX")"
    printf 'FROM scratch\nCMD ["true"]\n' >"${ctx}/Dockerfile"
    local n=0 manifest_json
    for manifest_json in "$@"; do
        mkdir -p "${ctx}/share/fixture_pkg_${n}"
        cp "${manifest_json}" "${ctx}/share/fixture_pkg_${n}/interface_manifest_fragment.json"
        echo "COPY share/fixture_pkg_${n}/interface_manifest_fragment.json /opt/autoware/share/fixture_pkg_${n}/interface_manifest_fragment.json" \
            >>"${ctx}/Dockerfile"
        n=$((n + 1))
    done
    docker build -t "${tag}" "${ctx}"
    built_images+=("${tag}")
}

build_labeled "${TAG_PREFIX}provider" "${FIXTURES}/manifests/planning_trajectory_provider.json"
build_labeled "${TAG_PREFIX}consumer-compatible" "${FIXTURES}/manifests/consumer_compatible.json"
build_labeled "${TAG_PREFIX}consumer-incompatible" "${FIXTURES}/manifests/consumer_incompatible.json"
build_labeled "${TAG_PREFIX}consumer-no-provider" "${FIXTURES}/manifests/consumer_no_provider.json"
build_labeled "${TAG_PREFIX}qos-provider" "${FIXTURES}/manifests/qos_provider_best_effort.json"
build_unlabeled "${TAG_PREFIX}unlabeled"
build_fragments_image "${TAG_PREFIX}fragment-provider" "${FIXTURES}/manifests/planning_trajectory_provider.json"

# ---- 4. Assert deploy_check.sh exit codes ---------------------------------------------------
assert_exit() {
    local expected="$1" compose="$2" name="$3" rc=0
    echo "---- ${name} (expect exit ${expected}) ----------------------------------------------"
    "${DEPLOY_CHECK}" "${compose}" || rc=$?
    [ "${rc}" -eq "${expected}" ] || fail "${name}: expected exit ${expected}, got ${rc}"
    log "OK ${name}: deploy_check exited ${rc} as expected"
}

# Like assert_exit, but also asserts the stderr diagnostic contains ${needle} and does NOT contain
# ${must_not_contain} — used for the broken-config case, where the exit code alone (2) can't tell a
# genuine `docker compose config` failure apart from the "no images" case it used to be misreported
# as; the message has to be checked too.
assert_exit_and_stderr() {
    local expected="$1" compose="$2" name="$3" needle="$4" must_not_contain="$5" rc=0 err
    echo "---- ${name} (expect exit ${expected}, stderr containing '${needle}') ----------------------------------------------"
    err="$("${DEPLOY_CHECK}" "${compose}" 2>&1 >/dev/null)" || rc=$?
    [ "${rc}" -eq "${expected}" ] || fail "${name}: expected exit ${expected}, got ${rc}"
    echo "${err}" | grep -qF -- "${needle}" || fail "${name}: expected stderr to contain '${needle}', got: ${err}"
    if [ -n "${must_not_contain}" ] && echo "${err}" | grep -qF -- "${must_not_contain}"; then
        fail "${name}: stderr wrongly contains '${must_not_contain}' (misdiagnosed), got: ${err}"
    fi
    log "OK ${name}: deploy_check exited ${rc} with the expected diagnostic"
}

assert_exit 0 "${FIXTURES}/compose/compose.compatible.yaml" "compatible-set"
assert_exit 1 "${FIXTURES}/compose/compose.incompatible.yaml" "incompatible-set"
assert_exit 1 "${FIXTURES}/compose/compose.no-provider.yaml" "no-provider-set"
assert_exit 2 "${FIXTURES}/compose/compose.unlabeled.yaml" "unlabeled-image"
assert_exit_and_stderr 2 "${FIXTURES}/compose/compose.broken-config.yaml" "broken-config" \
    "docker compose -f" "no images in"
assert_exit 0 "${FIXTURES}/compose/compose.fragments.yaml" "fragments"
assert_exit 1 "${FIXTURES}/compose/compose.qos-reject.yaml" "qos-reject"

log "ALL ASSERTIONS PASSED"
