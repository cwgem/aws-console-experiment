def load_plugin(name)
  plugin_path = "#{ENV['HOME']}/irbplugins/#{name}.rb"
  if File.exists? plugin_path
    load plugin_path
  else
    raise "Could not locate plugin #{plugin_path}"
  end
end
