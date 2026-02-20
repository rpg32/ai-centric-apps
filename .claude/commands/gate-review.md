# Gate Review

Run the gate review for the current pipeline stage of the active AI-Centric Apps project.

## Workflow

### 1. Identify Context
- Read `projects/registry.json` to find active project
- Read `projects/{project-id}/project-state.json` to get current stage
- Identify the gate criteria for the current stage

### 2. Gate Criteria for Each Stage

See the Gate Review System section in `.claude/CLAUDE.md` for the complete gate criteria for all 7 stages.

### 3. Evaluate Each Criterion

For each gate criterion:
1. **Automated check** (if possible): Run the check and record pass/fail with evidence
2. **Manual check** (if automated not possible): Review the artifact and assess against the criterion
3. Record result as PASS, FAIL, or WARN

### 4. Generate Gate Review Report

Create `projects/{project-id}/{current-stage-dir}/gate-review.md`:

```markdown
# Gate Review: {stage-name}
**Project:** {project-name}
**Date:** {date}
**Reviewer:** Claude (AI-Centric Apps System)

## Results

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 1 | {criterion} | PASS/FAIL/WARN | {evidence} |
| ... | ... | ... | ... |

## Summary
- Passed: {count}
- Failed: {count}
- Warnings: {count}

## Decision
{PASS: Ready to advance / FAIL: Must address issues}

## Blocking Issues
{list if any}
```

### 5. Check Evolution Context

Before updating state, check if this stage is in evolution mode:

1. Read the stage's `evolution_context` from `project-state.json` (if present).
2. **Quick fix mode** (`quick_fix: true`): Reinterpret results:
   - FAIL -> still blocks (the fix must not break existing functionality)
   - WARN -> convert to PASS with note: "Accepted as WARN in quick fix mode"
   - Recalculate the overall decision with the reinterpreted results
3. **Work unit mode** (`work_unit` field present): Apply full criteria, but note in the report which criteria relate to the work unit scope vs. pre-existing state.
4. **Iteration mode** (`iteration` field present): Apply full criteria, same as initial pipeline.

### 6. Update Project State

If ALL criteria PASS (after evolution reinterpretation if applicable):
- Set current stage status to "completed"
- Remove `evolution_context` from the stage
- If this was the last stage in a work unit's `affected_stages` -> mark the work unit as ready for completion
- If this was the last reopened stage in an iteration -> mark the iteration as complete
- Advance `current_stage` to next stage ID (or next affected stage for work units)
- Add history entry: "Gate review passed for {stage}"

If ANY criterion FAILS:
- Stage remains active
- Add each failure to `issues` array with severity "blocking"
- Add history entry: "Gate review failed for {stage}: {failure count} issues"

**On failure -- propose iteration loop (initial pipeline only):**

If this is NOT an evolution pass (standard pipeline execution) and the gate fails, check `pipeline-definition.json` for matching iteration loops:

1. Read the `iteration_loops` array from the pipeline definition.
2. Match the current stage against `from_stage` in each loop.
3. For each matching loop, check if any of the failure reasons align with the loop's `trigger`.
4. If a match is found, propose it:

> "This gate failure matches a known iteration pattern:"
> **{loop description}**
> "Suggested: re-enter stage **{to_stage}** with this context:"
> {data_backward template from the loop}
>
> "Would you like to create a work unit to re-enter {to_stage}?"

If the user agrees, invoke the work unit command with pre-filled scope from the iteration loop.

### 7. Git Commit
In the PROJECT repo:
```
git add -A
git commit -m "Gate: {stage} review -- {PASS/FAIL}"
```

### 8. Report to User
Display the gate review results and next steps:
- If passed: congratulate, tell them the next stage, suggest the next command
- If passed in evolution mode: also report work unit/iteration progress (e.g., "2 of 3 affected stages complete")
- If failed: list each issue clearly, suggest what to fix, offer to help
- If failed with iteration loop match: present the loop proposal
