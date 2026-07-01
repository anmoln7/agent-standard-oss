---
module: seo
tags: [json-ld, firefox, hydration, structured-data]
problem_type: gotcha
date: 2026-06-28
---

## Problem
JSON-LD `<script type="application/ld+json">` blocks throw a console error in
Firefox and occasionally break hydration, while Chrome is fine.

## Cause
Firefox parses the inline script's text content more strictly; unescaped `<`, `>`,
or a stray `</script>` inside the JSON string terminates the block early.

## Fix
Serialize the JSON-LD with the dangerous characters escaped before injecting:
`JSON.stringify(data).replace(/</g, '\\u003c')`. Render via
`dangerouslySetInnerHTML` with the escaped string, not a template literal.

<!-- This is a template example. Delete it when seeding a real repo's docs/solutions/. -->
