import Foundation



struct TrackProps {
    var name: String
    var artist: String
    var album: String
    var duration: Double
    var playerPosition: Double
}

struct TrackExtras {
    var albumArtUrl: String?
    var artistArtUrl: String?
    var trackViewUrl: String?
}

class Agent {
    static let shared = Agent()
    private let rpc = DiscordRPC(clientId: "773825528921849856")
    private var timer: Timer?
    private let spinnerApiBase = "https://able-pig-53.deno.dev"
    private var isPaused = false
    
    private var lastTrackKey: String = ""
    private var lastExtras: TrackExtras?
    
    private let icons = [
        "PLAY": "https://i.imgur.com/6uuaC8A.png",
        "PAUSE": "https://i.imgur.com/8oAUykh.png",
        "APPLE_MUSIC": "https://upload.wikimedia.org/wikipedia/commons/thumb/5/5f/Apple_Music_icon.svg/512px-Apple_Music_icon.svg.png"
    ]
    
    func start() {
        isPaused = false
        // Run immediately then schedule
        DispatchQueue.global(qos: .background).async {
            self.tick()
        }
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
        rpc.clearActivity()
        rpc.disconnect()
        writeStatus("Stopped")
    }
    
    func togglePause() -> Bool {
        isPaused.toggle()
        if isPaused {
            timer?.invalidate()
            timer = nil
            rpc.clearActivity()
            writeStatus("RPC Paused")
            return true // is Paused
        } else {
            start()
            return false // is not Paused
        }
    }
    
    private func loadSettings() -> Settings {
        let path = (NSString(string: "~/Library/Application Support/VAM-RPC/data/config.json").expandingTildeInPath)
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let settings = try? JSONDecoder().decode(Settings.self, from: data) else {
            return Settings.defaultSettings()
        }
        return settings
    }
    
    private func writeStatus(_ status: String) {
        let path = (NSString(string: "~/Library/Application Support/VAM-RPC/status.txt").expandingTildeInPath)
        try? status.write(toFile: path, atomically: true, encoding: .utf8)
    }
    
