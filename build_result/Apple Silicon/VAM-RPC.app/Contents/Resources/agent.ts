import { Client, type Activity } from "https://deno.land/x/discord_rpc@0.3.2/mod.ts";

// --- CONFIGURATION ---
const CLIENT_ID = "773825528921849856";
const SUPPORT_DIR = `${Deno.env.get("HOME")}/Library/Application Support/VAM-RPC`;
const STATUS_PATH = `${SUPPORT_DIR}/status.txt`;
const CONFIG_PATH = `${SUPPORT_DIR}/data/config.json`;

const ICONS = {
    PLAY: "https://i.imgur.com/6uuaC8A.png",
    PAUSE: "https://i.imgur.com/8oAUykh.png",
    APPLE_MUSIC: "https://upload.wikimedia.org/wikipedia/commons/thumb/5/5f/Apple_Music_icon.svg/512px-Apple_Music_icon.svg.png"
};

// --- INTERFACES ---
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
    enableAutoLaunch: boolean;
    showWhenHovering: boolean;
    detailsString: string;
    stateString: string;
    largeImageText: string;
    smallImageText: string;
    thirdString: string;
    smallImageSource: string;
    enableSmallImage: boolean;
    spinningSmallImage: boolean;
    bigImageType: string;
    enablePauseTimestamp: boolean;
    timestampType: string;
    customSpinnerApiUrl: string;
}

// Global settings object with defaults to prevent crashes
let currentSettings: Settings = {
    refreshInterval: 5,
    activityName: "Apple Music",
    enableSpotifyButton: true,
    spotifyButtonLabel: "Find On Spotify",
    enableAppleMusicButton: true,
    appleMusicButtonLabel: "Open on Apple Music",
    enableSonglinkButton: false,
    songlinkButtonLabel: "Find on Songlink",
    enableYoutubeMusicButton: false,
    youtubeMusicButtonLabel: "Find on YT Music",
    enableAutoLaunch: false,
    showWhenHovering: true,
    detailsString: "{name}",
    stateString: "by {artist}",
    largeImageText: "{album}",
    smallImageText: "{artist}",
    thirdString: "{name}-{album}",
    smallImageSource: "default",
    enableSmallImage: true,
    spinningSmallImage: false,
    bigImageType: "Album Art",
    enablePauseTimestamp: true,
    timestampType: "Elapsed",
    customSpinnerApiUrl: "https://able-pig-53.deno.dev"
};

// --- HELPER FUNCTIONS ---

async function loadSettings() {
    try {
        const content = await Deno.readTextFile(CONFIG_PATH);
        const loaded = JSON.parse(content);
        // Merge defaults with loaded to ensure all keys exist
        currentSettings = { ...currentSettings, ...loaded };
    } catch (e) {
        // console.warn("Config not found, using defaults");
    }
}

async function runJsInMusic<T>(script: string): Promise<T> {
    const wrappedScript = `JSON.stringify( (() => { ${script} })() )`;
    const cmd = new Deno.Command("osascript", { args: ["-l", "JavaScript", "-e", wrappedScript] });
    const { stdout, code } = await cmd.output();
    if (code !== 0) throw new Error("JXA Execution Failed");
    return JSON.parse(new TextDecoder().decode(stdout)) as T;
}

interface TrackProps { name: string; artist: string; album: string; duration: number; playerPosition: number; }

async function getMusicState(): Promise<{ state: "playing" | "paused" | "stopped", track?: TrackProps }> {
    const script = `
        const music = Application("Music");
        if (!music.running()) return { state: "stopped" };
        const state = music.playerState();
        
        if (state === "playing" || state === "paused") {
            try {
                const track = music.currentTrack;
                return {
                    state: state,
                    track: {
                        name: track.name(), artist: track.artist(), album: track.album(),
                        duration: track.duration(), playerPosition: music.playerPosition()
                    }
                };
            } catch (e) { return { state: "stopped" }; }
        }
        return { state: "stopped" };
    `;
    return await runJsInMusic(script);
}

