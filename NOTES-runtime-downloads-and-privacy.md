# Chromium 156 (Linux, unbranded): runtime downloads of executable code, and privacy notes

Scope: Chromium 156.0.8078.12, `is_chrome_branded=false`, Linux desktop, as built by
`www-client/chromium/chromium-156.0.8078.12.ebuild`. All `file:line` references are
into the pristine 156 tree. Research was read-only (no compile).

Hard rule this work enforces: **Chromium must not download executable code at runtime,
aside from wasm/JS used by actual web pages.** "Executable" = native shared libraries,
WebAssembly, or JavaScript that runs outside a normal web page (component extensions,
content scripts injected by the browser, privileged WebUI / DevTools contexts).
ML models (TFLite flatbuffers, weights, tokenizers) are *computation graphs executed by
an interpreter that is compiled into Chromium*; custom ops are compiled in, not
downloaded. They are treated as **data** here (with that nuance noted), as are lists,
protobuf configs and dictionaries.

Deliverable patch: `www-client/chromium/files/chromium-156-no-runtime-executable-downloads.patch`
(applies cleanly to the pristine tree: `git apply --check` and `patch -p1 --dry-run` both OK).

---

## 1. Inventory

### 1a. Component updater components registered in `chrome/browser/component_updater/registration.cc`

`RegisterComponentsForUpdate()` is at `registration.cc:144-256`. "Active" = registered in a
Linux Chromium build with the ebuild's default GN config. "User cfg" = a custom `EXTRA_GN`
(e.g. `build_with_internal_optimization_guide=false`).

