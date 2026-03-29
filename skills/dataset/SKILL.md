---
name: dataset
description: Create and manage RemoteManager Dataset workflows for running Python functions on remote HPC systems. Covers function definition, run submission, result retrieval, error handling, and dataset chaining. Use when setting up or debugging remote computation workflows.
user-invocable: true
allowed-tools: Read, Write, Bash, Glob, Grep
---

# RemoteManager Dataset Workflows

Help the user create and manage `Dataset` workflows for executing Python functions on remote machines. **Ask each question one at a time.** Skip questions whose answers are obvious from context.

## Pre-flight

Check if remotemanager is installed and whether the user already has a connection set up:

```bash
python3 -c "import remotemanager; print(remotemanager.__version__)" 2>/dev/null
```

Look for existing connection code (URL/Computer objects) or saved YAML configs in the working directory:

```bash
ls *.yaml *.py *.ipynb 2>/dev/null
```

If no connection exists, suggest running `/bigdft:remote` first.

## Questions

### 1 -- What computation?

```
What function do you want to run remotely?
  1. I'll describe it and you write the function
  2. I have an existing function
  3. I want to run a BigDFT calculation
```

### 2 -- How many runs?

```
How do you want to set up the runs?
  1. A single run
  2. A parameter sweep (vary one or more arguments)
  3. A set of specific configurations
```

### 3 -- Result handling

Only ask if non-obvious:

```
What do you need from the results?
  1. Just the return values
  2. Return values plus output files from the remote
  3. Chain into another computation (dataset chaining)
```

## Critical Rules for Remote Functions

**These rules are essential and must always be followed when writing functions for Dataset:**

1. **All imports must be inside the function body.** The function is serialized and sent to the remote; it cannot reference the local environment.

```python
# CORRECT
def compute(x):
    import numpy as np
    return np.sqrt(x)

# WRONG -- will fail on remote
import numpy as np
def compute(x):
    return np.sqrt(x)
```

2. **Pass the function object, not a call.** Use `function=compute`, never `function=compute()`.

3. **Functions must be self-contained.** They cannot reference variables, classes, or other functions from the local scope.

4. **To use helper functions**, decorate them with `@RemoteFunction`:

```python
from remotemanager import RemoteFunction

@RemoteFunction
def helper(x):
    return x ** 2

def main_func(a, b):
    return helper(a) + helper(b)

ds = Dataset(function=main_func, url=url)
```

5. **For complex objects** (custom classes, etc.), use the `dill` serializer:

```python
ds = Dataset(function=my_func, url=url,
             serialiser='dill')
```
This requires `pip install dill` on both local and remote.

## Output: Basic Dataset Workflow

```python
from remotemanager import Dataset, URL

# Connection (or load from YAML, or use Computer for SLURM)
url = URL(host='FILL', user='FILL')

# Define the function -- all imports MUST be inside
def FILL(FILL):
    # FILL: imports
    # FILL: computation
    return FILL

# Create dataset
ds = Dataset(
    function=FILL,
    url=url,
    local_dir='FILL',       # local staging directory
    remote_dir='FILL',      # directory on the remote machine
)

# Add runs
ds.append_run(args={FILL})

# Execute
ds.run()

# Wait for completion
ds.wait(interval=FILL, timeout=FILL)  # interval in seconds, timeout in seconds

# Retrieve results
ds.fetch_results()
print(ds.results)

# Check for errors
if ds.errors:
    print("Errors:", ds.errors)
    for r in ds.failed:
        print(r.full_error_)
```

## Dataset Constructor Reference

