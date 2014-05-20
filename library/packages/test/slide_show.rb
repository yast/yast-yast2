#! /usr/bin/rspec

top_srcdir = File.expand_path("../../../..", __FILE__)
inc_dirs = Dir.glob("#{top_srcdir}/library/*/src")
ENV["Y2DIR"] = inc_dirs.join(":")

require "yast"

Yast.import "SlideShow"
Yast.import "UI"

include Yast::Logger

describe "Yast::SlideShow" do
  before(:each) do
    log.info "--------- Running test ---------"
  end

  describe "#UpdateGlobalProgress" do
    before(:each) do
      Yast::SlideShow.stub(:ShowingSlide).and_return(false)
    end

    describe "when total progress widget exists" do
      before(:each) do
        Yast::UI.stub(:WidgetExists).with(:progressTotal).and_return(true)
      end

      it "updates slides if using slides" do
        Yast::SlideShow.stub(:ShowingSlide).and_return(true)
        expect(Yast::SlideShow).to receive(:ChangeSlideIfNecessary)

        Yast::SlideShow.UpdateGlobalProgress(9, "new label 0")
      end

      # IMPORTANT: Yast::SlideShow keeps 'value' and 'label' cached,
      # always use different value and label for each test so they
      # don't interfere with each other

      it "does not update progress label when setting it to nil" do
        expect(Yast::UI).to receive(:ChangeWidget).with(:progressTotal, :Value, 25)
        expect(Yast::UI).not_to receive(:ChangeWidget).with(:progressTotal, :Label, anything())

        Yast::SlideShow.UpdateGlobalProgress(25, nil)
      end

      it "does not update progress value when setting it to nil" do
        expect(Yast::UI).not_to receive(:ChangeWidget).with(:progressTotal, :Value, anything())
        expect(Yast::UI).to receive(:ChangeWidget).with(:progressTotal, :Label, "new label 1")

        Yast::SlideShow.UpdateGlobalProgress(nil, "new label 1")
      end

      # optimizes doing useless UI changes
      it "does not update progress value or label if setting them to their current value" do
        expect(Yast::UI).to receive(:ChangeWidget).with(:progressTotal, :Value, 31).once
        expect(Yast::UI).to receive(:ChangeWidget).with(:progressTotal, :Label, "new label 5").once

        # updates UI only once
        3.times { Yast::SlideShow.UpdateGlobalProgress(31, "new label 5") }
      end
    end
  end
end
