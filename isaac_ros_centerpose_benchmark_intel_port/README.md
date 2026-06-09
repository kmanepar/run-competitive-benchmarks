# Isaac ROS CenterPose Benchmark - Intel Port

This folder contains a standalone Intel benchmark script for CenterPose:
- `isaac_ros_centerpose_intel.py`

The workflow is based on the successful AprilTag lessons:
1. Use `launch_test` to run benchmark test scripts.
2. Avoid trying to build the full unmodified NVIDIA workspace on Intel-only machines (CUDA/NVCC dependency conflicts).
3. Use the Intel-ported `isaac_ros_benchmark` source for the OpenVINO node.

## What this script expects
The script uses the Intel OpenVINO composable node:
- `isaac_ros_benchmark::CenterPoseOpenVINONode`

It also expects:
- `ros2_benchmark`
- `image_proc`
- CenterPose synthetic model at:
  `src/ros2_benchmark/assets/models/centerpose_shoe/centerpose_shoe.xml`
- Dataset at:
  `src/ros2_benchmark/assets/datasets/r2b_dataset/r2b_storage`

## Setup Instructions

### 1) Create ROS workspace and download source

```bash
mkdir -p ~/ros2_ws/src
cd ~/ros2_ws/src

# NVIDIA benchmark framework repo
git clone https://github.com/NVIDIA-ISAAC-ROS/isaac_ros_benchmark.git

# NVIDIA benchmark runner repo
git clone https://github.com/NVIDIA-ISAAC-ROS/ros2_benchmark.git
```

### 2) Replace benchmark source with Intel-ported code

The CenterPose Intel benchmark script requires the Intel OpenVINO node implementation (`CenterPoseOpenVINONode`) that is not available in the stock NVIDIA repository.

Copy the Intel-ported `isaac_ros_benchmark` package source from this repo into your workspace (or clone your Intel fork directly in place of the NVIDIA one):

```bash
# Option A: replace with your local Intel port source
rm -rf ~/ros2_ws/src/isaac_ros_benchmark
cp -r /home/intel/isaac_ros_benchmark ~/ros2_ws/src/isaac_ros_benchmark

# Option B: clone your Intel fork directly (recommended for clean setup)
# git clone https://github.com/<your-user>/<your-intel-fork>.git ~/ros2_ws/src/isaac_ros_benchmark
```

### 3) Copy this standalone benchmark script

```bash
cp /path/to/this/folder/isaac_ros_centerpose_intel.py \
  ~/ros2_ws/src/isaac_ros_benchmark/benchmarks/isaac_ros_centerpose_benchmark/scripts/
```

### 4) Install runtime dependencies

```bash
sudo apt update
sudo apt install -y \
  python3-colcon-common-extensions \
  ros-jazzy-image-proc \
  ros-jazzy-vision-msgs \
  ros-jazzy-launch-testing \
  ros-jazzy-launch-testing-ament-cmake

pip install --user openvino numpy opencv-python
```

### 5) Build only the required packages

```bash
cd ~/ros2_ws
source /opt/ros/jazzy/setup.bash

colcon build --symlink-install --cmake-args -DCMAKE_BUILD_TYPE=Release
```

### 6) Generate CenterPose synthetic OpenVINO model

```bash
cd ~/ros2_ws/src/isaac_ros_benchmark
export ISAAC_ROS_WS=~/ros2_ws
python3 scripts/create_centerpose_model.py
```

### 7) Ensure dataset is available

Place the r2b dataset in:

`~/ros2_ws/src/ros2_benchmark/assets/datasets/r2b_dataset/r2b_storage`

### 8) Run the CenterPose Intel benchmark

```bash
cd ~/ros2_ws
source /opt/ros/jazzy/setup.bash
source install/setup.bash
export ISAAC_ROS_WS=~/ros2_ws

launch_test src/isaac_ros_benchmark/benchmarks/isaac_ros_centerpose_benchmark/scripts/isaac_ros_centerpose_intel.py
```

### 9) Collect results

The benchmark report is emitted to:
- Terminal output
- `/tmp/r2b-log-*.json`

You can archive it with:

```bash
mkdir -p ~/ros2_ws/src/isaac_ros_benchmark/results
cp /tmp/r2b-log-*.json ~/ros2_ws/src/isaac_ros_benchmark/results/
```

## Notes
- If OpenVINO GPU runtime is not available, edit the script parameter `openvino_device` from `GPU` to `CPU`.
- If throughput search overshoots on your platform, reduce `publisher_upper_frequency` to `300.0`.