async function fetchTrackExtras(artist: string, album: string) {
    const query = `${artist} ${album}`;
    const url = `https://itunes.apple.com/search?term=${encodeURIComponent(query)}&entity=album&limit=1`;
    try {
        const resp = await fetch(url);
        if (resp.ok) {
            const json = await resp.json();
            if (json.resultCount > 0) {
                return {
                    artwork: json.results[0].artworkUrl100.replace("100x100bb", "1000x1000bb"),
                    url: json.results[0].collectionViewUrl
                };
            }
        }
    } catch(e) {}
    return null;
}

function formatString(template: string, track: TrackProps): string {
    if (!template) return "";
    return template
        .replace(/\{name\}/g, track.name)
        .replace(/\{artist\}/g, track.artist)
        .replace(/\{album\}/g, track.album);
}

function ensureValid(str: string): string {
    if (!str || str.trim().length < 2) return "Unknown";
    return str.length > 127 ? str.substring(0, 127) : str;
}

// --- MAIN LOGIC ---

async function main() {
    await Deno.writeTextFile(STATUS_PATH, "Service Starting...");
    await loadSettings();
    
    const rpc = new Client({ id: CLIENT_ID });
    
    try {
        await rpc.connect();
    } catch (e) {
        console.error("RPC Connect Error:", e);
        // Exit so launchd can restart us
        Deno.exit(1);
    }

    const tick = async () => {
        try {
            await loadSettings();
            const music = await getMusicState();
            
            if ((music.state === "playing" || music.state === "paused") && music.track) {
                const track = music.track;
                const isPaused = music.state === "paused";
                
                await Deno.writeTextFile(STATUS_PATH, isPaused ? "Paused" : "Playing");
                
                const extras = await fetchTrackExtras(track.artist, track.album);
                
                const activity: Activity = {
                    type: 2, // Listening
                    details: ensureValid(formatString(currentSettings.detailsString, track)),
                    state: ensureValid(formatString(currentSettings.stateString, track)),
                    assets: {
                        large_image: extras?.artwork ?? ICONS.APPLE_MUSIC,
                        large_text: ensureValid(formatString(currentSettings.largeImageText, track))
                    }
                };

                // Timestamps
                if (!isPaused && track.duration > 0) {
                    const now = Date.now();
                    const start = Math.round(now - (track.playerPosition * 1000));
                    const end = Math.round(start + (track.duration * 1000));
                    activity.timestamps = { start, end };
                }

                // Small Image
                if (currentSettings.enableSmallImage) {
                    let smallKey = ICONS.APPLE_MUSIC;
                    let smallText = ensureValid(formatString(currentSettings.smallImageText, track));
                    
                    if (currentSettings.smallImageSource === "playbackStatus") {
                        smallKey = isPaused ? ICONS.PAUSE : ICONS.PLAY;
                        smallText = isPaused ? "Paused" : "Playing";
                    }
                    
                    // Spinner Logic
                    if (currentSettings.spinningSmallImage && extras?.artwork) {
                        const api = currentSettings.customSpinnerApiUrl || "https://able-pig-53.deno.dev";
                        smallKey = `${api}/spin.gif?url=${encodeURIComponent(extras.artwork)}`;
                    }
                    
                    activity.assets!.small_image = smallKey;
                    activity.assets!.small_text = smallText;
                }

                // Buttons
                const buttons = [];
                const searchQ = encodeURIComponent(`${track.name} ${track.artist}`);
                
                if (currentSettings.enableAppleMusicButton) {
                    buttons.push({ label: currentSettings.appleMusicButtonLabel, url: extras?.url ?? `https://music.apple.com/us/search?term=${searchQ}` });
                }
                if (currentSettings.enableSpotifyButton) {
                    buttons.push({ label: currentSettings.spotifyButtonLabel, url: `https://open.spotify.com/search/${searchQ}` });
                }
                
                if (buttons.length > 0) {
                    activity.buttons = buttons.slice(0, 2);
                }

                await rpc.setActivity(activity);
                
            } else {
                await rpc.clearActivity();
                await Deno.writeTextFile(STATUS_PATH, "Idle");
            }
        } catch (e) {
            console.error("Tick Loop Error:", e);
        } finally {
            // SAFETY: Use currentSettings with a hard fallback
            const interval = currentSettings.refreshInterval || 5;
            setTimeout(tick, interval * 1000);
        }
    };

    tick();
}

main();