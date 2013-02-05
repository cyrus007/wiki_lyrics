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
require 'wikilyricssubmitter'
require 'amarokmetalyrics'
require 'amarok'
require 'utils'
require 'gui'

module AmarokWikiLyrics

	# Hack to make module methods become class methods when the module gets included
	def AmarokWikiLyrics.included( including )
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

	include AmarokMetaLyrics
	include WikiLyricsSubmitter

	@@MENU_ENTRY_ALBUM  = 'Check album page'
	@@MENU_ENTRY_SONG   = 'Check song page'
	@@MENU_UPLOAD_COVER = 'Upload album cover'

	def read_config( force_prompt, restore_session=false )
		super( force_prompt )
		values = {
			'submit'			=> @submit,
			'review'			=> @review,
			'prompt_autogen'	=> @prompt_autogen,
			'prompt_new'		=> @prompt_new,
			'username'			=> @username,
			'password'			=> @password
		}
		if ( read = XMLHash.read( config_file, values ) )
			@review = values['review'].to_s() != 'false'
			@submit = values['submit'].to_s() == 'true'
			@prompt_autogen = values['prompt_autogen'].to_s() == 'true'
			@prompt_new = values['prompt_new'].to_s() == 'true'
			values['username'] = Strings.descramble( values['username'] )
			values['password'] = Strings.descramble( values['password'] )
		end
		if ( !read || force_prompt )
			if ( GUI.show_wikilyrics_config_dialog( values ) )
				@review = values['review'].to_s() != 'false'
				@submit = values['submit'].to_s() == 'true'
				@prompt_autogen = values['prompt_autogen'].to_s() == 'true'
				@prompt_new = values['prompt_new'].to_s() == 'true'
			end
			values['username'] = Strings.scramble( values['username'] )
			values['password'] = Strings.scramble( values['password'] )
			XMLHash.save( config_file, values )
			values['username'] = Strings.descramble( values['username'] )
			values['password'] = Strings.descramble( values['password'] )
		end

		if ( !@submit || !@review )
			@prompt_new = false
			@prompt_autogen = false
		end

 		if ( @submit )
			restore_session( config_file, values['username'], values['password'] ) if ( restore_session )
			login( values['username'], values['password'] )
		end

		self.submit = false if ( ! @logged_in )
	end

	def on_start()
		read_config( false, true )
		add_amarok_menu_item( @@MENU_ENTRY_SEARCH_CURRENT )
		add_amarok_menu_item( @@MENU_ENTRY_CLEAR_LYRICS_CACHE )
		if ( @submit && logged_in?() )
			add_amarok_menu_item( @@MENU_UPLOAD_COVER )
			add_amarok_menu_item( @@MENU_ENTRY_ALBUM )
			add_amarok_menu_item( @@MENU_ENTRY_SONG )
		end
	end

	def on_quit()
		super()
		remove_amarok_menu_item( @@MENU_UPLOAD_COVER )
		remove_amarok_menu_item( @@MENU_ENTRY_ALBUM )
		remove_amarok_menu_item( @@MENU_ENTRY_SONG )
		save_session( config_file ) if ( @logged_in )
	end

	def on_configure()
		read_config( true, false )
		remove_amarok_menu_item( @@MENU_UPLOAD_COVER )
		remove_amarok_menu_item( @@MENU_ENTRY_ALBUM )
		remove_amarok_menu_item( @@MENU_ENTRY_SONG )
		if ( @submit && logged_in?() )
			add_amarok_menu_item( @@MENU_UPLOAD_COVER )
			add_amarok_menu_item( @@MENU_ENTRY_ALBUM )
			add_amarok_menu_item( @@MENU_ENTRY_SONG )
		end
	end

	def on_custom_menu_item_selected( menu, item, urls )
		return if ( menu != script_name() )
		if ( item == @@MENU_UPLOAD_COVER )
			url = URI.parse( urls[0] )
			upload_album_cover( url.scheme == 'file' ? URI.decode( url.path ) : nil)
		elsif ( item == @@MENU_ENTRY_ALBUM )
			url = URI.parse( urls[0] )
			return if ( url.scheme != 'file' )
			check_album_page( URI.decode( url.path ) )
		elsif ( item == @@MENU_ENTRY_SONG )
			urls.each() do |url|
				# TODO add skip dialog, show remaining
				url = URI.parse( url )
				return if ( url.scheme != 'file' )
				check_song_page( URI.decode( url.path ) )
			end
		else
			super( menu, item, urls )
		end
	end


	# Amarok database tables:
	# =======================
	# - tags:     url dir album artist composer genre title year comment track discnumber length deviceid
	# - devices:  id lastmountpoint
	# - artist:   id name
	# - album:    id name
	# - composer: id name
	# - genre:    id name
	# - year:     id name

	def check_album_page( file )

		url = Amarok.query_collection_url( file )
		if ( url == nil )
			notify( "no album info found in Amarok database" )
			return
		end

		sql_rs = Amarok.query( "SELECT album, year FROM tags WHERE url=#{Strings.sql_quote(url)}", ['album_id', 'year_id'] )

		album = Amarok.query( "SELECT name FROM album WHERE id=#{sql_rs[0]['album_id']}", ['album'] )[0]['album']
		year = Amarok.query( "SELECT name FROM year WHERE id=#{sql_rs[0]['year_id']}", ['year'] )[0]['year']

		sql_query = "SELECT tags.discnumber, artist.name, tags.title, tags.length " \
					"FROM tags, artist " \
					"WHERE tags.album=#{sql_rs[0]['album_id']} AND tags.year=#{sql_rs[0]['year_id']} AND artist.id=tags.artist " \
					"ORDER BY tags.discnumber, tags.track"
		tracks = Amarok.query( sql_query, ['disc', 'artist', 'title', 'length'] )

		if ( tracks.size < 1 ) # can't even attempt to find the album...
			notify( "no album info found in Amarok database" )
		else
			tracks_data = Lyriki.parse_tracks( tracks )
			if ( find_album_page_url( tracks_data['artist'], album, year ) != nil )
				notify( "found page for <i>#{album}</i> by <i>#{tracks_data['artist']}</i>" )
			else
				notify( "no page found for <i>#{album}</i> by <i>#{tracks_data['artist']}</i>" )
				submit_album_page( album, year, tracks, Amarok.get_cover_file( tracks_data['artist'], album ) )
			end
		end

	end

	def upload_album_cover( file )

		album_data = { 'script_name' => script_name(), 'artist' => '', 'album' => '', 'year'=> '' }

		url = file ? Amarok.query_collection_url( file ) : nil
		if ( url != nil )

			sql_rs = Amarok.query( "SELECT album, year FROM tags WHERE url=#{Strings.sql_quote(url)}", ['album_id', 'year_id'] )

			album_data['album'] = Amarok.query( "SELECT name FROM album WHERE id=#{sql_rs[0]['album_id']}", ['album'] )[0]['album']
			album_data['year'] = Amarok.query( "SELECT name FROM year WHERE id=#{sql_rs[0]['year_id']}", ['year'] )[0]['year']

			sql_query = "SELECT tags.discnumber, artist.name, tags.title, tags.length " \
						"FROM tags, artist " \
						"WHERE tags.album=#{sql_rs[0]['album_id']} AND tags.year=#{sql_rs[0]['year_id']} AND artist.id=tags.artist " \
						"ORDER BY tags.discnumber, tags.track"
			tracks = Amarok.query( sql_query, ['disc', 'artist', 'title', 'length'] )
			tracks_data = Lyriki.parse_tracks( tracks )

			album_data['artist'] = tracks_data['artist'].to_s()
		end

		album_data['image_path'] = Amarok.get_cover_file( album_data['artist'], album_data['album'] )

		if ( GUI::show_upload_cover_dialog( album_data ) )

			album_data['year'] = album_data['year'].to_s()
			if ( Strings.empty?( album_data['artist'] ) || Strings.empty?( album_data['album'] ) ||
				 Strings.empty?( album_data['year'] ) )
				notify( 'invalid album params received' )
				return
			elsif ( Strings.empty?( album_data['image_path'] ) )
				notify( 'no cover image selected' )
				return
			end

			if ( ! find_album_art_name( album_data['artist'], album_data['album'], album_data['year'] ) )
				album_art_name = build_album_art_name( album_data['artist'], album_data['album'], album_data['year'] )
				album_art_desc = build_album_art_description( album_data['artist'], album_data['album'], album_data['year'] )
				image_path, mime_type = prepare_image_file( album_data['image_path'] )

				if ( Strings.empty?( image_path ) || Strings.empty?( mime_type ) )
					notify( 'there was an error converting the album cover to JPEG format' )
				elsif ( upload_file( image_path, album_art_name, mime_type, album_art_desc ) )
					notify( "uploaded album cover for <i>#{album_data['album']}</i> by <i>#{album_data['artist']}</i>" )
				else
					notify( 'there was an error uploading the album cover' )
				end
			else
				notify( 'album cover found, it won\'t be uploaded' )
			end

		end

	end

	def check_song_page( file )

		url = Amarok.query_collection_url( file )
		if ( url == nil )
			notify( "no song info found in Amarok database" )
			return
		end

		sql_rs = Amarok.query(	"SELECT artist.name, tags.title, album.name, year.name " \
								"FROM tags,artist,album,year " \
								"WHERE url=#{Strings.sql_quote(url)} AND artist.id=tags.artist AND album.id=tags.album AND year.id=tags.year",
								['artist','title','album','year'] )

		if ( sql_rs.size != 1 )
			notify( "no song info found in Amarok database" )
		else
			artist = Strings.cleanup_artist( sql_rs[0]['artist'], sql_rs[0]['title'] )
			title  = Strings.cleanup_title( sql_rs[0]['title'] )
			lyrics_full_search( artist, title, sql_rs[0]['album'], sql_rs[0]['year'], true )
		end

	end

end
