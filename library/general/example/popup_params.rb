# rubocop:disable all
require "yast"

require "yast2/popup"

Yast.import "UI"

include Yast::UIShortcuts

def code(params)
  "Yast2::Popup.show(#{params})"
end

content = VBox(
  InputField(Id(:params), Opt(:notify), "Popup Params:"),
  VSpacing(1),
  InputField(Id(:code), Opt(:disable), "Code to run:"),
  VSpacing(1),
  PushButton(Id(:call), "Show")
)

Yast::UI.OpenDialog(content)
loop do
  ret = Yast::UI.UserInput
  case ret
  when :params
    value = Yast::UI.QueryWidget(:params, :Value)
    Yast::UI.ChangeWidget(:code, :Value, code(value))
  when :cancel
    break
  when :call
    begin
      value = Yast::UI.QueryWidget(:params, :Value)
      eval(code(value))
    rescue => e
      Yast2::Popup.show("Failed with #{e.message}")
    end
  end
end

Yast::UI.CloseDialog
