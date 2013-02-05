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
require 'thread'
require 'tk'

module TK

	class BaseDialog

		@@mutex = Mutex.new()
		@@mainthread = nil
		@@root = nil
		@@top_windows = []

		attr_reader :accepted
		attr_reader :values

		def initialize( values, close_on_escape=true )
			@values = values
			@@mutex.lock()
			if ( @@root == nil )
				@@root = TkRoot.new()
				@@root.withdraw()
				@@mainthread = Thread.new() do
					Tk.mainloop()
				end
			end
			@@mutex.unlock()

			@x = nil
			@y = nil
			@width = nil
			@height = nil

			@close_on_escape = close_on_escape
		end

		def exec()

			@accepted = false

			@top_window = TkToplevel.new( @@root )
			@top_window.protocol( 'WM_DELETE_WINDOW', proc { destroy() } )
			@top_window.bind( 'Escape', proc { destroy() } ) if ( @close_on_escape )

			@top_window.withdraw()

			create_contents()

			instance_variables.each() do |obj|
				obj = instance_variable_get( obj )
				if ( obj.kind_of?( TkEntry ) )
					TK.setup_entry( obj, @top_window )
				elsif ( obj.kind_of?( TkText ) )
					TK.setup_text( obj, @top_window )
				end
			end

			@@mutex.lock()
			@@top_windows.insert( 0, @top_window )
			@@mutex.unlock()

 			if ( !@x && !@y ) # center the dialog
				set_size( @width, @height ) if ( @width )
				width, height = get_size()
				s_width, s_height = BaseDialog.get_screen_size()
				@x = (s_width - width) / 2
				@y = (s_height - height) / 2
			end
			set_position( @x, @y )

			@top_window.deiconify()

			begin
				sleep( 0.1 )
				@@mutex.lock()
				continue = @@top_windows.include?( @top_window )
				@@mutex.unlock()
			end while ( continue )
		end

		def destroy()
			return if ( @top_window == nil )
			@top_window.destroy()
			@@mutex.lock()
			@@top_windows.delete( @top_window )
			@@mutex.unlock()
			@top_window = nil
		end

		def accept()
			@accepted = true
			destroy()
		end

		def set_size( width, height )
			@width = width.to_i()
			@height = height.to_i()
			@@mutex.lock()
			if ( @@top_windows.include?( @top_window ) )
				@top_window.geometry( "#{@width}x#{@height}" )
			end
			@@mutex.unlock()
		end

		def set_position( x, y )
			@x = x.to_i()
			@y = y.to_i()
			@@mutex.lock()
			if ( @@top_windows.include?( @top_window ) )
				@top_window.geometry( "#{@x > 0 ? '+' : '-'}#{@x}#{@y > 0 ? '+' : '-'}#{@y}" )
			end
			@@mutex.unlock()
		end

		def get_size()
			return @width.to_i(), @height.to_i() if ( @width )
			@@mutex.lock()
			if ( @@top_windows.include?( @top_window ) )
				sleep( 1 ) # this is lame
				md = /([0-9]+)x([0-9]+)[-\+][0-9]+[-\+][0-9]+/.match( @top_window.geometry() )
				width, height = md[1].to_i(), md[2].to_i()
			else
				width, height = nil, nil
			end
			@@mutex.unlock()
			return width, height
		end

		def get_position()
			return @x.to_i(), @y.to_i()
		end

		def BaseDialog.get_screen_size()
			maxsize = Tk.root.maxsize()
			return maxsize[0], maxsize[1]
		end

		def create_action_buttons( row, mode='right', accept_text='Accept', cancel_text='Cancel' )
			parent = self
			buttons_frame = TkFrame.new( @top_window )
			buttons_frame.grid( 'row'=>row, 'column'=>1, 'columnspan'=>4, 'sticky'=>'ew' )
			accept_text = Strings.empty?( accept_text ) ? 'Accept' : accept_text
			cancel_text = Strings.empty?( cancel_text ) ? 'Cancel' : cancel_text
			@accept_button = TkButton.new( buttons_frame ) { text accept_text; command { parent.accept() } }
			@cancel_button = TkButton.new( buttons_frame ) { text cancel_text; command { parent.destroy() } }
			if ( mode == 'left' )
				@accept_button.pack( 'side'=>'left' )
				@cancel_button.pack( 'side'=>'left' )
			elsif ( mode == 'split' )
				@accept_button.pack( 'side'=>'left', 'fill'=>'x', 'expand'=>'true' )
				@cancel_button.pack( 'side'=>'right', 'fill'=>'x', 'expand'=>'true' )
			else
				@cancel_button.pack( 'side'=>'right' )
				@accept_button.pack( 'side'=>'right' )
			end
		end
		protected :create_action_buttons

	end

	def TK.setup_text( text, top_window=nil )

		proc_select_all = proc { text.tag_add( 'sel', '0.0', 'end' ) }
		proc_select_none = proc { text.tag_remove( 'sel', '0.0', 'end' ); }
		proc_delete = proc { text.delete( 'sel.first', 'sel.last' ) if ( text.tag_ranges( 'sel' ).size > 0 ) }
		proc_cut = proc { text.text_cut() }
		proc_copy = proc { text.text_copy() }
		proc_paste = proc do
			selected = text.tag_ranges( 'sel' ).size() > 0
			if ( selected )
				length = text.value.size()
				text.tag_add( 'prev_sel', 'sel.first', 'sel.last' )
			end
			text.text_paste();
			text.delete( 'prev_sel.first', 'prev_sel.last' ) if ( selected && text.value.size() != length )
			text.see( 'insert' )
		end
		# proc_undo = proc { text.edit_undo() } # TODO
		# proc_redo = proc { text.edit_redo() } # TODO

		menu = TkMenu.new( 'tearoff'=>false )
		# menu.add( 'command', 'label'=>'Undo', 'accel'=>'Ctrl+Z', 'command'=>proc_undo )
		# menu.add( 'command', 'label'=>'Redo', 'accel'=>'Ctrl+Shift+Z', 'command'=>proc_redo )
		# menu.add( 'separator' )
		menu.add( 'command', 'label'=>'Cut', 'accel'=>'Ctrl+X', 'command'=>proc_cut )
		menu.add( 'command', 'label'=>'Copy', 'accel'=>'Ctrl+C', 'command'=>proc_copy )
		menu.add( 'command', 'label'=>'Paste', 'accel'=>'Ctrl+V', 'command'=>proc_paste )
		menu.add( 'command', 'label'=>'Delete', 'accel'=>'Delete', 'command'=>proc_delete )
		menu.add( 'separator' )
		menu.add( 'command', 'label'=>'Select All', 'accel'=>'Ctrl+A', 'command'=>proc_select_all )
		menu.bind( 'FocusOut', proc { menu.unpost() } )

		text.bind( 'FocusOut', proc_select_none )
		text.bind( 'Button-3', proc { |e| menu.post( e.x_root, e.y_root ); menu.set_focus() } )
		text.bind( 'Control-Key-X', proc { proc_cut.call(); Tk.callback_break() } )
		text.bind( 'Control-Key-x', proc { proc_cut.call(); Tk.callback_break() } )
		text.bind( 'Control-Key-C', proc { proc_copy.call(); Tk.callback_break() } )
		text.bind( 'Control-Key-c', proc { proc_copy.call(); Tk.callback_break() } )
		text.bind( 'Control-Key-V', proc { proc_paste.call(); Tk.callback_break() } )
		text.bind( 'Control-Key-v', proc { proc_paste.call(); Tk.callback_break() } )
		text.bind( 'Control-Key-A', proc { proc_select_all.call(); Tk.callback_break() } )
		text.bind( 'Control-Key-a', proc { proc_select_all.call(); Tk.callback_break() } )
		# text.bind( 'Control-Key-Z', proc { proc_undo.call(); Tk.callback_break() } )
		# text.bind( 'Control-Key-z', proc { proc_undo.call(); Tk.callback_break() } )
		# text.bind( 'Control-Shift-Key-Z', proc { proc_redo.call(); Tk.callback_break() } )
		# text.bind( 'Control-Shift-Key-z', proc { proc_redo.call(); Tk.callback_break() } )

	end


	def TK.setup_entry( entry, top_window=nil )

		proc_select_all = proc { entry.selection_range( 0, 'end' ) }
		proc_select_none = proc { entry.selection_clear() }
		proc_delete = proc { entry.delete( 'sel.first', 'sel.last' ) if ( entry.selection_present() ) }
		proc_cut = proc do
			if ( entry.selection_present() )
				value = entry.value()
				TkClipboard.set( value.slice( entry.index( 'sel.first' ), entry.index( 'sel.last' ) ) )
				entry.delete( 'sel.first', 'sel.last' )
			end
		end
		proc_copy = proc do
			if ( entry.selection_present() )
				value = entry.value()
				TkClipboard.set( value.slice( entry.index( 'sel.first' ), entry.index( 'sel.last' ) ) )
			end
		end
		proc_paste = proc do
			data = TkClipboard.get()
			if ( ! Strings.empty?( data ) )
				entry.insert( entry.index( 'insert' ), data )
				entry.xview( 'insert' )
				if ( entry.selection_present() )
					entry.delete( 'sel.first', 'sel.last' )
				end
			end
		end
		# proc_undo = proc {} # TODO
		# proc_redo = proc {} # TODO

		menu = TkMenu.new( entry, 'tearoff'=>false )
		# menu.add( 'command', 'label'=>'Undo', 'accel'=>'Ctrl+Z', 'command'=>proc_undo )
		# menu.add( 'command', 'label'=>'Redo', 'accel'=>'Ctrl+Shift+Z', 'command'=>proc_redo )
		# menu.add( 'separator' )
		menu.add( 'command', 'label'=>'Cut', 'accel'=>'Ctrl+X', 'command'=>proc_cut )
		menu.add( 'command', 'label'=>'Copy', 'accel'=>'Ctrl+C', 'command'=>proc_copy )
		menu.add( 'command', 'label'=>'Paste', 'accel'=>'Ctrl+V', 'command'=>proc_paste )
		menu.add( 'command', 'label'=>'Delete', 'accel'=>'Delete', 'command'=>proc_delete )
		menu.add( 'separator' )
		menu.add( 'command', 'label'=>'Select All', 'accel'=>'Ctrl+A', 'command'=>proc_select_all )
		menu.bind( 'FocusOut', proc { menu.unpost() } )

		entry.bind( 'Button-3', proc {|e| menu.post( e.x_root, e.y_root ); menu.set_focus() } )
		entry.bind( 'FocusOut', proc_select_none )
		entry.bind( 'Control-Key-X', proc { proc_cut.call(); Tk.callback_break() } )
		entry.bind( 'Control-Key-x', proc { proc_cut.call(); Tk.callback_break() } )
		entry.bind( 'Control-Key-C', proc { proc_copy.call(); Tk.callback_break() } )
		entry.bind( 'Control-Key-c', proc { proc_copy.call(); Tk.callback_break() } )
		entry.bind( 'Control-Key-V', proc { proc_paste.call(); Tk.callback_break() } )
		entry.bind( 'Control-Key-v', proc { proc_paste.call(); Tk.callback_break() } )
		entry.bind( 'Control-Key-A', proc { proc_select_all.call(); Tk.callback_break() } )
		entry.bind( 'Control-Key-a', proc { proc_select_all.call(); Tk.callback_break() } )
		# entry.bind( 'Control-Key-Z', proc { proc_undo.call(); Tk.callback_break() } )
		# entry.bind( 'Control-Key-z', proc { proc_undo.call(); Tk.callback_break() } )
		# entry.bind( 'Control-Shift-Key-Z', proc { proc_redo.call(); Tk.callback_break() } )
		# entry.bind( 'Control-Shift-Key-z', proc { proc_redo.call(); Tk.callback_break() } )

	end


	class MetaLyricsConfigDialog < BaseDialog

		def initialize( values )
			super( values )
			set_size( 400, 230 )
		end

		def create_contents()
			@top_window.title( @values['script'] + ' script configuration' )

			TkLabel.new( @top_window ) do
				text 'Lyrics priority'
				grid( 'row'=>1, 'column'=>1, 'columnspan'=>4, 'sticky'=>'w' )
			end

			frame = TkFrame.new( @top_window )
			frame.grid( 'row'=>2, 'rowspan'=>4, 'column'=>2, 'sticky'=>'nesw' )
			y_scroll_bar = TkScrollbar.new( frame, 'orient'=>'ver' )
			y_scroll_bar.pack( 'side'=>'right', 'fill'=>'y' )
			@used_scripts_list = TkListbox.new( frame, 'selectmode' => 'single' ) do
				pack( 'side'=>'left', 'fill'=>'both', 'expand'=>true )
			end
			y_scroll_bar.command( proc { |*args| @used_scripts_list.yview( *args ) } )
			@used_scripts_list.yscrollcommand( proc { |first, last| y_scroll_bar.set( first, last ) } )
			@values['used_scripts'].each() do |script|
				@used_scripts_list.insert( 'end', script )
			end

			frame = TkFrame.new( @top_window )
			frame.grid( 'row'=>2, 'rowspan'=>4, 'column'=>4, 'sticky'=>'nesw' )
			y_scroll_bar = TkScrollbar.new( frame, 'orient'=>'ver' )
			y_scroll_bar.pack( 'side'=>'right', 'fill'=>'y' )
			@unused_scripts_list = TkListbox.new( frame, 'selectmode' => 'single' ) do
				pack( 'side'=>'left', 'fill'=>'both', 'expand'=>true )
			end
			y_scroll_bar.command( proc { |*args| @unused_scripts_list.yview( *args ) } )
			@unused_scripts_list.yscrollcommand( proc { |first, last| y_scroll_bar.set( first, last ) } )
			@values['unused_scripts'].each() do |script|
				@unused_scripts_list.insert( 'end', script )
			end

			parent = self

			@move_up_button = TkButton.new( @top_window ) do
				text 'Up'
				command { parent.move_up() }
				grid( 'row'=>3, 'column'=>1, 'sticky'=>'ew' )
			end
			@move_down_button = TkButton.new( @top_window ) do
				text 'Down'
				command { parent.move_down() }
				grid( 'row'=>4, 'column'=>1, 'sticky'=>'ew' )
			end

			@add_button = TkButton.new( @top_window ) do
				text '<< Add'
				command { parent.add_script() }
				grid( 'row'=>3, 'column'=>3, 'sticky'=>'ew' )
			end
			@remove_button = TkButton.new( @top_window ) do
				text 'Remove >>'
				command { parent.remove_script() }
				grid( 'row'=>4, 'column'=>3, 'sticky'=>'ew' )
			end

			@cleanup_lyrics_checkbox = TkCheckButton.new( @top_window )
			@cleanup_lyrics_checkbox.grid('row'=>6, 'column'=>1, 'columnspan'=>4, 'sticky'=>'w')
			@cleanup_lyrics_checkbox.set_value( @values['cleanup_lyrics'].to_s() == 'true' )
			@cleanup_lyrics_checkbox.text = 'Clean up retrieved lyrics'

			create_action_buttons( 7 )

			@top_window.grid_rowconfigure( 2, 'weight'=>1 )
			@top_window.grid_rowconfigure( 5, 'weight'=>1 )
			@top_window.grid_columnconfigure( 2, 'weight'=>1 )
			@top_window.grid_columnconfigure( 4, 'weight'=>1 )
		end

		def get_active_index( list_box )
			list_box.size().times do |idx|
				return idx if list_box.selection_includes( idx )
			end
			return nil
		end

		def move_up()
			active_idx = get_active_index( @used_scripts_list )
			return if ( active_idx == nil || active_idx == 0 )
			active = @used_scripts_list.get( active_idx )
			@used_scripts_list.delete( active_idx )
			@used_scripts_list.insert( active_idx-1, active )
			@used_scripts_list.selection_set( active_idx-1 )
		end

		def move_down()
			active_idx = get_active_index( @used_scripts_list )
			return if ( active_idx == nil || active_idx == @used_scripts_list.size()-1 )
			active = @used_scripts_list.get( active_idx )
			@used_scripts_list.delete( active_idx )
			@used_scripts_list.insert( active_idx+1, active )
			@used_scripts_list.selection_set( active_idx+1 )
		end

		def add_script()
			active_idx = get_active_index( @unused_scripts_list )
			return if ( active_idx == nil )
			active = @unused_scripts_list.get( active_idx )
			@unused_scripts_list.delete( active_idx )
			@used_scripts_list.insert( 'end', active )
			@used_scripts_list.selection_set( 'end' )
		end

		def remove_script()
			active_idx = get_active_index( @used_scripts_list )
			return if ( active_idx == nil )
			active = @used_scripts_list.get( active_idx )
			@used_scripts_list.delete( active_idx )
			@unused_scripts_list.insert( 'end', active )
			@unused_scripts_list.selection_set( 'end' )
		end

		def accept()
			@values = {
				'script' => @values['script'],
				'cleanup_lyrics' => @cleanup_lyrics_checkbox.get_value() != '0',
				'used_scripts' => [],
				'unused_scripts' => []
			}
			@used_scripts_list.size().times do |idx|
				@values['used_scripts'].insert( -1, @used_scripts_list.get( idx ) )
			end
			@unused_scripts_list.size().times do |idx|
				@values['unused_scripts'].insert( -1, @unused_scripts_list.get( idx ) )
			end
			super()
		end

	end


	class WikiLyricsConfigDialog < BaseDialog

		def initialize( values )
			super( values )
			set_size( 360, 210 )
		end

		def create_contents()
			@top_window.title( "Configure #{values['script_name']} settings" )

			TkLabel.new( @top_window ) { text 'General Settings' ; grid( 'row'=>1, 'column'=>1, 'columnspan'=>4, 'sticky'=>'w' ) }

			proc_submit_toggled = proc { toggle_submit_checked() }
			@submit_checkbox = TkCheckButton.new( @top_window ) { command proc_submit_toggled }
			@submit_checkbox.grid( 'row'=>2, 'column'=>1, 'columnspan'=>3, 'sticky'=>'w' )
			@submit_checkbox.set_value( values['submit'].to_s() == 'true' )
			@submit_checkbox.text = "Submit contents to #{values['script_name']}"

			proc_review_toggled = proc { toggle_review_checked() }
			@review_checkbox = TkCheckButton.new( @top_window ) { command proc_review_toggled }
			@review_checkbox.grid( 'row'=>3, 'column'=>1, 'columnspan'=>3, 'sticky'=>'w' )
			@review_checkbox.text = 'Prompt for review before submitting contents'
			@review_checkbox.state = @submit_checkbox.get_value() != '0' ? 'normal' : 'disabled'
			@review_checkbox.set_value( @review_checkbox.state == 'normal' && values['review'].to_s() == 'true' )

			@prompt_autogen_checkbox = TkCheckButton.new( @top_window )
			@prompt_autogen_checkbox.grid( 'row'=>4, 'column'=>1, 'columnspan'=>3, 'sticky'=>'w' )
			@prompt_autogen_checkbox.text = 'Edit song pages marked as autogenerated'
			@prompt_autogen_checkbox.state = @review_checkbox.get_value() != '0' ? 'normal' : 'disabled'
			@prompt_autogen_checkbox.set_value(@prompt_autogen_checkbox.state == 'normal' && values['prompt_autogen'].to_s() == 'true')

			@prompt_new_checkbox = TkCheckButton.new( @top_window )
			@prompt_new_checkbox.grid( 'row'=>5, 'column'=>1, 'columnspan'=>3, 'sticky'=>'w' )
			@prompt_new_checkbox.text = 'Show submit dialog even if no lyrics were found'
			@prompt_new_checkbox.state = @review_checkbox.get_value() != '0' ? 'normal' : 'disabled'
			@prompt_new_checkbox.set_value( @prompt_new_checkbox.state == 'normal' && values['prompt_new'].to_s() == 'true' )

			TkLabel.new( @top_window ) { text 'Login Settings' ; grid( 'row'=>7, 'column'=>1, 'columnspan'=>4, 'sticky'=>'w' ) }

			TkLabel.new( @top_window ) { text 'Username:' ; grid( 'row'=>8, 'column'=>1 ) }
			@username_var = TkVariable.new( values['username'] )
			@username_lineedit = TkEntry.new( @top_window, 'textvariable'=>@username_var ) do
				grid( 'row'=>8, 'column'=>2, 'columnspan'=>2, 'sticky'=>'ew' )
			end

			TkLabel.new( @top_window ) { text 'Password:' ; grid( 'row'=>9, 'column'=>1 ) }
			@password_var = TkVariable.new( values['password'] )
			@password_lineedit = TkEntry.new( @top_window, 'textvariable'=>@password_var, 'show'=>'*' ) do
				grid( 'row'=>9, 'column'=>2, 'columnspan'=>2, 'sticky'=>'ew' )
			end

			create_action_buttons( 11 )

			@top_window.grid_rowconfigure( 6, 'weight'=>1 )
			@top_window.grid_rowconfigure( 10, 'weight'=>5 )
			@top_window.grid_columnconfigure( 2, 'weight'=>1 )
			@top_window.grid_columnconfigure( 3, 'weight'=>1 )
		end

		def toggle_submit_checked()
			state = @submit_checkbox.get_value() == '0' ? 'disabled' : 'normal'
			@review_checkbox.state = state
			if ( state == 'disabled' )
				@review_checkbox.set_value( false )
				@prompt_autogen_checkbox.set_value( false )
				@prompt_new_checkbox.set_value( false )
				@prompt_autogen_checkbox.state = 'disabled'
				@prompt_new_checkbox.state = 'disabled'
			end
		end

		def toggle_review_checked()
			state = @review_checkbox.get_value() == '0' ? 'disabled' : 'normal'
			@prompt_autogen_checkbox.state = state
			@prompt_new_checkbox.state = state
			if ( state == 'disabled' )
				@prompt_autogen_checkbox.set_value( false )
				@prompt_new_checkbox.set_value( false )
			end
		end

		def accept()
			@values = {
				'submit'			=> @submit_checkbox.get_value() != '0',
				'review'			=> @review_checkbox.get_value() != '0',
				'prompt_autogen'	=> @prompt_autogen_checkbox.get_value() != '0',
				'prompt_new'		=> @prompt_new_checkbox.get_value() != '0',
				'username'			=> @username_var.value(),
				'password'			=> @password_var.value(),
			}
			super()
		end

	end

	class WikiLyricsSubmitSongDialog < BaseDialog

		def initialize( values )
			super( values )
			set_size( 600, 400 )
		end

		def create_contents()

			edit_mode = @values['edit_mode'].to_s() == 'true'
			@top_window.title( values['script_name'] + (edit_mode ? ' - Edit song page' : ' - Submit song page') )

			TkLabel.new( @top_window ) { text 'URL:' ; grid( 'row'=>1, 'column'=>1 ) }
			@url_lineedit_text = TkVariable.new( values['url'] )
			@url_lineedit = TkEntry.new( @top_window, 'textvariable'=>@url_lineedit_text ) do
				state "#{edit_mode ? 'disabled' : 'normal'}"
				grid( 'row'=>1, 'column'=>2, 'columnspan'=>3, 'sticky'=>'ew' )
			end

			TkLabel.new( @top_window ) { text 'Artist:' ; grid( 'row'=>2, 'column'=>1, 'sticky'=>'ew' ) }
			@artist_lineedit_text = TkVariable.new( values['artist'] )
			@artist_lineedit = TkEntry.new( @top_window, 'textvariable'=>@artist_lineedit_text ) do
				grid( 'row'=>2, 'column'=>2, 'sticky'=>'ew' )
			end

			TkLabel.new( @top_window ) { text 'Song:' ; grid( 'row'=>2, 'column'=>3, 'sticky'=>'ew' ) }
			@song_lineedit_text = TkVariable.new( values['song'] )
			@song_lineedit = TkEntry.new( @top_window, 'textvariable'=>@song_lineedit_text ) do
				grid( 'row'=>2, 'column'=>4, 'sticky'=>'ew' )
			end

			TkLabel.new( @top_window ) { text 'Credits:' ; grid( 'row'=>3, 'column'=>1, 'sticky'=>'ew' ) }
			@credits_lineedit_text = TkVariable.new( values['credits'] )
			@credits_lineedit = TkEntry.new( @top_window, 'textvariable'=>@credits_lineedit_text ) do
				grid( 'row'=>3, 'column'=>2, 'sticky'=>'ew' )
			end

			TkLabel.new( @top_window ) { text 'Lyricist:' ; grid( 'row'=>3, 'column'=>3, 'sticky'=>'ew' ) }
			@lyricist_lineedit_text = TkVariable.new( values['lyricist'] )
			@lyricist_lineedit = TkEntry.new( @top_window, 'textvariable'=>@lyricist_lineedit_text ) do
				grid('row'=>3, 'column'=>4, 'sticky'=>'ew' )
			end

			TkLabel.new( @top_window ) { text 'Year:' ; grid( 'row'=>4, 'column'=>1, 'sticky'=>'ew') }
			@year_spinbox_text = TkVariable.new( values['year'] )
			@year_spinbox = TkSpinbox.new(@top_window, 'textvariable'=>@year_spinbox_text, 'from'=>1900, 'to'=>Date.today().year) do
				grid( 'row'=>4, 'column'=>2, 'sticky'=>'ew' )
			end

			TkLabel.new( @top_window ) { text 'Album:' ; grid( 'row'=>4, 'column'=>3, 'sticky'=>'ew' ) }
			@album_lineedit_text = TkVariable.new( values['album'] )
			@album_lineedit = TkEntry.new( @top_window, 'textvariable'=>@album_lineedit_text ) do
				grid( 'row'=>4, 'column'=>4, 'sticky'=>'ew' )
			end

			proc_instrumental_toggled = proc { toggle_instrumental_checked() }
			@instrumental_checkbox = TkCheckButton.new( @top_window ) { command proc_instrumental_toggled }
			@instrumental_checkbox.grid( 'row'=>5, 'column'=>1, 'columnspan'=>3, 'sticky'=>'w' )
			@instrumental_checkbox.text = 'Instrumental piece'
			@instrumental_checkbox.set_value( values['instrumental'].to_s() == 'true' )

			lyrics_frame = TkFrame.new( @top_window )
			lyrics_frame.grid( 'row'=>6, 'column'=>1, 'columnspan'=>4, 'sticky'=>'nesw' )
			bar = TkScrollbar.new( lyrics_frame, 'orient'=>'ver' )
			bar.pack( 'side'=>'right', 'fill'=>'y' )
			@lyrics_text = TkText.new( lyrics_frame ) do
				yscrollcommand { |first, last| bar.set( first, last ) }
				width 80
				height 20
				pack( 'side'=>'left', 'fill'=>'both', 'expand'=>true )
			end
			@lyrics_text.insert( 'end', values['lyrics'] )
			bar.command( proc { |*args| @lyrics_text.yview(*args) } )
 			toggle_instrumental_checked()

			@autogen_checkbox = TkCheckButton.new( @top_window )
			@autogen_checkbox.grid( 'row'=>7, 'column'=>1, 'columnspan'=>4, 'sticky'=>'w' );
			@autogen_checkbox.set_value( true )
			@autogen_checkbox.text = 'Add to auto-generated category (leave checked if you haven\'t reviewed this form!)'

			create_action_buttons( 8, 'split', 'Submit' )

			@top_window.grid_rowconfigure( 6, 'weight'=>1 )
			4.times { |idx| @top_window.grid_columnconfigure( idx+1, 'weight'=>1 ) }
		end

		def toggle_instrumental_checked()
			state = @instrumental_checkbox.get_value() == '0' ? 'normal' : 'disabled'
			puts state.upcase
			@lyrics_text.state = state
		end

		def accept()
			@values = {
				'url'			=> @url_lineedit_text.value(),
				'artist'		=> @artist_lineedit_text.value(),
				'year'			=> @year_spinbox_text.value(),
				'album'			=> @album_lineedit_text.value(),
				'song'			=> @song_lineedit_text.value(),
				'lyrics'		=> @lyrics_text.value(),
				'instrumental'	=> @instrumental_checkbox.get_value() != '0',
				'lyricist'		=> @lyricist_lineedit_text.value(),
				'credits'		=> @credits_lineedit_text.value(),
				'autogen'		=> @autogen_checkbox.get_value() != '0'
			}
			super()
		end

	end


	class WikiLyricsSubmitAlbumDialog < BaseDialog

		def initialize( values )
			super( values )
			set_size( 600, 400 )
		end

		def create_contents()
			@top_window.title( values['script_name'] + ' - Submit album page' )

			TkLabel.new( @top_window ) { text 'URL:' ; grid( 'row'=>1, 'column'=>1 ) }
			@url_lineedit_text = TkVariable.new( values['url'] )
			@url_lineedit = TkEntry.new( @top_window, 'textvariable'=>@url_lineedit_text ) do
				grid( 'row'=>1, 'column'=>2, 'columnspan'=>3, 'sticky'=>'ew' )
			end

			TkLabel.new( @top_window ) { text 'Artist:' ; grid( 'row'=>2, 'column'=>1, 'sticky'=>'ew' ) }
			@artist_lineedit_text = TkVariable.new( values['artist'] )
			@artist_lineedit = TkEntry.new( @top_window, 'textvariable'=>@artist_lineedit_text ) do
				grid( 'row'=>2, 'column'=>2, 'columnspan'=>3, 'sticky'=>'ew' )
			end

			TkLabel.new( @top_window ) { text 'Released:' ; grid( 'row'=>3, 'column'=>1, 'sticky'=>'ew') }
			@released_lineedit_text = TkVariable.new( values['released'] )
			@released_lineedit = TkEntry.new(@top_window, 'textvariable'=>@released_lineedit_text ) do
				grid( 'row'=>3, 'column'=>2, 'sticky'=>'ew' )
			end

			TkLabel.new( @top_window ) { text 'Album:' ; grid( 'row'=>3, 'column'=>3, 'sticky'=>'ew' ) }
			@album_lineedit_text = TkVariable.new( values['album'] )
			@album_lineedit = TkEntry.new( @top_window, 'textvariable'=>@album_lineedit_text ) do
				grid( 'row'=>3, 'column'=>4, 'sticky'=>'ew' )
			end


			TkLabel.new( @top_window ) { text 'Image path:' ; grid( 'row'=>4, 'column'=>1, 'sticky'=>'ew' ) }

			image_frame = TkFrame.new( @top_window )
			image_frame.grid( 'row'=>4, 'column'=>2, 'columnspan'=>3, 'sticky'=>'ew' )

			@image_path_lineedit_text = TkVariable.new( @values.include?('image_path') ? @values['image_path'] : '(no need to upload album cover)' )
			state = @values.include?( 'image_path' ) ? 'normal' : 'disabled'
			@image_path_lineedit = TkEntry.new( image_frame, 'textvariable'=>@image_path_lineedit_text ) do
				state "#{state}"
				pack( 'side'=>'left', 'fill'=>'both', 'expand'=>true )
			end

			if ( values.include?( 'image_path' ) )
				proc_browse_image = proc { browse_image() }
				@image_button = TkButton.new( image_frame ) do
					text '...'
					command proc_browse_image
					pack( 'side'=>'right' )
				end
			end

			tracks_frame = TkFrame.new( @top_window )
			tracks_frame.grid( 'row'=>5, 'column'=>1, 'columnspan'=>4, 'sticky'=>'nesw' )
			bar = TkScrollbar.new( tracks_frame, 'orient'=>'ver' )
			bar.pack( 'side'=>'right', 'fill'=>'y' )
			@tracks_text = TkText.new( tracks_frame ) do
				yscrollcommand { |first, last| bar.set( first, last ) }
				width 80
				height 20
				pack( 'side'=>'left', 'fill'=>'both', 'expand'=>true )
			end
			@tracks_text.insert( 'end', values['tracks'] )
			bar.command( proc { |*args| @tracks_text.yview(*args) } )

			@autogen_checkbox = TkCheckButton.new( @top_window )
			@autogen_checkbox.grid( 'row'=>6, 'column'=>1, 'columnspan'=>4, 'sticky'=>'w' );
			@autogen_checkbox.set_value( true )
			@autogen_checkbox.text = 'Add to auto-generated category (leave checked if you haven\'t reviewed this form!)'

			create_action_buttons( 7, 'split', 'Submit' )

			@top_window.grid_rowconfigure( 5, 'weight'=>1 )
			4.times { |idx| @top_window.grid_columnconfigure( idx+1, 'weight'=>2 ) }
		end

		def browse_image()
			dirname = @image_path_lineedit_text.value().strip()
			dirname = Strings.empty?( dirname ) ? (ENV['HOME'] ? ENV['HOME'] : '.') : File.dirname( dirname )
			image_path = Tk.getOpenFile( {
				'parent' => @top_window,
				'title' => 'Select album image path',
				'initialdir' => dirname,
				'filetypes' =>  [['Images', '.jpg .JPG .png .PNG .bmp .BMP'], ['All Files', '*']]
			} )
			@image_path_lineedit_text.set_value( image_path.strip() ) if ( ! Strings.empty?( image_path ) )
		end

		def accept()
			aux = {
				'url'		=> @url_lineedit_text.value(),
				'artist'	=> @artist_lineedit_text.value(),
				'released'	=> @released_lineedit_text.value(),
				'album'		=> @album_lineedit_text.value(),
				'tracks'	=> @tracks_text.value(),
				'autogen'	=> @autogen_checkbox.get_value() != '0'
			}
			aux['image_path'] = @image_path_lineedit_text.value() if ( @values.include?( 'image_path' ) )
			@values = aux
			super()
		end

	end


	class UploadCoverDialog < BaseDialog

		def initialize( values )
			super( values )
			set_size( 380, 180 )
		end

		def create_contents()
			@top_window.title( "#{values['script_name']} - Upload album cover" )

			TkLabel.new( @top_window ) do
				text 'Album'
				grid( 'row'=>1, 'column'=>1, 'sticky'=>'w' )
			end

			TkLabel.new( @top_window ) do
				text 'Artist:'
				grid( 'row'=>2, 'column'=>1 )
			end

			@artist_var = TkVariable.new( @values['artist'] )
			@artist_lineedit = TkEntry.new( @top_window, 'textvariable'=>@artist_var ) do
				grid( 'row'=>2, 'column'=>2, 'sticky'=>'ew' )
			end

			TkLabel.new( @top_window ) do
				text 'Album:'
				grid( 'row'=>3, 'column'=>1 )
			end
			@album_var = TkVariable.new( @values['album'] )
			@album_lineedit = TkEntry.new( @top_window, 'textvariable'=>@album_var ) do
				grid( 'row'=>3, 'column'=>2, 'sticky'=>'ew' )
			end

			TkLabel.new( @top_window ) do
				text 'Year:'
				grid( 'row'=>4, 'column'=>1 )
			end
			@year_var = TkVariable.new( values['year'] )
			@year_spinbox = TkSpinbox.new(@top_window, 'textvariable'=>@year_var, 'from'=>1900, 'to'=>Date.today().year) do
				grid( 'row'=>4, 'column'=>2, 'sticky'=>'ew' )
			end

			TkLabel.new( @top_window ) do
				text 'Image'
				grid( 'row'=>6, 'column'=>1, 'columnspan'=>2, 'sticky'=>'w' )
			end

			TkLabel.new( @top_window ) do
				text 'Path:'
				grid( 'row'=>7, 'column'=>1, 'sticky'=>'ew' )
			end

			image_frame = TkFrame.new( @top_window )
			image_frame.grid( 'row'=>7, 'column'=>2, 'sticky'=>'ew' )
			@image_path_var = TkVariable.new( @values['image_path'] )
			@image_path_lineedit = TkEntry.new( image_frame, 'textvariable'=>@image_path_var ) do
				pack( 'side'=>'left', 'fill'=>'both', 'expand'=>true )
			end

			proc_browse_image = proc { browse_image() }
			@image_button = TkButton.new( image_frame ) do
				text '...'
				command proc_browse_image
				pack( 'side'=>'right' )
			end

			create_action_buttons( 9 )

			@top_window.grid_rowconfigure( 5, 'weight'=>1 )
			@top_window.grid_rowconfigure( 8, 'weight'=>1 )
			@top_window.grid_columnconfigure( 2, 'weight'=>1 )
		end

		def browse_image()
			dirname = @image_path_var.value().strip()
			dirname = Strings.empty?( dirname ) ? (ENV['HOME'] ? ENV['HOME'] : '.') : File.dirname( dirname )
			image_path = Tk.getOpenFile( {
				'parent' => @top_window,
				'title' => 'Select album image path',
				'initialdir' => dirname,
				'filetypes' =>  [['Images', '.jpg .JPG .png .PNG .bmp .BMP'], ['All Files', '*']]
			} )
			@image_path_var.set_value( image_path.strip() ) if ( ! Strings.empty?( image_path ) )
		end

		def accept()
			@values = {
				'artist'		=> @artist_var.value(),
				'album'			=> @album_var.value(),
				'year'			=> @year_var.value(),
				'image_path'	=> @image_path_var.value()
			}
			super()
		end

	end


	class LyrixAtConfigDialog < BaseDialog

		def initialize( values )
			super( values )
			set_size( 300, 100 )
		end

		def create_contents()
			@top_window.title( 'Configure Lyrix.At settings' )

			TkLabel.new( @top_window ) do
				text 'Login Settings'
				grid( 'row'=>1, 'column'=>1, 'columnspan'=>2, 'sticky'=>'w' )
			end

			TkLabel.new( @top_window ) do
				text 'Username:'
				grid( 'row'=>2, 'column'=>1 )
			end

			@username_var = TkVariable.new( @values['username'] )
			@username_lineedit = TkEntry.new( @top_window, 'textvariable'=>@username_var ) do
				grid( 'row'=>2, 'column'=>2, 'columnspan'=>2, 'sticky'=>'ew' )
			end

			TkLabel.new( @top_window ) do
				text 'Password:'
				grid( 'row'=>3, 'column'=>1 )
			end
			@password_var = TkVariable.new( @values['password'] )
			@password_lineedit = TkEntry.new( @top_window, 'textvariable'=>@password_var, 'show'=>'*' ) do
				grid( 'row'=>3, 'column'=>2, 'columnspan'=>2, 'sticky'=>'ew' )
			end

			create_action_buttons( 5 )

			@top_window.grid_rowconfigure( 4, 'weight'=>1 )
			@top_window.grid_columnconfigure( 2, 'weight'=>1 )
			@top_window.grid_columnconfigure( 3, 'weight'=>1 )
		end

		def accept()
			@values = {
				'username' => @username_var.value(),
				'password' => @password_var.value(),
			}
			super()
		end

	end


	class SearchLyricsDialog < BaseDialog

		def initialize( values )
			super( values )
			set_size( 300, 140 )
		end

		def create_contents()
			@top_window.title( 'Search Lyrics' )

			TkLabel.new( @top_window ) do
				text 'Search Settings'
				grid( 'row'=>1, 'column'=>1, 'columnspan'=>2, 'sticky'=>'w' )
			end

			TkLabel.new( @top_window ) do
				text 'Artist:'
				grid( 'row'=>2, 'column'=>1 )
			end

			@artist_var = TkVariable.new( @values['artist'] )
			@artist_lineedit = TkEntry.new( @top_window, 'textvariable'=>@artist_var ) do
				grid( 'row'=>2, 'column'=>2, 'columnspan'=>2, 'sticky'=>'ew' )
			end

			TkLabel.new( @top_window ) do
				text 'Title:'
				grid( 'row'=>3, 'column'=>1 )
			end
			@title_var = TkVariable.new( @values['title'] )
			@title_lineedit = TkEntry.new( @top_window, 'textvariable'=>@title_var ) do
				grid( 'row'=>3, 'column'=>2, 'columnspan'=>2, 'sticky'=>'ew' )
			end

			TkLabel.new( @top_window ) do
				text 'Album:'
				grid( 'row'=>4, 'column'=>1 )
			end
			@album_var = TkVariable.new( @values['album'] )
			@album_lineedit = TkEntry.new( @top_window, 'textvariable'=>@album_var ) do
				grid( 'row'=>4, 'column'=>2, 'columnspan'=>2, 'sticky'=>'ew' )
			end

			TkLabel.new( @top_window ) do
				text 'Year:'
				grid( 'row'=>5, 'column'=>1 )
			end
			@year_var = TkVariable.new( values['year'] )
			@year_spinbox = TkSpinbox.new(@top_window, 'textvariable'=>@year_var, 'from'=>1900, 'to'=>Date.today().year) do
				grid( 'row'=>5, 'column'=>2, 'columnspan'=>2, 'sticky'=>'ew' )
			end

			create_action_buttons( 7 )

			@top_window.grid_rowconfigure( 6, 'weight'=>1 )
			@top_window.grid_columnconfigure( 2, 'weight'=>1 )
			@top_window.grid_columnconfigure( 3, 'weight'=>1 )
		end

		def accept()
			@values = {
				'artist'	=> @artist_var.value(),
				'title'		=> @title_var.value(),
				'album'		=> @album_var.value(),
				'year'		=> @year_var.value(),
			}
			super()
		end

	end


	class LyricsDialog < BaseDialog

		def initialize( values )
			super( values )
			set_size( 400, 400 )
		end

		def create_contents()

			title = "Lyrics to '#{@values['title']}' by '#{@values['artist']}'"
			title += " [#{@values['site']}]" if @values['site']
			@top_window.title( title )
			lyrics_frame = TkFrame.new( @top_window )
			lyrics_frame.grid( 'row'=>1, 'column'=>1, 'sticky'=>'nesw' )
			bar = TkScrollbar.new( lyrics_frame, 'orient'=>'ver' )
			bar.pack( 'side'=>'right', 'fill'=>'y' )
			bar.command( proc { |*args| @lyrics_text.yview( *args ) } )
			@lyrics_text = TkText.new( lyrics_frame ) do
				yscrollcommand { |first, last| bar.set( first, last ) }
				width 60
				height 20
				pack( 'side'=>'left', 'fill'=>'both', 'expand'=>true )
			end
			@lyrics_text.pack()
			@lyrics_text.insert( 'end', @values['lyrics'] )

			@top_window.grid_rowconfigure( 1, 'weight'=>1 )
			@top_window.grid_columnconfigure( 1, 'weight'=>1 )
		end

	end

end
