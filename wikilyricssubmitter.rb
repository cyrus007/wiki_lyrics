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

module WikiLyricsSubmitter

	# Hack to make module methods become class methods when the module gets included
	def WikiLyricsSubmitter.included( including )
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
	end

	def lyrics_full_search( artist, title, album=nil, year=nil, verbose=false )
		ld = super( artist, title, album, year )
		if ( ld['lyrics'] != nil && ld['site'] == lyrics_site() ) # Lyrics were found on Lyriki
			if ( ld['custom']['autogen'] )
				notify( "found autogenerated page for <i>#{title}</i> by <i>#{artist}</i>" ) if ( verbose )
				if ( @prompt_autogen )
					album = ld['album'] if ( Strings.empty?( album ) )
					year = ld['year'] if ( year.to_i() == 0 )
					credits = ld['custom']['credits']
					lyricist = ld['custom']['lyricist']
					login() if ( ! logged_in?() )
					url, lyrics = submit_song_page( ld['lyrics'], artist, title, album, year, credits, lyricist, ld['lyrics_url'] )
					ld['lyrics'] = lyrics if ( url != nil )
				end
			else
				notify( "found page for <i>#{title}</i> by <i>#{artist}</i>" ) if ( verbose )
			end
		else
			notify( "no page found for <i>#{title}</i> by <i>#{artist}</i>" ) if ( verbose )
			if ( (ld['lyrics'] != nil && @submit) || @prompt_new )
				album = ld['album'] if ( Strings.empty?( album ) )
				year = ld['year'] if ( year.to_i() == 0 )
				credits = ld['custom']['credits']
				lyricist = ld['custom']['lyricist']
				login() if ( ! logged_in?() )
				no_lyrics = ld['lyrics'] == nil
				url, lyrics = submit_song_page( ld['lyrics'].to_s(), artist, title, album, year, credits, lyricist )
				ld['lyrics'] = nil if ( url == nil && no_lyrics )
			end
		end
		return ld
	end

	def submit()
		return @submit
	end

	def submit=( value )
		@submit = (value == true)
		if ( !@submit )
			@prompt_new = false
			@prompt_autogen = false
		end
	end

	def review()
		return @review
	end

	def review=( value )
		@review = (value == true)
		if ( !@review )
			@prompt_new = false
			@prompt_autogen = false
		end
	end

	def prompt_new()
		return @prompt_new
	end

	def prompt_new=( value )
		@prompt_new = (value == true)
		if ( @prompt_new )
			@submit = true
			@review = true
		end
	end

	def prompt_autogen()
		return @prompt_autogen
	end

	def prompt_autogen=( value )
		@prompt_autogen = (value == true)
		if ( @prompt_autogen )
			@submit = true
			@review = true
		end
	end

end

