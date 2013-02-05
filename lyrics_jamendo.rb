#  Copyright (C) 2006 by
#  Eduardo Robles Elvira <edulix@gmail.com>
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

class Jamendo < Lyrics

	def Jamendo.lyrics_site()
		return 'www.jamendo.com'
	end

	def Jamendo.script_name()
		return 'Jamendo'
	end

	def Jamendo.cleanup_artist_name( artist )
		artist = Strings.downcase( artist )
		artist.gsub!( /\[|\]|:/, '' )
		artist.gsub!( /_| |'|"|ø|&|@|\/|\*|\.|®|%|#/, ' ' ) # \' can also be ''
		artist.gsub!( /á|à|ä|â/, 'a' )
		artist.gsub!( /é|è|ë|ê/, 'e' )
		artist.gsub!( /í|ì|ï|î/, 'i' )
		artist.gsub!( /ó|ò|ö|ô/, 'o' )
		artist.gsub!( /ú|ù|ü|û/, 'u' )
		artist.squeeze!( ' ' )
		artist.strip!()
		artist.gsub!( ' ', '.' )
		return artist
	end

	def cleanup_artist_name( artist )
		self.class.cleanup_artist_name( artist )
	end

	def suggestions( artist, title, album=nil, year=nil )

		suggestions = []

		artist_url = "http://#{lyrics_site()}/en/artist/#{cleanup_artist_name( artist )}/"

		if ( log?() )
			log( script_name().upcase() )
			log( 'Retrieving SUGGESTIONS...' )
			log( " - received artist: #{artist}" )
			log( " - received title: #{title}" )
			log( " - received album: #{album}" ) if ( album )
			log( " - received year: #{year}" ) if ( year )
			log( " - built artist url: #{artist_url}" )
			log( 'Fetching artist page... ', 0 )
		end

		response = HTTP.fetch_page_get( artist_url, nil, 0 )

		if ( response && response.body() )
			error = response.body().include?( 'has no album on <b>jamendo</b> yet' )
			if ( error && log?() )
				log( 'INVALID PAGE' )
			elsif ( log?() )
				log( 'OK' )
			end
			log( response.body(), 2 ) if ( long_log?() )
		else
			error = true
			log( 'ERROR' ) if ( log?() )
		end

		if ( error )
			gs_artist = Strings.google_search_quote( artist )
			fl_artist_url = Strings.build_google_feeling_lucky_url( "artist \"albums on jamendo\" #{gs_artist}", "#{lyrics_site()}/en" )
			if ( log?() )
				log( " - built feeling lucky artist url: #{fl_artist_url}" )
				log( 'Fetching artist page... ', 0 )
			end

			response = HTTP.fetch_page_get( fl_artist_url )
			error = ! response || ! response.body()

			if ( log?() )
				if ( error )
					log( 'ERROR' )
				else
					md = /<title>Jamendo : (.*)<\/title>/.match( response.body() )
					error = (md == nil || ( Strings.normalize_token( md[1] ) != Strings.normalize_token( artist ) ))
					if ( error )
						log( 'INVALID PAGE' )
					else
						log( 'OK' )
					end
					log( response.body(), 2 ) if ( long_log?() )
				end
			end

		end

		return suggestions if ( error )
		body = response.body()

		log( 'Parsing artist album pages...', 0 ) if ( log?() )

		# body should contain the artist page, we have to iterate through the album pages excerpting the lyrics links

		albums_count = 0
		md = /loadDataFromIds\(\[([^\]]+)\]/.match( body )
		body = md[1] if ( md != nil )
		album = Strings.normalize_token( album.to_s() )
		body.split( /,/ ).each() do |album_entry|
			next if ( md == nil )

			album_url = "http://#{lyrics_site()}/en/album/#{album_entry}"
			albums_count += 1

			if ( log?() )
				log( '' ) if ( albums_count == 1 )
				log( " - #{album_url}" )
			end

			response = HTTP.fetch_page_get( album_url )
			next if ( ! response || ! response.body() )

			body = response.body()
			body.tr_s!( " \n\r\t", ' ' )

			insertion_idx = ( /<title>jamendo : .+ - #{album} ?<\/title>/i.match( body ) ) == nil ? -1 : 0
			body.split( /tr_name/ ).each() do |song_entry|
				song_entry.gsub!( /amp;/, '' )
				md = /'([^']+lyrics[^']+)'> *([^<]+)</.match( song_entry )
				next if ( md == nil )
				sugg = { 'url'=>"http://#{lyrics_site()}#{md[1]}", 'artist'=>artist, 'title'=>md[2].strip() }
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
		return { 'url' => build_google_feeling_lucky_url( artist, title ) }
	end

	def parse_lyrics( url, body, artist, title, album=nil, year=nil )

		body.squeeze!( ' ' )

		lyrics_data = {}

		md = /<title>Jamendo : Lyrics : ([^<]+)<\/title>/.match( body )
		lyrics_data['title'] = md[1].strip() if ( md != nil )

		md = /artist\/[^']+'> ([^<]+)</.match( body )
		lyrics_data['artist'] = md[1].strip() if ( md != nil )

 		md = /<pre>([^<]+)<\/pre>/.match( body )
 		lyrics_data['lyrics'] = (md == nil ? nil : md[1])

		return lyrics_data
	end

end
