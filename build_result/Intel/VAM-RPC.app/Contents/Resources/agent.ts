// agent.ts
import { Client, type Activity } from "https://deno.land/x/discord_rpc@0.3.2/mod.ts";

const SUPPORT_DIR = `${Deno.env.get("HOME")}/Library/Application Support/VAM-RPC`;
const STATUS_PATH = `${SUPPORT_DIR}/status.txt`;
const CONFIG_PATH = `${SUPPORT_DIR}/data/config.json`;

interface Settings {
    refreshInterval: number;
    activityName: string;
    enableSpotifyButton: boolean;
    spotifyButtonLabel: string;
    enableAppleMusicButton: boolean;
    appleMusicButtonLabel: string;
    enableSonglinkButton: boolean;
    songlinkButtonLabel: string;
    enableYoutubeMusicButton: boolean;
    youtubeMusicButtonLabel: string;
    detailsString: string;
    stateString: string;
    largeImageText: string;
    smallImageText: string;
    // Options: "default", "albumArt", "artistArt"
    smallImageSource: string;
}

async function loadSettings(): Promise<Settings> {
    const defaultSettings: Settings = {
        refreshInterval: 5,
        activityName: "Apple Music",
        enableSpotifyButton: true,
        spotifyButtonLabel: "♫ Find On Spotify",
        enableAppleMusicButton: true,
        appleMusicButtonLabel: "♫ Open on  Music",
        enableSonglinkButton: false, 
        songlinkButtonLabel: "♫ Find on Songlink",
        enableYoutubeMusicButton: false, 
        youtubeMusicButtonLabel: "♫ Find on YT Music",
        detailsString: "{name}",
        stateString: "by {artist}",
        largeImageText: "{name} - {album}",
        smallImageText: "{artist}",
        smallImageSource: "default",
    };

    try {
        const content = await Deno.readTextFile(CONFIG_PATH);
        const loaded = { ...defaultSettings, ...JSON.parse(content) };
        // Ensure valid smallImageSource
        if (!["default", "albumArt", "artistArt"].includes(loaded.smallImageSource)) {
            loaded.smallImageSource = "default";
        }
        console.log(`VAM-RPC Agent: ✅ Loaded settings.`);
        return loaded;
    } catch (e) {
        console.warn(`VAM-RPC Agent: ⚠️ Could not load settings. Using defaults.`);
        return defaultSettings;
    }
}

async function runJsInMusic<T>(script: string): Promise<T> {
    const wrappedScript = `JSON.stringify( (() => { ${script} })() )`;
    const cmd = new Deno.Command("osascript", { args: ["-l", "JavaScript", "-e", wrappedScript] });
    const { stdout, code, stderr } = await cmd.output();
    if (code !== 0) throw new Error(`AppleScript Error: ${new TextDecoder().decode(stderr)}`);
    return JSON.parse(new TextDecoder().decode(stdout)) as T;
}

interface TrackProps { name: string; artist: string; album: string; duration: number; playerPosition: number; }

async function getMusicState(): Promise<{ state: "playing" | "paused" | "stopped", track?: TrackProps }> {
    const script = `
        const music = Application("Music");
        if (!music.running()) return { state: "stopped" };
        const state = music.playerState();
        if (state === "playing") {
            try {
                const track = music.currentTrack;
                return {
                    state: "playing",
                    track: {
                        name: track.name(), artist: track.artist(), album: track.album(),
                        duration: track.duration(), playerPosition: music.playerPosition()
                    }
                };
            } catch (e) { return { state: "paused" }; }
        }
        return { state: "paused" };
    `;
    return await runJsInMusic(script);
}

interface TrackExtras { 
    albumArtUrl?: string; 
    artistArtUrl?: string;
    trackViewUrl?: string; 
}

async function fetchTrackExtras(props: TrackProps): Promise<TrackExtras> {
    const cleanArtist = props.artist.replace(/\(.*\)/g, "").trim();
    const cleanAlbum = props.album.replace(/\(.*\)/g, "").trim();
    
    const [albumData, artistData] = await Promise.all([
        fetchItunesAlbum(cleanArtist, cleanAlbum),
        fetchDeezerArtist(cleanArtist)
    ]);

    return {
        albumArtUrl: albumData?.artwork,
        trackViewUrl: albumData?.url,
        artistArtUrl: artistData
    };
}

async function fetchItunesAlbum(artist: string, album: string): Promise<{ artwork: string, url: string } | null> {
    const query = `${artist} ${album}`;
    const url = `https://itunes.apple.com/search?term=${encodeURIComponent(query)}&entity=album&limit=1`;
    
    try {
        const resp = await fetch(url);
        if (!resp.ok) return null;
        const json = await resp.json();
        
        if (json.resultCount > 0) {
            const result = json.results[0];
            const highResArt = result.artworkUrl100.replace("100x100bb", "1000x1000bb");
            return { artwork: highResArt, url: result.collectionViewUrl };
        }
    } catch (e) { console.warn("iTunes Fetch Error:", e); }
    return null;
}

