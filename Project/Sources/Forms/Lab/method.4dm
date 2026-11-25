// Form method for "Lab".
// The form class (formClass CMYKLab) has already built the state by the
// time this method runs; On Load only kicks off the first conversion so the
// output preview is not empty.
var $event : Object

$event:=Form event

Case of
	: ($event.code=On Load)
		SET WINDOW TITLE("CMYK Lab — miyako/CMYK demo")
		If (Form.lastResult=Null)
			Form.convertCurrent()
		End if
End case
