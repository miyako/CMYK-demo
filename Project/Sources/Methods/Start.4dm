#DECLARE($params : Object)

// GUI entry point, following the 4dstartup pattern. Called without a parameter
// (On Startup, menu) it brings an existing Lab window to the front or hands
// over to worker 1; called with a parameter (from CALL WORKER) it opens the
// window and hosts the "Lab" form non-blocking with DIALOG(...; *).
// The form class (CMYKLab) builds all state; the work happens in class
// functions called by the object methods.

var $title : Text
var $window; $i; $left; $top; $right; $bottom : Integer
var $lab : cs.CMYKLab

$title:="CMYK Lab — miyako/CMYK demo"

If (Count parameters=0)
	
	// already open? bring it to the front instead of opening a duplicate
	ARRAY LONGINT($windows; 0)
	WINDOW LIST($windows)
	For ($i; 1; Size of array($windows))
		$window:=$windows{$i}
		If (Window process($window)=1) && (Get window title($window)=$title)
			GET WINDOW RECT($left; $top; $right; $bottom; $window)
			CALL FORM($window; Formula(SET WINDOW RECT($left; $top; $right; $bottom; $window)))
			return 
		End if 
	End for 
	
	CALL WORKER(1; Current method name; {})
	
Else 
	
	SET MENU BAR(1)
	$lab:=cs.CMYKLab.new()
	$window:=Open form window("Lab"; Plain form window; Horizontally centered; Vertically centered)
	SET WINDOW TITLE($title; $window)
	DIALOG("Lab"; $lab; *)
	
End if 
