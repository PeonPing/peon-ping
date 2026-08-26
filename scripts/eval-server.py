#!/usr/bin/env python3
"""peon eval server: same-origin UI + API for judging a draft pack. Stdlib only."""
import argparse, glob, itertools, json, os, re, secrets, sys, threading, queue, subprocess, time, webbrowser, shutil, signal
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import socketserver
from urllib.parse import urlsplit, parse_qs

DRAFT = None          # draft dir (abs)
CLAUDE_BIN = "claude"
PORT = None            # bound port, set in main() — needed for Host/Origin checks
TOKEN = None           # per-session auth token, set in main() (B1)
EVENTS = []           # list of queue.Queue, one per connected SSE client
JOBS = queue.Queue()  # reroll jobs, drained by one worker (Task 7)
STATE = {"busy": False, "proc": None}
BUSY_LOCK = threading.Lock()   # guards the check-and-set of STATE["busy"] on accept
JOB_COUNTER = itertools.count()  # collision-proof job id suffix
SERVER = None         # HTTP server instance, set in main()
NAME_RE = re.compile(r"^[a-z0-9][a-z0-9_-]*$")

def manifest():
    with open(os.path.join(DRAFT, "openpeon.json")) as f:
        return json.load(f)

def pack_summary():
    m = manifest()
    cats = {k: [{"file": s["file"], "label": s.get("label", "")} for s in v.get("sounds", [])]
            for k, v in m.get("categories", {}).items()}
    log_path = os.path.join(DRAFT, "eval-log.json")
    entries = 0
    if os.path.exists(log_path):
        try:
            entries = len(json.load(open(log_path)))
        except Exception:
            entries = 0
    return {"name": m.get("name"), "display_name": m.get("display_name", m.get("name")),
            "draft": bool(m.get("x_openpeon_draft")), "categories": cats,
            "eval_log_entries": entries, "busy": STATE["busy"],
            "claude_available": shutil.which(CLAUDE_BIN) is not None,
            "prompts_present": os.path.exists(os.path.join(DRAFT, "prompts.json"))}

def _kill_proc_tree(proc, sig):
    """Send `sig` to proc's whole process group (it was started with start_new_session=True)
    so a spawned shell script's own children die too, not just the immediate child."""
    if proc is None:
        return
    try:
        pgid = os.getpgid(proc.pid)
        os.killpg(pgid, sig)
    except (ProcessLookupError, PermissionError, OSError):
        try:
            if sig == signal.SIGKILL:
                proc.kill()
            else:
                proc.terminate()
        except Exception:
            pass

def shutdown_handler(signum, frame):
    """Handle SIGTERM by gracefully shutting down the server. Also terminates any
    in-flight `claude -p` child (and its process tree) so it doesn't get orphaned."""
    proc = STATE.get("proc")
    if proc is not None and proc.poll() is None:
        _kill_proc_tree(proc, signal.SIGTERM)
    if SERVER:
        threading.Thread(target=SERVER.shutdown).start()

def broadcast(ev):
    for q in list(EVENTS):
        q.put(ev)

def _target_wav_paths(job):
    """Absolute paths of every WAV a job is expected to touch, resolved from the
    manifest ON DISK right now (before the reroll runs). Used for B3's
    before/after change-detection — a `claude -p` that exits 0 without writing
    anything must not be reported as `done`."""
    try:
        m = manifest()
    except Exception:
        return []
    cats = m.get("categories", {})
    paths = []
    if job.get("scope") == "sound":
        sounds = cats.get(job.get("category"), {}).get("sounds", [])
        idx = job.get("index")
        if isinstance(idx, int) and not isinstance(idx, bool) and 0 <= idx < len(sounds):
            f = sounds[idx].get("file")
            if f:
                paths.append(os.path.join(DRAFT, f))
    else:
        for cat in cats.values():
            for s in cat.get("sounds", []):
                f = s.get("file")
                if f:
                    paths.append(os.path.join(DRAFT, f))
    return paths

