require_relative "../test_helper"
require "installation/installation_data"

describe Installation::InstallationData do
  describe "#add" do
    before do
      expect(Yast::Mode).to receive(:update).and_return(false)
    end

    it "adds the default product callback" do
      expect(::Installation::InstallationInfo.instance)
        .to receive(:added?).with("installation").and_return(false)

      expect(::Installation::InstallationInfo.instance)
        .to receive(:add).with("installation")

      ::Installation::InstallationData.add
    end

    it "does not add the callback if it is already defined" do
      expect(::Installation::InstallationInfo.instance)
        .to receive(:added?).with("installation").and_return(true)

      expect(::Installation::InstallationInfo.instance)
        .to_not receive(:add)

      ::Installation::InstallationData.add
    end
  end
end
