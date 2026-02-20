# Pipeline Stage: Domain and Intent Scoping

Execute stage **01-scoping -- Domain and Intent Scoping** of the AI-Centric Apps pipeline.

## Pre-Checks

1. **Verify active project**: Read `projects/registry.json` to identify the active project. If ambiguous, ask the user.
2. **Verify correct stage**: Read `projects/{project-id}/project-state.json`. Confirm `current_stage` matches `01-scoping`. If not:
   - If the project is on an EARLIER stage -> warn that this stage hasn't been reached yet
   - If the project is on a LATER stage -> warn that this stage is already completed
   - Ask user if they want to proceed anyway (re-work scenario)
3. **Detect evolution mode**: Check if stage `01-scoping` has `status: "evolution"` or `status: "quick-fix"` in project-state.json. If so, read the `evolution_context` object and switch to evolution mode (see Evolution Mode section below).
4. **Check for blocking issues**: Review the `issues` array for any blocking items related to this stage.
5. **Check inbox**: Scan `comms/inbox/` for pending messages relevant to this stage.
6. **Check for existing partial work**: Scan `projects/{project-id}/01-scoping/` for existing artifacts. If output files already exist from a prior run or checkpoint, offer to continue from where the previous run left off rather than starting over.

## Dispatch

Delegate this stage to the **scoping-agent** subagent with the following context:

- **Project**: {project-id} at projects/{project-id}/
- **Working directory**: projects/{project-id}/01-scoping/
- **Stage**: 01-scoping (Domain and Intent Scoping)
- **Evolution context**: {include evolution_context if detected, otherwise "Initial pipeline run"}
- **Existing artifacts**: {list files in 01-scoping/ if any}
- **Pending messages**: {summarize relevant inbox messages}

The subagent has its knowledge and tool skills preloaded via its `skills` configuration.
It has access to the required MCP servers via its `mcpServers` configuration.

Also provide any outputs from previous stages that this stage depends on:
- (None -- this is the first stage)

## Post-Dispatch

When the subagent completes:

1. **Verify artifacts**: Check that expected output files exist in 01-scoping/
   - Expected artifacts: capability-spec.md, user-goal-map.md, domain-context-inventory.md, tech-stack-decision.json, gate-review.md
2. **Handle pending decisions**: If the subagent reported unresolved decisions, present to user
3. **Update project state**: Set stage `01-scoping` status to "review_pending" in `project-state.json`. Add history entry.
4. **Git commit**: In the PROJECT repo:
   ```
   cd projects/{project-id}
   git add -A
   git commit -m "Stage 01-scoping: {description of work done}"
   ```
5. **Learning capture**: If `projects/{project-id}/01-scoping/issues-log.md` or `successes-log.md` have entries, prompt the user: "This stage logged issues/successes. Would you like me to update skills with what was learned before clearing context?" If approved, update the appropriate `.claude/skills/` files and commit in the SYSTEM repo.
6. **Suggest next step**: If work is complete, suggest running `/gate-review`. If more iteration needed, explain what remains.
7. **Recommend `/clear`**: "Stage 01-scoping complete. All work is saved. I recommend `/clear` before starting the next stage for optimal output quality."

Do NOT automatically start the next pipeline stage. Let the user invoke it explicitly.

---

## Evolution Mode

When pre-check step 3 detects `evolution_context` on this stage, include in the dispatch context:

### Reading the Evolution Context

```json
{
  "status": "evolution",
  "evolution_context": {
    "work_unit": "wu-3",
    "quick_fix": false,
    "description": "Add USB-C connector to power input stage",
    "prior_status": "completed",
    "scope": "Schematic: add USB-C connector symbol, update power input net"
  }
}
```

### Dispatch Adjustments for Evolution Mode

| Aspect | Initial Pipeline | Evolution Mode |
|--------|-----------------|----------------|
| Starting point | Empty stage directory | Existing artifacts from prior pass |
| Artifacts | Create all from scratch | Modify only what the scope describes |
| Dispatch briefing | Standard stage work | Prefix with: "This is an evolution pass. Scope: {scope}. Modify existing artifacts. Do not rebuild from scratch." |
| Issue logging | Normal | Same -- log to issues-log.md |
| Success logging | Normal | Same -- log to successes-log.md |
| Post-dispatch | Set status to "review_pending" | Same -- set to "review_pending" |
| Gate review | Full criteria | Scoped (work unit) or lightweight (quick fix) -- see gate-review.md |

---

## Error Handling
- If subagent not found -> report error, check `.claude/agents/` directory
- If subagent returns with unresolved decisions -> present to user, re-dispatch if needed
- If previous stage outputs are missing -> warn user, suggest completing prior stage
- If evolution_context references a work unit that doesn't exist in project-state.json -> warn and ask user whether to proceed as a normal re-entry
- If evolution mode but stage directory is empty (no prior artifacts) -> warn: "This stage has no prior artifacts to evolve. Running as initial execution instead."
