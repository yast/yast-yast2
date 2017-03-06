require "yast"

args = Yast::WFM.Args

puts args
exit 66 if args != ['abc"\'\\|;&<>! ', "second"]
