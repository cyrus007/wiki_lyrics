#  Copyright (C) 2007 by Sergio Pistone
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

class NotPopular < Lyrics

	def NotPopular.lyrics_site()
		return 'www.notpopular.com'
	end

	def NotPopular.script_name()
		return 'Not Popular.com'
	end

	def suggestions( artist, title, album=nil, year=nil )

		artist_search_url = "http://#{lyrics_site()}/lyrics/searchResults.php?SearchField=#{CGI::escape( artist )}"

		if ( log?() )
			log( script_name().upcase() )
			log( 'Retrieving SUGGESTIONS...' )
			log( " - received artist: #{artist}" )
			log( " - received title: #{title}" )
			log( " - received album: #{album}" ) if ( album )
			log( " - received year: #{year}" ) if ( year )
			log( " - built artist search url: #{artist_search_url}" )
			log( 'Fetching artist search page... ', 0 )
		end

		response = HTTP.fetch_page_get( artist_search_url )
		error = ! response || ! response.body()

		if ( log?() )
			if ( error )
				log( 'ERROR' )
			else
				log( 'OK' )
				log( response.body(), 2 ) if ( long_log?() )
			end
		end

		suggestions = []

		return suggestions if ( error )

		body = response.body()
		body.tr_s!( " \n\r\t", ' ' )

		return suggestions if ( ! body.gsub!( /^.*<h3>Artists:<\/h3>/i, '' ) )
		return suggestions if ( ! body.gsub!( /<h3>Albums:<\/h3>.*$/i, '' ) )

		log( 'Parsing artist album pages...', 0 ) if ( log?() )

		# body should contain the artist's album links, we have to iterate through the album pages excerpting the lyrics links

		albums_count = 0
		normalized_album = Strings.normalize_token( album.to_s() )
		body.split( /<\/a><br>/ ).each() do |album_entry|

			md = /<a href="(viewLyrics.php\?AlbumID=[0-9]+)">/.match( album_entry )
			next if ( md == nil )

			album_url = "http://#{lyrics_site()}/lyrics/#{md[1]}"
			albums_count += 1

			if ( log?() )
				log( '' ) if ( albums_count == 1 )
				log( " - #{album_url}" )
			end

			response = HTTP.fetch_page_get( album_url )
			next if ( ! response || ! response.body() )

			body = response.body()
			body.tr_s!( " \n\r\t", ' ' )

			if ( (md = /<title>(.*) Lyrics - notPopular.com<\/title>/.match( body )) != nil )
				insertion_idx = Strings.normalize_token( md[1] ).index( normalized_album ) != nil ? 0 : -1
			else
				insertion_idx = -1
			end

			next if ( ! body.gsub!( /^.*<a name="top"><\/a>/i, '' ) )
			next if ( ! body.gsub!( /^.*<hr>/i, '' ) )
			next if ( ! body.gsub!( /<p><a name="1">.*$/i, '' ) )

			body.split( /<a href="#/ ).each() do |song_entry|
				md = /([0-9]+)">[0-9]+\) *([^<]+)<\/a>/.match( song_entry )
				next if ( md == nil )
				sugg = { 'url'=>"#{album_url}##{md[1]}", 'artist'=>artist, 'title'=>md[2].strip() }
				suggestions.insert( insertion_idx, sugg )
				insertion_idx += 1 if ( insertion_idx >= 0 )
				log( "    - art: #{sugg['artist']} | tit: #{sugg['title']} | url: #{sugg['url']}" ) if ( log?() )
			end

		end

		if ( albums_count == 0 && log?() )
			log( ' NO ALBUM PAGES AND SUGGESTIONS FOUND' )
		end

		return suggestions
	end

	def build_lyrics_fetch_data( artist, title, album=nil, year=nil )
		artist = Strings.google_search_quote( artist )
		album  = Strings.google_search_quote( album.to_s() )
		return { 'url' => Strings.build_google_feeling_lucky_url( "#{artist} #{album}", "#{lyrics_site()}/lyrics" ) }
	end

	def parse_lyrics( url, body, artist, title, album=nil, year=nil )

		body.tr_s!( " \n\r\t", ' ' )

		lyrics_data = {}

		artist = Strings.downcase( artist.squeeze( ' ' ).strip() )
		if ( (md = /<title>(.*) Lyrics - notPopular.com<\/title>/.match( body )) != nil )
			page_title = Strings.downcase( md[1].squeeze( ' ' ).strip() )
			if ( (idx = page_title.index( artist )) != nil )
				lyrics_data['artist'] = Strings.titlecase( page_title.slice( 0..idx+artist.size-1 ).strip() )
				lyrics_data['album'] = Strings.titlecase( page_title.slice( idx+artist.size+3..-1 ).strip() )
			end
		end

		if ( (md = /<\/h3>Label: [^<]+ <br>Release Year: ([0-9]+) <br>/.match( body )) != nil )
			lyrics_data['year'] = md[1]
		end

		return lyrics_data if ( ! body.gsub!( /^.*<a name="top"><\/a>/i, '' ) )
		return lyrics_data if ( ! body.gsub!( /^.*<p><a name="1"><\/a><b>/i, '' ) )
		return lyrics_data if ( ! body.gsub!( /<\/div>.*$/i, '' ) )

		md = /.*#([0-9]+)$/.match( url.to_s() )
		track = md == nil ? nil : md[1]

		title = Strings.normalize_token( title )
		body.split( /<br><span style="font-size: .8em;"><a href="#top">::top::<\/a><\/span><\/p><p><a name="[0-9]+"><\/a><b>/i ).each() do |song_content|
			md = /([0-9]+)\) *([^<]+)<\/b><br>(.*)/.match( song_content )
			next if ( md == nil || ( track && track != md[1] ) || ( !track && title != Strings.normalize_token( md[2] ) ) )
			lyrics_data['title'] = md[2]
			lyrics_data['lyrics'] = md[3]
			lyrics_data['lyrics'].gsub!( /<span style="font-size: .8em;".*$/, '' )
			lyrics_data['lyrics'].gsub!( /\ *<br\/?>/i, "\n" )
			return lyrics_data
		end

		return lyrics_data
	end

end
