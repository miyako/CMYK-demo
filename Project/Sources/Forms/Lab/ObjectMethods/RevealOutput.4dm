var $folder : 4D.Folder

$folder:=Folder(Form.outputFolderPath)
If ($folder.exists)
	SHOW ON DISK($folder.platformPath)
	Form.status:="Revealed "+$folder.name
Else
	Form.status:="Output folder is not available"
End if
