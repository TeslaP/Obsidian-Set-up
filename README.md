# Setup

Portable setup for Obsidian vault structure and custom Claude Code skills. Clone the repo and run the bootstrap to get a new machine ready.

## Quick start

```bash
git clone git@gitlab.com:booking-com/personal/pasha.teslenko/my-project.git
cd my-project/setup
./bootstrap.sh
```

Override the vault path if it's not `~/notes.md`:

```bash
VAULT_PATH=~/my-vault ./bootstrap.sh
```

## What it installs

**Obsidian vault structure:**
* Folder skeleton: Decisions, Inbox, Notes/Meetings, People, Summaries, Weekly updates, Bi-weekly updates
* `.obsidian/` config: core plugins, community plugins (dataview), graph settings
* Templates: `_template.md` for Decisions and People

**Claude Code skills:**
* `meeting-summary` -- summarizes Zoom transcripts into structured Obsidian notes
* `weekly-update` -- generates weekly status updates from Jira tickets + meeting context

## What it does NOT include

* Actual notes, summaries, people, decisions (your data)
* Meeting recordings or transcripts
* Claude Code auth/env settings (machine-specific)

## After bootstrap

1. Open Obsidian and point it at the vault directory
2. Route Zoom recordings to `<vault>/Notes/Meetings/` (see bootstrap output)
3. Optionally set up vault git backup (see `scripts/vault-backup.sh`)