| # | Component (manifest name / dir) | Registered at | Payload | Exec? | Active on Linux Chromium | Build / feature control | User cfg already | Action |
|---|---|---|---|---|---|---|---|---|
| 1 | Recovery Improved | `registration.cc:147-149` | updater recovery binary | native | **No** (`IS_WIN \|\| IS_MAC` only; impl files only built `if (is_chrome_branded)`, `component_updater/BUILD.gn:265-283`) | platform | n/a | none |
| 2 | **Widevine CDM** (`WidevineCdm`, id oimompecagnajdejgnnjijobebaeigek) | `registration.cc:151-153` | `_platform_specific/linux_x64/libwidevinecdm.so` + manifest | **native .so** | **Yes** when `enable_widevine=true` (USE=widevine, Gentoo default on) | `ENABLE_WIDEVINE_CDM_COMPONENT` = `enable_library_widevine_cdm && is_linux` (`third_party/widevine/cdm/widevine.gni`, plain assignment, **not** a `declare_args()` so it cannot be set from GN args) | – | **patched**: `RegisterWidevineCdmComponent()` is a no-op (`widevine_cdm_component_installer.cc:438`). System CDM still works, see §3 |
| 3 | Subresource Filter (`Unindexed Rules`) | `:155` | filter ruleset | data | Yes | always | – | none |
| 4 | On-Device Head Suggest | `:156` | binary suggestion model (trie) | data | Yes | always | – | none |
| 5 | Optimization Hints | `:158` | protobuf hints config | data | Yes | always | – | none (data) |
| 6 | Trust Token Key Commitments | `:159` | JSON | data | Yes | feature | – | none |
| 7 | Private Verification Tokens | `:160` | JSON config | data | Yes | feature | – | none |
| 8 | First-Party Sets | `:161` | list | data | Yes | always | – | none |
| 9 | Privacy Sandbox Attestations | `:162` | proto list | data | Yes | always | – | none |
| 10 | Actor Safety Lists | `:163` | allow/block lists (Glic actor) | data | Yes | always | – | none |
| 11 | History Search Strings | `:164-166` | strings | data | only if history-embeddings feature | feature | – | none |
| 12 | SSL Error Assistant | `:167` | proto | data | Yes | always | – | none |
| 13 | **Indigo** (`indigo/content_script.js`) | `:169` | `content_script.js` injected into web pages by `chrome/browser/indigo/indigo_service.cc:205` | **JS (browser-injected content script)** | registered only if `features::kIndigoComponent` (DISABLED by default, `chrome/common/chrome_features.cc:1467`) | feature flag only | – | **patched**: `RegisterIndigoComponent()` no-op (`indigo_component_installer.cc:127`) |
| 14 | File Type Policies | `:171-173` | proto | data | Yes (`SAFE_BROWSING_AVAILABLE`) | `safe_browsing_mode` | – | none |
| 15 | CRLSet | `:179` | cert revocation list | data | Yes | always | – | none |
| 16 | Origin Trials | `:182` | config | data | Yes | always | – | none |
| 17 | Media Engagement Preload | `:183` | list | data | Yes | always | – | none |
| 18 | PKI Metadata (+ fast-push) | `:185` | Chrome Root Store / CT logs | data | Yes | `chrome_root_store_supported` | – | none |
| 19 | Safety Tips | `:187` | list | data | Yes | always | – | none |
| 20 | Crowd Deny | `:188` | list | data | Yes | always | – | none |
| 21 | Smart Dim / Chrome Apps allowlist | `:190-193` | – | – | **No** (ChromeOS) | platform | n/a | none |
| 22 | Hyphenation | `:195-197` | hyphenation dictionaries | data | Yes (`use_minikin_hyphenation = !is_apple`, `third_party/blink/public/public_features.gni:13`) | GN | – | none |
| 23 | **Dictation Connector** (`DictationConnector`) | `:200` | `manifest.json`, `background_compiled.js`, `offscreen_compiled.js`, `offscreen.html` loaded as a component extension (`chrome/browser/dictation/connector_component_extension.cc:53-96`) | **JS (component extension)** | registered only if `dictation::kDictation` (DISABLED by default, `chrome/browser/dictation/features.cc`) | feature flag only | – | **patched**: `RegisterDictationConnectorComponent()` no-op (`dictation_connector_component_installer.cc:181`) |
| 24 | IWA Key Distribution | `:201` | key/config proto | data | Yes | always | – | none |
| 25 | Zxcvbn Data | `:202` | password-strength word lists | data | Yes | always | – | none |
| 26 | Real-Time URL Checks Allowlist | `:205-207` | – | – | **No** (Android) | platform | n/a | none |
| 27 | **Screen AI** (`screen_ai`) | `:209-211` (`ManageScreenAIComponentRegistration`, registers at startup if used recently / a11y feature on) and **on demand** from `chrome/browser/screen_ai/screen_ai_downloader_non_chromeos.cc:35` (PDF OCR, Reading Mode main-content extraction) | `libchromescreenai.so` | **native .so** | **Yes** in default config | `enable_screen_ai_service` (`services/screen_ai/buildflags/features.gni`, default true on Linux). NB: `=false` alone does **not** build: `component_updater/BUILD.gn:230-235` depends on `//chrome/browser/screen_ai:screen_ai_install_state` unconditionally and `chrome/browser/screen_ai/BUILD.gn:8` asserts the flag | – | **patched**: `ManageScreenAIComponentRegistration()` only cleans up, `RegisterScreenAIComponent()` reports `kDownloadFailed` (`screen_ai_component_installer.cc:125-151`) |
| 28 | Commerce Heuristics | `:213` | JSON | data | Yes | always | – | none |
| 29 | **TranslateKit** (`TranslateKit`) | `:215-225` (startup, only if previously registered) and **on demand** from `chrome/browser/on_device_translation/installer_impl.cc:344` when a page uses the `Translator`/`LanguageDetector` web APIs | `TranslateKitFiles/libtranslatekit.so` | **native .so** | **Yes** | `ENABLE_ON_DEVICE_TRANSLATION` (`components/on_device_translation/buildflags/features.gni`, default true on Linux). `enable_on_device_translation=false` is **not buildable on Linux** as-is: `chrome/browser/chrome_browser_interface_binders_webui_parts_desktop.cc:158,519-521` includes/binds `on_device_translation_internals` unguarded and `chrome/browser/ui/BUILD.gn:3245` depends on it | – | **patched**: `RegisterTranslateKitComponent()` no-op (`translate_kit_component_installer.cc:207`); `--translate-kit-binary-path` (system-provided library) still honoured (`installer_impl.cc:52-55,328-333`) |
| 29b | TranslateKit language packs (`:221-224`, `installer_impl.cc:376`) | | translation model/dictionary files | data (ML) | Yes | same | – | none (useless without the library; harmless) |
| 30 | Amount Extraction Heuristic Regexes | `:227-231` | regex list | data | Yes | always | – | none |
| 31 | **WASM TTS Engine** (`WasmTtsEngine`, id bjbcblmdcnggnibecjikpoljcgkbgphl) | `:233-235` (startup) + on-demand `UpdateWasmComponentOnDemand()` from `chrome/browser/ui/read_anything/read_anything_service.cc:71` when Reading Mode opens | `bindings_main.wasm`, `bindings_main.js`, `streaming_worklet_processor.js`, `background_compiled.js`, `offscreen_compiled.js`, manifest; installed as a component extension via `EmbeddedA11yExtensionLoader` (`wasm_tts_engine_component_installer.cc:214-216`) | **wasm + JS (component extension)** | **Yes** | platform (`IS_WIN\|\|IS_MAC\|\|IS_LINUX`); `features::kWasmTtsEngineAutoInstallDisabled` is DISABLED by default (`ui/accessibility/accessibility_features.cc:497`) | – | **patched**: `RegisterWasmTtsEngineComponent()` no-op (`:305`). The on-demand update of an unregistered id is rejected with `INVALID_ARGUMENT` (`components/component_updater/component_updater_service.cc:384-397`) |
| 32 | Captcha Providers | `:237` | JSON | data | Yes | always | – | none |
| 33 | Platform Runtime (`chrome_platform_runtime`) | `:239` | native library loaded with `LoadNativeLibraryWithOptions` (`chrome/common/platform_runtime/platform_runtime_impl.cc:79`) | **native** | **No**: registration body is `#if BUILDFLAG(IS_WIN) && BUILDFLAG(GOOGLE_CHROME_BRANDING)` (`platform_runtime_component_installer.cc:554-594`) | platform+branding | n/a | none needed |
| 34 | AI Embeddings Model | `:243-244` | `model.tflite` + `tokenizer.spm` | data (ML) | only if `blink::features::kAIEmbeddingsAPI` / passage-embedder features | feature | – | none |
| 35 | **AIM Eligibility Component Extension** (id kabpfonokkamggpgbldambnmkliehlbh) | `:249-251` | a newer copy of the *bundled* omnibox "AI Mode" eligibility component extension (HTML/JS), staged via `extensions::ComponentLoader::MaybeStageExtension` (`aim_eligibility_component_installer.cc:84`; loader side `chrome/browser/extensions/component_loader.cc:540-559`) | **JS (component extension)** | registered only if `omnibox::kAimEligibilityComponentExtension` (DISABLED by default, `components/omnibox/common/omnibox_features.cc:175`) | feature flag only; `ENABLE_EXTENSIONS_CORE` | – | **patched**: always takes the `Uninstall()` branch; the **bundled** extension keeps being loaded, the AI Mode button is untouched |

