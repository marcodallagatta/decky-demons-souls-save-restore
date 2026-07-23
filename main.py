import asyncio
import json
import os
from pathlib import Path

import decky


class Plugin:
    async def _run(self, filename: str) -> dict[str, object]:
        script = Path(decky.DECKY_PLUGIN_DIR) / "bin" / filename
        if not script.is_file() or script.is_symlink():
            return {
                "ok": False,
                "message": "Checkpoint script is missing; no save was changed",
            }

        process = await asyncio.create_subprocess_exec(
            str(script),
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.STDOUT,
            env={**os.environ, "HOME": decky.DECKY_USER_HOME},
        )
        output, _ = await process.communicate()
        lines = output.decode("utf-8", errors="replace").strip().splitlines()
        if not lines:
            return {
                "ok": False,
                "message": "Checkpoint action returned no result; no save was changed",
            }

        try:
            result = json.loads(lines[-1])
        except json.JSONDecodeError:
            decky.logger.error("Checkpoint action returned invalid JSON: %s", lines[-1])
            return {
                "ok": False,
                "message": "Checkpoint action returned an invalid result; check the Decky log",
            }

        if not isinstance(result, dict) or not isinstance(result.get("ok"), bool):
            return {
                "ok": False,
                "message": "Checkpoint action returned an incomplete result; check the Decky log",
            }

        message = result.get("message")
        if not isinstance(message, str):
            message = "Checkpoint action completed without a message"

        return {
            "ok": result["ok"],
            "message": message,
            "timestamp": result.get("timestamp"),
        }

    async def create_checkpoint(self) -> dict[str, object]:
        return await self._run("create-checkpoint.sh")

    async def restore_checkpoint(self) -> dict[str, object]:
        return await self._run("restore-checkpoint.sh")

    async def _main(self):
        decky.logger.info("Demon's Souls Checkpoints loaded")
