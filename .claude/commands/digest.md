# Digest Reference Material

Process reference material into actionable AI-Centric Apps knowledge skills. Accepts any reading material -- books, journal articles, papers, news articles, blog posts, technical documents, standards, specifications, or web pages.

Tracks all digested sources in a registry to prevent accidental re-digestion and support intentional re-analysis with different modes.

## Usage

```
/digest [source] [--mode fresh|incremental|targeted] [--target skill-name]
```

- `source` -- Path to a file in `references/` or a URL to fetch.
- No argument -- List available files in `references/` (with digest status) and ask which to process.
- `--mode fresh` -- Re-digest ignoring previous notes (fresh eyes).
- `--mode incremental` -- Re-digest focusing on what was skipped or new skill targets.
- `--mode targeted --target {skill}` -- Re-analyze specifically for content relevant to a particular skill.

## Workflow

### 1. Identify Source Material
Check `references/` for files or accept URL.

### 2. Check Digest Registry
Read `references/digest-registry.json`. Compare content hashes.

### 3. Read and Analyze
Identify key concepts, decision frameworks, quantitative guidelines, failure modes, worked examples, tool-specific techniques.

### 4. Extract Into Knowledge Skills
Create or update skill files in `.claude/skills/`.

### 5. Save Notes and Update Registry
Save extraction notes to `references/notes/` and update `references/digest-registry.json`.

### 6. Git Commit and Summary
```
git add .claude/skills/ references/notes/ references/digest-registry.json
git commit -m "Knowledge: digest {source-name}"
```

## Quality Checks
- Every extracted rule must have units or concrete values
- No vague advice
- Each skill file must be self-contained and loadable independently
- Do not copy verbatim -- rewrite in the skill file's voice and format
- Attribute sources for significant items