Other users of `ComponentInstaller` outside `registration.cc` (`git grep MakeRefCounted<ComponentInstaller>`):

| Component | Registered from | Payload | Exec? | Active | Control | Action |
|---|---|---|---|---|---|---|
| **SODA** (`SODA Library`) + SODA language packs | `chrome/browser/accessibility/soda_installer_impl.cc:65,93` ← `speech::SodaInstaller::Init()` (`components/soda/soda_installer.cc:90-128`), called from `chrome/browser/chrome_browser_main.cc:1660` and `components/live_caption/live_caption_controller.cc:137` when Live Caption / on-device Web Speech / Dictation is enabled, was used recently, or `media::kPreemptiveSodaDownload` (DISABLED by default, `media/base/media_switches.cc:911`) | `libsoda.so` (+ language pack model files) | **native .so** (packs: data) | **Yes** on x86-64 with AVX (`components/soda/soda_util.cc:43-53`) | `captions::IsLiveCaptionFeatureSupported()` → `speech::IsOnDeviceSpeechRecognitionSupported()` → `IsSupportedLinux()`; `media::kLiveCaption` ENABLED by default | **patched**: `IsSupportedLinux()` returns false, so neither `RegisterSodaComponent` nor `RegisterSodaLanguageComponent` ever registers (`soda_component_installer.cc:234,259`) and the Live Caption / on-device speech UI reports "unsupported" instead of offering a download |
| Optimization Guide on-device model (`OptGuideOnDeviceModel`, `OptimizationGuideModelsManifest`) | `chrome/browser/optimization_guide/model_execution/optimization_guide_global_state.cc:108-121` (`ManifestBrokerState`) under `USE_ON_DEVICE_MODEL_SERVICE` (true on Linux) | model weights/config | data (ML) | gated on `kOptimizationGuideModelExecution` + performance-class evaluation; in unbranded builds `ENABLE_ML_INTERNAL=false` so the service uses the fake backend (`services/on_device_model/on_device_model_service.cc:38-42`) | `build_with_internal_optimization_guide` (default = `is_chrome_branded` = false) | none. The inference library `liboptimization_guide_internal.so` is **never downloaded**: it is only looked up in `DIR_MODULE` (`services/on_device_model/ml/chrome_ml_holder.cc:28-51`, `components/optimization_guide/core/optimization_guide_library_holder.cc`) and does not exist in Chromium builds |
| Prediction models (`OptGuidePredictionModels`) and direct model downloads | `optimization_guide_global_state.cc:136-144` → `components/component_updater/installer_policies/prediction_model_component_installer.cc`; and `components/optimization_guide/core/delivery/prediction_model_download_manager.cc` (CRX from the OptimizationGuide service) | TFLite flatbuffers (+ metadata) | data (ML; executed by the compiled-in TFLite interpreter) | Yes | `kOptimizationHints`, `kRemoteOptimizationGuideFetching`, MSBB consent | none (see §5 for the privacy angle) |
| ChromeOS `cros_component_installer`, smart dim, app deprecation allowlist | ChromeOS only | – | – | No | platform | none |

