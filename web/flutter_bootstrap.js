{{flutter_js}}
{{flutter_build_config}}

// Same as the default bootstrap, but removes the HTML loading screen once
// the Flutter engine is ready to draw.
_flutter.loader.load({
  onEntrypointLoaded: async function (engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    const loader = document.getElementById('loader');
    if (loader) loader.remove();
    await appRunner.runApp();
  },
});
