# Contributing to Omnidea

Thank you for building with us. Here is how to get started.

---

## Building

Make sure you have Rust (cargo), Node.js (npm), and a C toolchain installed. Then:

```bash
git clone --recursive https://github.com/omnideaco/omnidea.git
cd omnidea
./build.sh
```

The build script checks for required tools, initializes submodules if needed, and builds everything in the correct order.

---

## Running Tests

Each repo has its own test suite:

```bash
# Omninet (protocol) -- 6,619 tests
cd Omninet && cargo test --workspace

# Ore (engine + libraries) -- TypeScript tests via vitest
cd Ore && npm test

# Omny (browser) -- omnidaemon Rust tests
cd Omny/omnidaemon && cargo test

# Omny (browser) -- omnigrams Vite build check
cd Omny/omnigrams && npm run build
```

All tests must pass before submitting a change.

---

## Code Style

### Rust
- Clippy clean, including tests: `cargo clippy --workspace --tests`
- No `print!()` or `println!()` -- use structured logging
- `#[serde(default)]` on new optional fields to preserve backward compatibility
- Never change an existing FFI function signature -- add a new one alongside it
- Every module has tests. Write them alongside the code.

### TypeScript
- Solid.js for reactive UI. No React patterns (no hooks, no JSX returning null).
- UnoCSS for styling. No Tailwind, no CSS-in-JS.
- Remix Icon for icons (`ri-{name}-{fill|line}`). No Font Awesome.

### General
- Equipment (Pact) for inter-module communication. No direct cross-crate imports.
- Ideas (.idea) as the universal content format.
- Regalia for design tokens. No hardcoded colors, spacing, or typography.

---

## Pull Requests

When submitting a PR:

1. **Describe what changed and why.** Not just "fixed bug" -- explain the root cause and the fix.
2. **Name which repo(s) are affected.** A change in Omny might need awareness of Omninet or Ore.
3. **Include test coverage.** New features need tests. Bug fixes need regression tests.
4. **Keep PRs focused.** One logical change per PR. If you found an unrelated issue, file it separately.

---

## The Covenant Governs

Every contribution to Omnidea is subject to the Covenant. This means your code must uphold Dignity, Sovereignty, and Consent. Contributions that enable surveillance, extraction, enclosure, or manipulation will not be accepted.

Read the [Covenant](Covenant/) if you have not already. It is the supreme law of this project.

---

## License

By contributing, you agree that your contributions are licensed under AGPL-3.0, governed by the Covenant. See [Omninet/LICENSE.md](Omninet/LICENSE.md).
