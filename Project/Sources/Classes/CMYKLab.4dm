property sourcePath : Text
property profilePath : Text
property sourceProfilePath : Text
property outputPath : Text

property intent : Text
property format : Text
property quality : Integer
property blackPointCompensation : Boolean
property allowAssumeSRGB : Boolean

property componentVersion : Text
property platformTarget : Text
property assetFolderPath : Text
property outputFolderPath : Text

property sourceInfo : Text
property profileInfo : Text
property outputInfo : Text
property status : Text
property elapsedText : Text
property warningsText : Text

property sourcePicture : Picture
property outputPicture : Picture

property resultRows : Collection
property scenarioRows : Collection
property selectedScenario : Object
property lastResult : Object
property scenarioSummary : Text

property _scenarios : Collection

Class constructor
	This.sourcePath:=""
	This.profilePath:=""
	This.sourceProfilePath:=""
	This.outputPath:=""
	This.intent:="relativeColorimetric"
	This.format:="tiff"
	This.quality:=90
	This.blackPointCompensation:=True
	This.allowAssumeSRGB:=False
	This.componentVersion:=""
	This.platformTarget:=""
	This.status:="Ready"
	This.elapsedText:=""
	This.warningsText:=""
	This.outputInfo:=""
	This.sourceInfo:=""
	This.profileInfo:=""
	This.scenarioSummary:=""
	This.resultRows:=New collection()
	This.scenarioRows:=New collection()
	This.selectedScenario:=Null
	This._scenarios:=New collection()

	This._resolvePaths()
	This.sourcePicture:=This._readPicture(This._asset("placeholder.png"))
	This.outputPicture:=This.sourcePicture
	This._loadScenarios()
	This.refreshVersion()
	This.useBundledProfile()
	This.selectSource(This._asset("chart-srgb.png"))
	This.prepareScenarios()

// --- environment -----------------------------------------------------------

Function _resolvePaths
	var $out : 4D.Folder
	This.assetFolderPath:=Folder("/RESOURCES").folder("Lab").path
	$out:=Folder(fk database folder).folder("LabOutput")
	If (Not($out.exists))
		$out.create()
	End if
	This.outputFolderPath:=$out.path
	If (Is macOS)
		This.platformTarget:="macOS-universal"
	Else
		If (Is Windows)
			This.platformTarget:="Windows-x64"
		Else
			This.platformTarget:="unsupported"
		End if
	End if

Function _assetFolder()->$folder : 4D.Folder
	$folder:=Folder(This.assetFolderPath)

Function _profileFolder()->$folder : 4D.Folder
	$folder:=Folder(This.assetFolderPath).folder("profiles")

Function _asset($name : Text)->$path : Text
	$path:=This._assetFolder().file($name).path

Function _profileAsset($name : Text)->$path : Text
	$path:=This._profileFolder().file($name).path

Function _outputFolder()->$folder : 4D.Folder
	$folder:=Folder(This.outputFolderPath)

Function refreshVersion
	var $result : Object
	$result:=This.converter().version()
	If ($result.ok)
		This.componentVersion:="miyako/CMYK "+String($result.value.version)+" · protocol "+String($result.value.protocol)
	Else
		This.componentVersion:="miyako/CMYK unavailable"
	End if

Function converter()->$converter : Object
	$converter:=cs.CMYK.Converter.new(This.platformTarget)

// --- source / profile selection -------------------------------------------

