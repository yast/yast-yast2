require "yast"

args = Yast::WFM.Args

Yast.y2milestone args.inspect
exit 66 if args != ['abc"\'\\|;&<>! ', "second"]
