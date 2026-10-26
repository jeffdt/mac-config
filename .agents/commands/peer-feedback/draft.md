---
description: Interactively draft peer feedback through reflective conversation
---

# Peer Feedback Draft

## Pre-computed Context

- Review year: !`date +%Y`

**Note:** Use the review year from pre-computed context for all file paths below.

## Determine Subject

**If `$ARGUMENTS` is provided**: Use that as the person's name.

**If no arguments provided**, infer the subject:
1. Check conversation context for a name we've been discussing (e.g., from recent research or drafting)
2. If not in context, list folders in `Career/<YEAR>/Peer Feedback/` that have `Draft *.md` files (work in progress)
3. If exactly one person has drafts in progress, confirm: "Continue working on feedback for [Name]?"
4. If multiple or none found, ask the user who they want to work on

Once the subject is determined, use their name wherever `$ARGUMENTS` appears below.

## Setup

**Context check**: Before reading files, check if you already have the following in context from earlier in this session. Only fetch what's missing:
- References for **$ARGUMENTS**
- Feedback template
- Company values
- Career architecture for their level

**If starting fresh or missing context**, read:
1. References file at `Career/<YEAR>/Peer Feedback/$ARGUMENTS/References.md`
2. Feedback template at `Career/<YEAR>/Peer Feedback/<YEAR> Peer Feedback - Template.md`
3. Company values at `Career/<YEAR>/Company Values.md`

**Always check for existing drafts**: Look for `Draft *.md` files in `Career/<YEAR>/Peer Feedback/$ARGUMENTS/`
- If drafts exist, find the highest numbered draft and read it
- Check for feedback in two places:
  - **Inline bold comments**: Text wrapped in `**bold**` within the draft content itself
  - **Draft Feedback section**: Comments under `# Draft Feedback` at the end
- **If feedback exists** (either inline or in section): Skip to **Revisions** workflow to create the next draft
- **If no feedback**: Ask if the user wants to continue refining or start fresh
- **If no drafts exist**: Proceed with **Conversation Approach** below

**Role and level** (skip if already known from context):
1. Determine the person's **track** and whether they are an **Individual Contributor (IC)** or **People Leader** from context, or ask if unclear
2. Read the appropriate career architecture files based on their track and level:

   **Engineering Individual Contributors:**
   - `Career/<YEAR>/Career arch - IC - L0-L3.csv` (Dev 1, Dev 2, Dev 3)
   - `Career/<YEAR>/Career arch - IC - L4-L5.csv` (Lead Engineer, Staff Engineer)

   **Engineering People Leaders:**
   - `Career/<YEAR>/Career arch - People Leader - L2-L3.csv` (EM, Senior EM)
   - `Career/<YEAR>/Career arch - People Leader - L4+.csv` (Director+)

   **Product Design:**
   - `Career/<YEAR>/Career arch - Product Design IC.csv` (L0-L7, Associate through Design Architect)

3. Confirm the person's role and level. If unclear from references, ask explicitly.

## Level Calibration

Use the career architecture to calibrate feedback:
- Identify whether they're performing **at**, **above**, or **below** their level in different dimensions
- When discussing strengths, note if they're demonstrating behaviors expected at a higher level
- When suggesting growth areas, reference specific expectations for their current or next level
- This context should inform the conversation and the final draft, but doesn't need to be explicit in the feedback itself

## Conversation Approach

Have a **free-flowing, reflective conversation** to surface authentic feedback. This is NOT a rigid questionnaire. The goal is to help the user reflect deeply on this person's performance and craft something meaningful.

**Guiding principles:**
- Reference their specific projects to jog memory ("Thinking back to their work on Project Zen...")
- Ask questions that prompt reflection beyond the obvious
- Clarify anything unclear about projects, their contributions, or their personality
- Explore different angles: technical skills, collaboration style, leadership, growth, communication
- Listen for themes and dig deeper when something interesting surfaces
- Don't just ask "what did they do well" - ask questions that reveal *how* they work and *why* it matters

**Example question styles (adapt freely, don't follow rigidly):**
- "When you were pairing on X, what was it like working with them?"
- "You mentioned they led Y - how did they handle the ambiguity/pressure/stakeholders?"
- "Was there a moment this year where they surprised you or exceeded expectations?"
- "What would be different about the team if they weren't on it?"
- "Is there something they do that you wish they did more of? Or less of?"
- "If you could give them one piece of advice for next year, what would it be?"

## Drafting

When you have enough context to craft a narrative:

1. Create a draft file at `Career/<YEAR>/Peer Feedback/$ARGUMENTS/Draft 1.md`
2. Write responses to both feedback questions that are:
   - **Two paragraphs max per question** - be concise
   - Specific and grounded in real examples
   - Authentic to the user's voice (not generic AI language)
   - Balanced - genuinely helpful constructive feedback, not just praise
   - Concise and direct, not flowery or performative
   - Free of em dashes and excessive hyphens
   - Avoid "mic-drop" closings or edgy phrasing that sounds like AI trying to land a point
3. End the draft with a `# Draft Feedback` section (empty) for general comments
4. Present the draft and let the user know they can add feedback in two ways:
   - **Inline**: Add `**bold comments**` directly next to the text they want changed
   - **General**: Add notes under `# Draft Feedback` for broader feedback

## Revisions

When the user indicates they've added feedback:
1. Read the current draft file and look for feedback in both places:
   - **Inline bold comments** (`**like this**`) within the draft text
   - **Draft Feedback section** at the end of the file
2. Create a new draft at `Career/<YEAR>/Peer Feedback/$ARGUMENTS/Draft N.md` (incrementing the version number)
3. Address all feedback (both inline and general) in the new version while preserving what worked
4. Remove the inline bold comments as you address them
5. Include a fresh empty `# Draft Feedback` section for further iteration

**Depth over breadth:**
- For strengths: Build a strong narrative around **one core strength** rather than lightly touching on 2-3. If multiple examples across different projects reinforce the same strength, use them to show it as a consistent throughline for their year. **Frame it through impact**: Don't just describe *how* they work—connect it to *what resulted*. The question asks about impact, so lead with the outcomes (what shipped, what improved, what was unblocked) and use the strength as the explanation for why they were able to achieve it.
- For growth: Give **specific, actionable feedback** - not vague suggestions. Name the behavior, explain why it matters, and suggest what "better" looks like. Generic advice like "communicate more" is not helpful; "When presenting technical decisions to stakeholders, leading with the business impact before diving into implementation details would help build alignment faster" is actionable.

**Company values:**
- Look for natural opportunities to connect the person's behavior to a company value
- Only include if there's a clear, genuine example—don't shoehorn it in
- When a value fits naturally, celebrate it as part of the narrative (e.g., "This is a great example of [value] in action")

## Questions to Answer

> 1. How did you see this Klaviyo create impact this year - through their work, collaboration, or leadership? Describe the specific strengths, skills, or behaviors that made a difference, and share examples of the results or outcomes you noticed.

> 2. Please share feedback that would help this Klaviyo strengthen their performance or increase their impact next year.
