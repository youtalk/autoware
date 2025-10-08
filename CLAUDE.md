# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is the Autoware meta-repository - the world's leading open-source software stack for autonomous driving built on ROS 2 (Robot Operating System 2). It contains `.repos` files that define the complete Autoware workspace by pulling in multiple external repositories.

The repository structure follows a modular architecture:
- **core/**: Stable, high-quality ROS packages (based on Autoware.Auto and Autoware.Universe)
- **universe/**: Experimental and cutting-edge ROS packages for autonomous driving research
- **launcher/**: Launch configurations and node parameters (autoware_launch)
- **sensor_component/**: Sensor drivers and interfaces (Nebula, transport_drivers, etc.)
- **middleware/**: Communication middleware (Agnocast)
- **param/**: Parameter configurations
- **docker/**: Open AD Kit containerized workloads

## Development Environment Setup

### Initial Setup
```bash
# Set up development environment (installs dependencies via Ansible)
./setup-dev-env.sh

# Or for non-interactive mode (CI)
./setup-dev-env.sh -y

# Without NVIDIA libraries
./setup-dev-env.sh --no-nvidia

# Download Autoware workspace dependencies
vcs import src < autoware.repos
```

### Using Docker (Open AD Kit)
```bash
# Development container with CUDA
docker run -it --rm \
  -v $PWD/src/universe/autoware_universe/XXX/autoware_YYY:/autoware/src/autoware_YYY \
  ghcr.io/autowarefoundation/autoware:universe-devel-cuda

# Without CUDA
docker run -it --rm ghcr.io/autowarefoundation/autoware:universe-devel
```

## Build System

Autoware uses **colcon** (ROS 2 build tool) with CMake for building packages.

### Building
```bash
# Build all packages
colcon build --symlink-install

# Build with debug symbols
colcon build --mixin debug compile-commands

# Build specific package
colcon build --packages-select <package_name>

# Build package and dependencies
colcon build --packages-up-to <package_name>

# Parallel build with 8 jobs
colcon build --parallel-workers 8
```

### Sourcing
```bash
# Source the workspace
source install/setup.bash
```

## Testing

### Running Tests
```bash
# Run all tests
colcon test

# Run tests for specific package
colcon test --packages-select <package_name>

# Show test results
colcon test-result --all --verbose
```

## Code Quality and Linting

### Pre-commit Hooks
The repository uses pre-commit hooks for code quality. Key tools:
- **C++**: clang-format, cpplint, clang-tidy
- **Python**: black, isort, flake8
- **Shell**: shellcheck, shfmt
- **ROS**: prettier-xacro, prettier-launch-xml, sort-package-xml
- **General**: markdownlint, prettier, yamllint

```bash
# Install pre-commit hooks
pre-commit install

# Run manually on all files
pre-commit run --all-files

# Run on specific files
pre-commit run --files <file_path>
```

### Linting Configuration
- C++ formatting: `.clang-format`, `.clang-tidy`, `.clang-tidy-ci`, `CPPLINT.cfg`
- Python: `setup.cfg` (flake8, isort)
- YAML: `.yamllint.yaml`
- Markdown: `.markdownlint.yaml`

## Architecture and Component Organization

### Core Packages (src/core/)
Stable packages including:
- `autoware_msgs`, `autoware_adapi_msgs`, `autoware_internal_msgs`: Message definitions
- `autoware_cmake`: Build system utilities
- `autoware_utils`: Common utilities
- `autoware_lanelet2_extension`: HD map handling
- `autoware_core`: Core autonomous driving functionality
- `autoware_rviz_plugins`: Visualization plugins

### Universe Packages (src/universe/autoware_universe/)
Organized by functional domain:
- `common/`: Shared utilities and interfaces
- `perception/`: Object detection, tracking, traffic light recognition
- `sensing/`: Sensor data preprocessing, GNSS, LiDAR utilities
- `localization/`: NDT scan matching, EKF, pose estimation
- `map/`: Map loading and projection
- `planning/`: Path planning, behavior planning, motion planning
- `control/`: Vehicle control, trajectory following, safety checks
- `vehicle/`: Vehicle interfaces and calibration
- `system/`: System monitoring, diagnostics, fault handling
- `simulator/`: Simulation components
- `evaluator/`: Performance evaluation tools
- `visualization/`: Visualization utilities

### External Dependencies (universe/external/)
Third-party packages:
- TIER IV proprietary adapters
- MORAI simulation messages
- Sensor-specific libraries (Eagleye, Nebula)
- CUDA/TensorRT packages

## Working with `.repos` Files

The `.repos` files define repository dependencies using vcstools format:

```bash
# Import repositories
vcs import src < autoware.repos

# Update repositories to latest
vcs pull src

# Check status
vcs status src
```

Available `.repos` files:
- `autoware.repos`: Main Autoware packages
- `simulator.repos`: Simulator dependencies
- `tools.repos`: Development tools
- `*-nightly.repos`: Nightly/development versions

## Running Autoware

### Planning Simulator
```bash
ros2 launch autoware_launch planning_simulator.launch.xml \
  map_path:=/path/to/map \
  vehicle_model:=sample_vehicle \
  sensor_model:=sample_sensor_kit
```

### Common ROS 2 Commands
```bash
# List nodes
ros2 node list

# List topics
ros2 topic list

# Echo topic
ros2 topic echo /topic_name

# Show node info
ros2 node info /node_name

# Launch with parameters
ros2 launch <package_name> <launch_file> param:=value
```

## Debugging

### Using GDB with ROS 2
```bash
# Run node with GDB
ros2 run --prefix "gdb -ex run --args" <package_name> <executable>

# Attach to running node
gdb -p <pid>
```

### Useful Tools
```bash
# Record rosbag
ros2 bag record -a

# Play rosbag
ros2 bag play <bag_file>

# RViz visualization
ros2 run rviz2 rviz2
```

## Key Development Notes

- **ROS 2 Distribution**: Humble (Ubuntu 22.04)
- **Build System**: colcon + CMake
- **Message Format**: ROS 2 messages (IDL-based)
- **Package Structure**: Each package contains `package.xml` and `CMakeLists.txt`
- **CUDA Support**: Optional, controlled via setup flags (`--no-nvidia`)
- **Git Submodules**: NOT used; dependencies managed via `.repos` files and vcstools

## Repository Management

### Branch Structure
- `main`: Main development branch
- PRs target `main` by default

### CI/CD
- GitHub Actions workflows in `.github/workflows/`
- Pre-commit CI for automated checks
- Docker image builds via `docker-build-and-push.yaml`
- Health checks, scenario tests, and more

## Documentation

- Official docs: https://autowarefoundation.github.io/autoware-documentation/main/
- Contributing guide: https://autowarefoundation.github.io/autoware-documentation/main/contributing/
- Docker documentation: See `docker/README.md`
