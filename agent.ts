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
}

async function loadSettings(): Promise<Settings> {
    const defaultSettings: Settings = {
        refreshInterval: 5,
        activityName: "Apple Music",
        enableSpotifyButton: true,
        spotifyButtonLabel: "♫ Find On Spotify",
        enableAppleMusicButton: true,
        appleMusicButtonLabel: "♫ Open on  Music",
    };

    try {
        const content = await Deno.readTextFile(CONFIG_PATH);
        const loaded = { ...defaultSettings, ...JSON.parse(content) };
        console.log(`VAM-RPC Agent: ✅ Successfully loaded settings from ${CONFIG_PATH}`);
        return loaded;
    } catch (e) {
        console.warn(`VAM-RPC Agent: ⚠️ Could not load settings. Using defaults. Reason: ${e.message}`);
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

interface TrackExtras { artworkUrl?: string; trackViewUrl?: string; }
async function fetchTrackExtras(props: TrackProps): Promise<TrackExtras> {
    const query = `${props.name} ${props.artist} ${props.album}`.replace(/\(.*\)/g, "").trim();
    const params = new URLSearchParams({ media: "music", entity: "song", limit: "1", term: query });
    const url = `https://itunes.apple.com/search?${params}`;
    try {
        const resp = await fetch(url);
        if (resp.ok) {
            const json = await resp.json();
            if (json.resultCount > 0) {
                const result = json.results[0];
                return { artworkUrl: result.artworkUrl100, trackViewUrl: result.trackViewUrl };
            }
        }
    } catch { /* Return empty */ }
    return {};
}

function ensureValidString(value: string | null | undefined, minLength = 2, maxLength = 128): string {
    if (!value) return " ".repeat(minLength);
    if (value.length < minLength) return value.padEnd(minLength, " ");
    if (value.length > maxLength) return `${value.slice(0, maxLength - 1)}…`;
    return value;
}

async function main() {
    console.log("VAM-RPC Agent: Starting service.");
    await Deno.writeTextFile(STATUS_PATH, "Service Starting...");
    
    const settings = await loadSettings();
    console.log("VAM-RPC Agent: Current settings:", settings);

    const rpc = new Client({ id: "773825528921849856" });
    await rpc.connect();
    console.log("VAM-RPC Agent: ✅ RPC Connected.");

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

                const activity: Activity = {
                    type: 2, // Listening
                    name: ensureValidString(settings.activityName),
                    details: ensureValidString(track.name),
                    state: ensureValidString(`by ${track.artist}`),
                    timestamps: { start, end },
                    assets: {
                        large_image: extras.artworkUrl ?? "appicon",
                        large_text: ensureValidString(track.album),
                        small_image: "music",
                        small_text: ensureValidString(settings.activityName), 
                    }
                };
                
                const buttons = [];
                if (settings.enableAppleMusicButton && extras.trackViewUrl) {
                    buttons.push({ label: ensureValidString(settings.appleMusicButtonLabel, 2, 32), url: extras.trackViewUrl });
                }
                if (settings.enableSpotifyButton) {
                    const spotifyQuery = encodeURIComponent(`${track.name} ${track.artist}`);
                    const spotifyUrl = `https://open.spotify.com/search/${spotifyQuery}`;
                    buttons.push({ label: ensureValidString(settings.spotifyButtonLabel, 2, 32), url: spotifyUrl });
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
    console.error(`VAM-RPC Agent: A fatal error occurred - ${e.message}`);
    Deno.writeTextFile(STATUS_PATH, `Fatal Error: ${e.message}. Restart service.`);
    Deno.exit(1);
});