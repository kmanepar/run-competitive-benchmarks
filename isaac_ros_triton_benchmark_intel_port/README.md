# Isaac ROS Triton Benchmark - Intel Port

This folder contains a standalone Intel benchmark script for the Triton benchmark replacement:
- `isaac_ros_triton_intel.py`

On Intel, this benchmark uses the OpenVINO-based `DopeOpenVINONode` in place of the original Triton path.

## Requirements
- ROS 2 Jazzy
- `ros2_benchmark`
- `image_proc`
- Intel-ported `isaac_ros_benchmark` source containing `DopeOpenVINONode`
- Model: `src/ros2_benchmark/assets/models/ketchup/ketchup.xml`
- Dataset: `src/ros2_benchmark/assets/datasets/r2b_dataset/r2b_storage`

## Setup

### 1) Create workspace and clone sources

```bash
mkdir -p ~/ros2_ws/src
cd ~/ros2_ws/src

git clone https://github.com/NVIDIA-ISAAC-ROS/isaac_ros_benchmark.git
git clone https://github.com/NVIDIA-ISAAC-ROS/ros2_benchmark.git
```

### 2) Use Intel-ported benchmark source

```bash
rm -rf ~/ros2_ws/src/isaac_ros_benchmark
cp -r /home/intel/isaac_ros_benchmark ~/ros2_ws/src/isaac_ros_benchmark
```

### 3) Copy this standalone script

```bash
cp /path/to/this/folder/isaac_ros_triton_intel.py \
  ~/ros2_ws/src/isaac_ros_benchmark/benchmarks/isaac_ros_triton_benchmark/scripts/
```

### 4) Install dependencies

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

### 5) Build and prepare model

```bash
cd ~/ros2_ws
source /opt/ros/jazzy/setup.bash
colcon build --symlink-install --cmake-args -DCMAKE_BUILD_TYPE=Release

cd ~/ros2_ws/src/isaac_ros_benchmark
export ISAAC_ROS_WS=~/ros2_ws
python3 scripts/create_dope_model.py
```

### 6) Ensure dataset is available

Put r2b dataset under:

`~/ros2_ws/src/ros2_benchmark/assets/datasets/r2b_dataset/r2b_storage`

### 7) Run benchmark

```bash
cd ~/ros2_ws
source /opt/ros/jazzy/setup.bash
source install/setup.bash
export ISAAC_ROS_WS=~/ros2_ws

launch_test src/isaac_ros_benchmark/benchmarks/isaac_ros_triton_benchmark/scripts/isaac_ros_triton_intel.py
```

### 8) Collect result

```bash
mkdir -p ~/ros2_ws/src/isaac_ros_benchmark/results
cp /tmp/r2b-log-*.json ~/ros2_ws/src/isaac_ros_benchmark/results/
```
