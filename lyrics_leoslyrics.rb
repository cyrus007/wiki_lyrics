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
require 'cgi'

class LeosLyrics < Lyrics

	def LeosLyrics.lyrics_site()
		return 'www.leoslyrics.com'
	end

	def LeosLyrics.script_name()
		return 'Leos Lyrics'
	end

	def build_lyrics_fetch_data( artist, title, album=nil, year=nil )
		return { 'url' => build_google_feeling_lucky_url( artist, title ) }
	end

	def parse_lyrics( url, body, artist, title, album=nil, year=nil )

		body = Strings.latin12utf8( body )
		body.tr_s!( " \n\r\t", ' ' )
		HTMLEntities.decode!( body )

		lyrics_data = {}

		if ( (md = /<TITLE> ?Leo's Lyrics Database ?- ?(.+) ?- ?(.+) ?lyrics ?<\/TITLE>/.match( body )) != nil )
			lyrics_data['artist'], lyrics_data['title'] = md[1], md[2]
		end

		if ( (md = /<font face="[^"]+" size=-1>(.+)<\/font>/.match( body )) != nil )
			lyrics_data['lyrics'] = md[1]
			lyrics_data['lyrics'].gsub!( /<\/font>.*/, '' )
			lyrics_data['lyrics'].gsub!( /\ ?<br ?\/?> ?/i, "\n" )
			lyrics_data['lyrics'].gsub!( /\n{3,}/, "\n\n" )
		end

		return lyrics_data
	end

	def build_suggestions_fetch_data( artist, title, album=nil, year=nil )
		return	{ 'url' =>	"http://#{lyrics_site()}/advanced.php?" \
							"artistmode=1&artist=#{CGI.escape( Strings.utf82latin1( artist ) )}&" \
							"songmode=1&song=#{CGI.escape( Strings.utf82latin1( title ) )}&mode=0" }
	end

	def parse_suggestions( url, body, artist, title, album=nil, year=nil )

		body = Strings.latin12utf8( body )
		body.tr_s!( " \n\r\t", ' ' )
		HTMLEntities.decode!( body )

		md = /<tr> ?<td> ?<font face="[^"]+" size=3> ?<B>ARTIST<\/B> ?<\/font> ?<\/td> ?<td> ?<font face="[^"]+" size=3> ?<B>SONG<\/B> ?<\/font> ?<\/td> ?<\/tr>(.+)<\/table> ?<p align="center">/.match( body )
		body = md[1] if ( md != nil )

		suggestions = []

		return suggestions if ( md == nil )

		body.split( '</td> <tr>' ).each do |entry|
			md = /<a href="(.+)">(.+)<\/a>(.+)listlyrics.php;(.+)\?hid=(.+)"><b>(.+)<\/b>/.match( entry )
			next if ( md == nil )
			s_url, s_artist, s_title = md[5], md[2], md[6]
			if ( s_url != '' && s_title != '' && s_artist != '' )
				suggestions << { 'url' => "http://#{lyrics_site()}/listlyrics.php?hid=#{s_url}",
								 'artist' => s_artist, 'title' => s_title }
			end
		end

		return suggestions
	end

end
