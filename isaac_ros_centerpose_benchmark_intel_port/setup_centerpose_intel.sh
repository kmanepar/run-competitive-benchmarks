#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS="${1:-$HOME/ros2_ws}"
ROS_DISTRO="${ROS_DISTRO:-jazzy}"

log() {
  echo "[centerpose-intel-setup] $*"
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

fetch_repo() {
  local repo_name="$1"
  local repo_url="$2"
  cd "$WS/src"

  if [[ -d "$repo_name" ]]; then
    log "Repository '$repo_name' already exists, keeping current contents"
    return 0
  fi

  if command -v git >/dev/null 2>&1; then
    log "Cloning $repo_name with git"
    git clone "$repo_url" "$repo_name"
  else
    need_cmd wget
    need_cmd unzip
    local zip_name="${repo_name}-main.zip"
    log "git not found, downloading archive for $repo_name"
    wget -O "$zip_name" "${repo_url}/archive/refs/heads/main.zip"
    unzip -o "$zip_name" >/tmp/${repo_name}_unzip.log
    mv "${repo_name}-main" "$repo_name"
  fi
}

patch_ros2_benchmark_cmake() {
  local cmake_file="$1"
  if grep -q "ament_index_has_resource(HAS_ISAAC_ROS_COMMON" "$cmake_file"; then
    log "Already patched: $cmake_file"
    return 0
  fi

  log "Patching $cmake_file to make isaac_ros_common version-info optional"
  sed -i \
    -e '/ament_index_get_resource(ISAAC_ROS_COMMON_CMAKE_PATH isaac_ros_common_cmake_path isaac_ros_common)/c\ament_index_has_resource(HAS_ISAAC_ROS_COMMON isaac_ros_common_cmake_path isaac_ros_common)' \
    -e '/include("${ISAAC_ROS_COMMON_CMAKE_PATH}\/isaac_ros_common-version-info.cmake")/c\if(HAS_ISAAC_ROS_COMMON)\n  ament_index_get_resource(ISAAC_ROS_COMMON_CMAKE_PATH isaac_ros_common_cmake_path isaac_ros_common)\n  include("${ISAAC_ROS_COMMON_CMAKE_PATH}/isaac_ros_common-version-info.cmake")\n  generate_version_info(${PROJECT_NAME})\nelse()\n  message(WARNING "isaac_ros_common not found; skipping version info generation for ${PROJECT_NAME}")\nendif()' \
    -e '/generate_version_info(${PROJECT_NAME})/d' \
    "$cmake_file"
}

log "Installing required system packages"
sudo apt update
sudo apt install -y \
  python3-colcon-common-extensions \
  ros-${ROS_DISTRO}-image-proc \
  ros-${ROS_DISTRO}-vision-msgs \
  ros-${ROS_DISTRO}-launch-testing \
  ros-${ROS_DISTRO}-launch-testing-ament-cmake \
  wget unzip

log "Installing Python runtime dependencies"
python3 -m pip install --user --upgrade --break-system-packages openvino numpy opencv-python

log "Preparing workspace at $WS"
mkdir -p "$WS/src"

fetch_repo "isaac_ros_benchmark" "https://github.com/NVIDIA-ISAAC-ROS/isaac_ros_benchmark"
fetch_repo "ros2_benchmark" "https://github.com/NVIDIA-ISAAC-ROS/ros2_benchmark"

log "Installing CenterPose benchmark script"
mkdir -p "$WS/src/isaac_ros_benchmark/benchmarks/isaac_ros_centerpose_benchmark/scripts"
cp "$SCRIPT_DIR/isaac_ros_centerpose_intel.py" \
  "$WS/src/isaac_ros_benchmark/benchmarks/isaac_ros_centerpose_benchmark/scripts/"

log "Installing Intel CenterPose plugin scaffold"
mkdir -p "$WS/src/isaac_ros_benchmark/isaac_ros_benchmark/include/isaac_ros_benchmark"
mkdir -p "$WS/src/isaac_ros_benchmark/isaac_ros_benchmark/src"
cp "$SCRIPT_DIR/plugin_scaffold/centerpose_openvino_node.hpp" \
  "$WS/src/isaac_ros_benchmark/isaac_ros_benchmark/include/isaac_ros_benchmark/"
cp "$SCRIPT_DIR/plugin_scaffold/centerpose_openvino_node.cpp" \
  "$WS/src/isaac_ros_benchmark/isaac_ros_benchmark/src/"
cp "$SCRIPT_DIR/plugin_scaffold/isaac_ros_benchmark.CMakeLists.txt" \
  "$WS/src/isaac_ros_benchmark/isaac_ros_benchmark/CMakeLists.txt"
cp "$SCRIPT_DIR/plugin_scaffold/isaac_ros_benchmark.package.xml" \
  "$WS/src/isaac_ros_benchmark/isaac_ros_benchmark/package.xml"

patch_ros2_benchmark_cmake "$WS/src/ros2_benchmark/ros2_benchmark/CMakeLists.txt"
patch_ros2_benchmark_cmake "$WS/src/ros2_benchmark/ros2_benchmark_interfaces/CMakeLists.txt"

log "Downloading required r2b storage dataset"
mkdir -p "$WS/src/ros2_benchmark/assets/datasets/r2b_dataset/r2b_storage"
wget -O "$WS/src/ros2_benchmark/assets/datasets/r2b_dataset/r2b_storage/metadata.yaml" \
  "https://api.ngc.nvidia.com/v2/resources/nvidia/isaac/r2bdataset2023/versions/2/files/r2b_storage/metadata.yaml"
wget -O "$WS/src/ros2_benchmark/assets/datasets/r2b_dataset/r2b_storage/r2b_storage_0.db3" \
  "https://api.ngc.nvidia.com/v2/resources/nvidia/isaac/r2bdataset2023/versions/2/files/r2b_storage/r2b_storage_0.db3"

log "Building benchmark packages"
source "/opt/ros/${ROS_DISTRO}/setup.bash"
cd "$WS"
colcon build --symlink-install --packages-select \
  ros2_benchmark_interfaces ros2_benchmark isaac_ros_benchmark \
  --cmake-args -DCMAKE_BUILD_TYPE=Release

log "Setup complete. To run benchmark:"
cat <<EOF
cd "$WS"
source /opt/ros/${ROS_DISTRO}/setup.bash
source install/setup.bash
export ISAAC_ROS_WS="$WS"
export OV_DEVICE=CPU
export OV_NUM_INFER_THREADS=8
export R2B_PUBLISHER_UPPER_FPS=80
export R2B_PLAYBACK_BUFFER_SIZE=100
launch_test src/isaac_ros_benchmark/benchmarks/isaac_ros_centerpose_benchmark/scripts/isaac_ros_centerpose_intel.py
EOF
