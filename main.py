#!/usr/bin/env python3
"""
ReMarket Unified Project Launcher (main.py)
===========================================
Chạy đồng thời cả 3 thành phần của dự án ReMarket chỉ với 1 lệnh:
  1. Python FastAPI + LangGraph AI Service (apps/ai)       -> http://localhost:8000
  2. NestJS Backend Service (apps/backend)                 -> http://localhost:3000/api/v1
  3. Flutter Frontend Application (apps/fe)                -> Edge / Chrome / Windows / Android

Cách sử dụng:
  python main.py                      # Chạy cả 3 phần chung 1 cửa sổ Terminal (có màu phân biệt)
  python main.py --windows            # Mở 3 cửa sổ PowerShell riêng biệt cho 3 phần
  python main.py --device windows     # Chạy AI + Backend + Flutter Windows Desktop
  python main.py --no-fe              # Chỉ chạy AI Service + NestJS Backend
"""

from __future__ import annotations

import argparse
import os
import shutil
import signal
import subprocess
import sys
import threading
import time
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parent
AI_DIR = ROOT_DIR / "apps" / "ai"
BACKEND_DIR = ROOT_DIR / "apps" / "backend"
FE_DIR = ROOT_DIR / "apps" / "fe"

# ANSI color codes for terminal output
RESET = "\033[0m"
BOLD = "\033[1m"
CYAN = "\033[96m"
GREEN = "\033[92m"
MAGENTA = "\033[95m"
YELLOW = "\033[93m"
RED = "\033[91m"


def enable_windows_ansi() -> None:
    if os.name == "nt":
        os.system("")


def ensure_env_files(backend_port: int, ai_port: int) -> None:
    """Đảm bảo file .env tồn tại ở apps/backend và apps/ai trước khi chạy."""
    backend_env = BACKEND_DIR / ".env"
    backend_example = BACKEND_DIR / ".env.example"
    if not backend_env.exists() and backend_example.exists():
        content = backend_example.read_text(encoding="utf-8")
        content = content.replace("PORT=5000", f"PORT={backend_port}")
        backend_env.write_text(content, encoding="utf-8")
        print(f"{YELLOW}[SETUP]{RESET} Đã tự động tạo {backend_env} (PORT={backend_port})")

    ai_env = AI_DIR / ".env"
    ai_example = AI_DIR / ".env.example"
    if not ai_env.exists() and ai_example.exists():
        content = ai_example.read_text(encoding="utf-8")
        content = content.replace(
            "BACKEND_API_BASE_URL=http://localhost:5000/api/v1",
            f"BACKEND_API_BASE_URL=http://localhost:{backend_port}/api/v1",
        )
        ai_env.write_text(content, encoding="utf-8")
        print(
            f"{YELLOW}[SETUP]{RESET} Đã tự động tạo {ai_env} — hãy nhớ điền GEMINI_API_KEY vào file này!"
        )


def resolve_ai_python() -> str:
    """Ưu tiên dùng Python có cài sẵn uvicorn/fastapi/langgraph (ví dụ .venv hoặc Python311)."""
    candidates = [
        AI_DIR / ".venv" / "Scripts" / "python.exe",
        AI_DIR / ".venv" / "bin" / "python",
        Path(os.path.expandvars(r"%LOCALAPPDATA%\Programs\Python\Python311\python.exe")),
        Path(os.path.expandvars(r"%LOCALAPPDATA%\Programs\Python\Python312\python.exe")),
        Path(sys.executable),
    ]
    for candidate in candidates:
        if candidate.exists():
            try:
                res = subprocess.run(
                    [str(candidate), "-c", "import uvicorn, fastapi"],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    timeout=5,
                    check=False,
                )
                if res.returncode == 0:
                    return str(candidate)
            except Exception:
                continue
    return sys.executable


def stream_output(pipe, prefix: str, color: str) -> None:
    """Đọc log từ tiến trình con và in ra màn hình kèm nhãn màu."""
    try:
        for line in iter(pipe.readline, ""):
            if not line:
                break
            sys.stdout.write(f"{color}{BOLD}{prefix}{RESET} {line}")
            sys.stdout.flush()
    except Exception:
        pass
    finally:
        try:
            pipe.close()
        except Exception:
            pass


def kill_process_tree(proc: subprocess.Popen) -> None:
    """Dừng toàn bộ tiến trình con (bao gồm node/uvicorn/flutter trên Windows)."""
    if proc.poll() is not None:
        return
    try:
        if os.name == "nt":
            subprocess.run(
                ["taskkill", "/F", "/T", "/PID", str(proc.pid)],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                check=False,
            )
        else:
            proc.terminate()
            proc.wait(timeout=5)
    except Exception:
        try:
            proc.kill()
        except Exception:
            pass


