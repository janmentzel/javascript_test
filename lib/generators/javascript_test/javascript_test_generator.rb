class JavascriptTestGenerator < Rails::Generators::NamedBase
  source_root File.expand_path('../templates', __FILE__)
  
  def generate_javascript_test
    empty_directory 'test/javascript'
    template 'javascript_test.html', File.join('test/javascript', "#{name.underscore}_test.html")
  end

end