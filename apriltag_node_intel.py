#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""
Performance test for apriltag_ros AprilTagNode on Intel CPU/iGPU.

The graph consists of the following:
- Preprocessors:
    1. PrepResizeNode: resizes images to HD
- Graph under Test:
    1. AprilTagNode: detects Apriltags

Required:
- Packages: apriltag_ros, image_proc, ros2_benchmark
- Dataset:  assets/datasets/r2b_dataset/r2b_storage
"""

from launch_ros.actions import ComposableNodeContainer
from launch_ros.descriptions import ComposableNode

from ros2_benchmark import (
    ImageResolution,
    ROS2BenchmarkConfig,
    ROS2BenchmarkTest
)

IMAGE_RESOLUTION = ImageResolution.HD
ROSBAG_PATH = 'datasets/r2b_dataset/r2b_storage'


def launch_setup(container_prefix, container_sigterm_timeout):
    """Generate launch description for benchmarking apriltag_ros on Intel."""
    cfg_36h11 = {
        'image_transport': 'raw',
        'family': '36h11',
        'size': 0.162,
    }

    apriltag_node = ComposableNode(
        name='AprilTagNode',
        namespace=TestAprilTagNodeIntel.generate_namespace(),
        package='apriltag_ros',
        plugin='AprilTagNode',
        parameters=[cfg_36h11],
        remappings=[
            ('image_rect', 'image'),
            ('detections', 'apriltag_detections'),
        ],
    )

    data_loader_node = ComposableNode(
        name='DataLoaderNode',
        namespace=TestAprilTagNodeIntel.generate_namespace(),
        package='ros2_benchmark',
        plugin='ros2_benchmark::DataLoaderNode',
        remappings=[
            ('hawk_0_left_rgb_image', 'data_loader/image'),
            ('hawk_0_left_rgb_camera_info', 'data_loader/camera_info'),
        ],
    )

    prep_resize_node = ComposableNode(
        name='PrepResizeNode',
        namespace=TestAprilTagNodeIntel.generate_namespace(),
        package='image_proc',
        plugin='image_proc::ResizeNode',
        parameters=[{
            'width': IMAGE_RESOLUTION['width'],
            'height': IMAGE_RESOLUTION['height'],
            'use_scale': False,
        }],
        remappings=[
            ('image/image_raw', 'data_loader/image'),
            ('image/camera_info', 'data_loader/camera_info'),
            ('resize/image_raw', 'buffer/image'),
            ('resize/camera_info', 'buffer/camera_info'),
        ],
    )

    playback_node = ComposableNode(
        name='PlaybackNode',
        namespace=TestAprilTagNodeIntel.generate_namespace(),
        package='ros2_benchmark',
        plugin='ros2_benchmark::PlaybackNode',
        parameters=[{
            'data_formats': [
                'sensor_msgs/msg/Image',
                'sensor_msgs/msg/CameraInfo',
            ],
        }],
        remappings=[
            ('buffer/input0', 'buffer/image'),
            ('input0', 'image'),
            ('buffer/input1', 'buffer/camera_info'),
            ('input1', 'camera_info'),
        ],
    )

    monitor_node = ComposableNode(
        name='MonitorNode',
        namespace=TestAprilTagNodeIntel.generate_namespace(),
        package='ros2_benchmark',
        plugin='ros2_benchmark::MonitorNode',
        parameters=[{
            'monitor_data_format': 'apriltag_msgs/msg/AprilTagDetectionArray',
        }],
        remappings=[
            ('output', 'apriltag_detections'),
        ],
    )

    composable_node_container = ComposableNodeContainer(
        name='container',
        namespace=TestAprilTagNodeIntel.generate_namespace(),
        package='rclcpp_components',
        executable='component_container_mt',
        prefix=container_prefix,
        sigterm_timeout=container_sigterm_timeout,
        composable_node_descriptions=[
            data_loader_node,
            prep_resize_node,
            playback_node,
            monitor_node,
            apriltag_node,
        ],
        output='screen',
    )

    return [composable_node_container]


def generate_test_description():
    return TestAprilTagNodeIntel.generate_test_description_with_nsys(launch_setup)


class TestAprilTagNodeIntel(ROS2BenchmarkTest):
    """Performance test for apriltag_ros AprilTagNode on Intel."""

    config = ROS2BenchmarkConfig(
        benchmark_name='AprilTag Node Benchmark (Intel CPU/iGPU)',
        input_data_path=ROSBAG_PATH,
        input_data_start_time=3.0,
        input_data_end_time=3.5,
        publisher_upper_frequency=600.0,
        publisher_lower_frequency=10.0,
        playback_message_buffer_size=10,
        custom_report_info={'data_resolution': IMAGE_RESOLUTION},
    )

    def test_benchmark(self):
        self.run_benchmark()
