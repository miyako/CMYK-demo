If (Form.lastResult#Null)
	SET TEXT TO PASTEBOARD(JSON Stringify(Form.lastResult; *))
	Form.status:="Result JSON copied to the pasteboard"
Else
	Form.status:="Nothing to copy yet — run a conversion or an inspection first"
End if
