#!/usr/bin/env python3
"""User-run CloudShell apply helper. Tests substitute Terraform; never probe AWS capacity."""

import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent
SELECTION = "zz-gaming-placement.auto.tfvars.json"
INSTANCE = "aws_instance.app"


def tf_json(*args):
    result = subprocess.run(
        ["terraform", *args], check=True, capture_output=True, text=True
    )
    return json.loads(result.stdout)


def instance_in(state):
    resources = state.get("values", {}).get("root_module", {}).get("resources", [])
    return next((r["values"] for r in resources if r.get("address") == INSTANCE), None)


def input_args(args):
    """Only variable inputs are accepted; no saved plan, destroy, target or replace flags."""
    result = []
    while args:
        arg, *args = args
        if arg in ("-var", "-var-file") and args:
            value, *args = args
            arg += "=" + value
        if not arg.startswith(("-var=", "-var-file=")):
            raise ValueError("Only -var and -var-file arguments are supported.")
        result.append(arg)
    return result


def candidates(azs, existing):
    if not isinstance(azs, list) or not azs or any(
        not isinstance(az, str) or not az for az in azs
    ) or len(set(azs)) != len(azs):
        raise ValueError("azs must be a non-empty list of unique AZ names.")
    if existing:
        az = existing.get("availability_zone")
        if az not in azs:
            raise ValueError("The existing instance AZ is missing from azs; refusing to move it.")
        return [az]
    return azs


def check_plan(plan, existing):
    changes = plan.get("resource_changes", [])
    if any("delete" in r["change"]["actions"] for r in changes):
        raise ValueError("Plan contains deletion/replacement. Use a separately reviewed Terraform workflow.")
    app = next((r for r in changes if r["address"] == INSTANCE), None)
    if app is None:
        raise ValueError("Plan does not contain aws_instance.app.")
    actions = app["change"]["actions"]
    if existing:
        if actions not in (["no-op"], ["update"]):
            raise ValueError("Existing instance would be recreated; automatic fallback is disabled.")
    elif actions != ["create"] or app["change"].get("before") is not None:
        raise ValueError("Expected a new instance; refusing automatic fallback.")


def capacity_only(errors):
    return bool(errors) and all(
        error.get("address") == INSTANCE
        and re.search(r"\bInsufficientInstanceCapacity\b", error.get("detail", ""))
        and "RunInstances" in error.get("detail", "")
        for error in errors
    )


def apply_plan(path):
    errors = []
    # JSON diagnostics let us identify the failing resource without parsing a debug log.
    with subprocess.Popen(
        ["terraform", "apply", "-input=false", "-json", str(path)],
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
    ) as process:
        try:
            for line in process.stdout:
                try:
                    event = json.loads(line)
                except json.JSONDecodeError:
                    errors.append({"detail": "Unrecognized Terraform output"})
                    print("Unrecognized Terraform output; fallback will be disabled.", flush=True)
                    continue
                if event.get("type") == "diagnostic":
                    diagnostic = event.get("diagnostic", {})
                    if diagnostic.get("severity") == "error":
                        errors.append(diagnostic)
                    print(diagnostic.get("summary", ""), flush=True)
                    print(diagnostic.get("detail", ""), flush=True)
                elif event.get("type") != "outputs":
                    print(event.get("@message", ""), flush=True)
            return process.wait(), errors
        except KeyboardInterrupt:
            # Wait for Terraform to finish handling the terminal's SIGINT and save state.
            process.wait()
            raise


def save_selection(az):
    # This file contains only an AZ, never credentials, state or a plan.
    target = ROOT / SELECTION
    if target.exists():
        value = json.loads(target.read_text())
        if not isinstance(value, dict) or set(value) != {"instance_az"}:
            raise ValueError(f"{SELECTION} is not a helper-owned selection file.")
    temporary = target.with_suffix(".tmp")
    temporary.write_text(json.dumps({"instance_az": az}) + "\n")
    temporary.replace(target)


def run(args):
    if any(k.startswith("TF_CLI_ARGS") for k in os.environ):
        raise ValueError("Unset TF_CLI_ARGS* before using this helper.")
    args = input_args(args)
    workspace = subprocess.run(
        ["terraform", "workspace", "show"], check=True, capture_output=True, text=True
    ).stdout.strip()
    if workspace != "default":
        raise ValueError("This helper supports only the default Terraform workspace.")
    existing = instance_in(tf_json("show", "-json"))
    # Override a stale selection after destroy while evaluating the candidate list.
    console = subprocess.run(
        ["terraform", "console", *args, "-var=instance_az=null"],
        input="jsonencode(var.azs)\n", check=True, capture_output=True, text=True,
    )
    azs = candidates(json.loads(json.loads(console.stdout)), existing)
    with tempfile.TemporaryDirectory(prefix="gaming-plan-") as directory:
        path = Path(directory) / "plan"
        for az in azs:
            # State is read again before every retry. Any partial instance stops fallback.
            current = instance_in(tf_json("show", "-json"))
            if not existing and current:
                raise ValueError("An instance is now in state; refusing to try another AZ.")
            if existing and (not current or current.get("id") != existing.get("id")):
                raise ValueError("Instance state changed; rerun the helper after reviewing it.")
            print(f"Planning in {az}", flush=True)
            subprocess.run(
                ["terraform", "plan", "-input=false", "-no-color", f"-out={path}",
                 *args, f"-var=instance_az={az}", "-var=aws_max_retries=2"], check=True,
            )
            check_plan(tf_json("show", "-json", str(path)), existing)
            if input(f"Apply this plan in {az}? Type yes: ").strip() != "yes":
                print("Cancelled. No further AZ will be tried.")
                return 1
            save_selection(az)
            code, errors = apply_plan(path)
            if code == 0 and not errors:
                print("Apply succeeded. Use terraform output to see connection details.")
                return 0
            if code != 1 or existing or not capacity_only(errors):
                print("Apply failed; this is not a safe initial capacity-only retry.")
                return code or 1
            if instance_in(tf_json("show", "-json")):
                print("An instance is recorded in state; fallback stopped.")
                return 1
            print(f"No capacity in {az}. Trying the next configured AZ, if any.", flush=True)
    print("All configured AZs lacked capacity. Partial network/key resources remain in state.")
    return 1


def main():
    if sys.argv[1:] == ["--help"]:
        print("python3 apply_with_az_fallback.py [-var=NAME=VALUE] [-var-file=PATH]")
        return 0
    os.chdir(ROOT)
    os.umask(0o077)
    # CloudShell/Linux: a kernel lock is released even after an interrupted run.
    import fcntl
    with (ROOT / ".gaming-apply.lock").open("a") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise ValueError("Another apply helper is running in this directory.") from None
        return run(sys.argv[1:])


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        # Captured JSON/state and command-line variable values are intentionally not printed.
        print("Stopped: " + (str(error) if isinstance(error, ValueError) else
              "Terraform or a local operation failed. No AZ retry was performed."), file=sys.stderr)
        sys.exit(1)
    except (KeyboardInterrupt, EOFError):
        print("Interrupted. Review Terraform state before running again.", file=sys.stderr)
        sys.exit(130)
