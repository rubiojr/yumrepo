require 'rspec'
require 'net/http'
require 'spec_helper'

describe YumRepo do

  FakeWeb.register_uri(:get, "http://centos.mirror.freedomvoice.com/6.0/os/SRPMS/repodata/repomd.xml", :body => File.read("spec/test_data/repomd.xml"))
  FakeWeb.register_uri(:get, "http://centos.mirror.freedomvoice.com/6.0/os/SRPMS/repodata/primary.xml.gz", :body => File.read("spec/test_data/primary.xml.gz"))
  YumRepo::Settings.instance.log_level = :error
  YumRepo::Settings.instance.cache_enabled = false

  describe "package list" do
    it "for test_data should have 5 entries" do
      pl = YumRepo::PackageList.new "http://centos.mirror.freedomvoice.com/6.0/os/SRPMS"
      pl.all.length.should == 5
    end
  end

  describe "package parsing" do
    before :each do
      @pl = YumRepo::PackageList.new "http://centos.mirror.freedomvoice.com/6.0/os/SRPMS"
    end

    it "first package should be readline" do
      @pl.all.first.name.should == "readline"
    end

    it "readline should have a summary" do
      @pl.all.first.summary.should == "A library for editing typed command lines"
    end

    it "readline should have a version" do
      @pl.all.first.version.should == "6.0"
    end

    it "readline should have a release" do
      @pl.all.first.release.should == "3.el6"
    end

    it "readline should not have a source rpm (" do
      @pl.all.second.src_rpm.should == "3.el6"
    end

    it "readline should have a group" do
      @pl.all.first.group.should == "System Environment/Libraries"
    end

    it "readline should have a vendor" do
      @pl.all.first.vendor.should == "CentOS"
    end

    it "readline should have a license" do
      @pl.all.first.license.should == "GPLv3+"
    end

    it "readline should have a description" do
      @pl.all.first.description.should == "The Readline library provides a set of functions
    that allow users to edit command lines. Both Emacs and vi
    editing modes are available. The Readline library includes
    additional functions for maintaining a list of
    previously-entered command lines for recalling or editing those
    lines, and for performing csh-like history expansion on
    previous commands."
    end

    it "readline should have a url" do
      @pl.all.first.url.should == "http://cnswww.cns.cwru.edu/php/chet/readline/rltop.html"
    end

    it "readline should have a location" do
      @pl.all.first.location.should == "Packages/readline-6.0-3.el6.src.rpm"
    end
  end

end
