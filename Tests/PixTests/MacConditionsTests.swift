import Foundation
import IOKit.ps
import Testing
@testable import Pix

@Test func macPowerIgnoresExternalAndUnreadableSourcesAndConvertsBatteryCapacity() {
    #expect(batteryLevel([]) == nil)
    let external: [String: Any] = [kIOPSTypeKey: "UPS", kIOPSCurrentCapacityKey: 80, kIOPSMaxCapacityKey: 100]
    let incomplete: [String: Any] = [kIOPSTypeKey: kIOPSInternalBatteryType, kIOPSMaxCapacityKey: 0]
    #expect(batteryLevel([external, incomplete]) == nil)
    let internalBattery: [String: Any] = [kIOPSTypeKey: kIOPSInternalBatteryType, kIOPSCurrentCapacityKey: 30, kIOPSMaxCapacityKey: 60]
    #expect(batteryLevel([external, incomplete, internalBattery]) == 50)
}

@Test func macThermalTranslationUsesOnlySeriousAndCriticalHeat() {
    #expect(!macIsHot(.nominal))
    #expect(!macIsHot(.fair))
    #expect(macIsHot(.serious))
    #expect(macIsHot(.critical))
}
