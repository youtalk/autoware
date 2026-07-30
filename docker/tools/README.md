# Deploy-time interface-admission gate

<!-- cspell:ignore skopeo -->

`deploy_check.sh` is the operator / CI entry point for **deploy-time static admission** of Autoware's component interfaces. It rejects an interface-incompatible image set **before `docker compose up`**, at deploy-config / OTA-assembly time — the cheapest place to catch a mismatch, before any build, pull, boot, or vehicle dispatch is paid for, and before any container in the set is actually created or started.

## Manifest resolution: label primary, installed fragments as fallback

Each component image should carry its interface manifest as **pure image metadata**, so the gate can read it without creating or starting a container and without any source present in the image (a binary-only third-party image works):

- **Primary**: the OCI image label `org.autoware.interface_manifest`, whose value is the manifest JSON payload. Read with `docker inspect` (or `skopeo inspect` / `crane config` against a registry, without pulling).
- **Fallback**: for an image that carries no such label, the `interface_manifest_fragment.json` file(s) installed under `/opt/autoware/share/<pkg>/` by every package that registers interfaces through `autoware_component_interface_utils`. `deploy_check.sh` `docker create`s the image to obtain a container ID and `docker cp`s `/opt/autoware/share` out of it, then admits every fragment it finds. **That container is created but never started** — the fallback is exactly as boot-free as the label path — and it is removed again once its filesystem has been read.

An image with neither the label nor any installed fragment is not IF-versioning conformant and is rejected as an operational error (exit 2).

The JSON payload schema (the fields of `provided[]` / `required[]` and the manifest envelope) is defined once by the `autoware_component_interface_admission` package in `autoware_core`; see that package's README for the authoritative schema. `deploy_check.sh` treats a manifest as an opaque JSON document and hands it to `manifest_admit`, which owns parsing and the verdict.

## One rule, several triggers

The gate does not reimplement compatibility. It runs the **same admission rule** — "the consumer's accepted MAJOR range contains the provider's MAJOR", plus the remap-safe name match, plus the QoS pivot check described below — that the runtime handshake will use, via the shared `manifest_admit` in `autoware_component_interface_admission`. Deploy-time and runtime are triggers of one rule, not parallel implementations. Because the deploy-time image set is **complete** (unlike runtime observe mode, where a provider may simply not have started yet), the deploy trigger additionally rejects a required interface with **no provider** anywhere in the set (`NO_PROVIDER`).

### QoS pivot enforcement

`manifest_admit` additionally accepts `--spec-manifest <path>`, the `autoware_component_interface_specs` pivot document that registers the reliability/durability/depth an interface's providers and consumers are expected to converge on. When the admission tool image carries a spec manifest at `/opt/autoware/interface_manifest.json`, `admit-tool-entrypoint.sh` (the reference tool image's entrypoint) prepends `--spec-manifest` automatically, so the gate also rejects a provider offering QoS below the registered pivot, or a consumer requiring QoS above it. A tool image without that file still runs the version-only admission rule; a pairing with no QoS on either side is accepted with a warning (QoS compatibility not evaluated for that pairing), not rejected.

## `deploy_check.sh`

```bash
# Reject an incompatible set before `docker compose up`
ADMIT_TOOL_IMAGE=my/admit-tool:jazzy ./docker/tools/deploy_check.sh path/to/compose.yaml
```

It resolves the image set with `docker compose config --images`, reads each image's manifest(s) (label primary, installed fragments as fallback — see above), writes each manifest to a file, and runs `manifest_admit` over the whole set from the tool image.

| Exit code | Meaning                                                                                                                                                                                                           |
| --------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `0`       | every required interface is satisfied by a compatible provider — deploy may proceed                                                                                                                               |
| `1`       | at least one admission rejection (`MAJOR` / `MINOR` mismatch, `NO_PROVIDER`, or a QoS pivot violation) — deploy blocked                                                                                           |
| `2`       | operational error: `docker compose config` failed, no images in the compose file, `docker inspect` failed, an image has neither the label nor any installed manifest fragment, or the tool image could not be run |

A present image that carries **no** `org.autoware.interface_manifest` label and no installed manifest fragment (exit 2, "not IF-versioning conformant") is kept distinct in the diagnostics from a `docker inspect` / `docker create` that failed because the image is absent locally or the daemon is down (exit 2, "not present locally or Docker unavailable") — the former is a non-conformant image, the latter an environment problem.

### `ADMIT_TOOL_IMAGE`

`manifest_admit` runs from a **dedicated tool image**, `ADMIT_TOOL_IMAGE`, and **never** from an image under test — so the admission binary is always trusted, independent of the (possibly third-party, possibly hostile) images it inspects. The tool image contract: its entrypoint runs `manifest_admit` with the ROS overlay sourced, takes the manifest JSON file paths as arguments, prepends `--spec-manifest` when a spec manifest is present at `/opt/autoware/interface_manifest.json`, and honours `manifest_admit`'s 0/1/2 exit-code contract. `docker/tools/test/admit-tool.Dockerfile` + `admit-tool-entrypoint.sh` are a reference tool image, built on `autoware:core-devel-jazzy`. There is no published tool image yet; set `ADMIT_TOOL_IMAGE` to one you build (the self-test builds its own).