| Parameter | Default | Description |
|-----------|---------|-------------|
| `function` | (required) | Python callable to execute remotely |
| `url` | localhost | `URL` or `Computer` object |
| `name` | None | Dataset identifier (auto-generated if None) |
| `local_dir` | None | Local staging directory |
| `remote_dir` | None | Working directory on remote |
| `run_dir` | None | Subdirectory within remote_dir for each run |
| `transport` | 'rsync' | File transfer: 'rsync', 'scp', or 'cp' |
| `serialiser` | 'json' | Data encoding: 'json', 'yaml', 'dill', 'jsonpickle' |
| `script` | None | Jobscript template string (for SLURM) |
| `skip` | True | Reuse existing database on reinit |
| `extra_files_send` | [] | Files to upload with every run |
| `extra_files_recv` | [] | Files to download after every run |
| `verbose` | True | Print status messages |
| `asynchronous` | True | Run all runners in parallel (False for sequential) |

## Example: Single Run

```python
def energy(structure_file):
    from BigDFT.Calculators import SystemCalculator
    from BigDFT.Inputfiles import Inputfile

    inp = Inputfile.from_yaml('input.yaml')
    calc = SystemCalculator()
    log = calc.run(input=inp, name='calc', run_dir='.')
    return log.energy

ds = Dataset(function=energy, url=url,
             local_dir='local_energy', remote_dir='remote_energy')

ds.append_run(
    args={'structure_file': 'molecule.xyz'},
    extra_files_send=['molecule.xyz', 'input.yaml'],
)

ds.run()
ds.wait(interval=30, timeout=3600)
ds.fetch_results()
print("Energy:", ds.results[0])
```

## Example: Parameter Sweep

```python
def converge(hgrid, rmult_coarse, rmult_fine):
    from BigDFT.Inputfiles import Inputfile
    from BigDFT.Calculators import SystemCalculator

    inp = Inputfile()
    inp.set_hgrid(hgrid)
    inp.set_rmult(coarse=rmult_coarse, fine=rmult_fine)
    inp.set_xc('PBE')

    calc = SystemCalculator()
    log = calc.run(input=inp, name='conv', run_dir='.')
    return {'energy': log.energy, 'hgrid': hgrid, 'rmult': [rmult_coarse, rmult_fine]}

ds = Dataset(function=converge, url=url,
             local_dir='convergence', remote_dir='convergence')

# Parameter sweep over grid spacing
for h in [0.5, 0.45, 0.4, 0.35, 0.3]:
    ds.append_run(args={'hgrid': h, 'rmult_coarse': 5.0, 'rmult_fine': 8.0})

ds.run()
ds.wait(interval=60, timeout=7200)
ds.fetch_results()

for r in ds.results:
    print(f"hgrid={r['hgrid']:.2f}  energy={r['energy']:.6f}")
```

## Example: Batch Appending with lazy_append

For large sweeps, `lazy_append` is more efficient:

```python
with ds.lazy_append():
    for h in [0.5, 0.45, 0.4, 0.35, 0.3]:
        for rmult in [(4, 6), (5, 7), (5, 8), (6, 9)]:
            ds.append_run(args={
                'hgrid': h,
                'rmult_coarse': rmult[0],
                'rmult_fine': rmult[1],
            })
```

## Example: With SLURM Resources

Set SLURM parameters per-run or globally:

```python
from remotemanager.connection.computer import Computer

conn = Computer.from_yaml('my_cluster.yaml')

ds = Dataset(function=my_func, url=conn,
             local_dir='slurm_runs', remote_dir='slurm_runs')

# Set defaults for all runs
ds.set_run_arg('nodes', 1)
ds.set_run_arg('ntasks', 4)
ds.set_run_arg('walltime', '2h')
ds.set_run_arg('account', 'my_project')

# Or override per run
ds.append_run(args={'size': 'small'})
ds.append_run(args={'size': 'large'},
              nodes=4, ntasks=16, walltime='8h')

ds.run()
```

### Setting Run Arguments

```python
# Set one parameter for all runners
ds.set_run_arg('nodes', 2)

# Set multiple parameters at once
ds.set_run_args(nodes=2, ntasks=8, walltime='4h')

# Update (merge) parameters
ds.update_run_args({'account': 'proj123'})
```

