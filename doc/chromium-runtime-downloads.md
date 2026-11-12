# Chromium 158 (Linux, unbranded): runtime downloads of executable code, and privacy notes

Scope: Chromium 158.0.8127.33 plus the 158 branch up to 8127@{#1699}, `is_chrome_branded=false`,
Linux desktop, default GN args (plus `enable_widevine=true`), as built by the 158 ebuilds. All
`file:line` references are into that pristine tree (before our patches). First written for 156.0.8078.12
(2026-10), re-audited for 158 on 2026-11-12 by reading the source (no compile); 157 differs from 158 only
where noted.

Hard rule this work enforces: **Chromium must not download executable code at runtime,
aside from wasm/JS used by actual web pages.** "Executable" = native shared libraries,
WebAssembly, or JavaScript that runs outside a normal web page (component extensions,
content scripts injected by the browser, privileged WebUI / DevTools contexts).
ML models (TFLite flatbuffers, weights, tokenizers) are *computation graphs executed by
an interpreter that is compiled into Chromium*; custom ops are compiled in, not
downloaded. They are treated as **data** here (with that nuance noted), as are lists,
protobuf configs and dictionaries.

The patches: `www-client/chromium/files/chromium-158-no-runtime-executable-downloads.patch` (and
`chromium-157-…` for 157; same gates).

**Exception:** Translate's `element.js` (§1b) is browser-fetched JavaScript run in an isolated world, not
by the page. It is allowed, as "Translate this page" needs it and only runs when the user translates (or set
a language to always translate). Nothing turns it off at runtime: the "Offer to translate" setting (pref
`translate.enabled`, policy `TranslateEnabled`) stops the offers and automatic translation, but not the manual
"Translate to …" (`TranslateManager::CanManuallyTranslateInternal()` doesn't check it).

---

## 1. Inventory

### 1a. Component updater components registered in `chrome/browser/component_updater/registration.cc`

`RegisterComponentsForUpdate()` is at `registration.cc:145-260`. "Active" = registered in a
Linux Chromium build with the ebuild's default GN config.

| # | Component | Registered at | Payload | Exec? | Active on Linux Chromium | Control | Action |
|---|---|---|---|---|---|---|---|
| 1 | Recovery Improved | `:148-150` | updater recovery binary | native | **No** (`IS_WIN \|\| IS_MAC`; implementation only built when branded, `component_updater/BUILD.gn:286-288,301-303`) | platform | none |
| 2 | **Widevine CDM** (`WidevineCdm`) | `:152-154` | `libwidevinecdm.so` | **native** | **Yes** with `enable_widevine` (USE=widevine, default on) | `ENABLE_WIDEVINE_CDM_COMPONENT` = `enable_library_widevine_cdm && (is_win\|\|is_mac\|\|is_linux\|\|is_chromeos)` (`third_party/widevine/cdm/widevine.gni:42-43`, not a GN arg) | **patched**: `RegisterWidevineCdmComponent()` no-op (`widevine_cdm_component_installer.cc:438-442`); system CDM: §3 |
| 3 | Subresource Filter | `:156` | filter ruleset | data | Yes | always | none |
| 4 | On-Device Head Suggest | `:157-158` | suggestion model | data | Yes | always | none |
| 5 | Optimization Hints | `:159` | protobuf hints | data | Yes | always | none |
| 6 | Trust Token Key Commitments | `:160` | JSON | data | Yes | always | none |
| 7 | Private Verification Tokens | `:161` | JSON | data | Yes | `kEnablePrivateVerificationTokens` | none |
| — | First-Party Sets | — | — | — | removed in 158 | — | — |
| 8 | Privacy Sandbox Attestations | `:162` | proto list | data | Yes | always | none |
| 9 | Actor Safety Lists | `:163` | allow/block lists | data | Yes | always | none |
| 10 | History Search Strings | `:164-166` | strings | data | with history embeddings | feature | none |
| 11 | SSL Error Assistant | `:167` | proto | data | Yes | always | none |
| 12 | **Indigo** | `:169` | `content_script.js`, injected by `indigo/indigo_agent_host.cc:69,115` | **JS (browser-injected)** | only with `kIndigoComponent` (DISABLED, `chrome_features.cc:1516`) | feature | **patched**: `RegisterIndigoComponent()` no-op (`indigo_component_installer.cc:127-136`) |
| 13 | File Type Policies | `:171-173` | proto | data | Yes | `safe_browsing_mode` | none |
| 14 | CRLSet, Origin Trials, MEI Preload, PKI Metadata (+ fast push, also gated by `kVerifyMTCs`), Safety Tips, Crowd Deny | `:179`, `:182`, `:183`, `:185`, `:187`, `:188` | lists, configs, root store | data | Yes | always | none |
| 15 | Smart Dim / app allowlist | `:190-193` | – | – | No (ChromeOS) | platform | none |
| 16 | Hyphenation | `:195-197` | dictionaries | data | Yes (`use_minikin_hyphenation = !is_apple`) | GN | none |
| 17 | **Dictation Connector** | `:200` | component extension JS | **JS** | only with `dictation::kDictation` (DISABLED, `dictation/features.cc:14`) | feature | **patched**: no-op (`dictation_connector_component_installer.cc:182-191`) |
| 18 | IWA Key Distribution, Zxcvbn | `:201`, `:202` | keys, word lists | data | Yes | always | none |
| 19 | Real-Time URL Allowlist | `:205-207` | – | – | No (Android) | platform | none |
| 20 | **Screen AI** | `:209-211`; on demand `screen_ai_downloader_non_chromeos.cc:37` | `libchromescreenai.so` | **native** | **Yes** | `enable_screen_ai_service` (default true; `=false` doesn't build: `component_updater/BUILD.gn:244-249`, `chrome/browser/screen_ai/BUILD.gn:8`) | **patched**: registration only cleans up, `RegisterScreenAIComponent()` reports `kDownloadFailed` (`screen_ai_component_installer.cc:125-152`, incl. 158's `MayTryDownload()` logic) |
| 21 | **Commerce Heuristics** | `:213` | JSON **and `cart_product_extraction.js`** (`commerce_heuristics_component_installer.cc:46`) | **JS** | only with the NTP cart module (`IsCartModuleEnabled()`, `new_tab_page_util.cc:75-81`; `IsOsSupportedForCart()` false on Linux, `:49-55`); no desktop caller of the script in 158 | feature | **patched**: uninstalls (`:189-202`) |
| 22 | **TranslateKit** | `:215-220`; on demand `on_device_translation/installer_impl.cc:344` | `libtranslatekit.so` | **native** | **Yes** | `enable_on_device_translation` (`=false` doesn't build on Linux: `chrome_browser_interface_binders_webui_parts_desktop.cc:160,526`) | **patched**: no-op (`translate_kit_component_installer.cc:206-233`); stored path ignored (`installer_impl.cc:50-56`); `--translate-kit-binary-path` still works |
| 22b | TranslateKit language packs | `:221-224` | models | data | Yes | same | none (useless without the library) |
| 23 | Amount Extraction Regexes | `:227-231` | regexes | data | Yes | always | none |
| 24 | **WASM TTS Engine** | `:233-235`; on demand `wasm_tts_engine_component_installer.cc:279-300` from `read_anything_service.cc:66-70` | `bindings_main.wasm` + JS, a component extension | **wasm + JS** | **Yes** | platform; `kWasmTtsEngineAutoInstallDisabled` DISABLED (`accessibility_features.cc:470-471`) | **patched**: no-op (`:302-307`); on-demand updates of unregistered ids fail (`component_updater_service.cc:391-412`) |
| 25 | Captcha Providers | `:237` | JSON | data | Yes | always | none |
| 26 | Platform Runtime | `:239` | native library (`chrome/services/platform_runtime/platform_runtime_service_impl.cc:73`) | **native** | **No**: `IS_WIN && GOOGLE_CHROME_BRANDING` (`platform_runtime_component_installer.cc:458-459`); service built only with `enable_request_header_integrity = is_chrome_branded` | platform + branding | none |
| 27 | Dynamic Patch (new in 158) | `:241-243` | `chrome_dynamic_patch.crx3` (child process binaries) | **native** | **No**: `#if IS_WIN`, built `if (is_win)` (`component_updater/BUILD.gn:280-283`), body branded only (`dynamic_patch_component_installer.cc:193-221`) | platform + branding | none |
| 28 | AI Embeddings Model | `:247-248` | `model.tflite`, `tokenizer.spm` | data (ML) | with the embeddings features (`ai_embeddings_component_installer.cc:161-187`) | feature | none |
| 29 | **Component extensions** (`ManageComponentExtensionRegistrations`, `component_extension_installer.cc`; 157: AIM eligibility only) | `:253-255` | newer copies of the bundled AIM eligibility and (new) New Tab Page component extensions, staged with `MaybeStageExtension` (`:109`; loader `component_loader.cc:268-295,435-478`) | **JS (component extensions)** | AIM: `kAimEligibilityComponentExtension` (DISABLED, `omnibox_features.cc:181-183`); NTP: `ntp_features::kNtpComponentExtension` (DISABLED, `ntp_features.cc:101-103`; built with `enable_webui_ntp`, true on Linux) | feature | **patched**: both uninstall and clear their staged copies (`component_extension_installer.cc:239-254`); the bundled extensions load as upstream (in 158 also only with those features, `component_loader.cc:552-586`) |

Other users of `ComponentInstaller` (`MakeRefCounted<ComponentInstaller>`, `ComponentInstallerPolicy`):

| Component | Registered from | Payload | Exec? | Active | Action |
|---|---|---|---|---|---|
| **SODA** + language packs | `accessibility/soda_installer_impl.cc:65,93` ← `SodaInstaller::Init()` (`components/soda/soda_installer.cc:90-127`), from `chrome_browser_main.cc:1660` and `live_caption_controller.cc:137` | `libsoda.so` (packs: data) | **native** | **Yes** on x86-64 with SSE4.1 (`soda_util.cc:43-53`); `kLiveCaption` ENABLED (`media_switches.cc:744`), `kPreemptiveSodaDownload` DISABLED (`:924`) | **patched**: `IsSupportedLinux()` → false, so neither component registers (`soda_component_installer.cc:228-267`). **And** the stored `libsoda.so` path (Local State `kSodaBinaryPath`) is ignored (`chrome/browser/speech/chrome_speech_recognition_service.cc:295`): a web page asking for on-device-only Web Speech recognition reaches the SODA engine regardless of support (`content/browser/speech/speech_recognition_manager_impl.cc:887-897,988-995`), and that path could only lead to a copy an earlier, unpatched build downloaded |
| Optimization Guide on-device model (158: `chrome/browser/component_updater/optimization_guide_on_device_model_installer.cc`, manifest + per-asset components, `:245,357`) | `optimization_guide_global_state.cc:82-91,171-172` | weights, config (`manifest.proto:42-100`) | data (ML) | unbranded: `ENABLE_ML_INTERNAL` false (`on_device_model.gni:24-25`) | none; the inference library is only looked up in `DIR_MODULE` (`chrome_ml_holder.cc:36-43`) and isn't built |
| Prediction models | `optimization_guide_global_state.cc:196-203` → `prediction_model_component_installer.cc:159-172` | TFLite | data (ML) | Yes | none |
| ChromeOS installers | ChromeOS only | – | – | No | none |

No other `ComponentInstaller` users exist in content, media, services, ui or extensions. The other
`update_client` users are the extension updater and `components/activity_reporter` (a ping only, built only
when branded). `install_product_component.cc` is a stub returning `kLaunchFailed` outside Windows.

Sanity sweep (`LoadNativeLibrary`, `dlopen`, `ScopedNativeLibrary` in chrome, components, services, media,
content, outside Windows/Mac/Android/ChromeOS files): `DIR_MODULE`-relative loads (`chrome_ml_holder.cc:43`,
`optimization_guide_library_holder.cc:39`, `shape_detection_library_holder.cc:24`, WebNN's
`libLiteRtWebGpuAccelerator.so` in `webnn_sandbox_init.cc:42-63`), system libraries (audio, network, GPU,
VA-API, libunity, EGL; the XR hook reads `$XR_RUNTIME_JSON` or `/etc`), and the loaders fed only by the
components above: CDM (`cdm_module.cc:123`), SODA (`soda_client_impl.cc:20`), Screen AI
(`screen_ai_library_wrapper_impl.cc:59`), TranslateKit (`translate_kit_client.cc:140`).

### 1b. Mechanisms other than the component updater

| Mechanism | Where | What | Exec? | Status / action |
|---|---|---|---|---|
| **DevTools remote front-end** | its own host `devtools://devtools-remote/remote/…` (`chrome/browser/ui/webui/devtools/devtools_ui.cc:81-85`), fetched from `https://chrome-devtools-frontend.appspot.com/` (`devtools_ui_data_source.cc:166-195`, constants `chrome/browser/devtools/url_constants.cc:7-10`); the host is still accepted by `DevToolsUIBindings::SanitizeFrontendURL` (`devtools_ui_bindings.cc:752-758`), so a remote front-end would get the bindings | JS in a privileged origin | **JS** | **patched**: 404, and CSP `script-src 'self'` (`:258`). `--custom-devtools-frontend` still works |
| Chrome Web Store extensions | `chrome/browser/extensions/updater/` | user-installed | JS | user-initiated; untouched. Policy force-installs (`external_provider_impl.cc:775-779`) are admin-initiated |
| External extensions from JSON / initial preferences | `external_provider_impl.cc`: `DIR_STANDALONE_EXTERNAL_EXTENSIONS` (`:862-869`), `DIR_EXTERNAL_EXTENSIONS` (`/usr/share/chromium/extensions`, `:899-906`), `DIR_USER_EXTERNAL_EXTENSIONS` (`:910-918`, Linux only when branded); all gated by pref `kBlockExternalExtensions` (`:860`). New: `kInitialExternalExtensions` (ENABLED, `chrome/browser/browser_features.cc:91`) installs Web Store ids listed in `initial_preferences` (`chrome_browser_main.cc:1995`, provider `:957-968`) | admin/user-supplied | JS | admin-controlled; nothing ships by default. Untouched |
| "External component" extensions | `external_component_loader.cc:43-46` | In-App Payments | JS | not active (branded only) |
| Bundled component extensions | `component_loader.cc:552-602` | compiled into the binary | JS | not downloaded. AIM eligibility and the NTP extension (both DISABLED) have component-updater refresh paths, patched (row 29). Upstream loads **Glic's extension by default** (`kApiGlicPrivate` ENABLED, `extensions/common/extension_features.cc:34`, `component_loader.cc:589-594`), although Glic itself is off on Linux: pages on `gemini.google.com`, `www.google.com` and other Google hosts can message it (§5). `chromium-157-glic-extension-needs-glic.patch` loads it only when Glic is enabled (`chrome://flags/#glic`) |
| Hunspell dictionaries | `spellcheck_hunspell_dictionary.cc:280-284` | dictionaries | data | untouched |
| Safe Browsing lists / CSD model | `v4_update_protocol_manager.cc`; CSD model via Optimization Guide | lists / TFLite | data | untouched |
| Google web content in `chrome-untrusted://` | NTP OneGoogleBar: the browser fetches `/async/newtab_ogb` (`one_google_bar_loader_impl.cc:42`) and splices its script fields into a bundled template served as `chrome-untrusted://new-tab-page/one-google-bar` (`untrusted_source.cc:174,342-352`, CSP `script-src 'self' 'unsafe-inline' https:` `:140`); no WebUI controller or Mojo there. Lens overlay. What's New is branded only in 158 (`whats_new_util.cc:35-42`) | Google web content | web-page JS | counted as web content (no privileged interfaces); §5 |
| **Translate element** | `components/translate/core/browser/translate_script.cc:55-56` fetches `translate.googleapis.com/translate_a/element.js`; `OnScriptFetchComplete` (`:197-245`) prepends the bundled `translate.js`; run in the translate isolated world (`translate_agent.cc:387-394`); `translate.js` then fetches more script from `translate.googleapis.com` and runs it with `new Function(…)` (`translate.js:433`). Triggered by "Translate this page" or a language set to always translate (`translate_manager.cc:466-485`), on any translatable URL (`translate_service.cc:147-154`) | browser-fetched JS, isolated world (no Mojo) | **JS** | **exception** (see the top): blocking it means no "Translate this page". Partial translate (`translateHtml`) is data |
| Variations seed | `variations_service.cc:284-300` | – | – | fetching is off in unbranded builds unless `--variations-server-url` is passed (`:290-297`); the patch doesn't rely on feature defaults anyway |

Also checked, nothing to block: Glic (off on Linux, `chrome_features.cc:528-535`; if enabled by flag,
`https://gemini.google.com/glic` gets privileged APIs through `chrome://glic`), the actor / agentic
browsing code (server actions are data; script tools only call tools the page declares,
`chrome/renderer/actor/script_tool.cc:112-123`), Contextual Tasks (a `<webview>` of Google AI Mode,
`postMessage` only), Reading Mode's CSP allowing translate hosts (`read_anything_untrusted_ui.cc:251-255`,
nothing bundled uses it), `chrome://newtab`'s CSP allowing Google hosts (`new_tab_ui.cc:208-212`, unused),
`.wasm` loaded by browser features (only WASM TTS, patched), browser-registered service workers (none),
Isolated Web Apps and Skills (DISABLED on Linux).

---

## 2. What the patch does

`chromium-158-no-runtime-executable-downloads.patch`: 14 files, plain `git diff` with `a/` `b/`
prefixes and a free-text header (works with `eapply`/`git apply`/`patch -p1`).

Design choices:

* Gates live in the individual installers' `Register*()` functions, **not** in `registration.cc`.
  That covers the on-demand registration paths too (SODA installer, Screen AI downloader,
  TranslateKit `installer_impl.cc`, Reading Mode's WASM TTS update), and keeps every hunk inside a
  function body that rarely changes upstream.
* Function bodies are *replaced* instead of adding an early `return`, because Chromium compiles with
  `-Wunreachable-code-aggressive`. Unused parameters are fine (`-Wno-unused-parameter`).
* Paths that an earlier, unpatched build stored (Widevine hint file, TranslateKit and SODA library
  paths) are ignored, so nothing such a build downloaded is loaded.
* Every edited region compiles the same under the default GN config and with
  `enable_screen_ai_service=false` / `build_with_tflite_lib=false` /
  `build_with_internal_optimization_guide=false` (files not built in a configuration are simply not
  compiled).

| File | Change |
|---|---|
| `chrome/browser/component_updater/widevine_cdm_component_installer.cc` | `RegisterWidevineCdmComponent()` → no-op |
| `chrome/common/media/cdm_registration.cc` | `GetHintedWidevine()` ignores the Component Update hint file and uses `<module dir>/WidevineCdm` (§3) |
| `chrome/browser/component_updater/wasm_tts_engine_component_installer.cc` | `RegisterWasmTtsEngineComponent()` → no-op |
| `chrome/browser/component_updater/dictation_connector_component_installer.cc` | `RegisterDictationConnectorComponent()` → no-op |
| `chrome/browser/component_updater/indigo_component_installer.cc` | `RegisterIndigoComponent()` → no-op |
| `chrome/browser/component_updater/commerce_heuristics_component_installer.cc` | always uninstalls |
| `chrome/browser/component_updater/component_extension_installer.cc` | AIM eligibility and NTP component extensions: always uninstalled (bundled copies unaffected) |
| `chrome/browser/component_updater/translate_kit_component_installer.cc` | `RegisterTranslateKitComponent()` → no-op (`--translate-kit-binary-path` still works) |
| `chrome/browser/on_device_translation/installer_impl.cc` | the library path stored in Local State is ignored |
| `components/on_device_translation/service_controller.cc` | `Translator.availability()` is `"unavailable"` without a library, so `create()` rejects instead of waiting for a download |
| `chrome/browser/component_updater/screen_ai_component_installer.cc` | registration only cleans up an old copy; `RegisterScreenAIComponent()` sets `kDownloadFailed` |
| `components/soda/soda_util.cc` | `IsSupportedLinux()` → `false` |
| `chrome/browser/speech/chrome_speech_recognition_service.cc` | the `libsoda.so` path stored in Local State is ignored |
| `chrome/browser/ui/webui/devtools/devtools_ui_data_source.cc` | `devtools://devtools-remote/…` → 404; CSP `script-src 'self'` |

Behavioural consequences: Live Caption / on-device Web Speech / Dictation are shown as unsupported; Reading
Mode falls back to system TTS voices; PDF OCR / main-content extraction report failure instead of downloading
Screen AI; the Translator web API reports every language pair as unavailable; `chrome://inspect` of remote
targets with a different DevTools version gets no front-end; DevTools UI languages outside its bundled
locales fall back to en-US.

---

## 3. Widevine with a system-provided CDM (USE=widevine)

How upstream finds a CDM on Linux (`chrome/common/media/cdm_registration.cc`, `chrome/common/chrome_paths.cc`):

1. **Bundled**: only with `bundle_widevine_cdm=true` (Chrome-branded builds). Looks at
   `<module dir>/WidevineCdm/` (`chrome::DIR_BUNDLED_WIDEVINE_CDM`).
2. **Hinted** (`ENABLE_WIDEVINE_CDM_COMPONENT`): reads
   `$USER_DATA_DIR/WidevineCdm/latest-component-updated-widevine-cdm` (`{"Path": "<cdm base dir>"}`). Only the
   Widevine component installer writes it, for a downloaded CDM or for a "preinstalled" one it found in
   `<module dir>/WidevineCdm`, which is how `www-plugins/chrome-binary-plugins`
   (`/usr/lib64/chromium-browser/WidevineCdm`) used to be picked up.

With the installer disabled, (2) would never see a system CDM again, but would still follow a hint file left by
an earlier build, possibly to a CDM *downloaded* by that build. So the patch changes `GetHintedWidevine()` to
ignore the hint file and use `<module dir>/WidevineCdm` if present. Result: `chrome-binary-plugins` works without
any user action (after a restart: the CDM is loaded before the zygote locks down), and nothing downloaded at
runtime is loaded. Compile-tested with the default `USE=widevine`; not runtime-tested (needs the proprietary
CDM).

---

## 4. Ebuild settings

The patch is applied unconditionally (hard rule). No GN args are needed for it; `enable_on_device_translation=false`
and `enable_screen_ai_service=false` don't build on Linux as is (rows 20, 22). Data components can be turned off
at runtime with policy `ComponentUpdatesEnabled=false`. Nothing sensible for SODA, Screen AI, TranslateKit or
WASM TTS as USE flags: they can't work without the download, so a flag would only re-enable it.

---

## 5. For later: "talking to Google about non-Google things"

Not addressed yet; background flows with their control point. "MSBB" = the "Make searches and browsing better"
consent (`url_keyed_anonymized_data_collection.enabled`), off by default in Chromium.

| Flow | Where | Trigger / data | Control |
|---|---|---|---|
| Optimization Guide hints | `components/optimization_guide/core/hints/hints_manager.cc:88-89` (GetHints) | per-navigation host/URL lists to `optimizationguide-pa.googleapis.com` | remote fetching needs MSBB **and** a Google API key (`optimization_guide_permissions_util.cc:15-56`); the component (row 5) is the no-consent fallback |
| Optimization Guide model downloads | `prediction_model_fetcher_impl.cc`, `prediction_model_download_manager.cc` | model requests (locale, version) | same |
| Server-side model execution (Compose, tab organization, …) | `remote_model_execution_common.h:34` (`chromemodelexecution-pa`); `kOptimizationGuideModelExecution` ENABLED (`optimization_guide_features.cc:100`) | page content | each feature has its own opt-in |
| Network time | `components/network_time/network_time_tracker.cc:155` | periodic `clients2.google.com/time` | feature `kNetworkTimeServiceQuerying` (ENABLED on Linux, `:73-78`), pref `network_time.network_time_queries_enabled` (`:309`, `:747`), policy `BrowserNetworkTimeQueriesEnabled` |
| Safe Browsing | list updates `v4_update_protocol_manager.cc`; real-time lookups `realtime/url_lookup_service.cc`; download protection `chrome/browser/safe_browsing/download_protection/`; CSD pings `client_side_detection_service.cc` | hashed prefixes (standard), full URLs (enhanced), download metadata | prefs `safebrowsing.enabled/enhanced`, policy `SafeBrowsingProtectionLevel`, GN `safe_browsing_mode` |
| SCT auditing | `chrome/browser/ssl/sct_reporting_service.cc` | certificate SCTs | only with Safe Browsing extended reporting / enhanced |
| Omnibox suggest / zero-suggest | `search_provider.cc`, `remote_suggestions_service.cc` | typed text; page URL for zero-suggest with MSBB | pref `search.suggest_enabled`; default search engine |
| Search prefetch, preconnect | `search_prefetch/field_trial_settings.cc:44` (ENABLED), `predictors/loading_predictor.cc` | – | pref `net.network_prediction_options` |
| NTP doodle, OneGoogleBar | `google_logo_api.cc:47`; `one_google_bar_loader_impl.cc:42` (`kNtpOneGoogleBar` ENABLED, `ntp_features.cc:178-184`) | with Google as default search engine; no consent | NTP customization prefs / policies |
| AI Mode eligibility | `aim_eligibility_service.cc:746`; `kAimEnabled`, `kAimServerEligibilityEnabled` ENABLED (`aim_eligibility_service_features.cc:11,13`) | OAuth token: signed-in users only | – |
| Glic extension bridge | `resources/glic/extension/manifest.json` (`externally_connectable` Google hosts), loaded by default upstream (§1b) | Google pages can query Glic state and ask it to act (`getState`, `invoke`, `activateTab`, …) | **done**: only loaded with Glic enabled (`chrome://flags/#glic`) |
| Autofill crowdsourcing / server predictions | `autofill_crowdsourcing_manager.cc:129` | form signatures of visited sites | `kAutofillServerCommunication` (`autofill_debug_features.cc:143`), autofill prefs |
| Password leak detection | `leak_detection_request.cc` | hashed credentials on sign-in | pref `profile.password_manager_leak_detection`, policy `PasswordLeakDetectionEnabled` |
| Translate | `translate_script.cc` (§1b), `translate_ranker_impl.cc`; partial translate `contextual_translate_delegate.cc:27` (`translate-pa`) | page text when the user translates; ranker model | pref `translate.enabled` / policy `TranslateEnabled` (offers and automatic translation only) |
| Spelling service | `spelling_service_client.cc`; dictionaries `spellcheck_hunspell_dictionary.cc:280-284` | typed text (opt-in) / dictionary downloads | pref `spellcheck.use_spelling_service` (`components/spellcheck/browser/pref_names.h:32`) |
| Component updater pings | `configurator_impl.cc`, `component_updater_url_constants.cc` (`update.googleapis.com`) | installed components + versions | policy `ComponentUpdatesEnabled` |
| About this site / merchant trust | `page_info/core/features.cc:33,40` (ENABLED) | when page info is opened | features |
| Private AI | `components/private_ai/features.cc:14` (ENABLED), `phosphor-pa.googleapis.com` (`:36-39`) | unclear whether it fires on its own | feature |
| Lens | `lens_features.cc:272,510` (`lensfrontend-pa`, `lens.google.com`) | screenshots, user-initiated | `kLensOverlay` |
| Variations seed | `variations_service.cc:284-300` | – | off in unbranded builds |
| UMA / crash reporting | `chrome_metrics_services_manager_client.cc` | – | consent, off by default |
| Domain reliability | `components/domain_reliability/google_configs.cc` | failures reaching Google domains; uploads also need UMA (`profile_network_context_service.cc:1496-1507`) | policy `DomainReliabilityAllowed` |
| Captive-portal probes | `captive_portal_detector.cc:24-26` | on network errors | tied to `kAlternateErrorPagesEnabled` (`captive_portal_service.cc:85-92`) |
| Commerce / shopping, history embeddings | `shopping_service.cc`; `components/history_embeddings/` | – | `kShoppingList` and history embeddings DISABLED |
| HaTS surveys | `hats_service_desktop.cc:595-604` | survey web content | needs metrics consent |
| Geolocation | `network_location_request.cc:49` | after a site gets location permission | site permission |
| DevTools `remoteBase` | `devtools_window.cc:1460-1489`, `devtools_ui.cc:42-45` | with DevTools open: CSS docs data and non-bundled UI locales from `chrome-devtools-frontend.appspot.com` | make `GetRemoteBaseURL()` empty; code from there is already blocked (patch + CSP) |
| Media Router, image proxy, search-engine choice, attribution reports | as in the 156 audit | – | not re-checked for 158 |

---

## Observed: first-launch traffic (156, 2026-10-14, default USE config)

Hosts contacted within about 90 seconds of the first start, with a fresh profile and Google as the default
search engine; the smoke test opened the NTP and typed into the omnibox (`--log-net-log`). Not repeated for 158.

- **Google NTP / search (expected, Google features):** `www.google.com` (NTP, `/complete/search` suggestions,
  `/async/*`), `www.gstatic.com`, `fonts.gstatic.com`, `ogads-pa.clients6.google.com` (OneGoogle bar),
  `accounts.google.com/ListAccounts`, and `play.google.com/log` (logging from the Google NTP page itself).
- **Component updater:** `update.googleapis.com/service/update2/json`, with downloads from `edgedl.me.gvt1.com`:
  Optimization Guide Models Manifest, Optimization Hints, Trust Token key commitments (all data), and
  differential updates. No executable code: the profile contained no ELF/WASM/JS outside the web cache.
- **Optimization guide:** `optimizationguide-pa.googleapis.com/v1:GetModels` (model metadata).
- **Spellcheck dictionary:** `redirector.gvt1.com/edgedl/chrome/dict/en-us-10-2.bdic`.
- **Network time:** `clients2.google.com/time/1/current`.
