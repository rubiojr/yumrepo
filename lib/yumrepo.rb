require 'rubygems'
require 'open-uri'
require 'nokogiri'
require 'net/https'
require 'zlib'
require 'benchmark'
require 'singleton'
require 'digest/md5'
require 'fileutils'
require 'logger'
require 'tempfile'
require 'active_support/core_ext'

module YumRepo

  VERSION = '0.2.1'

  def self.bench(msg)
    if defined? $yumrepo_perf_debug
      out = Benchmark.measure do
        yield
      end
      puts msg + out.to_s
    else
      yield
    end
  end

  class Settings
    include Singleton
    attr_accessor :cache_path, :cache_expire, :log_level, :cache_enabled

    def initialize
      @cache_path = "#{ENV['HOME']}/.yumrepo/cache/"
      # Cache expire in seconds
      @cache_expire = 3600
      @cache_enabled = true
      @initialized = false
      @log_level = :info
    end

    def log_level=(level)
      case level
      when :warn
        level = Logger::WARN
      when :debug
        level = Logger::DEBUG
      when :info
        level = Logger::INFO
      when :error
        level = Logger::ERROR
      when :fatal
        level = Logger::FATAL
      else
        level = Logger::DEBUG
      end
      log.level = level
    end

    def log
      @log ||= Logger.new($stdout)
    end

    def init
      if @initialized
        log.debug "Settings already initialized"
        return
      end
      log.debug "Initializing settings"
      @initialized = true
    end
  end

  class Repomd

    #
    # Rasises exception if can't retrieve repomd.xml
    #
    def initialize(url)
      @settings = Settings.instance
      @settings.init
      @url = url
      if @url =~ /\/repodata\/?/
        @url.gsub! '/repodata', ''
      end
      @url_digest = Digest::MD5.hexdigest(@url)
      @repomd_file = File.join(@settings.cache_path, @url_digest, 'repomd.xml')

      if @settings.cache_enabled and File.exist?(@repomd_file)
        @settings.log.debug "Using catched repomd.xml at #{@repomd_file}"
        f = open @repomd_file
      else
        @settings.log.debug "Fetching repomd.xml from #{@url}"
        f = URI.open "#{@url}/repodata/repomd.xml"
        if @settings.cache_enabled
          FileUtils.mkdir_p File.join(@settings.cache_path, @url_digest)
          @settings.log.debug "Caching repomd.xml for #{@url} at #{@repomd_file}"
          File.open(File.join(@settings.cache_path, @url_digest, 'repomd.xml'), 'w') do |xml|
            xml.puts f.read
          end
          f = open(@repomd_file)
        end
      end
      @repomd = Nokogiri::XML(f)
    end

    def filelists
      fl = []
      @repomd.xpath("/xmlns:repomd/xmlns:data[@type=\"filelists\"]/xmlns:location").each do |f|
       fl << File.join(@url, f['href'])
      end
      fl
    end

    def primary
      pl = []
      @repomd.xpath("/xmlns:repomd/xmlns:data[@type=\"primary\"]/xmlns:location").each do |p|
        pl << File.join(@url, p['href'])
      end

      if not @primary_xml or @primary_xml.closed?
        @primary_xml = _open_file("primary.xml.gz", @url_digest, pl.first)
      end
      @primary_xml
    end

    def meta
      def to_sym(h)
        h.inject({}) { |result, (key, value)|
          new_key = case key
                    when String then key.to_sym
                    else key
                    end
          new_value = case value
                      when Hash then to_sym(value)
                      else value
                      end
          result[new_key] = new_value
          result
        }
      end
      Hash[Hash.from_xml(@repomd.to_s)["repomd"]["data"].map {|h| [h["type"].to_sym, to_sym(h)] }]
    end

    def other
      pl = []
      @repomd.xpath("/xmlns:repomd/xmlns:data[@type=\"other\"]/xmlns:location").each do |p|
        pl << File.join(@url, p['href'])
      end

      if not @other_xml or @other_xml.closed?
        @other_xml = _open_file("other.xml.gz", @url_digest, pl.first)
      end
      @other_xml
    end

    private
    def _open_file(filename, cache_dir_name, data_url)
      cache_file_name = File.join(@settings.cache_path, cache_dir_name, filename)

      if @settings.cache_enabled and File.exist?(cache_file_name) and File.mtime(cache_file_name) > Time.now() - @settings.cache_expire
        @settings.log.debug "Using catched #{filename} at #{cache_file_name}"
        return File.open(cache_file_name, 'r')
      end

      FileUtils.mkdir_p File.join(@settings.cache_path, cache_dir_name) if @settings.cache_enabled
      if @settings.cache_enabled
        f = File.open(cache_file_name, "w+")
      else
        f = Tempfile.new(filename)
        f.unlink # see tempfile documentation
      end

      f.binmode
      @settings.log.debug "Caching #{filename} for #{data_url} at #{f.path}"
      f.puts URI.open(data_url).read
      f.pos = 0
      return f
    end

  end

  class PackageList

    def initialize(url)
      @url = url
      @packages = []
      xml_file = Repomd.new(url).primary

      begin
        buf = ''
        YumRepo.bench("Zlib::GzipReader.read") do
          buf = Zlib::GzipReader.new(xml_file).read
        end

        YumRepo.bench("Building Package Objects") do
          d = Nokogiri::XML::Reader(buf)
          d.each do |n|
            if n.name == 'package' and not n.node_type == Nokogiri::XML::Reader::TYPE_END_ELEMENT
              @packages << Package.new(n.outer_xml)
            end
          end
        end

      ensure
        if xml_file.respond_to?(:close!)
          xml_file.close!
        else
          xml_file.close
        end
      end

    end

    def each
      all.each do |p|
        yield p
      end
    end

    def all
      @packages
    end
  end

  class Package
    def initialize(xml)
      @xml = xml
    end

    def doc
      @doc ||= Nokogiri::XML(@xml)
    end

    def name
      doc.xpath('/xmlns:package/xmlns:name').text.strip
    end

    def summary
      doc.xpath('/xmlns:package/xmlns:summary').text.strip
    end

    def description
      doc.xpath('/xmlns:package/xmlns:description').text.strip
    end

    def arch
      doc.xpath('/xmlns:package/xmlns:arch').text.strip
    end

    def url
      doc.xpath('/xmlns:package/xmlns:url').text.strip
    end

    def location
      doc.xpath('/xmlns:package/xmlns:location/@href').text.strip
    end

    def version
      doc.xpath('/xmlns:package/xmlns:version/@ver').text.strip
    end

    def release
      doc.xpath('/xmlns:package/xmlns:version/@rel').text.strip
    end

    def src_rpm
      doc.xpath('/xmlns:package/xmlns:format/rpm:sourcerpm').text.strip
    end

    def group
      doc.xpath('/xmlns:package/xmlns:format/rpm:group').text.strip
    end

    def vendor
      doc.xpath('/xmlns:package/xmlns:format/rpm:vendor').text.strip
    end

    def license
      doc.xpath('/xmlns:package/xmlns:format/rpm:license').text.strip
    end

    def provides
      doc.xpath('/xmlns:package/xmlns:format/rpm:provides/rpm:entry').map do |pr|
        {
          :name => pr.at_xpath('./@name').text.strip
        }
      end
    end

    def requires
      doc.xpath('/xmlns:package/xmlns:format/rpm:requires/rpm:entry').map do |pr|
        {
          :name => pr.at_xpath('./@name').text.strip
        }
      end
    end
  end

  class PackageChangelogList
    def initialize(url)
      @url = url
      @changelogs = []
      xml_file = Repomd.new(url).other

      begin
        buf = ''
        YumRepo.bench("Zlib::GzipReader.read") do
          buf = Zlib::GzipReader.new(xml_file).read
        end

        YumRepo.bench("Building PackageChangelog Objects") do
          d = Nokogiri::XML::Reader(buf)
          d.each do |n|
            if n.name == 'package' and not n.node_type == Nokogiri::XML::Reader::TYPE_END_ELEMENT
              @changelogs << PackageChangelog.new(n.outer_xml)
            end
          end
        end

      ensure
        if xml_file.respond_to?(:close!)
          xml_file.close!
        else
          xml_file.close
        end
      end
    end

    def each
      all.each do |p|
        yield p
      end
    end

    def all
      @changelogs
    end
  end


  class PackageChangelog
    attr_reader :current_version, :current_release, :name, :arch

    @@version_regex_std = /(^|\:|\s+|v|r|V|R)(([0-9]+\.){1,10}[a-zA-Z0-9\-]+)/
    @@version_regex_odd = /(([a-zA-Z0-9\-]+)\-[a-zA-Z0-9\-]{1,10})/

    def initialize(xml)
      doc = Nokogiri::XML(xml)
      doc.remove_namespaces!
      @name = doc.xpath('/package/@name').text.strip
      @arch = doc.xpath('/package/@arch').text.strip
      @current_version = doc.xpath('/package/version/@ver').text.strip
      @current_release = doc.xpath('/package/version/@rel').text.strip

      @releases = doc.xpath('/package/changelog').map do |pr|
        {
          :author => pr.at_xpath('./@author').text.strip,
          :version => _get_version_string(pr.at_xpath('./@author').text),
          :date => Time.at(pr.at_xpath('./@date').text.strip.to_i),
          :summary => pr.text.sub(/^- /, '')
        }
      end
    end

    def each
      all.each do |r|
        yield r
      end
    end

    def all
      @releases
    end

    private

    def _get_version_string(input)
      m = @@version_regex_std.match(input)
      return m[2].to_s.strip() if m

      m = @@version_regex_odd.match(input)
      return m[1].to_s.strip() if m
    end

  end


end
