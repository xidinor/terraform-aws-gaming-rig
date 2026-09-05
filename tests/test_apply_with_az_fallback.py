"""Offline tests. No Terraform executable, credentials or AWS calls are used."""

import importlib.util
import io
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import MagicMock, patch

SPEC = importlib.util.spec_from_file_location(
    "helper", Path(__file__).resolve().parents[1] / "apply_with_az_fallback.py"
)
helper = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(helper)

CAPACITY = {"address": "aws_instance.app", "severity": "error",
            "detail": "creating EC2 Instance: operation error EC2: RunInstances, api error InsufficientInstanceCapacity"}


def state(instance=None):
    resources = [] if instance is None else [{"address": helper.INSTANCE, "values": instance}]
    return {"values": {"root_module": {"resources": resources}}}


class WorkflowTests(unittest.TestCase):
    def scenario(self, results, existing=None, answers=None, partial=False, plan_actions=None,
                 saved_az=None):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        root = Path(temp.name)
        if saved_az:
            (root / helper.SELECTION).write_text(json.dumps({"instance_az": saved_az}))
        plans = []
        calls = []
        current = existing

        def command(args, **kwargs):
            calls.append(args)
            if args[1:3] == ["workspace", "show"]:
                return subprocess.CompletedProcess(args, 0, "default\n")
            if args[1] == "console":
                self.assertIn("-var=instance_az=null", args)
                return subprocess.CompletedProcess(args, 0, json.dumps(json.dumps(["1a", "1c"])))
            self.assertEqual(args[1], "plan")
            plans.append(next(x.split("=", 2)[2] for x in args if x.startswith("-var=instance_az=")))
            return subprocess.CompletedProcess(args, 0)

        def read(*args):
            if len(args) == 2:
                return state(current)
            return {"resource_changes": [{"address": helper.INSTANCE, "change": {
                "actions": plan_actions or (["no-op"] if existing else ["create"]),
                "before": existing}}]}

        def apply(path):
            nonlocal current
            if partial:
                current = {"id": "i-partial", "availability_zone": "1a"}
            return results.pop(0)

        with patch.object(helper, "ROOT", root), patch.dict(helper.os.environ, {}, clear=True), \
             patch.object(helper.subprocess, "run", side_effect=command), \
             patch.object(helper, "tf_json", side_effect=read), \
             patch.object(helper, "apply_plan", side_effect=apply) as applied, \
             patch("builtins.input", side_effect=answers or ["yes", "yes"]), \
             patch("builtins.print"):
            code = helper.run([])
        saved = root / helper.SELECTION
        return code, plans, json.loads(saved.read_text()) if saved.exists() else None, applied.call_count

    def test_capacity_then_success(self):
        self.assertEqual(self.scenario([(1, [CAPACITY]), (0, [])]),
                         (0, ["1a", "1c"], {"instance_az": "1c"}, 2))

    def test_existing_instance_keeps_az(self):
        result = self.scenario([(0, [])], existing={"id": "i-existing", "availability_zone": "1c"})
        self.assertEqual(result, (0, ["1c"], {"instance_az": "1c"}, 1))

    def test_all_azs_exhausted(self):
        result = self.scenario([(1, [CAPACITY]), (1, [CAPACITY])])
        self.assertEqual(result[:2], (1, ["1a", "1c"]))

    def test_other_errors_never_retry(self):
        for error in ({"detail": "UnauthorizedOperation"},
                      {**CAPACITY, "address": "aws_subnet.public[0]"},
                      {"detail": "timeout"}):
            with self.subTest(error=error):
                self.assertEqual(self.scenario([(1, [error])])[:2], (1, ["1a"]))
        self.assertEqual(self.scenario([(1, [CAPACITY, {"detail": "timeout"}])])[:2], (1, ["1a"]))

    def test_partial_instance_never_retries(self):
        self.assertEqual(self.scenario([(1, [CAPACITY])], partial=True)[:2], (1, ["1a"]))

    def test_existing_failure_never_retries(self):
        result = self.scenario([(1, [CAPACITY])], existing={"id": "i-existing", "availability_zone": "1c"})
        self.assertEqual(result[:2], (1, ["1c"]))

    def test_signal_exit_never_retries(self):
        self.assertEqual(self.scenario([(-2, [CAPACITY])])[:2], (-2, ["1a"]))

    def test_user_cancellation(self):
        self.assertEqual(self.scenario([], answers=["no"]), (1, ["1a"], None, 0))

    def test_replacement_is_rejected_before_apply(self):
        with self.assertRaisesRegex(ValueError, "deletion/replacement"):
            self.scenario([], plan_actions=["delete", "create"])

    def test_destroy_resets_candidate_order(self):
        # A previous successful 1c selection survives destroy on disk, but state is empty.
        self.assertEqual(self.scenario([(0, [])], saved_az="1c"),
                         (0, ["1a"], {"instance_az": "1a"}, 1))

    def test_invalid_and_removed_azs(self):
        for azs in ([], ["1a", "1a"], [None]):
            with self.assertRaises(ValueError):
                helper.candidates(azs, None)
        with self.assertRaises(ValueError):
            helper.candidates(["1a"], {"availability_zone": "1c"})

    def test_only_variable_arguments_are_accepted(self):
        self.assertEqual(helper.input_args(["-var", "region=test", "-var-file=x.tfvars"]),
                         ["-var=region=test", "-var-file=x.tfvars"])
        for arg in ("-destroy", "-auto-approve", "-target=x", "saved.plan", "-replace=x"):
            with self.assertRaises(ValueError):
                helper.input_args([arg])

    def test_selection_persists_and_rejects_foreign_content(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(helper, "ROOT", Path(directory)):
            helper.save_selection("1c")
            helper.save_selection("1a")
            path = Path(directory) / helper.SELECTION
            self.assertEqual(json.loads(path.read_text()), {"instance_az": "1a"})
            path.write_text('{"region": "do-not-overwrite"}')
            with self.assertRaises(ValueError):
                helper.save_selection("1c")

    def test_apply_json_diagnostics_and_sensitive_outputs(self):
        process = MagicMock()
        process.__enter__.return_value = process
        process.wait.return_value = 1
        process.stdout = io.StringIO(
            json.dumps({"type": "diagnostic", "diagnostic": CAPACITY}) + "\n" +
            json.dumps({"type": "outputs", "outputs": {"secret": {"value": "test-secret"}}}) + "\n"
        )
        with patch.object(helper.subprocess, "Popen", return_value=process) as start, \
             patch("builtins.print") as output:
            code, errors = helper.apply_plan(Path("mock-plan"))
        self.assertEqual(code, 1)
        self.assertTrue(helper.capacity_only(errors))
        self.assertNotIn("test-secret", str(output.call_args_list))
        self.assertEqual(start.call_args.args[0],
                         ["terraform", "apply", "-input=false", "-json", "mock-plan"])

    def test_unrecognized_apply_output_disables_retry(self):
        process = MagicMock()
        process.__enter__.return_value = process
        process.wait.return_value = 1
        process.stdout = io.StringIO("not-json\n")
        with patch.object(helper.subprocess, "Popen", return_value=process), patch("builtins.print"):
            _, errors = helper.apply_plan(Path("mock-plan"))
        self.assertFalse(helper.capacity_only(errors))


if __name__ == "__main__":
    unittest.main()
