import WebKit
import MediaPlayer

// Wires macOS media keys, the Control Center "Now Playing" widget, and AirPods
// playback controls to whatever <video> element is currently active inside the
// WKWebView, so Streamy behaves like a real player instead of a hidden webpage.
public final class NowPlayingController {
    public static let shared = NowPlayingController()

    public weak var webView: WKWebView?

    private init() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.sendMediaControl("play")
            return .success
        }
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.sendMediaControl("pause")
            return .success
        }
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.sendMediaControl("toggle")
            return .success
        }

        // Seeking/skipping isn't meaningful across arbitrary streaming sites, so leave disabled
        // rather than wiring up commands that would silently do nothing.
        commandCenter.nextTrackCommand.isEnabled = false
        commandCenter.previousTrackCommand.isEnabled = false
        commandCenter.changePlaybackPositionCommand.isEnabled = false
    }

    private func sendMediaControl(_ action: String) {
        webView?.evaluateJavaScript("window.streamyMediaControl && window.streamyMediaControl('\(action)')")
    }

    public func updateTitle(_ title: String) {
        guard !title.isEmpty else { return }
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPMediaItemPropertyTitle] = title
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    public func updatePlaybackState(isPlaying: Bool) {
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
    }
}
