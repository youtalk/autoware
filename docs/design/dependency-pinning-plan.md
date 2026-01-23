# 依存パッケージバージョン固定 実装計画

## 概要

プロダクトとして頑健なリリース管理を実現するため、APTパッケージおよびPythonパッケージの依存関係をロックファイル方式でバージョン固定する。

## 採用アプローチ

| セットアップ種別 | 採用アプローチ |
|-----------------|---------------|
| Dockerコンテナ版 | アプローチA: ロックファイル方式 |
| ネイティブ版 | アプローチA: Ansibleロックファイル方式 |

---

## 1. Dockerコンテナセットアップ版

### 1.1 アーキテクチャ

```
┌─────────────────────────────────────────────────────────────────┐
│                      ビルドフロー                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  [開発ビルド]                    [リリースビルド]                │
│       │                               │                         │
│       ▼                               ▼                         │
│  ┌─────────────┐               ┌─────────────┐                 │
│  │ 通常ビルド   │               │ --locked    │                 │
│  │ (最新取得)   │               │ モード      │                 │
│  └──────┬──────┘               └──────┬──────┘                 │
│         │                              │                        │
│         ▼                              ▼                        │
│  ┌─────────────┐               ┌─────────────┐                 │
│  │ ロックファイル│               │ ロックファイル│                 │
│  │ 生成        │               │ から固定     │                 │
│  │             │               │ バージョン    │                 │
│  │ - apt.lock  │               │ インストール  │                 │
│  │ - pip.lock  │               │             │                 │
│  │ - rosdep.lock│              │             │                 │
│  └─────────────┘               └─────────────┘                 │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2 新規ファイル構成

```
autoware/
├── docker/
│   ├── lockfiles/
│   │   ├── amd64/
│   │   │   ├── apt-packages.lock          # APTパッケージ一覧
│   │   │   ├── python-packages.lock       # Pythonパッケージ一覧
│   │   │   └── rosdep-resolved.lock       # rosdep解決結果
│   │   └── arm64/
│   │       ├── apt-packages.lock
│   │       ├── python-packages.lock
│   │       └── rosdep-resolved.lock
│   ├── scripts/
│   │   ├── generate_lockfiles.sh          # ロックファイル生成
│   │   └── install_from_lockfile.sh       # ロックファイルからインストール
│   └── Dockerfile                          # --locked引数対応
├── amd64.env                               # base_image_digest追加
└── arm64.env                               # base_image_digest追加
```

### 1.3 ロックファイルフォーマット

#### apt-packages.lock
```
# Generated: 2026-01-23T10:00:00Z
# Platform: amd64
# Base Image: ros:humble-ros-base-jammy@sha256:abc123...
apt-utils=2.4.11
build-essential=12.9ubuntu3
cmake=3.22.1-1ubuntu1.22.04.2
curl=7.81.0-1ubuntu1.18
ros-humble-desktop=0.10.0-1jammy.20250115.123456
ros-humble-rmw-cyclonedds-cpp=1.3.4-1jammy.20250110.054321
python3-colcon-common-extensions=0.3.0-1
...
```

#### python-packages.lock
```
# Generated: 2026-01-23T10:00:00Z
# Platform: amd64
ansible==10.7.0
colcon-core==0.16.1
pytest==7.4.3
...
```

#### rosdep-resolved.lock
```
# Generated: 2026-01-23T10:00:00Z
# ROS Distro: humble
# Component: universe-common
ros-humble-ament-cmake-auto=1.3.7-1jammy.20250110.123456
ros-humble-rclcpp=21.2.0-1jammy.20250112.234567
ros-humble-tf2-ros=0.31.3-1jammy.20250111.345678
...
```

### 1.4 実装詳細

#### 1.4.1 generate_lockfiles.sh

```bash
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOCKFILE_DIR="${SCRIPT_DIR}/../lockfiles"
ARCH=$(dpkg --print-architecture)

# APTパッケージのロックファイル生成
generate_apt_lockfile() {
    local output_file="${LOCKFILE_DIR}/${ARCH}/apt-packages.lock"
    mkdir -p "$(dirname "$output_file")"

    {
        echo "# Generated: $(date -Iseconds)"
        echo "# Platform: ${ARCH}"
        echo "# Base Image: ${BASE_IMAGE:-unknown}"
        dpkg-query -W -f='${Package}=${Version}\n' | sort
    } > "$output_file"

    echo "Generated: $output_file"
}

