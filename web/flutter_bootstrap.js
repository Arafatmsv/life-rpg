{{flutter_js}}
{{flutter_build_config}}

// Default Flutter bootstrap plus two things:
//  * the service worker caches the app, so the home-screen app also starts
//    offline; a new version is downloaded in the background and shown on
//    the next launch;
//  * the HTML loading screen is removed once the engine is ready.
_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
  onEntrypointLoaded: async function (engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    const loader = document.getElementById('loader');
    if (loader) loader.remove();
    await appRunner.runApp();
  },
});