Sanity sweep: `git grep LoadNativeLibrary -- chrome components services media content/browser` finds only
`DIR_MODULE`-relative loads (optimization_guide_internal, chrome_shape_detection, chrome_ml), Android/Windows
system libraries, and the platform-runtime component (Windows+branded). The CDM (`media/cdm/cdm_module.cc`),
SODA (`chrome/services/speech/soda`), Screen AI (`services/screen_ai`) and TranslateKit
(`components/on_device_translation/service`) loaders are fed only by the components covered above.

### 1b. Mechanisms other than the component updater

| Mechanism | Where | What | Exec? | Status / action |
|---|---|---|---|---|
| **DevTools remote front-end** | `chrome/browser/ui/webui/devtools/devtools_ui_data_source.cc:182-204` serves `devtools://devtools/remote/serve_file/@<rev>/…` by fetching from `https://chrome-devtools-frontend.appspot.com/` (`chrome/browser/devtools/url_constants.cc:7-10`); CSP explicitly allows that host (`:234`). Used when `chrome://inspect` opens a remote target (Android device / remote-debugging browser) whose version differs, and for the `remoteBase` module loading of such sessions (`chrome/browser/devtools/devtools_ui_bindings.cc:388-409`) | JS run in the privileged `devtools://` origin | **JS** | **patched**: the `remote/` branch now always answers 404. The bundled front-end (`devtools://devtools/bundled/`) is unaffected. `--custom-devtools-frontend=<url>` (`devtools://devtools/custom/`) is an explicit developer switch and is left alone |
| Extensions from the Chrome Web Store | `extensions::ExtensionUpdater`, `chrome/browser/extensions/updater/` | user-installed extensions and their auto-updates | JS | **user-initiated** – out of scope, untouched. Policy force-installs (`ExtensionInstallForcelist`, `external_provider_impl.cc:760-765`) are admin-initiated |
| External extensions from JSON manifests | `ExternalPrefLoader` for `/usr/share/chromium/extensions` (`chrome::DIR_EXTERNAL_EXTENSIONS`, `external_provider_impl.cc:895-900`) and `~/.config/chromium/External Extensions` (`DIR_USER_EXTERNAL_EXTENSIONS`, `:905-912`) | whatever the admin/user drops there (may point at the Web Store) | JS | admin/user-controlled; nothing ships there by default. Untouched |
| "External component" extensions (Web Store installs that look built-in) | `chrome/browser/extensions/external_component_loader.cc:45-47` | In-App Payments Support app | JS | **not active**: `GOOGLE_CHROME_BRANDING` only. Other entries are ChromeOS only. `default_apps.cc` no longer exists in 156 |
| Component extensions bundled in resources (PDF viewer, Hangouts (`enable_hangout_services_extension`), network speech synthesis, Glic (off by default on Linux; its web client is loaded from Google only if enabled by flag), AIM eligibility, …) | `chrome/browser/extensions/component_loader.cc` | compiled into the binary | JS | not downloaded. The only component extension with a component-updater refresh path (`MaybeStageExtension`) is AIM eligibility (patched) |
| Hunspell dictionaries | `chrome/browser/spellchecker/spellcheck_hunspell_dictionary.cc:281` (`redirector.gvt1.com/edgedl/chrome/dict/*.bdic`) | dictionaries | data | untouched |
| Safe Browsing lists / client-side-detection model | `components/safe_browsing/core/browser/db/v4_update_protocol_manager.cc`, CSD model via Optimization Guide | lists / TFLite | data | untouched |
| Google web content in `chrome-untrusted://` iframes (NTP OneGoogleBar/Doodle/modules, `chrome://whats-new`, Lens overlay) | `chrome/browser/new_tab_page/one_google_bar/one_google_bar_loader_impl.cc`, `chrome/browser/ui/webui/whats_new/whats_new_util.cc`, `components/lens` | ordinary web pages in sandboxed frames | web-page JS | this *is* "wasm/JS used by actual web pages", served by Google about Google things. Untouched; listed in §5 |
| Translate element | `components/translate/core/browser/translate_script.cc` fetches `translate.googleapis.com/translate_a/element.js` and injects it into the page when the user asks to translate | JS in the page's renderer | web-page JS, user-initiated | untouched; §5 |
| Variations seed | `components/variations/service/variations_service.cc:276-290`: fetching is **disabled in non-Google-branded builds** unless `--variations-server-url` is passed | – | – | so feature flags that are DISABLED by default (Indigo, Dictation, AIM component, preemptive SODA) stay off unless the user flips them; the patch nevertheless removes those registrations so the hard rule does not depend on feature defaults |

