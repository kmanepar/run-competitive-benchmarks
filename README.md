# Isaac ROS AprilTag Benchmark - Intel Port

This folder contains the Intel-specific launch script (`apriltag_node_intel.py`) to run the Isaac ROS AprilTag benchmark on Intel CPU/iGPU platforms without requiring proprietary NVIDIA dependencies like TensorRT, Triton, or CUDA.

## Prerequisites
- Ubuntu 22.04 or 24.04 with ROS 2 Jazzy (or Humble) desktop installed.
- Intel system (Core, Xeon, etc.).

## Setup Instructions

### 1. Install System ROS Packages
Instead of building the core `isaac_ros_benchmark` frameworks from source (which require CUDA and `isaac_ros_common`), you can seamlessly use the `ros2_benchmark` and `apriltag_ros` binaries provided by apt:

```bash
sudo apt update
sudo apt install ros-jazzy-ros2-benchmark ros-jazzy-ros2-benchmark-interfaces \
                 ros-jazzy-apriltag-ros ros-jazzy-image-proc \
                 ros-jazzy-launch-testing ros-jazzy-launch-testing-ament-cmake
```
*(If on ROS 2 Humble, replace `jazzy` with `humble` in the package names above).*

### 2. Download the Benchmark Repositories
Download the NVIDIA Isaac ROS Benchmark repository to obtain the datasets and configuration structures:

```bash
mkdir -p ~/ros2_ws/src
cd ~/ros2_ws/src

# Clone the NVIDIA Isaac ROS Benchmark repository
git clone https://github.com/NVIDIA-ISAAC-ROS/isaac_ros_benchmark.git
```

**Crucial Note:** Do not run `colcon build` on the downloaded NVIDIA `isaac_ros_benchmark` repository out-of-the-box, as it requires NVIDIA CUDA (`nvcc`) and `isaac_ros_common`. Since we are running the standalone Python script using system packages, we bypass the CUDA package compilation entirely! 

### 3. Add the Intel Port Script
Copy the provided launch script (`apriltag_node_intel.py`) from this folder into the downloaded benchmark repository:

```bash
cp /path/to/this/folder/apriltag_node_intel.py ~/ros2_ws/src/isaac_ros_benchmark/benchmarks/isaac_ros_apriltag_benchmark/scripts/
```

### 4. Download and Prepare the Dataset
The benchmark relies on the `r2b_dataset`. You can follow the standard NVIDIA instructions to download the dataset. The benchmark uses `assets/datasets/r2b_dataset/r2b_storage` to find the .db3 bag flies. Ensure the `ISAAC_ROS_WS` variable is set or the dataset is placed accordingly.

```bash
export ISAAC_ROS_WS=~/ros2_ws
mkdir -p ~/ros2_ws/src/ros2_benchmark/assets/datasets/r2b_dataset/r2b_storage/
# Place the downloaded r2b_storage_0.db3 bags in the above directory
```

## Running the Benchmark

You don't need to `colcon build` to run this Python test format. Simply use ROS 2's `launch_test` utility:

```bash
cd ~/ros2_ws
source /opt/ros/jazzy/setup.bash

# Run the Intel port script directly
launch_test src/isaac_ros_benchmark/benchmarks/isaac_ros_apriltag_benchmark/scripts/apriltag_node_intel.py
```

After roughly 10 seconds of idle resource probing, the script will load the test data from the sqlite bag, process the graph on the Intel CPU, compute the performance metrics (e.g., latency, throughput), and produce the final benchmark report in the terminal.
