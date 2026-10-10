# ClaudeNotch

macOS menu bar + MacBook notch app that shows Claude Code session (5h) and weekly usage limits.

- Limits: `GET https://api.anthropic.com/api/oauth/usage`, using the OAuth token Claude Code keeps in the keychain (`Claude Code-credentials`).
- Local token counts: parsed from `~/.claude/projects/**/*.jsonl`.

## Build

Requires macOS 14+ and Xcode Command Line Tools.

```sh
./build.sh            # builds build/ClaudeNotch.app
./build.sh --install  # also installs to ~/Applications and launches it
```
