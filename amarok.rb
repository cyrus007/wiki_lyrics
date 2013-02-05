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
require 'rexml/document'
require 'md5'

module Amarok

	@@menues = {}
	@@images_folder = "#{ENV['HOME']}/.kde/share/apps/amarok/albumcovers/large/"

	def Amarok.notify( content )
		return system( 'dcop', 'amarok', 'playlist', 'shortStatusMessage', content )
	end

	def Amarok.popup( content )
		return system( 'dcop', 'amarok', 'playlist', 'popupMessage', content.gsub( "\n", '<br/>' ) )
	end

	# show given text or xml in amarok's lyrics tab
	def Amarok.show_in_lyricstab( content )
		if content.class == REXML::Document
			aux = ''
			content.write( aux )
			content = aux
		end
		return system( 'dcop', 'amarok', 'contextbrowser', 'showLyrics', content )
	end

	def Amarok.build_lyrics( artist, title, lyrics, page_url=nil )
		xml = REXML::Document.new( '<?xml version=\"1.0\" encoding=\"UTF-8\" ?>' )
		root = xml.add_element( 'lyrics' )
		root.add_attribute( 'title', title.to_s() )
		root.add_attribute( 'artist', artist.to_s() )
		root.add_attribute( 'page_url', page_url ) if ( page_url != nil )
		root.text = lyrics
		aux = ''
		xml.write( aux )
		return aux
	end

	def Amarok.show_lyrics( artist, title, lyrics, page_url=nil )
		return Amarok.show_in_lyricstab( Amarok.build_lyrics( artist, title, lyrics, page_url ) )
	end

	def Amarok.build_suggestions( artist, title, suggestions )
		xml = REXML::Document.new( '<?xml version=\"1.0\" encoding=\"UTF-8\" ?>' )
		root = xml.add_element( 'suggestions' )
		hint = ''
		suggestions.each() do |sugg|
			if ( sugg.class == String )
				hint = "#{sugg} - " if ( ! Strings.empty?( sugg ) )
				next
			end
			suggestion = root.add_element( 'suggestion' )
			suggestion.add_attribute( 'url', sugg['url'] )
			suggestion.add_attribute( 'artist', "#{hint}#{sugg['artist']}" )
			suggestion.add_attribute( 'title', sugg['title'] )
		end
		aux = ''
		xml.write( aux )
		return aux
	end

	def Amarok.show_suggestions( artist, title, suggestions )
		return Amarok.show_in_lyricstab( Amarok.build_suggestions( artist, title, suggestions ) )
	end

	def Amarok.show_not_found( artist, title )
		return Amarok.show_suggestions( artist, title, [] )
	end

	def Amarok.show_error()
		return Amarok.show_in_lyricstab( '' )
	end

	def Amarok.add_custom_menu_item( menu, item )
		menu_items = @@menues[menu]
		@@menues[menu] = menu_items = [] if ( menu_items == nil )
		menu_items.insert( -1, item ) if ( ! menu_items.include?( item ) )
		system( 'dcop', 'amarok', 'script', 'removeCustomMenuItem', menu, item )
		system( 'dcop', 'amarok', 'script', 'addCustomMenuItem', menu, item )
	end

	def Amarok.remove_custom_menu_item( menu, item )
		menu_items = @@menues[menu]
 		if ( menu_items != nil && menu_items.include?( item ) )
			menu_items.delete( item )
			@@menues.delete( menu ) if ( menu_items.size == 0 )
		end
		system( 'dcop', 'amarok', 'script', 'removeCustomMenuItem', menu, item )
	end

	def Amarok.get_custom_menu_item( menu_item_id )
		@@menues.each() do |menu, items|
			items.each() do |item|
				return menu, item if ( "#{menu} #{item}" == menu_item_id )
			end
		end
		return nil, nil
	end

	def Amarok.query( sql_query, keys=nil )
		if ( keys )
			keys_size = keys.size()
			results = []
			line_idx = 0
			`dcop amarok collection query #{Strings.shell_quote(sql_query)}`.chomp().split( "\n" ).each() do |line|
				result_idx = line_idx / keys_size
				key_idx = line_idx % keys_size
				results[result_idx] = {} if ( key_idx == 0 )
				results[result_idx][keys[key_idx]] = line
				line_idx += 1
			end
			return results
		else
			`dcop amarok collection query #{Strings.shell_quote(sql_query)}`
			return nil
		end
	end

	def Amarok.query_collection_url( file )
		root_rs = Amarok.query( "SELECT DISTINCT lastmountpoint FROM devices", ['root'] )
		return nil if ( root_rs.size == 0 )
		root_rs.each() do |root_r|
			if ( file.index( root_r['root'] ) == 0 )
				url = ".#{root_r['root'] == '/' ? file : file.slice( root_r['root'].size..-1 ) }"
				url_rs = Amarok.query( "SELECT url FROM tags WHERE url=#{Strings.sql_quote(url)}", ['url'] )
				return url if url_rs.size == 1
			end
		end
		return nil
	end

	def Amarok.get_cover_file( artist, album )
		md5sum = MD5.hexdigest( "#{Strings.downcase( artist )}#{Strings.downcase( album )}" )
		return FileTest.exist?( "#{@@images_folder}#{md5sum}" ) ? "#{@@images_folder}#{md5sum}" : nil
	end

	def Amarok.playing?()
		return `dcop amarok player isPlaying`.strip() == 'true'
	end

	def Amarok.get_current_url()
		url = `dcop amarok player encodedURL`.strip()
		return url == '' ? nil : url
	end

	def Amarok.get_current_artist()
		artist = `dcop amarok player artist`.strip()
		return artist == '' ? nil : artist
	end

	def Amarok.get_current_title()
		title = `dcop amarok player title`.strip()
		return title == '' ? nil : title
	end

	def Amarok.get_current_album()
		album = `dcop amarok player album`.strip()
		return album == '' ? nil : album
	end

	def Amarok.get_current_year()
		year = `dcop amarok player year`.strip()
		return year.to_i() <= 1900 ? nil : year.to_i()
	end

end
