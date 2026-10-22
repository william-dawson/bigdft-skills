# bigdft-skills

> **Moved.** Development continues at
> **[BigDFT-group/BigDFT-Agents](https://github.com/BigDFT-group/BigDFT-Agents)**.

This repository is kept only so that existing installs keep working: the
marketplace here now serves the `bigdft` and `bigdft-dev` plugins directly
from `BigDFT-group/BigDFT-Agents`, so `/plugin update` picks up current content without any change
on your side.

The skills previously kept in this repository's `skills/` directory have been
removed, because a second copy inevitably drifts from the real one — which is
exactly what happened. Anything that was here is in `BigDFT-group/BigDFT-Agents` now, renamed with a
`bigdft-` prefix and split across two plugins:

| plugin | skills |
|---|---|
| `bigdft` | install, input, systems, pseudopotentials, linear-scaling, logfile |
| `bigdft-dev` | futile, atlab, liborbs, psolver, projectors, variables, linear-scaling internals |

The RemoteManager skills (previously `remote` and `dataset`) now live in the
separate `remotemanager` plugin in that repository.

## Installation

```
/plugin marketplace add BigDFT-group/BigDFT-Agents
/plugin install bigdft@bigdft-agents-marketplace
```

Installing from this marketplace still works and resolves to the same content,
but prefer the line above so the indirection eventually disappears.
