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
require 'Qt'

$KCODE='u'

module QT

	class BaseDialog < Qt::Dialog

		attr_reader :values

		def initialize( values )
			super( nil )
			@values = values
		end

		def create_action_buttons( mode='right', accept_text='Accept', cancel_text='Cancel' )
			accept_text = Strings.empty?( accept_text ) ? 'Accept' : accept_text
			cancel_text = Strings.empty?( cancel_text ) ? 'Cancel' : cancel_text
			@accept_button = Qt::PushButton.new( accept_text, self )
			@cancel_button = Qt::PushButton.new( cancel_text, self )
			connect( @accept_button, SIGNAL( 'clicked()' ), self, SLOT( 'accept()' ) )
			connect( @cancel_button, SIGNAL( 'clicked()' ), self, SLOT( 'reject()' ) )
			if ( mode == 'left' )
				hbox = Qt::HBoxLayout.new( 4 )
 				hbox.setDirection( Qt::BoxLayout::LeftToRight )
				hbox.addWidget( @accept_button )
				hbox.addWidget( @cancel_button )
				hbox.addStretch()
			elsif ( mode == 'split' )
				hbox = Qt::HBoxLayout.new( 4 )
				hbox.addWidget( @accept_button, 1 )
				hbox.addWidget( @cancel_button, 1 )
			else
				hbox = Qt::HBoxLayout.new( 4 )
				hbox.addStretch()
				hbox.addWidget( @accept_button )
				hbox.addWidget( @cancel_button )
			end
			return hbox
		end
		protected :create_action_buttons

		def accepted()
			return result() == Qt::Dialog.Accepted
		end
	end

	class MetaLyricsConfigDialog < BaseDialog

		slots 'move_up()', 'move_down()', 'add_script()', 'remove_script()'

		def initialize( values )
			super( values )

			setCaption( @values['script'] + ' script configuration' )

			vbox = Qt::VBoxLayout.new( self, 5 )

			group = Qt::GroupBox.new( 'Scripts priority', self )

			@used_scripts_list = Qt::ListView.new( group )
			@used_scripts_list.setSelectionMode( Qt::ListView::Single )
			@used_scripts_list.addColumn( 'Currently used', -1 )
			@used_scripts_list.setResizeMode( Qt::ListView::LastColumn )
			@used_scripts_list.setSorting( -1 )
			@values['used_scripts'].reverse().each() do |script|
				item = Qt::ListViewItem.new( @used_scripts_list, script )
				@used_scripts_list.insertItem( item )
			end

			@unused_scripts_list = Qt::ListView.new( group )
			@unused_scripts_list.setSelectionMode( Qt::ListView::Single )
			@unused_scripts_list.addColumn( 'Available', -1 )
			@unused_scripts_list.setResizeMode( Qt::ListView::LastColumn )
			@unused_scripts_list.setSorting( -1 )
			@values['unused_scripts'].reverse().each() do |script|
				item = Qt::ListViewItem.new( @unused_scripts_list, script )
				@unused_scripts_list.insertItem( item )
			end

			@add_button = Qt::PushButton.new( '<< Add', group )
			@remove_button = Qt::PushButton.new( 'Remove >>', group )

			@move_up_button = Qt::PushButton.new( 'Up', group )
			@move_down_button = Qt::PushButton.new( 'Down', group )

			group_grid = Qt::GridLayout.new( group, 5, 4, 5 )
			group_grid.setRowSpacing( 0, 12 )
			group_grid.setColStretch( 1, 1 )
			group_grid.setColStretch( 3, 1 )
			group_grid.setRowStretch( 1, 1 )
			group_grid.setRowStretch( 4, 1 )

			group_grid.addWidget( @move_up_button, 2, 0 )
			group_grid.addWidget( @move_down_button, 3, 0 )

			group_grid.addMultiCellWidget( @used_scripts_list, 1, 4, 1, 1 )

			group_grid.addWidget( @add_button, 2, 2 )
			group_grid.addWidget( @remove_button, 3, 2 )

			group_grid.addMultiCellWidget( @unused_scripts_list, 1, 4, 3, 3 )

			vbox.addWidget( group )

			group = Qt::GroupBox.new( 1, Qt::Horizontal, 'Miscellaneous', self )
			@cleanup_lyrics_checkbox = Qt::CheckBox.new( group )
			@cleanup_lyrics_checkbox.setChecked( values['cleanup_lyrics'].to_s() == 'true' )
			@cleanup_lyrics_checkbox.setText( 'Clean up retrieved lyrics' )
			vbox.addWidget( group )

			buttons = create_action_buttons()
			vbox.addLayout( buttons )

			connect( @move_up_button, SIGNAL('clicked()'), self, SLOT('move_up()') )
			connect( @move_down_button, SIGNAL('clicked()'), self, SLOT('move_down()') )
			connect( @add_button, SIGNAL('clicked()'), self, SLOT('add_script()') )
			connect( @remove_button, SIGNAL('clicked()'), self, SLOT('remove_script()') )

			resize( 350, 230 )
		end

		# workaround for buggy qlistview (works as expected only when sorting is disabled)
		def list_view_move_item( list_view, item, after )
			return if ( item == after )
			if ( after == nil )
				list_view.takeItem( item )
				list_view.insertItem( item )
			else
				item.moveItem( after )
			end
		end

		def move_up()
			cur_item = @used_scripts_list.currentItem()
			return if ( cur_item == nil )
			prev_item = cur_item.itemAbove()
			return if ( prev_item == nil )
			prev_item = prev_item.itemAbove()
			list_view_move_item( @used_scripts_list, cur_item, prev_item )
			@used_scripts_list.setCurrentItem( cur_item )
		end

		def move_down()
			cur_item = @used_scripts_list.currentItem()
			return if ( cur_item == nil )
			next_item = cur_item.itemBelow()
			return if ( next_item == nil )
			list_view_move_item( @used_scripts_list, cur_item, next_item )
			@used_scripts_list.setCurrentItem( cur_item )
		end

		def add_script()
			unused_cur_item = @unused_scripts_list.currentItem()
			return if ( unused_cur_item == nil )
			@unused_scripts_list.takeItem( unused_cur_item )
			@used_scripts_list.insertItem( unused_cur_item )
			list_view_move_item( @used_scripts_list, unused_cur_item, @used_scripts_list.lastItem() )
			@used_scripts_list.setCurrentItem( unused_cur_item )
		end

		def remove_script()
			used_cur_item = @used_scripts_list.currentItem()
			return if ( used_cur_item == nil )
			@used_scripts_list.takeItem( used_cur_item )
			@unused_scripts_list.insertItem( used_cur_item )
			list_view_move_item( @unused_scripts_list, used_cur_item, @unused_scripts_list.lastItem() )
			@unused_scripts_list.setCurrentItem( used_cur_item )
		end

		def accept()
			@values = {
				'script' => @values['script'],
				'cleanup_lyrics' => @cleanup_lyrics_checkbox.isChecked(),
				'used_scripts' => [],
				'unused_scripts' => []
			}
			child = @used_scripts_list.firstChild()
			while ( child != nil )
				@values['used_scripts'].insert( -1, child.text( 0 ) )
				child = child.itemBelow()
			end
			child = @unused_scripts_list.firstChild()
			while ( child != nil )
				@values['unused_scripts'].insert( -1, child.text( 0 ) )
				child = child.itemBelow()
			end
			super()
		end

	end


	class WikiLyricsConfigDialog < BaseDialog

		slots 'toggle_submit_checked( bool )'
		slots 'toggle_review_checked( bool )'

		def initialize( values )
			super( values )

			setCaption( "Configure #{values['script_name']} settings" )

			layout = Qt::GridLayout.new( self, 1, 1, 5 )

			group = Qt::GroupBox.new( 'General Settings', self )
			group.setColumnLayout( 0, Qt::Vertical )
			group.layout().setSpacing( 5 )
			group_layout = Qt::GridLayout.new( group.layout() )
			group_layout.setAlignment( Qt::AlignTop )

			@submit_checkbox = Qt::CheckBox.new( group )
			@submit_checkbox.setChecked( values['submit'].to_s() == 'true' )
			@submit_checkbox.setText( "Submit contents to #{values['script_name']}" )
			group_layout.addMultiCellWidget( @submit_checkbox, 0, 0, 0, 1 )

			@review_checkbox = Qt::CheckBox.new( group )
			@review_checkbox.setEnabled( @submit_checkbox.isChecked() )
			@review_checkbox.setChecked( @review_checkbox.isEnabled() && values['review'].to_s() == 'true' )
			@review_checkbox.setText( 'Prompt for review before submitting contents' )
			group_layout.addMultiCellWidget( @review_checkbox, 1, 1, 0, 1 )

			@prompt_autogen_checkbox = Qt::CheckBox.new( group )
			@prompt_autogen_checkbox.setEnabled( @review_checkbox.isChecked() )
			@prompt_autogen_checkbox.setChecked( @prompt_autogen_checkbox.isEnabled() && values['prompt_autogen'].to_s() == 'true' )
			@prompt_autogen_checkbox.setText( 'Edit song pages marked as autogenerated' )
			group_layout.addMultiCellWidget( @prompt_autogen_checkbox, 2, 2, 0, 1 )

			@prompt_new_checkbox = Qt::CheckBox.new( group )
			@prompt_new_checkbox.setEnabled( @review_checkbox.isChecked() )
			@prompt_new_checkbox.setChecked( @prompt_new_checkbox.isEnabled() && values['prompt_new'].to_s() == 'true' )
			@prompt_new_checkbox.setText( 'Show submit dialog even if no lyrics were found' )
			group_layout.addMultiCellWidget( @prompt_new_checkbox, 3, 3, 0, 1 )

			layout.addMultiCellWidget( group, 0, 0, 0, 2 )

			group = Qt::GroupBox.new( 'Login Settings', self )
			group.setColumnLayout( 0, Qt::Vertical )
			group.layout().setSpacing( 5 )
			group_layout = Qt::GridLayout.new( group.layout() )
			group_layout.setAlignment( Qt::AlignTop )

			label = Qt::Label.new( '<b>Username</b>', group )
			group_layout.addWidget( label, 1, 0 );

			@username_lineedit = Qt::LineEdit.new( values['username'], group )
			group_layout.addWidget( @username_lineedit, 1, 1 );

			label = Qt::Label.new( '<b>Password</b>', group )
			group_layout.addWidget( label, 2, 0 )

			@password_lineedit = Qt::LineEdit.new( values['password'], group )
			@password_lineedit.setEchoMode( Qt::LineEdit::Password )
			group_layout.addWidget( @password_lineedit, 2, 1 )

			layout.addMultiCellWidget( group, 1, 1, 0, 2 )

			stretch = Qt::SpacerItem.new( 81, 20, Qt::SizePolicy::Expanding, Qt::SizePolicy::Minimum )
			layout.addItem( stretch, 2, 0 );

			buttons = create_action_buttons()
			layout.addMultiCellLayout( buttons, 2, 2, 0, 2 )

			connect( @submit_checkbox, SIGNAL('toggled(bool)'), self, SLOT('toggle_submit_checked(bool)') )
			connect( @review_checkbox, SIGNAL('toggled(bool)'), self, SLOT('toggle_review_checked(bool)') )

			resize( 300, 50 )
		end

		def toggle_submit_checked( checked )
			@review_checkbox.setEnabled( checked )
			if ( !checked )
				@review_checkbox.setChecked( false )
				@prompt_autogen_checkbox.setChecked( false )
				@prompt_new_checkbox.setChecked( false )
			end
		end

		def toggle_review_checked( checked )
			@prompt_autogen_checkbox.setEnabled( checked )
			@prompt_new_checkbox.setEnabled( checked )
			if ( !checked )
				@prompt_autogen_checkbox.setChecked( false )
				@prompt_new_checkbox.setChecked( false )
			end
		end

		def accept()
			@values = {
				'submit'			=> @submit_checkbox.isChecked(),
				'review'			=> @review_checkbox.isChecked(),
				'prompt_autogen'	=> @prompt_autogen_checkbox.isChecked(),
				'prompt_new'		=> @prompt_new_checkbox.isChecked(),
				'username'			=> @username_lineedit.text(),
				'password'			=> @password_lineedit.text(),
			}
			super()
		end

	end

	class WikiLyricsSubmitSongDialog < BaseDialog

		slots 'toggle_instrumental_checked( bool )'

		def initialize( values )
			super( values )

			edit_mode = @values['edit_mode'].to_s() == 'true'
			setCaption( values['script_name'] + (edit_mode ? ' - Edit song page' : ' - Submit song page') )

			@url_lineedit = Qt::LineEdit.new( values['url'], self )
			@url_lineedit.setEnabled( !edit_mode )

			@artist_lineedit = Qt::LineEdit.new( values['artist'], self )
			@song_lineedit = Qt::LineEdit.new( values['song'], self )

			@credits_lineedit = Qt::LineEdit.new( values['credits'], self )
			@lyricist_lineedit = Qt::LineEdit.new( values['lyricist'], self )

			@year_spinbox = Qt::SpinBox.new( self )
			@year_spinbox.setMinValue( 1900 )
			@year_spinbox.setMaxValue( Date.today().year )
			@year_spinbox.setValue( values['year'] )
			@album_lineedit = Qt::LineEdit.new( values['album'], self )

			@instrumental_checkbox = Qt::CheckBox.new( self )
			@instrumental_checkbox.setChecked( @values['instrumental'].to_s() == 'true' )
			@instrumental_checkbox.setText( 'Instrumental piece' )

			@lyrics_text = Qt::TextEdit.new( self )
			@lyrics_text.setText( values['lyrics'] )
			@lyrics_text.setDisabled( @instrumental_checkbox.isChecked() )

			@autogen_checkbox = Qt::CheckBox.new( self )
			@autogen_checkbox.setChecked( true )
			@autogen_checkbox.setText( 'Add to auto-generated category (leave checked if you haven\'t reviewed this form!)' )

			grid = Qt::GridLayout.new( self, 9, 5, 5 )
			grid.addColSpacing( 2, 15 )

			grid.addWidget( Qt::Label.new( '<b>URL</b>', self ), 0, 0, Qt::AlignRight )
			grid.addMultiCellWidget( @url_lineedit, 0, 0, 1, 4 )

			grid.addWidget( Qt::Label.new( '<b>Artist</b>', self ), 1, 0, Qt::AlignRight )
			grid.addWidget( @artist_lineedit, 1, 1 )
			grid.addWidget( Qt::Label.new( '<b>Song</b>', self ), 1, 3, Qt::AlignRight )
			grid.addWidget( @song_lineedit, 1, 4 )

			grid.addWidget( Qt::Label.new( '<b>Credits</b>', self ), 2, 0, Qt::AlignRight )
			grid.addWidget( @credits_lineedit, 2, 1 )
			grid.addWidget( Qt::Label.new( '<b>Lyricist</b>', self ), 2, 3, Qt::AlignRight )
			grid.addWidget( @lyricist_lineedit, 2, 4 )

			grid.addWidget( Qt::Label.new( '<b>Year</b>', self ), 3, 0, Qt::AlignRight )
			grid.addWidget( @year_spinbox, 3, 1 )
			grid.addWidget( Qt::Label.new( '<b>Album</b>', self ), 3, 3, Qt::AlignRight )
			grid.addWidget( @album_lineedit, 3, 4 )

			grid.addMultiCellWidget( @instrumental_checkbox, 4, 4, 0, 4 )

			grid.addMultiCellWidget( @lyrics_text, 5, 5, 0, 4 )
			grid.addMultiCellWidget( @autogen_checkbox, 6, 6, 0, 4 )

			buttons = create_action_buttons( 'split', 'Submit' )
			grid.addMultiCellLayout( buttons, 7, 7, 0, 4 )

			resize( 600, 400 )

			connect( @instrumental_checkbox, SIGNAL('toggled(bool)'), self, SLOT('toggle_instrumental_checked(bool)') )

		end

		def toggle_instrumental_checked( checked )
			@lyrics_text.setDisabled( checked )
		end

		def accept()
			@values = {
				'url'			=> @url_lineedit.text(),
				'artist'		=> @artist_lineedit.text(),
				'year'			=> @year_spinbox.value(),
				'album'			=> @album_lineedit.text(),
				'song'			=> @song_lineedit.text(),
				'lyrics'		=> @lyrics_text.text(),
				'instrumental'	=> @instrumental_checkbox.isChecked(),
				'lyricist'		=> @lyricist_lineedit.text(),
				'credits'		=> @credits_lineedit.text(),
				'autogen'		=> @autogen_checkbox.isChecked()
			}
			super()
		end

	end

	class WikiLyricsSubmitAlbumDialog < BaseDialog

		slots 'browse_image()'

		def initialize( values )
			super( values )

			@values = values

			setCaption( values['script_name'] + ' - Submit album page' )

			@url_lineedit = Qt::LineEdit.new( values['url'], self )

			@artist_lineedit = Qt::LineEdit.new( values['artist'], self )

			@released_lineedit = Qt::LineEdit.new( values['released'], self )
			@album_lineedit = Qt::LineEdit.new( values['album'], self )

			@image_path_lineedit = Qt::LineEdit.new( values['image_path'], self )
			if ( ! values.include?( 'image_path' ) )
				@image_path_lineedit.setEnabled( false )
				@image_path_lineedit.setText( '(no need to upload album cover)' )
			else
				@image_button = Qt::PushButton.new( '...', self )
				connect( @image_button, SIGNAL( 'clicked()' ), self, SLOT( 'browse_image()' ) )
			end

			@tracks_text = Qt::TextEdit.new( self )
			@tracks_text.setWordWrap( Qt::TextEdit::NoWrap )
			@tracks_text.setTextFormat( Qt::PlainText )
			@tracks_text.setText( values['tracks'] )

			@autogen_checkbox = Qt::CheckBox.new( self )
			@autogen_checkbox.setChecked( true )
			@autogen_checkbox.setText( 'Add to auto-generated category (leave checked if you haven\'t reviewed this form!)' )

			grid = Qt::GridLayout.new( self, 9, 5, 5 )
			grid.addColSpacing( 2, 15 )

			grid.addWidget( Qt::Label.new( '<b>URL</b>', self ), 0, 0, Qt::AlignRight )
			grid.addMultiCellWidget( @url_lineedit, 0, 0, 1, 4 )

			grid.addWidget( Qt::Label.new( '<b>Artist</b>', self ), 1, 0, Qt::AlignRight )
			grid.addMultiCellWidget( @artist_lineedit, 1, 1, 1, 4 )

			grid.addWidget( Qt::Label.new( '<b>Released</b>', self ), 2, 0, Qt::AlignRight )
			grid.addWidget( @released_lineedit, 2, 1 )
			grid.addWidget( Qt::Label.new( '<b>Album</b>', self ), 2, 3, Qt::AlignRight )
			grid.addWidget( @album_lineedit, 2, 4 )

			label = Qt::Label.new( '<b>Image path</b>', self )
			label.setAlignment( Qt::AlignLeft )
			grid.addWidget( label, 3, 0, Qt::AlignRight )
			img_hbox = Qt::HBoxLayout.new( 5 )
			img_hbox.addWidget( @image_path_lineedit )
			img_hbox.addWidget( @image_button ) if ( @values.include?( 'image_path' ) )
			grid.addMultiCellLayout( img_hbox, 3, 3, 1, 4 )

			grid.addMultiCellWidget( @tracks_text, 4, 4, 0, 4 )
			grid.addMultiCellWidget( @autogen_checkbox, 5, 5, 0, 4 )

			buttons = create_action_buttons( 'split', 'Submit' )
			grid.addMultiCellLayout( buttons, 6, 6, 0, 4 )

			resize( 600, 400 )
		end

		def browse_image()
			dirname = @image_path_lineedit.text().strip()
			dirname = Strings.empty?( dirname ) ? (ENV['HOME'] ? ENV['HOME'] : '.') : File.dirname( dirname )
			dialog = Qt::FileDialog.new( dirname, "Images (*.jpg *.JPG *.png *.PNG *.bmp *.BMP);;All Files (*)", self, nil, true )
			dialog.setCaption( 'Select album image path' )
			dialog.setMode( Qt::FileDialog::ExistingFile )
			 if ( dialog.exec() == Qt::Dialog::Accepted )
        		image_path = dialog.selectedFile()
				@image_path_lineedit.setText( image_path.strip() ) if ( ! Strings.empty?( image_path ) )
			end
		end

		def accept()
			aux = {
				'url'		=> @url_lineedit.text(),
				'artist'	=> @artist_lineedit.text(),
				'released'	=> @released_lineedit.text(),
				'album'		=> @album_lineedit.text(),
				'tracks'	=> @tracks_text.text(),
				'autogen'	=> @autogen_checkbox.isChecked()
			}
			aux['image_path'] = @image_path_lineedit.text() if ( @values.include?( 'image_path' ) )
			@values = aux
			super()
		end

	end


	class UploadCoverDialog < BaseDialog

		slots 'browse_image()'

		def initialize( values )
			super( values )

			setCaption( "#{values['script_name']} - Upload album cover" )

			vbox = Qt::VBoxLayout.new( self, 5 )

			group = Qt::GroupBox.new( 2, Qt::Horizontal, 'Album', self )

			Qt::Label.new( '<b>Artist</b>', group )
			@artist_lineedit = Qt::LineEdit.new( values['artist'], group )

			Qt::Label.new( '<b>Album</b>', group )
			@album_lineedit = Qt::LineEdit.new( values['album'], group )

			Qt::Label.new( '<b>Year</b>', group )
			@year_spinbox = Qt::SpinBox.new( group )
			@year_spinbox.setMinValue( 1900 )
			@year_spinbox.setMaxValue( Date.today().year() )
			@year_spinbox.setValue( values['year'] )

			vbox.addWidget( group )

			group = Qt::GroupBox.new( 3, Qt::Horizontal, 'Image', self )

			Qt::Label.new( '<b>Path</b>', group )
			@image_path_lineedit = Qt::LineEdit.new( values['image_path'], group )
			@image_path_lineedit.setText( values['image_path'] )

			@image_button = Qt::PushButton.new( '...', group )
			connect( @image_button, SIGNAL( 'clicked()' ), self, SLOT( 'browse_image()' ) )

			vbox.addWidget( group )

			buttons = create_action_buttons()
			vbox.addLayout( buttons )

			resize( 400, 100 )
		end

		def browse_image()
			dirname = @image_path_lineedit.text().strip()
			dirname = Strings.empty?( dirname ) ? (ENV['HOME'] ? ENV['HOME'] : '.') : File.dirname( dirname )
			dialog = Qt::FileDialog.new( dirname, "Images (*.jpg *.JPG *.png *.PNG *.bmp *.BMP);;All Files (*)", self, nil, true )
			dialog.setCaption( 'Select album image path' )
			dialog.setMode( Qt::FileDialog::ExistingFile )
			 if ( dialog.exec() == Qt::Dialog::Accepted )
        		image_path = dialog.selectedFile()
				@image_path_lineedit.setText( image_path.strip() ) if ( ! Strings.empty?( image_path ) )
			end
		end

		def accept()
			@values = {
				'artist'		=> @artist_lineedit.text(),
				'album'			=> @album_lineedit.text(),
				'year'			=> @year_spinbox.value(),
				'image_path'	=> @image_path_lineedit.text()
			}
			super()
		end

	end


	class LyrixAtConfigDialog < BaseDialog

		def initialize( values )
			super( values )

			setCaption( 'Configure Lyrix.At settings' )

			vbox = Qt::VBoxLayout.new( self, 5 )

			group = Qt::GroupBox.new( 2, Qt::Horizontal, 'Login Settings', self )
			Qt::Label.new( '<b>Username</b>', group )
			@username_lineedit = Qt::LineEdit.new( values['username'], group )
			Qt::Label.new( '<b>Password</b>', group )
			@password_lineedit = Qt::LineEdit.new( values['password'], group )
			@password_lineedit.setEchoMode( Qt::LineEdit::Password )
			vbox.addWidget( group )

			buttons = create_action_buttons()
			vbox.addLayout( buttons )

			resize( 300, 50 )
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

			setCaption( 'Search lyrics' )

			vbox = Qt::VBoxLayout.new( self, 5 )

			group = Qt::GroupBox.new( 2, Qt::Horizontal, 'Search Settings', self )

			Qt::Label.new( '<b>Artist</b>', group )
			@artist_lineedit = Qt::LineEdit.new( values['artist'], group )

			Qt::Label.new( '<b>Title</b>', group )
			@title_lineedit = Qt::LineEdit.new( values['title'], group )

			Qt::Label.new( '<b>Album</b>', group )
			@album_lineedit = Qt::LineEdit.new( values['album'], group )

			Qt::Label.new( '<b>Year</b>', group )
			@year_spinbox = Qt::SpinBox.new( group )
			@year_spinbox.setMinValue( 1900 )
			@year_spinbox.setMaxValue( Date.today().year() )
			@year_spinbox.setValue( values['year'] )

			vbox.addWidget( group )

			buttons = create_action_buttons()
			vbox.addLayout( buttons )

			resize( 300, 100 )
		end

		def accept()
			@values = {
				'artist' => @artist_lineedit.text(),
				'title'  => @title_lineedit.text(),
				'album'  => @album_lineedit.text(),
				'year'   => @year_spinbox.value(),
			}
			super()
		end

	end


	class LyricsDialog < BaseDialog

		def initialize( values )
			super( values )

			title = "Lyrics to '#{@values['title']}' by '#{@values['artist']}'"
			title += " [#{@values['site']}]" if @values['site']
			setCaption( title )

			@lyrics_text = Qt::TextEdit.new( self )
			@lyrics_text.setText( values['lyrics'] )

			grid = Qt::GridLayout.new( self, 1, 1, 5 )
			grid.addWidget( @lyrics_text, 0, 0 )

			resize( 400, 400 )
		end

	end

end
