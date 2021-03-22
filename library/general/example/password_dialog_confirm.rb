# typed: strict
$LOAD_PATH.unshift File.expand_path("../src/lib", __dir__)

require "yast"
require "yast2/popup"
require "ui/password_dialog"

res = UI::PasswordDialog.new("Test", confirm: true).run
Yast2::Popup.show("Dialog returns #{res.inspect}")
