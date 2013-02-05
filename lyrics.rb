#!/usr/bin/env ruby

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
require 'htmlentities'

$LOG      = false
$LONG_LOG = false
$LOG_FILE = $LOG ? "#{ENV['HOME']}/Desktop/lyrics.log" : nil

class Lyrics

	attr_reader :cleanup_lyrics
	attr_writer :cleanup_lyrics
	attr_reader :proxy_url
	attr_writer :proxy_url
	attr_reader :log_file
	attr_writer :log_file

	def initialize( cleanup_lyrics=true, log_file=$LOG_FILE )
		super()
		@cleanup_lyrics = cleanup_lyrics
		@log_file = log_file
	end

	def log?()
		return log_file() != nil
	end

	def long_log?()
		return log?() && $LONG_LOG
	end

	def log( message, new_lines=1 )
		Logging.log( log_file(), message, new_lines )
	end

	def lyrics_site()
		return self.class.lyrics_site()
	end

	def script_name()
		return self.class.script_name()
	end

	def Lyrics.known_url?( url )
		return url.index( "http://#{lyrics_site}" ) == 0
	end

	def known_url?( url )
		return self.class.known_url?( url )
	end

	def notify( message )
		puts "#{script_name()}: #{message}"
	end

	def normalize_lyrics_data( lyrics_data, artist, title, album, year, url=nil, site=nil )
		lyrics_data['lyrics'] = nil if ( ! lyrics_data.include?( 'lyrics' ) )
		lyrics_data['artist'] = artist if ( ! lyrics_data.include?( 'artist' ) )
		lyrics_data['title'] = title if ( ! lyrics_data.include?( 'title' ) )
		lyrics_data['album'] = album if ( ! lyrics_data.include?( 'album' ) )
		lyrics_data['year'] = year if ( ! lyrics_data.include?( 'year' ) )
		lyrics_data['url'] = url if ( ! lyrics_data.include?( 'url' ) )
		lyrics_data['site'] = site if ( ! lyrics_data.include?( 'site' ) )
		lyrics_data['suggestions'] = [] if ( ! lyrics_data.include?( 'suggestions' ) )
		lyrics_data['custom'] = {} if ( ! lyrics_data.include?( 'custom' ) )
		return lyrics_data
	end
	protected :normalize_lyrics_data

	# Returns { url, [post] }
	def build_lyrics_fetch_data( artist, title, album=nil, year=nil )
		return { 'url' => nil }
	end

	# Returns the lyrics page body or nil if it couldn't be retrieved
	def fetch_lyrics_page( url, post )
		return nil if ( url == nil )
		log( 'Fetching lyrics page... ', 0 ) if ( log?() )
		response = post ? HTTP.fetch_page_post( url, post ) : HTTP.fetch_page_get( url )
		if ( log?() )
			if ( response && response.body() )
				log( 'OK' )
				log( response.body(), 2 ) if ( long_log?() )
			else
				log( 'ERROR' )
			end
		end
		return response ? response.body() : nil
	end

	# Returns { lyrics, [artist], [title], [album], [year], [custom_data] }
	def parse_lyrics( url, body, artist, title, album=nil, year=nil )
		notify( 'warning: falling back to default (stub) implementation for parse_lyrics' )
		return { 'lyrics' => nil }
	end

	# Returns { lyrics, artist, title, album, year, url, site, suggestions, custom_data }
	def lyrics_direct_search( artist, title, album=nil, year=nil )

		fetch_data = build_lyrics_fetch_data( artist, title, album, year )

		if ( log?() )
			log( script_name().upcase() )
			log( 'Attempting LYRICS DIRECT SEARCH...' )
			log( " - received artist: #{artist}" )
			log( " - received title: #{title}" )
			log( " - received album: #{album}" ) if ( album )
			log( " - received year: #{year}" ) if ( year )
			log( " - built lyrics url: #{fetch_data['url']}" )
			if ( fetch_data['post'] != nil && fetch_data['post'].size() > 0)
				log( " - post data:" )
				post.each { |key, val| log( "    - #{key}: #{val}" ) }
			end
		end

		page_body = fetch_lyrics_page( fetch_data['url'], fetch_data['post'] )
		if ( page_body != nil )
			log( 'Parsing lyrics... ', 0 ) if ( log?() )
			lyrics_data = parse_lyrics( fetch_data['url'], page_body, artist, title, album, year )
			if ( log?() )
				log( lyrics_data['lyrics'] == nil ? "LYRICS NOT FOUND" : "LYRICS FOUND" )
				log( " - parsed lyrics:\n[#{lyrics_data['lyrics']}]" ) if long_log?()
				log( " - parsed artist: #{lyrics_data['artist']}") if ( lyrics_data['artist'] )
				log( " - parsed title: #{lyrics_data['title']}") if ( lyrics_data['title'] )
				log( " - parsed album: #{lyrics_data['album']}") if ( lyrics_data['album'] )
				log( " - parsed year: #{lyrics_data['year']}") if ( lyrics_data['year'] )
				if ( lyrics_data['custom'] != nil && lyrics_data['custom'].size() > 0 )
					log( " - parsed custom data:" )
					lyrics_data['custom'].each { |key, val| log( "    - #{key}: #{val}" ) }
				end
			end
			if ( lyrics_data['lyrics'] != nil )
				lyrics_data['lyrics'] = Strings.cleanup_lyrics( lyrics_data['lyrics'] ) if ( @cleanup_lyrics )
				return normalize_lyrics_data( lyrics_data, artist, title, album, year, fetch_data['url'], lyrics_site() );
			end
		end
		return normalize_lyrics_data( {}, artist, title, album, year )
	end

	# Returns { lyrics, artist, title, album, year, custom_data }
	def lyrics_from_url( url, artist, title, album=nil, year=nil )

		if ( known_url?( url ) )
			if ( log?() )
				log( script_name().upcase() )
				log( 'Retrieving LYRICS FROM URL...' )
				log( " - received url: #{url}" )
				log( " - received artist: #{artist}" )
				log( " - received title: #{title}" )
				log( " - received album: #{album}" ) if ( album )
				log( " - received year: #{year}" ) if ( year )
			end

			page_body = fetch_lyrics_page( url, nil )
			if ( page_body != nil )
				log( 'Parsing lyrics... ', 0 ) if ( log?() )
				lyrics_data = parse_lyrics( url, page_body, artist, title, album, year )
				if ( log?() )
					log( lyrics_data['lyrics'] == nil ? "LYRICS NOT FOUND" : "LYRICS FOUND" )
					log( " - parsed lyrics:\n[#{lyrics_data['lyrics']}]" ) if long_log?()
					log( " - parsed artist: #{lyrics_data['artist']}") if ( lyrics_data['artist'] )
					log( " - parsed title: #{lyrics_data['title']}") if ( lyrics_data['title'] )
					log( " - parsed album: #{lyrics_data['album']}") if ( lyrics_data['album'] )
					log( " - parsed year: #{lyrics_data['year']}") if ( lyrics_data['year'] )
					if ( lyrics_data['custom'] != nil && lyrics_data['custom'].size() > 0 )
						log( " - parsed custom data:" )
						lyrics_data['custom'].each { |key, val| log( "    - #{key}: #{val}" ) }
					end
				end
				if ( lyrics_data['lyrics'] != nil )
					lyrics_data['lyrics'] = Strings.cleanup_lyrics( lyrics_data['lyrics'] ) if ( @cleanup_lyrics )
					return normalize_lyrics_data( lyrics_data, artist, title, album, year, url, lyrics_site() )
				end
			end
		end

		return normalize_lyrics_data( {}, artist, title, album, year )

	end

	# Returns { url, [post] }
	def build_suggestions_fetch_data( artist, title, album=nil, year=nil )
		return { 'url' => nil }
	end

	# Returns the lyrics page body or nil if it couldn't be retrieved
	def fetch_suggestions_page( url, post )
		return nil if ( url == nil )
		if ( log?() )
			log( " - built suggestions url: #{url}" )
			if ( post != nil )
				log( " - post data:" )
				post.each { |key, val| log( "    - #{key}: #{val}" ) }
			end
			log( "Fetching suggestions page... ", 0 )
		end
		response = post ? HTTP.fetch_page_post( url, post ) : HTTP.fetch_page_get( url )
		if ( log?() )
			if ( response && response.body() )
				log( 'OK' )
				log( response.body(), 2 ) if ( long_log?() )
			else
				log( 'ERROR' )
			end
		end
		return response ? response.body() : nil
	end

	# Returns an array of maps { url, artist, title }
	def parse_suggestions( url, body, artist, title, album=nil, year=nil )
		notify( 'warning: falling back to default (stub) implementation for parse_suggestions' )
		return []
	end

	# Returns an array of maps { url, artist, title }
	def suggestions( artist, title, album=nil, year=nil )

		if ( log?() )
			log( script_name().upcase() )
			log( 'Retrieving SUGGESTIONS...' )
			log( " - received artist: #{artist}" )
			log( " - received title: #{title}" )
			log( " - received album: #{album}" ) if ( album )
			log( " - received year: #{year}" ) if ( year )
		end

		fetch_data = build_suggestions_fetch_data( artist, title, album, year )
		page_body = fetch_suggestions_page( fetch_data['url'], fetch_data['params'] )
		return [] if ( page_body == nil )

		log( 'Parsing suggestions...', 0 ) if ( log?() )
		suggestions = parse_suggestions( fetch_data['url'], page_body, artist, title, album, year )

		suggestions = [] if ( ! suggestions.is_a?( Array ) )
 		if ( log?() )
			if ( suggestions.size > 0 )
				log( '' )
				suggestions.each(){ |sugg| log( " - art: #{sugg['artist']} | tit: #{sugg['title']} | url: #{sugg['url']}" ) }
			else
				log( ' NO SUGGESTIONS FOUND' )
			end
		end

		return suggestions
	end

	# Returns { lyrics, artist, title, album, year, url, site, suggestions, custom_data }
	def on_lyrics_not_found( artist, title, album, year )
		return normalize_lyrics_data( {}, artist, title, album, year )
	end

	def lyrics_from_suggestions( artist, title, album=nil, year=nil, suggestions=nil )

		if ( log?() )
			log( script_name().upcase() )
			log( 'Searching LYRICS FROM SUGGESTIONS...' )
		end

		normalized_artist = Strings.normalize_token( artist )
		normalized_title = Strings.normalize_token( title )
		suggestions = suggestions( artist, title, album, year ) if ( suggestions == nil )
		log( 'Scanning suggestions... ', 0 ) if ( log?() )
		suggestions.each() do |sugg|
			next if ( sugg.class != Hash )
			if ( Strings.normalize_token( sugg['artist'] ) == normalized_artist &&
				 Strings.normalize_token( sugg['title'] ) == normalized_title )
				if ( log?() )
					log( 'MATCH FOUND' )
					log( " - art: #{sugg['artist']} | tit: #{sugg['title']} | url: #{sugg['url']}" )
				end
				lyrics_data = lyrics_from_url( sugg['url'], sugg['artist'], sugg['title'], album, year )
				if ( lyrics_data['lyrics'] != nil )
					lyrics_data['suggestions'] = suggestions
					return normalize_lyrics_data( lyrics_data, artist, title, album, year, sugg['url'], lyrics_site() )
				end
			end
		end
		log( 'NO MATCH FOUND' ) if ( log?() )
		return normalize_lyrics_data( { 'suggestions' => suggestions }, artist, title, album, year )
	end

	# Returns { lyrics, artist, title, album, year, url, site, suggestions, custom_data }
	def lyrics_full_search( artist, title, album=nil, year=nil )

		# LYRICS DIRECT SEARCH:
		lyrics_data = lyrics_direct_search( artist, title, album, year )
		return lyrics_data if ( lyrics_data['lyrics'] != nil )

		# NOT FOUND, SEARCH IN SUGGESTIONSFETCH BY SUGGESTIONS:
		suggests = suggestions( artist, title, album, year )
		lyrics_data = lyrics_from_suggestions( artist, title, album, year, suggests )
		return lyrics_data if ( lyrics_data['lyrics'] != nil )

		# NOT FOUND, TRY OTHER METHODS
		lyrics_data = on_lyrics_not_found( artist, title, album, year )
		suggests.insert( 0, script_name() ) if ( lyrics_data['suggestions'].size > 0 )
		suggests << 'other'
		lyrics_data['suggestions'] = suggests.concat( lyrics_data['suggestions'] )
		return lyrics_data
	end

	def build_google_feeling_lucky_url( artist, title=nil )
		lyrics = title ? 'lyrics ' : ''
		artist = Strings.google_search_quote( artist )
		title  = Strings.google_search_quote( title.to_s() )
		Strings.build_google_feeling_lucky_url( "#{lyrics} #{artist} #{title}", lyrics_site() )
	end

end
