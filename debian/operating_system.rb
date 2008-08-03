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

  # Alternatives directories
  def self.altdir
    File.join('','usr','local','etc','gems','alternatives')
  end

  def self.admindir
    File.join(Gem.dir,'..','alternatives')
  end

  def self.localbindir
    File.join('','usr','local','bin')
  end

  # Alternatives command
  def self.update_alts
    "update-alternatives --altdir #{Gem.altdir} --admindir #{Gem.admindir} --verbose"
  end

  post_install do |installer|
    executable_list = installer.spec.executables
    bindir = installer.bin_dir || Gem.bindir(installer.gem_home)
    if bindir == Gem.bindir && !executable_list.empty?
      set_args = "#{executable_list.first} #{File.join(bindir, executable_list.first)}"
      execs = executable_list.collect do |filename|
        "#{File.join(Gem.localbindir,filename)} #{filename} #{File.join(bindir, filename)} " 
      end
      FileUtils.mkdir_p Gem.altdir unless File.directory?(Gem.altdir)
      system %Q{
        #{Gem.update_alts} --install #{execs.shift} 100 #{"--slave" unless execs.empty?} #{execs.join(" --slave ")} && #{update_alts} --set #{set_args}
      }
    end
  end

  post_uninstall do |uninstaller|
    executable_list = uninstaller.spec.executables
    bindir = uninstaller.bin_dir || Gem.bindir(uninstaller.gem_home)
    if bindir == Gem.bindir && !executable_list.empty?
      alt_group_name = executable_list.first
      target = File.join(bindir,alt_group_name)
      unless File.exists?(target)
        remove_args = "#{alt_group_name} #{target}"
        # system pipe explanation
        # - Check there is something that needs changing
        # - 'target' has to be there or alternatives gets upset.
        #   (Can't move this to pre_uninstall because we don't know
        #   if the executable needs removing there.)
        # - if there is only 1 alternative switch to auto mode to work
        #   around a bug in the alternatives system remove command.
        #   (LP: 254382)
        # - Remove the alternative
        # - Remove the temporary target
        system %Q{
          #{Gem.update_alts} --list #{alt_group_name} >/dev/null &&
          touch #{target} &&
          if [ $(#{Gem.update_alts} --list #{alt_group_name}|wc -l) -eq 1 ]
          then
            #{Gem.update_alts} --auto #{alt_group_name}
          fi &&
          #{Gem.update_alts} --remove #{remove_args} &&
          rm -f #{target}
        }
      end
    end
  end

end
