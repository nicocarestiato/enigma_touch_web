import json
import os
import subprocess
import sys
from pathlib import Path

os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")

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
    preferred = (
        "videostoria_pi.mp4",
        "story_pi.mp4",
        "storia_pi.mp4",
        "story.mp4",
        "storia.mp4",
        "video.mp4",
    )
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
    path.write_text(
        json.dumps(payload, ensure_ascii=True, indent=2) + "\n",
        encoding="utf-8",
    )


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
        from PySide6.QtQml import QQmlApplicationEngine
    except ModuleNotFoundError:
        try:
            from PyQt6.QtCore import QUrl
            from PyQt6.QtGui import QGuiApplication
            from PyQt6.QtQml import QQmlApplicationEngine
        except ModuleNotFoundError:
            root = Path(__file__).resolve().parent
            venv_python = root / ".venv" / "Scripts" / "python.exe"
            print("[FATAL] Qt bindings non trovati nell'interprete corrente.")
            if venv_python.exists():
                print(f"[HINT] Avvia con: {venv_python} app.py")
            else:
                print("[HINT] Installa dipendenze: pip install PySide6")
                print("[HINT] Oppure su Raspberry Pi OS lancia: ./install_pi5_enigma.sh")
            return 1

    from simulation_controller import SimulationController

    root = Path(__file__).resolve().parent
    config_path = root / "config.json"
    config = _load_config(config_path)
    assets = root / "ui" / "assets"

    sfondo = assets / "sfondo.png"
    audio = assets / "audio1.mp3"
    story = assets / "story.txt"
    gallery_dir = assets / "gallery"
    story_video = _find_story_video(assets)

    print("[BOOT] root:", root)
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
    start_fullscreen = bool(config["start_fullscreen"])
    if sys.platform.startswith("linux"):
        start_fullscreen = True
    print("[BOOT] start page:", startup_page)
    print("[BOOT] fullscreen :", start_fullscreen)

    app = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()
    sim_controller = SimulationController()

    gpio_bridge = None

    try:
        from pico_serial_bridge import PicoSerialBridge
    except ModuleNotFoundError:
        PicoSerialBridge = None

    if PicoSerialBridge is not None:
        pico_bridge = PicoSerialBridge()
        if pico_bridge.available:
            gpio_bridge = pico_bridge
            print(f"[PICO] bridge attivo su {pico_bridge.port}")
        else:
            print(f"[PICO] bridge non attivo: {pico_bridge.error_message}")

    try:
        from gpio_bridge import GpioBridge
    except ModuleNotFoundError:
        GpioBridge = None

    if gpio_bridge is None and GpioBridge is not None:
        gpio_bridge = GpioBridge()
        if gpio_bridge.available:
            print("[GPIO] bridge attivo")
            if gpio_bridge.error_message:
                print(f"[GPIO] attenzione: {gpio_bridge.error_message}")
        else:
            print(f"[GPIO] bridge non attivo: {gpio_bridge.error_message}")

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
            "gpioBridge": gpio_bridge,
            "initialPage": startup_page,
            "startFullscreen": start_fullscreen,
        }
    )

    qml_path = root / "ui" / "Main.qml"
    engine.load(QUrl.fromLocalFile(str(qml_path)))

    if not engine.rootObjects():
        print("[FATAL] QML failed to load")
        return 1

    root_object = engine.rootObjects()[0]

    if gpio_bridge is not None and gpio_bridge.available:
        def _page() -> str:
            page = root_object.property("page")
            return page if isinstance(page, str) else ""

        def _set_page(name: str) -> None:
            root_object.setProperty("page", name)

        def _full_reset() -> None:
            # Restore the machine to a known baseline before returning to the initial disclaimer.
            sim_controller.cancelChallenge()
            sim_controller.timelineClear()
            sim_controller.clearPlugboard()
            sim_controller.setRotorOrder("I", "II", "III")
            sim_controller.setReflector("B")
            sim_controller.setPositions("AAA")
            sim_controller.clearStreams()
            sim_controller.resetMachine()
            root_object.setProperty("gpioSelectedRotor", 0)
            _set_page("disclaimer")

        def _cycle_mode() -> None:
            page = _page()
            if page == "home":
                _set_page("machine")
                return
            if page == "machine":
                _set_page("story")
                return
            if page == "story":
                _set_page("home")
                return
            _set_page("home")

        def _go_home() -> None:
            if _page() != "home":
                _set_page("home")

        def _rotate_rotor(index: int, delta: int) -> None:
            if _page() == "machine":
                sim_controller.rotateRotor(int(index), int(delta))
                root_object.setProperty("gpioSelectedRotor", int(index))

        def _reset_rotor_to_a(index: int) -> None:
            if _page() != "machine":
                return

            positions = sim_controller.property("startPositions")
            if not isinstance(positions, str) or len(positions) != 3:
                positions = "AAA"

            rotor_index = int(index)
            if rotor_index < 0 or rotor_index > 2:
                return

            chars = list(positions)
            chars[rotor_index] = "A"
            sim_controller.setPositions("".join(chars))
            root_object.setProperty("gpioSelectedRotor", rotor_index)

        def _legacy_encoder_press() -> None:
            if _page() == "machine":
                selected = root_object.property("gpioSelectedRotor")
                if not isinstance(selected, int):
                    selected = 0
                root_object.setProperty("gpioSelectedRotor", (selected + 1) % 3)

        def _system_power(action: str) -> None:
            if action not in {"poweroff", "reboot"}:
                return
            print(f"[POWER] systemctl {action}")
            try:
                subprocess.Popen(["systemctl", action])
            except Exception as exc:
                print(f"[POWER] errore: {exc}")

        gpio_bridge.resetHeld.connect(_full_reset)
        gpio_bridge.modePressed.connect(_cycle_mode)
        gpio_bridge.homePressed.connect(_go_home)
        gpio_bridge.encoderPressed.connect(_legacy_encoder_press)

        rotor_rotate = getattr(gpio_bridge, "rotorRotate", None)
        if rotor_rotate is not None:
            rotor_rotate.connect(_rotate_rotor)

        rotor_pressed = getattr(gpio_bridge, "rotorPressed", None)
        if rotor_pressed is not None:
            rotor_pressed.connect(_reset_rotor_to_a)

        power_off = getattr(gpio_bridge, "powerOffRequested", None)
        if power_off is not None:
            power_off.connect(lambda: _system_power("poweroff"))

        power_reboot = getattr(gpio_bridge, "powerRebootRequested", None)
        if power_reboot is not None:
            power_reboot.connect(lambda: _system_power("reboot"))

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
