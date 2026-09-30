---
name: weekly-update
description: "Generate weekly update notes from Jira and Obsidian. Use when the user types /weekly-update or wants to create a structured weekly status update per Jira ticket. Triggers on: 'weekly update', 'generate my weekly', 'write my weekly update', 'create week update', or /weekly-update. Run fully automatically, no manual input needed."
metadata:
  tags:
    - productivity
    - jira
    - obsidian
  author: pteslenko
  version: "1.1.0"
  compatibility: macos
---

# Weekly Update Generator

## What this skill does

Fetches all "In Progress" Jira tickets from the CPEXP project assigned to the current user, combines them with this week's Obsidian meeting summaries as background context, and generates one polished Markdown weekly update note per ticket, saved directly into the Obsidian vault. Fully automatic, no user input needed.

## When to Use

- User types `/weekly-update`
- User says "generate my weekly update", "write up my weekly", "create week update notes"

## When NOT to Use

- User wants a bi-weekly or monthly update
- User wants to update a specific past week (not the current one)

## Vault path

`~/notes.md` is a directory despite the `.md` extension.

---

## Steps

### 1. Determine current week

Run this Python snippet to get week metadata:

```bash
python3 -c "
from datetime import date
d = date.today()
iso = d.isocalendar()
wk = iso[1]
yr = iso[0]
mon = date.fromisocalendar(yr, wk, 1)
sun = date.fromisocalendar(yr, wk, 7)
mon_fmt = mon.strftime('%B %-d')
sun_fmt = sun.strftime('%B %-d')
print(f'WEEK={wk:02d}')
print(f'YEAR={yr}')
print(f'HEADER=Week {wk} ({mon_fmt} – {sun_fmt})')
print(f'ISO_TAG={yr}-W{wk:02d}')
"
```

Extract:
- `WEEK`: zero-padded week number, e.g. `29`
- `YEAR`: four-digit year, e.g. `2026`
- `HEADER`: note header string, e.g. `Week 29 (July 13 – July 19)`
- `ISO_TAG`: Obsidian frontmatter tag, e.g. `2026-W29`

### 2. Load Obsidian background context

Scan `~/notes.md/Summaries/` for `.md` files with `week: <ISO_TAG>` in their frontmatter.

```bash
grep -rl "week: <ISO_TAG>" ~/notes.md/Summaries/ 2>/dev/null
```

Read the body of all matching files. This content becomes background context for every ticket update; do not attribute it to a specific ticket, just use it to inform the writing.

If no summaries exist for this week, proceed without them.

### 3. Create output folder

```bash
mkdir -p ~/notes.md/Weekly\ Updates/WK<WEEK>\ -\ <YEAR>/
```

Example: `~/notes.md/Weekly Updates/WK29 - 2026/`

### 4. Fetch Jira tickets

The Atlassian MCP tools are not directly available as Claude Code tool calls. Call them via the `bk genai:mcp:toolbox` JSON-RPC subprocess instead.

Run this Node.js script to get the current user's `accountId` and fetch In Progress tickets in one session:

```javascript
node -e "
const { spawn } = require('child_process');
const proc = spawn('bk', ['genai:mcp:toolbox'], { stdio: ['pipe', 'pipe', 'pipe'] });

let buf = '';
const pending = {};
proc.stdout.on('data', (data) => {
  buf += data.toString();
  const lines = buf.split('\n');
  buf = lines.pop();
  for (const line of lines) {
    if (!line.trim()) continue;
    try {
      const msg = JSON.parse(line);
      if (msg.id && pending[msg.id]) { pending[msg.id](msg); delete pending[msg.id]; }
    } catch {}
  }
});

let nextId = 1;
function call(method, params) {
  return new Promise((resolve) => {
    const id = nextId++;
    pending[id] = resolve;
    proc.stdin.write(JSON.stringify({ jsonrpc: '2.0', id, method, params }) + '\n');
  });
}
function toolCall(name, args) { return call('tools/call', { name, arguments: args }); }

(async () => {
  await call('initialize', {
    protocolVersion: '2024-11-05',
    capabilities: {},
    clientInfo: { name: 'weekly-update', version: '1.0' }
  });

  const userResp = await toolCall('atlassian_get_current_user', { cloudId: 'booking.atlassian.net' });
  const user = JSON.parse(userResp.result.content[0].text);
  const accountId = user.accountId;

  const searchResp = await toolCall('atlassian_searchJiraIssuesUsingJql', {
    cloudId: 'booking.atlassian.net',
    jql: \`project = CPEXP AND status = \"In Progress\" AND assignee = \"\${accountId}\"\`,
    fields: ['summary', 'description', 'comment', 'status', 'issuetype'],
    limit: 20
  });

  process.stdout.write(searchResp.result.content[0].text + '\n');
  proc.kill();
})().catch(e => { console.error(e.message); proc.kill(); });
"
```

