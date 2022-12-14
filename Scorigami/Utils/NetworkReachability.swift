//
//  NetworkReachability.swift
//  Scorigami
//
//
// From designcode.io

import Foundation
import SystemConfiguration

class NetworkReachability: ObservableObject {
    @Published private(set) var reachable: Bool = false
    private let reachability =
              SCNetworkReachabilityCreateWithName(nil, Scorigami.sourceDomain)

    init() {
        self.reachable = checkConnection()
    }

    private func isNetworkReachable(with flags:
                                    SCNetworkReachabilityFlags) -> Bool {
        let isReachable = flags.contains(.reachable)
        let connectionRequired = flags.contains(.connectionRequired)
        let canConnectAutomatically = flags.contains(.connectionOnDemand) ||
            flags.contains(.connectionOnTraffic)
        let canConnectWithoutIntervention = canConnectAutomatically &&
            !flags.contains(.interventionRequired)
        return isReachable &&
               (!connectionRequired || canConnectWithoutIntervention)
    }

    func checkConnection() -> Bool {
        var flags = SCNetworkReachabilityFlags()
        SCNetworkReachabilityGetFlags(reachability!, &flags)

        return isNetworkReachable(with: flags)
    }
}
