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

class AZLyrics < Lyrics

	def AZLyrics.lyrics_site()
		return 'www.azlyrics.com'
	end

	def AZLyrics.script_name()
		return 'AZ Lyrics'
	end

	def build_lyrics_fetch_data( artist, title, album=nil, year=nil )
		return { 'url' => build_google_feeling_lucky_url( artist, title ) }
	end

	def parse_lyrics( url, body, artist, title, album=nil, year=nil )

		body = Strings.latin12utf8( body )
		body.tr_s!( " \n\r\t", ' ' )

		lyrics_data = {}

		md = /<B>([^<]+) LYRICS ?<\/B> ?<BR> ?<BR> ?<FONT size=2> ?<B> ?"([^<]+)" ?<\/b>(.+)\[ ?<a href="http:\/\/www\.azlyrics\.com">www\.azlyrics\.com<\/a> ?\]/.match( body )
		return lyrics_data if ( md == nil )

		lyrics_data['artist'], lyrics_data['title'], lyrics_data['lyrics'] = Strings.titlecase( md[1], true, true ), md[2], md[3]
		lyrics_data['lyrics'].gsub!( /<i>\[Thanks to.*$/, '' )
		lyrics_data['lyrics'].gsub!( /\ *<br ?\/?>\ */i, "\n" )
		lyrics_data['lyrics'].gsub!( /\n{3,}/, "\n\n" )

		return lyrics_data
	end

	def build_suggestions_fetch_data( artist, title, album=nil, year=nil )
		return { 'url' => build_google_feeling_lucky_url( artist ) }
	end

	def parse_suggestions( url, body, artist, title, album=nil, year=nil )

		body = Strings.latin12utf8( body )
		body.tr_s!( " \n\r\t", ' ' )

		suggestions = []

		md = /<TITLE>([^<]*) lyrics<\/TITLE>/i.match( body )
		return suggestions if ( md == nil )
		return suggestions if ( ! Strings.normalize_token( md[1] ).include?( Strings.normalize_token( artist ) ) )

		return suggestions if ( ! body.gsub!( /.*<tr><td align=center valign=top> <font face=verdana size=5><br> ?<b>[^<]+ lyrics<\/b>/i, '' ) )
		return suggestions if ( ! body.gsub!( /<\/font> ?<\/font> ?<\/td> ?<\/tr> ?<\/table>.*$/i, '' ) )

		body.split( /<br>/i ).each() do |entry|
			md = /<(A HREF|a href)="\.\.([^"]+)" target="_blank">([^"]+)<\/a>/.match( entry )
			next if ( md == nil )
			s_url, s_title = md[2], md[3]
			if ( s_url != '' && s_title != '' )
				suggestions << { 'url'=>"http://#{lyrics_site()}#{s_url}", 'artist'=>artist, 'title'=>s_title }
			end
		end

		return suggestions
	end

end
