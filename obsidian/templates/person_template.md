---
type: person
team:
role:
email:
slack:
tags:
  - person
---

# Person Name

## Role

## Key context

## Recent interactions

```dataview
LIST FROM "Summaries"
WHERE contains(file.content, this.file.name)
SORT date DESC
LIMIT 10
```
