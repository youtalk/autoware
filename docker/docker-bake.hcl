group "default" {
  targets = ["runtime"]
}

target "runtime" {
  dockerfile = "docker/Dockerfile"
  target = "runtime"
}
