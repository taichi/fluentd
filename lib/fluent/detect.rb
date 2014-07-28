def jruby?
  defined? JRUBY_VERSION
end
def windows?
  (RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/) != nil
end
