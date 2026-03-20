---
description: Research projects and collaborations with a colleague for peer feedback
---

# Peer Feedback Research

## Pre-computed Context

- Review year: !`date +%Y`

## Instructions

**Note:** Use the review year from pre-computed context for all date filters and file paths below.

1. Use **Glean Search** (mcp__glean_default__search) to find **$ARGUMENTS**'s major projects (whether or not Jeff DiTeodoro was involved) as well as direct collaborations with the user
2. Search queries to run (filter all searches to the **review year only** using `after:<YEAR>-01-01`):
   - **Collaborative work**: `$ARGUMENTS Jeff DiTeodoro project`
   - **Collaborative work**: `$ARGUMENTS collaboration` filtered by `from:me`
   - **Their major projects**: `$ARGUMENTS project` filtered by `owner:$ARGUMENTS`
   - **Their major projects**: `$ARGUMENTS RFC` or `$ARGUMENTS design doc`
   - **Their contributions**: `$ARGUMENTS` filtered by `from:$ARGUMENTS` in Confluence or Google Drive
3. Compile findings into the following categories:
   - **Major independent projects** (projects they led or owned, regardless of your involvement)
   - **Collaborative work** (projects you worked on together, with timelines, roles, and impact metrics)
   - Pairing sessions and technical mentorship
   - Code reviews and PR collaborations
   - Key outcomes and stakeholder feedback
4. Create a references file at:
   `Career/<YEAR>/Peer Feedback/$ARGUMENTS/References.md`
5. Include source links (Confluence, Linear, Google Drive, Slack) for all findings
6. Summarize the key collaborations after creating the file

## Follow-up Questions

If the user asks follow-up questions that cannot be answered from the search results already retrieved, use **Glean Chat** (mcp__glean_default__chat) to probe further. Chat is better for:
- Synthesizing information across multiple documents
- Answering specific questions about a project or collaboration
- Finding context that wasn't surfaced in keyword searches

## Output Format

The references file should include:
- Section headers for each major project
- Role descriptions for both parties
- Quantitative impact metrics where available
- Specific dates of collaboration (pairing sessions, reviews, etc.)
- Links to source documents
