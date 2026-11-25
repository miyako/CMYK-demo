#DECLARE($params : Object)

// Headless acceptance run. Executes the whole scenario matrix without opening
// any window, writes a JSON report and exits with the number of failures.
//
//   tool4d --project CMYK-demo.4DProject --dataless \
//          --startup-method Acceptance --user-param "/tmp/report.json"

var $lab : cs.CMYKLab
var $report; $row : Object
var $passed; $failed : Integer
var $path; $userParam : Text
var $scenarios : Collection
var $summary : Text

$userParam:=""
If (Get database parameter(User param value; $userParam)#0)
	$userParam:=""
End if
$path:="/tmp/cmyk-demo-acceptance.json"
If ($userParam#"")
	$path:=$userParam
End if

$lab:=cs.CMYKLab.new()
$lab.runAll()

$passed:=0
$failed:=0
For each ($row; $lab.scenarioRows)
	If ($row.actual=$row.expect)
		$passed+=1
	Else
		$failed+=1
	End if
End for each

$scenarios:=$lab.scenarioRows
$summary:=$lab.scenarioSummary

// Second pass: the exact interactive path (what the Convert button calls),
// including decoding the produced CMYK TIFF back into a 4D Picture preview.
$lab:=cs.CMYKLab.new()
$lab.convertCurrent()
$report:=New object("component"; $lab.componentVersion)
$report.platformTarget:=$lab.platformTarget
$report.source:=$lab.sourcePath
$report.scenarioSummary:=$summary
$report.passed:=$passed
$report.failed:=$failed
$report.scenarios:=$scenarios
$report.sourcePictureBytes:=Picture size($lab.sourcePicture)
$report.outputPictureBytes:=Picture size($lab.outputPicture)
$report.previewLoaded:=(Picture size($lab.sourcePicture)>0)
$report.interactiveStatus:=$lab.status
$report.interactiveOutput:=$lab.outputPath
$report.interactivePictureBytes:=Picture size($lab.outputPicture)
$report.firstError:=Null
If ($failed>0)
	For each ($row; $lab.scenarioRows)
		If ($row.actual#$row.expect)
			$report.firstError:=New object("name"; $row.name; "expected"; $row.expect; "actual"; $row.actual)
			break
		End if
	End for each
End if

File($path).setText(JSON Stringify($report; *))

If ($report.interactivePictureBytes<=0)
	$failed+=1
End if
If ($failed=0)
	LOG EVENT(Into system standard outputs; "ACCEPTANCE PASS "+String($passed)+" of "+String($lab.scenarioRows.length)+" -> "+$path)
Else
	LOG EVENT(Into system standard outputs; "ACCEPTANCE FAIL "+String($failed)+" of "+String($lab.scenarioRows.length)+" -> "+$path)
End if

QUIT 4D($failed)
