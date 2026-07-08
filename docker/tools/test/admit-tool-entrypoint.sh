#!/usr/bin/env bash
# Entrypoint of the deploy-time admission tool image (ADMIT_TOOL_IMAGE, built by admit-tool.Dockerfile).
# Sources the ROS environment plus the admission install overlay, then runs manifest_admit over the
# manifest JSON files passed as arguments. The process is replaced with manifest_admit (exec), so the
# container exit status is manifest_admit's own — 0 accepted / 1 rejection / 2 operational error —
# which deploy_check.sh propagates verbatim.
# The ROS / ament setup scripts reference variables that may be unset, so `set -u` is intentionally
# NOT enabled here; `set -e` still aborts on a genuine sourcing failure.
set -e

# shellcheck source=/dev/null
source /opt/ros/jazzy/setup.bash
# shellcheck source=/dev/null
source /opt/admission/install/setup.bash

exec ros2 run autoware_component_interface_admission manifest_admit "$@"
