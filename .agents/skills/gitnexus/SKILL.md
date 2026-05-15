---
name: gitnexus
description: Use when exploring smart-air code, checking impact before symbol edits, tracing bugs, or validating changed execution flows with GitNexus.
---

# GitNexus

Use GitNexus for code intelligence in this repository.

## Start

Check index freshness from the repository root:

```bash
rtk proxy npx gitnexus status
```

If stale, refresh:

```bash
rtk proxy npx gitnexus analyze
```

## Explore

Find process-grouped execution flows:

```bash
rtk proxy npx gitnexus query "concept"
```

Get symbol context:

```bash
rtk proxy npx gitnexus context SymbolName
```

## Impact

Before editing a function, method, class, provider, route handler, service, job,
or firmware module symbol, run:

```bash
rtk proxy npx gitnexus impact SymbolName --direction upstream
```

Report the blast radius before editing:

- direct callers
- affected processes
- risk level

Warn before proceeding if risk is HIGH or CRITICAL.

## Changed Scope

Before committing, verify changed symbols and execution flows:

```bash
rtk proxy npx gitnexus detect-changes
```

If the CLI subcommand is unavailable in the installed GitNexus version, use the
MCP `gitnexus_detect_changes()` tool when available.
