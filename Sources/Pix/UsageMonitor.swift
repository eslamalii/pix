import Foundation
import QuartzCore
import os

private let log = Logger(subsystem: appID, category: "usage")

/// Logs this app's own CPU and memory once a minute, when switched on (Settings.usageLog). Read with:
///   /usr/bin/log stream --predicate 'subsystem == "io.github.eslamalii.Pix" && category == "usage"'
@MainActor
final class UsageMonitor {
    private var lastCPU = cpuSeconds()
    private var lastWall = CACurrentMediaTime()
    private var timer: Timer?

    func start(state: @escaping @MainActor () -> String) {
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.report(state()) }  // scheduled on the main run loop
        }
    }

    private func report(_ state: String) {
        let cpu = cpuSeconds(), wall = CACurrentMediaTime()
        let percent = (cpu - lastCPU) / (wall - lastWall) * 100
        (lastCPU, lastWall) = (cpu, wall)
        log.notice("CPU \(percent, format: .fixed(precision: 1), privacy: .public)% · memory \(Int(memoryMB()), privacy: .public) MB · \(state, privacy: .public)")
    }
}

private func cpuSeconds() -> Double {
    var u = rusage()
    getrusage(RUSAGE_SELF, &u)
    return Double(u.ru_utime.tv_sec + u.ru_stime.tv_sec) + Double(u.ru_utime.tv_usec + u.ru_stime.tv_usec) / 1e6
}

private func memoryMB() -> Double {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
    _ = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
        }
    }
    return Double(info.resident_size) / 1_048_576
}
