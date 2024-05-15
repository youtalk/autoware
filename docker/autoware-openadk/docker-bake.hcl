group "default" {
  targets = ["prebuilt", "devel", "runtime"]
}

target "prebuilt" {
  dockerfile = "docker/autoware-openadk/Dockerfile"
  target = "prebuilt"
  tags = ["ghcr.io/youtalk/autoware/prebuilt:latest"]
  cache-from = ["type=registry,ref=ghcr.io/youtalk/autoware:buildcache"]
  cache-to = ["type=registry,ref=ghcr.io/youtalk/autoware:buildcache,mode=max"]
}

target "devel" {
  dockerfile = "docker/autoware-openadk/Dockerfile"
  target = "devel"
  tags = ["ghcr.io/youtalk/autoware/devel:latest"]
  cache-from = ["type=registry,ref=ghcr.io/youtalk/autoware:buildcache"]
  cache-to = ["type=registry,ref=ghcr.io/youtalk/autoware:buildcache,mode=max"]
}

target "runtime" {
  dockerfile = "docker/autoware-openadk/Dockerfile"
  target = "runtime"
  tags = ["ghcr.io/youtalk/autoware/runtime:latest"]
  cache-from = ["type=registry,ref=ghcr.io/youtalk/autoware:buildcache"]
  cache-to = ["type=registry,ref=ghcr.io/youtalk/autoware:buildcache,mode=max"]
}
