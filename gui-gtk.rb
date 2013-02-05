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
require 'date'
require 'gtk2'

Gtk.init()

module GTK

	class BaseDialog < Gtk::Window

		attr_reader :accepted
		attr_reader :values

		def initialize( values, close_on_escape=true )
			super()
			@values = values
			set_window_position( Gtk::Window::POS_CENTER )
			signal_connect( 'destroy' ) { Gtk.main_quit() }

			if ( close_on_escape )
				self.signal_connect( 'key_press_event' ) do |widget, event|
					if ( event.keyval == Gdk::Keyval::GDK_Escape )
						destroy()
					end
				end
			end
		end

		def create_action_buttons( mode='right', accept_text='Accept', cancel_text='Cancel' )
			accept_text = Strings.empty?( accept_text ) ? 'Accept' : accept_text
			cancel_text = Strings.empty?( cancel_text ) ? 'Cancel' : cancel_text
			@accept_button = Gtk::Button.new( accept_text )
			@cancel_button = Gtk::Button.new( cancel_text )
			@accept_button.signal_connect( 'clicked' ) { accept() }
			@cancel_button.signal_connect( 'clicked' ) { destroy() }
			if ( mode == 'left' )
				hbox = Gtk::HButtonBox.new();
				hbox.layout_style = Gtk::ButtonBox::START
				hbox.add( @accept_button )
				hbox.add( @cancel_button )
			elsif ( mode == 'split' )
				hbox = Gtk::HBox.new();
				hbox.pack_start( @accept_button )
				hbox.pack_start( @cancel_button )
			else
				hbox = Gtk::HButtonBox.new();
				hbox.layout_style = Gtk::ButtonBox::END
				hbox.add( @accept_button )
				hbox.add( @cancel_button )
			end
			return hbox
		end
		protected :create_action_buttons

		def exec()
			@accepted = false
			set_modal( true )
			show_all()
		end

		def accept()
			@accepted = true
			destroy()
		end

	end

	class MetaLyricsConfigDialog < BaseDialog

		def initialize( values )
			super( values )

			set_border_width( 5 )
			set_resizable( true )

			set_title( @values['script'] + ' script configuration' )

			vbox = Gtk::VBox.new( false, 3 );
			add( vbox )

			group = Gtk::Frame.new( 'Scripts priority' )
			vbox.pack_start( group, true )

			@used_scripts_store = Gtk::ListStore.new( String )
			@used_scripts_view = Gtk::TreeView.new( @used_scripts_store )
			column = Gtk::TreeViewColumn.new( 'Currently used', Gtk::CellRendererText.new(), :text => 0 )
			@used_scripts_view.append_column( column )
			used_scripts_viewport = Gtk::Viewport.new(
				@used_scripts_view.focus_hadjustment(),
				@used_scripts_view.focus_vadjustment()
			)
			used_scripts_viewport.set_shadow_type( Gtk::SHADOW_IN )
			used_scripts_viewport.add( @used_scripts_view )
			used_scripts_scrolledwindow = Gtk::ScrolledWindow.new()
			used_scripts_scrolledwindow.add( used_scripts_viewport )
			@values['used_scripts'].each() do |script|
				iter = @used_scripts_store.append()
				@used_scripts_store.set_value( iter, 0, script )
			end

			@unused_scripts_store = Gtk::ListStore.new( String )
			@unused_scripts_view = Gtk::TreeView.new( @unused_scripts_store )
			column = Gtk::TreeViewColumn.new( 'Available', Gtk::CellRendererText.new(), :text => 0 )
			@unused_scripts_view.append_column( column )
			unused_scripts_viewport = Gtk::Viewport.new(
				@unused_scripts_view.focus_hadjustment(),
				@unused_scripts_view.focus_vadjustment()
			)
			unused_scripts_viewport.set_shadow_type( Gtk::SHADOW_IN )
			unused_scripts_viewport.add( @unused_scripts_view )
			unused_scripts_scrolledwindow = Gtk::ScrolledWindow.new()
			unused_scripts_scrolledwindow.add( unused_scripts_viewport )
			@values['unused_scripts'].each() do |script|
				iter = @unused_scripts_store.append()
				@unused_scripts_store.set_value( iter, 0, script )
			end

			@move_up_button = Gtk::Button.new( 'Up' )
			@move_down_button = Gtk::Button.new( 'Down' )

			@add_button = Gtk::Button.new( '<< Add' )
			@remove_button = Gtk::Button.new( 'Remove >>' )

			group_grid = Gtk::Table.new( 4, 4, false )
			group_grid.set_row_spacings( 5 )
			group_grid.set_column_spacings( 5 )
			group.add( group_grid )

			group_grid.attach( @move_up_button, 0, 1, 1, 2, Gtk::FILL, 0 )
			group_grid.attach( @move_down_button, 0, 1, 2, 3, Gtk::FILL, 0 )

			group_grid.attach( used_scripts_scrolledwindow, 1, 2, 0, 4, Gtk::FILL|Gtk::EXPAND, Gtk::FILL|Gtk::EXPAND )

			group_grid.attach( @add_button, 2, 3, 1, 2, Gtk::FILL, 0 )
			group_grid.attach( @remove_button, 2, 3, 2, 3, Gtk::FILL, 0 )

			group_grid.attach( unused_scripts_scrolledwindow, 3, 4, 0, 4, Gtk::FILL|Gtk::EXPAND, Gtk::FILL|Gtk::EXPAND )

			group = Gtk::Frame.new( 'Miscellaneous' )
			vbox.pack_start( group, false )

			group_vbox = Gtk::VBox.new( false, 0 );
			group.add( group_vbox )

			@cleanup_lyrics_checkbox = Gtk::CheckButton.new( 'Clean up retrieved lyrics' )
			@cleanup_lyrics_checkbox.set_active( values['cleanup_lyrics'].to_s() == 'true' )

			group_vbox.add( @cleanup_lyrics_checkbox )

			buttons = create_action_buttons()
			vbox.pack_start( buttons, false )

			@move_up_button.signal_connect( 'clicked' ) { move_up() }
			@move_down_button.signal_connect( 'clicked' ) { move_down() }
			@add_button.signal_connect( 'clicked' ) { add_script() }
			@remove_button.signal_connect( 'clicked' ) { remove_script() }

			set_default_size( 350, 230 )
		end


		def move_up()
			sel_iter = @used_scripts_view.selection().selected()
			return if ( sel_iter == nil || sel_iter == @used_scripts_store.iter_first() )
			sel_path = sel_iter.path()
			script = sel_iter.get_value( 0 )
			@used_scripts_store.remove( sel_iter )
			sel_path.prev!()
			prev_iter = @used_scripts_store.get_iter( sel_path )
			iter = @used_scripts_store.insert_before( prev_iter )
			@used_scripts_store.set_value( iter, 0, script )
			@used_scripts_view.selection().select_iter( iter )
		end

		def move_down()
			sel_iter = @used_scripts_view.selection().selected()
			return if ( sel_iter == nil )
			script = sel_iter.get_value( 0 )
			sel_path = sel_iter.path()
			return if ( !sel_iter.next!() )
			next_iter = sel_iter
			iter = @used_scripts_store.insert_after( next_iter )
			@used_scripts_store.set_value( iter, 0, script )
			@used_scripts_store.remove( @used_scripts_store.get_iter( sel_path ) )
			@used_scripts_view.selection().select_iter( iter )
		end

		def add_script()
			unused_sel_iter = @unused_scripts_view.selection().selected()
			return if ( unused_sel_iter == nil )
			script = unused_sel_iter.get_value( 0 )
			@unused_scripts_store.remove( unused_sel_iter )
			iter = @used_scripts_store.append()
			@used_scripts_store.set_value( iter, 0, script )
			@used_scripts_view.selection().select_iter( iter )
		end

		def remove_script()
			used_sel_iter = @used_scripts_view.selection().selected()
			return if ( used_sel_iter == nil )
			script = used_sel_iter.get_value( 0 )
			@used_scripts_store.remove( used_sel_iter )
			iter = @unused_scripts_store.append()
			@unused_scripts_store.set_value( iter, 0, script )
			@unused_scripts_view.selection().select_iter( iter )
		end

		def accept()
			@values = {
				'script' => @values['script'],
				'cleanup_lyrics' => @cleanup_lyrics_checkbox.active?(),
				'used_scripts' => [],
				'unused_scripts' => []
			}
			iter = @used_scripts_store.iter_first()
			while ( iter != nil )
				@values['used_scripts'].insert( -1, iter.get_value( 0 ) )
				break if ( ! iter.next!() )
			end
			iter = @unused_scripts_store.iter_first()
			while ( iter != nil )
				@values['unused_scripts'].insert( -1, iter.get_value( 0 ) )
				break if ( ! iter.next!() )
			end
			super()
		end

	end


	class WikiLyricsConfigDialog < BaseDialog

		def initialize( values )
			super( values )

			set_border_width( 5 )
			set_resizable( true )
			set_default_size( 300, 50 )
			set_title( "Configure #{values['script_name']} settings" )

			@submit_checkbox = Gtk::CheckButton.new( "Submit contents to #{values['script_name']}" )
			@submit_checkbox.set_active( values['submit'].to_s() == 'true' )

			@review_checkbox = Gtk::CheckButton.new( 'Prompt for review before submitting contents' )
			@review_checkbox.set_sensitive( @submit_checkbox.active?() )
			@review_checkbox.set_active( @review_checkbox.sensitive?() && values['review'].to_s() == 'true' )

			@prompt_autogen_checkbox = Gtk::CheckButton.new( 'Edit song pages marked as autogenerated' )
			@prompt_autogen_checkbox.set_sensitive( @review_checkbox.active?() )
			@prompt_autogen_checkbox.set_active( @prompt_autogen_checkbox.sensitive?() && values['prompt_autogen'].to_s() == 'true' )

			@prompt_new_checkbox = Gtk::CheckButton.new( 'Show submit dialog even if no lyrics were found' )
			@prompt_new_checkbox.set_sensitive( @review_checkbox.active?() )
			@prompt_new_checkbox.set_active( @prompt_new_checkbox.sensitive?() && values['prompt_new'].to_s() == 'true' )

			@username_lineedit = Gtk::Entry.new()
			@username_lineedit.set_text( values['username'] )

			@password_lineedit = Gtk::Entry.new()
			@password_lineedit.set_text( values['password'] )
			@password_lineedit.visibility = false

			@submit_checkbox.signal_connect( 'toggled' ) { toggle_submit_checked() }
			@review_checkbox.signal_connect( 'toggled' ) { toggle_review_checked() }

			vbox = Gtk::VBox.new( false, 3 );
			add( vbox )
					grid1 = Gtk::Table.new( 4, 4, false )
					grid1.set_row_spacings( 3 )
					grid1.set_column_spacings( 3 )
					grid1.attach( @submit_checkbox, 0, 2, 0, 1, Gtk::EXPAND|Gtk::FILL, 0 )
					grid1.attach( @review_checkbox, 0, 2, 1, 2, Gtk::EXPAND|Gtk::FILL, 0, 0 )
					grid1.attach( @prompt_autogen_checkbox, 0, 2, 2, 3, Gtk::EXPAND|Gtk::FILL, 0 )
					grid1.attach( @prompt_new_checkbox, 0, 2, 3, 4, Gtk::EXPAND|Gtk::FILL, 0 )

				group1 = Gtk::Frame.new( 'General Settings' )
				group1.add( grid1 )

			vbox.add( group1 )

					grid2 = Gtk::Table.new( 4, 4, false )
					grid2.set_row_spacings( 3 )
					grid2.set_column_spacings( 3 )

					label1 = Gtk::Label.new( '<b>Username</b>' ); label1.set_use_markup( true )
					grid2.attach( label1, 0, 1, 0, 1, Gtk::FILL, 0, 5 )
					grid2.attach( @username_lineedit, 1, 2, 0, 1, Gtk::EXPAND|Gtk::FILL, 0 )
					label2 = Gtk::Label.new( '<b>Password</b>' ); label2.set_use_markup( true )
					grid2.attach( label2, 0, 1, 1, 2, Gtk::FILL, 0, 5 )
					grid2.attach( @password_lineedit, 1, 2, 1, 2, Gtk::EXPAND|Gtk::FILL, 0 )

				group2 = Gtk::Frame.new( 'Login Settings' )
				group2.add( grid2 )

			vbox.add( group2 )

			buttons = create_action_buttons()
			vbox.pack_start( buttons, false )
		end

		def toggle_submit_checked()
			checked = @submit_checkbox.active?()
			@review_checkbox.set_sensitive( checked )
			if ( !checked )
				@review_checkbox.set_active( false )
				@prompt_autogen_checkbox.set_active( false )
				@prompt_new_checkbox.set_active( false )
			end
		end

		def toggle_review_checked()
			checked = @review_checkbox.active?()
			@prompt_autogen_checkbox.set_sensitive( checked )
			@prompt_new_checkbox.set_sensitive( checked )
			if ( !checked )
				@prompt_autogen_checkbox.set_active( false )
				@prompt_new_checkbox.set_active( false )
			end
		end

		def accept()
			@values = {
				'submit'			=> @submit_checkbox.active?(),
				'review'			=> @review_checkbox.active?(),
				'prompt_autogen'	=> @prompt_autogen_checkbox.active?(),
				'prompt_new'		=> @prompt_new_checkbox.active?(),
				'username'			=> @username_lineedit.text(),
				'password'			=> @password_lineedit.text(),
			}
			super()
		end
	end

	class WikiLyricsSubmitSongDialog < BaseDialog

		def initialize( values )
			super( values )

			set_border_width( 5 )
			set_resizable( true )
			set_default_size( 600, 400 )
			resize( 600, 400 )

			edit_mode = @values['edit_mode'].to_s() == 'true'

			set_title( values['script_name'] + (edit_mode ? ' - Edit song page' : ' - Submit song page') )

			@url_lineedit = Gtk::Entry.new()
			@url_lineedit.set_text( values['url'] )
			@url_lineedit.set_editable( !edit_mode )

			@artist_lineedit = Gtk::Entry.new()
			@artist_lineedit.set_text( values['artist'] )

			@song_lineedit = Gtk::Entry.new()
			@song_lineedit.set_text( values['song'] )

			@credits_lineedit = Gtk::Entry.new()
			@credits_lineedit.set_text( values['credits'] )

			@lyricist_lineedit = Gtk::Entry.new()
			@lyricist_lineedit.set_text( values['lyricist'] )

			adj = Gtk::Adjustment.new( values['year'], 1900, Date.today().year, 1, 10, 0 )
			@year_spinbox = Gtk::SpinButton.new( adj )
			@year_spinbox.set_numeric( true )

			@album_lineedit = Gtk::Entry.new()
			@album_lineedit.set_text( values['album'] )

			@instrumental_checkbox = Gtk::CheckButton.new( 'Instrumental piece' )
			@instrumental_checkbox.set_active( values['instrumental'].to_s == 'true' )
			@instrumental_checkbox.signal_connect( 'toggled' ) { toggle_instrumental_checked() }

			lyrics_scrolled_window = Gtk::ScrolledWindow.new()
			lyrics_scrolled_window.set_policy( Gtk::POLICY_AUTOMATIC, Gtk::POLICY_AUTOMATIC )
			@lyrics_text_buffer = Gtk::TextBuffer.new()
			@lyrics_text_buffer.set_text( values['lyrics'] )
			@lyrics_text = Gtk::TextView.new()
			@lyrics_text.set_buffer( @lyrics_text_buffer )
			lyrics_scrolled_window.add( @lyrics_text )
			@lyrics_text.set_sensitive( ! @instrumental_checkbox.active?() )
			lyrics_frame = Gtk::Frame.new()
			lyrics_frame.add( lyrics_scrolled_window )
			lyrics_frame.set_shadow_type( Gtk::SHADOW_IN )

			@autogen_checkbox = Gtk::CheckButton.new( 'Add to auto-generated category (leave checked if you haven\'t reviewed this form!)' )
			@autogen_checkbox.set_active( true )

			grid = Gtk::Table.new( 9, 4, false )
			grid.set_row_spacings( 3 )
			add( grid )

			label = Gtk::Label.new( '<b>URL</b>' ); label.set_alignment( 0.9, 0.5 ); label.set_use_markup( true )
			grid.attach( label, 0, 1, 0, 1, Gtk::EXPAND|Gtk::FILL, 0 )
			grid.attach( @url_lineedit, 1, 4, 0, 1, Gtk::EXPAND|Gtk::FILL, 0 )

			label = Gtk::Label.new( '<b>Artist</b>' ); label.set_alignment( 0.9, 0.5 ); label.set_use_markup( true )
			grid.attach( label, 0, 1, 1, 2, Gtk::EXPAND|Gtk::FILL, 0 )
			grid.attach( @artist_lineedit, 1, 2, 1, 2, Gtk::EXPAND|Gtk::FILL, 0 )
			label = Gtk::Label.new( '<b>Song</b>' ); label.set_alignment( 0.9, 0.5 ); label.set_use_markup( true )
			grid.attach( label, 2, 3, 1, 2, Gtk::EXPAND|Gtk::FILL, 0 )
			grid.attach( @song_lineedit, 3, 4, 1, 2, Gtk::EXPAND|Gtk::FILL, 0 )

			label = Gtk::Label.new( '<b>Credits</b>' ); label.set_alignment( 0.9, 0.5 ); label.set_use_markup( true )
			grid.attach( label, 0, 1, 2, 3, Gtk::EXPAND|Gtk::FILL, 0 )
			grid.attach( @credits_lineedit, 1, 2, 2, 3, Gtk::EXPAND|Gtk::FILL, 0 )
			label = Gtk::Label.new( '<b>Lyricist</b>' ); label.set_alignment( 0.9, 0.5 ); label.set_use_markup( true )
			grid.attach( label, 2, 3, 2, 3, Gtk::EXPAND|Gtk::FILL, 0 )
			grid.attach( @lyricist_lineedit, 3, 4, 2, 3, Gtk::EXPAND|Gtk::FILL, 0 )

			label = Gtk::Label.new( '<b>Year</b>' ); label.set_alignment( 0.9, 0.5 ); label.set_use_markup( true )
			grid.attach( label, 0, 1, 3, 4, Gtk::EXPAND|Gtk::FILL, 0 )
			grid.attach( @year_spinbox, 1, 2, 3, 4, Gtk::EXPAND|Gtk::FILL, 0 )
			label = Gtk::Label.new( '<b>Album</b>' ); label.set_alignment( 0.9, 0.5 ); label.set_use_markup( true )
			grid.attach( label, 2, 3, 3, 4, Gtk::EXPAND|Gtk::FILL, 0 )
			grid.attach( @album_lineedit, 3, 4, 3, 4, Gtk::EXPAND|Gtk::FILL, 0 )

			grid.attach( @instrumental_checkbox, 0, 4, 4, 5, Gtk::EXPAND|Gtk::FILL, 0 )

			grid.attach( lyrics_frame, 0, 4, 5, 6, Gtk::EXPAND|Gtk::FILL, Gtk::EXPAND|Gtk::FILL )

			grid.attach( @autogen_checkbox, 0, 4, 6, 7, Gtk::EXPAND|Gtk::FILL, 0 )

			buttons = create_action_buttons( 'split', 'Submit' )
			grid.attach( buttons, 0, 4, 7, 8, Gtk::EXPAND|Gtk::FILL, 0 )

		end

		def toggle_instrumental_checked()
			@lyrics_text.set_sensitive( ! @instrumental_checkbox.active?() )
		end

		def accept()
			@values = {
				'url'			=> @url_lineedit.text(),
				'artist'		=> @artist_lineedit.text(),
				'year'			=> @year_spinbox.value().to_i(),
				'album'			=> @album_lineedit.text(),
				'song'			=> @song_lineedit.text(),
				'lyrics'		=> @lyrics_text_buffer.text(),
				'instrumental'	=> @instrumental_checkbox.active?(),
				'lyricist'		=> @lyricist_lineedit.text(),
				'credits'		=> @credits_lineedit.text(),
				'autogen'		=> @autogen_checkbox.active?()
			}
			super()
		end

	end


	class WikiLyricsSubmitAlbumDialog < BaseDialog

		def initialize( values )
			super( values )

			set_border_width( 5 )
			set_resizable( true )
			set_default_size( 600, 400 )
			resize( 600, 400 )
			set_title( values['script_name'] + 'Submit album page' )

			@url_lineedit = Gtk::Entry.new()
			@url_lineedit.set_text( values['url'] )

			@artist_lineedit = Gtk::Entry.new()
			@artist_lineedit.set_text( values['artist'] )

			@released_lineedit = Gtk::Entry.new()
			@released_lineedit.set_text( values['released'] )

			@album_lineedit = Gtk::Entry.new()
			@album_lineedit.set_text( values['album'] )

			@image_path_lineedit = Gtk::Entry.new()
			if ( values.include?( 'image_path' ) )
				@image_path_lineedit.set_text( values['image_path'] )
				@image_button = Gtk::Button.new( '...' )
				@image_button.signal_connect( 'clicked' ) { browse_image() }
			else
				@image_path_lineedit.set_text( '(no need to upload album cover)' )
				@image_path_lineedit.set_editable( false )
			end

			tracks_scrolled_window = Gtk::ScrolledWindow.new()
			tracks_scrolled_window.set_policy( Gtk::POLICY_AUTOMATIC, Gtk::POLICY_AUTOMATIC )
			@tracks_text_buffer = Gtk::TextBuffer.new()
			@tracks_text_buffer.set_text( values['tracks'] )
			@tracks_text = Gtk::TextView.new()
			@tracks_text.set_buffer( @tracks_text_buffer )
			tracks_scrolled_window.add( @tracks_text )
			tracks_frame = Gtk::Frame.new()
			tracks_frame.add( tracks_scrolled_window )
			tracks_frame.set_shadow_type( Gtk::SHADOW_IN )

			@autogen_checkbox =
				Gtk::CheckButton.new( 'Add to auto-generated category (leave checked if you haven\'t reviewed this form!)' )
			@autogen_checkbox.set_active( true )

			grid = Gtk::Table.new( 9, 4, false )
			grid.set_row_spacings( 3 )
			add( grid )

			label = Gtk::Label.new( '<b>URL</b>' ); label.set_alignment( 0.9, 0.5 ); label.set_use_markup( true )
			grid.attach( label, 0, 1, 0, 1, Gtk::EXPAND|Gtk::FILL, 0 )
			grid.attach( @url_lineedit, 1, 4, 0, 1, Gtk::EXPAND|Gtk::FILL, 0 )

			label = Gtk::Label.new( '<b>Artist</b>' ); label.set_alignment( 0.9, 0.5 ); label.set_use_markup( true )
			grid.attach( label, 0, 1, 1, 2, Gtk::EXPAND|Gtk::FILL, 0 )
			grid.attach( @artist_lineedit, 1, 4, 1, 2, Gtk::EXPAND|Gtk::FILL, 0 )

			label = Gtk::Label.new( '<b>Released</b>' ); label.set_alignment( 0.9, 0.5 ); label.set_use_markup( true )
			grid.attach( label, 0, 1, 2, 3, Gtk::EXPAND|Gtk::FILL, 0 )
			grid.attach( @released_lineedit, 1, 2, 2, 3, Gtk::EXPAND|Gtk::FILL, 0 )
			label = Gtk::Label.new( '<b>Album</b>' ); label.set_alignment( 0.9, 0.5 ); label.set_use_markup( true )
			grid.attach( label, 2, 3, 2, 3, Gtk::EXPAND|Gtk::FILL, 0 )
			grid.attach( @album_lineedit, 3, 4, 2, 3, Gtk::EXPAND|Gtk::FILL, 0 )

			label = Gtk::Label.new( '<b>Image path</b>' ); label.set_alignment( 0.9, 0.5 ); label.set_use_markup( true )
			grid.attach( label, 0, 1, 3, 4, Gtk::EXPAND|Gtk::FILL, 0 )
			img_hbox = Gtk::HBox.new();
			img_hbox.pack_start( @image_path_lineedit, true, true )
			img_hbox.pack_start( @image_button, false, true ) if ( values.include?( 'image_path' ) )
			grid.attach( img_hbox, 1, 4, 3, 4, Gtk::EXPAND|Gtk::FILL, 0 )

			grid.attach( tracks_frame, 0, 4, 4, 5, Gtk::EXPAND|Gtk::FILL, Gtk::EXPAND|Gtk::FILL )

			grid.attach( @autogen_checkbox, 0, 4, 5, 6, Gtk::EXPAND|Gtk::FILL, 0 )

			buttons = create_action_buttons( 'split', 'Submit' )
			grid.attach( buttons, 0, 4, 6, 7, Gtk::EXPAND|Gtk::FILL, 0 )

		end

		def browse_image()
			dirname = @image_path_lineedit.text().strip()
			dirname = Strings.empty?( dirname ) ? (ENV['HOME'] ? ENV['HOME'] : '.') : File.dirname( dirname )
			dialog = Gtk::FileChooserDialog.new(
				'Select album image path', self, Gtk::FileChooser::ACTION_OPEN, nil,
				[Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL],
				[Gtk::Stock::OPEN, Gtk::Dialog::RESPONSE_ACCEPT]
			)

			filter = Gtk::FileFilter.new()
			filter.set_name( 'Images' )
			['jpg', 'png', 'bmp'].each() { |ext| filter.add_pattern( "*.#{ext}" ).add_pattern( "*.#{ext.upcase}" ) }
			dialog.add_filter( filter )
			filter = Gtk::FileFilter.new()
			filter.set_name( 'All Files' )
			filter.add_pattern( "*" )
			dialog.add_filter( filter )

			dialog.set_local_only( true )
			dialog.set_select_multiple( false )
			dialog.set_current_folder( File.expand_path( dirname ) )
			if ( dialog.run == Gtk::Dialog::RESPONSE_ACCEPT )
        		image_path = GLib.filename_to_utf8( dialog.filename )
				@image_path_lineedit.set_text( image_path.strip() ) if ( ! Strings.empty?( image_path ) )
			end
			dialog.destroy()
		end

		def accept()
			aux = {
				'url'		=> @url_lineedit.text(),
				'artist'	=> @artist_lineedit.text(),
				'released'	=> @released_lineedit.text(),
				'album'		=> @album_lineedit.text(),
				'tracks'	=> @tracks_text_buffer.text(),
				'autogen'	=> @autogen_checkbox.active?()
			}
			aux['image_path'] = @image_path_lineedit.text() if ( @values.include?( 'image_path' ) )
			@values = aux
			super()
		end

	end


	class UploadCoverDialog < BaseDialog

		def initialize( values )
			super( values )

			set_border_width( 5 )
			set_resizable( true )
			set_default_size( 400, 100 )
			set_title( "#{values['script_name']} - Upload album cover" )

			@artist_lineedit = Gtk::Entry.new()
			@artist_lineedit.set_text( values['artist'] )

			@album_lineedit = Gtk::Entry.new()
			@album_lineedit.set_text( values['album'] )

			adj = Gtk::Adjustment.new( values['year'], 1900, Date.today().year, 1, 10, 0 )
			@year_spinbox = Gtk::SpinButton.new( adj )
			@year_spinbox.set_numeric( true )

			@image_path_lineedit = Gtk::Entry.new()
			@image_path_lineedit.set_text( values['image_path'] )
			@image_button = Gtk::Button.new( '...' )
			@image_button.signal_connect( 'clicked' ) { browse_image() }

			vbox = Gtk::VBox.new( false, 3 );
			add( vbox )

			group = Gtk::Frame.new( 'Album' )
			vbox.add( group )

			grid = Gtk::Table.new( 4, 4, false )
			grid.set_row_spacings( 3 )
			grid.set_column_spacings( 3 )
			group.add( grid )

			label = Gtk::Label.new( '<b>Artist</b>' ); label.set_use_markup( true )
			grid.attach( label, 0, 1, 0, 1, Gtk::FILL, 0, 5 )
			grid.attach( @artist_lineedit, 1, 2, 0, 1, Gtk::EXPAND|Gtk::FILL, 0 )

			label = Gtk::Label.new( '<b>Album</b>' ); label.set_use_markup( true )
			grid.attach( label, 0, 1, 2, 3, Gtk::FILL, 0, 5 )
			grid.attach( @album_lineedit, 1, 2, 2, 3, Gtk::EXPAND|Gtk::FILL, 0 )

			label = Gtk::Label.new( '<b>Year</b>' ); label.set_use_markup( true )
			grid.attach( label, 0, 1, 3, 4, Gtk::FILL, 0, 5 )
			grid.attach( @year_spinbox, 1, 2, 3, 4, Gtk::EXPAND|Gtk::FILL, 0 )

			group = Gtk::Frame.new( 'Image' )
			vbox.add( group )

			grid = Gtk::Table.new( 4, 4, false )
			grid.set_row_spacings( 3 )
			grid.set_column_spacings( 3 )
			group.add( grid )

			label = Gtk::Label.new( '<b>Path</b>' ); label.set_use_markup( true )
			grid.attach( label, 0, 1, 0, 1, Gtk::FILL, 0, 5 )
			grid.attach( @image_path_lineedit, 1, 2, 0, 1, Gtk::EXPAND|Gtk::FILL, 0 )
			grid.attach( @image_button, 2, 3, 0, 1, 0, 0 )

			buttons = create_action_buttons()
			vbox.add( buttons )
		end

		def browse_image()
			dirname = @image_path_lineedit.text().strip()
			dirname = Strings.empty?( dirname ) ? (ENV['HOME'] ? ENV['HOME'] : '.') : File.dirname( dirname )
			dialog = Gtk::FileChooserDialog.new(
				'Select album image path', self, Gtk::FileChooser::ACTION_OPEN, nil,
				[Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL],
				[Gtk::Stock::OPEN, Gtk::Dialog::RESPONSE_ACCEPT]
			)

			filter = Gtk::FileFilter.new()
			filter.set_name( 'Images' )
			['jpg', 'png', 'bmp'].each() { |ext| filter.add_pattern( "*.#{ext}" ).add_pattern( "*.#{ext.upcase}" ) }
			dialog.add_filter( filter )
			filter = Gtk::FileFilter.new()
			filter.set_name( 'All Files' )
			filter.add_pattern( "*" )
			dialog.add_filter( filter )

			dialog.set_local_only( true )
			dialog.set_select_multiple( false )
			dialog.set_current_folder( File.expand_path( dirname ) )
			if ( dialog.run == Gtk::Dialog::RESPONSE_ACCEPT )
        		image_path = GLib.filename_to_utf8( dialog.filename )
				@image_path_lineedit.set_text( image_path.strip() ) if ( ! Strings.empty?( image_path ) )
			end
			dialog.destroy()
		end

		def accept()
			@values = {
				'artist'		=> @artist_lineedit.text(),
				'album'			=> @album_lineedit.text(),
				'year'			=> @year_spinbox.value().to_i(),
				'image_path'	=> @image_path_lineedit.text()
			}
			super()
		end
	end


	class LyrixAtConfigDialog < BaseDialog

		def initialize( values )
			super( values )

			set_border_width( 5 )
			set_resizable( true )
			set_default_size( 300, 50 )
			set_title( 'Configure Lyrix.At settings' )

			@username_lineedit = Gtk::Entry.new()
			@username_lineedit.set_text( values['username'] )

			@password_lineedit = Gtk::Entry.new()
			@password_lineedit.set_text( values['password'] )
			@password_lineedit.visibility = false

			vbox = Gtk::VBox.new( false, 3 );
			add( vbox )

			group = Gtk::Frame.new( 'Login Settings' )
			vbox.add( group )

			grid = Gtk::Table.new( 4, 4, false )
			grid.set_row_spacings( 3 )
			grid.set_column_spacings( 3 )
			group.add( grid )

			label = Gtk::Label.new( '<b>Username</b>' ); label.set_use_markup( true )
			grid.attach( label, 0, 1, 0, 1, Gtk::FILL, 0, 5 )
			grid.attach( @username_lineedit, 1, 2, 0, 1, Gtk::EXPAND|Gtk::FILL, 0 )
			label = Gtk::Label.new( '<b>Password</b>' ); label.set_use_markup( true )
			grid.attach( label, 0, 1, 1, 2, Gtk::FILL, 0, 5 )
			grid.attach( @password_lineedit, 1, 2, 1, 2, Gtk::EXPAND|Gtk::FILL, 0 )

			buttons = create_action_buttons()
			vbox.add( buttons )
		end

		def accept()
			@values = {
				'username'	=> @username_lineedit.text(),
				'password'	=> @password_lineedit.text(),
			}
			super()
		end
	end


	class SearchLyricsDialog < BaseDialog

		def initialize( values )
			super( values )

			set_border_width( 5 )
			set_resizable( true )
			set_default_size( 300, 50 )
			set_title( 'Search lyrics' )

			@artist_lineedit = Gtk::Entry.new()
			@artist_lineedit.set_text( values['artist'] )

			@title_lineedit = Gtk::Entry.new()
			@title_lineedit.set_text( values['title'] )

			@album_lineedit = Gtk::Entry.new()
			@album_lineedit.set_text( values['album'] )

			adj = Gtk::Adjustment.new( values['year'], 1900, Date.today().year, 1, 10, 0 )
			@year_spinbox = Gtk::SpinButton.new( adj )
			@year_spinbox.set_numeric( true )

			vbox = Gtk::VBox.new( false, 3 );
			add( vbox )

			group = Gtk::Frame.new( 'Search Settings' )
			vbox.add( group )

			grid = Gtk::Table.new( 4, 4, false )
			grid.set_row_spacings( 3 )
			grid.set_column_spacings( 3 )
			group.add( grid )

			label = Gtk::Label.new( '<b>Artist</b>' ); label.set_use_markup( true )
			grid.attach( label, 0, 1, 0, 1, Gtk::FILL, 0, 5 )
			grid.attach( @artist_lineedit, 1, 2, 0, 1, Gtk::EXPAND|Gtk::FILL, 0 )

			label = Gtk::Label.new( '<b>Title</b>' ); label.set_use_markup( true )
			grid.attach( label, 0, 1, 1, 2, Gtk::FILL, 0, 5 )
			grid.attach( @title_lineedit, 1, 2, 1, 2, Gtk::EXPAND|Gtk::FILL, 0 )

			label = Gtk::Label.new( '<b>Album</b>' ); label.set_use_markup( true )
			grid.attach( label, 0, 1, 2, 3, Gtk::FILL, 0, 5 )
			grid.attach( @album_lineedit, 1, 2, 2, 3, Gtk::EXPAND|Gtk::FILL, 0 )

			label = Gtk::Label.new( '<b>Year</b>' ); label.set_use_markup( true )
			grid.attach( label, 0, 1, 3, 4, Gtk::FILL, 0, 5 )
			grid.attach( @year_spinbox, 1, 2, 3, 4, Gtk::EXPAND|Gtk::FILL, 0 )

			buttons = create_action_buttons()
			vbox.add( buttons )
		end

		def accept()
			@values = {
				'artist'	=> @artist_lineedit.text(),
				'title'		=> @title_lineedit.text(),
				'album'		=> @album_lineedit.text(),
				'year'		=> @year_spinbox.value().to_i(),
			}
			super()
		end
	end


	class LyricsDialog < BaseDialog

		def initialize( values )
			super( values )

			set_border_width( 5 )
			set_resizable( true )
			set_default_size( 400, 400 )
			resize( 400, 400 )

			title = "Lyrics to '#{@values['title']}' by '#{@values['artist']}'"
			title += " [#{@values['site']}]" if @values['site']
			set_title( title )

			lyrics_scrolled_window = Gtk::ScrolledWindow.new()
			lyrics_scrolled_window.set_policy( Gtk::POLICY_AUTOMATIC, Gtk::POLICY_AUTOMATIC )
			@lyrics_text_buffer = Gtk::TextBuffer.new()
			@lyrics_text_buffer.set_text( values['lyrics'] )
			@lyrics_text = Gtk::TextView.new()
			@lyrics_text.set_buffer( @lyrics_text_buffer )
			lyrics_scrolled_window.add( @lyrics_text )
			lyrics_frame = Gtk::Frame.new()
			lyrics_frame.add( lyrics_scrolled_window )
			lyrics_frame.set_shadow_type( Gtk::SHADOW_IN )

			add( lyrics_frame )
		end

	end

end