# Pythonパッケージのロックファイル生成
generate_pip_lockfile() {
    local output_file="${LOCKFILE_DIR}/${ARCH}/python-packages.lock"
    mkdir -p "$(dirname "$output_file")"

    {
        echo "# Generated: $(date -Iseconds)"
        echo "# Platform: ${ARCH}"
        pip3 freeze | sort
    } > "$output_file"

    echo "Generated: $output_file"
}

# rosdep解決結果のロックファイル生成
generate_rosdep_lockfile() {
    local src_path="${1:-/autoware/src}"
    local ros_distro="${ROS_DISTRO:-humble}"
    local output_file="${LOCKFILE_DIR}/${ARCH}/rosdep-resolved.lock"
    mkdir -p "$(dirname "$output_file")"

    {
        echo "# Generated: $(date -Iseconds)"
        echo "# ROS Distro: ${ros_distro}"
        rosdep keys --ignore-src --from-paths "$src_path" 2>/dev/null | \
            xargs -I {} sh -c "rosdep resolve {} --rosdistro $ros_distro 2>/dev/null | tail -1" | \
            xargs dpkg-query -W -f='${Package}=${Version}\n' 2>/dev/null | \
            sort | uniq
    } > "$output_file"

    echo "Generated: $output_file"
}

# メイン処理
main() {
    echo "Generating lockfiles for ${ARCH}..."
    generate_apt_lockfile
    generate_pip_lockfile
    generate_rosdep_lockfile "$@"
    echo "Done."
}

main "$@"
```

#### 1.4.2 install_from_lockfile.sh

```bash
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOCKFILE_DIR="${SCRIPT_DIR}/../lockfiles"
ARCH=$(dpkg --print-architecture)

# APTパッケージのインストール（ロックファイルから）
install_apt_from_lockfile() {
    local lockfile="${LOCKFILE_DIR}/${ARCH}/apt-packages.lock"

    if [[ ! -f "$lockfile" ]]; then
        echo "Error: Lockfile not found: $lockfile" >&2
        exit 1
    fi

    echo "Installing APT packages from lockfile..."

    # コメント行を除外してインストール
    grep -v '^#' "$lockfile" | grep -v '^$' | \
        xargs apt-get install -y --no-install-recommends --allow-downgrades
}

# Pythonパッケージのインストール（ロックファイルから）
install_pip_from_lockfile() {
    local lockfile="${LOCKFILE_DIR}/${ARCH}/python-packages.lock"

    if [[ ! -f "$lockfile" ]]; then
        echo "Warning: Pip lockfile not found: $lockfile" >&2
        return 0
    fi

    echo "Installing Python packages from lockfile..."

    # コメント行を除外してインストール
    grep -v '^#' "$lockfile" | grep -v '^$' > /tmp/requirements.txt
    pip3 install --no-cache-dir -r /tmp/requirements.txt
    rm /tmp/requirements.txt
}

# メイン処理
main() {
    local mode="${1:-all}"

    case "$mode" in
        apt)
            install_apt_from_lockfile
            ;;
        pip)
            install_pip_from_lockfile
            ;;
        all)
            install_apt_from_lockfile
            install_pip_from_lockfile
            ;;
        *)
            echo "Usage: $0 [apt|pip|all]" >&2
            exit 1
            ;;
    esac
}

main "$@"
```

#### 1.4.3 Dockerfile変更（差分）

```dockerfile
# ビルド引数追加
ARG USE_LOCKFILE=false

# ロックファイルコピー（--lockedモード時のみ使用）
COPY docker/lockfiles /autoware/lockfiles

# 条件分岐によるインストール
RUN if [ "$USE_LOCKFILE" = "true" ]; then \
        /autoware/docker/scripts/install_from_lockfile.sh apt; \
    else \
        rosdep update && \
        /autoware/resolve_rosdep_keys.sh /autoware/src "${ROS_DISTRO}" | \
        xargs apt-get install -y; \
    fi
```

#### 1.4.4 環境ファイル変更

```bash
# amd64.env に追加
base_image=ros:humble-ros-base-jammy
base_image_digest=sha256:abc123def456...  # 追加

autoware_base_image=ghcr.io/autowarefoundation/autoware-base:latest
autoware_base_image_digest=sha256:789xyz...  # 追加
```

### 1.5 CI/CDワークフロー

#### ロックファイル生成ワークフロー

```yaml
# .github/workflows/generate-lockfiles.yaml
name: Generate Lockfiles

on:
  workflow_dispatch:
  schedule:
    - cron: '0 0 * * 0'  # 週次実行

