require "yast"

args = Yast::WFM.Args

args == ['abc"\'\\|;&<>! ', 'second']
