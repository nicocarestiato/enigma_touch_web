import json
import os
import sys
from pathlib import Path

VALID_PAGES = {"boot", "intro", "home", "machine", "story"}
DEFAULT_CONFIG = {
    "rotors_pos": "DDA",
    "plugboard": "",
    "text_in": "",
    "text_out": "",
    "last_screen": "boot",
    "start_fullscreen": False,
}


def _gallery_sort_key(path: Path) -> tuple[int, object]:
    stem = path.stem.strip()
    if stem.isdigit():
        return (0, int(stem))
    return (1, stem.lower())


def _find_story_video(assets_dir: Path) -> Path | None:
    preferred = ("story.mp4", "storia.mp4", "video.mp4")
    for name in preferred:
        candidate = assets_dir / name
        if candidate.exists():
            return candidate

    candidates: list[Path] = []
    for ext in (".mp4", ".mov", ".m4v", ".webm", ".mkv", ".avi"):
        candidates.extend(assets_dir.glob(f"*{ext}"))

    if not candidates:
        return None

    return sorted(candidates, key=lambda p: p.name.lower())[0]


def _read_text(path: Path) -> str:
    encodings = ("utf-8", "utf-8-sig", "cp1252", "latin-1")
    for enc in encodings:
        try:
            return path.read_text(encoding=enc)
        except Exception:
            pass
    return ""


def _write_json(path: Path, payload: dict) -> None:
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            json.dumps(payload, ensure_ascii=True, indent=2) + "\n",
            encoding="utf-8",
        )
    except Exception as exc:
        print(f"[WARN] Config non scrivibile: {path} ({exc})")


def _load_config(path: Path) -> dict:
    data: dict = {}
    changed = False

    if path.exists():
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
            if not isinstance(data, dict):
                data = {}
                changed = True
        except Exception:
            data = {}
            changed = True
    else:
        changed = True

    # Migrate legacy key.
    legacy_last = data.pop("lastScreen", None)
    if legacy_last is not None and "last_screen" not in data:
        data["last_screen"] = legacy_last
        changed = True

    for key, value in DEFAULT_CONFIG.items():
        if key not in data:
            data[key] = value
            changed = True

    if data.get("last_screen") not in VALID_PAGES:
        data["last_screen"] = DEFAULT_CONFIG["last_screen"]
        changed = True

    data["start_fullscreen"] = bool(data.get("start_fullscreen", False))

    if changed:
        _write_json(path, data)

    return data


def main() -> int:
    try:
        from PySide6.QtCore import QUrl
        from PySide6.QtGui import QGuiApplication
        from PySide6.QtMultimedia import QMediaPlayer  # Ensure multimedia plugins are bundled in PyInstaller.
        from PySide6.QtQml import QQmlApplicationEngine
        from simulation_controller import SimulationController
    except ModuleNotFoundError:
        root = Path(__file__).resolve().parent
        venv_python = root / ".venv" / "Scripts" / "python.exe"
        print("[FATAL] PySide6 non installato nell'interprete corrente.")
        if venv_python.exists():
            print(f"[HINT] Avvia con: {venv_python} app.py")
        else:
            print("[HINT] Installa dipendenze: pip install PySide6")
        return 1

    source_root = Path(__file__).resolve().parent
    frozen = bool(getattr(sys, "frozen", False))
    bundle_root = Path(getattr(sys, "_MEIPASS", source_root))
    app_root = Path(sys.executable).resolve().parent if frozen else source_root

    config_path = app_root / "config.json"
    if frozen:
        try:
            config_path.parent.mkdir(parents=True, exist_ok=True)
            with config_path.open("a", encoding="utf-8"):
                pass
        except Exception:
            local_app_data = Path(os.getenv("LOCALAPPDATA", str(Path.home())))
            config_path = local_app_data / "EnigmaTouch" / "config.json"
    config = _load_config(config_path)
    assets = bundle_root / "ui" / "assets"

    sfondo = assets / "sfondo.png"
    audio = assets / "audio1.mp3"
    story = assets / "story.txt"
    gallery_dir = assets / "gallery"
    story_video = _find_story_video(assets)

    print("[BOOT] app root:", app_root)
    print("[BOOT] bundle root:", bundle_root)
    print("[BOOT] assets:", assets)
    print("[BOOT] sfondo:", sfondo, "exists:", sfondo.exists())
    print("[BOOT] audio :", audio, "exists:", audio.exists())
    print("[BOOT] story :", story, "exists:", story.exists())
    print("[BOOT] gallery:", gallery_dir, "exists:", gallery_dir.exists())
    print("[BOOT] video :", story_video if story_video else "none")

    story_text = _read_text(story)
    print("[BOOT] story len:", len(story_text))
    if story_text:
        print("[BOOT] story head:", repr(story_text[:180]))
    startup_page = "boot"
    print("[BOOT] start page:", startup_page)
    print("[BOOT] fullscreen :", config["start_fullscreen"])

    app = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()
    sim_controller = SimulationController()

    # Keep intro carousel limited to numbered gallery images (1.png, 2.png, ...).
    # This avoids showing helper/info assets dropped in the same folder.
    gallery_files = sorted(
        [path for path in gallery_dir.glob("*.png") if path.stem.strip().isdigit()],
        key=_gallery_sort_key,
    )
    gallery_urls = [QUrl.fromLocalFile(str(path)).toString() for path in gallery_files]
    print("[BOOT] gallery images:", len(gallery_urls))

    # URL locali per QML
    sfondo_url = QUrl.fromLocalFile(str(sfondo)) if sfondo.exists() else QUrl()
    audio_url = QUrl.fromLocalFile(str(audio)) if audio.exists() else QUrl()
    story_video_url = QUrl.fromLocalFile(str(story_video)) if story_video else QUrl()

    engine.setInitialProperties(
        {
            "sfondoAssetUrl": sfondo_url,
            "audioAssetUrl": audio_url,
            "storyAssetText": story_text,
            "storyVideoAssetUrl": story_video_url,
            "galleryAssetUrls": gallery_urls,
            "simController": sim_controller,
            "initialPage": startup_page,
            "startFullscreen": config["start_fullscreen"],
        }
    )

    qml_path = bundle_root / "ui" / "Main.qml"
    engine.load(QUrl.fromLocalFile(str(qml_path)))

    if not engine.rootObjects():
        print("[FATAL] QML failed to load")
        return 1

    root_object = engine.rootObjects()[0]

    def _persist_state() -> None:
        page = root_object.property("page")
        fullscreen = root_object.property("isFullscreen")
        if isinstance(page, str) and page in VALID_PAGES:
            config["last_screen"] = page
        config["start_fullscreen"] = bool(fullscreen)
        _write_json(config_path, config)

    app.aboutToQuit.connect(_persist_state)

    return app.exec()


if __name__ == "__main__":
    raise SystemExit(main())
