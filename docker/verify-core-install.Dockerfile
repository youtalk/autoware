# syntax=docker/dockerfile:1
# Fork-only Phase B verification (NOT for upstream). Runs the locked
# `install_image_deps --tags core` on top of the locked base image and stops,
# so the resolved package versions can be diffed WITHOUT needing the `src/`
# tree (vcs import) or a colcon build. Mirrors the ansible install step of
# core.Dockerfile's core-dependencies stage.
ARG BASE_IMAGE

FROM ${BASE_IMAGE} AS verify-core-install
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ARG ROS_DISTRO
ARG USE_LOCKFILE=false

USER aw
RUN --mount=type=bind,source=ansible-galaxy-requirements.yaml,target=/tmp/ansible/ansible-galaxy-requirements.yaml \
    --mount=type=bind,source=ansible,target=/tmp/ansible/ansible \
    --mount=type=cache,id=apt-cache-${ROS_DISTRO},target=/var/cache/apt,sharing=locked \
    --mount=type=cache,id=apt-lists-${ROS_DISTRO},target=/var/lib/apt/lists,sharing=locked \
    --mount=type=cache,id=pip-cache,target=/home/aw/.cache/pip,uid=1000,gid=1000 \
    --mount=type=cache,id=pipx-cache,target=/home/aw/.cache/pipx,uid=1000,gid=1000 \
    sudo apt-get update && \
    pipx install --include-deps "ansible==10.*" && \
    cd /tmp/ansible && \
    ansible-galaxy collection install -f -r ansible-galaxy-requirements.yaml && \
    ansible-playbook autoware.dev_env.install_image_deps \
      --tags core \
      --skip-tags base \
      -e "rosdistro=${ROS_DISTRO}" \
      -e "use_locked_versions=${USE_LOCKFILE}" && \
    pipx uninstall ansible
