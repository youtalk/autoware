// Fork-only cuda reproducibility verify (NOT for upstream). Load alongside the
// main bake file so ROS_DISTRO / USE_LOCKFILE / the base contexts resolve:
//   USE_LOCKFILE=true ROS_DISTRO=humble \
//     docker buildx bake -f docker/docker-bake.hcl -f docker/docker-bake-verify.hcl \
//       verify-cuda-install --load --no-cache
// base-cuda-devel already installs the full CUDA / TensorRT closure via
// install_nvidia, so this just re-tags it with a simple loadable name the
// workflow can `docker run` to diff the NVIDIA package versions.
target "verify-cuda-install" {
  inherits = ["base-cuda-devel"]
  tags     = ["verify-cuda:${ROS_DISTRO}"]
}