def _snapshot(paths):
    """(mtime_ns, size) per target WAV plus the eval-log entry count — the
    'did anything actually change' fingerprint for B3."""
    snap = {}
    for p in paths:
        try:
            st = os.stat(p)
            snap[p] = (st.st_mtime_ns, st.st_size)
        except OSError:
            snap[p] = None
    log_path = os.path.join(DRAFT, "eval-log.json")
    entries = 0
    if os.path.exists(log_path):
        try:
            entries = len(json.load(open(log_path)))
        except Exception:
            entries = 0
    return snap, entries

def worker():
    while True:
        job_id, job = JOBS.get()
        broadcast({"type": "started", "job": job_id})
        try:
            jobs_dir = os.path.join(DRAFT, "jobs")
            os.makedirs(jobs_dir, exist_ok=True)
            job_path = os.path.join(jobs_dir, job_id + ".json")
            with open(job_path, "w") as f:
                json.dump(job, f, indent=1)
            target_paths = _target_wav_paths(job)
            before_snap, before_entries = _snapshot(target_paths)
            prompt = ("Use the peon-ping-remix skill to execute the reroll job at %s. "
                      "Follow the skill exactly." % job_path)
            # B3(a): give the spawned Claude Code a cwd it's actually allowed to write
            # in, plus explicit --add-dir grants — under --permission-mode default
            # (the vast majority of real users) an agent with no cwd/--add-dir in the
            # draft tree cannot write the draft or run pack-render.py, yet used to
            # still exit 0 and get reported as a successful reroll.
            draft_ok = DRAFT and os.path.isdir(DRAFT)
            peon_dir_env = os.environ.get("PEON_DIR", "")
            claude_cmd = [CLAUDE_BIN]
            if draft_ok:
                claude_cmd += ["--add-dir", DRAFT]
            if peon_dir_env and os.path.isdir(peon_dir_env):
                claude_cmd += ["--add-dir", peon_dir_env]
            claude_cmd += ["-p", prompt]
            proc = subprocess.Popen(claude_cmd,
                                     cwd=DRAFT if draft_ok else None,
                                     stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                     text=True, start_new_session=True)
            STATE["proc"] = proc
            try:
                out, err = proc.communicate(timeout=1800)
                rc = proc.returncode
            except subprocess.TimeoutExpired:
                _kill_proc_tree(proc, signal.SIGKILL)
                out, err = proc.communicate()
                rc = -1
                err = err or out or "timed out after 1800s"
            if rc == 0:
                # B3(b): NEVER trust rc alone. A permission-refused write still
                # exits 0 — only believe "done" if the target WAV(s) or the
                # eval-log actually changed.
                after_snap, after_entries = _snapshot(target_paths)
                if after_snap != before_snap or after_entries != before_entries:
                    broadcast({"type": "done", "job": job_id})
                else:
                    tail = (out or err or "").strip()[-500:]
                    detail = ("the reroll made no changes — Claude Code may have "
                              "lacked write permission for the draft directory")
                    if tail:
                        detail += ": " + tail
                    broadcast({"type": "failed", "job": job_id, "detail": detail})
            else:
                broadcast({"type": "failed", "job": job_id, "detail": (err or out or "")[-500:]})
        except Exception as e:
            broadcast({"type": "failed", "job": job_id, "detail": str(e)[-500:]})
        finally:
            STATE["proc"] = None
            STATE["busy"] = False

