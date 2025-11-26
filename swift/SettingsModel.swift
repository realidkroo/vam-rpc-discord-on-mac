import Foundation

struct Settings: Codable, Equatable {
    // --- Legacy / Core ---
    var refreshInterval: Int
    var activityName: String
    
    // Buttons
    var enableSpotifyButton: Bool
    var spotifyButtonLabel: String
    var enableAppleMusicButton: Bool
    var appleMusicButtonLabel: String
    var enableSonglinkButton: Bool
    var songlinkButtonLabel: String
    var enableYoutubeMusicButton: Bool
    var youtubeMusicButtonLabel: String
    
    // General
    var enableAutoLaunch: Bool
    var showWhenHovering: Bool // New
    
    // Strings
    var detailsString: String
    var stateString: String
    var largeImageText: String
    var smallImageText: String
    var thirdString: String // New from screenshot
    
    // Images & Timestamp
    var smallImageSource: String 
    var enableSmallImage: Bool
    var spinningSmallImage: Bool
    var bigImageType: String
    var enablePauseTimestamp: Bool
    var timestampType: String
    
    // --- Experimental ---
    var customSpinnerApiUrl: String
    
    static func defaultSettings() -> Settings {
        return Settings(
            refreshInterval: 10,
            activityName: "Apple Music",
            enableSpotifyButton: true,
            spotifyButtonLabel: "Find on Spotify",
            enableAppleMusicButton: true,
            appleMusicButtonLabel: "Open on Apple Music",
            enableSonglinkButton: false,
            songlinkButtonLabel: "Find on Songlink",
            enableYoutubeMusicButton: false,
            youtubeMusicButtonLabel: "Find on Youtube Music",
            enableAutoLaunch: false,
            showWhenHovering: true,
            detailsString: "{name}",
            stateString: "by {artist}",
            largeImageText: "{album}",
            smallImageText: "{artist}",
            thirdString: "{name}-{album}",
            smallImageSource: "Artist Image",
            enableSmallImage: true,
            spinningSmallImage: false,
            bigImageType: "Album Art",
            enablePauseTimestamp: true,
            timestampType: "Elapsed",
            customSpinnerApiUrl: "https://able-pig-53.deno.dev"
        )
    }
}