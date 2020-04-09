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

  describe ".XMLToYCPString" do
    # XXX: not so obvious limitation of xml parser
    context "when namespace for config is \"http://www.suse.com/1.0/configns\" and type attribute is in config namespace" do
      it "returns integer for xml element with type=\"integer\"" do
        input = "<?xml version=\"1.0\"?>\n" \
          "<!DOCTYPE test SYSTEM \"Testing system\">\n" \
          "<test xmlns=\"http://www.suse.com/1.0/yast2ns\" xmlns:config=\"http://www.suse.com/1.0/configns\">\n" \
          "  <test config:type=\"integer\">5</test>\n" \
          "  <lest config:type=\"integer\">-5</lest>\n" \
          "  <invalid config:type=\"integer\">invalid</invalid>\n" \
          "</test>\n"
        expected = { "test" => 5, "lest" => -5, "invalid" => 0 }

        expect(subject.XMLToYCPString(input)).to eq expected
      end

      it "returns symbol for xml element with type=\"symbol\"" do
        input = "<?xml version=\"1.0\"?>\n" \
          "<!DOCTYPE test SYSTEM \"Testing system\">\n" \
          "<test xmlns=\"http://www.suse.com/1.0/yast2ns\" xmlns:config=\"http://www.suse.com/1.0/configns\">\n" \
          "  <test config:type=\"symbol\">5</test>\n" \
          "  <lest config:type=\"symbol\">test</lest>\n" \
          "</test>\n"
        expected = { "test" => :"5", "lest" => :test }

        expect(subject.XMLToYCPString(input)).to eq expected
      end

      it "returns boolean for xml element with type=\"boolean\"" do
        input = "<?xml version=\"1.0\"?>\n" \
          "<!DOCTYPE test SYSTEM \"Testing system\">\n" \
          "<test xmlns=\"http://www.suse.com/1.0/yast2ns\" xmlns:config=\"http://www.suse.com/1.0/configns\">\n" \
          "  <test config:type=\"boolean\">true</test>\n" \
          "  <lest config:type=\"boolean\">false</lest>\n" \
          "  <invalid config:type=\"boolean\">invalid</invalid>\n" \
          "</test>\n"
        expected = { "test" => true, "lest" => false, "invalid" => false }

        expect(subject.XMLToYCPString(input)).to eq expected
      end

      it "returns array for xml element with type=\"list\"" do
        input = "<?xml version=\"1.0\"?>\n" \
          "<!DOCTYPE test SYSTEM \"Testing system\">\n" \
          "<test xmlns=\"http://www.suse.com/1.0/yast2ns\" xmlns:config=\"http://www.suse.com/1.0/configns\">\n" \
          "  <test config:type=\"list\">\n" \
          "    <lest config:type=\"boolean\">false</lest>\n" \
          "    <int config:type=\"integer\">5</int>\n" \
          "  </test>\n" \
          "</test>\n"
        expected = { "test" => [false, 5] }

        expect(subject.XMLToYCPString(input)).to eq expected
      end

      it "returns list for xml element with type=\"list\" if contain value" do
        input = "<?xml version=\"1.0\"?>\n" \
          "<!DOCTYPE test SYSTEM \"Testing system\">\n" \
          "<test xmlns=\"http://www.suse.com/1.0/yast2ns\" xmlns:config=\"http://www.suse.com/1.0/configns\">\n" \
          "  <test config:type=\"list\">\n" \
          "    <lest config:type=\"boolean\">false</lest>\n" \
          "    <int config:type=\"integer\">5</int>\n" \
          "    test value \n" \
          "  </test>\n" \
          "</test>\n"
        expected = { "test" => [false, 5] }

        expect(subject.XMLToYCPString(input)).to eq expected
      end
    end

    it "returns hash for xml element that contain only sub elements" do
      input = "<?xml version=\"1.0\"?>\n" \
        "<!DOCTYPE test SYSTEM \"Testing system\">\n" \
        "<test xmlns=\"http://www.suse.com/1.0/yast2ns\" xmlns:config=\"http://www.suse.com/1.0/configns\">\n" \
        "  <test>\n" \
        "    <lest config:type=\"boolean\">false</lest>\n" \
        "    <int config:type=\"integer\">5</int>\n" \
        "  </test>\n" \
        "</test>\n"
      expected = { "test" => { "lest" => false, "int" => 5 } }

      expect(subject.XMLToYCPString(input)).to eq expected
    end

    # XXX: cause many bug reports when user accidentally add value as e.g. typo
    it "returns string for xml element that contain sub elements and value" do
      input = "<?xml version=\"1.0\"?>\n" \
        "<!DOCTYPE test SYSTEM \"Testing system\">\n" \
        "<test xmlns=\"http://www.suse.com/1.0/yast2ns\" xmlns:config=\"http://www.suse.com/1.0/configns\">\n" \
        "  <test>\n" \
        "    <lest config:type=\"boolean\">false</lest>\n" \
        "    <int config:type=\"integer\">5</int>\n" \
        "    test value \n" \
        "  </test>\n" \
        "</test>\n"
      expected = { "test" => "\n    test value \n  " }

      pending "disabled, as it is even more complicated, as it does not use all value, but only last value"
      expect(subject.XMLToYCPString(input)).to eq expected
    end

    # XXX: also cause some headaches
    it "skips elements with empty value" do
      input = "<?xml version=\"1.0\"?>\n" \
        "<!DOCTYPE test SYSTEM \"Testing system\">\n" \
        "<test xmlns=\"http://www.suse.com/1.0/yast2ns\" xmlns:config=\"http://www.suse.com/1.0/configns\">\n" \
        "  <lest config:type=\"boolean\">false</lest>\n" \
        "  <int></int>\n" \
        "</test>\n"
      expected = { "lest" => false }

      expect(subject.XMLToYCPString(input)).to eq expected
    end

    # for cdata see global before
    it "returns cdata section as string" do
      input = "<?xml version=\"1.0\"?>\n" \
        "<!DOCTYPE test SYSTEM \"Testing system\">\n" \
        "<test xmlns=\"http://www.suse.com/1.0/yast2ns\" xmlns:config=\"http://www.suse.com/1.0/configns\">\n" \
        "  <cdata1>false</cdata1>\n" \
        "</test>\n"
      expected = { "cdata1" => "false" }

      expect(subject.XMLToYCPString(input)).to eq expected
    end

    it "returns nil if xml is malformed" do
      input = "<?xml version=\"1.0\"?>\n" \
        "<!DOCTYPE test SYSTEM \"Testing system\">\n" \
        "<test xmlns=\"http://www.suse.com/1.0/yast2ns\" xmlns:config=\"http://www.suse.com/1.0/configns\">\n" \
        "  <not_closed>false</invalid\n" \
        "</test>\n"
      expected = nil

      expect(subject.XMLToYCPString(input)).to eq expected
    end
  end

  describe ".XMLError" do
    it "returns the last error whe parsing XML" do
      input = "<?xml version=\"1.0\"?>\n" \
        "<!DOCTYPE test SYSTEM \"Testing system\">\n" \
        "<test xmlns=\"http://www.suse.com/1.0/yast2ns\" xmlns:config=\"http://www.suse.com/1.0/configns\">\n" \
        "  <not_closed>false</invalid\n" \
        "</test>\n"
      subject.XMLToYCPString(input)

      expect(subject.XMLError).to_not be_empty
    end

    it "returns empty string if there is no error" do
      input = "<?xml version=\"1.0\"?>\n" \
        "<test>false</test>"
      subject.XMLToYCPString(input)

      expect(subject.XMLError).to eq ""
    end
  end

  describe "XMLValidation" do
    let(:schema) do
      '<element name="test" xmlns="http://relaxng.org/ns/structure/1.0">
         <zeroOrMore>
           <element name="person">
             <element name="name">
               <text/>
             </element>
             <element name="voice">
               <text/>
             </element>
           </element>
         </zeroOrMore>
       </element>'
    end

    it "returns empty string for valid xml" do
      xml = '<?xml version="1.0"?>
             <test>
               <person>
                 <name>
                   clark
                 </name>
                 <voice>
                   nice
                 </voice>
               </person>
             </test>'

      expect(Yast::XML.XMLValidation(xml, schema)).to be_empty
    end

    it "returns error when xml is not valid for given schema" do
      xml = '<?xml version="1.0"?>
             <test>
               <person>
                 <name>
                   clark
                 </name>
               </person>
             </test>'

      expect(Yast::XML.XMLValidation(xml, schema)).to_not be_empty
    end
  end
end
