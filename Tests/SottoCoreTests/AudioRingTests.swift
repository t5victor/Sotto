import SottoAudioRingC
import XCTest
@testable import SottoCore

final class AudioRingTests: XCTestCase {
    func testRealtimeCapacityCoversHardwareQuantumLargerThanTapRequest() {
        XCTAssertGreaterThanOrEqual(
            MicrophoneRecorder.realtimeFrameCapacity(sampleRate: 48_000),
            4_800
        )
        XCTAssertEqual(
            MicrophoneRecorder.realtimeFrameCapacity(sampleRate: 192_000),
            48_000
        )
    }

    func testSingleProducerSingleConsumerOrderAndOverflowAreExplicit() throws {
        let state = try XCTUnwrap(sotto_audio_ring_create(2))
        defer { sotto_audio_ring_destroy(state) }

        XCTAssertEqual(sotto_audio_ring_acquire_write(state), 0)
        sotto_audio_ring_commit_write(state)
        XCTAssertEqual(sotto_audio_ring_acquire_write(state), 1)
        sotto_audio_ring_commit_write(state)

        XCTAssertEqual(sotto_audio_ring_acquire_write(state), -1)
        XCTAssertTrue(sotto_audio_ring_did_overflow(state))
        XCTAssertFalse(sotto_audio_ring_is_accepting(state))

        XCTAssertEqual(sotto_audio_ring_acquire_read(state), 0)
        sotto_audio_ring_commit_read(state)
        XCTAssertEqual(sotto_audio_ring_acquire_read(state), 1)
        sotto_audio_ring_commit_read(state)
        XCTAssertEqual(sotto_audio_ring_acquire_read(state), -1)
    }

    func testNormalCloseDoesNotMasqueradeAsOverflow() throws {
        let state = try XCTUnwrap(sotto_audio_ring_create(4))
        defer { sotto_audio_ring_destroy(state) }

        sotto_audio_ring_close(state)

        XCTAssertFalse(sotto_audio_ring_is_accepting(state))
        XCTAssertFalse(sotto_audio_ring_did_overflow(state))
        XCTAssertEqual(sotto_audio_ring_acquire_write(state), -1)
    }
}
