#!/usr/bin/env ruby

require 'fileutils'

def get_ruby_dir()
	candidate_dirs = [ ENV['PROGRAMFILES'], ENV['SYSTEMDRIVE'], ENV['SYSTEMDRIVE'] ]
	candidate_dirs.each() do |dir|
		next if ( dir == nil )
		dir = "#{dir.gsub( '\\', '/' )}/ruby"
		return dir if ( FileTest.exist?( dir ) )
	end
	return nil
end

def get_gtk_dir()
	return ENV['GTK_BASEPATH'] != nil ? ENV['GTK_BASEPATH'].gsub( '\\', '/' ) : nil
end

toolkit = ARGV[0].to_s().downcase().strip()
if ( toolkit == 'gtk' || toolkit == 'gtk2' )
	ruby_dir = get_ruby_dir()
	if ( ruby_dir == nil )
		puts 'Sorry... couldn\'t find the Ruby installation dir.'
		exit 1
	end
	gtk_dir = get_gtk_dir()
	if ( gtk_dir == nil )
		puts 'Sorry... couldn\'t find the GTK installation dir.'
		exit 1
	end
	begin
		puts 'Applying Ruby/GTK fix:'
		$stdout << " - Backing up '#{ruby_dir}/bin/iconv.dll' to '#{ruby_dir}/bin/iconv.dll.old'..."
		FileUtils.move( "#{ruby_dir}/bin/iconv.dll", "#{ruby_dir}/bin/iconv.dll.old" )
		puts ' OK'
		$stdout << " - Copying '#{gtk_dir}/bin/iconv' to '#{ruby_dir}/bin/iconv.dll'..."
		FileUtils.copy( "#{gtk_dir}/bin/iconv.dll", "#{ruby_dir}/bin/iconv.dll" )
		puts ' OK'
		puts 'GTK fix applied successfully.'
	rescue Errno::ENOENT
		puts ' ERROR'
		puts 'There was an error applying the GTK fix.'
		exit 1
	end
elsif ( toolkit == 'tk' )
	puts 'Sorry... not implemented yet.'
	exit 1
else
	puts 'Usage: win_fix.rb {gtk|tk}'
	puts 'Fix common problems with Ruby/GTK or Tcl/Tk Windows installations.'
	exit 1
end
