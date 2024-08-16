FROM youtalk/autoware-base:latest-humble-autoware-core-base AS autoware-core
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ARG ROS_DISTRO
ENV CCACHE_DIR="/root/.ccache"

WORKDIR /autoware

# Build autoware.core
RUN --mount=type=cache,target=${CCACHE_DIR} \
  --mount=type=bind,source=src/core,target=/autoware/src/core \
  source /opt/ros/"$ROS_DISTRO"/setup.bash \
  && du -sh ${CCACHE_DIR} && ccache -s \
  && colcon build --cmake-args \
    " -Wno-dev" \
    " --no-warn-unused-cli" \
    --merge-install \
    --install-base /opt/autoware \
    --mixin release compile-commands ccache \
  && du -sh ${CCACHE_DIR} && ccache -s

FROM youtalk/autoware-base:latest-humble-autoware-universe-base AS autoware-universe
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ARG ROS_DISTRO
ENV CCACHE_DIR="/root/.ccache"

COPY --from=autoware-core /opt/autoware /opt/autoware

# Build autoware.universe
RUN --mount=type=cache,target=${CCACHE_DIR} \
  --mount=type=bind,source=src/launcher,target=/autoware/src/launcher \
  --mount=type=bind,source=src/param,target=/autoware/src/param \
  --mount=type=bind,source=src/sensor_component,target=/autoware/src/sensor_component \
  --mount=type=bind,source=src/sensor_kit,target=/autoware/src/sensor_kit \
  --mount=type=bind,source=src/universe,target=/autoware/src/universe \
  --mount=type=bind,source=src/vehicle,target=/autoware/src/vehicle \
  source /opt/ros/"$ROS_DISTRO"/setup.bash \
  && source /opt/autoware/setup.bash \
  && du -sh ${CCACHE_DIR} && ccache -s \
  && colcon build --cmake-args \
    " -Wno-dev" \
    " --no-warn-unused-cli" \
    --merge-install \
    --install-base /opt/autoware \
    --mixin release compile-commands ccache \
  && du -sh ${CCACHE_DIR} && ccache -s

FROM youtalk/autoware-base:latest-humble-autoware-universe-cuda-base AS autoware-universe-cuda
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ARG ROS_DISTRO
ENV CCACHE_DIR="/root/.ccache"

COPY --from=autoware-universe /opt/autoware /opt/autoware

# Build autoware.universe with CUDA
RUN --mount=type=cache,target=${CCACHE_DIR} \
  --mount=type=bind,source=src/universe,target=/autoware/src/universe \
  source /opt/ros/"$ROS_DISTRO"/setup.bash \
  && source /opt/autoware/setup.bash \
  && du -sh ${CCACHE_DIR} && ccache -s \
  && colcon build --cmake-args \
    " -Wno-dev" \
    " --no-warn-unused-cli" \
    --merge-install \
    --install-base /opt/autoware \
    --mixin release compile-commands ccache \
  && du -sh ${CCACHE_DIR} && ccache -s

FROM autoware-universe AS devel
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install development tools and artifacts
RUN --mount=type=ssh \
  --mount=type=cache,target=/var/cache/apt,sharing=locked \
  ./setup-dev-env.sh -y --module dev-tools openadkit \
  && pip uninstall -y ansible ansible-core \
  && apt-get autoremove -y && rm -rf "$HOME"/.cache

COPY src /autoware/src
# Create entrypoint
COPY docker/etc/ros_entrypoint.sh /ros_entrypoint.sh
RUN chmod +x /ros_entrypoint.sh
ENTRYPOINT ["/ros_entrypoint.sh"]
CMD ["/bin/bash"]

FROM autoware-universe-cuda AS devel-cuda
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install development tools and artifacts
RUN --mount=type=ssh \
  --mount=type=cache,target=/var/cache/apt,sharing=locked \
  ./setup-dev-env.sh -y --module dev-tools openadkit \
  && pip uninstall -y ansible ansible-core \
  && apt-get autoremove -y && rm -rf "$HOME"/.cache

FROM youtalk/autoware-base:latest-humble-runtime-base AS runtime
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

COPY --from=autoware-universe /opt/autoware /opt/autoware

# Copy bash aliases
COPY docker/etc/.bash_aliases /root/.bash_aliases
RUN echo "source /opt/autoware/setup.bash" > /etc/bash.bashrc

# Create entrypoint
COPY docker/etc/ros_entrypoint.sh /ros_entrypoint.sh
RUN chmod +x /ros_entrypoint.sh
ENTRYPOINT ["/ros_entrypoint.sh"]
CMD ["bash"]

FROM youtalk/autoware-base:latest-humble-runtime-cuda-base AS runtime-cuda
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

COPY --from=autoware-universe-cuda /opt/autoware /opt/autoware

# Copy bash aliases
COPY docker/etc/.bash_aliases /root/.bash_aliases
RUN echo "source /opt/autoware/setup.bash" > /etc/bash.bashrc

# Create entrypoint
COPY docker/etc/ros_entrypoint.sh /ros_entrypoint.sh
RUN chmod +x /ros_entrypoint.sh
ENTRYPOINT ["/ros_entrypoint.sh"]
CMD ["bash"]
