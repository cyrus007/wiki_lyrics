#  Copyright (C) 2006 by Sergio Pistone
#  sergio_pistone@yahoo.com.ar
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the
#  Free Software Foundation, Inc.,
#  59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

$LOAD_PATH << File.expand_path(File.dirname(__FILE__))
require 'utils'
require 'lyrics_lyriki'
require 'lyrics_azlyrics'
require 'lyrics_baidump3'
require 'lyrics_giitaayan'
require 'lyrics_jamendo'
require 'lyrics_leoslyrics'
require 'lyrics_lyrc'
require 'lyrics_lyricwiki'
require 'lyrics_notpopular'
require 'lyrics_sing365'
require 'lyrics_terraletras'

module MetaLyrics

	@@SCRIPTS = [
		Lyriki.new(),
		LyricWiki.new(),
		AZLyrics.new(),
		BaiduMP3.new(),
		Giitaayan.new(),
		Jamendo.new(),
		LeosLyrics.new(),
		Lyrc.new(),
		NotPopular.new(),
		Sing365.new(),
		TerraLetras.new()
	]

	# Hack to make module methods become class methods when the module gets included
	def MetaLyrics.included( including )
		if including.is_a?( Class )
			including.extend( ClassMethods ) # adds class methods
		else # including.is_a?( Module )
			including::ClassMethods.append_class_methods( self )
		end
	end

	# Methods under this module will became class methods when the module gets included
	# Note: don't use def self.<method name> but just <method name>
	module ClassMethods
		def ClassMethods.append_class_methods( mod )
			include mod::ClassMethods
		end

		def config_file()
			return lyrics_site() + '.xml'
		end
	end

	def config_file()
		return self.class.config_file()
	end

	def lyrics_from_url( url, artist, title, album=nil, year=nil )
		lyrics_data = super( url, artist, title, album, year )
		return lyrics_data if ( lyrics_data['lyrics'] != nil )

		# Lyrics where not found: that means either that the url couldn't be
		# handled by self or that it was handled but still no lyrics were found.
		# In any case we ask the remaining scripts to try to fetch the lyrics at
		# url. In the first case, the url will probably be handled by one of the
		# other scripts; in the second one, none will succed unless there's other
		# script capable of handling such url. It costs nothing to try though, so
		# we do it either way.

		@used_scripts = @@SCRIPTS if ( ! defined?( @used_scripts ) )
		@used_scripts.each() do |script|
			next if ( script.class == self.class || ! script.known_url?( url ) )
			lyrics_data = script.lyrics_from_url( url, artist, title, album, year )
			return lyrics_data if ( lyrics_data['lyrics'] != nil )
		end

		return lyrics_data
	end

	def on_lyrics_not_found( artist, title, album, year )
		return lyrics_from_other_scripts( artist, title, album, year )
	end

	# Returns { lyrics, artist, title, album, year, url, site, suggestions, custom_data }
	def lyrics_from_other_scripts( artist, title, album=nil, year=nil )
		suggestions = []
		@used_scripts = @@SCRIPTS if ( ! defined?( @used_scripts ) )
		@used_scripts.each() do |script|
			next if ( script.class == self.class )
			log( "\nQuering script #{script.class.to_s.upcase()} for lyrics to #{artist} - #{title}" ) if ( log?() )
			begin
				lyrics_data = script.lyrics_full_search( artist, title, album, year )
				if ( lyrics_data['suggestions'].size > 0 )
					suggestions << script.script_name()
					suggestions.concat( lyrics_data['suggestions'] )
					lyrics_data['suggestions'] = suggestions
				end
				return lyrics_data if ( lyrics_data['lyrics'] != nil )
			rescue Timeout::Error
				notify( "#{script.script_name()} request has timed out! Site #{script.lyrics_site()} might be down." )
			end
		end
		return normalize_lyrics_data( { 'suggestions' => suggestions }, artist, title, album, year )
	end

	def read_config( force_prompt )
		values = { 'used_scripts' => nil, 'cleanup_lyrics' => @cleanup_lyrics }
		if ( read = XMLHash.read( config_file, values ) )
			self.used_script_names = values['used_scripts'].split( ';' )
			@cleanup_lyrics = values['cleanup_lyrics'].to_s() == 'true'
		end
		if ( !read || force_prompt )
			values['script'] = script_name()
			values['used_scripts'] = self.used_script_names() - [self.script_name()]
			values['unused_scripts'] = self.avail_script_names() - values['used_scripts'] - [self.script_name()]
			if ( GUI.show_meta_lyrics_config_dialog( values ) )
				self.used_script_names = values['used_scripts']
				@cleanup_lyrics = values['cleanup_lyrics'].to_s() == 'true'
			end
			values['used_scripts'] = self.used_script_names.join( ';' )
			values.delete( 'script' )
			values.delete( 'unused_scripts' )
			XMLHash.save( config_file, values )
		end
	end

	def avail_script_names()
		ret = []
		@@SCRIPTS.each { |script| ret.insert( -1, script.script_name() ) }
		return ret
	end

	def used_script_names()
		@used_scripts = @@SCRIPTS if ( ! defined?( @used_scripts ) )
		ret = []
		@used_scripts.each { |script| ret.insert( -1, script.script_name() ) }
		return ret
	end

	def used_script_names=( script_names )
		@used_scripts = []
		script_names.uniq().each() do |script_name|
			@@SCRIPTS.each do |script|
				if ( script.script_name() == script_name )
					@used_scripts.insert( -1, script )
					break
				end
			end
		end
	end

end
