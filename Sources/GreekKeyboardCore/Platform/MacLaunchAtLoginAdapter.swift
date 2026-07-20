import Foundation
import ServiceManagement

@MainActor
public final class MacLaunchAtLoginAdapter: LaunchAtLoginServiceProtocol {
  public init() {}

  public var isEnabled: Bool {
    SMAppService.mainApp.status == .enabled
  }

  public func setEnabled(_ isEnabled: Bool) throws {
    if isEnabled {
      try SMAppService.mainApp.register()
    } else {
      try SMAppService.mainApp.unregister()
    }
  }
}
