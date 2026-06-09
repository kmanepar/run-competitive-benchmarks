# Isaac ROS DetectNet Benchmark - Intel Port

This folder contains a standalone Intel benchmark script for DetectNet (PeopleNet):
- `isaac_ros_detectnet_intel.py`

It follows the same proven workflow as AprilTag and CenterPose:
1. Run benchmark scripts with `launch_test`.
2. Use Intel-ported `isaac_ros_benchmark` source for OpenVINO nodes.
3. Avoid building unmodified CUDA-dependent NVIDIA stack on Intel-only systems.

## What this script expects
- OpenVINO composable node: `isaac_ros_benchmark::DetectNetOpenVINONode`
- `ros2_benchmark`
- `image_proc`
- Model: `src/ros2_benchmark/assets/models/peoplenet/peoplenet.xml`
- Dataset: `src/ros2_benchmark/assets/datasets/r2b_dataset/r2b_storage`

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

This script requires the Intel OpenVINO node implementation (`DetectNetOpenVINONode`) that is not available in stock NVIDIA source.

```bash
# Option A: replace with your local Intel-port workspace copy
rm -rf ~/ros2_ws/src/isaac_ros_benchmark
cp -r /home/intel/isaac_ros_benchmark ~/ros2_ws/src/isaac_ros_benchmark

# Option B: clone your Intel fork directly
# git clone https://github.com/<your-user>/<your-intel-fork>.git ~/ros2_ws/src/isaac_ros_benchmark
```

### 3) Copy this standalone benchmark script

```bash
cp /path/to/this/folder/isaac_ros_detectnet_intel.py \
  ~/ros2_ws/src/isaac_ros_benchmark/benchmarks/isaac_ros_detectnet_benchmark/scripts/
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

### 5) Build required packages

```bash
cd ~/ros2_ws
source /opt/ros/jazzy/setup.bash
colcon build --symlink-install --cmake-args -DCMAKE_BUILD_TYPE=Release
```

### 6) Generate DetectNet synthetic OpenVINO model

```bash
cd ~/ros2_ws/src/isaac_ros_benchmark
export ISAAC_ROS_WS=~/ros2_ws
python3 scripts/create_detectnet_model.py
```

### 7) Ensure dataset is available

Place the r2b dataset in:

`~/ros2_ws/src/ros2_benchmark/assets/datasets/r2b_dataset/r2b_storage`

### 8) Run the DetectNet Intel benchmark

```bash
cd ~/ros2_ws
source /opt/ros/jazzy/setup.bash
source install/setup.bash
export ISAAC_ROS_WS=~/ros2_ws

launch_test src/isaac_ros_benchmark/benchmarks/isaac_ros_detectnet_benchmark/scripts/isaac_ros_detectnet_intel.py
```

### 9) Collect results

Outputs are available in terminal and `/tmp/r2b-log-*.json`.

```bash
mkdir -p ~/ros2_ws/src/isaac_ros_benchmark/results
cp /tmp/r2b-log-*.json ~/ros2_ws/src/isaac_ros_benchmark/results/
```
