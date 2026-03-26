# Omnidea Wiring Guide

**The integration recipe.** How features flow through the stack, and how to add new ones.

Read this before implementing anything that crosses repo boundaries. This is the map.

---

## The One Path

Every feature in Omnidea follows the same pipe:

```
Rust crate (logic)
  → divi_* FFI function (C ABI, JSON strings)
    → Equipment Phone handler (daemon module)
      → IPC over Unix socket (line-delimited JSON)
        → window.omninet bridge (JS)
          → Solid.js component (UI)
```

There is one pattern. Not five. When in doubt, follow the pipe.

---

## The Three Repos

| Repo | Role | Language | Where |
|------|------|----------|-------|
| **Omninet** | The protocol. 29 Rust crates, 6,619 tests. Complete. | Rust | `Omninet/` |
| **Omny** | The browser. Daemon + shell + chrome + programs. | Rust + TypeScript | `Omny/` |
| **Ore** | Engine + libraries. SDK + UI + editor + Crystal + Beryllium. | TypeScript + Rust | `Ore/` |

**Data flows:** Omninet → (FFI) → Omny daemon → (IPC) → Omny shell → (bridge) → Ore SDK → Omny programs

---

## Layer 1: Rust Crate (Omninet)

### Where does the logic go?

Pick the crate that owns the domain. The 26 ABCs:

| Letter | Crate | Owns | Zero Deps? |
|--------|-------|------|------------|
| A | Advisor | AI cognition, thoughts, synapse, LLM routing | |
| B | Bulwark | Safety, trust layers, Kids Sphere, permissions | |
| C | Crown | Identity, keypairs, keyring, soul, social graph | ✓ |
| D | Divinity | FFI boundary + Zig orchestrator + platform bridges (don't add domain logic here) | |
| E | Equipment | Phone/Email/Contacts/Pager/Communicator | ✓ |
| F | Fortune | Economics, treasury, UBI, demurrage, cash, exchange | |
| G | Globe | Networking (ORP), relay protocol, relay pool, gospel | |
| H | Hall | Encrypted file I/O for .idea packages | |
| I | Ideas | .idea format, Digits, Headers, schemas, CRDT ops | |
| J | Jail | Accountability, trust graph, flags, graduated response | |
| K | Kingdom | Governance, communities, charters, proposals, voting | |
| L | Lingo | Language, Babel obfuscation, formulas, translation | |
| M | Magic | Rendering, code projection, document state | |
| N | Nexus | Export/import/bridge (PDF, DOCX, XLSX, SMTP, etc.) | |
| O | Oracle | Onboarding, hints, recovery, sovereignty tiers | ✓ |
| P | Polity | Constitutional guard, rights/duties/protections | |
| Q | Quest | Gamification, missions, achievements, skill trees | ✓ |
| R | Regalia | Design language, tokens, layout, animation, themes | |
| S | Sentinal | Encryption, AES-256-GCM, PBKDF2, BIP-39 | ✓ |
| T | Target | Cargo build output (not a crate) | |
| U | Undercroft | Health observatory, app catalog, device manager | |
| V | Vault | Encrypted storage, SQLCipher manifest, collectives | |
| W | World | Digital (Omnibus/Tower/MagicalIndex) + Physical | |
| X | X | Shared utilities, Value, CRDT, geo, color | ✓ |
| Y | Yoke | History, provenance, relationships, versioning | |
| Z | Zeitgeist | Discovery, Tower directory, search routing, trends | |

**Rule:** No direct cross-crate imports between domain crates. Use Equipment (Phone/Email) for cross-crate communication, or place shared types in the domain-owning crate (usually X or Ideas).

---

## Layer 2: FFI Boundary (Omninet → Divinity/ffi)

### Adding an FFI function

1. Add your function in the appropriate `Divinity/ffi/src/{domain}_ffi.rs` file
2. Use the `divi_` prefix: `pub extern "C" fn divi_yoke_bookmark_create(...)`
3. Follow one of three return patterns:

**Pattern A — Status code (most mutations):**
```rust
#[unsafe(no_mangle)]
pub extern "C" fn divi_vault_unlock(vault: *mut DiviVault, password: *const c_char) -> i32 {
    clear_last_error();
    // ... do work ...
    // Return 0 on success, -1 on error (set_last_error for details)
}
```

**Pattern B — JSON string (most queries):**
```rust
#[unsafe(no_mangle)]
pub extern "C" fn divi_crown_whoami(keyring: *mut CrownKeyring) -> *mut c_char {
    clear_last_error();
    // ... do work ...
    json_to_c(&result)  // Returns *mut c_char (JSON), null on error
    // Caller frees via divi_free_string()
}
```

**Pattern C — Bytes via out-params (raw data):**
```rust
#[unsafe(no_mangle)]
pub unsafe extern "C" fn divi_sentinal_encrypt(
    plaintext: *const u8, plaintext_len: usize,
    key: *const u8, key_len: usize,
    out_data: *mut *mut u8, out_len: *mut usize,
) -> i32 {
    // 0 = success, result in *out_data/*out_len
    // Caller frees via divi_free_bytes()
}
```

### Helpers

**In `helpers.rs`:**
- `c_str_to_str(ptr)` — null-safe CStr → &str
- `string_to_c(s)` — String → CString → raw
- `json_to_c<T: Serialize>(value)` — serialize to JSON, null on failure
- `lock_or_recover<T>(mutex)` — poison-recovering Mutex lock
- `bytes_to_owned(data)` — Vec<u8> → raw pointer + length

**In `lib.rs`:**
- `set_last_error(msg)` / `clear_last_error()` — thread-local error string

### Opaque pointer pattern

Types with `&mut self` methods get wrapped in `Mutex` at the FFI boundary:
```rust
pub struct DiviVault(Mutex<Vault>);
```
Types that are already thread-safe (Equipment, Omnibus) are used directly.

### After adding FFI functions

The C header (`divinity_ffi.h`) auto-generates via cbindgen. The SDK codegen script (`Ore/sdk/scripts/generate.py`) parses this header to produce TypeScript types and operations automatically.

---

## Layer 3: Daemon Module (Omny → omnidaemon)

### Where daemon modules live

`Omny/omnidaemon/daemon/src/modules/`

### The DaemonModule trait

```rust
pub trait DaemonModule: Send + Sync {
    fn id(&self) -> &str;           // e.g., "crown"
    fn name(&self) -> &str;         // e.g., "Crown Identity"
    fn deps(&self) -> &[&str];     // e.g., &["vault"]
    fn register(&self, state: &Arc<DaemonState>);
    fn catalog(&self) -> ModuleCatalog;
}
```

### Adding a daemon module

1. Create `Omny/omnidaemon/daemon/src/modules/your_mod.rs`
2. Implement `DaemonModule`
3. Register Phone handlers for each operation:

```rust
fn register(&self, state: &Arc<DaemonState>) {
    let state = Arc::clone(state);
    state.phone.register_raw("bookmark.create", move |data| {
        let params: serde_json::Value = serde_json::from_slice(data)?;
        // ... do work using state.vault, state.omnibus, etc. ...
        Ok(serde_json::to_vec(&json!({ "id": bookmark_id }))?)
    });
}
```

4. Add to module list in `Omny/omnidaemon/daemon/src/modules/mod.rs`
5. Modules boot in dependency order automatically

### The DaemonState

Available in every module handler (via `Arc<DaemonState>`):
- `state.phone` — Equipment Phone (RPC dispatch)
- `state.email` — Equipment Email (pub/sub events)
- `state.contacts` — Equipment Contacts (module registry)
- `state.pager` — Equipment Pager (notifications)
- `state.communicator` — Equipment Communicator (real-time sessions, future)
- `state.vault` — `Mutex<Vault>` (encrypted storage)
- `state.omnibus` — `OmnibusRef` (networking — access Omnibus via `state.omnibus.omnibus()`, Tower via `state.omnibus.tower()`)
- `state.crown_locked` — `AtomicBool` Crown lock state
- `state.config` — `Mutex<DaemonConfig>` daemon configuration
- `state.data_dir` — `PathBuf` data directory (e.g., `~/.omnidea/data`)
- `state.editor_sessions` — `Mutex<HashMap<Uuid, EditorSession>>` open editors

### Lock ordering convention

**Always: sessions → vault.** Never vault → sessions. (Session 156 ABBA deadlock lesson.)

---

## Layer 4: API Contract (Omny → omnidaemon/api_json.rs)

**Never use `serde_json::to_value()` on complex structs.** The API contract is hand-built.

### Why hand-built?

`#[serde(rename)]`, `#[serde(skip_serializing_if)]`, and `#[serde(flatten)]` silently change JSON shape when someone edits a struct in Omninet. Hand-built JSON makes the contract visible in one file.

### The pattern

```rust
// In api_json.rs
pub fn bookmark_json(bookmark: &Bookmark) -> Value {
    json!({
        "id": bookmark.id.to_string(),
        "url": bookmark.url,
        "title": bookmark.title,
        "created": bookmark.created_at.to_rfc3339(),
    })
}
```

### x::Value unwrapping

`x::Value` uses custom serde that wraps variants: `{"string": "hello"}`. For TypeScript clients, unwrap to plain JSON using `x_to_json()` / `json_to_x()` in api_json.rs.

---

## Layer 5: IPC Protocol (Daemon ↔ Clients)

### Transport

Unix domain socket at `~/.omnidea/daemon.sock` (Named Pipe on Windows).
Line-delimited JSON. One JSON object per line.

### Authentication (first message)

```json
{"auth": "<hex-token>", "client_type": "beryllium", "program_id": null}
→ {"auth": "ok", "session_id": "abc123", "client_type": "beryllium"}
```

Token lives at `~/.omnidea/auth.token` (0600 permissions).

### Request/Response

```json
→ {"id": 1, "method": "bookmark.create", "params": {"url": "net://...", "title": "My Page"}}
← {"id": 1, "result": {"id": "abc123"}}
```
Or on error:
```json
← {"id": 1, "error": {"code": -32601, "message": "unknown method"}}
```

### Push events (server → client)

```json
← {"event": "bookmark.created", "data": {"id": "abc123"}}
```

### Error codes

| Code | Meaning |
|------|---------|
| -1 | General error |
| -2 | Serialization failure |
| -5 | Permission denied |
| -6 | Auth failure |
| -32601 | Unknown method |

---

## Layer 6: JS Bridge (Omny → omnishell/bridge.rs → window.omninet)

### The bridge object

Programs access the daemon through `window.omninet`:

```typescript
// Pipeline execution (routes through Equipment Phone dispatch)
const result = await window.omninet.run(pipelineJson: string): Promise<string>

// Platform operations (identity, capture, chrome)
const state = await window.omninet.platform(op: string, inputJson: string): Promise<string>

// Push event subscription
window.omninet.on(event: string, handler: Function)
window.omninet.off(event: string, handler: Function)
```

### Two bridge implementations (auto-detected)

1. **WebIDL** — native Servo API in Beryllium (faster, preferred)
2. **Fetch** — `GET omny://api/run/{base64}` fallback (works in any browser for dev)

### CRITICAL: Wire format mismatch (known bug)

The WebIDL bridge (`Omninet.webidl`) declares `run(DOMString pipelineJson)` — it expects a **string**. The fetch bridge also expects a string (it base64-encodes it for the URL).

**But the SDK disagrees.** `Ore/sdk/src/bridge.ts` declares `run(pipeline: PipelineRequest)` taking an **object**, and `ops.ts` passes objects directly (not JSON strings). The omnigrams bridge (`omninet.ts`) correctly uses JSON strings.

**Rule:** When calling `window.omninet.run()` directly, always `JSON.stringify()` first. The SDK's generated ops work because they're primarily used in Programs served through the fetch bridge, where serialization happens at a different layer — but the type declaration in `bridge.ts` is wrong and should be `run(pipelineJson: string)`.

### Anti-spoofing

Both editor and omnigrams capture `window.omninet` method references at module load time via `.bind()` and freeze them. Malicious code replacing `window.omninet` later can't affect existing programs.

---

## Layer 7: SDK (Ore → @omnidea/net)

### Auto-generated from Rust

`Ore/sdk/scripts/generate.py` parses:
1. Rust source files for structs/enums with `Serialize`/`Deserialize` → TypeScript interfaces
2. The C header (`divinity_ffi.h`) for FFI function discovery → TypeScript operations

**860 operations.** 817 interfaces. 370 type aliases.

### How programs use it

```typescript
import { crown } from '@omnidea/net';

const result = await crown.whoami();
// Internally calls: window.omninet.run({
//   source: 'sdk',
//   steps: [{ id: 'r', op: 'crown.whoami', input: {} }]
// })
// Note: ops.ts passes an object. See "Wire format mismatch" in Layer 6.
```

### Adding a new SDK operation

You don't edit `ops.ts` or `types.ts`. You:
1. Add the FFI function in Omninet
2. Regenerate the C header (cbindgen, automatic)
3. Run `cd Ore/sdk && npm run generate`
4. The new operation appears in TypeScript automatically

---

## Layer 8: UI Components (Ore → @omnidea/ui)

### 40 Solid.js components

Organized by atomic design: `atoms/` → `components/` → `crystal/` → `layout/` → `theme/`

### Key facts

- **No direct `@omnidea/net` consumption.** UI components are purely presentational.
- **Two visual modes:** `neu` (neumorphic flat) and `crystal` (WebGPU glass). Components branch on `isCrystal()`.
- **Source-distributed.** Consumers compile the TSX (ensures single Solid.js runtime).
- **Regalia token vocabulary:** Ember (color), Crest (palette), Span (spacing), Glyph (typography), Arch (radius), Umbra (shadows).
- **Icon convention:** Remix Icon `ri-{name}-{fill|line}` CSS classes.

---

## Layer 9: Programs (Omny → omnigrams)

### What programs are

Solid.js TypeScript applications served via `omny://system/{name}.html`. They are "lenses" — views into Omnidea's data, not siloed apps.

### Structure

```
omnigrams/
  src/
    entries/     ← HTML mount points
    pages/       ← Top-level Solid.js page components
    lib/
      omninet.ts ← Bridge SDK (run, platform, on, off)
      stores/    ← Reactive state (Solid.js signals)
      components/ ← Shared atoms + composites
  dist/          ← Build output (served via omny://)
```

### Adding a new program

1. Create `omnigrams/src/pages/YourPage.tsx`
2. Create `omnigrams/src/entries/your-page.tsx` (mount point)
3. Create `omnigrams/dist/your-page.html` (entry HTML)
4. Use `@omnidea/net` SDK for data operations
5. Use `@omnidea/ui` components for UI
6. The `omny://` protocol handler serves it automatically from `dist/`

---

## Complete Example: Adding "Bookmarks"

Here's every file you'd touch, in order:

### 1. Omninet — Rust logic
**File:** `Omninet/Yoke/src/bookmark.rs` (or wherever bookmarks belong)
```rust
pub struct Bookmark { pub id: Uuid, pub url: String, pub title: String, pub created_at: DateTime<Utc> }
pub fn create_bookmark(url: &str, title: &str) -> Result<Bookmark, YokeError> { ... }
```

### 2. Omninet — FFI exposure
**File:** `Omninet/Divinity/ffi/src/yoke_ffi.rs`
```rust
#[unsafe(no_mangle)]
pub extern "C" fn divi_yoke_bookmark_create(url: *const c_char, title: *const c_char) -> *mut c_char {
    clear_last_error();
    let url = c_str_to_str(url).unwrap_or("");
    let title = c_str_to_str(title).unwrap_or("");
    match yoke::bookmark::create_bookmark(url, title) {
        Ok(b) => json_to_c(&b),
        Err(e) => { set_last_error(&e.to_string()); std::ptr::null_mut() }
    }
}
```

### 3. Ore — SDK regeneration
```bash
cd Ore/sdk && npm run generate
# bookmark.create now appears in @omnidea/net automatically
```

### 4. Omny — Daemon module handler
**File:** `Omny/omnidaemon/daemon/src/modules/yoke_mod.rs` (add handler)
```rust
state.phone.register_raw("bookmark.create", move |data| {
    let params: Value = serde_json::from_slice(data)?;
    let url = params["url"].as_str().unwrap_or("");
    let title = params["title"].as_str().unwrap_or("");
    // Call FFI or Rust directly
    let bookmark = yoke::bookmark::create_bookmark(url, title)?;
    Ok(serde_json::to_vec(&bookmark_json(&bookmark))?)
});
```

### 5. Omny — API contract
**File:** `Omny/omnidaemon/daemon/src/api_json.rs` (add converter)
```rust
pub fn bookmark_json(b: &Bookmark) -> Value {
    json!({ "id": b.id.to_string(), "url": b.url, "title": b.title, "created": b.created_at.to_rfc3339() })
}
```

### 6. Omny — Program UI
**File:** `Omny/omnigrams/src/pages/Bookmarks.tsx`
```tsx
import { yoke } from '@omnidea/net';
import { Button, Card } from '@omnidea/ui';

export default function Bookmarks() {
  const [bookmarks, setBookmarks] = createSignal([]);
  const addBookmark = async () => {
    const result = await yoke.bookmarkCreate({ url: '...', title: '...' });
    // update UI
  };
  return <Card><Button onClick={addBookmark}>Add Bookmark</Button></Card>;
}
```

**That's it.** Six touch points, same pattern every time.

---

## Build System

| Piece | Tool | Command |
|-------|------|---------|
| Omninet (Rust) | Cargo | `cargo build --release` / `cargo test` |
| Omninet (C header) | cbindgen | Automatic during cargo build |
| Ore (SDK codegen) | Python | `cd sdk && npm run generate` |
| Ore (SDK compile) | TypeScript | `cd sdk && tsc` |
| Ore (Crystal) | Vite | `cd crystal && vite build` |
| Ore (UI CSS) | tsx | `cd ui && tsx scripts/build-css.ts` |
| Ore (all) | npm workspaces | `npm run build` (sdk → crystal → ui) |
| Omny (daemon) | Cargo | `cd omnidaemon && cargo build` |
| Omny (shell) | Cargo | `cd omnishell && cargo build` |
| Omny (programs) | Vite | `cd omnigrams && npm run build` |
| Beryllium | Servo mach | `cd Ore/beryllium && ./mach build` |
| Tests (Rust) | Cargo | `cargo test` (from Omninet root) |
| Tests (TypeScript) | Vitest | `cd Ore && npx vitest run` |

**Build order:** Omninet → Ore SDK → Ore UI → Omny daemon → Omny programs → Omny shell

---

## Files You'll Touch Most

| When you're doing... | You'll touch... |
|---------------------|-----------------|
| Adding protocol logic | `Omninet/{Crate}/src/*.rs` |
| Exposing to FFI | `Omninet/Divinity/ffi/src/{domain}_ffi.rs` |
| Wiring to daemon | `Omny/omnidaemon/daemon/src/modules/{domain}_mod.rs` |
| Controlling JSON shape | `Omny/omnidaemon/daemon/src/api_json.rs` |
| Updating SDK types | `cd Ore/sdk && npm run generate` (automatic) |
| Building UI | `Omny/omnigrams/src/pages/*.tsx` + `Ore/ui/src/**/*.tsx` |
| Adding a component | `Ore/ui/src/lib/{atoms\|components\|layout}/*.tsx` |
| Editor features | `Ore/editor/src/*.ts` + `Omny/omnidaemon/.../editor_mod.rs` |
| Glass/Crystal effects | `Ore/crystal/src/*.ts` |
| Theme/tokens | `Ore/ui/src/lib/theme/` + Regalia crate |

---

## Key Config Files

| File | What |
|------|------|
| `~/.omnidea/daemon.config.toml` | Daemon configuration |
| `~/.omnidea/auth.token` | IPC authentication (32-byte hex, 0600) |
| `~/.omnidea/daemon.sock` | Unix socket for IPC |
| `~/.omnidea/daemon.pid` | PID file |
| `~/.omnidea/vault.db` | Encrypted SQLCipher database |
| `~/.omnidea/daemon.log` | Daemon log (when daemonized) |

---

## Known Gotchas

1. **x::Value serde** — wraps each variant in `{"string": "hello"}`. Must unwrap in api_json.rs for TypeScript.
2. **Bridge type mismatch** — SDK `bridge.ts` declares `run(PipelineRequest)` (object) but WebIDL and fetch bridges expect JSON string. SDK `ops.ts` passes objects. Omnigrams bridge correctly uses strings. Always stringify when calling `window.omninet.run()` directly.
3. **Lock ordering** — sessions → vault. Never vault → sessions. (ABBA deadlock, session 156.)
4. **Field name mismatches** — TypeScript and Rust can disagree on field names silently. The #1 source of bugs. Always check api_json.rs.
5. **Equipment uses raw bytes** — Phone/Email transport `&[u8]`, not JSON. Modules serialize/deserialize JSON themselves.
6. **Opaque pointers need cleanup** — every `divi_*_new()` must have a matching `divi_*_free()`. Leaks are silent.
7. **Async is rare** — only Globe (relay pool) is async. Everything else is sync. Globe holds `Arc<tokio::Runtime>`.

---

*Last updated: Session 160 audit (2026-03-26)*