## Scope and honest limitations

- **Matches version + `interface_name`, plus the registered QoS pivot.** A compose file can remap a topic name after the image is built, and that remap happens in the launch / compose layer, not in the image itself — it is **not statically resolvable from image metadata**, so a remap-induced `TOPIC_MISMATCH` is left for the runtime trigger to catch instead. The deploy-time gate checks that the `interface_name` matches, the MAJOR version is compatible, and (when a spec manifest is supplied) each side's QoS is on the correct side of the registered pivot.
- **Cooperative manifests.** The gate assumes honest, self-declared manifests. Tamper resistance (signing / attestation) is out of scope.
- **Multi-container prerequisite.** The per-image mechanisms (OCI label and installed fragment alike) presuppose per-component (multi-container) images, since both attach to a single image; a native / monolithic deployment has no per-component image boundary for either to attach to, so it falls back to the runtime trigger instead.

## What this directory ships — and what it does not

This directory ships the **gate, the label/fragment resolution, the QoS pivot wiring, and a self-test**. It deliberately does **not** touch the production `Dockerfile` definitions or the `docker/docker-bake.hcl` bake definitions: baking real interface manifests into the shipping Autoware images depends on per-component (multi-container) images existing, which is separate follow-up work. Until then the gate is exercised end-to-end against fixture images built by the self-test, which proves the mechanism without changing any production image.

## Self-test

`test/run_self_test.sh` builds a dedicated `ADMIT_TOOL_IMAGE` containing `manifest_admit` (with the fixture spec manifest baked in for the QoS-pivot cases), builds a matrix of fixture images from the manifests under `test/fixtures/manifests/`, and asserts `deploy_check.sh`'s exit code on the compose sets under `test/fixtures/compose/`. It also runs a second, spec-manifest-less tool image directly (not through `deploy_check.sh`) to assert that `admit-tool-entrypoint.sh` itself warns on stderr when it finds no spec manifest to pass:

| Compose set                       | Fixture                                                                                                                                                                                                | Expected exit                                                                       |
| --------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------- |
| `compose.compatible.yaml`         | provider 0.1.0 + consumer accepting MAJOR 0                                                                                                                                                            | `0`                                                                                 |
| `compose.incompatible.yaml`       | provider 0.1.0 + consumer accepting MAJOR 1                                                                                                                                                            | `1` (MAJOR)                                                                         |
| `compose.no-provider.yaml`        | consumer requires an interface no image provides                                                                                                                                                       | `1` (NO_PROVIDER)                                                                   |
| `compose.unlabeled.yaml`          | one image present but carrying no label and no installed manifest fragment                                                                                                                             | `2`                                                                                 |
| `compose.broken-config.yaml`      | interpolates a required (`${VAR:?...}`) variable that is never set, so `docker compose config` itself fails                                                                                            | `2` (reported as a `docker compose` failure, not "no images")                       |
| `compose.fragments.yaml`          | a label-less provider carrying only an installed `interface_manifest_fragment.json`                                                                                                                    | `0` (fallback discovers and admits the fragment)                                    |
| `compose.qos-reject.yaml`         | a lone provider offering `best_effort` against a `reliable` pivot in the fixture spec manifest                                                                                                         | `1` (QoS pivot violation)                                                           |
| `compose.qos-pivot-consumer.yaml` | a version-compatible provider whose QoS meets the pivot, plus a consumer requiring `transient_local` durability against the fixture spec manifest's `reliable` / `volatile` pivot                      | `1` (QOS_PIVOT_CONSUMER — the provider rules out NO_PROVIDER as an alternate cause) |
| `compose.multi-fragment.yaml`     | one image carrying two installed fragments: one at the documented depth-2 path and one nested one level deeper, the way `install(DIRECTORY config DESTINATION share/${PROJECT_NAME})` would install it | `1` (NO_PROVIDER — proves the deeper fragment is still discovered)                  |

All images it builds are tagged `autoware-admission-self-test-*` and removed on exit.

### Developer loop (build the tool from a local checkout)

```bash
# Build manifest_admit from a local autoware_component_interface_admission checkout, wrapped in a
# tool image built on autoware:core-devel-jazzy, then run the full fixture matrix locally.
CORE_LOCAL_PATH=/path/to/autoware_core ./docker/tools/test/run_self_test.sh
```

### CI loop (clone the package from autoware_core)

```bash
# Default: clone autowarefoundation/autoware_core @ main and build the package from it. Until the
# package merges, point it at the fork branch that carries it.
CORE_REPO=<owner>/autoware_core CORE_REF=<branch> ./docker/tools/test/run_self_test.sh
```

The GitHub Actions workflow `deploy-admission-self-test.yaml` runs the self-test on `pull_request` (paths under `docker/tools/**`) and on `workflow_dispatch` (with `core-repo` / `core-ref` inputs). It is **advisory (non-required)**: it becomes meaningful once `autoware_component_interface_admission` merges into `autoware_core` — the landing order is admission package first, then this gate.
