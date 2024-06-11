group "default" {
  targets = ["prebuilt", "devel", "runtime"]
}

target "prebuilt" {
  dockerfile = "docker/Dockerfile"
  target = "prebuilt"
}

target "devel" {
  dockerfile = "docker/Dockerfile"
  target = "devel"
}

target "runtime" {
  dockerfile = "docker/Dockerfile"
  target = "runtime"
}
