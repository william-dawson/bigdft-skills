# bigdft-skills

> **Warning:** This plugin is under active development and not yet ready for general use. Skills may be incomplete, produce incorrect input, or change without notice. Use at your own risk.

A Claude Code plugin providing skills for working with the [BigDFT](https://bigdft.org) electronic structure code.

## Installation

```
/plugin marketplace add william-dawson/bigdft-skills
/plugin install bigdft@bigdft-skills
```

Or test locally:

```
claude --plugin-dir /path/to/bigdft-skills
```

## Skills

Skills are invoked via `/bigdft:<skill-name>`.

| Skill | Description |
|-------|-------------|
| `/bigdft:install` | Guide installation of BigDFT from source. Detects platform/compilers, generates an rcfile, and walks through the build. |
| `/bigdft:input` | Generate BigDFT input files (YAML or Python). Walks through calculation type, system, DFT parameters, and advanced options. |
| `/bigdft:remote` | Set up a remote connection to an HPC system (URL/Computer, SSH, SLURM templates). |
| `/bigdft:dataset` | Create and manage RemoteManager Dataset workflows for remote execution of Python functions. |
| `/bigdft:futile` | Developer guide for the Futile library: dictionaries, memory management, YAML I/O, error handling, timing, MPI wrappers. |
| `/bigdft:variables` | Add or modify input variables in BigDFT, CheSS, or PSolver. Full pipeline from YAML definition to Fortran access. |
| `/bigdft:logfile` | Parse and analyze BigDFT logfile output. Extract energies, forces, eigenvalues, convergence data, and more. |
| `/bigdft:systems` | Build and manipulate atomic systems with Atom, Fragment, and System classes. Structure I/O, fragmentation, and analysis. |
| `/bigdft:pseudopotentials` | Set up pseudopotentials: Python API, command-line file copying, PSP formats, and electron count implications. |
| `/bigdft:linear-scaling` | Configure linear scaling: lin_basis_params, ig_occupation, adding new elements, nbasis/rloc selection. |
| `/bigdft:liborbs` | Developer guide for liborbs: localization regions, wavelet compression, views abstraction, operator application, and MPI/GPU. |

## Development

The `bigdft-suite/` directory contains a clone of the BigDFT source for reference during skill development. It is gitignored and not part of this repository.
