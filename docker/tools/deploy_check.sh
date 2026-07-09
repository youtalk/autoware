#!/usr/bin/env bash
# Deploy-time component-interface admission gate (design section 3.1, the P2 Stage-1 primary
# detection).
#
# Given a docker-compose file, resolve the image set it selects, read each image's baked interface
# manifest from the OCI label org.autoware.interface_manifest via `docker inspect` (pure image
# metadata — no container is created or started, and no source need be present in the image, so a
# binary-only third-party image works), then run the SAME admission rule the runtime handshake uses
# (manifest_admit / evaluate_deploy) over the whole set. A non-zero exit BLOCKS the deploy / OTA
# assembly BEFORE `docker compose up`.
#
# manifest_admit runs from a dedicated tool image (ADMIT_TOOL_IMAGE), NEVER from an image under
# test. That image's entrypoint must run manifest_admit with the ROS overlay sourced, taking the
# manifest JSON file paths as arguments and honouring manifest_admit's 0/1/2 exit-code contract
# (see docker/tools/test/admit-tool-entrypoint.sh for the reference tool image).
#
# Usage:
#   ./deploy_check.sh <compose-file>
#   ADMIT_TOOL_IMAGE=my/admit-tool:tag ./deploy_check.sh <compose-file>
#
# Exit codes (mirrors manifest_admit):
#   0  every required interface is satisfied by a compatible provider
#   1  at least one admission rejection (MAJOR / MINOR / TOPIC mismatch or NO_PROVIDER)
#   2  operational error (no images, `docker inspect` failed, an image lacks the label, or the
#      admission tool could not be run)
set -euo pipefail

COMPOSE_FILE="${1:?usage: deploy_check.sh <compose-file>}"
LABEL="org.autoware.interface_manifest"
ADMIT_TOOL_IMAGE="${ADMIT_TOOL_IMAGE:-autoware-admit-tool:jazzy}"

workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT

# Resolve the image set the deploy config selects (no pull, no boot).
mapfile -t images < <(docker compose -f "${COMPOSE_FILE}" config --images | sort -u)
if [ "${#images[@]}" -eq 0 ]; then
    echo "deploy_check: no images in ${COMPOSE_FILE}" >&2
    exit 2
fi

admit_args=()
i=0
for img in "${images[@]}"; do
    echo "[deploy_check] inspecting ${img}"
    # Keep a `docker inspect` failure (image not present locally, daemon down) distinct from an
    # image that IS present but carries no label: the former is an operational error, the latter a
    # non-conformant image. Both block the deploy (exit 2) but with different diagnostics.
    if ! manifest="$(docker inspect -f "{{ index .Config.Labels \"${LABEL}\" }}" "${img}" \
        2>"${workdir}/inspect_err")"; then
        echo "deploy_check: 'docker inspect ${img}' failed — image not present locally or Docker unavailable" >&2
        sed 's/^/  docker: /' "${workdir}/inspect_err" >&2
        exit 2
    fi
    if [ -z "${manifest}" ] || [ "${manifest}" = "<no value>" ]; then
        echo "deploy_check: image ${img} has no ${LABEL} label — not IF-versioning conformant" >&2
        exit 2
    fi
    printf '%s' "${manifest}" >"${workdir}/manifest_${i}.json"
    admit_args+=("/in/manifest_${i}.json")
    i=$((i + 1))
done

echo "[deploy_check] running admission over ${i} manifest(s) via ${ADMIT_TOOL_IMAGE} (no boot, no DDS)"
rc=0
docker run --rm -v "${workdir}:/in:ro" "${ADMIT_TOOL_IMAGE}" "${admit_args[@]}" || rc=$?

case "${rc}" in
0)
    echo "[deploy_check] ACCEPTED: the composed image set is interface-compatible"
    exit 0
    ;;
1)
    echo "[deploy_check] REJECTED: incompatible interface set — blocking deploy" >&2
    exit 1
    ;;
2)
    echo "[deploy_check] operational error reported by the admission tool (exit 2)" >&2
    exit 2
    ;;
*)
    # manifest_admit only ever returns 0/1/2; any other status means the tool image itself
    # could not be run (e.g. ADMIT_TOOL_IMAGE missing) — an operational error.
    echo "deploy_check: could not run the admission tool image ${ADMIT_TOOL_IMAGE} (docker exit ${rc})" >&2
    exit 2
    ;;
esac
