#    RubyGems - Debian packaging alterations
#    Copyright (C) 2008, Neil Wilson, Brightbox Systems
#    
#    This file is part of Rubygems packaging
#
#    Licensed unded the GPL. See /usr/share/common-licenses/GPL
#
require "rubygems/config_file"

module Gem

  # Set the default gem installation directories and paths to the Debian
  # defaults by poking the correct values into the ENV hash.
  ENV['GEM_HOME'] = File.join('','var','lib','gems',ConfigMap[:ruby_version])
  # I don't want to see 'default_dir' ever.
  ENV['GEM_PATH'] = user_dir

  # Always remove the executable when the gem is removed.
  # (No good reason for them to remain and they complicate the 
  # alternatives system)
  ConfigFile::OPERATING_SYSTEM_DEFAULTS["uninstall"] = "-x"
  # Don't create documentation unless asked
  ConfigFile::OPERATING_SYSTEM_DEFAULTS["install"] = "--no-ri --no-rdoc"
  ConfigFile::OPERATING_SYSTEM_DEFAULTS["update"] = "--no-ri --no-rdoc"

  post_install do |installer|
    executable_list = installer.spec.executables
    bindir = installer.bin_dir || Gem.bindir(installer.gem_home)
    if bindir == Gem.bindir && !executable_list.empty?
      localdir = File.join('','usr','local','bin')
      execs = executable_list.collect do |filename|
        "#{File.join(localdir,filename)} #{filename} #{File.join(bindir, filename)} " 
      end
      system %Q{
          update-alternatives --verbose --install #{execs.shift} 100 #{"--slave" unless execs.empty?} #{execs.join(" --slave ")}
          }
    end
  end

  post_uninstall do |uninstaller|
    executable_list = uninstaller.spec.executables
    bindir = uninstaller.bin_dir || Gem.bindir(uninstaller.gem_home)
    if bindir == Gem.bindir && !executable_list.empty?
      filename = executable_list.first
      localdir = File.join('','usr','local','bin')
      target = File.join(bindir, filename)
      unless File.exists?(target)
        # 'target' has to be there or alternatives gets upset.
        # Can't move this to pre_uninstall because we don't know
        # if the executable needs removing there.
        system %Q{
          touch #{target} && update-alternatives --verbose --remove #{filename} #{target} && rm -f #{target}
          }
      end
    end
  end

end