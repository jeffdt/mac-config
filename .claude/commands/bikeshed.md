---
description: Structured naming review with alternatives and a recommendation
argument-hint: [name]
---

Pause the current design conversation and review naming decisions.

If an argument is provided, focus on that specific name: **$ARGUMENTS**

If no argument is provided (or the argument is empty), scan the recent conversation for all naming decisions (commands, flags, config keys, functions, components, variables, etc.) and review them as a set.

## Process

### 1. Identify names and context

Collect the name(s) to review. For each name, note:
- What the thing actually does (its behavior, not its label)
- What ecosystem it lives in (CLI tool, REST API, React component, Terraform module, etc.)
- What sibling names exist in the same project or command family

### 2. Generate alternatives

For each name, produce 5-8 candidates including the current name. Source alternatives from:
- Domain conventions (git uses "prune", "stash"; REST uses "create", "update"; React uses "useX")
- Plain-English synonyms and verb/noun variations
- Existing terminology in the ecosystem the tool lives in

Do not reach for clever or thematic options unless the project already uses that register.

### 3. Evaluate against five dimensions

For each candidate, assess:

- **Connotation accuracy** — Does the word's natural meaning match what the thing actually does? A name that implies the wrong mental model is worse than a boring name. Example: "force" suggesting "suppress confirmation" when the real behavior is "switch from dry-run to execute."

- **Domain conventions** — Does it feel native to its ecosystem, or imported from another one? Names should match the conventions users already know from the tools around them.

- **Sibling consistency** — Does it fit the naming register of its neighbors? If siblings use a metaphor (doctor, hospital), a literal name breaks the pattern. But forcing a metaphor where it does not extend naturally is worse than breaking the pattern.

- **Ambiguity risk** — Could someone reasonably misinterpret what this means? Would a new user guess its purpose correctly on first encounter?

- **Mouth feel** — Is it easy to type, say aloud, and tab-complete? Does it scan well in help text? Short, common words beat long or unusual ones.

### 4. Recommend

Pick a winner. Explain which dimensions tipped the decision and why. If the current name already scores well on all dimensions, say so and do not manufacture alternatives just for the sake of it.

## Output style

Conversational, not a formal report. For a single name: brief analysis, alternatives with notes on each, then the recommendation. For a batch: group related names, flag any cross-name consistency issues, then walk through each.
