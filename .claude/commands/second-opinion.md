---
description: Get independent verification of a conclusion from fresh subagent(s). Optional argument for count (e.g., /second-opinion 3)
---

You are about to get a second opinion on a conclusion or suggestion that was just reached. The goal is to mitigate non-determinism by having fresh agent(s) independently arrive at (or challenge) the same conclusion.

## Argument Handling

- If `$ARGUMENTS` is provided and is a number (e.g., "3"), spawn that many subagents in parallel
- If `$ARGUMENTS` is empty or not a number, spawn 1 subagent (default behavior)
- Maximum recommended: 5 agents (to avoid excessive resource usage)

## Critical Requirement: No Bias

The subagent MUST NOT receive any opinions, conclusions, or suggestions from this conversation. It should only receive:
- The original problem or question being investigated
- Relevant technical context (file names, technologies, APIs involved)
- A clear, objective prompt asking it to research and reach its own conclusion

## Step 1: Identify What Needs Verification

Review the conversation to find the most recent conclusion, suggestion, or recommendation that could benefit from independent verification. Look for:
- Technical decisions or recommendations
- Interpretations of documentation or API behavior
- Conclusions about how something works
- Suggestions for how to implement something
- Assertions about best practices or correct approaches

**If you cannot identify a clear conclusion to verify**, or if there are multiple candidates and it's unclear which one the user wants verified, use AskUserQuestionTool to ask:
- What specific conclusion or suggestion should be independently verified?
- Present the candidates as options if there are multiple

## Step 2: Craft an Unbiased Prompt

Create a prompt for the subagent that:

1. **Describes the original problem objectively** - What were we trying to figure out? What technical context is relevant?
2. **Asks a specific, answerable question** - Frame it as a research question, not a validation request
3. **Provides necessary context** - Technologies, versions, file paths, etc.
4. **Excludes ALL opinions from this conversation** - No hints about what conclusion was reached, no leading language

### Good Prompt Example
```
Research the Terraform AWS provider documentation for aws_instance user_data handling.

Specifically answer: When passing user_data to an aws_instance resource, does Terraform automatically base64 encode the value, or do you need to explicitly call base64encode() on the user_data string?

Look at official Terraform documentation or authoritative sources to answer this.
```

### Bad Prompt Example (DO NOT DO THIS)
```
We think Terraform auto-encodes user_data. Can you verify this is correct?
```

## Step 3: Launch the Subagent(s)

Use the Task tool with subagent_type="general-purpose" to launch independent research agent(s) with your unbiased prompt.

**If spawning multiple agents:**
- Launch ALL agents in parallel (single message with multiple Task tool calls)
- Each agent receives the identical unbiased prompt
- This tests whether different agents independently reach the same conclusion

Instruct each subagent to:
- Research the question using available tools (documentation, web search, code exploration)
- Provide a clear conclusion with supporting evidence
- Cite sources where possible

## Step 4: Compare and Report

Once all subagent(s) return:

**For single agent:**
1. Compare conclusions - Does the subagent agree or disagree with the original conclusion?
2. Highlight discrepancies - If there's disagreement, explain both perspectives
3. Assess confidence - Based on the evidence, which conclusion seems more reliable?
4. Recommend next steps - If there's conflict, suggest how to resolve it

**For multiple agents:**
1. Tally the results - How many agents reached each conclusion?
2. Report consensus or split - "3/3 agents concluded X" or "2/3 concluded X, 1/3 concluded Y"
3. Compare with original - Does the majority/consensus align with the original conclusion?
4. Surface interesting divergences - If any agent found something the others missed, highlight it
5. Assess overall confidence - Strong consensus increases confidence; split results suggest the question needs more investigation

## Begin Now

Review the conversation and identify what needs independent verification. If unclear, ask the user. Then craft an unbiased prompt and launch the subagent.
