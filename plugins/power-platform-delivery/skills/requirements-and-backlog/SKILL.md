---
name: requirements-and-backlog
description: Turns a business need into an implementation-ready backlog. Runs discovery on objectives, scope, assumptions, risks and non-functional needs, then breaks the work into epics, features and vertical-slice user stories with testable acceptance criteria, checked against INVEST and a readiness checklist. Use when gathering, refining, splitting, prioritising or reviewing requirements.
---

# Requirements and backlog

Intended for `product-analyst`, but usable by anyone. Load `power-platform-standards` first. Read and write work items with `azure-boards`. Turn acceptance criteria into scenarios with `bdd-scenarios`.

| Reference | Load it when |
| --- | --- |
| [discovery.md](references/discovery.md) | Exploring a new or unclear need: the questions to ask, the non-functional prompts and the discovery output |
| [backlog.md](references/backlog.md) | Breaking work into epics, features and stories, splitting a story or writing acceptance criteria |
| [readiness.md](references/readiness.md) | Checking a story against INVEST and the readiness checklist, or prioritising and sequencing |

## Principles

- **Problem before solution.** Understand the outcome and who needs it before discussing how. Challenge a request that arrives as a solution.
- **Facts, not invention.** Label what you know as confirmed, assumed or unknown. Don't invent rules, data, users or numbers. Ask, or record an open question.
- **Traceable.** Every story traces to a feature, an epic and a business objective. Flag an orphan rather than guess its parent.
- **Vertical slices.** Each story delivers something a user can see or use, end to end. Never split by technical layer.
- **Testable.** Every acceptance criterion has an observable outcome that passes or fails.
- **Non-functional needs count.** Capture them alongside the functional ones, using the prompts in [discovery.md](references/discovery.md).
- **Proportionate.** Match the depth to the size and risk of the work. A small change doesn't need a full discovery.

## Procedure

1. **Gather context.** Read the work item, its parent, its children and its linked items through `azure-boards`. Look for existing items that cover the same need. Read any documents the user points to.
2. **Discover.** If the need is new or unclear, work through [discovery.md](references/discovery.md). Ask the questions that matter for this need, not the whole list.
3. **Break down.** Shape the work into epics, features and stories as [backlog.md](references/backlog.md) describes.
4. **Write the stories.** Use the story and acceptance criteria format in [backlog.md](references/backlog.md).
5. **Check readiness.** Check each story against [readiness.md](references/readiness.md). Fix what you can, and list what needs someone else's answer.
6. **Sequence and prioritise.** Suggest an order and say why. The product owner decides the priority.
7. **Confirm, then record.** Present the result for review. Create or update work items through `azure-boards`, and only when the user asks or confirms.

## Output

For discovery, use the headings in [discovery.md](references/discovery.md). For a breakdown, use the headings in [backlog.md](references/backlog.md). For a review of an existing item, report:

- **Summary**: what the item asks for and whether it's ready.
- **Readiness**: each failed check, with the fix.
- **Suggested changes**: a rewritten title, story or acceptance criteria.
- **Open questions**: each with the person who needs to answer it.

Write "None identified" under a heading rather than leave it out.
