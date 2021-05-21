require_relative "../test_helper"
require "installation/installation_data"

describe Installation::InstallationData do
  describe "#register_callback" do
    it "adds the default product callback" do
      expect(::Installation::InstallationInfo.instance)
        .to receive(:callback?).with("installation").and_return(false)

      expect(::Installation::InstallationInfo.instance)
        .to receive(:add_callback).with("installation")

      subject.register_callback
    end

    it "does not add the callback if it is already defined" do
      expect(::Installation::InstallationInfo.instance)
        .to receive(:callback?).with("installation").and_return(true)

      expect(::Installation::InstallationInfo.instance)
        .to_not receive(:add_callback)

      subject.register_callback
    end
  end
end
