# This fork

A Windows build of the Uncharted: The Nathan Drake Collection port, kept in step with
[Supermedo/uncharted_pc](https://github.com/Supermedo/uncharted_pc) (upstream) and carrying a
different launcher plus a few fixes that are not upstream.

Upstream base: **v0.3.15** (November 2026). Everything upstream ships for the engine is merged
here - crash and freeze fixes, the U3 sinking-character fix, early submit, the texture and
checkpoint fixes - except the items listed below.

## What this fork has on top of upstream

- **Launcher** (`launcher/uncharted_launcher.py`, the #168 lineage): frameless window, hero banner,
  pages for Play, Game, Cheats, Display, Controls, Saves, Trophies, Advanced and Log, seven UI
  languages, trophy lists, save backup, Xbox/keyboard button prompts, XeSS, 30 FPS, tray icon.
  Upstream's 0.3.10 launcher redesign and its Fixes page are not used; the values those toggles
  set are this fork's defaults (see `run.py`'s `per_game_defaults()`), and anything else can be set
  through Advanced -> Environment.
- **Artwork handling**: `art` files are looked up by stem with `.png/.jpg/.jpeg/.webp`, so PNG
  drops work under the `.jpg` names; uniform padding bands are trimmed; the library tiles share one
  size and shape (taken from the deepest cover) and each picture is fitted whole over a blurred
  copy of itself; the banner carries the picture and its logo wordmark only.
- **Per-game GPU read-back defaults** in `run.py`, with tests (`tests/test_run_defaults.py`), so an
  upstream sync cannot silently turn a fix off.
- **Red zone**: the link-time tables (#403) plus the runtime patch of #559, which covers builds
  without a table.

## Merging upstream

1. `git fetch upstream --tags`, read `git log <last>..upstream/main`, and the release notes.
2. One commit per upstream fix or PR: cherry-pick (or squash-merge a PR branch) with upstream's
   message and author; our own changes use `Area: sentence (#PR, author)`.
3. Resolve conflicts by keeping both sides' intent: take upstream's engine change, keep this fork's
   launcher structure, and re-read the comments (`run.py`, `probe.c`, `runtime_pad.c` are the usual
   files where upstream's context lines come from commits this fork does not carry).
4. Build, then smoke-test Uncharted 1 (EU dump) - and U2/U3 when their read-backs or patches
   changed. `grep -n 'Fault\|ASSERT'` in the run log; close the window instead of killing it, so
   the exit path is exercised.
5. Run `python -m unittest discover -s tests -q` (green), then bump `VERSION` in the launcher to the
   upstream release the tree is based on.

## Building and running

```
# MSYS2 CLANG64 shell
bash build.sh                                   # out/bb-probe.exe
python launcher/uncharted_launcher.py           # the launcher
BB_GAME_DIR=<dump with eboot.bin> python run.py  # the game without the launcher
```

Saves, shader caches, `crash.dmp` and `last_run.log` live under `user/`; the prepared game image
under `out/`. Artwork is in `launcher/art` (tracked here) or in `art` next to `Uncharted.exe` in a
packaged build.

## Tests

`python -m unittest discover -s tests -q` is green on Windows. Suites that drive the Linux
`run.sh` and the AppImage driver discovery are skipped on Windows, and the symlink tests skip when
the OS does not allow creating links (Windows needs Developer Mode). `.github/workflows/tests.yml`
runs the suite on windows-latest and ubuntu-latest; it needs Actions enabled for the repository
(Settings -> Actions -> General).

## Not carried

- Low latency mode (NVIDIA Reflex / AMD Anti-Lag 2) - upstream 0.3.14.
- PGO builds - upstream 0.3.14; this fork builds with `-O2` and LTO off by default.
- U2 Chapter Select weapon sets, the audio fallback chain and skipping the friends'-stats notice -
  upstream 0.3.14/0.3.15.
