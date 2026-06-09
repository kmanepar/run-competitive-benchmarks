#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Performance test for DNN Image Encoder on Intel (resize via image_proc)."""
import os, time
from launch_ros.actions import ComposableNodeContainer
from launch_ros.descriptions import ComposableNode
from ros2_benchmark import Resolution, ROS2BenchmarkConfig, ROS2BenchmarkTest

IMAGE_RESOLUTION = Resolution(1920, 1080)
NETWORK_RESOLUTION = Resolution(640, 480)
ROSBAG_PATH = 'datasets/r2b_dataset/r2b_storage'

def launch_setup(container_prefix, container_sigterm_timeout):
    ns = TestDnnEncoderIntel.generate_namespace()
    nodes = [
        ComposableNode(name='DataLoaderNode', namespace=ns, package='ros2_benchmark',
            plugin='ros2_benchmark::DataLoaderNode',
            remappings=[('hawk_0_left_rgb_image', 'data_loader/image'),
                        ('hawk_0_left_rgb_camera_info', 'data_loader/camera_info')]),
        ComposableNode(name='PlaybackNode', namespace=ns, package='ros2_benchmark',
            plugin='ros2_benchmark::PlaybackNode',
            parameters=[{'data_formats': ['sensor_msgs/msg/Image', 'sensor_msgs/msg/CameraInfo']}],
            remappings=[('buffer/input0', 'data_loader/image'), ('input0', 'image'),
                        ('buffer/input1', 'data_loader/camera_info'), ('input1', 'camera_info')]),
        ComposableNode(name='ResizeNode', namespace=ns, package='image_proc',
            plugin='image_proc::ResizeNode',
            parameters=[{'width': NETWORK_RESOLUTION['width'], 'height': NETWORK_RESOLUTION['height'], 'use_scale': False}],
            remappings=[('image/image_raw', 'image'), ('image/camera_info', 'camera_info'),
                        ('resize/image_raw', 'output'), ('resize/camera_info', 'output_camera_info')]),
        ComposableNode(name='MonitorNode', namespace=ns, package='ros2_benchmark',
            plugin='ros2_benchmark::MonitorNode',
            parameters=[{'monitor_data_format': 'sensor_msgs/msg/Image'}],
            remappings=[('output', 'output')]),
    ]
    return [ComposableNodeContainer(name='container', namespace=ns, package='rclcpp_components',
        executable='component_container_mt', prefix=container_prefix,
        sigterm_timeout=container_sigterm_timeout, composable_node_descriptions=nodes, output='screen')]

def generate_test_description():
    return TestDnnEncoderIntel.generate_test_description_with_nsys(launch_setup)

class TestDnnEncoderIntel(ROS2BenchmarkTest):
    config = ROS2BenchmarkConfig(
        benchmark_name='Isaac ROS DNN Image Encoder Benchmark (Intel image_proc)',
        input_data_path=ROSBAG_PATH, input_data_start_time=0.0, input_data_end_time=4.0,
        publisher_upper_frequency=300.0, publisher_lower_frequency=10.0,
        playback_message_buffer_size=200,
        custom_report_info={'data_resolution': IMAGE_RESOLUTION, 'network_resolution': NETWORK_RESOLUTION})
    def test_benchmark(self): self.run_benchmark()