---

## 2. What the patch does

`www-client/chromium/files/chromium-156-no-runtime-executable-downloads.patch` – 12 files, ~140 changed lines,
plain `git diff` with `a/` `b/` prefixes, free-text header on top (works with `eapply`/`git apply`/`patch -p1`).

Design choices:

* Gates live in the individual installers' `Register*()` functions, **not** in `registration.cc`.
  That covers the on-demand registration paths too (SODA installer, Screen AI downloader,
  TranslateKit `installer_impl.cc`, Reading Mode's WASM TTS update), keeps every hunk inside a function
  body that rarely changes upstream.
* Function bodies are *replaced* instead of adding an early `return` because Chromium compiles with
  `-Wunreachable-code-aggressive` (`build/config/compiler/BUILD.gn:2243`). Unused parameters are fine
  (`-Wno-unused-parameter`, `:1962`). No anonymous-namespace helper becomes unused
  (`SetBinaryPathInPrefs` is still used twice in the TranslateKit installer; `ShouldInstall` is a static
  member; `StartRemoteDataRequest` is a private member that stays defined).
* Every edited region is compiled identically under the default GN config and under such an EXTRA_GN;
  the only config-dependent file is `screen_ai_component_installer.cc`, which isn't compiled with
  `enable_screen_ai_service=false` (the hunk still applies textually).

| File | Change |
|---|---|
| `chrome/browser/component_updater/widevine_cdm_component_installer.cc` | `RegisterWidevineCdmComponent()` → no-op |
| `chrome/common/media/cdm_registration.cc` | `GetHintedWidevine()` ignores the Component Update hint file (it may point at a CDM downloaded by an earlier build) and uses `<module dir>/WidevineCdm` instead, see §3 |
| `chrome/browser/component_updater/wasm_tts_engine_component_installer.cc` | `RegisterWasmTtsEngineComponent()` → no-op |
| `chrome/browser/component_updater/dictation_connector_component_installer.cc` | `RegisterDictationConnectorComponent()` → no-op |
| `chrome/browser/component_updater/indigo_component_installer.cc` | `RegisterIndigoComponent()` → no-op |
| `chrome/browser/component_updater/translate_kit_component_installer.cc` | `RegisterTranslateKitComponent()` → no-op (`--translate-kit-binary-path` still works) |
| `chrome/browser/on_device_translation/installer_impl.cc` | `GetTranslateKitLibraryPath()` only honours `--translate-kit-binary-path`, not a path stored in local state by the installer of an earlier build |
| `components/on_device_translation/service_controller.cc` | `CanTranslateImpl()` reports `kNoNotSupportedLanguage` while there is no library, so `Translator.availability()` is `"unavailable"` and `create()` rejects instead of waiting for a download |
| `chrome/browser/component_updater/screen_ai_component_installer.cc` | `ManageScreenAIComponentRegistration()` only cleans up an old copy; `RegisterScreenAIComponent()` sets `kDownloadFailed` so UI waiting on it gives up |
| `chrome/browser/component_updater/aim_eligibility_component_installer.cc` | `ManageAimEligibilityComponentRegistration()` always uninstalls the component-updated copy; bundled extension keeps loading |
| `components/soda/soda_util.cc` | `IsSupportedLinux()` → `false` (on-device speech reported unsupported, no SODA/language-pack registration) |
| `chrome/browser/ui/webui/devtools/devtools_ui_data_source.cc` | `devtools://devtools/remote/…` → 404 instead of fetching from appspot.com; CSP `script-src 'self'` (no longer allows chrome-devtools-frontend.appspot.com) |

Behavioural consequences: Live Caption / on-device Web Speech / Dictation are shown as unsupported; Reading Mode
falls back to system TTS voices (no "natural" voices); PDF OCR / main-content extraction report failure instead
of downloading Screen AI; the Translator web API reports every language pair as unavailable;
`chrome://inspect` of remote targets with a different DevTools version does not get a front-end; DevTools UI
languages outside DevTools' bundled locales fall back to en-US (they were fetched from `remoteBase`).

Confidence that it compiles in both configs: **high**. Risky spots, in order: (1) the ScreenAI hunk relies on
`ScreenAIInstallState::SetState(kDownloadFailed)` being legal from any state (it is: `screen_ai_install_state.cc:161-174`
only DCHECKs on *repeated* states and explicitly allows repeated `kDownloadFailed`); (2) the DevTools hunk leaves
`kRemoteFrontendBase`/`kRemoteFrontendDomain` (extern consts) and `DevToolsUIBindings` unused in that TU – not a
warning; (3) `base/cpu.h` becomes an unused include in `soda_util.cc` – not a warning.

---

## 3. Widevine with a system-provided CDM (USE=widevine)

How upstream 156 finds a CDM on Linux (`chrome/common/media/cdm_registration.cc`, `chrome/common/chrome_paths.cc:310-332`):

1. **Bundled**: only with `bundle_widevine_cdm=true` (`BUNDLE_WIDEVINE_CDM`, Chrome-branded builds only).
   Looks at `<module dir>/WidevineCdm/` (`chrome::DIR_BUNDLED_WIDEVINE_CDM`).
2. **Hinted** (`ENABLE_WIDEVINE_CDM_COMPONENT`, true on Linux x64/arm64 with `enable_widevine=true`): reads
   `$USER_DATA_DIR/WidevineCdm/latest-component-updated-widevine-cdm` (`{"Path": "<cdm base dir>"}`). Only the
   Widevine component installer writes it, either for a downloaded CDM or for a "preinstalled" one it found in
   `<module dir>/WidevineCdm` – which is how `www-plugins/chrome-binary-plugins`
   (`/usr/lib64/chromium-browser/WidevineCdm`) used to be picked up.

With the installer disabled, (2) would never see a system CDM again, but would still follow a hint file left by an
earlier build – possibly to a CDM *downloaded* by that build. So the patch changes `GetHintedWidevine()` to ignore
the hint file and use `<module dir>/WidevineCdm` (i.e. `/usr/lib64/chromium-browser/WidevineCdm`) if present.
Result: `chrome-binary-plugins` works without any user action (after a restart: the CDM is loaded before the zygote
locks down), and nothing downloaded at runtime is ever loaded. Compile-tested with the default `USE=widevine`;
not runtime-tested (needs the proprietary CDM).

---

## 4. Recommended ebuild changes (written before implementation; 1–2 are done)

1. Add `"${FILESDIR}/chromium-156-no-runtime-executable-downloads.patch"` to `PATCHES`. Unconditional (hard rule).
2. No new GN args are required for the hard rule. Explicitly **not** recommended: `enable_on_device_translation=false`
   (not buildable on Linux without extra patches, see table row 29) and `enable_screen_ai_service=false`
   (doesn't build as is, row 27).
3. USE-flag ideas (optional; the executable-download gates stay unconditional either way):
   * `component-updates` (default on): default component updates off only with `-component-updates`, for users who
     also want to stop data components. Alternative: a `--component-updater=...` runtime flag / policy
     `ComponentUpdatesEnabled=false` already exists (`components/component_updater/pref_names.cc`).
   * `widevine`: kept; handled in the patch (§3), no user action needed.
   * Nothing sensible for SODA/ScreenAI/TranslateKit/WASM-TTS: they cannot work without the download, so a USE flag
     would only re-enable the download.

---

## 5. For later: "talking to Google about non-Google things"

Not required for the first ebuild; a seed list of background flows seen while doing the above, with the control
point. "MSBB" = the "Make searches and browsing better" / URL-keyed anonymized data collection consent
(`url_keyed_anonymized_data_collection.enabled`), off by default in Chromium but easy to toggle on.

| Flow | Where | Trigger / data | Control |
|---|---|---|---|
| Optimization Guide hints | `components/optimization_guide/core/hints/hints_fetcher.cc`, `chrome/browser/optimization_guide/chrome_hints_manager.cc` | per-navigation host/URL lists sent to `optimizationguide-pa.googleapis.com` | `kOptimizationHints` (ENABLED, `optimization_guide_features.cc:60`), remote fetching requires MSBB; the component (row 5) is the no-consent fallback |
| Optimization Guide model downloads | `components/optimization_guide/core/delivery/prediction_model_fetcher_impl.cc`, `prediction_model_download_manager.cc` | model requests include locale/version, not URLs | same |
| Server-side model execution (Compose, tab organization, history search, …) | `components/optimization_guide/core/model_execution/model_execution_fetcher.cc` | page content | none; feature-gated, privacy work |
| Network time | `components/network_time/network_time_tracker.cc:58-64` | periodic `clients2.google.com/time` | none |
| Safe Browsing | list updates `components/safe_browsing/core/browser/db/v4_update_protocol_manager.cc`; real-time URL lookups `components/safe_browsing/core/browser/realtime/url_lookup_service.cc`; download protection `chrome/browser/safe_browsing/download_protection/`; CSD phishing pings `components/safe_browsing/content/browser/client_side_detection_service.cc`; extended reporting | hashed prefixes (standard), full URLs (enhanced), download metadata | prefs `safebrowsing.enabled/enhanced`, policy `SafeBrowsingProtectionLevel`, GN `safe_browsing_mode` |
| SCT auditing | `chrome/browser/ssl/sct_reporting_service.cc` | certificate SCTs of any site | only with Safe Browsing extended reporting / enhanced |
| Omnibox suggest / zero-suggest | `components/omnibox/browser/search_provider.cc`, `remote_suggestions_service.cc` | typed text; current page URL for zero-suggest when MSBB | pref `search.suggest_enabled`; default search engine |
| Preconnect to default search engine | `chrome/browser/predictors/loading_predictor.cc` | at startup / omnibox focus | pref `net.network_prediction_options` |
| Autofill crowdsourcing / server predictions | `components/autofill/core/browser/crowdsourcing/autofill_crowdsourcing_manager.cc` | form signatures of visited sites queried/uploaded | `kAutofillServerCommunication`, autofill prefs |
| Password leak detection | `components/password_manager/core/browser/leak_detection/leak_detection_request.cc` | hashed credentials on every sign-in | pref `profile.password_manager_leak_detection`, policy `PasswordLeakDetectionEnabled` |
| Translate | `components/translate/core/browser/translate_script.cc`, `translate_ranker_impl.cc` | page text to `translate.googleapis.com` when the user translates; ranker model fetch | prefs `translate.enabled`; Vanadium patches 0084/0099/0147 as reference |
| Spelling service | `components/spellcheck/browser/spelling_service_client.cc`; dictionaries `chrome/browser/spellchecker/spellcheck_hunspell_dictionary.cc:281` | typed text (opt-in) / dictionary downloads | pref `spellcheck.use_spelling_service` |
| Component updater pings | `components/component_updater/configurator_impl.cc`, `component_updater_url_constants.cc:17-21` (`update.googleapis.com`) | list of installed components + versions, periodic | policy `ComponentUpdatesEnabled`; Vanadium patch 0090 ("disable component updater pings") as reference |
| Variations seed | `components/variations/service/variations_service.cc:276-290` | – | already off in unbranded builds |
| UMA / crash reporting | `chrome/browser/metrics/chrome_metrics_services_manager_client.cc` | – | consent-gated, off by default |
| Domain reliability | `components/domain_reliability/google_configs.cc` | beacons about failures reaching Google domains only | policy `DomainReliabilityAllowed` |
| Captive-portal / connectivity probes | `components/captive_portal/core/captive_portal_detector.cc` (`gstatic.com/generate_204`) | on network errors | pref `captive_portal` / policy |
| Page content annotations / history embeddings | `components/page_content_annotations/core/page_content_annotations_service.cc`, `components/history_embeddings/` | page content, on-device mostly | none; privacy work |
| Commerce / shopping | `components/commerce/core/shopping_service.cc` | product URLs/page info of shopping sites | MSBB + `kShoppingList`-style features |
| HaTS surveys | `chrome/browser/ui/hats/hats_service_desktop.cc` | loads Google survey web content triggered on arbitrary sites | feature-gated |
| NTP remote content, What's New | `chrome/browser/new_tab_page/one_google_bar/one_google_bar_loader_impl.cc`, `chrome/browser/ui/webui/whats_new/whats_new_util.cc` | Google web content about Google things | prefs/policies (`PromotionsEnabled`, NTP customizations) |
| Image proxy | `components/image_fetcher/core/image_fetcher_service.cc` | NTP module images via Google image service | with the features that use it |
| Search-engine-choice / geo | `components/search_engines/search_engine_choice/search_engine_choice_service.cc` | – | – |
| Media Router / Cast | local mDNS discovery | local network | pref `media_router.enable_media_router`; cloud services off by default |
| DevTools `remoteBase` | `chrome/browser/devtools/devtools_window.cc:1445`, front-end `panels/elements/WebCustomData.ts`, `core/i18n/i18nImpl.ts` | when DevTools is open: CSS documentation data and non-bundled UI locales (JSON) from `chrome-devtools-frontend.appspot.com` | make `DevToolsUI::GetRemoteBaseURL()` return an empty URL; code from there is already blocked by the patch and the CSP |
| Attribution / private aggregation reports | sites, not Google | – | privacy sandbox prefs |

---

## Observed: first-launch traffic (2026-10-14, default USE config)

These are hosts contacted within about 90 seconds of the first start, with a fresh
profile and Google as the default search engine. The smoke test opened the NTP and
typed into the omnibox. Data comes from `--log-net-log`.

- **Google NTP / search (expected, Google features):** `www.google.com` (NTP,
  `/complete/search` suggestions, `/async/*`), `www.gstatic.com`, `fonts.gstatic.com`,
  `ogads-pa.clients6.google.com` (OneGoogle bar), `accounts.google.com/ListAccounts`,
  and `play.google.com/log` (logging from the Google NTP page itself).
- **Component updater:** `update.googleapis.com/service/update2/json`, with downloads
  from `edgedl.me.gvt1.com`.
  - Installed within the window: Optimization Guide Models Manifest (a list of
    models), Optimization Hints, and Trust Token key commitments. All are data.
  - Other downloads in flight were differential updates (subresource filter rules, …).
  - No executable code: the profile contained no ELF/WASM/JS outside the web cache.
- **Optimization guide:** `optimizationguide-pa.googleapis.com/v1:GetModels`
  (model metadata).
- **Spellcheck dictionary:** `redirector.gvt1.com/edgedl/chrome/dict/en-us-10-2.bdic`.
- **Network time:** `clients2.google.com/time/1/current`.

Candidates for the privacy work are the component-updater pings, `GetModels`, network
time and the dictionary fetch. The NTP traffic is part of using Google's NTP and search.
