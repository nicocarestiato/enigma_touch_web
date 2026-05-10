from __future__ import annotations

import random
import time
from typing import Dict, List, Tuple

try:
    from PySide6.QtCore import QObject, Property, Signal, Slot
    from PySide6.QtGui import QGuiApplication
except ModuleNotFoundError:
    from PyQt6.QtCore import QObject, pyqtProperty as Property, pyqtSignal as Signal, pyqtSlot as Slot
    from PyQt6.QtGui import QGuiApplication

from enigma import ALPHABET, Enigma, Plugboard, REFLECTORS, ROTOR_SPECS


class SimulationController(QObject):
    stateChanged = Signal()

    CHALLENGE_WORDS: Tuple[str, ...] = (
        "ENIGMA",
        "ROTORE",
        "CIPHER",
        "KRIEG",
        "UHRBOX",
        "BLETCHLEY",
        "TURING",
        "NOTCH",
        "STREAM",
        "CRYPTO",
    )

    def __init__(self) -> None:
        super().__init__()
        self._rotor_left = "I"
        self._rotor_middle = "II"
        self._rotor_right = "III"
        self._reflector = "B"
        self._start_positions = "AAA"
        self._current_positions = "AAA"
        self._plug_pairs: List[Tuple[str, str]] = []

        self._input_buffer = ""
        self._output_buffer = ""
        self._batch_output = ""
        self._last_step = "Pronto."
        self._trace_lines: List[str] = []
        self._status_message = "Configurazione iniziale pronta."

        self._signal_path_headline = "Percorso segnale in attesa."
        self._signal_path_text = "Digita una lettera per vedere il percorso completo."

        self._timeline_events: List[Dict[str, str]] = []
        self._timeline_index = -1
        self._timeline_current_summary = "Nessuno step selezionato."
        self._timeline_current_details = "La timeline si riempie durante la simulazione."

        self._challenge_active = False
        self._challenge_solved = False
        self._challenge_plain = ""
        self._challenge_cipher = ""
        self._challenge_solution_positions = ""
        self._challenge_started_at = 0.0
        self._challenge_attempts = 0
        self._challenge_score = 0
        self._challenge_status = "Nessuna missione attiva."
        self._challenge_locked_rotors: Tuple[str, str, str] = ("I", "II", "III")
        self._challenge_locked_reflector = "B"
        self._challenge_locked_plug_pairs: List[Tuple[str, str]] = []

        self._plugboard = Plugboard()
        self._machine = Enigma(
            rotor_names=(self._rotor_left, self._rotor_middle, self._rotor_right),
            reflector=self._reflector,
            plugboard=self._plugboard,
        )
        self._machine.set_positions(*self._start_positions)

    def _emit(self) -> None:
        self.stateChanged.emit()

    def _normalize_positions(self, value: str) -> str:
        clean = (value or "").upper().strip()
        if len(clean) != 3:
            return ""
        if any(ch not in ALPHABET for ch in clean):
            return ""
        return clean

    def _clear_runtime(self) -> None:
        self._input_buffer = ""
        self._output_buffer = ""
        self._batch_output = ""
        self._last_step = "Pronto."
        self._trace_lines.clear()
        self._signal_path_headline = "Percorso segnale in attesa."
        self._signal_path_text = "Digita una lettera per vedere il percorso completo."

    def _trace(self, line: str) -> None:
        self._trace_lines.append(line)
        if len(self._trace_lines) > 90:
            self._trace_lines = self._trace_lines[-90:]

    def _apply_plug_pairs(self) -> None:
        self._plugboard.clear()
        for a, b in self._plug_pairs:
            self._plugboard.add_pair(a, b)

    def _rebuild_machine(self, keep_current_position: bool = True, clear_runtime: bool = False) -> None:
        rotor_names = (self._rotor_left, self._rotor_middle, self._rotor_right)
        self._plugboard = Plugboard()
        self._apply_plug_pairs()
        self._machine = Enigma(
            rotor_names=rotor_names,
            reflector=self._reflector,
            plugboard=self._plugboard,
        )

        target = self._current_positions if keep_current_position else self._start_positions
        normalized = self._normalize_positions(target) or "AAA"
        self._machine.set_positions(*normalized)
        self._current_positions = self._machine.get_positions()

        if clear_runtime:
            self._clear_runtime()

    def _sorted_pairs(self) -> str:
        if not self._plug_pairs:
            return "Nessuna connessione"
        pairs = [f"{a}-{b}" for a, b in self._plug_pairs]
        return ", ".join(sorted(pairs))

    def _shift_char(self, ch: str, delta: int) -> str:
        base = ord(ch) - ord("A")
        shifted = (base + delta) % 26
        return chr(ord("A") + shifted)

    def _format_signal_path(self, trace: Dict[str, object]) -> str:
        forward = trace.get("forward", [])
        backward = trace.get("backward", [])

        forward_chunks = [
            f"{step['rotor']}({step['position']}): {step['in']}->{step['out']}"
            for step in forward
        ]
        backward_chunks = [
            f"{step['rotor']}({step['position']}): {step['in']}->{step['out']}"
            for step in backward
        ]

        lines = [
            f"Posizioni: {trace.get('positions_before', '---')} -> {trace.get('positions_after', '---')}",
            f"Plug IN: {trace.get('input', '-')} -> {trace.get('plug_in', '-')}",
            "Forward: " + (" | ".join(forward_chunks) if forward_chunks else "n/a"),
            f"Reflector {trace.get('reflector_name', '-')}: {trace.get('reflector_in', '-')} -> {trace.get('reflector_out', '-')}",
            "Backward: " + (" | ".join(backward_chunks) if backward_chunks else "n/a"),
            f"Plug OUT: {trace.get('reflector_out', '-')} -> {trace.get('plug_out', '-')}",
            f"Output: {trace.get('output', '-')}",
        ]
        return "\n".join(lines)

    def _set_signal_path(self, trace: Dict[str, object]) -> None:
        self._signal_path_headline = (
            f"{trace.get('input', '-')} -> {trace.get('output', '-')} | "
            f"{trace.get('positions_before', '---')} -> {trace.get('positions_after', '---')}"
        )
        self._signal_path_text = self._format_signal_path(trace)

    def _record_timeline(self, summary: str, details: str, kind: str = "event") -> None:
        self._timeline_events.append(
            {
                "kind": kind,
                "summary": summary,
                "details": details,
            }
        )
        if len(self._timeline_events) > 240:
            overflow = len(self._timeline_events) - 240
            self._timeline_events = self._timeline_events[overflow:]
            self._timeline_index = max(-1, self._timeline_index - overflow)

        self._timeline_index = len(self._timeline_events) - 1
        self._update_timeline_current()

    def _update_timeline_current(self) -> None:
        if self._timeline_index < 0 or self._timeline_index >= len(self._timeline_events):
            self._timeline_current_summary = "Nessuno step selezionato."
            self._timeline_current_details = "La timeline si riempie durante la simulazione."
            return
        event = self._timeline_events[self._timeline_index]
        self._timeline_current_summary = event["summary"]
        self._timeline_current_details = event["details"]

    def _timeline_recent_text(self) -> str:
        if not self._timeline_events:
            return "Timeline vuota."

        start = max(0, len(self._timeline_events) - 14)
        lines: List[str] = []
        for local_idx, event in enumerate(self._timeline_events[start:]):
            global_idx = start + local_idx
            marker = ">" if global_idx == self._timeline_index else " "
            lines.append(f"{marker} [{global_idx + 1:03d}] {event['summary']}")
        return "\n".join(lines)

    def _recompute_runtime_from_input(self, text: str) -> None:
        self._machine.set_positions(*self._start_positions)
        self._current_positions = self._machine.get_positions()
        self._input_buffer = ""
        self._output_buffer = ""
        self._batch_output = ""

        last_trace: Dict[str, object] | None = None
        for ch in text:
            out, trace = self._machine.encode_char_trace(ch)
            self._input_buffer += ch
            self._output_buffer += out
            self._current_positions = trace.get("positions_after", self._current_positions)
            last_trace = trace

        if last_trace is not None:
            self._set_signal_path(last_trace)
            self._last_step = (
                f"{last_trace.get('input', '-')} -> {last_trace.get('output', '-')} | "
                f"{last_trace.get('positions_before', '---')} -> {last_trace.get('positions_after', '---')}"
            )
        else:
            self._last_step = "Pronto."
            self._signal_path_headline = "Percorso segnale in attesa."
            self._signal_path_text = "Digita una lettera per vedere il percorso completo."

    def _challenge_elapsed_seconds(self) -> int:
        if self._challenge_started_at <= 0:
            return 0
        return int(max(0, time.time() - self._challenge_started_at))

    def _challenge_config_matches(self) -> bool:
        rotors_ok = (
            self._rotor_left,
            self._rotor_middle,
            self._rotor_right,
        ) == self._challenge_locked_rotors
        reflector_ok = self._reflector == self._challenge_locked_reflector
        plugs_ok = sorted(self._plug_pairs) == sorted(self._challenge_locked_plug_pairs)
        return rotors_ok and reflector_ok and plugs_ok

    def _challenge_config_summary(self) -> str:
        plugs = "Nessuno"
        if self._challenge_locked_plug_pairs:
            plugs = ", ".join(f"{a}-{b}" for a, b in sorted(self._challenge_locked_plug_pairs))
        return (
            f"Rotori {self._challenge_locked_rotors[0]}-{self._challenge_locked_rotors[1]}-{self._challenge_locked_rotors[2]} | "
            f"Reflector {self._challenge_locked_reflector} | Plugboard {plugs}"
        )

    @Slot(str, str, str)
    def setRotorOrder(self, left: str, middle: str, right: str) -> None:
        left = (left or "").strip().upper()
        middle = (middle or "").strip().upper()
        right = (right or "").strip().upper()

        if left not in ROTOR_SPECS or middle not in ROTOR_SPECS or right not in ROTOR_SPECS:
            self._status_message = "Rotori non validi."
            self._emit()
            return
        if len({left, middle, right}) != 3:
            self._status_message = "I tre rotori devono essere diversi."
            self._emit()
            return

        self._rotor_left = left
        self._rotor_middle = middle
        self._rotor_right = right
        self._rebuild_machine(keep_current_position=True, clear_runtime=True)
        self._status_message = f"Rotori impostati: {left}-{middle}-{right}"
        self._trace(self._status_message)
        self._record_timeline(self._status_message, "Configurazione aggiornata.", "config")
        self._emit()

    @Slot(str)
    def setReflector(self, reflector: str) -> None:
        name = (reflector or "").strip().upper()
        if name not in REFLECTORS:
            self._status_message = "Reflector non valido."
            self._emit()
            return
        self._reflector = name
        self._rebuild_machine(keep_current_position=True, clear_runtime=True)
        self._status_message = f"Reflector impostato: {name}"
        self._trace(self._status_message)
        self._record_timeline(self._status_message, "Configurazione aggiornata.", "config")
        self._emit()

    @Slot(str)
    def setPositions(self, positions: str) -> None:
        normalized = self._normalize_positions(positions)
        if not normalized:
            self._status_message = "Posizioni non valide. Usa 3 lettere (es. DDA)."
            self._emit()
            return
        self._start_positions = normalized
        self._current_positions = normalized
        self._machine.set_positions(*normalized)
        self._clear_runtime()
        self._status_message = f"Posizioni impostate: {normalized}"
        self._trace(self._status_message)
        self._record_timeline(self._status_message, "Posizione iniziale cambiata.", "config")
        self._emit()

    @Slot(int, int)
    def rotateRotor(self, index: int, delta: int) -> None:
        if index < 0 or index > 2:
            self._status_message = "Indice rotore non valido."
            self._emit()
            return
        if delta == 0:
            return

        step = 1 if delta > 0 else -1
        current = list(self._current_positions)
        current[index] = self._shift_char(current[index], step)
        updated = "".join(current)

        self._start_positions = updated
        self._current_positions = updated
        self._machine.set_positions(*updated)
        self._clear_runtime()
        self._status_message = f"Rotore {index + 1} -> {updated[index]} (posizioni {updated})"
        self._trace(self._status_message)
        self._record_timeline(self._status_message, "Regolazione manuale rotore.", "config")
        self._emit()

    @Slot(str, str)
    def addPlugPair(self, a: str, b: str) -> None:
        left = (a or "").strip().upper()[:1]
        right = (b or "").strip().upper()[:1]

        if left not in ALPHABET or right not in ALPHABET:
            self._status_message = "Plugboard: usa due lettere valide."
            self._emit()
            return
        if left == right:
            self._status_message = "Plugboard: lettere uguali non consentite."
            self._emit()
            return

        filtered: List[Tuple[str, str]] = []
        for x, y in self._plug_pairs:
            if left in (x, y) or right in (x, y):
                continue
            filtered.append((x, y))

        pair = tuple(sorted((left, right)))
        filtered.append(pair)
        self._plug_pairs = filtered

        self._rebuild_machine(keep_current_position=True, clear_runtime=False)
        self._status_message = f"Plugboard collegato: {pair[0]}-{pair[1]}"
        self._trace(self._status_message)
        self._record_timeline(self._status_message, "Connessione plugboard aggiornata.", "config")
        self._emit()

    @Slot(str)
    def removePlugByLetter(self, letter: str) -> None:
        ch = (letter or "").strip().upper()[:1]
        if ch not in ALPHABET:
            self._status_message = "Plugboard: lettera non valida."
            self._emit()
            return

        before = len(self._plug_pairs)
        self._plug_pairs = [(a, b) for a, b in self._plug_pairs if ch not in (a, b)]
        if len(self._plug_pairs) == before:
            self._status_message = f"Plugboard: nessuna connessione per {ch}."
            self._emit()
            return

        self._rebuild_machine(keep_current_position=True, clear_runtime=False)
        self._status_message = f"Plugboard: rimossa connessione di {ch}."
        self._trace(self._status_message)
        self._record_timeline(self._status_message, "Connessione plugboard rimossa.", "config")
        self._emit()

    @Slot()
    def clearPlugboard(self) -> None:
        self._plug_pairs.clear()
        self._rebuild_machine(keep_current_position=True, clear_runtime=False)
        self._status_message = "Plugboard azzerato."
        self._trace(self._status_message)
        self._record_timeline(self._status_message, "Plugboard svuotato.", "config")
        self._emit()

    @Slot(result=str)
    def resetMachine(self) -> str:
        self._machine.set_positions(*self._start_positions)
        self._current_positions = self._machine.get_positions()
        self._clear_runtime()
        self._status_message = f"Macchina resettata su {self._start_positions}."
        self._trace(self._status_message)
        self._record_timeline(self._status_message, "Reset completo.", "event")
        self._emit()
        return self._current_positions

    @Slot(result=str)
    def clearStreams(self) -> str:
        self._clear_runtime()
        self._status_message = "Stream puliti."
        self._trace(self._status_message)
        self._record_timeline(self._status_message, "Input e output svuotati.", "event")
        self._emit()
        return "ok"

    @Slot(result=str)
    def clearInputStream(self) -> str:
        self._input_buffer = ""
        self._status_message = "Input stream svuotato."
        self._trace(self._status_message)
        self._record_timeline(self._status_message, "Solo input svuotato.", "event")
        self._emit()
        return "ok"

    @Slot(result=str)
    def backspaceInputStream(self) -> str:
        if not self._input_buffer:
            return ""
        reduced = self._input_buffer[:-1]
        self._recompute_runtime_from_input(reduced)
        self._status_message = "Input stream: rimosso ultimo carattere."
        self._trace(self._status_message)
        self._record_timeline(self._status_message, "Ricostruzione output dopo backspace.", "event")
        self._emit()
        return self._input_buffer

    @Slot(result=str)
    def copyOutputToClipboard(self) -> str:
        app = QGuiApplication.instance()
        if app is None:
            self._status_message = "Clipboard non disponibile."
            self._emit()
            return ""

        app.clipboard().setText(self._output_buffer)
        self._status_message = "Output copiato negli appunti."
        self._trace(self._status_message)
        self._record_timeline(self._status_message, "Output copiato.", "event")
        self._emit()
        return self._output_buffer

    @Slot(str, result=str)
    def stepChar(self, value: str) -> str:
        ch = (value or "")[:1]
        if not ch:
            return ""

        upper = ch.upper()
        out, trace = self._machine.encode_char_trace(upper)
        before = trace.get("positions_before", self._machine.get_positions())
        after = trace.get("positions_after", self._machine.get_positions())
        self._current_positions = str(after)

        self._input_buffer += upper
        self._output_buffer += out
        self._last_step = f"{upper} -> {out} | {before} -> {after}"
        self._set_signal_path(trace)
        self._trace(self._last_step)
        self._record_timeline(self._last_step, self._signal_path_text, "step")
        self._status_message = "Step eseguito."
        self._emit()
        return out

    @Slot(str, result=str)
    def encodeBatch(self, text: str) -> str:
        payload = text or ""
        before = self._machine.get_positions()
        out = self._machine.encode_text(payload)
        after = self._machine.get_positions()
        self._current_positions = after

        self._batch_output = out
        self._last_step = f"BATCH {len(payload)} caratteri | {before} -> {after}"
        self._trace(self._last_step)
        self._record_timeline(self._last_step, "Batch mode.", "batch")
        self._status_message = "Testo cifrato."
        self._emit()
        return out

    @Slot()
    def timelinePrev(self) -> None:
        if not self._timeline_events:
            return
        self._timeline_index = max(0, self._timeline_index - 1)
        self._update_timeline_current()
        self._status_message = f"Replay: step {self._timeline_index + 1}/{len(self._timeline_events)}"
        self._emit()

    @Slot()
    def timelineNext(self) -> None:
        if not self._timeline_events:
            return
        self._timeline_index = min(len(self._timeline_events) - 1, self._timeline_index + 1)
        self._update_timeline_current()
        self._status_message = f"Replay: step {self._timeline_index + 1}/{len(self._timeline_events)}"
        self._emit()

    @Slot(int)
    def timelineSelect(self, index: int) -> None:
        if not self._timeline_events:
            return
        clamped = max(0, min(len(self._timeline_events) - 1, int(index)))
        self._timeline_index = clamped
        self._update_timeline_current()
        self._status_message = f"Replay: step {self._timeline_index + 1}/{len(self._timeline_events)}"
        self._emit()

    @Slot()
    def timelineClear(self) -> None:
        self._timeline_events.clear()
        self._timeline_index = -1
        self._update_timeline_current()
        self._status_message = "Timeline svuotata."
        self._trace(self._status_message)
        self._emit()

    @Slot(result=str)
    def startChallenge(self) -> str:
        self._challenge_locked_rotors = (self._rotor_left, self._rotor_middle, self._rotor_right)
        self._challenge_locked_reflector = self._reflector
        self._challenge_locked_plug_pairs = list(self._plug_pairs)
        self._challenge_plain = random.choice(self.CHALLENGE_WORDS)
        self._challenge_solution_positions = "".join(random.choice(ALPHABET) for _ in range(3))

        challenge_plugboard = Plugboard()
        for a, b in self._challenge_locked_plug_pairs:
            challenge_plugboard.add_pair(a, b)

        challenge_machine = Enigma(
            rotor_names=self._challenge_locked_rotors,
            reflector=self._challenge_locked_reflector,
            plugboard=challenge_plugboard,
        )
        challenge_machine.set_positions(*self._challenge_solution_positions)
        self._challenge_cipher = challenge_machine.encode_text(self._challenge_plain)

        self._challenge_active = True
        self._challenge_solved = False
        self._challenge_attempts = 0
        self._challenge_score = 0
        self._challenge_started_at = time.time()
        self._challenge_status = (
            "Missione avviata: imposta una posizione iniziale valida e digita il plaintext target."
        )
        self._clear_runtime()
        self._machine.set_positions(*self._start_positions)
        self._current_positions = self._machine.get_positions()

        detail = (
            f"Plain: {self._challenge_plain}\n"
            f"Cipher target: {self._challenge_cipher}\n"
            f"{self._challenge_config_summary()}"
        )
        self._trace("Challenge avviata.")
        self._record_timeline("Challenge avviata", detail, "challenge")
        self._status_message = "Challenge mode attivo."
        self._emit()
        return self._challenge_cipher

    @Slot(result=str)
    def submitChallenge(self) -> str:
        if not self._challenge_active and not self._challenge_solved:
            self._challenge_status = "Nessuna missione attiva."
            self._emit()
            return self._challenge_status
        if self._challenge_solved:
            self._challenge_status = f"Missione gia completata. Score: {self._challenge_score}"
            self._emit()
            return self._challenge_status

        self._challenge_attempts += 1

        if not self._challenge_config_matches():
            self._challenge_status = (
                f"Tentativo {self._challenge_attempts}: configurazione diversa da quella della missione."
            )
            self._trace(self._challenge_status)
            self._emit()
            return self._challenge_status

        if self._input_buffer != self._challenge_plain:
            self._challenge_status = (
                f"Tentativo {self._challenge_attempts}: digita esattamente '{self._challenge_plain}'."
            )
            self._trace(self._challenge_status)
            self._emit()
            return self._challenge_status

        if self._output_buffer == self._challenge_cipher:
            elapsed = self._challenge_elapsed_seconds()
            self._challenge_solved = True
            self._challenge_active = False
            self._challenge_score = max(120, 1800 - (self._challenge_attempts - 1) * 120 - elapsed * 4)
            self._challenge_status = (
                f"Missione completata in {elapsed}s con {self._challenge_attempts} tentativi. "
                f"Score: {self._challenge_score}"
            )
            self._trace(self._challenge_status)
            self._record_timeline("Challenge completata", self._challenge_status, "challenge")
            self._status_message = "Challenge completata."
            self._emit()
            return self._challenge_status

        idx = 0
        max_len = min(len(self._output_buffer), len(self._challenge_cipher))
        while idx < max_len and self._output_buffer[idx] == self._challenge_cipher[idx]:
            idx += 1

        if len(self._output_buffer) < len(self._challenge_cipher):
            hint = f"output troppo corto ({len(self._output_buffer)}/{len(self._challenge_cipher)})."
        elif idx < len(self._challenge_cipher):
            hint = (
                f"primo mismatch in posizione {idx + 1}: atteso {self._challenge_cipher[idx]}, "
                f"ottenuto {self._output_buffer[idx]}."
            )
        else:
            hint = "output non coerente con la missione."

        self._challenge_status = f"Tentativo {self._challenge_attempts}: {hint}"
        self._trace(self._challenge_status)
        self._emit()
        return self._challenge_status

    @Slot(result=str)
    def cancelChallenge(self) -> str:
        self._challenge_active = False
        if not self._challenge_solved:
            self._challenge_status = "Missione annullata."
        self._status_message = "Challenge mode disattivato."
        self._trace(self._challenge_status)
        self._record_timeline("Challenge fermata", self._challenge_status, "challenge")
        self._emit()
        return self._challenge_status

    @Slot(result=str)
    def revealChallengeSolution(self) -> str:
        if not self._challenge_active and not self._challenge_solved:
            return "---"
        self._challenge_status = (
            f"Soluzione missione: posizioni iniziali {self._challenge_solution_positions}."
        )
        self._trace(self._challenge_status)
        self._emit()
        return self._challenge_solution_positions

    @Slot(result=int)
    def challengeHeartbeat(self) -> int:
        if self._challenge_active:
            self._emit()
        return self._challenge_elapsed_seconds()

    @Property(str, notify=stateChanged)
    def rotorLeft(self) -> str:
        return self._rotor_left

    @Property(str, notify=stateChanged)
    def rotorMiddle(self) -> str:
        return self._rotor_middle

    @Property(str, notify=stateChanged)
    def rotorRight(self) -> str:
        return self._rotor_right

    @Property(str, notify=stateChanged)
    def reflector(self) -> str:
        return self._reflector

    @Property(str, notify=stateChanged)
    def startPositions(self) -> str:
        return self._start_positions

    @Property(str, notify=stateChanged)
    def currentPositions(self) -> str:
        return self._current_positions

    @Property(str, notify=stateChanged)
    def plugboardPairs(self) -> str:
        return self._sorted_pairs()

    @Property(str, notify=stateChanged)
    def inputBuffer(self) -> str:
        return self._input_buffer

    @Property(str, notify=stateChanged)
    def outputBuffer(self) -> str:
        return self._output_buffer

    @Property(str, notify=stateChanged)
    def batchOutput(self) -> str:
        return self._batch_output

    @Property(str, notify=stateChanged)
    def lastStep(self) -> str:
        return self._last_step

    @Property(str, notify=stateChanged)
    def traceLog(self) -> str:
        if not self._trace_lines:
            return ""
        return "\n".join(self._trace_lines[-18:])

    @Property(str, notify=stateChanged)
    def statusMessage(self) -> str:
        return self._status_message

    @Property(str, notify=stateChanged)
    def signalPathHeadline(self) -> str:
        return self._signal_path_headline

    @Property(str, notify=stateChanged)
    def signalPathText(self) -> str:
        return self._signal_path_text

    @Property(int, notify=stateChanged)
    def timelineCount(self) -> int:
        return len(self._timeline_events)

    @Property(int, notify=stateChanged)
    def timelineIndex(self) -> int:
        return self._timeline_index

    @Property(str, notify=stateChanged)
    def timelineCurrentSummary(self) -> str:
        return self._timeline_current_summary

    @Property(str, notify=stateChanged)
    def timelineCurrentDetails(self) -> str:
        return self._timeline_current_details

    @Property(str, notify=stateChanged)
    def timelineRecent(self) -> str:
        return self._timeline_recent_text()

    @Property(bool, notify=stateChanged)
    def challengeActive(self) -> bool:
        return self._challenge_active

    @Property(bool, notify=stateChanged)
    def challengeSolved(self) -> bool:
        return self._challenge_solved

    @Property(str, notify=stateChanged)
    def challengePlain(self) -> str:
        return self._challenge_plain

    @Property(str, notify=stateChanged)
    def challengeCipher(self) -> str:
        return self._challenge_cipher

    @Property(str, notify=stateChanged)
    def challengeConfig(self) -> str:
        if not self._challenge_active and not self._challenge_solved:
            return "Nessuna missione attiva."
        return self._challenge_config_summary()

    @Property(str, notify=stateChanged)
    def challengeStatus(self) -> str:
        return self._challenge_status

    @Property(int, notify=stateChanged)
    def challengeAttempts(self) -> int:
        return self._challenge_attempts

    @Property(int, notify=stateChanged)
    def challengeElapsed(self) -> int:
        return self._challenge_elapsed_seconds()

    @Property(int, notify=stateChanged)
    def challengeScore(self) -> int:
        return self._challenge_score
