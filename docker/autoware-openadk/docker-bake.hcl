group "default" {
  targets = ["prebuilt", "devel", "runtime"]
}

target "prebuilt" {
  dockerfile = "docker/autoware-openadk/Dockerfile"
  target = "prebuilt"
}

target "devel" {
  dockerfile = "docker/autoware-openadk/Dockerfile"
  target = "devel"
}

target "runtime" {
  dockerfile = "docker/autoware-openadk/Dockerfile"
  target = "runtime"
}
