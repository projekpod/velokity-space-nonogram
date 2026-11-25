(() => {
  const events = new Map();
  const fixture = { calls: [], height: 78 };
  const connect = (name, callback) => events.set(name, callback);
  const emit = (name, value) => events.get(`${name}_state_changed`)?.(value);
  const modules = new Proxy({}, { get: () => ({ on() {} }) });
  window.velokityPortalFixture = fixture;
  window.bridge = {
    ...modules,
    get isInitialized() { return true; },
    async initialize() {},
    setGameLoadingProgress() {},
    platform: {
      id: "crazy_games",
      language: "en",
      on: connect,
      sendMessage: message => fixture.calls.push(message),
    },
    advertisement: {
      on: connect,
      isBannerSupported: true,
      isRewardedSupported: true,
      isInterstitialSupported: false,
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
