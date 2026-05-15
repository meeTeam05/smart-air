# Reference: Planning with Files Principles

## Filesystem as external memory

Use files as persistent working memory:

- context window is volatile
- files are durable
- important discoveries should be written down

## Read before deciding

After many tool calls, goals drift. Re-read the active plan before major decisions.

## Update after acting

After meaningful work:

- update `progress.md`
- update plan status
- record files changed

## Never repeat the same failed action

If an action fails:

- log it
- adjust the next attempt
- do not silently repeat the same thing

## Keep the plan close to the work

The plan should sit in the active `.planning` directory so the current repo state and the task state stay together.
