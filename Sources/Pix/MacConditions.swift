import Foundation
import AmbientCore
import IOKit.ps

/// Translate macOS facts into the Controller's Power value; an unavailable source is not assumed to be a battery.
func currentPower() -> Power {
    let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue()
    let source = info.flatMap { IOPSGetProvidingPowerSourceType($0)?.takeUnretainedValue() } as String?
    let sources = info.flatMap { IOPSCopyPowerSourcesList($0)?.takeRetainedValue() as? [CFTypeRef] } ?? []
    let descriptions = sources.compactMap { source in
        info.flatMap { IOPSGetPowerSourceDescription($0, source)?.takeUnretainedValue() as? [String: Any] }
    }
    return Power(onBattery: source == kIOPMBatteryPowerKey, lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled,
                 level: batteryLevel(descriptions))
}

/// macOS's own verdict on temperature: serious or critical counts as hot.
func macIsHot(_ state: ProcessInfo.ThermalState = ProcessInfo.processInfo.thermalState) -> Bool {
    state == .serious || state == .critical
}

/// Ignore external sources and incomplete battery records, as the live adapter does when macOS cannot read a source.
func batteryLevel(_ descriptions: [[String: Any]]) -> Int? {
    for description in descriptions {
        guard description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
              let current = description[kIOPSCurrentCapacityKey] as? Int,
              let maximum = description[kIOPSMaxCapacityKey] as? Int, maximum > 0 else { continue }
        return current * 100 / maximum
    }
    return nil
}
