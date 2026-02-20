# Process Review

Analyze pipeline execution metrics across completed projects to identify patterns, bottlenecks, and improvement opportunities for the AI-Centric Apps expert system.

## Usage
```
/process-review
```

No arguments. This command reads metrics from all completed projects.

## Workflow

### Step 1: Gather Metrics Data
Read pipeline-metrics.json and project-state.json from all projects.

### Step 2: Analyze Stage Performance
Compute average duration, rework rate, average issues, decision frequency per stage.

### Step 3: Identify Patterns
Categorize findings: skill gaps, tool gaps, gate calibration, pipeline ordering, context management.

### Step 4: Present Findings
Display summary report with key findings and recommendations.

### Step 5: Log Review
Record in pipeline-metrics.json.

## Notes
- This is a read-only analysis command
- No git commit needed unless improvements are applied afterward
