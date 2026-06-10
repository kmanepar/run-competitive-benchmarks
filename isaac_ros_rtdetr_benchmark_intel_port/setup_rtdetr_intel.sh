#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS="${1:-$HOME/ros2_ws}"
ROS_DISTRO="${ROS_DISTRO:-jazzy}"
log() { echo "[rtdetr-intel-setup] $*"; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "Missing: $1" >&2; exit 1; }; }
fetch_repo() {
  local repo_name="$1" repo_url="$2"
  cd "$WS/src"
  [[ -d "$repo_name" ]] && { log "$repo_name exists"; return 0; }
  if command -v git >/dev/null 2>&1; then
    log "Cloning $repo_name"; git clone "$repo_url" "$repo_name"
  else
    need_cmd wget unzip
    local zip="${repo_name}-main.zip"
    log "Downloading $repo_name"; wget -O "$zip" "${repo_url}/archive/refs/heads/main.zip"
    unzip -o "$zip" >/tmp/${repo_name}_unzip.log; mv "${repo_name}-main" "$repo_name"
  fi
}
patch_cmake() {
  local f="$1"
  grep -q "ament_index_has_resource(HAS_ISAAC_ROS_COMMON" "$f" && { log "Already patched: $f"; return 0; }
  log "Patching $f"
  sed -i \
    -e '/ament_index_get_resource(ISAAC_ROS_COMMON_CMAKE_PATH isaac_ros_common_cmake_path isaac_ros_common)/c\ament_index_has_resource(HAS_ISAAC_ROS_COMMON isaac_ros_common_cmake_path isaac_ros_common)' \
    -e '/include("${ISAAC_ROS_COMMON_CMAKE_PATH}\/isaac_ros_common-version-info.cmake")/c\if(HAS_ISAAC_ROS_COMMON)\n  ament_index_get_resource(ISAAC_ROS_COMMON_CMAKE_PATH isaac_ros_common_cmake_path isaac_ros_common)\n  include("${ISAAC_ROS_COMMON_CMAKE_PATH}/isaac_ros_common-version-info.cmake")\n  generate_version_info(${PROJECT_NAME})\nelse()\n  message(WARNING "isaac_ros_common not found")\nendif()' \
    -e '/generate_version_info(${PROJECT_NAME})/d' "$f"
}
log "Installing packages"; sudo apt update; sudo apt install -y python3-colcon-common-extensions ros-${ROS_DISTRO}-image-proc ros-${ROS_DISTRO}-vision-msgs ros-${ROS_DISTRO}-launch-testing ros-${ROS_DISTRO}-launch-testing-ament-cmake wget unzip
log "Installing Python deps"; python3 -m pip install --user --upgrade --break-system-packages openvino numpy opencv-python
mkdir -p "$WS/src"
fetch_repo "isaac_ros_benchmark" "https://github.com/NVIDIA-ISAAC-ROS/isaac_ros_benchmark"
fetch_repo "ros2_benchmark" "https://github.com/NVIDIA-ISAAC-ROS/ros2_benchmark"
log "Installing RT-DETR benchmark script"
mkdir -p "$WS/src/isaac_ros_benchmark/benchmarks/isaac_ros_rtdetr_benchmark/scripts"
cp "$SCRIPT_DIR/isaac_ros_rtdetr_intel.py" "$WS/src/isaac_ros_benchmark/benchmarks/isaac_ros_rtdetr_benchmark/scripts/"
log "Installing Intel RT-DETR plugin scaffold"
mkdir -p "$WS/src/isaac_ros_benchmark/isaac_ros_benchmark/include/isaac_ros_benchmark" "$WS/src/isaac_ros_benchmark/isaac_ros_benchmark/src"
cp "$SCRIPT_DIR/plugin_scaffold/rtdetr_openvino_node.hpp" "$WS/src/isaac_ros_benchmark/isaac_ros_benchmark/include/isaac_ros_benchmark/"
cp "$SCRIPT_DIR/plugin_scaffold/rtdetr_openvino_node.cpp" "$WS/src/isaac_ros_benchmark/isaac_ros_benchmark/src/"
cp "$SCRIPT_DIR/plugin_scaffold/isaac_ros_benchmark.CMakeLists.txt" "$WS/src/isaac_ros_benchmark/isaac_ros_benchmark/CMakeLists.txt"
cp "$SCRIPT_DIR/plugin_scaffold/isaac_ros_benchmark.package.xml" "$WS/src/isaac_ros_benchmark/isaac_ros_benchmark/package.xml"
patch_cmake "$WS/src/ros2_benchmark/ros2_benchmark/CMakeLists.txt"
patch_cmake "$WS/src/ros2_benchmark/ros2_benchmark_interfaces/CMakeLists.txt"
log "Downloading dataset"
mkdir -p "$WS/src/ros2_benchmark/assets/datasets/r2b_dataset/r2b_storage"
wget -O "$WS/src/ros2_benchmark/assets/datasets/r2b_dataset/r2b_storage/metadata.yaml" "https://api.ngc.nvidia.com/v2/resources/nvidia/isaac/r2bdataset2023/versions/2/files/r2b_storage/metadata.yaml"
wget -O "$WS/src/ros2_benchmark/assets/datasets/r2b_dataset/r2b_storage/r2b_storage_0.db3" "https://api.ngc.nvidia.com/v2/resources/nvidia/isaac/r2bdataset2023/versions/2/files/r2b_storage/r2b_storage_0.db3"
log "Building packages"; source "/opt/ros/${ROS_DISTRO}/setup.bash"; cd "$WS"
colcon build --symlink-install --packages-select ros2_benchmark_interfaces ros2_benchmark isaac_ros_benchmark --cmake-args -DCMAKE_BUILD_TYPE=Release
cat <<EOF
cd "$WS"; source /opt/ros/${ROS_DISTRO}/setup.bash; source install/setup.bash
export ISAAC_ROS_WS="$WS" OV_DEVICE=CPU OV_NUM_INFER_THREADS=8 R2B_PUBLISHER_UPPER_FPS=80 R2B_PLAYBACK_BUFFER_SIZE=100
launch_test src/isaac_ros_benchmark/benchmarks/isaac_ros_rtdetr_benchmark/scripts/isaac_ros_rtdetr_intel.py
EOF
