//
//  PerformanceMonitor.swift
//  Waifu2x
//
//  Created by vuhe on 2025/1/2.
//  Copyright © 2025 vuhe. All rights reserved.
//
import Darwin
import Foundation

/// 性能监控工具
class PerformanceMonitor {
    private var startTime: DispatchTime
    private var measurements: [(cpu: Double, memory: Double, timestamp: DispatchTime)] = []
    private let measurementInterval: UInt64 = 500_000 // 0.5ms in nanoseconds

    init() {
        startTime = .now()
    }

    /// 开始监控并执行任务
    func measure<T>(_ block: () async throws -> T) async rethrows -> T {
        startTime = .now()
        measurements = []

        // 在后台队列进行采样
        let sampleTask = Task {
            while !Task.isCancelled {
                let cpu = getCurrentCPUUsage()
                let memory = getCurrentMemoryUsage()
                measurements.append((cpu, memory, .now()))
                try? await Task.sleep(nanoseconds: measurementInterval) // 1ms 间隔
            }
        }

        // 执行实际任务
        let result = try await block()

        // 停止采样
        sampleTask.cancel()

        // 打印结果
        printResults()

        return result
    }

    private func printResults() {
        guard !measurements.isEmpty else {
            print("No measurements collected")
            return
        }

        let duration = Double(DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000_000
        let cpuValues = measurements.map(\.cpu)
        let memoryValues = measurements.map(\.memory)

        let maxCPU = cpuValues.max() ?? 0
        let avgCPU = cpuValues.reduce(0, +) / Double(cpuValues.count)
        let maxMemory = memoryValues.max() ?? 0
        let avgMemory = memoryValues.reduce(0, +) / Double(memoryValues.count)

        print("\n=== Performance Report ===")
        print("Duration: \(duration.rounded(to: 3))s")
        print("Samples: \(measurements.count)")
        print("CPU Usage:")
        print("  Max: \(maxCPU.rounded(to: 2))%")
        print("  Avg: \(avgCPU.rounded(to: 2))%")
        print("Memory Usage:")
        print("  Max: \(formatBytes(maxMemory))")
        print("  Avg: \(formatBytes(avgMemory))")
        print("=======================\n")
    }

    /// 获取当前 CPU 使用率
    private func getCurrentCPUUsage() -> Double {
        var totalUsageOfCPU = 0.0
        var threadsList: thread_act_array_t?
        var threadsCount = mach_msg_type_number_t(0)

        let threadsResult = task_threads(mach_task_self_, &threadsList, &threadsCount)

        if threadsResult == KERN_SUCCESS, let threadsList {
            for index in 0 ..< threadsCount {
                var threadInfo = thread_basic_info()
                var threadInfoCount = mach_msg_type_number_t(THREAD_INFO_MAX)

                let infoResult = withUnsafeMutablePointer(to: &threadInfo) {
                    $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                        thread_info(
                            threadsList[Int(index)],
                            thread_flavor_t(THREAD_BASIC_INFO),
                            $0,
                            &threadInfoCount
                        )
                    }
                }

                if infoResult == KERN_SUCCESS {
                    let threadBasicInfo = threadInfo
                    let cpuUsage = Double(threadBasicInfo.cpu_usage) / Double(TH_USAGE_SCALE)
                    totalUsageOfCPU += cpuUsage * 100.0
                }
            }

            vm_deallocate(
                mach_task_self_,
                vm_address_t(UInt(bitPattern: threadsList)),
                vm_size_t(Int(threadsCount) * MemoryLayout<thread_t>.stride)
            )
        }

        return totalUsageOfCPU
    }

    /// 获取当前内存使用量
    private func getCurrentMemoryUsage() -> Double {
        var taskInfo = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(TASK_VM_INFO),
                    $0,
                    &count
                )
            }
        }

        if result == KERN_SUCCESS {
            return Double(taskInfo.phys_footprint)
        }

        return 0
    }

    /// 格式化字节数
    private func formatBytes(_ bytes: Double) -> String {
        let units = ["B", "KB", "MB", "GB"]
        var value = bytes
        var unitIndex = 0

        while value > 1024, unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }

        return String(format: "%.2f %@", value, units[unitIndex])
    }
}

extension Double {
    func rounded(to places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
