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

module GUI

	@@toolkits = []

	def GUI.set_toolkit_priority( toolkits )
		toolkits.each() do |toolkit|
			if ( @@toolkits.include?( toolkit ) )
				# check if the toolkit is already loaded (and change it's priority)
				@@toolkits.delete( toolkit )
				@@toolkits.insert( 0, toolkit )
				return toolkit
			elsif ( GUI.load_toolkit( toolkit ) ) # try to load the toolkit
				@@toolkits.insert( 0, toolkit )
				return toolkit
			end
		end
		return GUI.get_preferred_toolkit()
	end

	def GUI.load_toolkit( toolkit )
		toolkit = toolkit.downcase()
		if ( toolkit == 'qt' )
			begin
				return require( 'gui-qt' )
			rescue LoadError
				$stderr << "Qt bindings not found\n"
			end
		elsif ( toolkit == 'gtk' )
			begin
				return require( 'gui-gtk' )
			rescue LoadError
				$stderr << "GTK bindings not found\n"
			end
		elsif ( toolkit == 'tk' )
			begin
				return require( 'gui-tk' )
			rescue LoadError
				$stderr << "Tk bindings not found\n"
			end
		end
		return false
	end

	def GUI.get_preferred_toolkit()
		return @@toolkits.length > 0 ? @@toolkits[0].downcase() : nil
	end

	def GUI.show_dialog( dlg_construct, *args )

		pref_toolkit = GUI.get_preferred_toolkit()
		if ( pref_toolkit == 'qt' )
			app = Qt::Application.new( ARGV )
			dialog = eval( 'QT::' + dlg_construct )
			app.setMainWidget( dialog )
			app.mainWidget.show()
			app.exec()
		elsif ( pref_toolkit == 'gtk' )
			dialog = eval( 'GTK::' + dlg_construct )
			dialog.exec()
			Gtk.main()
		elsif ( pref_toolkit == 'tk' )
			dialog = eval( 'TK::' + dlg_construct )
			dialog.exec()
		end

		if ( pref_toolkit == nil )
			return nil
		elsif dialog.accepted()
			return dialog.values()
		else
			return nil
		end

	end

	def GUI.show_meta_lyrics_config_dialog( values )
		ret = GUI.show_dialog( 'MetaLyricsConfigDialog.new( args[0] )', values )
		values.update( ret ) if ( ret != nil )
		return ret != nil
	end

	def GUI.show_wikilyrics_config_dialog( values )
		values['script_name'] = 'WikiLyrics' if ( ! values.include?( 'script_name' ) )
		ret = GUI.show_dialog( 'WikiLyricsConfigDialog.new( args[0] )', values )
		values.update( ret ) if ( ret != nil )
		return ret != nil
	end

	def GUI.show_wikilyrics_submit_song_dialog( values )
		values['year'] = values['year'].to_i()
		values['script_name'] = 'WikiLyrics' if ( ! values.include?( 'script_name' ) )
		ret = GUI.show_dialog( 'WikiLyricsSubmitSongDialog.new( args[0] )', values )
		values.update( ret ) if ( ret != nil )
		return ret != nil
	end

	def GUI.show_wikilyrics_submit_album_dialog( values )
		values['released'] = values['released'].to_s()
		values['script_name'] = 'WikiLyrics' if ( ! values.include?( 'script_name' ) )
		ret = GUI.show_dialog( 'WikiLyricsSubmitAlbumDialog.new( args[0] )', values )
		values.update( ret ) if ( ret != nil )
		return ret != nil
	end

	def GUI.show_upload_cover_dialog( values )
		values['script_name'] = 'WikiLyrics' if ( ! values.include?( 'script_name' ) )
		values['year'] = values['year'].to_i()
		ret = GUI.show_dialog( 'UploadCoverDialog.new( args[0] )', values )
		values.update( ret ) if ( ret != nil )
		return ret != nil
	end

	def GUI.show_lyrixat_config_dialog( values )
		ret = GUI.show_dialog( 'LyrixAtConfigDialog.new( args[0] )', values )
		values.update( ret ) if ( ret != nil )
		return ret != nil
	end

	def GUI.show_search_lyrics_dialog( values )
		values['year'] = values['year'].to_i()
		ret = GUI.show_dialog( 'SearchLyricsDialog.new( args[0] )', values )
		values.update( ret ) if ( ret != nil )
		return ret != nil
	end

	def GUI.show_lyrics_dialog( lyrics )
		GUI.show_dialog( 'LyricsDialog.new( args[0] )', lyrics )
	end

	def GUI.show_message_dialog( message, title=nil )
		if ( title )
			system( 'kdialog', '--icon', 'amarok', '--title', title, '--msgbox', '<qt>' + message.gsub( "\n", '<br/>' ) + '</qt>' )
		else
			system( 'kdialog', '--icon', 'amarok', '--msgbox', '<qt>' + message.gsub( "\n", '<br/>' ) + '</qt>' )
		end
	end

	def GUI.show_confirmation_dialog( message, title=nil )
		if ( title )
			system( 'kdialog', '--icon', 'amarok', '--title', title, '--yesno', '<qt>' + message.gsub( "\n", '<br/>' ) + '</qt>' )
		else
			system( 'kdialog', '--icon', 'amarok', '--yesno', '<qt>' + message.gsub( "\n", '<br/>' ) + '</qt>' )
		end
		return $? == 0
	end

