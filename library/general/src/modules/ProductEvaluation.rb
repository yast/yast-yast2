# Copyright (c) [2020] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "yast"
require "y2packager/medium_type"
require "y2packager/resolvable"
require "y2packager/repository"

module Yast
  class ProductEvaluationClass < Module

    LOGFILE = "product_information"
    LOGDIR = "/var/log/YaST2/product_info/"
    SCC_FILE = "/var/log/YaST2/registration_addons.yml"
      
    include Yast::Logger    
    
    def main

      Yast.import "Mode"
      Yast.import "RootPart"
      Yast.import "Packages"      

      #
      # Function calls which has been set by other modules or 3.parties.
      # These functions will be called while generating the output.
      # The return value (hash) will be logged into the output file.
      @dump_callbacks = []
    end

    #
    # Reset all callbacks which would be called while dumping the
    # log file.
    #
    def reset()
      @dump_callbacks = []      
    end

    #
    # Add a callback which will be called while generating the
    # yml file. This callback must return a hash.
    #
    # Example:
    #
    #     Yast.import "ProductEvaluation"          
    #
    #     func = -> do
    #        data = MyClass.collect_data
    #        { foo: data }
    #     end
    #
    #     ProductEvaluation.add(func)
    #
    # @param [Proc] function which has be called

    def add(function_call)
      @dump_callbacks << function_call
    end

    #
    # Writes all current available information about the
    # product selection in a YUML file
    #
    # @param [String] filename
    # @return [Boolean] success
    def write(filename = LOGFILE)
      ret = {}
      destfile = File.join(LOGDIR, "#{filename}_#{Time.now.strftime('%F_%I_%M_%S')}.yml")
      log.info( "Writing product information to #{destfile}" )
      
      @dump_callbacks.each do |callback|
        ret.merge!(callback.call)
      end

      ret["mode"] = Yast::Mode.mode
      ret["offline_medium"] = Y2Packager::MediumType.offline?
      if Yast::Mode.update
        #evaluating root partitions
        ret["root_prtitions"] = Yast::RootPart.rootPartitions
        ret["selected_root_partition"] = Yast::RootPart.selectedRootPartition
      end
      
      addons = registration_addons
      ret["registration_addons"] = addons unless addons.empty?
      
      ret["available_base_products"] = available_base_products

      products = Yast::Packages.group_products_by_status(Y2Packager::Resolvable.find(kind: :product))
      ret["evaluated_result"] = {}
      ret["evaluated_result"]["install_products"] = to_product_hash_list(products[:new])

      if Yast::Mode.update
        # Evaluating Products
        ret["evaluated_result"]["removed_products"] = to_product_hash_list(products[:removed])
        ret["evaluated_result"]["kept_products"] = to_product_hash_list(products[:kept])
        ret["evaluated_result"]["updated_products"] = to_update_hash_list(products[:updated])
      end

      ret["repositories"] = to_repo_hash_list(Y2Packager::Repository.all)

      ::FileUtils.mkdir_p(LOGDIR) unless File.exist?(LOGDIR)
      File.write(destfile, ret.to_yaml)
    end
    
private

    def to_product_hash_list(products)
      products.map do |product|
        { "name" => product.name, "short_name" => product.short_name,
          "display_name" => product.display_name, "version" => product.version,
          "vendor" => product.vendor }
      end
    end

    def to_repo_hash_list(repos)
      repos.map do |repo|
        {"id" => repo.repo_id,
         "name" => repo.name,
         "url" => repo.url.to_s,
         "dir" => repo.product_dir,
         "alias" => repo.repo_alias,
         "enabled" => repo.enabled?,
         "local" => repo.local?}
      end
    end

    def to_update_hash_list(products)
      products.map do |from, to|
        { "from" => {"name" => from.name, "short_name" => from.short_name,
          "display_name" => from.display_name, "version" => from.version,
          "vendor" => from.vendor},
          "to" => {"name" => to.name, "short_name" => to.short_name,
          "display_name" => to.display_name, "version" => to.version,
          "vendor" => to.vendor} }
      end
    end

    def available_base_products
      libzypp_products = Y2Packager::ProductReader.new.available_base_products
      if libzypp_products.empty? && Y2Packager::MediumType.offline?
        # Reading the product info again from the offline medium
        Y2Packager::ProductLocation
          .scan(InstURL.installInf2Url(""))
          .select { |p| p.details&.base }
          .sort(&::Y2Packager::PRODUCT_SORTER).map do |product|
          {"name" => product.details.product, "dir" => product.dir,
           "short_name" => product.details.summary,
           "display_name" => product.details.description,
           "product_package" => product.details.product_package}
        end
      else
        to_product_hash_list(libzypp_products)
      end
    end

    def registration_addons
      ret = []
      if Yast::WFM.ClientExists("scc") && File.exist?(SCC_FILE)
        require "registration/addon"
        
        addons = YAML.load_file(SCC_FILE)
        ret = addons.map do |a|
          {"name" => a.name,
           "display_name" => a.friendly_name,
           "id" => "#{a.identifier}-#{a.version}-#{a.arch}",
           "eula" => a.eula_url,
           "free" => a.free}
        end
      end
      ret
    end
    
  end
 
  ProductEvaluation = ProductEvaluationClass.new
  ProductEvaluation.main
end
