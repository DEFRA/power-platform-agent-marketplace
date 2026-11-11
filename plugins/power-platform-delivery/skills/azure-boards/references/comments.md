# Comments and rich-text fields

Azure Boards stores comments, descriptions and acceptance criteria as HTML. It doesn't render Markdown, so `**bold**` shows as asterisks.

## Rules

- Build the whole value on one line (see [cli.md](cli.md) for why).
- Start a comment with an `<h3>` title that says what it is, such as "Architecture review". Use `<h4>` for sections.
- Use one `<p>` per point, `<b>` for a label at the start of a paragraph, `<ul><li>` for a list and `<br>` for a line break.
- Write acceptance criteria as an `<ol>` with one `<li>` per criterion, so they can be referred to by number.
- Put what the reader must do or decide first.
- Refer to another work item as `#<id>`. Azure Boards turns it into a link.
- Don't use a literal `&` (see [cli.md](cli.md)).
- Keep it short. Point to a document in the repository rather than pasting it.

## Example

An architecture review comment, wrapped here so it's easier to read. Send it as one line.

```html
<h3>Architecture review</h3>
<p><b>Outcome:</b> fits an existing pattern (level 1), low complexity.</p>
<h4>Recommendation</h4>
<p>Record the outcome as a choice column on the inspection, set by a real-time workflow, as ADR 0003 describes.</p>
<h4>Actions</h4>
<ul><li><b>Product analyst:</b> confirm whether a failed inspection reopens the case.</li></ul>
<p><b>Design:</b> committed to the work item branch with this review.</p>
```