async function fetchDeezerArtist(artist: string): Promise<string | undefined> {
    const url = `https://api.deezer.com/search/artist?q=${encodeURIComponent(artist)}&limit=1`;
    try {
        const resp = await fetch(url);
        if (!resp.ok) return undefined;
        const json = await resp.json();
        
        if (json.data && json.data.length > 0) {
            // Deezer provides 'picture_xl' which is a great profile picture
            return json.data[0].picture_xl ?? json.data[0].picture_medium;
        }
    } catch (e) { console.warn("Deezer Fetch Error:", e); }
    return undefined;
}
// ---------------------------

function ensureValidString(value: string | null | undefined, minLength = 2, maxLength = 128): string {
    if (!value) return " ".repeat(minLength);
    if (value.length < minLength) return value.padEnd(minLength, " ");
    if (value.length > maxLength) return `${value.slice(0, maxLength - 1)}…`;
    return value;
}

function formatString(template: string, track: TrackProps): string {
    return template
        .replace(/\{name\}/g, track.name)
        .replace(/\{artist\}/g, track.artist)
        .replace(/\{album\}/g, track.album);
}

async function main() {
    console.log("VAM-RPC Agent: Starting service (Hybrid API Mode).");
    await Deno.writeTextFile(STATUS_PATH, "Service Starting...");
    
    const settings = await loadSettings();
    const rpc = new Client({ id: "773825528921849856" });
    
    try {
        await rpc.connect();
        console.log("VAM-RPC Agent: ✅ RPC Connected.");
    } catch (e) {
        console.error("Failed to connect to Discord RPC:", e);
        await Deno.writeTextFile(STATUS_PATH, "Error: Discord RPC Failed");
        return;
    }

    const tick = async () => {
        try {
            const music = await getMusicState();

            if (music.state === "playing" && music.track) {
                const track = music.track;
                await Deno.writeTextFile(STATUS_PATH, `Playing: ${track.name}`);

                const extras = await fetchTrackExtras(track);
                
                let start, end;
                if (track.duration > 0) {
                    const now = Date.now();
                    start = Math.round(now - (track.playerPosition * 1000));
                    end = Math.round(start + (track.duration * 1000));
                }

                let smallImageKey = "music";
                
                if (settings.smallImageSource === "albumArt" && extras.albumArtUrl) {
                    smallImageKey = extras.albumArtUrl;
                } else if (settings.smallImageSource === "artistArt" && extras.artistArtUrl) {
                    smallImageKey = extras.artistArtUrl;
                }

                const activity: Activity = {
                    type: 2, 
                    name: ensureValidString(formatString(settings.activityName, track)),
                    details: ensureValidString(formatString(settings.detailsString, track)),
                    state: ensureValidString(formatString(settings.stateString, track)),
                    timestamps: { start, end },
                    assets: {
                        large_image: extras.albumArtUrl ?? "appicon",
                        large_text: ensureValidString(formatString(settings.largeImageText, track)),
                        
                        small_image: smallImageKey,
                        small_text: ensureValidString(formatString(settings.smallImageText, track)),
                    }
                };
                
                const buttons = [];
                const searchQuery = encodeURIComponent(`${track.name} ${track.artist}`);

                if (settings.enableAppleMusicButton) {
                    const url = extras.trackViewUrl 
                        ? extras.trackViewUrl 
                        : `https://music.apple.com/us/search?term=${searchQuery}`;
                    buttons.push({ label: ensureValidString(settings.appleMusicButtonLabel, 2, 32), url: url });
                }
                if (settings.enableSpotifyButton) {
                    const spotifyUrl = `https://open.spotify.com/search/${searchQuery}`;
                    buttons.push({ label: ensureValidString(settings.spotifyButtonLabel, 2, 32), url: spotifyUrl });
                }
                if (settings.enableSonglinkButton) {
                    const songlinkUrl = `https://song.link/s?q=${searchQuery}`;
                    buttons.push({ label: ensureValidString(settings.songlinkButtonLabel, 2, 32), url: songlinkUrl });
                }
                if (settings.enableYoutubeMusicButton) {
                    const youtubeMusicUrl = `https://music.youtube.com/search?q=${searchQuery}`;
                    buttons.push({ label: ensureValidString(settings.youtubeMusicButtonLabel, 2, 32), url: youtubeMusicUrl });
                }
                if (buttons.length > 0) { activity.buttons = buttons; }

                await rpc.setActivity(activity);

            } else {
                await rpc.clearActivity();
                await Deno.writeTextFile(STATUS_PATH, "Paused or Stopped");
            }
        } catch (e) {
            console.error(`VAM-RPC Agent: Error during update - ${e.message}`);
            await Deno.writeTextFile(STATUS_PATH, `Error: ${e.message}`);
        } finally {
            setTimeout(tick, settings.refreshInterval * 1000);
        }
    };
    
    tick();
}

main().catch(e => {
    console.error(`VAM-RPC Agent: Fatal Error - ${e.message}`);
    Deno.writeTextFile(STATUS_PATH, `Fatal Error: ${e.message}`);
    Deno.exit(1);
});