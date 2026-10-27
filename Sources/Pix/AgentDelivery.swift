import Foundation
import AmbientCore

/// Keeps launch-time Agent reports in order until application wiring is ready.
/// A second app instance forwards the original links and never delivers them locally.
@MainActor
final class AgentDelivery {
    private let forward: ([URL]) -> Bool
    private var pending: [Event] = []
    private var send: ((Event) -> Void)?

    init(forward: @escaping ([URL]) -> Bool) { self.forward = forward }

    func receive(_ urls: [URL]) {
        guard !forward(urls) else { return }
        for report in urls.compactMap(AgentReport.init(url:)) {
            let event = Event.agent(report.state, agent: report.agent)
            if let send { send(event) } else { pending.append(event) }
        }
    }

    func start(_ send: @escaping (Event) -> Void) {
        guard self.send == nil else { return }
        self.send = send
        let waiting = pending
        pending = []
        waiting.forEach(send)
    }
}