Function selectSource($path : Text)
	If (Value type($path)#Is text)
		return
	End if
	If ($path="")
		return
	End if
	This.sourcePath:=$path
	This.inspectSource()

Function selectProfile($path : Text)
	If (Value type($path)#Is text)
		return
	End if
	If ($path="")
		return
	End if
	This.profilePath:=$path
	This.describeProfile()

Function useBundledProfile
	This.selectProfile(This._profileAsset("destination.icc"))

Function chooseSource
	var $path; $chosen : Text
	ARRAY TEXT($selected; 0)
	$path:=Select document(This._assetFolder().platformPath; ".png,.jpg,.jpeg,.tif,.tiff"; "Choose a source image"; 0; $selected)
	If ($path="")
		return
	End if
	$chosen:=$path
	If (Size of array($selected)>0)
		$chosen:=$selected{1}
	End if
	This.selectSource(File($chosen; fk platform path).path)
	This.status:="Source selected: "+This._name(This.sourcePath)

Function chooseProfile
	var $path; $chosen : Text
	ARRAY TEXT($selected; 0)
	$path:=Select document(This._profileFolder().platformPath; ".icc,.icm"; "Choose a destination ICC profile"; 0; $selected)
	If ($path="")
		return
	End if
	$chosen:=$path
	If (Size of array($selected)>0)
		$chosen:=$selected{1}
	End if
	This.selectProfile(File($chosen; fk platform path).path)
	This.status:="Destination profile selected: "+This._name(This.profilePath)

Function chooseSourceProfile
	var $path; $chosen : Text
	ARRAY TEXT($selected; 0)
	$path:=Select document(This._profileFolder().platformPath; ".icc,.icm"; "Choose a source ICC profile"; 0; $selected)
	If ($path="")
		return
	End if
	$chosen:=$path
	If (Size of array($selected)>0)
		$chosen:=$selected{1}
	End if
	This.sourceProfilePath:=File($chosen; fk platform path).path
	This.status:="Source profile selected: "+This._name(This.sourceProfilePath)

Function clearSourceProfile
	This.sourceProfilePath:=""
	This.status:="Source profile cleared; untagged inputs will ask for one (or opt in to sRGB)"

// --- inspection ------------------------------------------------------------

Function inspectSource
	var $file : 4D.File
	var $result : Object
	$file:=File(This.sourcePath)
	If (Not($file.exists))
		This.sourceInfo:="File not found: "+This.sourcePath
		This.sourcePicture:=This._readPicture("")
		This.status:="Source file not found"
		return
	End if
	$result:=This.converter().inspectFile($file)
	If ($result.ok)
		This.sourceInfo:=This._describeInspection($result.value)
		This.sourcePicture:=This._readPicture($file.path)
		This._fillResult($result)
		This.status:="Inspected "+This._name(This.sourcePath)
	Else
		This.sourceInfo:="Inspection failed: "+This._errorText($result)
		This.sourcePicture:=This._readPicture("")
		This._fillResult($result)
		This.status:="Inspection failed"
	End if

Function describeProfile
	var $file : 4D.File
	$file:=File(This.profilePath)
	If (Not($file.exists))
		This.profileInfo:="Profile not found: "+This.profilePath
		return
	End if
	This.profileInfo:=This._name(This.profilePath)+" · "+String($file.size)+" bytes · contents are validated by the CLI on each run"

// --- conversion ------------------------------------------------------------

Function convertCurrent
	var $source; $destination; $profile : 4D.File
	var $options; $result : Object
	var $start : Integer
	var $base; $target : Text

	$source:=File(This.sourcePath)
	If (Not($source.exists))
		This.status:="Choose an existing source image first"
		return
	End if
	$profile:=File(This.profilePath)
	If (Not($profile.exists))
		This.status:="Choose an existing destination ICC profile first"
		return
	End if

	$base:=This._baseName(This.sourcePath)
	$target:=This._uniqueOutput($base+"-cmyk."+This._extensionFor(This.format))
	$destination:=File($target)
	This.outputPath:=$destination.path
	This.warningsText:=""
	This.elapsedText:=""

	$options:=New object("destinationProfile"; $profile; "intent"; This.intent; "blackPointCompensation"; This.blackPointCompensation; "allowAssumeSRGB"; This.allowAssumeSRGB; "format"; This.format; "quality"; This.quality)
	If (This.sourceProfilePath#"")
		$options.sourceProfile:=File(This.sourceProfilePath)
	End if

	$start:=Milliseconds
	$result:=This.converter().convertFile($source; $destination; $options)
	This.elapsedText:=String(Milliseconds-$start)+" ms"
	This._fillResult($result)

	If ($result.ok)
		This.outputInfo:=This._describeConversion($result.value)
		This.outputPicture:=This._readPicture($destination.path)
		If (This._warnings($result.value)="")
			This.warningsText:="No warnings reported."
		Else
			This.warningsText:=This._warnings($result.value)
		End if
		This.status:="Converted to "+This._name($destination.path)+" in "+This.elapsedText
	Else
		This.outputInfo:="Conversion failed: "+This._errorText($result)
		This.outputPicture:=This._readPicture("")
		This.warningsText:="No output was written. The source file was not modified."
		This.status:="Conversion failed: "+This._errorText($result)
	End if

Function _extensionFor($format : Text)->$extension : Text
	$extension:="tif"
	If ($format="jpeg")
		$extension:="jpg"
	End if

// --- scenarios -------------------------------------------------------------

Function _loadScenarios
	This._scenarios:=New collection()

	This._scenarios.push(New object("name"; "Tagged RGB PNG → CMYK TIFF"; "kind"; "convert"; "source"; "chart-srgb.png"; "profile"; "destination.icc"; "options"; New object(); "expect"; "ok"; "note"; "Embedded sRGB profile is used; output is tagged CMYK."))
	This._scenarios.push(New object("name"; "Tagged RGB JPEG → CMYK JPEG"; "kind"; "convert"; "source"; "chart-srgb.jpg"; "profile"; "destination.icc"; "options"; New object("format"; "jpeg"; "quality"; 85); "expect"; "ok"; "note"; "JPEG input at 144 DPI; JPEG output honours quality."))
	This._scenarios.push(New object("name"; "Untagged PNG, no opt-in"; "kind"; "convert"; "source"; "untagged.png"; "profile"; "destination.icc"; "options"; New object(); "expect"; "missing_source_profile"; "note"; "The component refuses to guess a source profile."))
	This._scenarios.push(New object("name"; "Untagged PNG + assume sRGB"; "kind"; "convert"; "source"; "untagged.png"; "profile"; "destination.icc"; "options"; New object("allowAssumeSRGB"; True); "expect"; "ok"; "note"; "Explicit opt-in returns sourceProfile.origin = assumed-srgb."))
	This._scenarios.push(New object("name"; "Untagged PNG + supplied ICC"; "kind"; "convert"; "source"; "untagged.png"; "profile"; "destination.icc"; "sourceProfile"; "srgb.icc"; "options"; New object(); "expect"; "ok"; "note"; "A supplied source profile wins over any assumption."))
	This._scenarios.push(New object("name"; "Alpha PNG is rejected"; "kind"; "convert"; "source"; "alpha.png"; "profile"; "destination.icc"; "options"; New object(); "expect"; "unsupported_image"; "note"; "Alpha is refused rather than silently flattened."))
	This._scenarios.push(New object("name"; "Existing destination is kept"; "kind"; "convert"; "source"; "chart-srgb.png"; "profile"; "destination.icc"; "options"; New object(); "expect"; "destination_exists"; "preCreate"; True; "note"; "Outputs are never overwritten, including the source file itself."))
	This._scenarios.push(New object("name"; "Quality 101 is invalid"; "kind"; "convert"; "source"; "chart-srgb.png"; "profile"; "destination.icc"; "options"; New object("quality"; 101); "expect"; "invalid_argument"; "note"; "Options are validated in 4D before the CLI is launched."))
	This._scenarios.push(New object("name"; "Missing destination profile"; "kind"; "convert"; "source"; "chart-srgb.png"; "profile"; "missing.icc"; "options"; New object(); "expect"; "read_failed"; "note"; "The OS error is preserved in the CLI error message."))
	This._scenarios.push(New object("name"; "CMYK TIFF → CMYK TIFF"; "kind"; "convert"; "source"; "cmyk-chart.tif"; "profile"; "destination.icc"; "options"; New object(); "expect"; "ok"; "note"; "CMYK input is re-separated through its embedded source profile."))
	This._scenarios.push(New object("name"; "Inspect the CMYK output"; "kind"; "inspect"; "source"; "cmyk-chart.tif"; "expect"; "ok"; "note"; "Inspect reports four channels and an embedded CMYK profile."))

Function prepareScenarios
	var $row; $scenario : Object
	This.scenarioRows:=New collection()
	For each ($scenario; This._scenarios)
		$row:=New object("name"; $scenario.name; "expect"; $scenario.expect; "actual"; "—"; "ms"; "")
		This.scenarioRows.push($row)
	End for each
	This.scenarioSummary:="Not run yet · "+String(This._scenarios.length)+" cases"

Function runSelected
	If (This.selectedScenario=Null)
		This.runAll()
		return
	End if
	This.runScenario(This._indexOfRow(This.selectedScenario))
	This.status:=This.scenarioSummary

Function runAll
	var $passed; $failed; $index : Integer
	$passed:=0
	$failed:=0
	For ($index; 0; This._scenarios.length-1)
		If (This.runScenario($index))
			$passed+=1
		Else
			$failed+=1
		End if
	End for
	This.scenarioSummary:=String($passed)+" passed · "+String($failed)+" failed · of "+String(This._scenarios.length)
	This.status:=This.scenarioSummary

Function resetScenarios
	This.prepareScenarios()
	This.status:="Scenario table reset — press “Run all scenarios” to execute the matrix"

Function runScenario($index : Integer)->$passed : Boolean
	var $scenario; $options; $result; $row : Object
	var $source; $destination; $profile; $sourceProfile : 4D.File
	var $actual; $extension : Text
	var $start : Integer
	var $key : Text

	$passed:=False
	If (($index<0) | ($index>=This._scenarios.length))
		return
	End if
	$scenario:=This._scenarios[$index]
	$extension:="tif"
	If ($scenario.kind="convert")
		If (Value type($scenario.options.format)=Is text)
			If ($scenario.options.format="jpeg")
				$extension:="jpg"
			End if
		End if
	End if
	$source:=This._assetFolder().file($scenario.source)
	$destination:=This._outputFolder().file("scenario-"+This._pad($index+1)+"."+$extension)
	If ($destination.exists)
		$destination.delete()
	End if
	If ($scenario.preCreate=True)
		$destination.setText("occupied before conversion")
	End if

	$start:=Milliseconds
	If ($scenario.kind="inspect")
		$result:=This.converter().inspectFile($source)
	Else
		$profile:=This._profileFolder().file($scenario.profile)
		$options:=New object("destinationProfile"; $profile; "intent"; This.intent; "blackPointCompensation"; True; "allowAssumeSRGB"; False; "format"; "tiff"; "quality"; This.quality)
		If (Value type($scenario.options)=Is object)
			For each ($key; $scenario.options)
				$options[$key]:=$scenario.options[$key]
			End for each
		End if
		If (Value type($scenario.sourceProfile)=Is text)
			$sourceProfile:=This._profileFolder().file($scenario.sourceProfile)
			$options.sourceProfile:=$sourceProfile
		End if
		$result:=This.converter().convertFile($source; $destination; $options)
	End if

	$actual:=This._outcome($result)
	$passed:=($actual=$scenario.expect)
	$row:=This.scenarioRows[$index]
	$row.actual:=$actual
	$row.ms:=String(Milliseconds-$start)
	$row.name:=$scenario.name
	This._replaceRow($index; $row)
	This.selectedScenario:=Null
	return $passed

// --- presentation helpers --------------------------------------------------

Function _fillResult($result : Object)
	var $value : Object
	This.resultRows:=New collection()
	This.lastResult:=$result
	If ($result.ok)
		This._addRow("ok"; "true")
		$value:=$result.value
		If (Value type($value)#Is object)
			return
		End if
		Case of
			: (Value type($value.width)=Is real)
				// Inspection results carry bitDepth/orientation/dpi; conversion
				// results do not, so only list what the component returned.
				This._addRow("size"; String($value.width)+" × "+String($value.height))
				This._addRow("channels"; String($value.channels))
				This._addRow("colorSpace"; String($value.colorSpace))
				If (Value type($value.bitDepth)=Is real)
					This._addRow("bitDepth"; String($value.bitDepth))
				End if
				This._addRow("format"; String($value.format))
				If (Value type($value.orientation)=Is real)
					This._addRow("orientation"; String($value.orientation))
				End if
				If ((Value type($value.dpiX)=Is real) && (Value type($value.dpiY)=Is real))
					This._addRow("dpi"; String($value.dpiX)+" × "+String($value.dpiY))
				End if
				If (Value type($value.sourceProfile)=Is object)
					This._addRow("sourceProfile"; String($value.sourceProfile.origin)+" · "+String($value.sourceProfile.description))
				End if
				If (Value type($value.destinationProfile)=Is object)
					This._addRow("destinationProfile"; String($value.destinationProfile.description))
				End if
			Else
				This._addRow("version"; String($value.version))
				This._addRow("protocol"; String($value.protocol))
		End case
		If (This._warnings($value)#"")
			This._addRow("warnings"; Replace string(This._warnings($value); "\n"; " · "))
		End if
	Else
		This._addRow("ok"; "false")
		This._addRow("error.code"; String($result.error.code))
		This._addRow("error.message"; This._errorText($result))
		If (Value type($result.exitCode)=Is real)
			This._addRow("exitCode"; String($result.exitCode))
		End if
	End if
	This._addRow("elapsed"; This.elapsedText)

Function _addRow($name : Text; $value : Text)
	This.resultRows.push(New object("name"; $name; "value"; $value))

Function _replaceRow($index : Integer; $row : Object)
	var $rows : Collection
	$rows:=This.scenarioRows.copy()
	$rows[$index]:=$row
	This.scenarioRows:=$rows

Function _indexOfRow($row : Object)->$index : Integer
	var $i : Integer
	$index:=-1
	For ($i; 0; This.scenarioRows.length-1)
		If (This.scenarioRows[$i]=$row)
			$index:=$i
		End if
	End for
	return $index

Function _describeInspection($value : Object)->$text : Text
	$text:=String($value.width)+" × "+String($value.height)+" px · "+String($value.channels)+" channels · "+String($value.colorSpace)+" · "+String($value.bitDepth)+" bit · "+String($value.format)
	If ($value.alpha)
		$text:=$text+" · alpha"
	End if
	If ($value.embeddedProfile.present)
		$text:=$text+" · tagged "+String($value.embeddedProfile.description)+" ("+String($value.embeddedProfile.bytes)+" bytes)"
	Else
		$text:=$text+" · no embedded profile"
	End if
	return $text

Function _describeConversion($value : Object)->$text : Text
	$text:="CMYK "+String($value.width)+" × "+String($value.height)+" · "+String($value.format)+" · source "+String($value.sourceProfile.origin)
	return $text

Function _warnings($value : Object)->$text : Text
	var $lines : Collection
	var $warning : Variant
	$text:=""
	If (Value type($value.warnings)#Is collection)
		return ""
	End if
	$lines:=New collection()
	For each ($warning; $value.warnings)
		If (Value type($warning)=Is text)
			$lines.push($warning)
		End if
	End for each
	$text:=$lines.join("\n")
	return $text

Function _outcome($result : Object)->$text : Text
	var $parsed : Variant
	$text:="ok"
	If ($result.ok)
		return $text
	End if
	$text:=String($result.error.code)
	If ($result.error.code="cli_error")
		$parsed:=Null
		Try
			$parsed:=JSON Parse($result.stderr)
		Catch
			$parsed:=Null
		End try
		If (Value type($parsed)=Is object)
			If (Value type($parsed.error)=Is object)
				$text:=String($parsed.error.code)
			End if
		End if
	End if
	return $text

Function _errorText($result : Object)->$text : Text
	var $parsed : Variant
	$text:=""
	If ($result.ok)
		return $text
	End if
	If (Value type($result.error)#Is object)
		return "unexpected result"
	End if
	$text:=String($result.error.code)+": "+String($result.error.message)
	If ($result.error.code="cli_error")
		$parsed:=Null
		Try
			$parsed:=JSON Parse($result.stderr)
		Catch
			$parsed:=Null
		End try
		If (Value type($parsed)=Is object)
			If (Value type($parsed.error)=Is object)
				$text:=String($parsed.error.code)+": "+String($parsed.error.message)
			End if
		End if
	End if
	return $text

// --- files -----------------------------------------------------------------

Function _readPicture($posixPath : Text)->$picture : Picture
	var $pic : Picture
	var $file : 4D.File
	If ($posixPath#"")
		$file:=File($posixPath)
		If ($file.exists)
			READ PICTURE FILE($file.platformPath; $pic)
		End if
	End if
	$picture:=$pic

Function _uniqueOutput($fileName : Text)->$path : Text
	var $counter : Integer
	var $folder : 4D.Folder
	var $base; $ext; $candidate : Text

	$folder:=This._outputFolder()
	$path:=$folder.file($fileName).path
	$base:=This._baseName($path)
	$ext:=This._extension($path)
	$counter:=1
	While (File($path).exists)
		$counter+=1
		$candidate:=$base+"-"+String($counter)+"."+$ext
		$path:=$folder.file($candidate).path
	End while
	return $path

Function _baseName($path : Text)->$name : Text
	var $file : 4D.File
	$file:=File($path)
	return $file.name

Function _extension($path : Text)->$extension : Text
	var $file : 4D.File
	$file:=File($path)
	$extension:=$file.extension
	If (Substring($extension; 1; 1)=".")
		$extension:=Substring($extension; 2)
	End if

Function _name($path : Text)->$name : Text
	var $file : 4D.File
	$file:=File($path)
	return $file.fullName

Function _pad($value : Integer)->$text : Text
	$text:=String($value)
	If (Length($text)<2)
		$text:="0"+$text
	End if
	return $text
