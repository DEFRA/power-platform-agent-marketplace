# Readiness

## INVEST

| Check       | The story…                                                  | If it fails                                                          |
| ----------- | ----------------------------------------------------------- | -------------------------------------------------------------------- |
| Independent | Can be built and released without waiting for another story | Reorder or merge the stories, or record the dependency               |
| Negotiable  | States the need and leaves room for how to meet it          | Move the design detail to a note                                     |
| Valuable    | Delivers something a user or the organisation can see       | Merge it with the story it enables, or rewrite it around the outcome |
| Estimable   | Is clear enough for the team to size                        | Answer the open questions, or plan a time-boxed spike                |
| Small       | Fits in a sprint                                            | Split it, as [backlog.md](backlog.md) describes                      |
| Testable    | Has acceptance criteria that pass or fail                   | Rewrite the criteria                                                 |

## Readiness checklist

A story is ready when:

- it's linked to its parent feature, and the feature is linked to its epic;
- the title, story and acceptance criteria are complete, with no placeholders;
- the acceptance criteria cover failures and permissions as well as the main path;
- the non-functional needs that apply are stated;
- the business rules and data are confirmed rather than assumed;
- dependencies are identified and either resolved or scheduled;
- open questions are answered, or the product owner has accepted them as known risks;
- any architectural impact is identified, such as a new table, an integration, a security change or a change to another solution.

## Prioritising

Suggest priorities and say why. The product owner decides. Weigh:

| Factor           | Ask                                                                |
| ---------------- | ------------------------------------------------------------------ |
| Value            | How far does it move the business objective?                       |
| Risk reduction   | Does it test an uncertain assumption or a risky integration early? |
| Dependencies     | Is other work waiting for it?                                      |
| Time sensitivity | Is there a deadline, a legislation date or a seasonal peak?        |
| Cost of delay    | What's lost for each week it waits?                                |
| Effort           | Is it a quick win, or large for the value it brings?               |

## Sequencing

- Deliver a thin end-to-end slice first, then widen it.
- Schedule stories that unblock others, or that test risky assumptions, early.
- Show which stories can run in parallel and which must wait for others.
- Say what the order assumes, so the team can see when it needs to change.
