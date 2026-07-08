# syntax=docker/dockerfile:1
# Dedicated deploy-time admission tool image for the self-test.
#
# Stage 1 compiles ONLY manifest_admit from autoware_component_interface_admission in a full build
# base; stage 2 wraps just the resulting install space in a minimal ROS base image. deploy_check.sh
# runs THIS image (ADMIT_TOOL_IMAGE) — never an image under test — so the admission binary is always
# trusted, independent of the images it inspects.
#
# BUILD_BASE_IMAGE must provide autoware_cmake + nlohmann_json (autoware:universe-devel-jazzy, whose
# Autoware overlay lives at /opt/autoware, is the reference). run_self_test.sh selects the local tag
# for the developer loop and the GHCR tag for the CI clone.
ARG BUILD_BASE_IMAGE=ghcr.io/autowarefoundation/autoware:universe-devel-jazzy
ARG RUNTIME_BASE_IMAGE=ros:jazzy-ros-base

FROM ${BUILD_BASE_IMAGE} AS build
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
USER root
WORKDIR /ws
COPY src /ws/src
# Source the ROS base and, when present, the Autoware overlay (/opt/autoware) that carries
# autoware_cmake, then build only manifest_admit.
# hadolint ignore=SC1091
RUN source /opt/ros/jazzy/setup.bash \
    && if [ -f /opt/autoware/setup.bash ]; then source /opt/autoware/setup.bash; fi \
    && colcon build --packages-select autoware_component_interface_admission \
        --cmake-args -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF

FROM ${RUNTIME_BASE_IMAGE} AS runtime
COPY --from=build /ws/install /opt/admission/install
COPY entrypoint.sh /usr/local/bin/admit-tool-entrypoint.sh
RUN chmod +x /usr/local/bin/admit-tool-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/admit-tool-entrypoint.sh"]
