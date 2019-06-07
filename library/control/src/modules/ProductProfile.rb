# typed: false
# encoding: utf-8

# File:	modules/ProductProfile.ycp
# Package:	yast2
# Summary:	Functions for handling Product Profiles
# Authors:	Jiri Suchomel <jsuchome@suse.cz>
#
# $Id$
require "yast"
require "shellwords"

module Yast
  class ProductProfileClass < Module
    def main
      textdomain "base"

      Yast.import "Directory"
      Yast.import "Label"
      Yast.import "Mode"
      Yast.import "Pkg"
      Yast.import "Report"

      # path to the profile file on the media
      @profile_path = "/product.profile"

      # Result map of isCompliance call.
      # If map is not empty, contains reasons why system is not compliant.
      @compliance = {}

      # profiles for all installed products
      # (full paths to the temporary copies)
      @all_profiles = []

      # mapping of product id's to product names
      @productid2name = {}

      # remember products already checked
      @compliance_checked = {}

      # directory to store profiles temporary during installation
      @profiles_dir = ""
    end

    # return the result of last compliance test
    def GetComplianceMap
      deep_copy(@compliance)
    end

    # Return the list of paths to gpg keyfiles present in the root of given product media
    # @param the product id
    def GetSigKeysForProduct(src_id)
      # find the list of sigkeys
      dir_file = Pkg.SourceProvideOptionalFile(src_id, 1, "/directory.yast")
      out = Convert.to_map(
        SCR.Execute(
          path(".target.bash_output"),
          Builtins.sformat("/usr/bin/grep 'gpg-pubkey' %1 2>/dev/null", dir_file.shellescape)
        )
      )
      keys = []
      Builtins.foreach(
        Builtins.splitstring(Ops.get_string(out, "stdout", ""), "\n")
      ) do |k|
        if k != ""
          key = Pkg.SourceProvideOptionalFile(src_id, 1, Ops.add("/", k))
          keys = Builtins.add(keys, key) if !key.nil?
        end
      end
      deep_copy(keys)
    end

    # Checks the profile compliance with the system.
    # @param if productId is not nil, check only compliance with given product
    # (once new product is added, function should be called to with new product ID)
    # @ret true if the system is compliant
    def IsCompliant(productId)
      profiles = []
      products = []
      sigkeys = []

      if @profiles_dir == ""
        @profiles_dir = Ops.add(Directory.tmpdir, "/profiles/")
        SCR.Execute(path(".target.mkdir"), @profiles_dir)
      end

      # iterate all (or given) products and get the info about them
      Builtins.foreach(Pkg.ResolvableProperties("", :product, "")) do |product|
        src_id = Ops.get_integer(product, "source", -1)
        name = Ops.get_string(product, "name", "")
        if productId.nil? &&
            Ops.get_symbol(product, "status", :none) != :selected
          next
        end
        next if !productId.nil? && src_id != productId
        Ops.set(@compliance_checked, src_id, true)
        profile = Pkg.SourceProvideOptionalFile(src_id, 1, @profile_path)
        if !profile.nil?
          profiles = Builtins.add(profiles, profile)
          # backup profiles so they can be copied them to the installed system
          tmp_path = Ops.add(Ops.add(@profiles_dir, name), ".profile")
          SCR.Execute(
            path(".target.bash"),
            Builtins.sformat("/bin/cp -a %1 %2", profile.shellescape, tmp_path.shellescape)
          )
          @all_profiles = Builtins.add(@all_profiles, tmp_path)
          Ops.set(@productid2name, src_id, name)
        else
          Builtins.y2debug("no profile found for product %1", name)
          next
        end
        # generate product map:
        version_release = Builtins.splitstring(
          Ops.get_string(product, "version", ""),
          "-"
        )
        products = Builtins.add(
          products,

          "arch"    => Ops.get_string(product, "arch", ""),
          "name"    => name,
          "version" => Ops.get(version_release, 0, ""),
          "release" => Ops.get(version_release, 1, ""),
          "vendor"  => Ops.get_string(product, "vendor", "")

        )
        sigkeys = Convert.convert(
          Builtins.union(sigkeys, GetSigKeysForProduct(src_id)),
          from: "list",
          to:   "list <string>"
        )
      end

      if profiles == []
        Builtins.y2milestone("no product profile present")
        @compliance = {}
        return true
      end

      @compliance = YaPI::SubscriptionTools.isCompliant(profiles, products, sigkeys)
      @compliance.nil?
    end

    # Checks the profile compliance with the system.
    # If system is not complient, shows a popup with reasons and asks
    # to continue with the installation.
    # @ret Returns true if system is complient or user agrees to continue
    # although the complience test failed.
    # @param if productId is not nil, check only compliance with given product
    # (once new product is added, function should be called to with new product ID)
    def CheckCompliance(productId)
      # behavior for non-installation not defined yet
      return true if !Mode.installation

      # no need to check same products twice
      if productId.nil? && @compliance_checked != {} ||
          !productId.nil? && Ops.get(@compliance_checked, productId, false)
        return true
      end

      begin
        # YaPI::SubscriptionTools are only available for SLES
        Yast.import "YaPI::SubscriptionTools"
      rescue NameError
        Builtins.y2milestone("subscription-tools package not present: no compliance checking")
        return true
      end

      return true if IsCompliant(productId)

      reasons = []
      Builtins.foreach(@compliance) do |_key, val|
        if Ops.is_map?(val) && Builtins.haskey(Convert.to_map(val), "message")
          reasons = Builtins.add(
            reasons,
            Ops.get_string(Convert.to_map(val), "message", "")
          )
        end
      end
      reasons_s = Builtins.mergestring(reasons, "\n")
      # last part of the question (variable)
      end_question = _("Do you want to continue or abort the installation?")

      # button label
      continue_button = _("&Continue Installation")
      # button label
      cancel_button = _("&Abort Installation")

      # checking specific product
      if !productId.nil?
        # last part of the question (variable)
        end_question = _("Do you want to add new product anyway?")
        continue_button = Label.YesButton
        cancel_button = Label.NoButton
      end

      ret = Report.AnyQuestion(
        # popup dialog caption
        _("Warning"),
        # popup message, %1 is list of problems
        Builtins.sformat(
          _(
            "The profile does not allow you to run the products on this system.\n" \
              "Proceeding to run this installation will leave you in an unsupported state\n" \
              "and might impact your compliance requirements.\n" \
              "     \n" \
              "The following requirements are not fulfilled on this system:\n" \
              "    \n" \
              "%1\n" \
              "\n" \
              "%2"
          ),
          reasons_s,
          end_question
        ),
        continue_button,
        cancel_button,
        :no_button
      )
      if !ret && !productId.nil?
        # canceled adding add-on: remove profile stored before
        name = Ops.get(@productid2name, productId, "")
        tmp_path = Ops.add(Ops.add(@profiles_dir, name), ".profile")
        Builtins.y2milestone("deleting %1", tmp_path)
        SCR.Execute(path(".target.bash"), "/bin/rm #{tmp_path.shellescape}")
        @all_profiles = Builtins.filter(@all_profiles) { |p| p != tmp_path }
      end
      ret
    end

    publish variable: :all_profiles, type: "list <string>"
    publish variable: :productid2name, type: "map <integer, string>"
    publish variable: :compliance_checked, type: "map <integer, boolean>"
    publish function: :GetComplianceMap, type: "map <string, any> ()"
    publish function: :GetSigKeysForProduct, type: "list <string> (integer)"
    publish function: :IsCompliant, type: "boolean (integer)"
    publish function: :CheckCompliance, type: "boolean (integer)"
  end

  ProductProfile = ProductProfileClass.new
  ProductProfile.main
end
