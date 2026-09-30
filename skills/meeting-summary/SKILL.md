---
name: meeting-summary
description: "Use when the user has finished a meeting and wants structured notes saved to Obsidian. Triggers on: 'summarize my meeting', 'meeting notes', 'write up today's call', 'write up that 1:1', or /meeting-summary. Use this whenever a meeting transcript exists, even if the user doesn't say 'Obsidian' explicitly."
metadata:
  tags:
    - productivity
    - meetings
    - obsidian
  author: pteslenko
  version: "1.8.0"
  compatibility: macos
---

# Meeting Summary

## When to Use

- Right after a Zoom meeting ends and a transcript file is present
- User says "summarize my meeting", "write up that call", "meeting notes from today", or similar
- User invokes `/meeting-summary` directly, with or without a transcript path
- User wants to backfill all unsummarized meetings: "summarize all meetings", "catch up on all transcripts", "which meetings don't have summaries", `/meeting-summary all`

## When NOT to Use

- No transcript file exists (meeting wasn't recorded or transcribed)
- Non-Zoom transcript format (different speaker/timestamp layout)
- User wants real-time in-meeting notes (no transcript yet)

## Setup

### 1. Point Zoom to your Obsidian vault

Zoom saves each meeting as a subfolder (transcript included) wherever local recordings are stored. Route them straight into the vault:

1. Open **Zoom → Settings → Recording**
2. Under **Local Recording**, click **Change** and set the path to `$VAULT_PATH/Notes/Meetings/`
3. Enable **"Create audio transcript"** (checkbox in the same section)

After the meeting ends Zoom will create:
```
$VAULT_PATH/Notes/Meetings/
└── YYYY-MM-DD HH.MM.SS <Meeting Name>/
    ├── <Meeting Name>  transcript_<id>.txt   ← what this skill reads
    └── <Meeting Name>.mp4                    ← recording (ignored)
```

Note the **double space** before "transcript": that's Zoom's default naming. The skill handles it; avoid renaming these files.

### 2. Obsidian vault structure

```
$VAULT_PATH/
├── Notes/
│   └── Meetings/          ← Zoom saves here (set above)
│       └── 2026-07-14 14.54.45 Weekly Sync/
│           └── Weekly Sync  transcript_....txt
└── Summaries/             ← skill writes one .md per meeting here
    └── 2026-07-14 14.54.45 Weekly Sync.md
```

**For best Obsidian experience:**

- Install **Dataview** to query all summaries by week or tag:
  ```dataview
  TABLE date, week FROM "Summaries"
  WHERE type = "meeting-summary"
  SORT date DESC
  ```
- The `source` frontmatter field in each summary auto-links back to the raw transcript file
- `week: YYYY-WNN` lets you pull all meetings from a sprint in one query, e.g. `WHERE week = "2026-W29"`

## Vault path

Default: `~/notes.md`. Override with `VAULT_PATH` env var if the vault is elsewhere.

```
$VAULT_PATH/
├── Notes/Meetings/    ← transcripts (input)
└── Summaries/         ← one .md per meeting (output)
```

## Steps

### 0. Detect mode

Check if `args` equals `all`, or if the user's message contains "all", "backfill", "catch up", "unsummarized", or "missing":

- **Batch mode** → follow [Batch Mode](#batch-mode) steps below instead of steps 1–5.
- **Single mode** → continue with step 1.

---

## Batch Mode

Run this when the user wants to summarize all meetings that don't have a summary yet.

### B1. Enumerate transcript folders

List all entries in `$VAULT_PATH/Notes/Meetings/`. For each entry that is a **directory** (not a loose `.txt` file), record the folder name.

```bash
ls -1 "$VAULT_PATH/Notes/Meetings/"
```

Filter to only directories:
```bash
find "$VAULT_PATH/Notes/Meetings/" -mindepth 1 -maxdepth 1 -type d
```

### B2. Enumerate existing summaries

List all `.md` files in `$VAULT_PATH/Summaries/`, stripping the `.md` extension to get bare folder names.

```bash
ls -1 "$VAULT_PATH/Summaries/" | sed 's/\.md$//'
```

### B3. Diff: find unsummarized folders

For each transcript folder from B1, check whether `$VAULT_PATH/Summaries/<folder name>.md` exists. Collect all folders where it does **not** exist.

Print a summary to the user:
```
Found N transcript folders. X already summarized. Y need summaries:
  - 2026-07-10 10.33.15 Gen AI _ Smart Search Weekly
  - 2026-07-13 13.19.05 Smart Search - tracking
  ...
```

If Y = 0, tell the user "All transcripts already have summaries." and stop.

### B4. Process each unsummarized folder, in chronological order

Sort the unsummarized folders by date (ascending). For each one, run steps 1–6 from Single Mode (find the transcript file, read it, summarize, select tags, write the `.md`, print Slack output).

After each summary is written, print:
```
✓ Summarized: <folder name>
```

### B5. Final report

After all are processed, print:
```
Done. Summarized Y meetings:
  - <folder name 1>
  - <folder name 2>
  ...
```

---

## Single Mode

### 1. Find the transcript

If `args` contains a file path, use that.

Otherwise: list all folders under `$VAULT_PATH/Notes/Meetings/`, pick the one with the most recent modification time, then find the file inside it that matches `*transcript*.txt`.

Extract:
- **folder name**: full folder name, e.g. `2026-07-14 14.54.45 Pasha _ Joanna 1o1`
- **meeting name**: strip the leading timestamp (`YYYY-MM-DD HH.MM.SS `), e.g. `Pasha _ Joanna 1o1`
- **meeting date**: the `YYYY-MM-DD` prefix
- **ISO week**: run `date -jf "%Y-%m-%d" "<meeting date>" "+%G-W%V"` → e.g. `2026-W29`

### 2. Read the transcript

Read the full transcript file.

### 3. Summarize: use this prompt verbatim

Generate the summary yourself. Replace `<TRANSCRIPT>` with the transcript text:

---

You are summarizing a meeting transcript into a concise, structured format.

Instructions:
- Output must have exactly 3 sections: TLDR, Agreements, Next steps
- Each section must contain 3–5 bullet points. Next steps can contain more but only if necessary.
- Each bullet must be max 150 characters
- Keep language clear, simple, and non-AI sounding
- Focus on decisions, alignment, and actions, not discussion details
- Avoid repetition across sections
- Use short, direct phrasing (no long sentences, no filler words)
- Always include names of people for the Agreements and next steps
- Do not include explanations outside the format
- Do not use em dashes in any text

Format:
## `TLDR`
- ...

## `Agreements`
- ...

## `Next steps`
- ...

Input:
<TRANSCRIPT>

---

### 4. Select contextual tags

**Build the tag inventory:** extract all existing tags from every summary's frontmatter:

```bash
grep -h "^  - " "$VAULT_PATH/Summaries/"*.md | sort -u | sed 's/^  - //'
```

Exclude `meeting-summary` from the selectable pool; it is always added automatically.

**Analyze the finished summary** (the output of step 3, not the raw transcript) for dominant topics. A topic is eligible if it accounts for ≥15% of the summary's bullet points/sentences.

**Select tags:** pick up to 4 tags from the inventory that match the identified topics. Prefer existing tags over creating new ones.

**Creating new tags (use sparingly):** only create a new tag when:
- Fewer than 2 existing tags match the summary content, AND
- There is a clearly dominant uncovered topic that isn't already named by any existing tag

New tags must use kebab-case (e.g., `content-governance`, not `ContentGovernance`).

**`meeting-summary` is always included and does not count toward the 4-tag limit.**

### 5. Write the Obsidian summary file

Output path: `$VAULT_PATH/Summaries/<folder name>.md`

```
---
type: meeting-summary
tags:
  - meeting-summary
  - <contextual-tag-1>
  - <contextual-tag-2>
  ...up to 4 contextual tags; omit if none qualify
source: "[[Meetings/<folder name>.txt]]"
date: <YYYY-MM-DD>
week: <YYYY-WNN>
---

# <meeting name>
*<YYYY-MM-DD>*

## `TLDR`
<TLDR bullets>

## `Agreements`
<Agreements bullets>

## `Next steps`
<Next steps bullets>
```

### 5b. Extract decisions

Scan the `## Agreements` section of the summary just written. For each bullet that contains signal words ("decided", "agreed", "will use", "chosen", "confirmed", "ruled out", "preferred", "approved"), extract a decision.

**For each candidate decision (max 5 per summary):**

1. **Normalize the title:**
   * Strip the bullet prefix (`- `, `* `)
   * Strip leading attribution: remove patterns like "Pasha and Joanna agreed", "Team agreed", "Both agreed", "[Name] confirmed" -- everything before the actual decision content
   * Strip trailing attribution: remove "; [Name] will...", "-- Pasha & Jessie", etc.
   * Convert to a noun phrase where possible, e.g., "Singular JSON schema for all response types" not "agreed to use a singular JSON schema"
   * Cap at 60 chars (not 80 -- shorter titles are better filenames)
   * Make filename-safe: replace `/`, `:`, `?`, `*`, `"`, `<`, `>`, `|` with spaces, collapse multiple spaces
   * If the cleaned title is under 15 chars, it's too vague -- skip it

2. **Dedup against existing decisions:**
   * List all files in `~/notes.md/Decisions/` (excluding `_template.md`)
   * For each existing decision, extract the title portion (everything after the date prefix)
   * Match if ANY of these are true (case-insensitive):
     * The new title is a substring of an existing title, or vice versa
     * The existing decision's `## Decision` body section contains the core noun phrase from the new title
     * 3+ significant words (excluding stop words: the, a, is, for, to, and, or, in, of, on, at, by, not) overlap between new and existing title
   * If a match is found, **do not create a new note**. Instead, check if the existing decision's `## Source` section already links to the current summary. If not, append the current summary as an additional source link. Report as "linked to existing".

3. **Create the note** (only if no dedup match) at `~/notes.md/Decisions/<meeting date> <decision title>.md`:

```yaml
---
type: decision
date: <meeting date YYYY-MM-DD>
status: active
project: <inferred from summary tags, first non-meeting-summary tag>
participants: <speaker names from transcript, as a YAML list>
tags:
  - decision
  - <project tag, same as above>
---
```

Body sections:
* `## Context` -- one sentence from the TLDR that relates to this decision
* `## Decision` -- the agreement bullet, cleaned up into a full sentence
* `## Source` -- wiki-link back to the summary: `[[Summaries/<folder name>]]`

Skip Rationale, Alternatives, and Consequences sections (the user fills those in later if needed).

4. **Report:**
```
Decisions:
  + <title> (new)
  ~ <title> → linked to existing: <existing filename> (added source)
  = <title> (already linked, skipped)
  - <title> (too vague, skipped)
```

If no decision signal words found in Agreements, skip silently (print nothing).

**Constraints:**
* Max 5 decisions per summary
* Never overwrite an existing Decision note's content -- only append source links
* Prefer linking to existing records over creating near-duplicates

### 5c. Detect and register people

**Tier 1: Transcript speakers (automatic)**

1. **Extract and normalize speaker names:**
   * Parse all `[Speaker Name]` lines from the transcript (already read in step 2)
   * Extract unique full names
   * **Normalize before matching:**
     * Collapse multiple spaces ("Joanna van  Beuzekom" -> "Joanna van Beuzekom")
     * Skip entries that are all-lowercase (e.g., "antonis", "fbeverdam") -- these are Zoom display name glitches, not real names
     * Skip entries that look like room/device names (contain digits, "AMS", "Room", "Conference", or are longer than 40 chars)
     * Skip "Pasha Teslenko" and "Pasha" (vault owner)

2. **Match against existing People notes:**
   * List all `.md` files in `~/notes.md/People/` (excluding `_template.md`)
   * For each speaker name, check for a match using this priority:
     1. Exact filename match (e.g., speaker "Steffanie Perton" matches `Steffanie Perton.md`)
     2. First name match (e.g., speaker "Nathan Rivera" matches `Nathan.md`)
     3. Partial name match (e.g., speaker "Antonis Karnavas" matches `Antonis.md`; speaker "Antonios Eleftherios Karnavas" matches `Antonis.md` because "Antonis" is a substring)
   * If a match is found at any level, **use the existing note** -- do not create a new one. Map this speaker to that note's filename for tagging purposes.

3. **For each speaker, either create or enrich:**

   **A) New person (no match in step 2):**
   * Search Slack: use the `slack_search_users` MCP tool with the full Zoom display name
   * If exactly 1 result: pull display_name, email, title/role, team from the Slack profile via `slack_read_user_profile`
   * If 0 or 2+ results: use just the Zoom display name, leave email/title/team blank
   * **Choose the filename:** Use the Slack display_name if available (it's the canonical form). Otherwise use the Zoom display name. If a first-name-only file would collide with an existing person, use the full name.
   * Create `~/notes.md/People/<chosen name>.md`:

```yaml
---
type: person
team: <from Slack, or blank>
role: <title from Slack, or blank>
email: <from Slack, or blank>
slack: <Slack user ID, or blank>
tags:
  - person
---
```

Body:
```markdown
# <Full Name>

## Role

<title from Slack, or "">

## Key context

Participant in <meeting name> on <date>.

## Recent interactions

\`\`\`dataview
LIST FROM "Summaries"
WHERE contains(file.content, "<first name>")
SORT date DESC
LIMIT 10
\`\`\`
```

   **B) Existing person with missing data (match found in step 2):**
   * Read the matched People note's frontmatter
   * If `email:` or `role:` are empty/blank, this note needs enrichment
   * Search Slack: `slack_search_users` with the full Zoom display name (same as new person flow)
   * If exactly 1 result: read their profile and fill in only the empty fields (`role:`, `email:`, `slack:`, `team:`)
   * Also update the `## Role` body section if it's empty and Slack returned a title
   * **Never overwrite fields that already have values** -- only fill blanks
   * If Slack returns 0 or 2+ results, leave the note unchanged
   * Report as "enriched" in the output

   **C) Add project tags to the person note (both new and existing):**
   * Collect the contextual tags from the current summary (the non-`meeting-summary` tags from step 4, e.g., `smart-search`, `rag-v3`)
   * Read the person note's existing tags list
   * Add any new tags that aren't already present (keep `person` first, then project tags alphabetically)
   * This builds up a tag profile over time: a person who appears in `smart-search`, `rag-v3`, and `support-agent` meetings will accumulate all three tags
   * Never remove existing tags -- only append new ones

