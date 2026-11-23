import Cocoa
import FlutterMacOS
import XCTest

@testable import machine_info

class RunnerTests: XCTestCase {

  func testPayloadDecodesReadingsFromTheChannel() {
    let cpu: [String: Any] = ["key": "cpu", "label": "CPU", "value": "42%", "detail": "Carga total",
                              "ratio": 0.42, "level": "elevated", "symbol": "cpu"]
    let payload = IslandPayload([
      "title": "Machine Info",
      "hostname": "mac",
      "level": "critical",
      "primary": cpu,
      "secondary": NSNull(),
      "readings": [cpu, ["no key": true]],
    ])

    XCTAssertEqual(payload.hostname, "mac")
    XCTAssertEqual(payload.level, .critical)
    XCTAssertEqual(payload.primary?.value, "42%")
    XCTAssertEqual(payload.primary?.level, .elevated)
    XCTAssertNil(payload.secondary)
    XCTAssertEqual(payload.readings.count, 1)
  }

  func testReadingClampsRatioAndFallsBackOnUnknownLevels() {
    let reading = IslandReading(["key": "disk", "ratio": 3.5, "level": "weird"])
    XCTAssertEqual(reading?.ratio, 1)
    XCTAssertEqual(reading?.level, .normal)
    XCTAssertNil(IslandReading("not a map"))
  }

  func testCompactSizeLeavesRoomForBothWings() {
    let geometry = NotchGeometry(notchWidth: 180, height: 32, hasNotch: true)
    XCTAssertEqual(geometry.compactSize.width, 180 + NotchGeometry.wingWidth * 2)
    XCTAssertEqual(geometry.compactSize.height, 32)
  }

  func testNotchShapeOpenPathSkipsTheTopEdge() {
    let rect = CGRect(x: 0, y: 0, width: 200, height: 40)
    let closed = NotchShape(topRadius: 6, bottomRadius: 12).path(in: rect)
    let open = NotchShape(topRadius: 6, bottomRadius: 12, closed: false).path(in: rect)
    XCTAssertEqual(closed.boundingRect, open.boundingRect)
    XCTAssertNotEqual(closed.description, open.description)
  }
}
