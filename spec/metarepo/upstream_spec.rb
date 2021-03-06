#
# Author: adam@opscode.com
#
# Copyright 2012, Opscode, Inc.
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

require 'metarepo/upstream'

describe Metarepo::Upstream do
  before(:each) do 
    @upstream = Metarepo::Upstream.new
    @upstream.name = "Shadows Fall"
    @upstream.type = "dir"
    @upstream.path = "/foo"
    @centos = Metarepo::Upstream.create(:name => "centos-6.0-os-i386", :type => "yum", :path => File.join(SPEC_DATA, "/upstream/centos/6.0/os/i386/Packages"))
  end

  describe "name" do
    it "must be unique" do
      @upstream.save
      lambda { 
        o = Metarepo::Upstream.create(:name => "Shadows Fall", :type => "dir", :path => "/foo")
      }.should raise_error(Sequel::ValidationFailed)
    end
  end

  describe "path" do
    it "must be present" do
      lambda { 
        Metarepo::Upstream.create(:name => "Shadows Fall", :type => "dir")
      }.should raise_error(Sequel::ValidationFailed)
    end
  end

  describe "type" do
    it "must be present" do
      lambda { 
        Metarepo::Upstream.create(:name => "Shadows Fall", :path => "/foo")
      }.should raise_error(Sequel::ValidationFailed)
    end

    [ "yum", "apt", "dir" ].each do |type_name|
      it "can be #{type_name}" do
        @upstream.type = type_name
        lambda { @upstream.save }.should_not raise_error(Sequel::ValidationFailed)
      end
    end

    it "raises an error on other values" do
      @upstream.type = "frobnobbery"
      lambda { @upstream.save }.should raise_error(Sequel::ValidationFailed)
    end
  end
  
  describe "list_packages" do

		describe "rpm" do
			it "should return the path to each package in the upstream" do
				lp = @centos.list_packages
				lp.should include(File.join(SPEC_DATA, "/upstream/centos/6.0/os/i386/Packages", "bitmap-fonts-compat-0.3-15.el6.noarch.rpm"))
				lp.should include(File.join(SPEC_DATA, "/upstream/centos/6.0/os/i386/Packages", "basesystem-10.0-4.el6.noarch.rpm"))
			end
		end

		describe "debian" do
			it "should return the packages in the pool for the repo" do
				@deb = Metarepo::Upstream.create(:name => "debian-stable-main-amd64", :type => "apt", :path => File.join(SPEC_DATA, "upstream/debian/dists/stable/main/binary-amd64"))
				lp = @deb.list_packages
				lp.should include(File.join(SPEC_DATA, "upstream/debian/pool/main/2/2vcard/2vcard_0.5-3_all.deb"))
			end
		end
  end

  describe "sync_packages" do
    it "should create Metarepo::Package entries for each package in the upstream" do
      @centos.sync_packages
      Metarepo::Package[:name => "bitmap-fonts-compat"].should be_a_kind_of(Metarepo::Package)
      Metarepo::Package[:name => "basesystem"].should be_a_kind_of(Metarepo::Package)
    end

    it "should associate the packages with the upstream" do
      @centos.sync_packages
      @centos.packages.detect { |obj| obj.name == "bitmap-fonts-compat" }.should be_a_kind_of(Metarepo::Package)
      @centos.packages.detect { |obj| obj.name == "basesystem" }.should be_a_kind_of(Metarepo::Package)
    end

    it "should remove packages from the upstream that are no longer present" do
      @centos.sync_packages
      @centos.sync_packages([File.join(SPEC_DATA, "/upstream/centos/6.0/os/i386/Packages", "basesystem-10.0-4.el6.noarch.rpm")])
      @centos.packages(true).detect { |obj| obj.name == "bitmap-fonts-compat" }.should == nil 
      @centos.packages.detect { |obj| obj.name == "basesystem" }.should be_a_kind_of(Metarepo::Package)
    end
  end
end
