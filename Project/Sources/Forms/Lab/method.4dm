// Form method for "Lab".
// The form class (formClass CMYKLab) has already built the state by the
// time this method runs; On Load only kicks off the first conversion so the
// output preview is not empty. The window title is set by Start.
var $event : Object

$event:=Form event

Case of
	: ($event.code=On Load)
		If (Form.outputPath="")
			Form.convertCurrent()
		End if
End case
