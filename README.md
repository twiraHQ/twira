<p align="center">
  <img src="https://twira.com/brand/icon-512.png" width="96" alt="Twira">
</p>

<h1 align="center">Twira</h1>

<p align="center">
  Coding power tools for AI agents. Deliver better code, faster and safer.
</p>

<p align="center">
  <a href="https://github.com/TwiraHQ/twira/releases"><img src="https://img.shields.io/github/v/release/TwiraHQ/twira?label=release" alt="Latest release"></a>
  <img src="https://img.shields.io/badge/platforms-macOS%20%7C%20Linux%20%7C%20Windows-blue" alt="macOS, Linux, Windows">
  <img src="https://img.shields.io/badge/licence-proprietary%2C%20free%20tier-lightgrey" alt="Proprietary, free tier">
</p>

<p align="center">
  <b>18 PowerTools</b> · <b>26 languages</b> · <b>65 deterministic detectors</b> ·
  <b>Wire-level PII redaction</b> · <b>Tamper-evident audit chain</b> ·
  <b>Works with every MCP agent</b>
</p>

<p align="center">
  <a href="#install">Install</a> ·
  <a href="#what-is-twira">What is Twira</a> ·
  <a href="#the-ai-compliance-proxy">AI Compliance Proxy</a> ·
  <a href="#the-toolbelt">The toolbelt</a> ·
  <a href="#free-vs-pro">Free vs Pro</a> ·
  <a href="#get-started">Get started</a> ·
  <a href="https://twira.com">twira.com</a>
</p>

---

## Install

```sh
# curl (macOS / Linux)
curl -fsSL https://twira.com/install.sh | sh

# npm
npm install -g @twira/cli

# Homebrew (macOS / Linux)
brew install twirahq/tap/twira
```

One binary, no runtime dependencies, on macOS, Linux and Windows. No signup,
no account, no card.

## What is Twira?

Twira is a single local binary that gives your AI coding agent deterministic,
indexed access to your codebase, so it reads real code instead of guessing.
Larger context windows didn't fix the hallucinations; deterministic tools did.
Your agent is the operator. Twira is the power tool beneath it. You stay in
control.

Indexed search across 26 languages. 65 deterministic detectors. Tamper-evident
audit chain. Works with Claude Code, Codex, Gemini, Cursor, and anything else
that speaks MCP.

Every tool is reachable two ways: your AI agent calls them over MCP, and you
call the same tools from your terminal. Deterministic, local-first,
cryptographic where it matters. Your source code never leaves your machine.

```json
{
  "mcpServers": {
    "Twira": {
      "command": "twira",
      "args": ["mcp"]
    }
  }
}
```

You never need to write that config by hand: `twira init` detects your agent
and wires it for you.

## The AI Compliance Proxy

The flagship. A wire-level proxy that sits between your AI agents and the
model providers they call, on your machine, so personal data and secrets are
redacted **before** they leave it:

```
 your AI agent ──▶  Twira proxy  ─────────────────▶  model provider
                    │ redact PII + secrets             sees placeholder
                    │ swap in the custodied API key    tokens, never the
                    │ sign + chain every call          real values
 you see normal ◀── restore real values  ◀──────────  response
 output
```

- **Redaction at the wire.** Around 50 text patterns plus deterministic
  person-name detection, structured Article 9 identifiers (health, politics,
  religion), API keys and secrets, and OCR-driven redaction inside images:
  faces blurred, personal text blacked out, EXIF stripped.
- **Reversible, invisibly.** Each value becomes a session-scoped token on the
  way out and is swapped back on the way home. Your workflow never notices;
  the provider never sees the real data.
- **Key custody.** Provider API keys are stored AES-256-GCM encrypted and
  injected at the wire. The agent never sees the key. Rotate centrally
  without touching every machine.
- **Signed receipts.** Every call is Ed25519-signed and Merkle-chained,
  verifiable offline. Per-session evidence in the dashboard shows exactly
  what was redacted, what token replaced it, and how often it was sent, and
  exports as a signed redaction certificate.
- **Compliance postures.** Hospital, Bank and Government floors enforce
  Strict; General maps to Standard; Dev to Lenient. GDPR purge removes
  mappings and bodies on request while keeping the chain proof intact.
