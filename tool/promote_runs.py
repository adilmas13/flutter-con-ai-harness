"""Copy approved live runs from build/live_runs/ into recordings/recordings.json.

Usage: just promote L2/follow-up/with L3/plan/without ...
       just promote all          (every run in build/live_runs/)
"""

import glob
import json
import os
import sys

RECORDINGS = "recordings/recordings.json"


def main(names):
    if not names:
        sys.exit("Name the runs to promote, e.g. L2/follow-up/with, or 'all'.")
    files = sorted(glob.glob("build/live_runs/*.json"))
    wanted = files if names == ["all"] else [
        f"build/live_runs/{n.replace('/', '__')}.json" for n in names]
    with open(RECORDINGS, encoding="utf-8") as f:
        store = json.load(f)
    count = 0
    for path in wanted:
        if not os.path.exists(path):
            sys.exit(f"No live run at {path}. Run `just run-live` first.")
        with open(path, encoding="utf-8") as f:
            run = json.load(f)
        for key, rec in run["recordings"].items():
            store["recordings"][key] = rec
            count += 1
        print(f"promoted {run['run']} ({len(run['recordings'])} turns)")
    store["recordings"] = dict(sorted(store["recordings"].items()))
    with open(RECORDINGS, "w", encoding="utf-8") as f:
        json.dump(store, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print(f"{count} turns written to {RECORDINGS}")


if __name__ == "__main__":
    main(sys.argv[1:])