end

if ( $0 == __FILE__ )
# 	['qt', 'gtk', 'tk'].each() do |toolkit|
	['tk'].each() do |toolkit|

		GUI.set_toolkit_priority( toolkit )

		values = { 'script'=>'Lyriki', 'used_scripts'=>['used1', 'used2', 'used3', 'used4'], 'unused_scripts'=>['unused1', 'unused2'], 'cleanup_lyrics'=>'true' }
		puts GUI.show_meta_lyrics_config_dialog( values )
		values.each() { |key, val| puts "#{key}: #{val}" }

		values = { 'username'=>'username', 'password'=>'password'}
		puts GUI.show_lyrixat_config_dialog( values )
		values.each() { |key, val| puts "#{key}: #{val}" }

		values = { 'artist'=>'artist', 'title'=>'title', 'lyrics'=>'lyrícs', 'site'=>'site' }
		puts GUI.show_lyrics_dialog( values )
		values.each() { |key, val| puts "#{key}: #{val}" }

		values = { 'submit'=>'true', 'review'=>'true', 'prompt_autogen'=>'false', 'prompt_new'=>'false', 'username'=>'username', 'password'=>'password' }
		puts GUI.show_wikilyrics_config_dialog( values )
		values.each() { |key, val| puts "#{key}: #{val}" }

		values = {'url'=>'url', 'artist'=>'artist', 'year'=>'1999','album'=>'album','song'=>'song','lyrics'=>'lyrics','lyricist'=>'lyricist',
		'credits'=>'credits', 'autogen'=>'false' }
		puts GUI.show_wikilyrics_submit_song_dialog( values )
		values.each() { |key, val| puts "#{key}: #{val}" }

		values = {'url'=>'url', 'artist'=>'artist', 'released'=>'October 14, 1999','album'=>'album', 'autogen'=>'false', 'image_path'=>'image_path', 'tracks'=>'tracks <small>fffff</small>' }
		puts GUI.show_wikilyrics_submit_album_dialog( values )
		values.each() { |key, val| puts "#{key}: #{val}" }

		values = { 'artist'=>'artist', 'album'=>'album', 'year'=>'year', 'image_path' => 'image_path' }
		puts GUI.show_upload_cover_dialog( values )
		values.each() { |key, val| puts "#{key}: #{val}" }

		values = {'url'=>'url', 'artist'=>'artist', 'released'=>'October 14, 1999','album'=>'album', 'autogen'=>'false', 'tracks'=>'tracks <small>fffff</small>' }
		puts GUI.show_wikilyrics_submit_album_dialog( values )
		values.each() { |key, val| puts "#{key}: #{val}" }

		values = { 'artist'=>'artist', 'title'=>'title', 'album'=>'album', 'year'=>'year' }
		puts GUI.show_search_lyrics_dialog( values )
		values.each() { |key, val| puts "#{key}: #{val}" }

	end
end