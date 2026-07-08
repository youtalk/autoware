# Deploy-time interface-admission gate

<!-- cspell:ignore skopeo -->

`deploy_check.sh` is the operator / CI entry point for **deploy-time static admission** of Autoware's component interfaces — the primary (Stage-1) detection of the component interface versioning design (section 3.1, the `deploy_admission` CI gate of section 8, migration phase P2). It rejects an interface-incompatible image set **before `docker compose up`**, at deploy-config / OTA-assembly time — the cheapest place to catch a mismatch, before any build, pull, boot, or vehicle dispatch is paid for.

## OCI-label conformance contract

Each component image carries its interface manifest as **pure image metadata**, so the gate reads it without creating or starting a container and without any source present in the image (a binary-only third-party image works):

- **Primary**: the OCI image label `org.autoware.interface_manifest`, whose value is the manifest JSON payload. Read with `docker inspect` (or `skopeo inspect` / `crane config` against a registry, without pulling).
- **Secondary**: the fixed path `/opt/autoware/manifest.json` inside the image.

The JSON payload schema (the fields of `provided[]` / `required[]` and the manifest envelope) is defined once by the `autoware_component_interface_admission` package in `autoware_universe`; see that package's README for the authoritative schema. `deploy_check.sh` treats the label value as an opaque JSON document and hands it to `manifest_admit`, which owns parsing and the verdict.

## One rule, two triggers

The gate does not reimplement compatibility. It runs the **same `evaluate()` admission rule** — "the consumer's accepted MAJOR range contains the provider's MAJOR", plus the remap-safe name match — that the runtime handshake will use, via the shared `manifest_admit` / `evaluate_deploy()` in `autoware_component_interface_admission`. Deploy-time and runtime are two triggers of one rule, not parallel implementations. Because the deploy-time image set is **complete** (unlike runtime observe mode, where a provider may simply not have started yet), the deploy trigger additionally rejects a required interface with **no provider** anywhere in the set (`NO_PROVIDER`).

## `deploy_check.sh`

```bash
# Reject an incompatible set before `docker compose up`
ADMIT_TOOL_IMAGE=my/admit-tool:jazzy ./docker/tools/deploy_check.sh path/to/compose.yaml
```

It resolves the image set with `docker compose config --images`, extracts each image's `org.autoware.interface_manifest` label via `docker inspect`, writes each manifest to a file, and runs `manifest_admit` over the whole set from the tool image.

| Exit code | Meaning                                                                                                                                 |
| --------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| `0`       | every required interface is satisfied by a compatible provider — deploy may proceed                                                     |
| `1`       | at least one admission rejection (`MAJOR` / `MINOR` / `TOPIC` mismatch or `NO_PROVIDER`) — deploy blocked                               |
| `2`       | operational error: no images in the compose file, `docker inspect` failed, an image lacks the label, or the tool image could not be run |

A present image that carries **no** `org.autoware.interface_manifest` label (exit 2, "not IF-versioning conformant") is kept distinct in the diagnostics from a `docker inspect` that failed because the image is absent locally or the daemon is down (exit 2, "image not present locally or Docker unavailable") — the former is a non-conformant image, the latter an environment problem.

### `ADMIT_TOOL_IMAGE`

`manifest_admit` runs from a **dedicated tool image**, `ADMIT_TOOL_IMAGE`, and **never** from an image under test — so the admission binary is always trusted, independent of the (possibly third-party, possibly hostile) images it inspects. The tool image contract: its entrypoint runs `manifest_admit` with the ROS overlay sourced, takes the manifest JSON file paths as arguments, and honours `manifest_admit`'s 0/1/2 exit-code contract. `docker/tools/test/admit-tool.Dockerfile` + `admit-tool-entrypoint.sh` are a reference tool image. There is no published tool image yet; set `ADMIT_TOOL_IMAGE` to one you build (the self-test builds its own).

## Scope and honest limitations

- **Matches version + `interface_name` only.** The remap-resolved `resolved_name` (stage 2 of the rule) lives in the launch / compose layer and is **not statically resolvable from image metadata**, so a remap-induced `TOPIC_MISMATCH` is the residual the runtime trigger backstops (R-IF-13). The deploy-time gate performs only stage 1 (same `interface_name` + compatible MAJOR).
- **Cooperative manifests.** The gate assumes honest, self-declared manifests. Tamper resistance (signing / attestation) is out of scope.
- **Multi-container prerequisite (R-IF-14).** The OCI-label mechanism presupposes per-component (multi-container) images. Native / monolithic deployments are not covered by the image-label mechanism and fall back to the runtime trigger.

## What this PR ships — and what it does not (R-IF-14)

This directory ships the **gate, the label contract, and a self-test**. It deliberately does **not** touch the production `Dockerfile` definitions or the `docker/docker-bake.hcl` bake definitions: baking real interface manifests into the shipping Autoware images is deferred until per-component (multi-container) images exist (R-IF-14). Until then the gate is exercised end-to-end against label-only fixture images built by the self-test, which proves the mechanism without changing any production image.

## Self-test

`test/run_self_test.sh` builds a dedicated `ADMIT_TOOL_IMAGE` containing `manifest_admit`, builds a matrix of label-only fixture images from the manifests under `test/fixtures/manifests/`, and asserts `deploy_check.sh`'s exit code on the compose sets under `test/fixtures/compose/`:

| Compose set                 | Fixture                                             | Expected exit     |
| --------------------------- | --------------------------------------------------- | ----------------- |
| `compose.compatible.yaml`   | provider 0.1.0 + consumer accepting MAJOR 0         | `0`               |
| `compose.incompatible.yaml` | provider 0.1.0 + consumer accepting MAJOR 1         | `1` (MAJOR)       |
| `compose.no-provider.yaml`  | consumer requires an interface no image provides    | `1` (NO_PROVIDER) |
| `compose.unlabeled.yaml`    | one image present but carrying no conformance label | `2`               |

All images it builds are tagged `oss-if-gate-self-test-*` and removed on exit.

### Developer loop (build the tool from a local checkout)

```bash
# Build manifest_admit from a local autoware_component_interface_admission checkout, wrapped in a
# tool image built on autoware:universe-devel-jazzy, then run the full fixture matrix locally.
UNIVERSE_LOCAL_PATH=/path/to/autoware_universe ./docker/tools/test/run_self_test.sh
```

### CI loop (clone the package from autoware_universe)

```bash
# Default: clone autowarefoundation/autoware_universe @ main and build the package from it. Until
# the package merges, point it at the fork branch that carries it.
UNIVERSE_REPO=<owner>/autoware_universe UNIVERSE_REF=<branch> ./docker/tools/test/run_self_test.sh
```

The GitHub Actions workflow `deploy-admission-self-test.yaml` runs the self-test on `pull_request` (paths under `docker/tools/**`) and on `workflow_dispatch` (with `universe-repo` / `universe-ref` inputs). It is **advisory (non-required)**: it becomes meaningful once `autoware_component_interface_admission` merges into `autoware_universe` — the landing order is admission package first, then this gate.
