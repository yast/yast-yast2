require_relative "test_helper"

Yast.import "XML"

describe "Yast::XML" do
  subject { Yast::XML }

  before do
    subject.xmlCreateDoc("test",
      "cdataSections" => ["cdata1", "cdata2"],
      "systemID"      => "Testing system",
      "rootElement"   => "test",
      "listEntries"   => { "list1" => "list1_element", "list2" => "list2_element" })
  end

  describe "YCPToXMLString" do
    it "return nil for not defined doc_type" do
      expect(subject.YCPToXMLString("not-exist", "test")).to eq nil
    end

    it "returns converted xml for known doc type and passed object" do
      input = { "test" => :abc, "lest" => 15 }
      expected = "<?xml version=\"1.0\"?>\n" \
        "<!DOCTYPE test SYSTEM \"Testing system\">\n" \
        "<test>\n" \
        "  <lest type=\"integer\">15</lest>\n" \
        "  <test type=\"symbol\">abc</test>\n" \
        "</test>\n"

      expect(subject.YCPToXMLString("test", input)).to eq expected
    end

    context "for boolean" do
      it "creates xml element with type=boolean attribute" do
        input = { "test" => true, "lest" => false }
        expected = "<?xml version=\"1.0\"?>\n" \
          "<!DOCTYPE test SYSTEM \"Testing system\">\n" \
          "<test>\n" \
          "  <lest type=\"boolean\">false</lest>\n" \
          "  <test type=\"boolean\">true</test>\n" \
          "</test>\n"

        expect(subject.YCPToXMLString("test", input)).to eq expected
      end
    end

    context "for integer" do
      it "creates xml element with type=integer attribute" do
        input = { "test" => 5, "lest" => -5 }
        expected = "<?xml version=\"1.0\"?>\n" \
          "<!DOCTYPE test SYSTEM \"Testing system\">\n" \
          "<test>\n" \
          "  <lest type=\"integer\">-5</lest>\n" \
          "  <test type=\"integer\">5</test>\n" \
          "</test>\n"

        expect(subject.YCPToXMLString("test", input)).to eq expected
      end
    end

    context "for symbols" do
      it "creates xml element with type=symbol attribute" do
        input = { "test" => :test, "lest" => :lest }
        expected = "<?xml version=\"1.0\"?>\n" \
          "<!DOCTYPE test SYSTEM \"Testing system\">\n" \
          "<test>\n" \
          "  <lest type=\"symbol\">lest</lest>\n" \
          "  <test type=\"symbol\">test</test>\n" \
          "</test>\n"

        expect(subject.YCPToXMLString("test", input)).to eq expected
      end
    end

    context "for symbols" do
      it "creates xml element with type=symbol attribute" do
        input = { "test" => :test, "lest" => :lest }
        expected = "<?xml version=\"1.0\"?>\n" \
          "<!DOCTYPE test SYSTEM \"Testing system\">\n" \
          "<test>\n" \
          "  <lest type=\"symbol\">lest</lest>\n" \
          "  <test type=\"symbol\">test</test>\n" \
          "</test>\n"

        expect(subject.YCPToXMLString("test", input)).to eq expected
      end
    end

    context "for hash" do
      it "create xml elements for its keys and values" do
        input = { "test" => { "a" => "b", "lest" => :lest } }
        expected = "<?xml version=\"1.0\"?>\n" \
          "<!DOCTYPE test SYSTEM \"Testing system\">\n" \
          "<test>\n" \
          "  <test>\n" \
          "    <a>b</a>\n" \
          "    <lest type=\"symbol\">lest</lest>\n" \
          "  </test>\n" \
          "</test>\n"

        expect(subject.YCPToXMLString("test", input)).to eq expected
      end

      it "skips all entries that does not have string as key" do
        input = { "test" => { "a" => "b", "lest" => :lest, 1 => 2, nil => "t", :symbol => "symbol" } }
        expected = "<?xml version=\"1.0\"?>\n" \
          "<!DOCTYPE test SYSTEM \"Testing system\">\n" \
          "<test>\n" \
          "  <test>\n" \
          "    <a>b</a>\n" \
          "    <lest type=\"symbol\">lest</lest>\n" \
          "  </test>\n" \
          "</test>\n"

        expect(subject.YCPToXMLString("test", input)).to eq expected
      end

      it "place keys in alphabetic sorting" do
        input = { "test" => { "a" => "b", "lest" => :lest, "b" => "c" } }
        expected = "<?xml version=\"1.0\"?>\n" \
          "<!DOCTYPE test SYSTEM \"Testing system\">\n" \
          "<test>\n" \
          "  <test>\n" \
          "    <a>b</a>\n" \
          "    <b>c</b>\n" \
          "    <lest type=\"symbol\">lest</lest>\n" \
          "  </test>\n" \
          "</test>\n"

        expect(subject.YCPToXMLString("test", input)).to eq expected
      end

      # TODO: looks a bit strange to me and even no warning is written to log
      it "skips all entries after entry with nil as value" do
        input = { "test" => { "a" => "b", "b" => "c", "c" => nil, "d" => "e", "e" => "f" } }
        expected = "<?xml version=\"1.0\"?>\n" \
          "<!DOCTYPE test SYSTEM \"Testing system\">\n" \
          "<test>\n" \
          "  <test>\n" \
          "    <a>b</a>\n" \
          "    <b>c</b>\n" \
          "  </test>\n" \
          "</test>\n"

        expect(subject.YCPToXMLString("test", input)).to eq expected
      end
    end

    context "for array" do
      it "create xml elements for values and specify type=list" do
        input = { "test" => ["b", :lest] }
        expected = "<?xml version=\"1.0\"?>\n" \
          "<!DOCTYPE test SYSTEM \"Testing system\">\n" \
          "<test>\n" \
          "  <test type=\"list\">\n" \
          "    <listentry>b</listentry>\n" \
          "    <listentry type=\"symbol\">lest</listentry>\n" \
          "  </test>\n" \
          "</test>\n"

        expect(subject.YCPToXMLString("test", input)).to eq expected
      end

      # see global before section for listEntries
      it "creates xml elements with name passed to listEntries if found" do
        input = { "list1" => ["b", :lest] }
        expected = "<?xml version=\"1.0\"?>\n" \
          "<!DOCTYPE test SYSTEM \"Testing system\">\n" \
          "<test>\n" \
          "  <list1 type=\"list\">\n" \
          "    <list1_element>b</list1_element>\n" \
          "    <list1_element type=\"symbol\">lest</list1_element>\n" \
          "  </list1>\n" \
          "</test>\n"

        expect(subject.YCPToXMLString("test", input)).to eq expected
      end

      # TODO: looks a bit strange to me and even no warning is written to log
      it "skips all entries after entry with nil" do
        input = { "test" => ["a", "b", nil, "d", "e", "f"] }
        expected = "<?xml version=\"1.0\"?>\n" \
          "<!DOCTYPE test SYSTEM \"Testing system\">\n" \
          "<test>\n" \
          "  <test type=\"list\">\n" \
          "    <listentry>a</listentry>\n" \
          "    <listentry>b</listentry>\n" \
          "  </test>\n" \
          "</test>\n"

        expect(subject.YCPToXMLString("test", input)).to eq expected
      end
    end
  end
end
