group "default" {
  targets = ["prebuilt", "devel", "runtime"]
}

target "prebuilt" {
  dockerfile = "docker/autoware-openadk/Dockerfile"
  target = "prebuilt"
  tags = ["ghcr.io/${GITHUB_REPOSITORY}/prebuilt:latest"]
  cache-from = ["type=registry,ref=ghcr.io/${GITHUB_REPOSITORY}:buildcache"]
  cache-to = ["type=registry,ref=ghcr.io/${GITHUB_REPOSITORY}:buildcache,mode=max"]
}

target "devel" {
  dockerfile = "docker/autoware-openadk/Dockerfile"
  target = "devel"
  tags = ["ghcr.io/${GITHUB_REPOSITORY}/devel:latest"]
  cache-from = ["type=registry,ref=ghcr.io/${GITHUB_REPOSITORY}:buildcache"]
  cache-to = ["type=registry,ref=ghcr.io/${GITHUB_REPOSITORY}:buildcache,mode=max"]
}

target "runtime" {
  dockerfile = "docker/autoware-openadk/Dockerfile"
  target = "runtime"
  tags = ["ghcr.io/${GITHUB_REPOSITORY}/runtime:latest"]
  cache-from = ["type=registry,ref=ghcr.io/${GITHUB_REPOSITORY}:buildcache"]
  cache-to = ["type=registry,ref=ghcr.io/${GITHUB_REPOSITORY}:buildcache,mode=max"]
}
