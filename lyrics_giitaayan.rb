#  Copyright (C) 2007 by Sergio Pistone
#  Swapan Sarkar <swapan@yahoo.com>
#  Sergio Pistone <sergio_pistone@yahoo.com.ar>
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
require 'itrans'
require 'cgi'

class Giitaayan < Lyrics

	def Giitaayan.lyrics_site()
		return 'www.giitaayan.com'
	end

	def Giitaayan.script_name()
		return 'Giitaayan'
	end

	def parse_lyrics( url, body, artist, title, album=nil, year=nil )

		lyrics_data = { 'custom' => {} }

		['stitle', 'film', 'year', 'starring', 'singer', 'music', 'lyrics'].each() do |key|
			if ( ( md = /\\#{key}\{(.+)}%/.match( body ) ) != nil )
				lyrics_data['custom'][key] = md[1]
			end
		end

		lyrics_data['artist'] = lyrics_data['custom']['singer'] if ( ! Strings.empty?( lyrics_data['custom']['singer'] ) )
		lyrics_data['year'] = lyrics_data['custom']['year'] if ( ! Strings.empty?( lyrics_data['custom']['year'] ) )
		lyrics_data['lyricist'] = lyrics_data['custom']['lyricist'] if ( ! Strings.empty?( lyrics_data['custom']['lyrics'] ) )
		if ( ! Strings.empty?( lyrics_data['custom']['music'] ) || ! Strings.empty?( lyrics_data['custom']['lyrics'] ) )
			lyrics_data['credits'] = "#{lyrics_data['custom']['music']} #{lyrics_data['custom']['lyrics']}".strip()
		end
		if ( ! Strings.empty?( lyrics_data['custom']['stitle'] ) )
			lyrics_data['custom']['stitle'] = ITRANS.to_devanagari( lyrics_data['custom']['stitle'] )
			lyrics_data['title'] = lyrics_data['custom']['stitle']
		end

		return lyrics_data if ( ! body.gsub!( /^.*\n#indian\s*\n%?/m, '' ) )
		return lyrics_data if ( ! body.gsub!( /%?\s*\n#endindian.*$/m, '' ) )

		log( body )

		body.gsub!( '\threedots', '...' )
		body.gsub!( '\-', '-' )
		body.gsub!( '\:', ':' )
		body.gsub!( /%[^\n]*/, '' )

		lyrics_data['lyrics'] = ITRANS.to_devanagari( body )

		return lyrics_data
	end

	def build_suggestions_fetch_data( artist, title, album=nil, year=nil )
		return { 'url' => "http://#{lyrics_site()}/search.asp?browse=stitle&s=#{CGI.escape(ITRANS.from_devanagari( title ))}" }
	end

	# returns an array of maps with following keys: url, artist, title
	def parse_suggestions( url, body, artist, title, album=nil, year=nil )

		#body = Strings.latin12utf8( body )
		body.tr_s!( " \n\r\t", ' ' )

		suggestions = []

		return suggestions if ( body.include?( 'Sorry, no song found for your search!' ) )
		return suggestions if ( ! body.gsub!( /^.*<div align="center"><b>Lyrics<\/b><\/div> ?<\/td> ?<\/tr> ?<tr>/, '' ) )
		return suggestions if ( ! body.gsub!( /<form name="form1" method="get" action="search\.asp".*$/, '' ) )

		body.gsub!( /<br> ?Page <b>1<\/b> ?<a href="search.asp\?PageNo=2&s=na&browse=stitle">.*$/, '' )

		body.split( /<\/tr> ?<tr> ?/ ).each() do |sugg|
			md1 = /^ ?<td>([^<]+) - <a/.match( sugg )
			next if ( md1 == nil )
			md2 = /<a href="http:\/\/[^\/]+\/cgi-bin\/webitrans\.pl\?fileurl=(http.+\.isb)&format=isongs-s"/.match( sugg )
			next if ( md2 == nil )
			suggestions << { 'url'=>md2[1], 'title'=>ITRANS.to_devanagari( md1[1] ) }
		end
		return suggestions
	end

end