def launch_in_separate_windows(
    backend_port: int,
    ai_port: int,
    fe_device: str,
    fe_web_port: int,
    no_fe: bool,
) -> None:
    """Mở từng phần trong một cửa sổ PowerShell riêng biệt trên Windows."""
    ai_python = resolve_ai_python()
    api_base_url = f"http://localhost:{backend_port}/api/v1"

    ai_cmd = (
        f"$Host.UI.RawUI.WindowTitle = 'ReMarket - AI Service (:{ai_port})'; "
        f"cd '{AI_DIR}'; "
        f"& '{ai_python}' -m uvicorn app.main:app --host 0.0.0.0 --port {ai_port} --reload"
    )
    be_cmd = (
        f"$Host.UI.RawUI.WindowTitle = 'ReMarket - NestJS Backend (:{backend_port})'; "
        f"cd '{BACKEND_DIR}'; "
        f"$env:PORT='{backend_port}'; $env:AI_SERVICE_URL='http://localhost:{ai_port}'; "
        f"npm run start:dev"
    )

    print(f"{CYAN}➜ Đang mở cửa sổ PowerShell cho AI Service (:{ai_port})...{RESET}")
    subprocess.Popen(
        ["powershell", "-NoExit", "-Command", ai_cmd],
        creationflags=subprocess.CREATE_NEW_CONSOLE if os.name == "nt" else 0,
    )

    print(f"{GREEN}➜ Đang mở cửa sổ PowerShell cho NestJS Backend (:{backend_port})...{RESET}")
    subprocess.Popen(
        ["powershell", "-NoExit", "-Command", be_cmd],
        creationflags=subprocess.CREATE_NEW_CONSOLE if os.name == "nt" else 0,
    )

    if not no_fe:
        web_port_arg = f"--web-port {fe_web_port}" if fe_device in ("edge", "chrome", "web-server") else ""
        fe_cmd = (
            f"$Host.UI.RawUI.WindowTitle = 'ReMarket - Flutter FE ({fe_device})'; "
            f"cd '{FE_DIR}'; "
            f"flutter run -d {fe_device} {web_port_arg} --dart-define=API_BASE_URL={api_base_url}"
        )
        print(f"{MAGENTA}➜ Đang mở cửa sổ PowerShell cho Flutter Frontend ({fe_device})...{RESET}")
        subprocess.Popen(
            ["powershell", "-NoExit", "-Command", fe_cmd],
            creationflags=subprocess.CREATE_NEW_CONSOLE if os.name == "nt" else 0,
        )

    print(f"\n{BOLD}{GREEN}✔ Đã khởi chạy tất cả cửa sổ thành công!{RESET}")


