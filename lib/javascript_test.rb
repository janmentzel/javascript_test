#require 'rake/tasklib'
require 'thread'
require 'webrick'

class JavaScriptTest
  
  class Browser
    def supported?; true; end
    def setup ; end
    def open(url) ; end
    def teardown ; end
  
    def host
      require 'rbconfig'
      Config::CONFIG['host']
    end
    
    def macos?
      host.include?('darwin')
    end
    
    def windows?
      host.include?('mswin')
    end
    
    def linux?
      host.include?('linux')
    end
    
    def applescript(script)
      raise "Can't run AppleScript on #{host}" unless macos?
      system "osascript -e '#{script}' 2>&1 >/dev/null"
    end
    
    def teardown
      if macos?
        applescript <<-EOS if macos?
          tell application "System Events"
            tell process "#{to_s}"
              set frontmost to true
            end tell
            keystroke "w" using command down
          end tell
        EOS
      end
    end
    
    
    def visit(url)
      system("open -a \"#{to_s}\" \"#{url}\"") if macos?
    end    
  end
  
  class FirefoxBrowser < Browser
    def initialize(path='c:\Program Files\Mozilla Firefox\firefox.exe')
      @path = path
    end
  
    def visit(url)
      super if macos? 
      system("#{@path} #{url}") if windows? 
      system("firefox #{url}") if linux?
    end
  
    def to_s
      "Firefox"
    end
    
  end
  
  class SafariBrowser < Browser
    def supported?
      macos?
    end
    
    def visit(url)
      super if macos?
      # TODO windows
    end
  
    def to_s
      "Safari"
    end
  end
  
  class ChromeBrowser < Browser
    def supported?
      macos?
    end
    
    def visit(url)
      super if macos?
      # TODO windows
    end
  
    def to_s
      'Google Chrome'
    end
  end
  
  class IEBrowser < Browser
    def initialize(path='C:\Program Files\Internet Explorer\IEXPLORE.EXE')
      @path = path
    end
    
    def setup
      if windows?
        puts %{
          MAJOR ANNOYANCE on Windows.
          You have to shut down the Internet Explorer manually after each test
          for the script to proceed.
          Any suggestions on fixing this is GREATLY appreaciated!
          Thank you for your understanding.
        }
      end
    end
  
    def supported?
      windows?
    end
    
    def visit(url)
      system("#{@path} #{url}") if windows? 
    end
  
    def to_s
      "Internet Explorer"
    end
  end
  
  class KonquerorBrowser < Browser
    def supported?
      linux?
    end
    
    def visit(url)
      system("kfmclient openURL #{url}")
    end
    
    def to_s
      "Konqueror"
    end
  end
  
  # shut up, webrick :-)
  class ::WEBrick::HTTPServer
    def access_log(config, req, res)
      # nop
    end
  end
  class ::WEBrick::BasicLog
    def log(level, data)
      # nop
    end
  end
  
  class NonCachingFileHandler < WEBrick::HTTPServlet::FileHandler
    def do_GET(req, res)
      super
      res['etag'] = nil
      res['last-modified'] = Time.now + 1000
      res['Cache-Control'] = 'no-store, no-cache, must-revalidate, post-check=0, pre-check=0"'
      res['Pragma'] = 'no-cache'
      res['Expires'] = Time.now - 1000
    end
  end
  
  class Runner
  
    def initialize(name=:test)
      @name = name
      @tests = []
      @browsers = []
      @result = true
  
      @queue = Queue.new
  
      result = []
  
      @server = WEBrick::HTTPServer.new(:Port => 4711) # TODO: make port configurable
      @server.mount_proc("/results") do |req, res|
        @queue.push(ActiveSupport::JSON.decode(req.query['json']))
        res.body = "OK"
      end
      yield self if block_given?
      
      define
    end
    
    def successful?
      @result
    end
    
    def red(text); colorize(text, "\e[31m"); end
    def green(text); colorize(text, "\e[32m"); end
    
    def colorize(text, color_code)
      "#{color_code}#{text}\e[0m"
    end
    
    def success?(result)
      result['failures'].to_i == 0
    end
        
    def add_result(test, result)
      @results ||= []
      @results << [test, result]
      success?(result)
    end
    
    def print_result(browser)
      sum = {}
      failed = []
      all_ok = true
      @results.each do |row| 
        test, result = row
        ok = success?(result)
        
        if !ok 
          failed << test
        end
        
        all_ok &= ok
        result.except('failedTests').inject(sum) do |m, i|
               k, v = i
               m[k] ||= 0
               m[k] += v.to_i
               m
        end
      end
      if all_ok
        puts "#{green(browser)}\n #{sum['tests']} tests, #{sum['assertions']} assertions, #{sum['failures']} failures"
      else
        puts "#{red(browser)}"
        @results.each do |row|
          test, result = row
          unless success?(result)
            puts " #{test} "
            puts "   " + red(result['failedTests'].join("\n   "))
          end
        end
        puts " #{sum['tests']} tests, #{sum['assertions']} assertions, #{sum['failures']} failures"
      
      end
      puts ""
      @results = []
      all_ok
    end

    def define
      trap("INT") {
        Thread.current.kill
        @server.shutdown 
      }
      t = Thread.new { @server.start }
      
      # run all combinations of browsers and tests
      @browsers.each do |browser|
        if browser.supported?
          @tests.each do |test|
            browser.visit("http://localhost:4711#{test}?resultsURL=http://localhost:4711/results")
            browser.teardown if add_result(test, @queue.pop)
          end
          print_result(browser)
        else
          puts "#{browser} skipped, not supported on this OS"
        end
      end
      
      @server.shutdown
      t.join
    end
  
    def mount(path, dir=nil)
      dir ||= (Dir.pwd + path)
  
      @server.mount(path, NonCachingFileHandler, dir)
    end
  
    # test should be specified as a url
    def run(test)
      url = "/test/javascript/#{test}_test.html"
      unless File.exists?(File.join(Rails.root,url))
        raise "Missing test file #{url} for #{test} #{File.join(Rails.root,url)}"
      end
      @tests << url
    end
  
    def browser(browser)
      browser =
        case(browser)
          when :firefox
            FirefoxBrowser.new
          when :safari
            SafariBrowser.new
          when :chrome
            ChromeBrowser.new
          when :ie
            IEBrowser.new
          when :konqueror
            KonquerorBrowser.new
          else
            browser
        end
  
      @browsers<<browser
    end
  end

end