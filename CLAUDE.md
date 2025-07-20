# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Autoware is an open-source autonomous driving software stack built on ROS 2. It provides perception, localization, planning, and control modules for self-driving vehicles.

## Essential Development Commands

### Building
```bash
# Standard build
colcon build --symlink-install --cmake-args -DCMAKE_BUILD_TYPE=Release

# Debug build with compile commands
colcon build --mixin debug compile-commands

# Build specific package
colcon build --packages-select <package_name>

# Build with tests
colcon build --packages-select <package_name> --cmake-args -DBUILD_TESTING=ON
```

### Testing
```bash
# Run all tests
colcon test

# Run tests for specific package
colcon test --packages-select <package_name>

# View test results
colcon test-result --verbose

# Run single test executable (example)
./build/<package_name>/test/<test_executable>
```

### Linting and Formatting
```bash
# Run pre-commit hooks on all files
pre-commit run --all-files

# The project uses:
# - clang-format for C++ (Google style with modifications)
# - black for Python (line length 100)
# - cpplint for C++ linting
# - shellcheck/shfmt for shell scripts
```

### Running Autoware
```bash
# Planning simulator (no real vehicle needed)
ros2 launch autoware_launch planning_simulator.launch.xml \
  map_path:=/path/to/map \
  vehicle_model:=sample_vehicle \
  sensor_model:=sample_sensor_kit

# Docker Compose (recommended)
docker compose --profile planning-simulation up
```

## Architecture Overview

Autoware follows a modular architecture organized by functionality:

### Core Components Location
- **Perception**: `src/universe/autoware_universe/perception/` - Object detection, tracking, traffic light recognition
- **Localization**: `src/universe/autoware_universe/localization/` - NDT matching, EKF, GNSS fusion
- **Planning**: `src/universe/autoware_universe/planning/` - Mission, behavior, and motion planning
- **Control**: `src/universe/autoware_universe/control/` - Trajectory following, vehicle commands
- **Map**: `src/universe/autoware_universe/map/` - Lanelet2 HD maps, point cloud maps

### Key Design Patterns

1. **Package Structure**: Each package follows ROS 2 ament_cmake conventions with:
   - `package.xml` - Dependencies and metadata
   - `CMakeLists.txt` - Build configuration using `autoware_package()` macro
   - `include/<package_name>/` - Public headers
   - `src/` - Implementation files
   - `test/` - Unit tests using Google Test

2. **Node Architecture**: Most nodes follow a component-based design:
   - Inherit from `rclcpp::Node` or `rclcpp_lifecycle::LifecycleNode`
   - Use ROS 2 parameters for configuration
   - Implement callbacks for subscribers
   - Publish results on standardized topics

3. **Message Passing**: Uses custom message types defined in:
   - `src/core/autoware_msgs/` - Core message definitions
   - `tier4_autoware_msgs` - Extended message types

4. **Launch System**: Hierarchical launch files in `src/launcher/autoware_launch/`:
   - Component launches: `tier4_*_component.launch.xml`
   - Full system launch: `autoware.launch.xml`
   - Simulator launch: `planning_simulator.launch.xml`

### Development Workflow

1. **Adding New Features**:
   - Create package in appropriate directory under `src/universe/autoware_universe/`
   - Use `autoware_package()` in CMakeLists.txt
   - Follow existing package structure and naming conventions
   - Add to appropriate component launch file

2. **Modifying Existing Nodes**:
   - Check node's README for specific details
   - Maintain backward compatibility with ROS parameters
   - Update tests when changing functionality
   - Follow the established coding style (Google C++ style with modifications)

3. **Testing Changes**:
   - Unit tests go in `test/` directory
   - Integration tests use ROS 2 launch testing
   - Use planning simulator for system-level testing

### Important Files and Locations

- **Repository dependencies**: `autoware.repos` - VCS file listing all required repositories
- **Docker configurations**: `docker/` - Dockerfiles and scripts for containerized development
- **Pre-commit config**: `.pre-commit-config.yaml` - Code quality checks
- **Environment setup**: `setup-dev-env.sh` - Ansible-based development environment setup

### Common Development Tasks

When working on Autoware code:
1. Always source the ROS 2 environment before building
2. Use `--symlink-install` for faster development iterations
3. Check package-specific README files for detailed documentation
4. Use Docker Compose profiles for consistent testing environments
5. Run pre-commit hooks before committing to ensure code quality