jobs:
  generate:
    strategy:
      matrix:
        arch: [amd64, arm64]
    runs-on: ${{ matrix.arch == 'arm64' && 'self-hosted-arm64' || 'ubuntu-latest' }}
    steps:
      - uses: actions/checkout@v4

      - name: Build and generate lockfiles
        run: |
          docker build -t autoware:lockfile-gen .
          docker run --rm -v $PWD/docker/lockfiles:/output autoware:lockfile-gen \
            /autoware/docker/scripts/generate_lockfiles.sh

      - name: Create PR with updated lockfiles
        uses: peter-evans/create-pull-request@v5
        with:
          title: "chore: update dependency lockfiles"
          branch: chore/update-lockfiles
```

#### ロックファイル検証ワークフロー

```yaml
# .github/workflows/validate-lockfiles.yaml
name: Validate Lockfiles

on:
  pull_request:
    paths:
      - 'docker/lockfiles/**'

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Validate lockfile format
        run: |
          ./scripts/validate_lockfiles.sh

      - name: Test locked build
        run: |
          docker build --build-arg USE_LOCKFILE=true -t autoware:locked-test .
```

---

## 2. ネイティブセットアップ版

### 2.1 アーキテクチャ

```
┌─────────────────────────────────────────────────────────────────┐
│                      セットアップフロー                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  [開発セットアップ]              [リリースセットアップ]          │
│       │                               │                         │
│       ▼                               ▼                         │
│  ┌─────────────┐               ┌─────────────┐                 │
│  │ setup-dev-  │               │ setup-dev-  │                 │
│  │ env.sh      │               │ env.sh      │                 │
│  │ (通常)      │               │ --locked    │                 │
│  └──────┬──────┘               └──────┬──────┘                 │
│         │                              │                        │
│         ▼                              ▼                        │
│  ┌─────────────┐               ┌─────────────┐                 │
│  │ Ansible     │               │ Ansible     │                 │
│  │ state:latest│               │ 固定バージョン│                 │
│  └──────┬──────┘               └──────┬──────┘                 │
│         │                              │                        │
│         ▼                              ▼                        │
│  ┌─────────────┐               ┌─────────────┐                 │
│  │ ロックファイル│               │ locked-     │                 │
│  │ 生成可能    │               │ versions.yaml│                 │
│  └─────────────┘               │ 参照        │                 │
│                                └─────────────┘                 │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 新規ファイル構成

```
autoware/
├── ansible/
│   ├── vars/
│   │   ├── locked-versions-humble-amd64.yaml   # Humble/amd64用
│   │   ├── locked-versions-humble-arm64.yaml   # Humble/arm64用
│   │   ├── locked-versions-jazzy-amd64.yaml    # Jazzy/amd64用
│   │   └── locked-versions-jazzy-arm64.yaml    # Jazzy/arm64用
│   └── roles/
│       └── */tasks/main.yaml                    # バージョン指定対応
├── scripts/
│   ├── generate_ansible_lockfile.sh            # ロックファイル生成
│   └── validate_ansible_lockfile.sh            # ロックファイル検証
└── setup-dev-env.sh                            # --lockedオプション追加
```

### 2.3 ロックファイルフォーマット

#### locked-versions-humble-amd64.yaml

```yaml
# Dependency Version Lockfile
# Generated: 2026-01-23T10:00:00Z
# ROS Distro: humble
# Platform: amd64
# Ubuntu: 22.04 (jammy)

# ROS2 packages
ros2_packages:
  ros-humble-desktop: "0.10.0-1jammy.20250115.123456"
  ros-humble-rmw-cyclonedds-cpp: "1.3.4-1jammy.20250110.054321"
  ros-humble-rclcpp: "21.2.0-1jammy.20250112.234567"
  ros-humble-tf2-ros: "0.31.3-1jammy.20250111.345678"

# Development tools
dev_tools_packages:
  python3-colcon-mixin: "0.2.0-1"
  python3-colcon-common-extensions: "0.3.0-1"
  python3-pytest: "7.4.3-1"
  python3-pytest-cov: "4.1.0-1"
  python3-flake8: "5.0.4-4"

# Build tools
build_packages:
  build-essential: "12.9ubuntu3"
  cmake: "3.22.1-1ubuntu1.22.04.2"
  ccache: "4.5.1-1"

# System libraries
system_packages:
  libboost-all-dev: "1.74.0.3ubuntu7"
  libeigen3-dev: "3.4.0-2ubuntu2"
  libpcl-dev: "1.12.1+dfsg-3build1"
  libopencv-dev: "4.5.4+dfsg-9ubuntu4"

# CUDA packages (from env file, reference only)
cuda_packages:
  cuda-command-line-tools-12-8: "12.8.0-1"
  cuda-minimal-build-12-8: "12.8.0-1"
  libcusparse-dev-12-8: "12.8.0.41-1"

# TensorRT packages (from env file, reference only)
tensorrt_packages:
  libnvinfer10: "10.8.0.43-1+cuda12.8"
  libnvinfer-plugin10: "10.8.0.43-1+cuda12.8"
  libnvonnxparsers10: "10.8.0.43-1+cuda12.8"
```