Parse the JSON output. For each issue, `fields.comment.comments` contains the comments array; take the **last 2 entries** (highest index).

### 5. Generate one note per ticket

For each ticket, write a note to:
```
~/notes.md/Weekly Updates/WK<WEEK> - <YEAR>/WK<WEEK> <Ticket Summary Title>.md
```

Sanitize the ticket title for use as a filename: replace `/`, `:`, `?`, `*`, `"`, `<`, `>`, `|`, `\` with a space or dash. Keep it readable.

**Content generation rules:**

You are the author of this weekly update. Combine:
- **Primary source**: Jira ticket description + last 2 comments
- **Background context**: this week's Obsidian meeting summaries (already loaded in step 2)

Write the update following these rules:
- Do not invent facts not present in the source material
- Do not use em dashes in any text
- Do not include section headings that have no supporting content; omit them
- Write in clear, direct business English: concise, stakeholder-friendly, confident
- Use `*` for all bullets
- Keep inline links that appear in the Jira content
- The final section is always `### Next Steps`; include only if there is supporting content
- Derive 2–4 section headings dynamically from the ticket content (e.g., what was built, key decisions, blockers, integrations tested)
- Do not add commentary, preamble, or metadata outside the Markdown

**Output format:**

```markdown
## <HEADER>

### <Section derived from content>
* ...
* ...

### <Section derived from content>
* ...
* ...

### Next Steps
* ...
* ...
```

### 6. Confirm to user

After all notes are written, print:

```
Done. Generated N weekly update(s) for WK<WEEK> - <YEAR>:
  ✓ WK<WEEK> <Ticket Title 1>.md
  ✓ WK<WEEK> <Ticket Title 2>.md

Saved to: ~/notes.md/Weekly Updates/WK<WEEK> - <YEAR>/
```

If no In Progress tickets were found, say: "No In Progress CPEXP tickets found for your account. Nothing to write."

### 6b. Weekly decisions digest

After the ticket update confirmation, surface all decisions made this week.

1. Scan `~/notes.md/Decisions/*.md` for files where the `date:` frontmatter value falls within the current week (Monday through Sunday of the week determined in step 1).

```bash
for f in ~/notes.md/Decisions/*.md; do
  d=$(grep "^date:" "$f" 2>/dev/null | head -1 | sed 's/date: *//')
  echo "$d $f"
done
```

Filter to dates between Monday and Sunday of the current week.

2. If any found, print after the ticket confirmation:

```
Decisions made this week:
  - <date> <decision title> (from <source summary>)
  - <date> <decision title> (from <source summary>)
```

Read the `## Source` section of each decision to get the source summary name.

3. If none found, skip silently (print nothing).

**Constraints:**
* Read-only: do not create or modify any Decision files
* This is informational output only, not written to a file

---

## Gotchas

- **`~/notes.md` is a directory**: despite the `.md` extension, the vault root is a folder on macOS. Always treat it as a directory path.
- **Atlassian MCP via toolbox only**: the `atlassian_*` tools are not available as direct Claude Code tool calls. They must be invoked via the `bk genai:mcp:toolbox` JSON-RPC subprocess (see step 4). The toolbox reads credentials from `~/.bkcloud/genai-config.json` automatically; no manual auth setup needed.
- **Toolbox requires `bk` CLI**: `bk` must be in PATH (`which bk` → `/usr/local/bin/bk`). If it's missing, the Node.js subprocess call will fail immediately.
- **Jira `comment` field**: comments are in `fields.comment.comments`. Take the last 2 by index. If `comments` is empty, skip; the description alone is the source.
- **Filename sanitization**: Jira ticket titles often contain `/` or `:`. Strip or replace these before using as a filename; macOS disallows `/` in filenames.
- **macOS `%-d`**: removes zero-padding from day numbers (e.g., `July 7` not `July 07`). This is BSD/macOS-specific; the Python snippet handles it.
- **Empty week**: if the CPEXP board has no In Progress tickets, stop gracefully without creating any files or folders.

## Example prompts

**Triggers (should invoke this skill):**
- `/weekly-update`
- "Generate my weekly update"
- "Write up my weekly"
- "Create my week 29 update"
- "Weekly status notes from Jira"

**Non-triggers (should NOT invoke this skill):**
- "Summarize my meeting" → use `meeting-summary`
- "What's on my Jira board?"
- "Write a bi-weekly update"
- "Create a monthly report"
