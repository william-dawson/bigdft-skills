---
name: remote
description: Set up a remote connection to an HPC system for RemoteManager. Guides SSH configuration, URL/Computer objects, SLURM templates, and connection testing. Use when preparing to run calculations on a remote machine.
user-invocable: true
allowed-tools: Read, Write, Bash, Glob, Grep
---

# RemoteManager Connection Setup

Help the user set up a connection to a remote HPC system using RemoteManager's `URL` and `Computer` classes. **Ask each question one at a time.** Auto-detect what you can before asking.

## Pre-flight

Before asking questions, silently check:

```bash
python3 -c "import remotemanager; print(remotemanager.__version__)" 2>/dev/null
ssh -o BatchMode=yes -o ConnectTimeout=5 dummy_host true 2>&1 | head -1  # just to confirm ssh exists
which rsync scp 2>/dev/null
cat ~/.ssh/config 2>/dev/null | head -40
```

If remotemanager is not installed, tell the user to install it:
```bash
pip install remotemanager
```

## Questions

### 1 -- Remote host

```
What is the remote machine you want to connect to?
  - Hostname or IP (e.g. login.cluster.org)
  - Username on the remote
```

Check if the host appears in `~/.ssh/config` and auto-fill user/port/proxy if found.

### 2 -- Test the connection

After getting host and user, immediately test:

```python
from remotemanager import URL
url = URL(host='FILL', user='FILL')
url.test_connection()
```

If it fails, help troubleshoot:
- Passwordless SSH not set up: guide through `ssh-keygen` + `ssh-copy-id`
- 2FA required: suggest `passfile` or `envpass` parameter for sshpass
- ProxyJump needed: suggest SSH config or `ssh_insert` parameter
- Wrong Python on remote: try `url = URL(..., python='python3.9')` or similar

### 3 -- Job scheduler

```
Does this machine use a job scheduler?
  1. SLURM (most common)
  2. No scheduler (direct execution via bash)
  3. Other (provide submit command)
```

If SLURM, proceed to template setup. If bash, the URL is ready to use.

### 4 -- SLURM template (if applicable)

Ask about the cluster's SLURM configuration:

```
For the SLURM template, I need:
  - Default partition/queue name
  - Account/project name (if required)
  - Typical resource requests (nodes, tasks, walltime)
  - Any module loads or environment setup needed
```

Then generate a template. Do not ask all of these individually -- ask in one go since they're all related to the same template.

## Output: URL (No Scheduler)

For direct bash execution:

```python
from remotemanager import URL

url = URL(
    host='FILL',           # e.g. 'login.cluster.org'
    user='FILL',           # e.g. 'jdoe'
)

# Test the connection
url.test_connection()
```

### URL Parameters Reference

| Parameter | Default | Description |
|-----------|---------|-------------|
| `host` | (required) | Remote hostname or IP |
| `user` | (required) | SSH username |
| `port` | 22 | SSH port |
| `python` | 'python3' | Python interpreter on remote |
| `submitter` | 'bash' | Job submission command ('bash' or 'sbatch') |
| `shell` | 'bash' | Shell for remote commands |
| `timeout` | 30 | SSH connection timeout (seconds) |
| `max_timeouts` | 3 | Max consecutive timeouts before error |
| `raise_errors` | True | Raise exceptions on stderr output |
| `error_ignore_patterns` | [] | Regex patterns to suppress in stderr |
| `quiet_ssh` | True | Suppress SSH noise in stderr |
| `keyfile` | None | Path to SSH private key |
| `passfile` | None | File containing password (for sshpass 2FA) |
| `envpass` | None | Environment variable with password (for sshpass 2FA) |
| `landing_dir` | None | Default directory for SSH commands |
| `ssh_insert` | None | Extra SSH flags (e.g. ProxyJump config) |

### URL with SSH Authentication Options

**Standard key-based (default):**
```python
url = URL(host='cluster', user='jdoe')
```

**Custom SSH key:**
```python
url = URL(host='cluster', user='jdoe', keyfile='~/.ssh/id_cluster')
```

**2FA with sshpass (password from file):**
```python
url = URL(host='cluster', user='jdoe', passfile='~/.ssh/otp_pass')
```

**2FA with sshpass (password from environment):**
```python
url = URL(host='cluster', user='jdoe', envpass='CLUSTER_PASS')
```

**ProxyJump (via SSH config):**

Add to `~/.ssh/config`:
```
Host cluster
    HostName login.cluster.org
    User jdoe
    ProxyJump gateway.org
```
Then just use:
```python
url = URL(host='cluster', user='jdoe')
```

**ProxyJump (inline):**
```python
url = URL(host='cluster', user='jdoe',
          ssh_insert='-J gateway_user@gateway.org')
```

### URL Utility Methods

```python
# Test the full connection pipeline
url.test_connection()

# Check latency
url.ping()

# Run a command on the remote
cmd = url.cmd('hostname')
print(cmd.stdout)

# Create an SSH tunnel (e.g. for Jupyter on remote)
url.tunnel(local_port=8888, remote_port=8888)

# File system utilities
url.utils.mkdir('path/on/remote')
url.utils.ls('path/on/remote')
url.utils.file_presence('path/to/file')
url.utils.file_mtime('path/to/file')
```

## Output: Computer (With SLURM)

For SLURM-based execution, use `Computer` which combines a URL with a jobscript template:

```python
from remotemanager.connection.computer import Computer

template = """#!/bin/bash
#SBATCH --job-name=#JOBNAME:default=bigdft_run#
#SBATCH --nodes=#NODES:default=1#
#SBATCH --ntasks=#NTASKS:default=4#
#SBATCH --cpus-per-task=#CPUS_PER_TASK:default=1:optional=True#
#SBATCH --time=#WALLTIME:default=1h:format=time#
#SBATCH --partition=#PARTITION#
#SBATCH --account=#ACCOUNT:optional=True#
#SBATCH --output=slurm-%j.out
#SBATCH --error=slurm-%j.err

#MODULES:optional=True#

"""

conn = Computer(
    host='FILL',
    user='FILL',
    submitter='sbatch',
    template=template,
)

# Set default values for template parameters
conn.nodes = FILL          # e.g. 1
conn.ntasks = FILL         # e.g. 4
conn.partition = FILL      # e.g. 'standard'
conn.walltime = FILL       # e.g. '2h' or '1d' or '30m'
conn.account = FILL        # e.g. 'my_project'

# Preview the generated script
print(conn.script())

# Test connection
conn.test_connection()

# Save for reuse
conn.to_yaml('my_cluster.yaml')
```

### Loading a Saved Computer

```python
conn = Computer.from_yaml('my_cluster.yaml')
```

### Template Syntax Reference

Template parameters use the `#NAME# ` placeholder syntax:

```
#NAME#                                    -- required parameter, no default
#NAME:default=value#                      -- parameter with default value
#NAME:optional=True#                      -- optional, line removed if not set
#NAME:format=time#                        -- time formatting (accepts '1h', '30m', '2d', etc.)
#NAME:format=float#                       -- float formatting
#NAME:default={expr}#                     -- dynamic default from other parameters
#NAME:hidden=True#                        -- not shown in parameter listing
#NAME:requires=OTHER#                     -- only included if OTHER is set
#NAME:min=1:max=100#                      -- numeric validation
#NAME:static=True#                        -- cannot be overridden per-runner
```

**Time format accepts:** `'30m'`, `'2h'`, `'1d'`, `'1:30:00'`, `'01:00:00'`

**Dynamic defaults using other parameters:**
```
#NODES:default={ntasks*cpus_per_task/cores_per_node}#
```

**Empty treatment:** When an optional parameter is not set:
- Default: the entire line containing the placeholder is removed
- Override with `empty=local` to remove just the placeholder, keeping the line
- Override with `empty=ignore` to leave the placeholder text as-is

### Example Templates

**Basic SLURM:**
```
#!/bin/bash
#SBATCH --job-name=#JOBNAME:default=run#
#SBATCH --nodes=#NODES:default=1#
#SBATCH --ntasks=#NTASKS:default=1#
#SBATCH --time=#WALLTIME:default=1h:format=time#
#SBATCH --partition=#PARTITION#
#SBATCH --account=#ACCOUNT:optional=True#

#MODULES:optional=True#
```

**SLURM with GPU:**
```
#!/bin/bash
#SBATCH --job-name=#JOBNAME:default=gpu_run#
#SBATCH --nodes=#NODES:default=1#
#SBATCH --ntasks=#NTASKS:default=1#
#SBATCH --gpus-per-node=#GPUS:default=1#
#SBATCH --time=#WALLTIME:default=4h:format=time#
#SBATCH --partition=#GPU_PARTITION#
#SBATCH --account=#ACCOUNT:optional=True#

#MODULES:optional=True#
```

**SLURM with environment setup:**
```
#!/bin/bash
#SBATCH --job-name=#JOBNAME:default=bigdft#
#SBATCH --nodes=#NODES:default=1#
#SBATCH --ntasks=#NTASKS:default=4#
#SBATCH --time=#WALLTIME:default=2h:format=time#
#SBATCH --partition=#PARTITION#
#SBATCH --account=#ACCOUNT#

module purge
#MODULES:optional=True#

export OMP_NUM_THREADS=#OMP_THREADS:default=1#
export MKL_NUM_THREADS=#OMP_THREADS:default=1#

source #BIGDFT_VARS:optional=True#
```

### JUBE Interoperability

For known HPC centers with JUBE4MaX templates:

```python
from remotemanager.JUBEInterop import JUBETemplate

# Load from JUBE4MaX repository
jt = JUBETemplate.from_repo(path='/path/to/jube4max/platforms')

# List available platforms
print(jt.available)

# Get template for a specific platform
template = jt.template('leonardo')
```

## Using the Connection with a Dataset

Once the connection is set up, pass it to a Dataset:

```python
from remotemanager import Dataset

# With URL (no scheduler)
ds = Dataset(function=my_func, url=url)

# With Computer (SLURM)
ds = Dataset(function=my_func, url=conn)
```

See `/bigdft:dataset` for the full Dataset workflow.

## Notes

- Passwordless SSH is required. Test with `ssh user@host hostname` before using RemoteManager.
- The remote machine must have Python >= 3.5 (>= 3.9 recommended).
- The remote must be Linux-based.
- rsync >= 3.0.0 is the default file transfer mechanism. Use `scp` as fallback if rsync is unavailable.
- `Computer.to_yaml()` / `Computer.from_yaml()` allow saving and reloading connection configs so they don't need to be recreated each session.
- Template parameters are case-insensitive in the template but lowercase in Python (`#NODES#` is set via `conn.nodes = 4`).
- The `error_ignore_patterns` parameter is useful for suppressing noisy SSH banners or MOTD messages that would otherwise trigger false errors.