### 2.4 実装詳細

#### 2.4.1 setup-dev-env.sh変更（差分）

```bash
# オプション追加
usage() {
    cat << EOF
Usage: $0 [OPTIONS] [TARGET]
...
  --locked              Use locked package versions for reproducible builds
...
EOF
}

# 変数追加
use_locked_versions=false

# オプションパース追加
while [[ $# -gt 0 ]]; do
    case $1 in
        --locked)
            use_locked_versions=true
            shift
            ;;
        # ... 既存オプション
    esac
done

# Ansible実行時に変数を渡す
ansible_args+=("-e" "use_locked_versions=${use_locked_versions}")
if [[ "$use_locked_versions" == "true" ]]; then
    lockfile="ansible/vars/locked-versions-${rosdistro}-$(dpkg --print-architecture).yaml"
    if [[ -f "$lockfile" ]]; then
        ansible_args+=("-e" "@${lockfile}")
    else
        echo "Error: Lockfile not found: $lockfile" >&2
        exit 1
    fi
fi
```

#### 2.4.2 Ansibleロール変更例（ros2_dev_tools）

```yaml
# ansible/roles/ros2_dev_tools/tasks/main.yaml

- name: Install ROS2 development tools (locked versions)
  become: true
  ansible.builtin.apt:
    name:
      - "python3-colcon-mixin={{ dev_tools_packages['python3-colcon-mixin'] }}"
      - "python3-colcon-common-extensions={{ dev_tools_packages['python3-colcon-common-extensions'] }}"
      - "python3-pytest={{ dev_tools_packages['python3-pytest'] }}"
      - "python3-pytest-cov={{ dev_tools_packages['python3-pytest-cov'] }}"
      - "python3-flake8={{ dev_tools_packages['python3-flake8'] }}"
    state: present
    allow_downgrade: true
  when: use_locked_versions | default(false)

- name: Install ROS2 development tools (latest)
  become: true
  ansible.builtin.apt:
    name:
      - python3-colcon-mixin
      - python3-colcon-common-extensions
      - python3-pytest
      - python3-pytest-cov
      - python3-flake8
    state: latest
    update_cache: true
  when: not (use_locked_versions | default(false))
```

#### 2.4.3 generate_ansible_lockfile.sh

```bash
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AUTOWARE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROS_DISTRO="${ROS_DISTRO:-humble}"
ARCH=$(dpkg --print-architecture)

OUTPUT_FILE="${AUTOWARE_DIR}/ansible/vars/locked-versions-${ROS_DISTRO}-${ARCH}.yaml"

# パッケージカテゴリごとにバージョンを取得
get_package_versions() {
    local category="$1"
    shift
    local packages=("$@")

    echo "${category}:"
    for pkg in "${packages[@]}"; do
        version=$(dpkg-query -W -f='${Version}' "$pkg" 2>/dev/null || echo "not-installed")
        echo "  ${pkg}: \"${version}\""
    done
}

# メイン処理
main() {
    echo "Generating Ansible lockfile: $OUTPUT_FILE"

    {
        echo "# Dependency Version Lockfile"
        echo "# Generated: $(date -Iseconds)"
        echo "# ROS Distro: ${ROS_DISTRO}"
        echo "# Platform: ${ARCH}"
        echo "# Ubuntu: $(lsb_release -rs) ($(lsb_release -cs))"
        echo ""

        # ROS2パッケージ
        ros2_packages=(
            "ros-${ROS_DISTRO}-desktop"
            "ros-${ROS_DISTRO}-rmw-cyclonedds-cpp"
            "ros-${ROS_DISTRO}-rclcpp"
            "ros-${ROS_DISTRO}-tf2-ros"
        )
        get_package_versions "ros2_packages" "${ros2_packages[@]}"
        echo ""

        # 開発ツール
        dev_tools=(
            "python3-colcon-mixin"
            "python3-colcon-common-extensions"
            "python3-pytest"
            "python3-pytest-cov"
            "python3-flake8"
        )
        get_package_versions "dev_tools_packages" "${dev_tools[@]}"
        echo ""

        # ビルドツール
        build_tools=(
            "build-essential"
            "cmake"
            "ccache"
        )
        get_package_versions "build_packages" "${build_tools[@]}"
        echo ""

        # システムライブラリ
        system_libs=(
            "libboost-all-dev"
            "libeigen3-dev"
            "libpcl-dev"
            "libopencv-dev"
        )
        get_package_versions "system_packages" "${system_libs[@]}"

    } > "$OUTPUT_FILE"

    echo "Generated: $OUTPUT_FILE"
}

main "$@"
```

