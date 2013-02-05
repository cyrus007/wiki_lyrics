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
require 'lyrics'

class Sing365 < Lyrics

	def Sing365.lyrics_site()
		return 'www.sing365.com'
	end

	def Sing365.script_name()
		return 'Sing365'
	end

	def build_lyrics_fetch_data( artist, title, album=nil, year=nil )
		return { 'url' => build_google_feeling_lucky_url( artist, title ) }
	end

	def parse_lyrics( url, body, artist, title, album=nil, year=nil )

		body.tr_s!( " \n\r\t", ' ' )

		lyrics_data = {}

		if ( (md = /<meta name="Description" content="([^"]+) - ([^"]+) lyrics">/.match( body )) != nil )
			lyrics_data['artist'], lyrics_data['title'] = md[1], md[2]
		end

		if ( body.gsub!( /^.*<B>[^<]+<\/B><B> Lyrics<\/B><br><BR>/, '' ) )
			lyrics_data['lyrics'] = body
			lyrics_data['lyrics'].gsub!( /^.*<\/script><BR>/, '' )
			lyrics_data['lyrics'].gsub!( /<hr size=1 color=#cccccc>If you find some error in.*$/, '' )
			lyrics_data['lyrics'].gsub!( /\ ?<br\/?> ?/i, "\n" )
			lyrics_data['lyrics'].gsub!( /\n{3,}/, "\n\n" )
		end

		return lyrics_data
	end

	def build_suggestions_fetch_data( artist, title, album=nil, year=nil )
		return { 'url' => build_google_feeling_lucky_url( artist ) }
	end

	def parse_suggestions( url, body, artist, title, album=nil, year=nil )

		body.tr_s!( " \n\r\t", ' ' )

		suggestions = []

		return suggestions if ( ! body.gsub!( /.*<\/script><BR> <li>[^<]+ Lyrics - /, '' ) )
		return suggestions if ( ! body.gsub!( /<\/lu><br><BR> \(<font color=Red>Submit.*$/, '' ) )

		body.split( '<li>' ).each() do |entry|
			md = /<a href="([^"]+)">([^<>]+) Lyrics<\/a>/.match( entry )
			next if ( md == nil )
			s_url, s_title = md[1], md[2]
			if ( s_url != '' && s_title != '' )
				suggestions << { 'url'=>"http://#{lyrics_site()}#{s_url}", 'artist'=>artist, 'title'=>s_title }
			end
		end

		return suggestions
	end

end
