/* global document, window, navigator, fetch, requestAnimationFrame, cancelAnimationFrame */

(function () {
  "use strict";

  const state = {
    page: "disclaimer",
    soundtrackMode: "classic",
    bgMusicEnabled: true,
    bgMusicVolume: 0.5,
    bgStartupFade: 0,
    storyDuckingFactor: 0.2,
    storyAudioPlaying: false,
    emergencyMusicFactor: 1.0,
    uiBrightness: 1.0,
    disruptionEnabled: true,
    disruptionOccurred: false,
    disruptionActive: false,
    disruptionTimer: null,
    disruptionBlackTimer: null,
    disruptionMessageTimer: null,
    disruptionResumeStoryAudio: false,
    disruptionResumeStoryVideo: false,
    bootMs: 10000,
    bootHoldMs: 2000,
    bootPause48Ms: 1000,
    bootPause60Ms: 3000,
    bootPause98Ms: 1000,
    bootRaf: null,
    rotors: ["I", "II", "III"],
    reflector: "B",
    positions: "AAA",
    plugboardPairs: [],
    apiBase:
      (window.localStorage && window.localStorage.getItem("enigma_api_base")) ||
      "https://enigma-touch-web-api.onrender.com",
  };

  const pageIds = [
    "disclaimer",
    "soundtrack",
    "boot",
    "intro",
    "home",
    "machine",
    "story",
  ];

  const q = (id) => document.getElementById(id);
  const pages = new Map(pageIds.map((id) => [id, q("page-" + id)]));
  const pageFade = q("page-fade");
  const byline = q("byline");
  const topButtons = q("top-buttons");
  const brightnessLayer = q("brightness-layer");

  const bgMusic = q("bg-music");
  const storyAudio = q("story-audio");
  const storyVideo = q("story-video");

  const disruptionOverlay = q("disruption-overlay");
  const disruptionBlack = q("disruption-black");
  const disruptionMessage = q("disruption-message");
  const disruptionTitle = q("disruption-title");
  const disruptionText = q("disruption-text");

  const bootFill = q("boot-fill");
  const bootGlow = q("boot-glow");
  const bootStatus = q("boot-status");
  const bootPercent = q("boot-percent");

  const tracks = {
    classic: "ui/assets/sottofondo.mp3",
    war: "ui/assets/sottofondospari.mp3",
  };

  const creditsModal = q("credits-modal");
  const settingsModal = q("settings-modal");

  function clamp(value, min, max) {
    return Math.max(min, Math.min(max, value));
  }

  function randomInt(min, max) {
    return Math.floor(Math.random() * (max - min + 1)) + min;
  }

  function pickOne(list) {
    return list[randomInt(0, list.length - 1)];
  }

  function pickDistinct(list, count) {
    const src = list.slice();
    const out = [];
    while (src.length > 0 && out.length < count) {
      const idx = randomInt(0, src.length - 1);
      out.push(src[idx]);
      src.splice(idx, 1);
    }
    return out;
  }

  function formatList(values) {
    if (values.length === 0) {
      return "";
    }
    if (values.length === 1) {
      return values[0];
    }
    if (values.length === 2) {
      return values[0] + " e " + values[1];
    }
    return values.slice(0, -1).join(", ") + " e " + values[values.length - 1];
  }

  function showModal(modal) {
    modal.classList.remove("hidden");
  }

  function hideModal(modal) {
    modal.classList.add("hidden");
  }

  function updateOverlayVisibility() {
    const hideTop = state.page === "disclaimer" || state.page === "soundtrack";
    topButtons.style.display = hideTop ? "none" : "flex";
    const hideByline =
      state.page === "intro" ||
      state.page === "machine" ||
      state.page === "disclaimer" ||
      state.page === "soundtrack";
    byline.style.display = hideByline ? "none" : "block";
  }

  function setPage(next) {
    if (!pages.has(next) || next === state.page) {
      return;
    }
    pageFade.classList.add("active");
    window.setTimeout(() => {
      pages.get(state.page).classList.remove("active");
      state.page = next;
      pages.get(state.page).classList.add("active");
      updateOverlayVisibility();
      if (next === "boot") {
        startBootSequence();
      }
      if (next === "story") {
        syncStoryDucking(true);
      } else {
        syncStoryDucking(false);
      }
      window.setTimeout(() => pageFade.classList.remove("active"), 140);
    }, 120);
  }

  function bootStatusText(progress) {
    if (progress < 0.2) {
      return "Inizializzazione interfaccia...";
    }
    if (progress < 0.45) {
      return "Caricamento risorse grafiche...";
    }
    if (progress < 0.7) {
      return "Sincronizzazione moduli Enigma...";
    }
    if (progress < 0.92) {
      return "Ottimizzazione esperienza...";
    }
    return "Pronto.";
  }

  function progressAtElapsed(elapsed) {
    const travel =
      state.bootMs -
      state.bootHoldMs -
      state.bootPause48Ms -
      state.bootPause60Ms -
      state.bootPause98Ms;
    const seg1 = state.bootHoldMs;
    const seg2 = seg1 + Math.round(travel * 0.48);
    const seg3 = seg2 + state.bootPause48Ms;
    const seg4 = seg3 + Math.round(travel * 0.12);
    const seg5 = seg4 + state.bootPause60Ms;
    const seg6 = seg5 + Math.round(travel * 0.38);
    const seg7 = seg6 + state.bootPause98Ms;
    const seg8 = state.bootMs;

    if (elapsed <= seg1) return 0;
    if (elapsed <= seg2) return ((elapsed - seg1) / (seg2 - seg1)) * 0.48;
    if (elapsed <= seg3) return 0.48;
    if (elapsed <= seg4) return 0.48 + ((elapsed - seg3) / (seg4 - seg3)) * 0.12;
    if (elapsed <= seg5) return 0.6;
    if (elapsed <= seg6) return 0.6 + ((elapsed - seg5) / (seg6 - seg5)) * 0.38;
    if (elapsed <= seg7) return 0.98;
    if (elapsed <= seg8) return 0.98 + ((elapsed - seg7) / Math.max(1, seg8 - seg7)) * 0.02;
    return 1.0;
  }

  function updateBootUi(progress) {
    const pct = Math.round(progress * 100);
    bootFill.style.width = pct + "%";
    bootGlow.style.left = "calc(" + pct + "% - 72px)";
    bootPercent.textContent = pct + "%";
    bootStatus.textContent = bootStatusText(progress);
  }

  function startBootSequence() {
    if (state.bootRaf) {
      cancelAnimationFrame(state.bootRaf);
      state.bootRaf = null;
    }
    const start = performance.now();
    const tick = (now) => {
      const elapsed = now - start;
      const progress = clamp(progressAtElapsed(elapsed), 0, 1);
      updateBootUi(progress);
      if (elapsed >= state.bootMs) {
        state.bootRaf = null;
        setPage("intro");
        return;
      }
      state.bootRaf = requestAnimationFrame(tick);
    };
    state.bootRaf = requestAnimationFrame(tick);
  }

  function updateBgMusicVolume() {
    const raw =
      (state.bgMusicEnabled ? state.bgMusicVolume : 0) *
      state.bgStartupFade *
      (state.storyAudioPlaying ? state.storyDuckingFactor : 1) *
      state.emergencyMusicFactor;
    bgMusic.volume = clamp(raw, 0, 1);
  }

  function animateValue(setter, from, to, durationMs, done) {
    const start = performance.now();
    function step(now) {
      const t = clamp((now - start) / Math.max(1, durationMs), 0, 1);
      const eased = t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
      setter(from + (to - from) * eased);
      if (t >= 1) {
        if (done) done();
        return;
      }
      requestAnimationFrame(step);
    }
    requestAnimationFrame(step);
  }

  function setSoundtrack(mode, restartPlayback) {
    const next = mode === "war" ? "war" : "classic";
    state.soundtrackMode = next;
    if (restartPlayback) {
      bgMusic.src = tracks[state.soundtrackMode];
      bgMusic.currentTime = 0;
      bgMusic.play().catch(() => {});
    }
    syncSettingsUi();
  }

  function startMusicWithFade() {
    bgMusic.src = tracks[state.soundtrackMode];
    state.bgStartupFade = 0;
    updateBgMusicVolume();
    bgMusic.play().catch(() => {});
    animateValue(
      (v) => {
        state.bgStartupFade = v;
        updateBgMusicVolume();
      },
      0,
      1,
      4000
    );
  }

  function syncStoryDucking(isStoryPage) {
    if (!isStoryPage) {
      state.storyAudioPlaying = false;
      updateBgMusicVolume();
      return;
    }
    const active = !storyAudio.paused || !storyVideo.paused;
    state.storyAudioPlaying = active;
    updateBgMusicVolume();
  }

  function loadStoryText() {
    fetch("ui/assets/story.txt")
      .then((r) => (r.ok ? r.text() : "story.txt non trovato."))
      .then((t) => {
        q("story-text").textContent = t;
      })
      .catch(() => {
        q("story-text").textContent = "story.txt non trovato.";
      });
  }

  function setupGallery() {
    const track = q("gallery-track");
    const inner = document.createElement("div");
    inner.className = "gallery-inner";
    for (let i = 1; i <= 8; i += 1) {
      const img = document.createElement("img");
      img.src = "ui/assets/gallery/" + i + ".png";
      img.alt = "gallery-" + i;
      inner.appendChild(img);
    }
    track.innerHTML = "";
    track.appendChild(inner);
  }

  function getMachineConfig() {
    const left = q("rotor-left").value;
    const middle = q("rotor-middle").value;
    const right = q("rotor-right").value;
    const reflector = q("reflector").value;
    const positions = (q("positions").value || "AAA").toUpperCase().replace(/[^A-Z]/g, "").slice(0, 3);
    if (positions.length === 3) {
      state.positions = positions;
    }
    return {
      rotors: [left, middle, right],
      reflector: reflector,
      positions: state.positions,
      plugboard_pairs: state.plugboardPairs.slice(),
    };
  }

  function setMachineStatus(text) {
    q("machine-status").textContent = text;
  }

  async function machineRequest(path, text) {
    const payload = getMachineConfig();
    payload.text = text;
    const url = state.apiBase.replace(/\/+$/, "") + path;
    const res = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });
    if (!res.ok) {
      let detail = "Errore API";
      try {
        const data = await res.json();
        if (data && data.detail) detail = data.detail;
      } catch (e) {}
      throw new Error(detail);
    }
    return res.json();
  }

  async function runEncode(pathLabel) {
    const input = q("machine-input").value || "";
    if (!input.length) {
      setMachineStatus("Inserisci prima del testo.");
      return;
    }
    setMachineStatus("Elaborazione in corso...");
    try {
      const data = await machineRequest(pathLabel, input);
      q("machine-output").value = data.output || "";
      state.positions = data.final_positions || state.positions;
      q("positions").value = state.positions;
      setMachineStatus("Operazione completata. Posizioni finali: " + state.positions);
    } catch (err) {
      setMachineStatus("Errore: " + err.message);
    }
  }

  function normalizePair(v) {
    return (v || "").toUpperCase().replace(/[^A-Z]/g, "").slice(0, 1);
  }

  function renderPlugboard() {
    const box = q("plugboard-list");
    box.innerHTML = "";
    state.plugboardPairs.forEach((pair) => {
      const chip = document.createElement("button");
      chip.className = "pair-chip";
      chip.textContent = pair + "  x";
      chip.title = "Rimuovi " + pair;
      chip.addEventListener("click", () => {
        state.plugboardPairs = state.plugboardPairs.filter((p) => p !== pair);
        renderPlugboard();
      });
      box.appendChild(chip);
    });
  }

  function addPlugPair() {
    const a = normalizePair(q("plug-a").value);
    const b = normalizePair(q("plug-b").value);
    if (!a || !b || a === b) {
      setMachineStatus("Coppia plugboard non valida.");
      return;
    }
    let pair = a < b ? a + "-" + b : b + "-" + a;
    state.plugboardPairs = state.plugboardPairs.filter((p) => !p.includes(a) && !p.includes(b));
    state.plugboardPairs.push(pair);
    state.plugboardPairs.sort();
    q("plug-a").value = "";
    q("plug-b").value = "";
    renderPlugboard();
    setMachineStatus("Plugboard aggiornato.");
  }

  function isDisruptionEligiblePage() {
    return state.page === "intro" || state.page === "home" || state.page === "machine" || state.page === "story";
  }

  function scheduleDisruption(initial) {
    if (!state.disruptionEnabled || state.disruptionOccurred || state.disruptionActive) {
      return;
    }
    if (state.disruptionTimer) {
      window.clearTimeout(state.disruptionTimer);
      state.disruptionTimer = null;
    }
    const min = initial ? 55000 : 25000;
    const max = initial ? 90000 : 60000;
    state.disruptionTimer = window.setTimeout(triggerDisruption, randomInt(min, max));
  }

  function buildDisruptionMessage() {
    const localita = pickDistinct(
      [
        "Wolverton",
        "Stony Stratford",
        "Fenny Stratford",
        "Woburn Sands",
        "Newport Pagnell",
        "Buckingham",
        "Leighton Buzzard",
        "Bicester",
      ],
      randomInt(3, 4)
    );
    const attore = pickOne(["Luftwaffe tedesca", "forze dell'Asse", "squadriglie tedesche d'attacco"]);
    const azione = pickOne(["azioni offensive coordinate", "una nuova ondata di incursioni", "un attacco mirato alle infrastrutture"]);
    const velivolo = pickOne(["Heinkel He 111", "Junkers Ju 88", "Dornier Do 17", "Messerschmitt Bf 110"]);
    const ordigno = pickOne(["V-1", "V-2"]);

    disruptionTitle.textContent = "ALLERTA OPERATIVA: BLACKOUT TEMPORANEO";
    disruptionText.textContent =
      "Rapporto da Bletchley Park: detonazioni segnalate nell'area di " +
      formatList(localita) +
      ".\n\nIntelligence: " +
      attore +
      " in " +
      azione +
      ", possibile impiego di " +
      velivolo +
      " e ordigni " +
      ordigno +
      ".\n\nInterruzione di corrente confermata. I generatori di emergenza entreranno in funzione tra pochi istanti.";
    return randomInt(14000, 26000);
  }

  function setDisruptionOverlay(visible, blackOnly) {
    if (!visible) {
      disruptionOverlay.classList.add("hidden");
      disruptionMessage.classList.add("hidden");
      disruptionBlack.style.opacity = "0";
      return;
    }
    disruptionOverlay.classList.remove("hidden");
    disruptionBlack.style.opacity = "0.96";
    if (blackOnly) {
      disruptionMessage.classList.add("hidden");
    } else {
      disruptionMessage.classList.remove("hidden");
    }
  }

  function triggerDisruption() {
    if (!state.disruptionEnabled || state.disruptionOccurred || state.disruptionActive) {
      return;
    }
    if (!isDisruptionEligiblePage()) {
      scheduleDisruption(false);
      return;
    }
    state.disruptionOccurred = true;
    state.disruptionActive = true;

    state.disruptionResumeStoryAudio = !storyAudio.paused;
    state.disruptionResumeStoryVideo = !storyVideo.paused;
    if (state.disruptionResumeStoryAudio) storyAudio.pause();
    if (state.disruptionResumeStoryVideo) storyVideo.pause();
    state.storyAudioPlaying = false;
    updateBgMusicVolume();

    animateValue(
      (v) => {
        state.emergencyMusicFactor = v;
        updateBgMusicVolume();
      },
      state.emergencyMusicFactor,
      0,
      700
    );

    setDisruptionOverlay(true, true);
    const messageDuration = buildDisruptionMessage();

    state.disruptionBlackTimer = window.setTimeout(() => {
      setDisruptionOverlay(true, false);
      state.disruptionMessageTimer = window.setTimeout(() => {
        finishDisruption();
      }, messageDuration);
    }, 2000);
  }

  function finishDisruption() {
    if (!state.disruptionActive) {
      return;
    }
    state.disruptionActive = false;
    setDisruptionOverlay(false, false);
    animateValue(
      (v) => {
        state.emergencyMusicFactor = v;
        updateBgMusicVolume();
      },
      state.emergencyMusicFactor,
      1,
      900
    );
    if (state.page === "story" && state.disruptionResumeStoryAudio) {
      storyAudio.play().catch(() => {});
      if (state.disruptionResumeStoryVideo) {
        storyVideo.play().catch(() => {});
      }
    }
    state.disruptionResumeStoryAudio = false;
    state.disruptionResumeStoryVideo = false;
  }

  function syncSettingsUi() {
    q("settings-music-enabled").checked = state.bgMusicEnabled;
    q("settings-volume").value = Math.round(state.bgMusicVolume * 100);
    q("settings-volume-label").textContent = Math.round(state.bgMusicVolume * 100) + "%";
    q("settings-ducking").value = Math.round(state.storyDuckingFactor * 100);
    q("settings-duck-label").textContent = Math.round((1 - state.storyDuckingFactor) * 100) + "%";
    q("settings-brightness").value = Math.round(state.uiBrightness * 100);
    q("settings-brightness-label").textContent = Math.round(state.uiBrightness * 100) + "%";
    q("settings-disruption-enabled").checked = state.disruptionEnabled;
    q("settings-api-url").value = state.apiBase;
  }

  function applySettings() {
    const wasEnabled = state.disruptionEnabled;
    state.bgMusicEnabled = q("settings-music-enabled").checked;
    state.bgMusicVolume = clamp(Number(q("settings-volume").value) / 100, 0, 1);
    state.storyDuckingFactor = clamp(Number(q("settings-ducking").value) / 100, 0.15, 1);
    state.uiBrightness = clamp(Number(q("settings-brightness").value) / 100, 0.45, 1);
    state.disruptionEnabled = q("settings-disruption-enabled").checked;
    state.apiBase = (q("settings-api-url").value || "").trim() || state.apiBase;
    if (window.localStorage) {
      window.localStorage.setItem("enigma_api_base", state.apiBase);
    }
    brightnessLayer.style.opacity = ((1 - state.uiBrightness) * 0.7).toFixed(3);
    updateBgMusicVolume();
    syncSettingsUi();

    if (!state.disruptionEnabled && wasEnabled) {
      if (state.disruptionTimer) {
        window.clearTimeout(state.disruptionTimer);
        state.disruptionTimer = null;
      }
    } else if (state.disruptionEnabled && !wasEnabled && !state.disruptionOccurred && !state.disruptionActive) {
      scheduleDisruption(false);
    }
  }

  function setupMachineOptions() {
    const rotorNames = ["I", "II", "III", "IV", "V"];
    const reflectorNames = ["B", "C"];
    ["rotor-left", "rotor-middle", "rotor-right"].forEach((id, i) => {
      const sel = q(id);
      sel.innerHTML = "";
      rotorNames.forEach((name) => {
        const opt = document.createElement("option");
        opt.value = name;
        opt.textContent = name;
        if (name === state.rotors[i]) opt.selected = true;
        sel.appendChild(opt);
      });
    });
    const reflector = q("reflector");
    reflector.innerHTML = "";
    reflectorNames.forEach((name) => {
      const opt = document.createElement("option");
      opt.value = name;
      opt.textContent = name;
      reflector.appendChild(opt);
    });
    reflector.value = state.reflector;
    q("positions").value = state.positions;
  }

  function bindEvents() {
    q("btn-disclaimer-continue").addEventListener("click", () => setPage("soundtrack"));
    q("btn-theme-war").addEventListener("click", () => {
      setSoundtrack("war", false);
      startMusicWithFade();
      setPage("boot");
    });
    q("btn-theme-classic").addEventListener("click", () => {
      setSoundtrack("classic", false);
      startMusicWithFade();
      setPage("boot");
    });

    q("btn-start-experience").addEventListener("click", () => setPage("home"));
    q("btn-open-machine").addEventListener("click", () => setPage("machine"));
    q("btn-open-story").addEventListener("click", () => setPage("story"));
    q("btn-machine-home").addEventListener("click", () => setPage("home"));
    q("btn-story-home").addEventListener("click", () => {
      storyAudio.pause();
      storyVideo.pause();
      syncStoryDucking(false);
      setPage("home");
    });

    q("btn-apply-config").addEventListener("click", () => {
      const left = q("rotor-left").value;
      const middle = q("rotor-middle").value;
      const right = q("rotor-right").value;
      if (new Set([left, middle, right]).size !== 3) {
        setMachineStatus("I tre rotori devono essere diversi.");
        return;
      }
      state.rotors = [left, middle, right];
      state.reflector = q("reflector").value;
      const p = (q("positions").value || "").toUpperCase().replace(/[^A-Z]/g, "").slice(0, 3);
      if (p.length !== 3) {
        setMachineStatus("Posizioni non valide, usa 3 lettere.");
        return;
      }
      state.positions = p;
      q("positions").value = state.positions;
      setMachineStatus("Configurazione applicata.");
    });

    q("btn-reset-machine").addEventListener("click", () => {
      q("positions").value = state.positions;
      setMachineStatus("Posizioni resettate a " + state.positions + ".");
    });

    q("btn-add-pair").addEventListener("click", addPlugPair);
    q("btn-clear-pairs").addEventListener("click", () => {
      state.plugboardPairs = [];
      renderPlugboard();
      setMachineStatus("Plugboard azzerato.");
    });
    q("btn-clear-streams").addEventListener("click", () => {
      q("machine-input").value = "";
      q("machine-output").value = "";
      setMachineStatus("Stream puliti.");
    });
    q("btn-encode").addEventListener("click", () => runEncode("/encode"));
    q("btn-decode").addEventListener("click", () => runEncode("/decode"));

    q("btn-story-sync-play").addEventListener("click", () => {
      storyAudio.play().catch(() => {});
      storyVideo.play().catch(() => {});
      syncStoryDucking(true);
    });
    q("btn-story-sync-stop").addEventListener("click", () => {
      storyAudio.pause();
      storyVideo.pause();
      syncStoryDucking(true);
    });

    ["play", "pause", "ended"].forEach((evt) => {
      storyAudio.addEventListener(evt, () => syncStoryDucking(state.page === "story"));
      storyVideo.addEventListener(evt, () => syncStoryDucking(state.page === "story"));
    });

    window.setInterval(() => {
      if (state.page === "story" && !storyAudio.paused && !storyVideo.paused) {
        const drift = Math.abs(storyAudio.currentTime - storyVideo.currentTime);
        if (drift > 0.35) {
          storyVideo.currentTime = storyAudio.currentTime;
        }
      }
    }, 850);

    q("btn-fullscreen").addEventListener("click", async () => {
      if (!document.fullscreenElement) {
        await document.documentElement.requestFullscreen().catch(() => {});
      } else {
        await document.exitFullscreen().catch(() => {});
      }
      q("btn-fullscreen").textContent = document.fullscreenElement ? "WINDOW" : "FULLSCREEN";
    });

    q("btn-credits").addEventListener("click", () => showModal(creditsModal));
    q("btn-settings").addEventListener("click", () => {
      syncSettingsUi();
      showModal(settingsModal);
    });
    document.querySelectorAll("[data-close-modal]").forEach((btn) => {
      btn.addEventListener("click", () => hideModal(q(btn.getAttribute("data-close-modal"))));
    });

    q("settings-theme-classic").addEventListener("click", () => setSoundtrack("classic", true));
    q("settings-theme-war").addEventListener("click", () => setSoundtrack("war", true));
    q("settings-defaults").addEventListener("click", () => {
      state.bgMusicEnabled = true;
      state.bgMusicVolume = 0.5;
      state.storyDuckingFactor = 0.2;
      state.uiBrightness = 1;
      state.disruptionEnabled = true;
      setSoundtrack("classic", true);
      syncSettingsUi();
      applySettings();
    });
    q("settings-save").addEventListener("click", () => {
      applySettings();
      hideModal(settingsModal);
    });

    ["settings-volume", "settings-ducking", "settings-brightness"].forEach((id) => {
      q(id).addEventListener("input", syncSettingsUi);
    });
  }

  function initialize() {
    setupGallery();
    setupMachineOptions();
    loadStoryText();
    renderPlugboard();
    bindEvents();

    syncSettingsUi();
    applySettings();
    updateOverlayVisibility();
    updateBootUi(0);
    scheduleDisruption(true);
  }

  initialize();
})();