### 2.5 CI/CDワークフロー

```yaml
# .github/workflows/generate-ansible-lockfiles.yaml
name: Generate Ansible Lockfiles

on:
  workflow_dispatch:
  schedule:
    - cron: '0 0 * * 0'

jobs:
  generate:
    strategy:
      matrix:
        rosdistro: [humble, jazzy]
        arch: [amd64, arm64]
    runs-on: ${{ matrix.arch == 'arm64' && 'self-hosted-arm64' || 'ubuntu-latest' }}
    steps:
      - uses: actions/checkout@v4

      - name: Setup environment
        run: |
          ./setup-dev-env.sh -y --module all

      - name: Generate lockfile
        run: |
          ROS_DISTRO=${{ matrix.rosdistro }} ./scripts/generate_ansible_lockfile.sh

      - name: Upload lockfile
        uses: actions/upload-artifact@v4
        with:
          name: lockfile-${{ matrix.rosdistro }}-${{ matrix.arch }}
          path: ansible/vars/locked-versions-*.yaml
```

---

## 3. 実装フェーズ

### Phase 1: 基盤整備（Week 1-2）

| タスク | 担当 | 成果物 |
|--------|------|--------|
| ロックファイルフォーマット策定 | - | 本ドキュメント |
| Dockerベースイメージダイジェスト固定 | - | amd64.env, arm64.env |
| ロックファイル生成スクリプト作成 | - | generate_lockfiles.sh |
| 基本的なCI/CD設定 | - | .github/workflows/*.yaml |

### Phase 2: Dockerコンテナ版実装（Week 3-4）

| タスク | 担当 | 成果物 |
|--------|------|--------|
| Dockerfile改修（--locked対応） | - | docker/Dockerfile |
| install_from_lockfile.sh作成 | - | docker/scripts/ |
| 初回ロックファイル生成 | - | docker/lockfiles/ |
| ロックビルドのテスト | - | テスト結果 |

### Phase 3: ネイティブセットアップ版実装（Week 5-6）

| タスク | 担当 | 成果物 |
|--------|------|--------|
| setup-dev-env.sh改修 | - | setup-dev-env.sh |
| Ansibleロール改修 | - | ansible/roles/*/tasks/main.yaml |
| ロックファイル生成スクリプト | - | scripts/generate_ansible_lockfile.sh |
| 初回ロックファイル生成 | - | ansible/vars/*.yaml |

### Phase 4: 運用整備（Week 7-8）

| タスク | 担当 | 成果物 |
|--------|------|--------|
| ロックファイル更新ワークフロー整備 | - | CI/CD設定 |
| セキュリティ更新プロセス策定 | - | 運用ドキュメント |
| ユーザードキュメント作成 | - | docs/ |
| リリースプロセスへの統合 | - | リリース手順書 |

---

## 4. 運用ガイドライン

### 4.1 ロックファイル更新タイミング

- **定期更新**: 週次で自動生成（CI/CD）
- **手動更新**: セキュリティパッチ適用時
- **リリース時**: リリースブランチでロックファイルを固定

### 4.2 セキュリティ更新プロセス

1. セキュリティアドバイザリの確認
2. 該当パッケージの新バージョン検証
3. ロックファイルの更新
4. テスト実行
5. リリース

### 4.3 トラブルシューティング

| 問題 | 対処法 |
|------|--------|
| パッケージが見つからない | リポジトリのスナップショットを確認、代替バージョンを検討 |
| 依存関係の競合 | `apt-get install -f`で依存解決、必要に応じてロックファイル調整 |
| ビルドエラー | 通常モード（非locked）でビルドし、原因特定 |

---

## 5. 参考資料

- [ROS 2 Documentation - rosdep](https://docs.ros.org/en/humble/Tutorials/Intermediate/Rosdep.html)
- [Ansible apt module](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/apt_module.html)
- [Docker Build Cache](https://docs.docker.com/build/cache/)
- [Ubuntu Snapshot Service](https://snapshot.ubuntu.com/)
