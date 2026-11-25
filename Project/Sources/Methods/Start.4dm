#DECLARE($params : Object)

// GUI entry point. The project's startup method opens a single window hosting
// the "Lab" form. The form class (CMYKLab) builds all state; the actual work
// happens in class functions called by the object methods.

var $lab : cs.CMYKLab
var $window : Integer

SET MENU BAR(1)
$lab:=cs.CMYKLab.new()
$window:=Open form window("Lab"; Plain form window; Horizontally Centered; Vertically Centered)
SET WINDOW TITLE("CMYK Lab — miyako/CMYK demo")
DIALOG("Lab"; $lab)
CLOSE WINDOW($window)
