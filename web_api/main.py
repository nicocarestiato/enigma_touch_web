from __future__ import annotations

from typing import List, Tuple

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from enigma import ALPHABET, Enigma, Plugboard, REFLECTORS, ROTOR_SPECS


app = FastAPI(title="Enigma Touch Web API", version="1.0.0")

# For development and first public demo; we can harden this later.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class EncodeRequest(BaseModel):
    text: str = Field(default="", max_length=20000)
    rotors: List[str] = Field(default_factory=lambda: ["I", "II", "III"])
    reflector: str = "B"
    positions: str = "AAA"
    plugboard_pairs: List[str] = Field(default_factory=list)


class EncodeResponse(BaseModel):
    output: str
    final_positions: str


def _parse_plug_pairs(raw_pairs: List[str]) -> List[Tuple[str, str]]:
    pairs: List[Tuple[str, str]] = []
    used = set()
    for raw in raw_pairs:
        item = (raw or "").strip().upper().replace("-", "")
        if len(item) != 2:
            raise HTTPException(status_code=400, detail=f"Coppia plugboard non valida: {raw!r}")
        a, b = item[0], item[1]
        if a not in ALPHABET or b not in ALPHABET:
            raise HTTPException(status_code=400, detail=f"Coppia plugboard non valida: {raw!r}")
        if a == b:
            raise HTTPException(status_code=400, detail=f"Coppia plugboard con lettere uguali: {raw!r}")
        if a in used or b in used:
            raise HTTPException(status_code=400, detail=f"Lettera plugboard duplicata: {raw!r}")
        used.add(a)
        used.add(b)
        if a < b:
            pairs.append((a, b))
        else:
            pairs.append((b, a))
    return pairs


def _build_machine(req: EncodeRequest) -> Enigma:
    rotors = [r.strip().upper() for r in req.rotors]
    if len(rotors) != 3:
        raise HTTPException(status_code=400, detail="Servono esattamente 3 rotori.")
    if any(r not in ROTOR_SPECS for r in rotors):
        raise HTTPException(status_code=400, detail="Nome rotore non valido.")
    if len(set(rotors)) != 3:
        raise HTTPException(status_code=400, detail="I 3 rotori devono essere diversi.")

    reflector = (req.reflector or "").strip().upper()
    if reflector not in REFLECTORS:
        raise HTTPException(status_code=400, detail="Reflector non valido.")

    positions = (req.positions or "").strip().upper()
    if len(positions) != 3 or any(ch not in ALPHABET for ch in positions):
        raise HTTPException(status_code=400, detail="Posizioni non valide (usa 3 lettere, es. DDA).")

    plugboard = Plugboard()
    for a, b in _parse_plug_pairs(req.plugboard_pairs):
        plugboard.add_pair(a, b)

    machine = Enigma(
        rotor_names=(rotors[0], rotors[1], rotors[2]),
        reflector=reflector,
        plugboard=plugboard,
    )
    machine.set_positions(positions[0], positions[1], positions[2])
    return machine


@app.get("/")
def root() -> dict:
    return {"service": "enigma-touch-web-api", "status": "ok"}


@app.get("/health")
def health() -> dict:
    return {"ok": True}


@app.post("/encode", response_model=EncodeResponse)
def encode(req: EncodeRequest) -> EncodeResponse:
    machine = _build_machine(req)
    output = machine.encode_text(req.text or "")
    return EncodeResponse(output=output, final_positions=machine.get_positions())


# Enigma uses the same transformation for encode and decode when config is identical.
@app.post("/decode", response_model=EncodeResponse)
def decode(req: EncodeRequest) -> EncodeResponse:
    return encode(req)
