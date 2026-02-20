import os, re

base = 'C:/Users/RobertGeiger/Programs/forge-ai-ws-ai-centric-apps/systems/ai-centric-apps'

# Read CLAUDE.md
with open(os.path.join(base, '.claude', 'CLAUDE.md'), 'r', encoding='utf-8') as f:
    claude_md = f.read()

# Check that CLAUDE.md references agents that exist
agents_dir = os.path.join(base, '.claude', 'agents')
existing_agents = set(f.replace('.md', '') for f in os.listdir(agents_dir) if f.endswith('.md'))

# Find agent references in CLAUDE.md
agent_pattern = re.compile(r'(\w[\w-]*-agent)')
agent_refs = set(agent_pattern.findall(claude_md))

print('=== CLAUDE.md Agent References ===')
all_pass = True
for ref in sorted(agent_refs):
    exists = ref in existing_agents
    if not exists:
        all_pass = False
    print(f'  {"PASS" if exists else "FAIL"}: {ref}')

# Check stage commands reference valid agents
cmds_dir = os.path.join(base, '.claude', 'commands')
print()
print('=== Stage Command -> Agent References ===')
for i in range(1, 8):
    stage_files = [f for f in os.listdir(cmds_dir) if f.startswith(f'stage-0{i}')]
    for sf in stage_files:
        with open(os.path.join(cmds_dir, sf), 'r', encoding='utf-8') as f:
            content = f.read()
        agent_matches = set(agent_pattern.findall(content))
        for am in sorted(agent_matches):
            exists = am in existing_agents
            if not exists:
                all_pass = False
            print(f'  {"PASS" if exists else "FAIL"}: {sf} -> {am}')

# Check project-template variables are intact
print()
print('=== Project Template Variables Intact ===')
template_dir = os.path.join(base, 'project-template')
for tf in sorted(os.listdir(template_dir)):
    if tf.endswith('.forge'):
        with open(os.path.join(template_dir, tf), 'r', encoding='utf-8') as f:
            content = f.read()
        vars_found = re.findall(r'\{\{[A-Z_]+\}\}', content)
        has_vars = len(vars_found) > 0
        print(f'  {"PASS" if has_vars else "WARN"}: {tf} has {len(vars_found)} template variables')

print()
if all_pass:
    print('ALL CROSS-REFERENCE CHECKS PASSED')
else:
    print('SOME CROSS-REFERENCE CHECKS FAILED')
