import Foundation
import Testing
import AmbientCore
@testable import Pix

@MainActor
@Test func agentDeliveryBuffersLaunchReportsThenDeliversNewReportsImmediately() {
    let delivery = AgentDelivery(forward: { _ in false })
    var reports: [AgentReport] = []
    delivery.receive([URL(string: "pix://agent/working?session=first")!, URL(string: "pix://agent/invalid")!])
    delivery.receive([URL(string: "pix://agent/waiting")!])
    #expect(reports.isEmpty)
    delivery.start { event in
        if case .agent(let state, let agent) = event { reports.append(AgentReport(state: state, agent: agent)) }
    }
    #expect(reports == [AgentReport(state: .working, agent: "first"), AgentReport(state: .waiting)])
    delivery.receive([URL(string: "pix://agent/done?session=first")!])
    #expect(reports.last == AgentReport(state: .done, agent: "first"))
    delivery.start { _ in Issue.record("Starting twice must not replace delivery or replay reports") }
    #expect(reports.count == 3)
}

@MainActor
@Test func agentDeliveryForwardsOriginalLinksWithoutBufferingOrLocalDelivery() {
    var forwarded: [[URL]] = []
    let delivery = AgentDelivery(forward: { forwarded.append($0); return true })
    let urls = [URL(string: "pix://agent/working?session=one")!, URL(string: "pix://agent/not-a-state")!]
    delivery.receive(urls)
    delivery.start { _ in Issue.record("A forwarded report must not be delivered locally") }
    delivery.receive(urls)
    #expect(forwarded == [urls, urls])
}
