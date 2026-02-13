# Contributing to peon-ping

## Add a new sound pack

Sound packs are now hosted in their own GitHub repos and registered in the [OpenPeon registry](https://github.com/PeonPing/registry).

### 1. Create your pack

Create a new GitHub repo (e.g., `yourname/openpeon-mypack`) with this structure:

```
openpeon-mypack/
  openpeon.json
  sounds/
    SomeSound.wav
    AnotherSound.mp3
    ...
  README.md
  LICENSE
```

Audio formats: WAV, MP3, or OGG. Keep files small (game sound effects are ideal). Max 1 MB per file, 50 MB total.

### 2. Write the manifest

Create an `openpeon.json` mapping your sounds to CESP categories:

```json
{
  "cesp_version": "1.0",
  "name": "my_pack",
  "display_name": "My Character",
  "version": "1.0.0",
  "author": { "name": "Your Name", "github": "yourname" },
  "license": "CC-BY-NC-4.0",
  "language": "en",
  "categories": {
    "session.start": {
      "sounds": [
        { "file": "sounds/Hello.mp3", "label": "Hello there" }
      ]
    },
    "task.acknowledge": {
      "sounds": [
        { "file": "sounds/OnIt.mp3", "label": "On it" }
      ]
    },
    "task.complete": {
      "sounds": [
        { "file": "sounds/Done.mp3", "label": "Done" }
      ]
    },
    "task.error": {
      "sounds": [
        { "file": "sounds/Oops.mp3", "label": "Oops" }
      ]
    },
    "input.required": {
      "sounds": [
        { "file": "sounds/NeedHelp.mp3", "label": "Need your help" }
      ]
    },
    "resource.limit": {
      "sounds": [
        { "file": "sounds/Blocked.mp3", "label": "Blocked" }
      ]
    },
    "user.spam": {
      "sounds": [
        { "file": "sounds/StopIt.mp3", "label": "Stop it" }
      ]
    }
  }
}
```

**Categories explained:**

| Category | When it plays |
|---|---|
| `session.start` | Session starts (`$ claude`) |
| `task.acknowledge` | Claude acknowledges a task |
| `task.complete` | Claude finishes and is idle |
| `task.error` | Something fails |
| `input.required` | Claude needs tool approval |
| `resource.limit` | Resource limits hit |
| `user.spam` | User spams prompts (3+ in 10 seconds) |

Not every category is required — just include the ones you have sounds for.

### 3. Tag a release

```bash
git tag v1.0.0
git push origin v1.0.0
```

### 4. Register your pack

Submit your pack to the [OpenPeon registry](https://github.com/PeonPing/registry):

1. Fork [PeonPing/registry](https://github.com/PeonPing/registry)
2. Add your pack entry to `index.json` (keep alphabetical order — see [registry CONTRIBUTING.md](https://github.com/PeonPing/registry/blob/main/CONTRIBUTING.md))
3. Open a pull request

Once merged, your pack will be installable by everyone and listed on [openpeon.com/packs](https://openpeon.com/packs).

### 5. Bump the version

We use [semver](https://semver.org/). Edit the `VERSION` file in the repo root:

- **New sound pack** → bump the patch version (e.g. `1.0.0` → `1.0.1`)
- **New feature** (new hook event, config option) → bump the minor version (e.g. `1.0.1` → `1.1.0`)
- **Breaking change** (config format change, removed feature) → bump the major version

Users with an older version will see an update notice on session start.

## Automate pack creation

Have a single audio file with all your character's quotes? You can auto-transcribe and split it:

1. Copy `.env.example` to `.env` and add your [Deepgram API key](https://console.deepgram.com) (or use [Whisper](https://github.com/openai/whisper) locally)
2. Transcribe with word-level timestamps:

```bash
# Option A: Deepgram (cloud, fast)
source .env
curl --http1.1 -X POST \
  "https://api.deepgram.com/v1/listen?model=nova-2&smart_format=true&utterances=true&utt_split=0.8" \
  -H "Authorization: Token $DEEPGRAM_API_KEY" \
  -H "Content-Type: audio/mpeg" \
  --data-binary @your_audio.mp3 -o transcription.json

# Option B: Whisper (local, free)
pip install openai-whisper
whisper your_audio.mp3 --model base --language en --output_format json --word_timestamps True --output_dir .
```

3. Use the timestamps from the JSON to cut individual clips with ffmpeg:

```bash
ffmpeg -i your_audio.mp3 -ss 0.0 -to 1.5 -c copy sounds/Quote1.mp3 -y
ffmpeg -i your_audio.mp3 -ss 2.0 -to 4.8 -c copy sounds/Quote2.mp3 -y
# ... repeat for each quote
```

4. Map the clips to categories in `openpeon.json` and you're done.

## Contribute code

Bug fixes, new features, and IDE adapters are welcome as PRs to this repo. Sound packs should **not** be added here — use the registry flow above.

Run tests before submitting:

```bash
bats tests/
```

## Pack ideas

Browse the full catalog at [openpeon.com/packs](https://openpeon.com/packs) for inspiration, or check the [create guide](https://openpeon.com/create) for the complete walkthrough.
