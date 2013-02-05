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

class Lyrc < Lyrics

	def Lyrc.lyrics_site()
		return 'lyrc.com.ar'
	end

	def Lyrc.script_name()
		return 'Lyrc'
	end

	def build_lyrics_fetch_data( artist, title, album=nil, year=nil )
		artist = Strings.utf82latin1( artist )
		title  = Strings.utf82latin1( title )
		return { 'url' => "http://#{lyrics_site()}/en/tema1en.php?artist=#{CGI.escape(artist)}&songname=#{CGI.escape(title)}" }
	end

	def parse_lyrics( url, body, artist, title, album=nil, year=nil )

		body = Strings.latin12utf8( body )
		body.tr_s!( " \n\r\t", ' ' )

		lyrics_data = {}

		md = /<font size='2' ?> ?<b>([^<]+)<\/b> ?<br> ?<u>([^<]+)<\/u> ?<\/font>(.+)<a href="#" onClick="javascript:window.open\('\/?badsong.php\?/.match( body )
		md = /<font size='2' ?> ?<b>([^<]+)<\/b> ?<br> ?<u><font size='2' ?>([^<]+)<\/font> ?<\/u> ?<\/font>(.+)<a href="#" onClick="javascript:window.open\('\/?badsong.php\?/.match( body ) if ( md == nil )

		if ( md != nil )
			lyrics_data['artist'], lyrics_data['title'], lyrics_data['lyrics'] = md[1], md[2], md[3]
			lyrics_data['lyrics'].gsub!( /^.*<\/script>/, '' )
			lyrics_data['lyrics'].gsub!( /^.*<\/table>/, '' )
			lyrics_data['lyrics'].gsub!( /<p><hr size=1 noshade color=white width=100%>.*$/, '' )

			lyrics_data['lyrics'].gsub!( /\ ?<br ?\/?> ?/i, "\n" )
			lyrics_data['lyrics'].gsub!( /\n{3,}/, "\n\n" )
		end

		return lyrics_data

	end

	def build_suggestions_fetch_data( artist, title, album=nil, year=nil )
		# Same as the lyrics url (if the lyrics are found returns the lyrics, else the suggestions)
		return build_lyrics_fetch_data( artist, title, album, year )
	end

	# returns an array of maps with following keys: url, artist, title
	def parse_suggestions( url, body, artist, title, album=nil, year=nil )

		body = Strings.latin12utf8( body )
		body.tr_s!( " \n\r\t", ' ' )

		suggestions = []

		md = /Suggestions : <br>(.+)<br><br> If none is your song <br><br>/.match( body )
		return suggestions if ( md == nil )

		md[1].split( '</a>' ).each do |entry|
			md = /<a href="(.+)"><font color='white'>(.+) - (.+)<\/font>/.match( entry )
			next if ( md == nil )
			s_url, s_artist, s_title = md[1], md[2], md[3]
			if ( s_url != '' && s_title != '' && s_artist != '' )
				suggestions << { 'url'=>"http://#{lyrics_site()}/en/#{s_url}", 'artist'=>s_artist, 'title'=>s_title }
			end
		end

		return suggestions
	end

end
