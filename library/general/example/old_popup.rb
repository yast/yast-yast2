require "yast"

Yast.import "Popup"

ret = Yast::Popup.TimedErrorAnyQuestion("head", "msg", "yes", "no", :focus_no, 10)
Yast::Popup.Message("Returned #{ret.inspect}")
