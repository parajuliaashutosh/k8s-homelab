# Audit

Security audit of the host using [Lynis](https://github.com/CISOfy/lynis).

## Usage

```bash
sudo ./lynis-audit.sh              # update Lynis, then run the audit
sudo ./lynis-audit.sh --no-update  # run with the Lynis already installed
```

Needs root and `git`. Lynis is cloned into `/opt/lynis` on the first run.

The audit pauses after each section, so press **Enter** to continue.

## Reports

Each run is saved to `reports/lynis/<hostname>-<date>_<time>/` (UTC):

| File | What it is |
|---|---|
| `lynis.log` | Full log of every test |
| `lynis-report.dat` | Results as `key=value` (hardening index, warnings, suggestions) |
| `lynis-version.txt` | Lynis version used, so runs can be compared |

A short summary (hardening index, warnings, suggestions) is printed at the end.

Reports are owned by root and ignored by git, because they contain details about the host.
To read them, use `sudo`, for example `sudo less reports/lynis/<run>/lynis.log`.
