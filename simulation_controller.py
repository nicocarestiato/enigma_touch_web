from __future__ import annotations

from typing import List, Tuple

from PySide6.QtCore import QObject, Property, Signal, Slot
from PySide6.QtGui import QGuiApplication

from enigma import ALPHABET, Enigma, Plugboard, REFLECTORS, ROTOR_SPECS


class SimulationController(QObject):
    stateChanged = Signal()

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

    def _trace(self, line: str) -> None:
        self._trace_lines.append(line)
        if len(self._trace_lines) > 80:
            self._trace_lines = self._trace_lines[-80:]

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

        # Remove any pair that already contains one of the two letters.
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
        self._emit()

    @Slot()
    def clearPlugboard(self) -> None:
        self._plug_pairs.clear()
        self._rebuild_machine(keep_current_position=True, clear_runtime=False)
        self._status_message = "Plugboard azzerato."
        self._trace(self._status_message)
        self._emit()

    @Slot(result=str)
    def resetMachine(self) -> str:
        self._machine.set_positions(*self._start_positions)
        self._current_positions = self._machine.get_positions()
        self._clear_runtime()
        self._status_message = f"Macchina resettata su {self._start_positions}."
        self._trace(self._status_message)
        self._emit()
        return self._current_positions

    @Slot(result=str)
    def clearStreams(self) -> str:
        self._clear_runtime()
        self._status_message = "Stream puliti."
        self._emit()
        return "ok"

    @Slot(result=str)
    def clearInputStream(self) -> str:
        self._input_buffer = ""
        self._status_message = "Input stream svuotato."
        self._emit()
        return "ok"

    @Slot(result=str)
    def backspaceInputStream(self) -> str:
        if not self._input_buffer:
            return ""
        self._input_buffer = self._input_buffer[:-1]
        self._status_message = "Input stream: rimosso ultimo carattere."
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
        self._emit()
        return self._output_buffer

    @Slot(str, result=str)
    def stepChar(self, value: str) -> str:
        ch = (value or "")[:1]
        if not ch:
            return ""

        upper = ch.upper()
        before = self._machine.get_positions()
        out = self._machine.encode_char(upper)
        after = self._machine.get_positions()
        self._current_positions = after

        self._input_buffer += upper
        self._output_buffer += out
        self._last_step = f"{upper} -> {out} | {before} -> {after}"
        self._trace(self._last_step)
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
        self._status_message = "Testo cifrato."
        self._emit()
        return out

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
