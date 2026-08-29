#!/usr/bin/env python3
"""Apply small fnOS reliability patches to the pinned Studio release tree."""

from __future__ import annotations

import sys
from pathlib import Path


def replace_once(path: Path, old: str, new: str, label: str) -> None:
    text = path.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one patch anchor in {path}, found {count}")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")



def patch_server_bridge_resolver(root: Path) -> None:
    """Keep fnOS's Agent runtime available after upstream runtime selection.

    Studio v0.7.1 clears HERMES_AGENT_BRIDGE_PYTHON and HERMES_AGENT_ROOT
    when it detects a user-cli installation.  On fnOS HERMES_BIN is a shell
    launcher, so the subsequent shebang fallback can incorrectly execute that
    shell as Python and exit with code 2.  The fnOS-specific variables survive
    that upstream cleanup and point at the actual Agent runtime.
    """
    bundle = root / "dist/server/index.js"
    if not bundle.is_file():
        # The source-level fixture used by runtime-config.sh only contains
        # the Python bridge files. The release tree has the compiled bundle.
        return
    replace_once(
        bundle,
        """function jse(t={}){let e=t.hermesHome||Gy(),n=Jsn(t.agentRoot,e),a=t.python||process.env.HERMES_AGENT_BRIDGE_PYTHON;if(a)return{command:a,argsPrefix:[],agentRoot:n,hermesHome:e};""",
        """function jse(t={}){let e=t.hermesHome||Gy(),n=Jsn(t.agentRoot||process.env.HERMES_AGENT_ROOT_FNOS,e),a=t.python||process.env.HERMES_AGENT_BRIDGE_PYTHON||process.env.HERMES_AGENT_BRIDGE_PYTHON_FNOS;if(a)return{command:a,argsPrefix:[],agentRoot:n,hermesHome:e};""",
        "fnos-agent-runtime-fallback",
    )

def main() -> int:
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} STUDIO_ROOT", file=sys.stderr)
        return 2
    root = Path(sys.argv[1]).resolve()
    patch_server_bridge_resolver(root)
    python_roots = [
        root / "dist/server/agent-bridge/python",
        root / "packages/server/src/services/hermes/agent-bridge/python",
    ]
    targets = [path for path in python_roots if (path / "bridge_pool.py").is_file()]
    if not targets:
        locations = ", ".join(str(path) for path in python_roots)
        raise FileNotFoundError(f"Studio Bridge runtime not found in: {locations}")

    for python_root in targets:
        bridge_pool = python_root / "bridge_pool.py"
        bridge_broker = python_root / "bridge_broker.py"
        if not bridge_broker.is_file():
            raise FileNotFoundError(bridge_broker)

        replace_once(
            bridge_pool,
            '''                        def title_callback(title: str) -> None:
''',
            '''                        def title_callback(title: str, _source: str = "") -> None:
''',
            "title-callback-api",
        )
        replace_once(
            bridge_pool,
            '''                            final_response,
                            result.get("messages", []) if isinstance(result.get("messages"), list) else [],
                            failure_callback=getattr(session.agent, "_emit_auxiliary_failure", None),
''',
            '''                            conversation_history=(
                                result.get("messages", [])
                                if isinstance(result.get("messages"), list)
                                else []
                            ),
                            # The Agent writes an immediate deterministic title and
                            # refines it on a daemon thread. Title refinement must not
                            # surface a timeout as a failed chat response.
                            failure_callback=None,
''',
            "title-api-compatibility",
        )
        replace_once(
            bridge_broker,
            '''        except Exception as exc:
            print(f"[hermes-bridge-broker] connection error: {exc}", file=sys.stderr, flush=True)
        finally:
''',
            '''        except (BrokenPipeError, ConnectionResetError, ConnectionAbortedError):
            # The browser may close or refresh after sending a request. The
            # response then has nowhere to go, but the broker remains healthy.
            pass
        except OSError as exc:
            if getattr(exc, "errno", None) not in {32, 54, 103, 104}:
                print(f"[hermes-bridge-broker] connection error: {exc}", file=sys.stderr, flush=True)
        except Exception as exc:
            print(f"[hermes-bridge-broker] connection error: {exc}", file=sys.stderr, flush=True)
        finally:
''',
            "broker-disconnect-policy",
        )
    patched = ", ".join(str(path.relative_to(root)) for path in targets)
    print(f"Applied fnOS Studio reliability patches: {patched}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
