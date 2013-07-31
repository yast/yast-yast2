# encoding: utf-8

# ***************************************************************************
#
# Copyright (c) 2002 - 2012 Novell, Inc.
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail,
# you may find current contact information at www.novell.com
#
# ***************************************************************************
module Yast
  module WizardInclude
    def initialize_Wizard(include_target)
      Yast.include include_target, "testsuite.rb"
      Yast.import "Sequencer"
      Sequencer.docheck = false

      TEST(lambda { Sequencer.Run(aliases, sequence) }, [], nil) if @cur != -1
    end

    def ok
      Builtins.y2error("ok")
      :ok
    end
    def back
      Builtins.y2error("back")
      :back
    end
    def next
      Builtins.y2error("next")
      :next
    end
    def finish
      Builtins.y2error("finish")
      :finish
    end
    def details
      Builtins.y2error("details")
      :details
    end
    def expert
      Builtins.y2error("expert")
      :expert
    end

    # define boolean WS_check(map aliases, map sequence) ``{ return true; }

    # integer cur = 0;
    # list clicks = [ `next, `next, `details, `ok, `next ];
    # list clicks = [ `n, `n, `d, `o, `n];
    def click
      ret = nil
      s = Builtins.size(@clicks)
      if Ops.less_than(@cur, s) && Ops.is_symbol?(Ops.get(@clicks, @cur))
        ret = Ops.get_symbol(@clicks, @cur)
      end
      @cur = Ops.add(@cur, 1)
      log = Builtins.sformat("%1", ret)
      if Builtins.substring(log, 0, 1) == "`"
        log = Builtins.substring(log, 1, Builtins.size(log))
      end
      Builtins.y2error("%1", log)
      ret
    end

    # sequence = sequence();
    # cur = lookup(sequnce,"ws_start");
    # define any clickng() ``{
    #     any ret = lookup(sequence,cur,$[]);
    #     list l = mapkeys(ret);
    #     integer i = random(size(l)+1);
    #     if(i<size(l)) {
    # 	cur = lookup(ret,select(l,i,nil),nil);
    # 	/* push cur * /
    # 	ret = select(l,i,nil);
    #     }
    #     else {
    # 	/* pop cur * /
    # 	ret = `back;
    #     }
    #     return ret;
    # }

    # aliases
    def aliases
      {
        "begin"        => lambda { click },
        "config"       => lambda { click },
        "end"          => lambda { click },
        "expert"       => lambda { click },
        "expert2"      => lambda { click },
        "details"      => lambda { click },
        "superdetails" => lambda { click }
      }
    end

    # example5.ycp sequence
    def sequence
      _Sequence5 = {
        "ws_start"     => "begin",
        "begin"        => { :next => "config" },
        "expert"       => { :next => "expert2" },
        "expert2"      => { :next => "end", :ok => "config" },
        "config"       => {
          :next    => "end",
          :details => "details",
          :expert  => "expert"
        },
        "details"      => {
          :next    => "end",
          :details => "superdetails",
          :ok      => "config"
        },
        "superdetails" => { :next => "end", :ok => "details" },
        "end"          => { :finish => :ws_finish }
      }

      deep_copy(_Sequence5)
    end
  end
end
