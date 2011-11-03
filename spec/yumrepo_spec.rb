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
      YumRepo::Settings.instance.cache_enabled = false # not strictly neccessary, but for safety
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

    it "perl-Module-Info should not have a source rpm" do
      p = @pl.all.last
      p.name.should == "perl-Module-Info"
      p.src_rpm.should == "xorg-x11-drv-savage-2.3.1-1.1.el6.src.rpm"
    end

    it "readline should have a source rpm of empty string" do
      @pl.all.first.src_rpm.should == ""
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

    it "readline should provide nothing" do
      @pl.all.last.provides.should == [{:name=>"config(pothana2000-fonts)"},
                                       {:name=>"font(:lang=te)"},
                                       {:name=>"font(pothana2000)"},
                                       {:name=>"pothana2000-fonts"}]
    end

    it "perl-Module-Info should provide stuff" do
      p = @pl.all.last
      p.name.should == "perl-Module-Info"
      @pl.all.first.provides.should == []
    end

    it "readline should require stuff" do
      @pl.all.first.requires.should == [{:name=>"rpmlib(FileDigests)"},
                                        {:name=>"ncurses-devel"},
                                        {:name=>"rpmlib(CompressedFileNames)"}]
    end
  end

  describe "cache" do
    before :each do
      @cache_dir = File.expand_path("~/.yumrepo/cache/09e41263dad74ad145d3ace79bbdaf21")
      @cache_file = File.join(@cache_dir, "primary.xml.gz")
      FileUtils.remove_entry_secure(@cache_dir) if File.exist?(@cache_dir)
    end

    it "enabled the cache file should be created" do
      File.exist?(@cache_file).should == false
      YumRepo::Settings.instance.cache_enabled = true
      pl = YumRepo::PackageList.new "http://centos.mirror.freedomvoice.com/6.0/os/SRPMS"
      pl.all.length.should == 5
      File.exist?(@cache_file).should == true
    end

    it "enabled and cache file exists, we should use it if it's not too old" do
      File.exist?(@cache_file).should == false
      YumRepo::Settings.instance.cache_enabled = true
      YumRepo::PackageList.new "http://centos.mirror.freedomvoice.com/6.0/os/SRPMS"
      File.exist?(@cache_file).should == true

      mtime = Time.at(((Time.now() - YumRepo::Settings.instance.cache_expire) + 10).to_i)
      File.utime(0, mtime, @cache_file)
      File.atime(@cache_file).should == Time.at(0)
      File.mtime(@cache_file).should == mtime
      YumRepo::PackageList.new "http://centos.mirror.freedomvoice.com/6.0/os/SRPMS"
      File.mtime(@cache_file).should == mtime
      (File.atime(@cache_file) > Time.at(0)).should == true
    end

    it "enabled and cache file exists, and is too old we should replace it" do
      File.exist?(@cache_file).should == false
      YumRepo::Settings.instance.cache_enabled = true
      YumRepo::PackageList.new "http://centos.mirror.freedomvoice.com/6.0/os/SRPMS"
      File.exist?(@cache_file).should == true

      File.utime(0, 1, @cache_file)
      File.atime(@cache_file).should == Time.at(0)
      File.mtime(@cache_file).should == Time.at(1)
      YumRepo::PackageList.new "http://centos.mirror.freedomvoice.com/6.0/os/SRPMS"
      File.mtime(@cache_file).should_not == Time.at(1)
      (File.atime(@cache_file) > Time.at(0)).should == true
    end

    it "disabled the cache file should not be created" do
      File.exist?(@cache_file).should == false
      YumRepo::Settings.instance.cache_enabled = false
      pl = YumRepo::PackageList.new "http://centos.mirror.freedomvoice.com/6.0/os/SRPMS"
      pl.all.length.should == 5
      File.exist?(@cache_file).should == false
    end

    after :each do
      YumRepo::Settings.instance.cache_enabled = false
      FileUtils.remove_entry_secure(@cache_dir) if File.exist?(@cache_dir)
    end
  end
end