def main() -> int:
    enable_windows_ansi()

    parser = argparse.ArgumentParser(
        description="ReMarket Unified Launcher — Chạy đồng thời AI + Backend + Flutter FE"
    )
    parser.add_argument(
        "--backend-port",
        type=int,
        default=3000,
        help="Cổng của NestJS Backend (mặc định: 3000)",
    )
    parser.add_argument(
        "--ai-port",
        type=int,
        default=8000,
        help="Cổng của Python FastAPI AI Service (mặc định: 8000)",
    )
    parser.add_argument(
        "--device",
        type=str,
        default="edge",
        help="Thiết bị chạy Flutter: edge, chrome, windows, hoặc device ID (mặc định: edge)",
    )
    parser.add_argument(
        "--web-port",
        type=int,
        default=8080,
        help="Cổng chạy Flutter Web khi dùng edge/chrome (mặc định: 8080)",
    )
    parser.add_argument(
        "--no-fe",
        action="store_true",
        help="Chỉ chạy AI Service và NestJS Backend, không bật Flutter",
    )
    parser.add_argument(
        "--windows",
        action="store_true",
        help="Mở 3 cửa sổ PowerShell riêng biệt thay vì gộp chung 1 Terminal",
    )
    args = parser.parse_args()

    ensure_env_files(backend_port=args.backend_port, ai_port=args.ai_port)

    print(f"{BOLD}============================================================{RESET}")
    print(f"{BOLD}🚀 REMARKET — KHỞI CHẠY TOÀN HỆ THỐNG (AI + BACKEND + FE){RESET}")
    print(f"{BOLD}============================================================{RESET}")
    print(f"  {CYAN}• AI Service (FastAPI + LangGraph):{RESET} http://localhost:{args.ai_port}")
    print(f"  {GREEN}• Backend API (NestJS + MongoDB)  :{RESET} http://localhost:{args.backend_port}/api/v1")
    print(f"  {GREEN}• Swagger Docs                    :{RESET} http://localhost:{args.backend_port}/api/docs")
    if not args.no_fe:
        print(f"  {MAGENTA}• Flutter App ({args.device})              :{RESET} Đang khởi động...")
    print(f"{BOLD}============================================================{RESET}\n")

    if args.windows and os.name == "nt":
        launch_in_separate_windows(
            backend_port=args.backend_port,
            ai_port=args.ai_port,
            fe_device=args.device,
            fe_web_port=args.web_port,
            no_fe=args.no_fe,
        )
        return 0

    processes: list[tuple[str, subprocess.Popen]] = []

    try:
        # 1. Start Python AI Service (apps/ai)
        ai_python = resolve_ai_python()
        ai_env = os.environ.copy()
        ai_env["PYTHONUNBUFFERED"] = "1"
        ai_env["BACKEND_API_BASE_URL"] = f"http://localhost:{args.backend_port}/api/v1"

        ai_proc = subprocess.Popen(
            [
                ai_python,
                "-m",
                "uvicorn",
                "app.main:app",
                "--host",
                "0.0.0.0",
                "--port",
                str(args.ai_port),
                "--reload",
            ],
            cwd=str(AI_DIR),
            env=ai_env,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
        processes.append(("AI Service", ai_proc))
        threading.Thread(
            target=stream_output,
            args=(ai_proc.stdout, f"[AI :{args.ai_port}]", CYAN),
            daemon=True,
        ).start()

        # 2. Start NestJS Backend (apps/backend)
        npm_cmd = shutil.which("npm.cmd") or shutil.which("npm") or "npm"
        be_env = os.environ.copy()
        be_env["PORT"] = str(args.backend_port)
        be_env["AI_SERVICE_URL"] = f"http://localhost:{args.ai_port}"
        be_env["BACKEND_API_BASE_URL"] = f"http://localhost:{args.backend_port}/api/v1"

        be_proc = subprocess.Popen(
            [npm_cmd, "run", "start:dev"],
            cwd=str(BACKEND_DIR),
            env=be_env,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
        processes.append(("NestJS Backend", be_proc))
        threading.Thread(
            target=stream_output,
            args=(be_proc.stdout, f"[BE :{args.backend_port}]", GREEN),
            daemon=True,
        ).start()

        # 3. Start Flutter Frontend (apps/fe)
        flutter_cmd = (
            shutil.which("flutter.bat") or shutil.which("flutter") or "flutter"
        )
        fe_args = [
            flutter_cmd,
            "run",
            "-d",
            args.device,
            f"--dart-define=API_BASE_URL=http://localhost:{args.backend_port}/api/v1",
        ]
        if args.device in ("edge", "chrome", "web-server"):
            fe_args.extend(["--web-port", str(args.web_port)])

        fe_proc_holder: list[subprocess.Popen | None] = [None]
        fe_restart_count = 0

        def spawn_flutter_fe() -> subprocess.Popen:
            proc = subprocess.Popen(
                fe_args,
                cwd=str(FE_DIR),
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                encoding="utf-8",
                errors="replace",
            )
            fe_proc_holder[0] = proc
            threading.Thread(
                target=stream_output,
                args=(proc.stdout, f"[FE :{args.device}]", MAGENTA),
                daemon=True,
            ).start()
            return proc

        if not args.no_fe:
            time.sleep(2.0)  # Đợi Backend & AI khởi động trước 2s
            fe_proc = spawn_flutter_fe()
            processes.append(("Flutter FE", fe_proc))

            def forward_stdin_to_flutter() -> None:
                try:
                    for line in sys.stdin:
                        cmd = line.strip()
                        if not cmd:
                            continue
                        current_proc = fe_proc_holder[0]
                        if current_proc is not None and current_proc.poll() is None and current_proc.stdin:
                            current_proc.stdin.write(cmd[0])
                            current_proc.stdin.flush()
                        elif cmd[0].upper() == "R":
                            print(f"{YELLOW}🔄 Đang khởi động lại Flutter FE...{RESET}")
                            new_proc = spawn_flutter_fe()
                            for idx, (pname, _) in enumerate(processes):
                                if pname == "Flutter FE":
                                    processes[idx] = ("Flutter FE", new_proc)
                except Exception:
                    pass

            threading.Thread(
                target=forward_stdin_to_flutter,
                daemon=True,
            ).start()

        print(
            f"{YELLOW}💡 Gõ 'R' + Enter trong Terminal để Hot Restart Flutter (tránh bấm F5 trên trình duyệt khi đang gắn gỡ lỗi DWDS), hoặc nhấn Ctrl+C để dừng cả 3 dịch vụ.{RESET}\n"
        )

        # Keep running while processes are alive
        while True:
            time.sleep(1.0)
            for idx, (name, proc) in enumerate(list(processes)):
                ret = proc.poll()
                if ret is not None and ret != 0:
                    if name == "Flutter FE" and fe_restart_count < 3:
                        fe_restart_count += 1
                        print(
                            f"\n{YELLOW}⚠ Kết nối trình duyệt [Flutter FE] bị ngắt (mã {ret}). Tự động khởi động lại Flutter FE (lần {fe_restart_count}/3)...{RESET}\n"
                        )
                        time.sleep(1.5)
                        new_proc = spawn_flutter_fe()
                        processes[idx] = ("Flutter FE", new_proc)
                        continue
                    print(
                        f"\n{RED}✖ Dịch vụ [{name}] đã dừng với mã lỗi {ret}. Đang đóng các dịch vụ còn lại...{RESET}"
                    )
                    return ret

    except KeyboardInterrupt:
        print(f"\n{YELLOW}🛑 Đang dừng toàn bộ dịch vụ ReMarket (AI + Backend + FE)...{RESET}")
    finally:
        for name, proc in processes:
            kill_process_tree(proc)
        print(f"{GREEN}✔ Đã đóng toàn bộ dịch vụ an toàn.{RESET}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
