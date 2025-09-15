// agent.ts 
import { Client, type Activity } from "https://deno.land/x/discord_rpc@0.3.2/mod.ts";

const SUPPORT_DIR = `${Deno.env.get("HOME")}/Library/Application Support/VAM-RPC`;
const STATUS_PATH = `${SUPPORT_DIR}/status.txt`;

async function runJsInMusic<T>(script: string): Promise<T> {
    const wrappedScript = `JSON.stringify( (() => { ${script} })() )`;
    
    const cmd = new Deno.Command("osascript", { args: ["-l", "JavaScript", "-e", wrappedScript] });
    const { stdout, code, stderr } = await cmd.output();

    if (code !== 0) {
        throw new Error(`AppleScript Error: ${new TextDecoder().decode(stderr)}`);
    }
    return JSON.parse(new TextDecoder().decode(stdout)) as T;
}

interface TrackProps { name: string; artist: string; album: string; duration: number; playerPosition: number; }

async function getMusicState(): Promise<{ state: "playing" | "paused" | "stopped", track?: TrackProps }> {
    //executed in function wrap
    const script = `
        const music = Application("Music");
        if (!music.running()) {
            return { state: "stopped" };
        }
        const state = music.playerState();
        if (state === "playing") {
            try {
                const track = music.currentTrack;
                const props = {
                    name: track.name(),
                    artist: track.artist(),
                    album: track.album(),
                    duration: track.duration(),
                    playerPosition: music.playerPosition()
                };
                return { state: "playing", track: props };
            } catch (e) {
                // This handles cases where music is 'playing' but there's no track (e.g., between songs)
                return { state: "paused" };
            }
        }
        return { state: "paused" };
    `;
    return await runJsInMusic(script);
}

// --- iTunes API for Artwork  ---
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

function ensureValidString(value: string, minLength = 2, maxLength = 128): string {
    if (!value) return "".padEnd(minLength, " ");
    if (value.length < minLength) return value.padEnd(minLength, " ");
    if (value.length > maxLength) return `${value.slice(0, maxLength - 1)}…`;
    return value;
}

async function main() {
    console.log("VAM-RPC Agent: Starting service.");
    await Deno.writeTextFile(STATUS_PATH, "Service Starting...");
    
    console.log("VAM-RPC Agent: Connecting to Discord RPC...");
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
                    type: 2,
                    details: ensureValidString(`${track.name}`),
                    state: ensureValidString(`${track.artist}`),
                    timestamps: { start, end },
                    assets: {
                        large_image: extras.artworkUrl ?? "appicon",
                        large_text: ensureValidString(`⠀⠀`),//3rd text ( emty text )
                        //large_text: ensureValidString(track.album),
                        small_image: "music",
                        small_text: "Apple Music",
                    }
                };
                
                const buttons = [];
                if (extras.trackViewUrl) {
                    buttons.push({ label: "Listen on  Music", url: extras.trackViewUrl });
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
            setTimeout(tick, 5000); // Check every 5 seconds
        }
    };
    
    tick(); // Start the loop
}

main().catch(e => {
    console.error(`VAM-RPC Agent: A fatal error occurred - ${e.message}`);
    Deno.writeTextFile(STATUS_PATH, `Fatal Error: ${e.message}. Restart service.`);
    Deno.exit(1);
});