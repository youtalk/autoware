group "default" {
  targets = ["prebuilt"]
}

target "prebuilt" {
  dockerfile = "docker/Dockerfile"
  target = "prebuilt"
}
