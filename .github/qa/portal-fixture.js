(() => {
  const events = new Map();
  const options = window.velokityPortalOptions ?? {};
  const fixture = { calls: [], height: 78, minimumDelay: 0, audio: options.audio ?? true };
  const storageKey = key => `qa-portal:${key}`;
  const checkInitialized = () => {
    if (!initialized) throw new Error("Bridge API called before initialize resolved");
  };
  let initialized = false;
  const connect = (name, callback) => events.set(name, callback);
  const emit = (name, value) => events.get(`${name}_state_changed`)?.(value);
  const modules = new Proxy({}, { get: () => ({ on() {} }) });
  fixture.setPaused = value => emit("pause", value);
  fixture.setAudio = value => {
    fixture.audio = value;
    emit("audio", value);
  };
  fixture.saved = () => JSON.parse(localStorage.getItem(storageKey("velokity-save-qa")));
  fixture.seed = value => localStorage.setItem(storageKey("velokity-save-qa"), value);
  fixture.archives = () => Object.keys(localStorage).filter(key => key.startsWith(storageKey("velokity-save-qa-corrupt-")))
    .map(key => localStorage.getItem(key));
  window.velokityPortalFixture = fixture;
  window.bridge = {
    ...modules,
    get isInitialized() { return initialized; },
    async initialize() {
      await Promise.resolve();
      initialized = true;
    },
    setGameLoadingProgress: checkInitialized,
    storage: {
      async get(keys) {
        checkInitialized();
        fixture.calls.push("storage:get");
        return keys.map(key => localStorage.getItem(storageKey(key)));
      },
      async set(key, value) {
        checkInitialized();
        fixture.calls.push(`storage:set:${key}`);
        if (fixture.failWrite) throw new Error("Fixture storage failure");
        localStorage.setItem(storageKey(key), value);
      },
    },
    platform: {
      id: "playgama",
      language: options.language ?? "en",
      get isAudioEnabled() { return fixture.audio; },
      on: connect,
      sendMessage(message) {
        checkInitialized();
        fixture.calls.push(message);
      },
    },
    advertisement: {
      on: connect,
      isBannerSupported: true,
      isRewardedSupported: options.rewarded ?? true,
      isInterstitialSupported: true,
      setMinimumDelayBetweenInterstitial(seconds) {
        checkInitialized();
        fixture.minimumDelay = seconds;
      },
      showInterstitial() {
        fixture.calls.push("interstitial");
        emit("interstitial", "loading");
        emit("interstitial", "failed");
      },
      showBanner(position) {
        fixture.calls.push(`banner:${position}`);
        const banner = document.createElement("div");
        banner.id = "banner-container";
        banner.style.cssText = `position:fixed;bottom:0;width:100%;height:${fixture.height}px;background:#f5c16c`;
        document.body.append(banner);
        emit("banner", "shown");
      },
      hideBanner() {
        fixture.calls.push("banner:hidden");
        document.getElementById("banner-container")?.remove();
        emit("banner", "hidden");
      },
      showRewarded(placement) {
        fixture.calls.push(`rewarded:${placement}`);
        emit("rewarded", "opened");
        setTimeout(() => {
          emit("rewarded", "rewarded");
          emit("rewarded", "closed");
        }, 200);
      },
    },
  };
  Object.setPrototypeOf(window.bridge, modules);
})();
