# BigDFT Skills

This is a Claude Code plugin repository containing skills for working with BigDFT.

## Structure

- `.claude-plugin/` - Plugin metadata (plugin.json, marketplace.json)
- `skills/` - Each subdirectory is a skill with a `SKILL.md` file
- `bigdft-suite/` - Reference clone of BigDFT source (gitignored)

## Skill conventions

- Skills are invoked as `/bigdft:<skill-name>`
- Each skill lives in `skills/<skill-name>/SKILL.md`
- Follow the pattern from the oniom-skills reference repo:
  - Use YAML frontmatter for metadata
  - Ask questions one at a time (conversational flow)
  - Auto-detect what you can, only ask about genuinely ambiguous choices
  - Include code building blocks as fenced Python/Fortran blocks
  - Use `# FILL` comments for values Claude should customize

## BigDFT reference

BigDFT is a DFT electronic structure code using wavelets as a basis set. Key components:
- **PyBigDFT** (`bigdft-suite/PyBigDFT/`) - Python interface with modules for Atoms, Systems, Calculators, Logfiles, InputActions, Fragments, etc.
- **Futile** - Fortran utilities library
- **CheSS** - Sparse matrix operations
- **PSolver** - Poisson solver
- Build system uses jhbuild via `Installer.py`
