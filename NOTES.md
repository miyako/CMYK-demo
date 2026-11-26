# Notes: chokepoints, failures and findings

Time-ordered observations from building this demo against `miyako/CMYK` 0.1.2
with 4D 21R4 / tool4d `21R4.100224` on macOS arm64. Every item below was hit for
real in this repository, not inferred from documentation.

## Chokepoints that cost the most time

| # | Symptom | Real cause | Fix used here |
| --- | --- | --- | --- |
| 1 | `Unknown member method` (-10729) pointing at a class function that clearly exists | The function *did* exist; a `File("name.tif")` inside its argument chain received a **relative** filename and threw `FiFo [3] A valid posix path was expected`. The wrapped error surfaced as -10729 with an empty method name. | Resolve an absolute path (`Folder(...).file(name).path`) before calling any helper that does `File(...)`; keep argument chains short. |
| 2 | `SystemWorker` refuses to start: `launch_failed: 4D could not create the system worker`, plus `POSX [13] Permission denied` | `zipfile.extractall` in Python drops Unix modes, so the staged `Resources/bin/macOS/image-cmyk` came out non-executable. The same code worked when the component was unpacked by `unzip`/git. | `scripts/stage_component.py` re-applies `external_attr >> 16` modes after extraction. |
| 3 | `4D was expecting a picture` (`[59]`), only in the headless report | A typed `Picture` property that was never assigned is **not** an empty picture when read back through `Form`/object access. | Constructor assigns a real 4×4 transparent PNG (`Resources/Lab/placeholder.png`) to both preview properties. |
| 4 | `READ PICTURE FILE` returns an empty picture with no error | The virtual path `/RESOURCES/…` was passed. 4D wants a real filesystem path. | `File(...).platformPath`. Note `.path` (POSIX) is not equivalent on macOS for legacy calls. |
| 5 | Preview always empty after a *successful* conversion | The source picture and the output picture are separate properties; only the conversion path assigned the output. Covering the initial state needed a genuine picture, see #3. | `_readPicture()` is used for both, and returns an empty picture for `""` rather than `Null`. |

## Tooling findings

* **The Dependency Manager is an IDE feature only.** `tool4d` prints
  `PackageManager No component to fetch dependencies` and
  `Dependency 'CMYK' cannot be found` on every launch even when
  `Components/CMYK.4dbase` is present and `cs.CMYK.Converter` calls succeed. The
  messages are *not* a failure signal. The real failure signal is the class not
  resolving at runtime.
* **`Compile project` cannot resolve a source component class.**
  `tools/4dlsp/tool4d-lsp-stdio validate` reports exactly one diagnostic on the
  class, `The class cs.CMYK is unknown`, because the language server only knows
  *compiled* components. The `4dlsp` skill says to expect this and prove loading
  at runtime; do that (the acceptance report does). A compiled-host check was
  therefore `not_run` here — the acceptance evidence is an interpreted run.
* **`FORM LOAD` works headlessly and instantiates `formClass`.** This gives a
  cheap binding smoke test: after `FORM LOAD("Lab")`, `Form.componentVersion` and
  `Form.scenarioRows` are live. Do this before ever opening a window.
* **`Get database parameter(User param value; $text)` returns 0 on success**, and
  fills `$text`. Treating a nonzero return as "no parameter" and ignoring `$text`
  is the correct shape.
* **`--skip-onstartup` is required once `On Startup` exists.** tool4d runs the
  `On Startup` database method *before* `--startup-method` unless told otherwise.
  An `On Startup` that opens a window will therefore break every headless run
  (and hang if a window can be created).
* **`Picture size` returns bytes, not dimensions.** Use `PICTURE PROPERTIES` when
  width/height matter; `Picture size` is still the cheapest "did 4D decode it"
  probe for a report.
* **`File.extension` includes the leading dot** (`.tif`). Concatenating `"."+extension`
  produced `chart-srgb-cmyk-2..tif`.

## Form JSON findings (boon-validated)

* `"css"` is the form-level key for style sheets; `"styleSheets"` is invented and
  silently ignored. The project-wide `Project/Sources/styleSheets.css` is loaded
  automatically and needs no form reference.
* A rectangle object's type string is `"rectangle"`, not `"rect"`.
* Listbox `headerHeight` must be a string with a unit (`"22px"`); a number is
  rejected by the schema.
* Boolean operators in 4D do **not** short-circuit. Type guards must be separate
  `If` statements, not `(Value type(x)=Is object) && x.y`.
* A wrong `dataSource` does not fail `FORM LOAD`; it fails when the widget is
  drawn. `scripts/check_bindings.py` catches that statically because there is no
  other cheap way to see it headlessly.

## Component behaviour worth knowing (verified by the matrix)

* Untagged RGB without `allowAssumeSRGB` fails with `missing_source_profile`;
  with the opt-in it succeeds and reports `sourceProfile.origin = "assumed-srgb"`.
  A supplied `sourceProfile` wins over both and reports `"supplied"`.
* Alpha channels are refused (`unsupported_image`), not flattened.
* A destination path that already exists is never overwritten
  (`destination_exists`), including the source file itself.
* `quality` outside 1…100 is rejected in 4D (`invalid_argument`) before the CLI
  is launched, while a missing destination profile surfaces as
  `read_failed` carrying the OS error.
* A CMYK TIFF input is re-separated through its embedded profile and succeeds.
* `inspectFile` on the produced CMYK TIFF reports four channels and an embedded
  CMYK profile — that is the strongest "the file really is CMYK" evidence here.

## Limits of this demo (stated honestly)

* The right-hand preview decodes the CMYK TIFF with a generic path; it is a
  visual approximation and not colorimetric proof. The UI says so.
* The 0.1.2 component ships `lib4d-arm64.dylib` only. Intel macOS and Windows 4D
  loading are untested here; the Windows CLI binary in the component is not
  exercised by this demo.
* Full `Compile project` was not run, because the dependency is a source
  component (see above). Everything reported as passing is an interpreted
  `tool4d` run of the exact staged 0.1.2 archive.
* `Documentation/*.png` are runtime captures from 4D 21.2 (`DIALOG` +
  `FORM SCREENSHOT`, light and dark colour scheme), so they show the applied
  stylesheet and the state after the first conversion. They are regenerated by
  hand when the layout changes; nothing checks them in CI.