4. **Tag the summary with participants:**
   * Re-read the summary file written in step 5
   * For each speaker (both existing and newly created), add their first name (lowercase) as a tag
   * Use the People note filename's first word as the tag, not the Zoom display name (avoids duplicates from Zoom name variants)
   * Write the file back

Example resulting frontmatter:
```yaml
tags:
  - meeting-summary
  - smart-search
  - steffanie
  - antonis
  - nathan
```

**Tier 2: Namedrops (flagged only)**

5. Scan the summary body for capitalized names that are not in the transcript speakers list and not common English words. Look for names near person-context words ("mentioned", "asked", "will", "should", "to meet", "from").

6. Print at the end (only if any found):
```
People mentioned but not in transcript (not auto-created):
  - Bogdan
  - Cecil
Add them manually if needed.
```

**Constraints:**
* Never overwrite existing People notes' content or non-empty fields -- only fill blanks
* Slack lookup: max 1 query per person (covers both new and enrichment paths; don't retry on ambiguous results)
* Person tags use first name lowercase only, derived from the People note filename
* The same person appearing with different Zoom display names across meetings should always resolve to the same People note

### 6. Confirm save

Tell the user: "Saved to `Summaries/<folder name>.md`. The file is ready to copy to Slack."

Then print the decisions report from step 5b (if any) and the people report from step 5c:

```
People:
  + <name> (new, from Slack: <role>)
  + <name> (new, no Slack match)
  ^ <name> (enriched: added role, email)
  = <name> (already complete)

People mentioned but not in transcript (not auto-created):
  - <name>
```

## Gotchas

- **Double space in transcript filename**: Zoom saves transcripts as `<Meeting Name>  transcript_....txt` (two spaces before "transcript"). The glob `*transcript*.txt` handles it, but direct string matching will fail.
- **`~/notes.md` is a directory**: despite the `.md` extension, the vault root is a folder on macOS. Shell tools that assume it's a file will error; always treat it as a directory path.
- **macOS-only `date` command**: `date -jf` is BSD/macOS-specific. On Linux, use `date -d` or the Python fallback: `python3 -c "from datetime import date; d=date.fromisoformat('YYYY-MM-DD'); print(f'{d.isocalendar()[0]}-W{d.isocalendar()[1]:02d}')"`
- **Mid-session registry**: a newly created skill won't be recognized by `/skill-name` invocation until the next Claude Code session. Run manually by invoking the skill body directly if needed.
- **Loose `.txt` files in Meetings/`: some transcripts are saved directly in `Notes/Meetings/` (not inside a subfolder). In batch mode, skip these loose files; they have no folder name to derive a summary path from. In single mode, if `args` points directly to one of these, derive the folder name from the filename itself (strip ` transcript_*.txt` suffix).

## Example prompts

**Triggers (should invoke this skill):**
- "Summarize my meeting"
- "Write up today's 1:1"
- "Meeting notes from this morning"
- `/meeting-summary`
- "Summarize all my meetings" → batch mode
- "Which meetings don't have summaries yet?" → batch mode
- "Catch up on all transcripts" → batch mode
- `/meeting-summary all` → batch mode

**Non-triggers (should NOT invoke this skill):**
- "What meetings do I have tomorrow?"
- "Create a meeting agenda"
- "Summarize this document"