class Handler(BaseHTTPRequestHandler):
    def log_message(self, *a):  # quiet
        pass

    def _json(self, obj, code=200):
        body = json.dumps(obj, indent=1).encode()
        self.send_response(code)
        self.send_header("content-type", "application/json")
        self.send_header("content-length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    # ---- B1: auth/origin/host defense -------------------------------------

    def _query_token(self):
        try:
            qs = parse_qs(urlsplit(self.path).query)
        except Exception:
            return None
        vals = qs.get("t")
        return vals[0] if vals else None

    def _api_authorized(self):
        supplied = self.headers.get("X-Eval-Token") or self._query_token()
        return bool(supplied) and bool(TOKEN) and secrets.compare_digest(supplied, TOKEN)

    def _host_ok(self):
        host = (self.headers.get("Host") or "").split(",")[0].strip().lower()
        return host in ("127.0.0.1:%d" % PORT, "localhost:%d" % PORT)

    def _origin_ok(self):
        origin = self.headers.get("Origin")
        if origin is None:
            return True  # same-origin requests (curl, EventSource) send no Origin
        return origin in ("http://127.0.0.1:%d" % PORT, "http://localhost:%d" % PORT)

    def _content_type_ok(self):
        ct = (self.headers.get("Content-Type") or "").split(";")[0].strip().lower()
        return ct.startswith("application/json")

    def _sse(self):
        q = queue.Queue()
        EVENTS.append(q)
        self.send_response(200)
        self.send_header("content-type", "text/event-stream")
        self.send_header("cache-control", "no-cache")
        self.end_headers()
        try:
            while True:
                try:
                    ev = q.get(timeout=15)
                    self.wfile.write(b"data: " + json.dumps(ev).encode() + b"\n\n")
                except queue.Empty:
                    self.wfile.write(b": keepalive\n\n")
                self.wfile.flush()
        except (BrokenPipeError, ConnectionResetError):
            pass
        finally:
            EVENTS.remove(q)

    def do_GET(self):
        path_only = self.path.split("?", 1)[0]  # routing ignores the query string;
                                                  # _api_authorized/_query_token read self.path directly
        if not self._host_ok():
            return self._json({"error": "forbidden"}, 403)
        if path_only.startswith("/api/") and not self._api_authorized():
            return self._json({"error": "forbidden"}, 403)
        if path_only == "/api/pack":
            # DRAFT may have been moved away by a completed approve; a late poll
            # in the ~1s window before shutdown must get a clean 404, not a traceback.
            if not os.path.isdir(DRAFT):
                return self._json({"error": "not found"}, 404)
            return self._json(pack_summary())
        if path_only.startswith("/sounds/"):
            if not os.path.isdir(DRAFT):
                return self._json({"error": "not found"}, 404)
            base = path_only[len("/sounds/"):]
            if "/" in base or ".." in base or not base.endswith(".wav"):
                return self._json({"error": "not found"}, 404)
            p = os.path.join(DRAFT, "sounds", base)
            if not os.path.isfile(p):
                return self._json({"error": "not found"}, 404)
            # Resolve symlinks and verify target is within sounds dir
            real_p = os.path.realpath(p)
            sounds_dir = os.path.realpath(os.path.join(DRAFT, "sounds"))
            if not real_p.startswith(sounds_dir + os.sep) and real_p != sounds_dir:
                return self._json({"error": "not found"}, 404)
            data = open(real_p, "rb").read()
            self.send_response(200)
            self.send_header("content-type", "audio/wav")
            self.send_header("content-length", str(len(data)))
            self.end_headers()
            return self.wfile.write(data)
        if path_only == "/":
            ui = os.path.join(os.path.dirname(os.path.abspath(__file__)), "eval-ui.html")
            body = open(ui, "rb").read() if os.path.exists(ui) else b"<h1>peon eval</h1>"
            self.send_response(200)
            self.send_header("content-type", "text/html; charset=utf-8")
            self.send_header("content-length", str(len(body)))
            self.end_headers()
            return self.wfile.write(body)
        if path_only == "/api/events":
            return self._sse()          # Task 7
        return self._json({"error": "not found"}, 404)

    def do_POST(self):
        path_only = self.path.split("?", 1)[0]
        if not self._host_ok():
            return self._json({"error": "forbidden"}, 403)
        if path_only.startswith("/api/"):
            if not self._api_authorized():
                return self._json({"error": "forbidden"}, 403)
            if not self._content_type_ok():
                return self._json({"error": "forbidden"}, 403)
            if not self._origin_ok():
                return self._json({"error": "forbidden"}, 403)
        if path_only == "/api/reroll":
            return self._reroll()
        if path_only == "/api/approve":
            return self._approve()
        return self._json({"error": "not found"}, 404)

    def _reroll(self):
        # DRAFT may have been moved away by a completed approve; a late/duplicate
        # request in the ~1s window before shutdown must get a clean 404, not a traceback.
        if not os.path.isdir(DRAFT):
            return self._json({"error": "not found"}, 404)
        length = int(self.headers.get("content-length", 0))
        raw = self.rfile.read(length) if length else b""
        try:
            body = json.loads(raw) if raw else {}
        except json.JSONDecodeError:
            return self._json({"error": "invalid json"}, 400)
        scope = body.get("scope")
        if scope not in ("sound", "pack"):
            return self._json({"error": "scope must be 'sound' or 'pack'"}, 400)
        category = body.get("category")
        index = body.get("index")
        caption = body.get("caption")
        m = manifest()
        if scope == "sound":
            cats = m.get("categories", {})
            if category not in cats:
                return self._json({"error": "unknown category"}, 400)
            sounds = cats[category].get("sounds", [])
            if not isinstance(index, int) or isinstance(index, bool) or index < 0 or index >= len(sounds):
                return self._json({"error": "index out of range"}, 400)
        # Atomic check-and-set: only one concurrent request can flip busy False->True.
        # The worker no longer sets STATE["busy"]; it only clears it after the terminal event.
        with BUSY_LOCK:
            if STATE["busy"]:
                return self._json({"error": "busy"}, 409)
            STATE["busy"] = True
        job_id = "%d-%d" % (int(time.time() * 1000), next(JOB_COUNTER))
        job = {"scope": scope, "category": category, "index": index, "caption": caption,
               "draft_dir": DRAFT, "pack_name": m.get("name")}
        JOBS.put((job_id, job))
        return self._json({"job": job_id}, 202)

    def _approve(self):
        """The only door out of draft state. Strips the draft stamp, moves the pack
        to the approved dir, optionally installs it, and schedules the eval session's
        own shutdown. Uses the same BUSY_LOCK check-and-set discipline as _reroll so
        an approve racing a reroll accept (or a second approve) can't interleave."""
        with BUSY_LOCK:
            if STATE["busy"]:
                return self._json({"error": "busy"}, 409)
            STATE["busy"] = True
        ok = False
        try:
            if not os.path.isdir(DRAFT):
                return self._json({"error": "not found"}, 404)
            length = int(self.headers.get("content-length", 0))
            raw = self.rfile.read(length) if length else b""
            try:
                body = json.loads(raw) if raw else {}
            except json.JSONDecodeError:
                return self._json({"error": "invalid json"}, 400)
            m = manifest()
            # B5: approve is the only door out of draft state — it must refuse
            # anything that isn't actually stamped as a draft (e.g. `peon eval`
            # pointed straight at an installed pack, or any random directory
            # with an openpeon.json).
            if not m.get("x_openpeon_draft"):
                return self._json({"error": "not a draft"}, 409)
            m.pop("x_openpeon_draft", None)
            # B2: `name` is a write path. Never trust it verbatim — it must be a
            # bare, slash-free, dot-free identifier, or we fall back to the
            # draft directory's own basename (itself re-validated).
            name = m.get("name")
            if not isinstance(name, str) or not NAME_RE.fullmatch(name):
                name = os.path.basename(DRAFT.rstrip(os.sep))
            if not NAME_RE.fullmatch(name or ""):
                return self._json({"error": "invalid pack name"}, 400)
            approved_root = os.environ.get("PEON_APPROVED_DIR",
                                            os.path.expanduser("~/.peon-ping/packs"))
            final = os.path.join(approved_root, name)
            real_root = os.path.realpath(approved_root)
            real_final = os.path.realpath(final)
            if real_final != real_root and not real_final.startswith(real_root + os.sep):
                return self._json({"error": "invalid pack name"}, 400)
            if os.path.exists(final):
                return self._json({"error": "exists", "path": final}, 409)
            # The manifest's `name` must match the validated/normalized value
            # used for the write path, not whatever the draft author put in
            # openpeon.json — otherwise directory identity and manifest
            # identity diverge and a downstream consumer that joins manifest
            # `name` to a path (registry publish, site tooling, `peon packs`)
            # re-opens the traversal this normalization was meant to close.
            m["name"] = name
            with open(os.path.join(DRAFT, "openpeon.json"), "w") as f:
                json.dump(m, f, indent=2)
            shutil.rmtree(os.path.join(DRAFT, "jobs"), ignore_errors=True)
            # R13: prune stray render-job scratch files left at the draft root by
            # older create-pack/remix runs (now they write under jobs/, which the
            # rmtree above already prunes) so approved packs don't ship junk.
            for stray in glob.glob(os.path.join(DRAFT, "render-job*.json")):
                try:
                    os.unlink(stray)
                except OSError:
                    pass
            try:
                os.unlink(os.path.join(DRAFT, ".eval-server.json"))
            except OSError:
                pass
            os.makedirs(approved_root, exist_ok=True)
            shutil.move(DRAFT, final)
            # R11: the move is the point of no return — the draft is gone from
            # here on, so this counts as success even if the OPTIONAL install
            # step below fails. Set state immediately so a raise in the install
            # step can't leave the request hanging with no HTTP response while
            # the pack has already vanished from DRAFT.
            ok = True
            installed = False
            install_error = None
            if body.get("install"):
                peon_dir = os.environ.get("PEON_DIR", os.path.expanduser("~/.claude/hooks/peon-ping"))
                packs_root = os.path.join(peon_dir, "packs")
                install_target = os.path.join(packs_root, name)
                real_packs_root = os.path.realpath(packs_root)
                real_install_target = os.path.realpath(install_target)
                try:
                    if real_install_target != real_packs_root and not real_install_target.startswith(real_packs_root + os.sep):
                        raise ValueError("invalid install target")
                    shutil.copytree(final, install_target, dirs_exist_ok=True)
                    installed = True
                except Exception as e:
                    install_error = str(e)
            # The eval session is over — no further requests are expected.
            threading.Timer(1.0, self.server.shutdown).start()
            resp = {"approved": final, "installed": installed}
            if install_error:
                resp["install_error"] = install_error
            return self._json(resp)
        finally:
            # DRAFT still exists on any non-success path (busy/exists/bad-json/error):
            # release the lock so a retry isn't stuck behind a phantom "busy".
            if not ok:
                STATE["busy"] = False

class FastBindServer(ThreadingHTTPServer):
    """ThreadingHTTPServer that binds without a reverse-DNS lookup.

    http.server's server_bind() calls socket.getfqdn(host), which does a reverse
    lookup on the bind address. On a host with no reverse record for 127.0.0.1
    that call blocks until the resolver gives up (GitHub's macOS runners are the
    reliable case: it stalls past the point where callers assume the server is
    dead). The result is only ever used to populate server_name for CGI variables
    this server never emits, so bind without it and keep startup instant.
    """

    def server_bind(self):
        socketserver.TCPServer.server_bind(self)
        host, port = self.server_address[:2]
        self.server_name = host
        self.server_port = port


def main():
    global DRAFT, CLAUDE_BIN, SERVER, PORT, TOKEN
    ap = argparse.ArgumentParser()
    ap.add_argument("--draft", required=True)
    ap.add_argument("--port", type=int, default=0)
    ap.add_argument("--claude-bin", default="claude")
    ap.add_argument("--no-open", action="store_true")
    ap.add_argument("--print-port", action="store_true")
    args = ap.parse_args()
    DRAFT = os.path.abspath(args.draft)
    CLAUDE_BIN = args.claude_bin
    if not os.path.exists(os.path.join(DRAFT, "openpeon.json")):
        sys.stderr.write("no openpeon.json in %s\n" % DRAFT)
        sys.exit(1)
    TOKEN = secrets.token_urlsafe(32)
    SERVER = FastBindServer(("127.0.0.1", args.port), Handler)
    port = SERVER.server_address[1]
    PORT = port
    lock = os.path.join(DRAFT, ".eval-server.json")
    with open(lock, "w") as f:
        json.dump({"port": port, "pid": os.getpid(), "token": TOKEN}, f)
    signal.signal(signal.SIGTERM, shutdown_handler)
    threading.Thread(target=worker, daemon=True).start()
    if args.print_port:
        print("PORT=%d" % port, flush=True)
    if not args.no_open:
        webbrowser.open("http://127.0.0.1:%d/?t=%s" % (port, TOKEN))
    try:
        SERVER.serve_forever()
    finally:
        try:
            os.unlink(lock)
        except OSError:
            pass

if __name__ == "__main__":
    main()
