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

    context "for string" do
      it "creates xml element with no type attribute" do
        input = { "test" => "test", "lest" => "lest" }
        expected = "<?xml version=\"1.0\"?>\n" \
          "<!DOCTYPE test SYSTEM \"Testing system\">\n" \
          "<test>\n" \
          "  <lest>lest</lest>\n" \
          "  <test>test</test>\n" \
          "</test>\n"

        expect(subject.YCPToXMLString("test", input)).to eq expected
      end
    end

    context "for hash" do
      it "create xml elements for its keys and values and type=hash attribute" do
        input = { "test" => { "a" => "b", "lest" => :lest } }
        expected = "<?xml version=\"1.0\"?>\n" \
          "<!DOCTYPE test SYSTEM \"Testing system\">\n" \
          "<test>\n" \
          "  <test type=\"map\">\n" \
          "    <a>b</a>\n" \
          "    <lest type=\"symbol\">lest</lest>\n" \
          "  </test>\n" \
          "</test>\n"

        expect(subject.YCPToXMLString("test", input)).to eq expected
      end

      it "raises XMLInvalidKey when key is not string" do
        input = { "test" => { "a" => "b", "lest" => :lest, 1 => 2, nil => "t", :symbol => "symbol" } }

        expect { subject.YCPToXMLString("test", input) }.to raise_error(Yast::XMLInvalidKey)
      end

      it "places keys in alphabetic sorting" do
        input = { "test" => { "a" => "b", "lest" => :lest, "b" => "c" } }
        expected = "<?xml version=\"1.0\"?>\n" \
          "<!DOCTYPE test SYSTEM \"Testing system\">\n" \
          "<test>\n" \
          "  <test type=\"map\">\n" \
          "    <a>b</a>\n" \
          "    <b>c</b>\n" \
          "    <lest type=\"symbol\">lest</lest>\n" \
          "  </test>\n" \
          "</test>\n"

        expect(subject.YCPToXMLString("test", input)).to eq expected
      end

      it "raises XMLNilObject when entry has nil as value" do
        input = { "test" => { "a" => "b", "b" => "c", "c" => nil, "d" => "e", "e" => "f" } }

        expect { subject.YCPToXMLString("test", input) }.to raise_error(Yast::XMLNilObject)
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

      it "raises XMLNilObject when list contains nil" do
        input = { "test" => ["a", "b", nil, "d", "e", "f"] }

        expect { subject.YCPToXMLString("test", input) }.to raise_error(Yast::XMLNilObject)
      end
    end

    it "creates properly specified namespaces" do
      subject.xmlCreateDoc("testns",
        "cdataSections" => ["cdata1", "cdata2"],
        "systemID"      => "Testing system",
        "rootElement"   => "test",
        "nameSpace"     => "http://www.suse.com/1.0/yast2ns",
        "typeNamespace" => "http://www.suse.com/1.0/configns")

      input = { "test" => :abc, "lest" => 15 }
      expected = "<?xml version=\"1.0\"?>\n" \
        "<!DOCTYPE test SYSTEM \"Testing system\">\n" \
        "<test xmlns=\"http://www.suse.com/1.0/yast2ns\" xmlns:config=\"http://www.suse.com/1.0/configns\">\n" \
        "  <lest config:type=\"integer\">15</lest>\n" \
        "  <test config:type=\"symbol\">abc</test>\n" \
        "</test>\n"

      expect(subject.YCPToXMLString("testns", input)).to eq expected
    end
  end

  describe ".XMLToYCPString" do
    context "regarding 'config:type' and 't' attributes:" do
      it "recognizes the 't' attribute" do
        input = "<test xmlns=\"http://www.suse.com/1.0/yast2ns\" xmlns:config=\"http://www.suse.com/1.0/configns\">\n" \
          "  <foo t=\"symbol\">sym</foo>\n" \
          "</test>\n"
        expected = { "foo" => :sym }
        expect(subject.XMLToYCPString(input)).to eq expected
      end

      it "recognizes the 'type' attribute (unnamespaced)" do
        input = "<test xmlns=\"http://www.suse.com/1.0/yast2ns\" xmlns:config=\"http://www.suse.com/1.0/configns\">\n" \
          "  <foo type=\"symbol\">sym</foo>\n" \
          "</test>\n"
        expected = { "foo" => :sym }
        expect(subject.XMLToYCPString(input)).to eq expected
      end

      it "recognizes the 'config:type' attribute" do
        input = "<test xmlns=\"http://www.suse.com/1.0/yast2ns\" xmlns:config=\"http://www.suse.com/1.0/configns\">\n" \
          "  <foo config:type=\"symbol\">sym</foo>\n" \
          "</test>\n"
        expected = { "foo" => :sym }
        expect(subject.XMLToYCPString(input)).to eq expected
      end

      it "recognizes the 'config:type' attribute even with a different prefix" do
        input = "<test xmlns=\"http://www.suse.com/1.0/yast2ns\" xmlns:c=\"http://www.suse.com/1.0/configns\">\n" \
          "  <foo c:type=\"symbol\">sym</foo>\n" \
          "</test>\n"
        expected = { "foo" => :sym }
        expect(subject.XMLToYCPString(input)).to eq expected
      end

      it "in case of conflict, the shortest attribute wins (t over type over config:type)" do
        input = "<test xmlns=\"http://www.suse.com/1.0/yast2ns\" xmlns:config=\"http://www.suse.com/1.0/configns\">\n" \
          "  <foo t=\"string\" type=\"symbol\">str</foo>\n" \
          "  <bar t=\"string\" config:type=\"symbol\">str</bar>\n" \
          "  <baz config:type=\"integer\" type=\"string\">42</baz>\n" \
          "</test>\n"
        expected = { "foo" => "str", "bar" => "str", "baz" => "42" }
        expect(subject.XMLToYCPString(input)).to eq expected
      end
    end

    it "returns string for xml element with type=\"string\"" do
      input = "<?xml version=\"1.0\"?>\n" \
        "<!DOCTYPE test SYSTEM \"Testing system\">\n" \
        "<test xmlns=\"http://www.suse.com/1.0/yast2ns\" xmlns:config=\"http://www.suse.com/1.0/configns\">\n" \
        "  <test config:type=\"string\">5</test>\n" \
        "  <lest config:type=\"string\"> \n" \
        "    -5 \n" \
        "  </lest>\n" \
        "</test>\n"
      expected = { "test" => "5", "lest" => "-5" }

      expect(subject.XMLToYCPString(input)).to eq expected
    end

    # backward compatibility
    it "returns string for xml element with type=\"disksize\"" do
      input = "<?xml version=\"1.0\"?>\n" \
        "<!DOCTYPE test SYSTEM \"Testing system\">\n" \
        "<test xmlns=\"http://www.suse.com/1.0/yast2ns\" xmlns:config=\"http://www.suse.com/1.0/configns\">\n" \
        "  <test config:type=\"disksize\">5</test>\n" \
        "  <lest config:type=\"disksize\"> \n" \
        "    -5 \n" \
        "  </lest>\n" \
        "</test>\n"
      expected = { "test" => "5", "lest" => "-5" }

      expect(subject.XMLToYCPString(input)).to eq expected
    end

    it "returns string for xml element without type and with text" do
      input = "<?xml version=\"1.0\"?>\n" \
        "<!DOCTYPE test SYSTEM \"Testing system\">\n" \
        "<test xmlns=\"http://www.suse.com/1.0/yast2ns\" xmlns:config=\"http://www.suse.com/1.0/configns\">\n" \
        "  <test>5</test>\n" \
        "  <lest>\n" \
        "    -5 \n" \
        "  </lest>\n" \
        "</test>\n"
      expected = { "test" => "5", "lest" => "-5" }

      expect(subject.XMLToYCPString(input)).to eq expected
    end

    it "returns integer for xml element with type=\"integer\"" do
      input = "<?xml version=\"1.0\"?>\n" \
        "<!DOCTYPE test SYSTEM \"Testing system\">\n" \
        "<test xmlns=\"http://www.suse.com/1.0/yast2ns\" xmlns:config=\"http://www.suse.com/1.0/configns\">\n" \
        "  <test config:type=\"integer\">5</test>\n" \
        "  <lest config:type=\"integer\">-5</lest>\n" \
        "</test>\n"
      expected = { "test" => 5, "lest" => -5 }

      expect(subject.XMLToYCPString(input)).to eq expected
    end

    it "raises XMLInvalidContent for invalid integers" do
      input = "<?xml version=\"1.0\"?>\n" \
        "<!DOCTYPE test SYSTEM \"Testing system\">\n" \
        "<test xmlns=\"http://www.suse.com/1.0/yast2ns\" xmlns:config=\"http://www.suse.com/1.0/configns\">\n" \
        "  <test config:type=\"integer\">5</test>\n" \
        "  <lest config:type=\"integer\">-5</lest>\n" \
        "  <invalid config:type=\"integer\">invalid</invalid>\n" \
        "</test>\n"

      expect { subject.XMLToYCPString(input) }.to raise_error(Yast::XMLInvalidContent)
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
        "</test>\n"
      expected = { "test" => true, "lest" => false }

      expect(subject.XMLToYCPString(input)).to eq expected
    end

    it "raises XMLInvalidContent xml element with type=\"boolean\" and unknown value" do
      input = "<?xml version=\"1.0\"?>\n" \
        "<!DOCTYPE test SYSTEM \"Testing system\">\n" \
        "<test xmlns=\"http://www.suse.com/1.0/yast2ns\" xmlns:config=\"http://www.suse.com/1.0/configns\">\n" \
        "  <test config:type=\"boolean\">true</test>\n" \
        "  <lest config:type=\"boolean\">invalid</lest>\n" \
        "</test>\n"

      expect { subject.XMLToYCPString(input) }.to raise_error(Yast::XMLInvalidContent)
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

    it "works also on nested arrays" do
      input = "<?xml version=\"1.0\"?>\n" \
        "<!DOCTYPE test SYSTEM \"Testing system\">\n" \
        "<test xmlns=\"http://www.suse.com/1.0/yast2ns\" xmlns:config=\"http://www.suse.com/1.0/configns\">\n" \
        "  <test config:type=\"list\">\n" \
        "    <lest config:type=\"list\">\n" \
        "      <a config:type=\"boolean\">false</a>\n" \
        "      <b config:type=\"boolean\">true</b>\n" \
        "    </lest>\n" \
        "    <int config:type=\"integer\">5</int>\n" \
        "  </test>\n" \
        "</test>\n"
      expected = { "test" => [[false, true], 5] }

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

  it "raise Yast::XMLInvalidContent for xml element that contain sub elements and value" do
    input = "<?xml version=\"1.0\"?>\n" \
      "<!DOCTYPE test SYSTEM \"Testing system\">\n" \
      "<test xmlns=\"http://www.suse.com/1.0/yast2ns\" xmlns:config=\"http://www.suse.com/1.0/configns\">\n" \
      "  <test>\n" \
      "    <lest config:type=\"boolean\">false</lest>\n" \
      "    <int config:type=\"integer\">5</int>\n" \
      "    test value \n" \
      "  </test>\n" \
      "</test>\n"

    expect { subject.XMLToYCPString(input) }.to raise_error(Yast::XMLInvalidContent)
  end

  context "element with empty value" do
    it "return empty string if no type is specified" do
      input = "<?xml version=\"1.0\"?>\n" \
        "<!DOCTYPE test SYSTEM \"Testing system\">\n" \
        "<test xmlns=\"http://www.suse.com/1.0/yast2ns\" xmlns:config=\"http://www.suse.com/1.0/configns\">\n" \
        "  <test></test>\n" \
        "</test>\n"

      expected = { "test" => "" }
      expect(subject.XMLToYCPString(input)).to eq expected
    end

    it "returns empty string with type string" do
      input = "<?xml version=\"1.0\"?>\n" \
        "<!DOCTYPE test SYSTEM \"Testing system\">\n" \
        "<test xmlns=\"http://www.suse.com/1.0/yast2ns\" xmlns:config=\"http://www.suse.com/1.0/configns\">\n" \
        "  <test type=\"string\" />\n" \
        "</test>\n"
      expected = { "test" => "" }

      expect(subject.XMLToYCPString(input)).to eq expected
    end

    it "returns empty hash with type map" do
      input = "<?xml version=\"1.0\"?>\n" \
        "<!DOCTYPE test SYSTEM \"Testing system\">\n" \
        "<test xmlns=\"http://www.suse.com/1.0/yast2ns\" xmlns:config=\"http://www.suse.com/1.0/configns\">\n" \
        "  <test type=\"map\" />\n" \
        "</test>\n"
      expected = { "test" => {} }

      expect(subject.XMLToYCPString(input)).to eq expected
    end

    it "returns empty array with type list" do
      input = "<?xml version=\"1.0\"?>\n" \
        "<!DOCTYPE test SYSTEM \"Testing system\">\n" \
        "<test xmlns=\"http://www.suse.com/1.0/yast2ns\" xmlns:config=\"http://www.suse.com/1.0/configns\">\n" \
        "  <test type=\"list\" />\n" \
        "</test>\n"
      expected = { "test" => [] }

      expect(subject.XMLToYCPString(input)).to eq expected
    end

    it "raises XMLInvalidContent with type symbol" do
      input = "<?xml version=\"1.0\"?>\n" \
        "<!DOCTYPE test SYSTEM \"Testing system\">\n" \
        "<test xmlns=\"http://www.suse.com/1.0/yast2ns\" xmlns:config=\"http://www.suse.com/1.0/configns\">\n" \
        "  <lest type=\"symbol\"></lest>\n" \
        "</test>\n"

      expect { subject.XMLToYCPString(input) }.to raise_error(Yast::XMLInvalidContent)
    end

    it "raises XMLInvalidContent with type integer" do
      input = "<?xml version=\"1.0\"?>\n" \
        "<!DOCTYPE test SYSTEM \"Testing system\">\n" \
        "<test xmlns=\"http://www.suse.com/1.0/yast2ns\" xmlns:config=\"http://www.suse.com/1.0/configns\">\n" \
        "  <lest type=\"integer\"></lest>\n" \
        "</test>\n"

      expect { subject.XMLToYCPString(input) }.to raise_error(Yast::XMLInvalidContent)
    end

    it "raises XMLInvalidContent with type boolean" do
      input = "<?xml version=\"1.0\"?>\n" \
        "<!DOCTYPE test SYSTEM \"Testing system\">\n" \
        "<test xmlns=\"http://www.suse.com/1.0/yast2ns\" xmlns:config=\"http://www.suse.com/1.0/configns\">\n" \
        "  <lest type=\"boolean\"></lest>\n" \
        "</test>\n"

      expect { subject.XMLToYCPString(input) }.to raise_error(Yast::XMLInvalidContent)
    end

    it "workaround with empty cdata still works" do
      input = "<?xml version=\"1.0\"?>\n" \
        "<!DOCTYPE test SYSTEM \"Testing system\">\n" \
        "<test xmlns=\"http://www.suse.com/1.0/yast2ns\" xmlns:config=\"http://www.suse.com/1.0/configns\">\n" \
        "  <lest><![CDATA[]]></lest>\n" \
        "</test>\n"
      expected = { "lest" => "" }

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

    it "raises Yast::XMLParseError if xml is malformed" do
      input = "<?xml version=\"1.0\"?>\n" \
        "<!DOCTYPE test SYSTEM \"Testing system\">\n" \
        "<test xmlns=\"http://www.suse.com/1.0/yast2ns\" xmlns:config=\"http://www.suse.com/1.0/configns\">\n" \
        "  <not_closed>false</invalid\n" \
        "</test>\n"

      expect { subject.XMLToYCPString(input) }.to raise_error(Yast::XMLParseError)
    end

    it "ignores xml comments" do
      input = "<?xml version=\"1.0\"?>\n" \
        "<!DOCTYPE test SYSTEM \"Testing system\">\n" \
        "<test xmlns=\"http://www.suse.com/1.0/yast2ns\" xmlns:config=\"http://www.suse.com/1.0/configns\">\n" \
        "  <!-- we need empty list -->\n" \
        "  <test type=\"list\" />\n" \
        "</test>\n"
      expected = { "test" => [] }

      expect(subject.XMLToYCPString(input)).to eq expected
    end
  end

  describe "validate" do
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

    it "returns array for valid xml" do
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

      expect(Yast::XML.validate(xml, schema)).to be_empty
    end

    it "returns error string in array when xml is not valid for given schema" do
      xml = '<?xml version="1.0"?>
             <test>
               <person>
                 <name>
                   clark
                 </name>
               </person>
             </test>'

      expect(Yast::XML.validate(xml, schema)).to_not be_empty
    end
  end
end
