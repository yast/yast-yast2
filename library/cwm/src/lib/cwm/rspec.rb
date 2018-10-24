# in your specs:
#   require "cwm/rspec"

RSpec.shared_examples "CWM::AbstractWidget" do
  context "these methods are only tested if they exist" do
    describe "#label" do
      it "produces a String" do
        next unless subject.respond_to?(:label)

        expect(subject.label).to be_a String
      end
    end

    describe "#help" do
      it "produces a String" do
        next unless subject.respond_to?(:help)

        expect(subject.help).to be_a String
      end
    end

    describe "#opt" do
      it "produces Symbols" do
        next unless subject.respond_to?(:opt)

        expect(subject.opt).to be_an Enumerable
        subject.opt.each do |o|
          expect(o).to be_a Symbol
        end
      end
    end

    describe "#handle" do
      it "produces a Symbol or nil" do
        next unless subject.respond_to?(:handle)

        m = subject.method(:handle)
        args = m.arity == 0 ? [] : [:dummy_event]
        expect(subject.handle(* args)).to be_a(Symbol).or be_nil
      end
    end

    describe "#validate" do
      it "produces a Boolean (or nil)" do
        next unless subject.respond_to?(:validate)

        expect(subject.validate).to be(true).or be(false).or be_nil
      end
    end
  end
end

RSpec.shared_examples "CWM::CustomWidget" do
  include_examples "CWM::AbstractWidget"
  describe "#contents" do
    it "produces a Term" do
      expect(subject.contents).to be_a Yast::Term
    end
  end
end

RSpec.shared_examples "CWM::Pager" do
  include_examples "CWM::CustomWidget"
  describe "#current_page" do
    it "produces a Page or nil" do
      expect(subject.current_page).to be_a(CWM::Page).or be_nil
    end
  end
end

RSpec.shared_examples "CWM::Page" do
  include_examples "CWM::CustomWidget"
end

# Tab is an alias for Page
RSpec.shared_examples "CWM::Tab" do
  include_examples "CWM::Page"
end

RSpec.shared_examples "CWM::ItemsSelection" do
  describe "#items" do
    it "produces an array of pairs of strings" do
      expect(subject.items).to be_an Enumerable
      subject.items.each do |i|
        expect(i[0]).to be_a String
        expect(i[1]).to be_a String
      end
    end
  end
end

RSpec.shared_examples "CWM::ComboBox" do
  include_examples "CWM::AbstractWidget"
  include_examples "CWM::ItemsSelection"
end

RSpec.shared_examples "CWM::PushButton" do
  include_examples "CWM::AbstractWidget"
end

RSpec.shared_examples "CWM spacing" do |method|
  describe "##{method}" do
    it "returns and Integer or a Float number if defined" do
      expect(subject.send(method)).to be_an(Integer).or be_a(Float) if subject.respond_to?(method)
    end

    it "returns a positive number or zero if defined" do
      expect(subject.send(method)).to be >= 0 if subject.respond_to?(method)
    end
  end
end

RSpec.shared_examples "CWM::RadioButtons" do
  include_examples "CWM::AbstractWidget"
  include_examples "CWM::ItemsSelection"

  include_examples "CWM spacing", :hspacing
  include_examples "CWM spacing", :vspacing
end

RSpec.shared_examples "CWM::ValueBasedWidget" do
end

RSpec.shared_examples "CWM::CheckBox" do
  include_examples "CWM::AbstractWidget"
  include_examples "CWM::ValueBasedWidget"
end

RSpec.shared_examples "CWM::RichText" do
  include_examples "CWM::AbstractWidget"
  include_examples "CWM::ValueBasedWidget"
end

RSpec.shared_examples "CWM::Table" do
  include_examples "CWM::AbstractWidget"

  describe "#header" do
    it "produces an array of strings" do
      expect(subject.header).to be_an Enumerable
      subject.header.each do |header|
        expect(header).to be_a String
      end
    end
  end

  describe "#items" do
    it "produces an array of arrays" do
      expect(subject.items).to be_an Enumerable
      subject.items.each do |item|
        expect(item).to be_a Array
      end
    end
  end
end

RSpec.shared_examples "CWM::Dialog" do
  describe "#contents" do
    it "produces a Term" do
      expect(subject.contents).to be_a Yast::Term
    end
  end

  describe "#title" do
    it "produces a String or nil" do
      expect(subject.title).to be_a(String).or be_nil
    end
  end

  describe "#back_button" do
    it "produces a String or nil" do
      expect(subject.back_button).to be_a(String).or be_nil
    end
  end

  describe "#abort_button" do
    it "produces a String or nil" do
      expect(subject.abort_button).to be_a(String).or be_nil
    end
  end

  describe "#next_button" do
    it "produces a String or nil" do
      expect(subject.next_button).to be_a(String).or be_nil
    end
  end

  describe "#skip_store_for" do
    it "produces an Array" do
      expect(subject.skip_store_for).to be_an Array
    end
  end
end
