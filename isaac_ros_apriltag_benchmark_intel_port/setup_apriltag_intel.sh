#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS="${1:-$HOME/ros2_ws}"
ROS_DISTRO="${ROS_DISTRO:-jazzy}"

log() {
  echo "[apriltag-intel-setup] $*"
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

log "Installing required system packages"
sudo apt update
sudo apt install -y \
  ros-${ROS_DISTRO}-ros2-benchmark \
  ros-${ROS_DISTRO}-ros2-benchmark-interfaces \
  ros-${ROS_DISTRO}-apriltag \
  ros-${ROS_DISTRO}-apriltag-msgs \
  ros-${ROS_DISTRO}-apriltag-ros \
  ros-${ROS_DISTRO}-image-proc \
  ros-${ROS_DISTRO}-launch-testing \
  ros-${ROS_DISTRO}-launch-testing-ament-cmake \
  wget unzip

log "Preparing workspace at $WS"
mkdir -p "$WS/src"

fetch_repo "isaac_ros_benchmark" "https://github.com/NVIDIA-ISAAC-ROS/isaac_ros_benchmark"
fetch_repo "ros2_benchmark" "https://github.com/NVIDIA-ISAAC-ROS/ros2_benchmark"

log "Installing Apriltag benchmark script"
mkdir -p "$WS/src/isaac_ros_benchmark/benchmarks/isaac_ros_apriltag_benchmark/scripts"
cp "$SCRIPT_DIR/isaac_ros_apriltag_intel.py" \
  "$WS/src/isaac_ros_benchmark/benchmarks/isaac_ros_apriltag_benchmark/scripts/"

log "Downloading required r2b storage dataset"
mkdir -p "$WS/src/ros2_benchmark/assets/datasets/r2b_dataset/r2b_storage"
wget -O "$WS/src/ros2_benchmark/assets/datasets/r2b_dataset/r2b_storage/metadata.yaml" \
  "https://api.ngc.nvidia.com/v2/resources/nvidia/isaac/r2bdataset2023/versions/2/files/r2b_storage/metadata.yaml"
wget -O "$WS/src/ros2_benchmark/assets/datasets/r2b_dataset/r2b_storage/r2b_storage_0.db3" \
  "https://api.ngc.nvidia.com/v2/resources/nvidia/isaac/r2bdataset2023/versions/2/files/r2b_storage/r2b_storage_0.db3"

log "Setup complete. To run benchmark:"
cat <<EOF
cd "$WS"
source /opt/ros/${ROS_DISTRO}/setup.bash
export ISAAC_ROS_WS="$WS"
export R2B_PUBLISHER_UPPER_FPS=80
export R2B_PLAYBACK_BUFFER_SIZE=80
launch_test src/isaac_ros_benchmark/benchmarks/isaac_ros_apriltag_benchmark/scripts/isaac_ros_apriltag_intel.py
EOF