    private func runAppleScript(_ script: String) -> String? {
        return autoreleasepool {
            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                let result = appleScript.executeAndReturnError(&error)
                if error == nil {
                    return result.stringValue
                } else {
                    writeStatus("AppleScript Error")
                    print("AppleScript Error: \(String(describing: error))")
                }
            }
            return nil
        }
    }
    
    private func getMusicState() -> (state: String, track: TrackProps?) {
        let script = """
        tell application "System Events"
            if not (exists process "Music") then return "stopped"
        end tell
        tell application "Music"
            if player state is stopped then return "stopped"
            set myState to player state as string
            set tName to name of current track
            set tArtist to artist of current track
            set tAlbum to album of current track
            set tDur to duration of current track
            set tPos to player position
            return myState & "|||" & tName & "|||" & tArtist & "|||" & tAlbum & "|||" & tDur & "|||" & tPos
        end tell
        """
        
        guard let result = runAppleScript(script) else { return ("stopped", nil) }
        if result == "stopped" { return ("stopped", nil) }
        
        let parts = result.components(separatedBy: "|||")
        if parts.count == 6 {
            let state = parts[0]
            let durationStr = parts[4].replacingOccurrences(of: ",", with: ".")
            let posStr = parts[5].replacingOccurrences(of: ",", with: ".")
            let track = TrackProps(
                name: parts[1],
                artist: parts[2],
                album: parts[3],
                duration: Double(durationStr) ?? 0,
                playerPosition: Double(posStr) ?? 0
            )
            return (state, track)
        }
        return ("stopped", nil)
    }
    
    private func tick() {
        if isPaused { return }
        
        let settings = loadSettings()
        let music = getMusicState()
        
        if (music.state == "playing" || music.state == "paused"), let track = music.track {
            let trackIsPaused = music.state == "paused"
            writeStatus(trackIsPaused ? "Paused: \(track.name)" : "Playing: \(track.name)")
            
            let trackKey = "\(track.name) - \(track.artist) - \(track.album)"
            if trackKey == self.lastTrackKey, let extras = self.lastExtras {
                self.updateDiscord(track: track, settings: settings, extras: extras, isPaused: trackIsPaused)
            } else {
                fetchTrackExtras(track: track) { extras in
                    self.lastTrackKey = trackKey
                    self.lastExtras = extras
                    self.updateDiscord(track: track, settings: settings, extras: extras, isPaused: trackIsPaused)
                }
            }
        } else {
            rpc.clearActivity()
            writeStatus("Stopped")
            scheduleNextTick(interval: settings.refreshInterval)
        }
    }
    
    private func scheduleNextTick(interval: Int) {
        DispatchQueue.main.async {
            self.timer?.invalidate()
            self.timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(interval), repeats: false) { _ in
                DispatchQueue.global(qos: .background).async { self.tick() }
            }
        }
    }
    
    private func updateDiscord(track: TrackProps, settings: Settings, extras: TrackExtras, isPaused: Bool) {
        var activity: [String: Any] = [
            "type": 2,
            "name": self.formatString(settings.activityName, track),
            "details": self.formatString(settings.detailsString, track),
            "state": self.formatString(settings.stateString, track)
        ]
        
        if !isPaused && track.duration > 0 {
            let now = Int(Date().timeIntervalSince1970)
            let start = now - Int(track.playerPosition)
            let end = start + Int(track.duration)
            activity["timestamps"] = ["start": start, "end": end]
        }
        
        var smallImageKey: String?
        var smallImageTextValue = self.formatString(settings.smallImageText, track)
        
        if settings.smallImageSource == "albumArt", let url = extras.albumArtUrl {
            smallImageKey = url
        } else if settings.smallImageSource == "artistArt", let url = extras.artistArtUrl {
            smallImageKey = url
        } else if settings.smallImageSource == "playbackStatus" {
            smallImageKey = isPaused ? self.icons["PAUSE"] : self.icons["PLAY"]
            smallImageTextValue = isPaused ? "Paused" : "Playing"
        } else if settings.smallImageSource == "appIcon" {
            smallImageKey = self.icons["APPLE_MUSIC"]
            smallImageTextValue = "Apple Music"
        } else if settings.smallImageSource == "artistArtAnimated", let url = extras.artistArtUrl {
            if let encoded = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                smallImageKey = "\(self.spinnerApiBase)/spin.gif?url=\(encoded)"
            }
        } else if settings.smallImageSource == "albumArtAnimated", let url = extras.albumArtUrl {
            if let encoded = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                smallImageKey = "\(self.spinnerApiBase)/spin.gif?url=\(encoded)"
            }
        }
        
        var assets: [String: String] = [
            "large_image": extras.albumArtUrl ?? self.icons["APPLE_MUSIC"]!,
            "large_text": self.formatString(settings.largeImageText, track)
        ]
        if let sm = smallImageKey {
            assets["small_image"] = sm
            assets["small_text"] = smallImageTextValue
        }
        activity["assets"] = assets
        
        var buttons = [[String: String]]()
        let searchQuery = "\(track.name) \(track.artist)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        if settings.enableAppleMusicButton {
            let url = extras.trackViewUrl ?? "https://music.apple.com/us/search?term=\(searchQuery)"
            buttons.append(["label": self.formatString(settings.appleMusicButtonLabel, track), "url": url])
        }
        if settings.enableSpotifyButton {
            buttons.append(["label": self.formatString(settings.spotifyButtonLabel, track), "url": "https://open.spotify.com/search/\(searchQuery)"])
        }
        if settings.enableSonglinkButton {
            buttons.append(["label": self.formatString(settings.songlinkButtonLabel, track), "url": "https://song.link/s?q=\(searchQuery)"])
        }
        if settings.enableYoutubeMusicButton {
            buttons.append(["label": self.formatString(settings.youtubeMusicButtonLabel, track), "url": "https://music.youtube.com/search?q=\(searchQuery)"])
        }
        
        if buttons.count > 2 { buttons = Array(buttons.prefix(2)) }
        if !buttons.isEmpty { activity["buttons"] = buttons }
        
        self.rpc.setActivity(activity: activity)
        
        self.scheduleNextTick(interval: settings.refreshInterval)
    }
    
    private func formatString(_ template: String, _ track: TrackProps) -> String {
        var str = template
            .replacingOccurrences(of: "{name}", with: track.name)
            .replacingOccurrences(of: "{artist}", with: track.artist)
            .replacingOccurrences(of: "{album}", with: track.album)
        if str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "  " }
        if str.count < 2 { str = str.padding(toLength: 2, withPad: " ", startingAt: 0) }
        if str.count > 128 { str = String(str.prefix(127)) + "…" }
        return str
    }
    
    private func fetchTrackExtras(track: TrackProps, completion: @escaping (TrackExtras) -> Void) {
        let fullArtist = track.artist.replacingOccurrences(of: "\\(.*\\)", with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
        let cleanAlbum = track.album.replacingOccurrences(of: "\\(.*\\)", with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
        
        let primaryArtist = fullArtist.components(separatedBy: CharacterSet(charactersIn: ",&")).first?
            .components(separatedBy: " feat. ").first?
            .components(separatedBy: " ft. ").first?
            .components(separatedBy: " x ").first?
            .components(separatedBy: " vs ").first?.trimmingCharacters(in: .whitespaces) ?? fullArtist
        
        var extras = TrackExtras()
        let group = DispatchGroup()
        
        group.enter()
        fetchItunesAlbum(artist: fullArtist, album: cleanAlbum) { itunesData in
            if let data = itunesData {
                extras.albumArtUrl = data.artwork
                extras.trackViewUrl = data.url
                group.leave()
            } else {
                self.fetchItunesAlbum(artist: primaryArtist, album: cleanAlbum) { itunesData2 in
                    if let data = itunesData2 {
                        extras.albumArtUrl = data.artwork
                        extras.trackViewUrl = data.url
                    } else {
                        let dGroup = DispatchGroup()
                        dGroup.enter()
                        self.fetchDeezerAlbum(artist: fullArtist, album: cleanAlbum) { cover in
                            if let c = cover {
                                extras.albumArtUrl = c
                                dGroup.leave()
                            } else {
                                self.fetchDeezerAlbum(artist: primaryArtist, album: cleanAlbum) { cover2 in
                                    extras.albumArtUrl = cover2
                                    dGroup.leave()
                                }
                            }
                        }
                        dGroup.wait()
                    }
                    group.leave()
                }
            }
        }
        
        group.enter()
        fetchDeezerArtist(artist: primaryArtist) { picture in
            extras.artistArtUrl = picture
            group.leave()
        }
        
        group.notify(queue: .global(qos: .background)) {
            completion(extras)
        }
    }
    
    private func fetchItunesAlbum(artist: String, album: String, completion: @escaping ((artwork: String, url: String)?) -> Void) {
        let query = "\(artist) \(album)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlStr = "https://itunes.apple.com/search?term=\(query)&entity=album&limit=1"
        guard let url = URL(string: urlStr) else { completion(nil); return }
        
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]],
                  let first = results.first,
                  let artworkUrl100 = first["artworkUrl100"] as? String,
                  let collectionViewUrl = first["collectionViewUrl"] as? String else {
                completion(nil)
                return
            }
            let hqArtwork = artworkUrl100.replacingOccurrences(of: "100x100bb", with: "1000x1000bb")
            completion((hqArtwork, collectionViewUrl))
        }.resume()
    }
    
    private func fetchDeezerArtist(artist: String, completion: @escaping (String?) -> Void) {
        let query = artist.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlStr = "https://api.deezer.com/search/artist?q=\(query)&limit=1"
        guard let url = URL(string: urlStr) else { completion(nil); return }
        
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let dataArr = json["data"] as? [[String: Any]],
                  let first = dataArr.first else {
                completion(nil)
                return
            }
            let pic = (first["picture_xl"] as? String) ?? (first["picture_medium"] as? String)
            completion(pic)
        }.resume()
    }
    
    private func fetchDeezerAlbum(artist: String, album: String, completion: @escaping (String?) -> Void) {
        let query = "\(artist) \(album)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlStr = "https://api.deezer.com/search/album?q=\(query)&limit=1"
        guard let url = URL(string: urlStr) else { completion(nil); return }
        
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let dataArr = json["data"] as? [[String: Any]],
                  let first = dataArr.first else {
                completion(nil)
                return
            }
            let cover = (first["cover_xl"] as? String) ?? (first["cover_big"] as? String)
            completion(cover)
        }.resume()
    }
}
