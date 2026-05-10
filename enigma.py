# enigma.py
from __future__ import annotations
from dataclasses import dataclass
from typing import Dict, List, Optional, Tuple

ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
A2I = {c: i for i, c in enumerate(ALPHABET)}
I2A = {i: c for i, c in enumerate(ALPHABET)}

def char_to_i(c: str) -> int:
    return A2I[c]

def i_to_char(i: int) -> str:
    return I2A[i % 26]


# Historical wirings (Enigma I)
ROTOR_SPECS: Dict[str, Tuple[str, str]] = {
    "I":   ("EKMFLGDQVZNTOWYHXUSPAIBRCJ", "Q"),
    "II":  ("AJDKSIRUXBLHWTMCQGZNPYFVOE", "E"),
    "III": ("BDFHJLCPRTXVZNYEIWGAKMUSQO", "V"),
    "IV":  ("ESOVPZJAYQUIRHXLNFTGKDCMWB", "J"),
    "V":   ("VZBRGITYUPSDNHLXAWMJQOFECK", "Z"),
}

REFLECTORS: Dict[str, str] = {
    "B": "YRUHQSLDPXNGOKMIEBFZCWVJAT",
    "C": "FVPJIAOYEDRZXWGCTKUQSBNMHL",
}


class Plugboard:
    """
    Plugboard mapping as pairs. Symmetric mapping.
    """
    def __init__(self) -> None:
        self._map: Dict[str, str] = {}

    def clear(self) -> None:
        self._map.clear()

    def pairs_list(self) -> List[str]:
        seen = set()
        pairs = []
        for a, b in self._map.items():
            if a in seen or b in seen:
                continue
            if a == b:
                continue
            if a < b:
                pairs.append(f"{a}-{b}")
            else:
                pairs.append(f"{b}-{a}")
            seen.add(a); seen.add(b)
        pairs.sort()
        return pairs

    def add_pair(self, a: str, b: str) -> None:
        a = a.upper().strip()
        b = b.upper().strip()
        if a == b:
            return
        if a not in ALPHABET or b not in ALPHABET:
            return

        # remove existing connections for a or b
        self.remove(a)
        self.remove(b)

        self._map[a] = b
        self._map[b] = a

    def remove(self, a: str) -> None:
        a = a.upper().strip()
        if a in self._map:
            b = self._map.pop(a)
            # remove the symmetric entry
            if b in self._map and self._map[b] == a:
                self._map.pop(b, None)

    def swap(self, c: str) -> str:
        c = c.upper()
        return self._map.get(c, c)


@dataclass
class Rotor:
    name: str
    wiring: str
    notch: str
    pos: int = 0  # 0..25

    def at_notch(self) -> bool:
        return i_to_char(self.pos) == self.notch

    def step(self) -> None:
        self.pos = (self.pos + 1) % 26

    def forward(self, i: int) -> int:
        # apply position shift
        shifted = (i + self.pos) % 26
        out_c = self.wiring[shifted]
        out_i = char_to_i(out_c)
        # remove position shift
        return (out_i - self.pos) % 26

    def backward(self, i: int) -> int:
        shifted = (i + self.pos) % 26
        # inverse wiring
        inv_index = self.wiring.index(i_to_char(shifted))
        return (inv_index - self.pos) % 26


class Enigma:
    """
    Minimal Enigma I simulation with:
    - 3 rotors (left, middle, right)
    - reflector
    - plugboard
    Implements classic stepping with double-step behavior.
    """
    def __init__(
        self,
        rotor_names: Tuple[str, str, str] = ("I", "II", "III"),
        reflector: str = "B",
        plugboard: Optional[Plugboard] = None
    ) -> None:
        self.plugboard = plugboard or Plugboard()
        self.reflector_name = reflector

        self.rotors: List[Rotor] = []
        for rn in rotor_names:
            wiring, notch = ROTOR_SPECS[rn]
            self.rotors.append(Rotor(name=rn, wiring=wiring, notch=notch, pos=0))

        self._reflector = REFLECTORS[self.reflector_name]

    def set_positions(self, left: str, middle: str, right: str) -> None:
        left = left.upper(); middle = middle.upper(); right = right.upper()
        self.rotors[0].pos = char_to_i(left)
        self.rotors[1].pos = char_to_i(middle)
        self.rotors[2].pos = char_to_i(right)

    def get_positions(self) -> str:
        return (
            i_to_char(self.rotors[0].pos)
            + i_to_char(self.rotors[1].pos)
            + i_to_char(self.rotors[2].pos)
        )

    def _step_rotors(self) -> None:
        left, mid, right = self.rotors[0], self.rotors[1], self.rotors[2]

        # classic double-step:
        # if middle at notch -> left steps; middle steps
        # if right at notch -> middle steps
        if mid.at_notch():
            left.step()
            mid.step()
        elif right.at_notch():
            mid.step()

        # right always steps
        right.step()

    def encode_char(self, c: str) -> str:
        out, _ = self.encode_char_trace(c)
        return out

    def encode_char_trace(self, c: str) -> Tuple[str, Dict[str, object]]:
        c = c.upper()
        if c not in ALPHABET:
            return c, {
                "input": c,
                "output": c,
                "positions_before": self.get_positions(),
                "positions_after": self.get_positions(),
                "plug_in": c,
                "plug_out": c,
                "forward": [],
                "backward": [],
                "reflector_in": c,
                "reflector_out": c,
                "reflector_name": self.reflector_name,
            }

        positions_before = self.get_positions()
        self._step_rotors()
        positions_after = self.get_positions()

        # plugboard in
        plug_in = self.plugboard.swap(c)
        i = char_to_i(plug_in)
        forward_trace: List[Dict[str, object]] = []

        # forward through rotors (right to left)
        for rotor in (self.rotors[2], self.rotors[1], self.rotors[0]):
            in_i = i
            shifted = (in_i + rotor.pos) % 26
            wired_c = rotor.wiring[shifted]
            wired_i = char_to_i(wired_c)
            out_i = (wired_i - rotor.pos) % 26
            forward_trace.append(
                {
                    "rotor": rotor.name,
                    "position": i_to_char(rotor.pos),
                    "in": i_to_char(in_i),
                    "out": i_to_char(out_i),
                }
            )
            i = out_i

        # reflector
        reflector_in = i_to_char(i)
        reflector_out = self._reflector[i]
        i = char_to_i(reflector_out)
        backward_trace: List[Dict[str, object]] = []

        # backward through rotors (left to right)
        for rotor in (self.rotors[0], self.rotors[1], self.rotors[2]):
            in_i = i
            shifted = (in_i + rotor.pos) % 26
            target_c = i_to_char(shifted)
            inv_index = rotor.wiring.index(target_c)
            out_i = (inv_index - rotor.pos) % 26
            backward_trace.append(
                {
                    "rotor": rotor.name,
                    "position": i_to_char(rotor.pos),
                    "in": i_to_char(in_i),
                    "out": i_to_char(out_i),
                }
            )
            i = out_i

        out = i_to_char(i)

        # plugboard out
        plug_out = self.plugboard.swap(out)
        trace = {
            "input": c,
            "output": plug_out,
            "positions_before": positions_before,
            "positions_after": positions_after,
            "plug_in": plug_in,
            "plug_out": plug_out,
            "forward": forward_trace,
            "backward": backward_trace,
            "reflector_in": reflector_in,
            "reflector_out": reflector_out,
            "reflector_name": self.reflector_name,
        }
        return plug_out, trace

    def encode_text(self, text: str) -> str:
        res = []
        for ch in text:
            res.append(self.encode_char(ch))
        return "".join(res)
