#!/usr/bin/env rspec

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

  TOTAL_PROGRESS_ID = Yast::SlideShowClass::UI_ID::TOTAL_PROGRESS

  describe "#UpdateGlobalProgress" do
    before(:each) do
      allow(Yast::SlideShow).to receive(:ShowingSlide).and_return(false)

      # reseting total progress before each test
      Yast::SlideShow.UpdateGlobalProgress(0, "")
    end

    describe "when total progress widget is missing" do
      it "does not update the total progress" do
        expect(Yast::UI).to receive(:WidgetExists).with(TOTAL_PROGRESS_ID).and_return(false)
        expect(Yast::UI).not_to receive(:ChangeWidget).with(TOTAL_PROGRESS_ID, anything(), anything())

        Yast::SlideShow.UpdateGlobalProgress(1, "new label -1")
      end
    end

    describe "when total progress widget exists" do
      before(:each) do
        allow(Yast::UI).to receive(:WidgetExists).and_return(false)
        expect(Yast::UI).to receive(:WidgetExists).with(TOTAL_PROGRESS_ID).and_return(true)
      end

      it "updates the progress value and label" do
        expect(Yast::UI).to receive(:ChangeWidget).with(TOTAL_PROGRESS_ID, :Value, 100)
        expect(Yast::UI).to receive(:ChangeWidget).with(TOTAL_PROGRESS_ID, :Label, "finished")

        Yast::SlideShow.UpdateGlobalProgress(100, "finished")
      end

      it "updates slides if using slides" do
        allow(Yast::SlideShow).to receive(:ShowingSlide).and_return(true)
        expect(Yast::SlideShow).to receive(:ChangeSlideIfNecessary)

        Yast::SlideShow.UpdateGlobalProgress(9, "new label 0")
      end

      it "does not update progress label when setting it to nil" do
        expect(Yast::UI).to receive(:ChangeWidget).with(TOTAL_PROGRESS_ID, :Value, 25)
        expect(Yast::UI).not_to receive(:ChangeWidget).with(TOTAL_PROGRESS_ID, :Label, anything())

        Yast::SlideShow.UpdateGlobalProgress(25, nil)
      end

      it "does not update progress value when setting it to nil" do
        expect(Yast::UI).not_to receive(:ChangeWidget).with(TOTAL_PROGRESS_ID, :Value, anything())
        expect(Yast::UI).to receive(:ChangeWidget).with(TOTAL_PROGRESS_ID, :Label, "new label 1")

        Yast::SlideShow.UpdateGlobalProgress(nil, "new label 1")
      end

      # optimizes doing useless UI changes
      it "does not update progress value or label if setting them to their current value" do
        expect(Yast::UI).to receive(:ChangeWidget).with(TOTAL_PROGRESS_ID, :Value, 31).once
        expect(Yast::UI).to receive(:ChangeWidget).with(TOTAL_PROGRESS_ID, :Label, "new label 5").once

        # updates UI only once
        3.times { Yast::SlideShow.UpdateGlobalProgress(31, "new label 5") }
      end
    end
  end

  PACKAGES_PROGRESS_ID = Yast::SlideShowClass::UI_ID::CURRENT_PACKAGE

  describe "#SubProgress" do
    before(:each) do
      allow(Yast::UI).to receive(:WidgetExists).and_return(false)

      # reseting sub-progress before each test
      Yast::SlideShow.SubProgress(0, "")
    end

    describe "when total progress widget does not exists" do
      it "does not update the total progress" do
        expect(Yast::UI).to receive(:WidgetExists).with(PACKAGES_PROGRESS_ID).and_return(false)
        expect(Yast::UI).not_to receive(:ChangeWidget).with(PACKAGES_PROGRESS_ID, anything(), anything())

        Yast::SlideShow.SubProgress(9, "some label")
      end
    end

    describe "when total progress widget exists" do
      before(:each) do
        expect(Yast::UI).to receive(:WidgetExists).with(PACKAGES_PROGRESS_ID).and_return(true)
      end

      it "updates packages progress value and label" do
        expect(Yast::UI).to receive(:ChangeWidget).with(PACKAGES_PROGRESS_ID, :Value, 100)
        expect(Yast::UI).to receive(:ChangeWidget).with(PACKAGES_PROGRESS_ID, :Label, "finished")

        Yast::SlideShow.SubProgress(100, "finished")
      end

      it "does not update progress label when setting it to nil" do
        expect(Yast::UI).to receive(:ChangeWidget).with(PACKAGES_PROGRESS_ID, :Value, 13)
        expect(Yast::UI).not_to receive(:ChangeWidget).with(PACKAGES_PROGRESS_ID, :Label, anything())

        Yast::SlideShow.SubProgress(13, nil)
      end

      it "does not update progress value when setting it to nil" do
        expect(Yast::UI).not_to receive(:ChangeWidget).with(PACKAGES_PROGRESS_ID, :Value, anything())
        expect(Yast::UI).to receive(:ChangeWidget).with(PACKAGES_PROGRESS_ID, :Label, "package test 1")

        Yast::SlideShow.SubProgress(nil, "package test 1")
      end

      # optimizes doing useless UI changes
      it "does not update progress value or label if setting them to their current value" do
        expect(Yast::UI).to receive(:ChangeWidget).with(PACKAGES_PROGRESS_ID, :Value, 67).once
        expect(Yast::UI).to receive(:ChangeWidget).with(PACKAGES_PROGRESS_ID, :Label, "package test 2").once

        # updates UI only once
        3.times { Yast::SlideShow.SubProgress(67, "package test 2") }
      end
    end
  end

  describe "#Setup" do
    it "the total progress is adjusted to exact 100%" do
      # input data from minimal SLES installation
      stages = [
        {"name"=>"disk", "description"=>"Preparing disks...", "value"=>120, "units"=>:sec},
        {"name"=>"images", "description"=>"Deploying Images...", "value"=>0, "units"=>:kb},
        {"name"=>"packages", "description"=>"Installing Packages...", "value"=>1348246, "units"=>:kb},
        {"name"=>"finish", "description"=>"Finishing Basic Installation", "value"=>100, "units"=>:sec}
      ]

      Yast::SlideShow.Setup(stages)
      total_size = Yast::SlideShow.GetSetup.values.reduce(0){|sum, stage| sum += stage["size"]}
      expect(total_size).to eq(100)
    end
  end

end
