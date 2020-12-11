require "yast"

require "yast2/popup"

Yast2::Popup.show("Simple text")

Yast2::Popup.show("First paragraph.\n\n" + "Long text without newlines. " * 50)

Yast2::Popup.show("First paragraph.", details: "Long text without newlines. " * 50)

Yast2::Popup.show("Long text\n" * 50)

Yast2::Popup.show("Simple text with details", details: "More details here")

Yast2::Popup.show("Simple text with timeout", timeout: 10)

Yast2::Popup.show("Continue/Cancel buttons", buttons: :continue_cancel)

Yast2::Popup.show("Yes/No buttons", buttons: :yes_no)

Yast2::Popup.show("Yes/No buttons with No focused", buttons: :yes_no, focus: :no)

Yast2::Popup.show("Yes/No buttons with timeout returning focused item", buttons: :yes_no, focus: :no, timeout: 10)

Yast2::Popup.show("Own buttons", buttons: { button1: "button 1", button2: "button 2" }, focus: :button2)

Yast2::Popup.show("Richtext is set to <b>false</b>", richtext: false)

Yast2::Popup.show("Long text. Richtext is set to <b>false</b>\n" * 50, richtext: false)

Yast2::Popup.show("Richtext is set to <b>true</b>", richtext: true)

Yast2::Popup.show("Long text. Richtext is set to <b>true</b><br>" * 50, richtext: true)

Yast2::Popup.show("Long text with newlines. Richtext is set to <b>true</b>\n" * 50, richtext: true)

Yast2::Popup.show(":notice style", style: :notice)

Yast2::Popup.show(":important style", style: :important)

Yast2::Popup.show(":warning style", style: :warning)

Yast2::Popup.show("Headline set", headline: "Headline")

Yast2::Popup.show("Headline set to :error", headline: :error)

Yast2::Popup.show(
  "All options",
  headline: "Headline",
  details:  "details",
  timeout:  10,
  buttons:  :yes_no,
  focus:    :no,
  richtext: false,
  style:    :important
)
