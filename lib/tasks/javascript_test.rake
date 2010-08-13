desc "Run tests for JavaScripts"
task 'test:javascripts' => :environment do
  JavaScriptTest::Runner.new do |t| 

    t.mount("/", File.join(Rails.root))
    t.mount("/test", File.join(Rails.root, 'test'))
    t.mount('/test/javascript/assets', File.join(Rails.root, 'vendor/plugins/javascript_test/assets'))
    
    Dir.glob('test/javascript/*_test.html').each do |js|
      t.run(File.basename(js,'.html').gsub(/_test/,''))
    end
    
    t.browser(:safari)
    t.browser(:chrome)
    t.browser(:firefox)
    t.browser(:ie)
    t.browser(:konqueror)
  end
end
