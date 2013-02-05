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
require 'amarok'
require 'metalyrics'
require 'cgi'
require 'thread'

TOOLKIT_PRIORITY = ['qt', 'gtk', 'tk']

module AmarokMetaLyrics

	# Hack to make module methods become class methods when the module gets included
	def AmarokMetaLyrics.included( including )
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

		def notify( message )
			Amarok.notify( '<b>[' + script_name() + ']</b> ' + message.gsub( "\n", ' ' ) )
		end

		def popup( message )
			Amarok.popup( '<b>[' + script_name() + ']</b><br/>' + message )
		end

		def add_amarok_menu_item( menu_item )
			Amarok.add_custom_menu_item( script_name(), menu_item )
		end

		def remove_amarok_menu_item( menu_item )
			Amarok.remove_custom_menu_item( script_name(), menu_item )
		end
	end

	include MetaLyrics

	@@MENU_ENTRY_SEARCH_CURRENT = 'Search current song lyrics'
	@@MENU_ENTRY_CLEAR_LYRICS_CACHE = 'Clear lyrics cache'

	def notify( message )
		self.class.notify( message )
	end

	def popup( message )
		self.class.popup( message )
	end

	def add_amarok_menu_item( menu_item )
		self.class.add_amarok_menu_item( menu_item )
	end

	def remove_amarok_menu_item( menu_item )
		self.class.remove_amarok_menu_item( menu_item )
	end

	def show_lyrics_full_search( artist, title, album, year )

		# NOTE: we must check that the current song doesn't change while we're fetching
		# the lyrics, otherwise Amarok will associate the lyrics with the wrong song
		prev_artist = Strings.normalize_token!( Amarok.get_current_artist().to_s() )
		prev_title  = Strings.normalize_token!( Amarok.get_current_title().to_s() )

		lyrics_data = lyrics_full_search( artist, title, album, year )

		return if ( Strings.normalize_token!( Amarok.get_current_artist().to_s() ) != prev_artist ||
					Strings.normalize_token!( Amarok.get_current_title().to_s() ) != prev_title )

		if ( lyrics_data['lyrics'] != nil )
			Amarok.show_lyrics( lyrics_data['artist'], lyrics_data['title'], (@cleanup_lyrics ? "\n" : '') + lyrics_data['lyrics'], lyrics_data['url'] )
		elsif ( lyrics_data['suggestions'] != nil )
			Amarok.show_suggestions( lyrics_data['artist'], lyrics_data['title'], lyrics_data['suggestions'] )
		else
			Amarok.show_not_found( lyrics_data['artist'], lyrics_data['title'] )
		end

	end

	def show_lyrics_from_url( url, artist, title, album, year )

		# NOTE: we must check that the current song doesn't change while we're fetching
		# the lyrics, otherwise Amarok will associate the lyrics with the wrong song
		prev_artist = Strings.normalize_token!( Amarok.get_current_artist().to_s() )
		prev_title  = Strings.normalize_token!( Amarok.get_current_title().to_s() )

		lyrics_data = lyrics_from_url( url, artist, title, album, year )

		return if ( Strings.normalize_token!( Amarok.get_current_artist().to_s() ) != prev_artist ||
					Strings.normalize_token!( Amarok.get_current_title().to_s() ) != prev_title )

		if ( lyrics_data['lyrics'] != nil )
			Amarok.show_lyrics( lyrics_data['artist'], lyrics_data['title'], (@cleanup_lyrics ? "\n" : '') + lyrics_data['lyrics'], lyrics_data['url'] )
		else
			Amarok.show_not_found( lyrics_data['artist'], lyrics_data['title'] )
		end
	end

	def on_start()
		read_config( false )
		add_amarok_menu_item( @@MENU_ENTRY_SEARCH_CURRENT )
		add_amarok_menu_item( @@MENU_ENTRY_CLEAR_LYRICS_CACHE )
	end

	def on_quit()
		remove_amarok_menu_item( @@MENU_ENTRY_SEARCH_CURRENT )
		remove_amarok_menu_item( @@MENU_ENTRY_CLEAR_LYRICS_CACHE )
	end

	def on_configure()
		read_config( true )
	end

	def on_fetch_lyrics( artist, title, album, year )
		show_lyrics_full_search( artist, title, album, year )
	end

	def on_fetch_lyrics_from_url( url, artist, title, album, year )
		show_lyrics_from_url( url, artist, title, album, year )
	end

	def on_custom_menu_item_selected( menu, item, urls )
		return if ( menu != script_name() )
		if ( item == @@MENU_ENTRY_SEARCH_CURRENT )
			if ( Amarok.playing?() )
				values = {
					'artist' => Amarok.get_current_artist().to_s(),
					'title'  => Amarok.get_current_title().to_s(),
					'album'  => Amarok.get_current_album(),
					'year'   => Amarok.get_current_year(),
				}
				if ( GUI.show_search_lyrics_dialog( values ) )
					show_lyrics_full_search( values['artist'], values['title'], values['album'], values['year'] )
				end
			else
				notify( "No song currently playing" )
			end
		elsif ( item == @@MENU_ENTRY_CLEAR_LYRICS_CACHE )
			if ( GUI.show_confirmation_dialog( 'Are you sure you want to clear the lyrics cache?', script_name() ) )
				Amarok.query( "DELETE FROM lyrics WHERE url <> ''" )
				notify( 'lyrics cache cleared' )
			end
		end
	end

	def set_configure_msg()
		@mutex.synchronize do
			# prioritize configure messages:
			if ( @messages[0] != 'configure' )
				@messages.insert( 0, 'configure' )
			end
			@queued_cond.signal()
		end
	end
	protected :set_configure_msg

	def set_generic_msg( command )
		@mutex.synchronize do
			# we queue only two messages to try to stay in synch with Amarok current track
			@messages[@messages.size < 2 ? @messages.size : 1 ] = command
			@queued_cond.signal()
		end
	end
	protected :set_generic_msg

	def get_msg()
		@mutex.synchronize do
			@queued_cond.wait( @mutex ) if ( @messages.empty?() )
			return @messages.shift()
		end
	end
	protected :get_msg

	def main()
		@mutex = Mutex.new()
		@queued_cond  = ConditionVariable.new()
		@messages = []

		Logging.reset( log_file() ) if ( log?() )

		exit_code = 0

		a = Thread.new() do
			begin
				on_start()
				run_worker()
			rescue Exception => e
				if ( e.is_a?( Errno::ECONNREFUSED ) )
					popup( 'Can\'t connect to the Internet (check your proxy settings).' )
				elsif ( e.is_a?( SocketError ) || e.is_a?( Errno::ETIMEDOUT ) )
					popup( 'The connection is down, exiting.' )
				else # unexpected error
					$stderr << e.message() << "\n"
					$stderr << e.backtrace().join( "\n" )
					exit_code = 1
				end
			end
			exit( exit_code )
		end

		trap( 'SIGTERM' ) { $stderr << 'SIGTERM caugth' } # causes to fall to the Exception block below on abnormal termination
		begin
			run_stdin_listener()
		rescue Exception => e
		end
		on_quit()
		exit( exit_code )
	end

	def run_stdin_listener()
		loop do
			message = gets().chomp()
			command = /[A-Za-z]*/.match( message ).to_s()
			case command
				when 'configure'
					set_configure_msg()
				when 'fetchLyrics'
					set_generic_msg( message )
				when 'fetchLyricsByUrl'
					set_generic_msg( message )
				when 'customMenuClicked'
					set_generic_msg( message )
			end
		end
	end
	protected :run_stdin_listener

	def run_worker()
		loop do
			message = get_msg()
			return if ( message == nil )
			command = /[A-Za-z]*/.match( message ).to_s()
			case command
				when 'configure'
					on_configure()
				when 'fetchLyrics'
					args = message.split()
					if args.length < 2
						Amarok.show_error()
					else 
						artist = Amarok.get_current_artist().to_s()
						title  = Amarok.get_current_title().to_s()
						if artist.empty? 
							tmpartist, tmptitle = title.split( '-' )
							if tmptitle == nil
								title = tmpartist; artist = '';
							else
								title = tmptitle; artist = tmpartist;
							end
                                                end
						on_fetch_lyrics(
							Strings.cleanup_artist( artist, title ),
							Strings.cleanup_title( title ),
							Amarok.get_current_album(),
							Amarok.get_current_year()
						)
					end
				when 'fetchLyricsByUrl'
					args = message.split()
					if args.length < 2
						Amarok.show_error()
					else
						artist = Amarok.get_current_artist().to_s()
						title  = Amarok.get_current_title().to_s()
						on_fetch_lyrics_from_url(
							args[1],
							Strings.cleanup_artist( artist, title ),
							Strings.cleanup_title( title ),
							Amarok.get_current_album(),
							Amarok.get_current_year()
						)
					end
				when 'customMenuClicked'
					urls_start = message.index( /([a-zA-Z]+:\/\/[^: ]+){1,}/ )
					return if ( urls_start == nil )
					menu_id = message.slice( 'customMenuClicked:'.size()+1..urls_start-2 )
					menu, item = Amarok.get_custom_menu_item( menu_id )
					if ( menu != nil && item != nil )
						urls = message.slice( urls_start..-1 ).split( ' ' )
						on_custom_menu_item_selected( menu, item, urls )
					end
			end
		end
	end
	protected :run_worker

end

if ( GUI.set_toolkit_priority( TOOLKIT_PRIORITY ) == nil )
	Amarok.popup( "<b>[Lyriki-Lyrics]</b><br/>Sorry...\nYou need one of QtRuby, RubyGTK or TkRuby to run this program" )
	exit( 0 )
end

proxy_url, excluded_urls, reverse = KDE.get_proxy_settings()
HTTP.set_proxy_settings( proxy_url, excluded_urls, reverse )