- **Spend visibility.** Per-agent token usage across every provider, in one
  place.

Built for the rules teams actually face: GDPR and UK GDPR, the EU AI Act,
ISO/IEC 42001, the NIST AI Risk Management Framework, Singapore's Agentic AI
framework, and equivalent regimes worldwide.

## The toolbelt

Eighteen PowerTools. Each one a single command, deterministic and local.

### Look up code

| Tool | What it does |
|---|---|
| **Index** | Your codebase as a queryable knowledge graph: symbols, call graph, dependencies, references and optional embeddings across 26 languages, kept fresh on every commit. |
| **Code Search** | Find anything fast. Five modes in one interface: symbol, path, content, regex and semantic (vector + keyword + call-graph, fused). |
| **Code Read** | A symbol slice, a file overview, or the whole file, without burning tokens re-reading what the index already knows. |
| **Impact** | Know what would break before you ship: references, dependency direction and blast radius from the call graph, risk-rated. |
| **Database MCP** | Code and database on one interface. Maps every table, FK, index, view and RLS policy live across 6 engines; read-only queries; finds every place code touches a table across 17 ORM patterns. |

### Find bugs and risks

| Tool | What it does |
|---|---|
| **Diagnose (SAST)** | 65 deterministic detectors across 4 profiles, locally, in the millisecond range. Baselines, suppressions that survive renames and refactors, output as JSON or SARIF 2.1.0. |
| **Dependency Vulnerabilities (SCA)** | OSV-backed and reachability-filtered (installed AND imported, so the noise drops). Local cache means air-gapped runs still work. |
| **Risk** | Triage what changed: RED, YELLOW, GREEN per commit, at a glance. |

### Data protection and evidence

| Tool | What it does |
|---|---|
| **AI Compliance Proxy** | The wire-level redaction, custody and receipts engine described above. |
| **Audit** | A tamper-evident, cryptographically signed, append-only record of every meaningful action the agent takes. RFC 3161 time-stamped, verifiable offline. |

### Coordinate the work

| Tool | What it does |
|---|---|
| **Team** | Ask, review, brainstorm and debate across 10+ frontier models from 6+ providers, synthesised into one peer-reviewed answer. |
| **Code Review** | Type `/code-review` in your agent: multiple frontier models review the commit, each with a different lens. |
| **Plan Review** | Type `/plan-review`: multiple models review the implementation plan before any code gets written. |
| **Masterplan** | One shared task graph that every agent in every session works from. Atomic claims, no duplicated work. |
| **Relay** | Parallel agent sessions on the same repo without collisions, coordinated by file claims. |
| **Lore** | Institutional memory across agents: save the lesson once, and every future session checks it before touching the file. |
| **Port** | Cross-language migration with structural matching. Port a 200,000-line legacy codebase without losing a function. |

### Defensibility and ergonomics

| Tool | What it does |
|---|---|
| **Localhost Dashboard** | The visual control panel on 127.0.0.1: redaction evidence, sessions, spend, audit, toggles, instructions. |
| **Notifications** | Desktop toasts, a chime, optional spoken alerts when an agent finishes, asks, or needs permission. |

## Free vs Pro

**Free, for ever, personal use.** Index, Code Search and Code Read. No
signup, no email, no card.

**Pro, the full toolbelt.** $29.99/month with a 14-day trial, no card
required. Free for students who verify with an institutional email. Full
comparison at [twira.com/pricing](https://twira.com/pricing).

## Works with

26 languages · 6 database engines · 6+ AI providers · Claude Code, Codex,
Gemini CLI, Cursor and any MCP-compatible agent · macOS / Linux / Windows ·
air-gap capable.

## Get started

```sh
twira init       # set up Twira in your repo: wires your AI agent (MCP) and builds the index
twira login      # link this machine to your Twira account (Pro and trials)
twira dashboard  # open the local dashboard in your browser
```

From there your AI agent does the work. Ask it to search, read, check impact,
or diagnose, and it reaches for Twira's tools by itself.

## Links

- Website: https://twira.com
- Pricing: https://twira.com/pricing
- Contact: https://twira.com/contact
- Releases: https://github.com/TwiraHQ/twira/releases

---

Free for personal use, straight from install. Pro unlocks the full toolbelt
with a 14-day trial, no card required.
