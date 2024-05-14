group "default" {
  targets = ["prebuilt", "devel", "runtime"]
}

target "prebuilt" {
  dockerfile = "docker/autoware-openadk/Dockerfile"
  target = "prebuilt"
  cache-from = ["type=registry,ref=ghcr.io/youtalk/autoware:buildcache"]
  cache-to = ["type=registry,ref=ghcr.io/youtalk/autoware:buildcache,mode=max"]
}

target "devel" {
  dockerfile = "docker/autoware-openadk/Dockerfile"
  target = "devel"
cache-from = ["type=registry,ref=ghcr.io/youtalk/autoware:buildcache"]
  cache-to = ["type=registry,ref=ghcr.io/youtalk/autoware:buildcache,mode=max"]
}

target "runtime" {
  dockerfile = "docker/autoware-openadk/Dockerfile"
  target = "runtime"
  cache-from = ["type=registry,ref=ghcr.io/youtalk/autoware:buildcache"]
  cache-to = ["type=registry,ref=ghcr.io/youtalk/autoware:buildcache,mode=max"]
}
