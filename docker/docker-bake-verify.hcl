// Fork-only Phase B verification bake (NOT for upstream). Load alongside the
// main bake file so ROS_DISTRO / USE_LOCKFILE / the base target resolve:
//   USE_LOCKFILE=true ROS_DISTRO=humble \
//     docker buildx bake -f docker/docker-bake.hcl -f docker/docker-bake-verify.hcl \
//       verify-core-install --load --no-cache
// Builds the locked base (target:base, digest + snapshot + pins) then runs the
// locked install_image_deps --tags core on top of it.
target "verify-core-install" {
  dockerfile = "docker/verify-core-install.Dockerfile"
  target     = "verify-core-install"
  tags       = ["verify-core:${ROS_DISTRO}"]
  contexts = {
    autoware-base = "target:base"
  }
  args = {
    BASE_IMAGE   = "autoware-base"
    ROS_DISTRO   = ROS_DISTRO
    USE_LOCKFILE = USE_LOCKFILE
  }
}