**Parameter priority (highest wins):**
run() call > per-runner args > Dataset defaults > Computer defaults > template defaults

## Example: Extra Files

Send input files to the remote and retrieve output files:

```python
ds.append_run(
    args={'input_file': 'data.txt'},
    extra_files_send=['data.txt', 'config.yaml'],
    extra_files_recv=['output.dat', 'result.log'],
)
```

Or set files for all runs:

```python
ds = Dataset(function=my_func, url=url,
             extra_files_send=['shared_data.h5'],
             extra_files_recv=['result.json'])
```

## Example: Dataset Chaining

Chain datasets so the output of one feeds into the next. Child functions receive parent results via the `loaded` variable:

```python
def generate(n_atoms):
    import random
    positions = [[random.random()*10 for _ in range(3)] for _ in range(n_atoms)]
    return {'positions': positions, 'n_atoms': n_atoms}

def calculate(method):
    # `loaded` is automatically available -- contains parent's result
    positions = loaded['positions']  # noqa: F821
    # ... run calculation with positions ...
    return {'energy': -42.0, 'method': method}

def analyze(threshold):
    energy = loaded['energy']  # noqa: F821
    return energy < threshold

ds_gen = Dataset(function=generate, url=url,
                 local_dir='chain/gen', remote_dir='chain/gen')
ds_calc = Dataset(function=calculate, url=url,
                  local_dir='chain/calc', remote_dir='chain/calc')
ds_post = Dataset(function=analyze, url=url,
                  local_dir='chain/post', remote_dir='chain/post')

# Set up the chain
ds_gen.set_downstream(ds_calc)
ds_calc.set_downstream(ds_post)

# Append runs -- propagates through the chain
ds_gen.append_run(args={'n_atoms': 10})
ds_calc.set_run_args(method='PBE')
ds_post.set_run_args(threshold=-40.0)

# Run the first dataset -- downstream runs automatically when upstream completes
ds_gen.run()
ds_gen.wait(interval=10, timeout=300)
ds_gen.fetch_results()

# Now run downstream
ds_calc.run()
ds_calc.wait(interval=30, timeout=3600)
ds_calc.fetch_results()

ds_post.run()
ds_post.wait(interval=5, timeout=60)
ds_post.fetch_results()
print(ds_post.results)
```

**Important:** In chained functions, the variable `loaded` is injected automatically -- it contains the deserialized result from the upstream dataset. Do not define it yourself; just use it. Add `# noqa: F821` to suppress linter warnings.

## Execution Lifecycle

The `ds.run()` call executes three stages internally:

1. **`stage()`** -- generates all files locally (run scripts, jobscripts, master script)
2. **`transfer()`** -- uploads files to remote via rsync/scp
3. **`execute()`** -- runs the master script via SSH, which submits each runner

You can also call these individually:
```python
ds.stage()
ds.transfer()
# ... inspect files before executing ...
ds.execute()
```

### Runner States

Each runner progresses through these states:

```
created -> staged -> transferred -> submitted -> started -> completed (or failed) -> satisfied
```

Check states:
```python
for i, runner in enumerate(ds.runners):
    print(f"Run {i}: {runner.state_}")
```

## Error Handling and Retries

```python
# Check for errors
print(ds.errors)          # list of error summaries (one per runner)
print(ds.failed)          # list of failed Runner objects

# Get full traceback for a failed runner
for runner in ds.failed:
    print(runner.full_error_)

# Retry all failed runs
ds.retry_failed()
ds.run()
ds.wait(interval=10, timeout=300)
ds.fetch_results()

# Remove a specific run and re-add with corrected args
ds.remove_run(3)  # remove by index
ds.append_run(args={'corrected': 'value'})
```

## Database Persistence

Datasets auto-persist to YAML database files. This means you can restart your notebook/script and the dataset will pick up where it left off:

```python
# First session
ds = Dataset(function=my_func, url=url, name='experiment1',
             local_dir='exp1', remote_dir='exp1')
ds.append_run(args={'x': 42})
ds.run()
# ... close notebook ...

# Later session -- automatically restores state because skip=True (default)
ds = Dataset(function=my_func, url=url, name='experiment1',
             local_dir='exp1', remote_dir='exp1')
ds.wait(interval=10, timeout=300)
ds.fetch_results()
print(ds.results)
```

### Backup and Restore

```python
# Full backup (database + all result files)
ds.backup('experiment_backup.zip', full=True)

# Lightweight backup (database only)
ds.pack('experiment_snapshot')

# Restore from backup
ds_restored = Dataset.restore('experiment_backup.zip')

# Clean up everything (local dirs, remote dirs, database)
ds.hard_reset()
```

## Serializer Selection

| Serializer | Install | Use When |
|------------|---------|----------|
| `'json'` | built-in | Default. Simple types (numbers, strings, lists, dicts) |
| `'yaml'` | built-in | Same as JSON, YAML formatting |
| `'dill'` | `pip install dill` | Complex objects, custom classes, lambdas |
| `'jsonpickle'` | `pip install jsonpickle` | Complex objects with JSON readability |

```python
# For complex return types
ds = Dataset(function=my_func, url=url, serialiser='dill')
```

**Important:** If using `dill` or `jsonpickle`, the package must be installed on both local and remote machines.

## Quick Execution Shortcuts

### @SanzuFunction Decorator

For one-off remote function calls without manually creating a Dataset:

```python
from remotemanager import SanzuFunction, URL

@SanzuFunction(url=URL(host='cluster', user='jdoe'))
def compute(x, y):
    import math
    return math.sqrt(x**2 + y**2)

result = compute(x=3, y=4)  # transparently runs on remote
print(result)  # 5.0
```

### %%sanzu Jupyter Magic

For running notebook cells on a remote machine:

```python
%load_ext remotemanager
```

Then in a cell:
```python
%%sanzu url = URL(host='cluster', user='jdoe')
%%sanzu local_dir = "local_magic"
%%sanzu remote_dir = "remote_magic"
%%sargs x = 42
%%spull result

import math
result = math.sqrt(x)
```

After execution, `result` is available in the notebook namespace.

## Common Patterns

### Wait with Progress

```python
ds.run()
while not all(r.is_finished_ for r in ds.runners):
    ds.fetch_results()
    done = sum(1 for r in ds.runners if r.is_finished_)
    total = len(ds.runners)
    print(f"Progress: {done}/{total}")
    import time
    time.sleep(30)
ds.fetch_results()
```

### Collecting Results into a Table

```python
ds.fetch_results()
import json
for i, (runner, result) in enumerate(zip(ds.runners, ds.results)):
    print(f"Run {i}: args={runner.args_}  result={result}")
```

### Copying Runners Between Datasets

```python
ds_new = Dataset(function=new_func, url=url,
                 local_dir='new', remote_dir='new')
ds_new.copy_runners(ds_old)  # copies all runner args
```

## Notes

- `skip=True` (default) means reinitializing a Dataset with the same function and name will restore state from the database file. Set `skip=False` to force a fresh start.
- Database files are named `dataset-{8char-hex}.yaml` based on a hash of the function. Use `name=` for human-readable identification.
- `ds.run()` is asynchronous by default -- all runners execute simultaneously. Use `asynchronous=False` for sequential execution.
- The `local_dir` and `remote_dir` should generally be unique per dataset to avoid file collisions.
- `ds.wait()` polls the remote for completion. The `interval` parameter controls how often it checks (in seconds). Don't set it too low to avoid SSH overhead.
- Results are `None` for runners that haven't completed yet. Always call `ds.fetch_results()` before accessing `ds.results`.
