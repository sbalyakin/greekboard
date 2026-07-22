import Foundation

let repositoryRoot = URL(fileURLWithPath: #filePath)
  .deletingLastPathComponent()
  .deletingLastPathComponent()
let scriptURL = repositoryRoot.appendingPathComponent("scripts/rebuild_and_relaunch.sh")

let process = Process()
process.executableURL = scriptURL
process.currentDirectoryURL = repositoryRoot

do {
  try process.run()
  process.waitUntilExit()
  exit(process.terminationStatus)
} catch {
  fputs("error: failed to launch rebuild_and_relaunch.sh: \(error)\n", stderr)
  exit(1)
}
