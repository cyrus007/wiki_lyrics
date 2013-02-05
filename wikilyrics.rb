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
require 'lyrics'
require 'gui'
require 'md5'

class WikiLyrics < Lyrics

	@@NAME    = 'WL'
	@@VERSION = '0.9.2'

	@@FOLLOW_REDIRECTS = 3

	attr_reader :review, :username, :password
	attr_writer :review

	def initialize( cleanup_lyrics=true, log_file=$LOG_FILE, review=true, username=nil, password=nil )
		super( cleanup_lyrics, log_file )
		@logged_in = false
		@review = review
		@username = username
		@password = password
	end

	def logged_in?()
		return @logged_in
	end

	def build_lyrics_fetch_data( artist, title, album=nil, year=nil )
		return { 'url' => build_song_url( artist, title ) }
	end

	def db_error?( page_body )
		return /<!-- start content -->\s*A database query syntax error has occurred\.\s*This may indicate a bug in the software\.*/m.match( page_body ) != nil
	end
	protected :db_error?

	def fetch_lyrics_page( url, post )
		return nil if ( url == nil )
		url = url + '&action=raw&ctype=text/javascript'
		page_body = super( url, post )
		return nil if ( page_body == nil || db_error?( page_body ) )

		# work around pages that are redirects
		count = 0
		article = parse_url( url )
		while ( count < @@FOLLOW_REDIRECTS && (md = /#redirect \[\[([^\]]+)\]\]/i.match( page_body )) != nil )
			target_article = cleanup_article( md[1] )
			if ( article == target_article )
				log( "ERROR (circular redirect found)" ) if ( log?() )
				return nil
			end
			url = "http://#{lyrics_site()}/index.php?title=#{md[1].gsub(' ', '_')}&action=raw&ctype=text/javascript"
			log( "Found redirect page (#{count+1}), following link to #{url}... ", 0 ) if ( log?() )
			response = HTTP.fetch_page_get( url )
			if ( log?() )
				if ( response && response.body() )
					log( 'OK' )
					log( response.body(), 2 ) if ( long_log?() )
				else
					log( 'ERROR' )
				end
			end
			page_body = response ? response.body() : nil
			return nil if ( page_body == nil || db_error?( page_body ) )
			count = count + 1
			article = target_article
		end
		return page_body
	end

	def build_suggestions_fetch_data( artist, title, album=nil, year=nil )
		return { 'url' => build_song_search_url( artist, title ) }
	end

	def lyrics_from_url( url, artist, title, album=nil, year=nil )
		# we fetch wiki lyrics in raw mode so we need this specific format
		if ( ! url.index( 'index.php?title=' ) )
			if ( ! Strings.empty?( artist ) && ! Strings.empty?( title ) )
				url = build_song_url( artist, title )
			else
				a, t = self.class.parse_song_url( sugg['title'] )
				url = build_song_url( a, t )
			end
		end
		return super( url, artist, title, album, year )
	end

	def parse_suggestions( url, body, artist, title, album=nil, year=nil )
		suggestions = parse_search_results( body, true )
		idx = 0
		suggestions.size.times do
			sugg = suggestions[idx]
			sugg['artist'], sugg['title'] = self.class.parse_song_url( sugg['title'] )
			if ( Strings.empty?( sugg['artist'] ) || Strings.empty?( sugg['title'] ) || /\ \([0-9]{4,4}\)$/.match( sugg['title'] ) )
				suggestions.delete_at( idx )
			else
				idx += 1
			end
		end
		return suggestions
	end

	def login( username=@username, password=@password, force=false )

		return true if ( !force && @logged_in && username == @username && password == @password )
		@username, @password = username, password
		return false if ( @username == nil || @password == nil )

		headers = { 'Keep-Alive'=>'300', 'Connection'=>'keep-alive' }
		resp = HTTP.fetch_page_get( "http://#{lyrics_site()}/index.php?title=Special:Userlogin", headers )
		@cookie = resp.response['set-cookie'].split( '; ' )[0]

		params = { 'wpName'=>@username, 'wpPassword'=>@password, 'wpLoginattempt'=>'Log In' }
		headers.update( { 'Cookie'=>@cookie } )
		resp = HTTP.fetch_page_post( "http://#{lyrics_site()}/index.php?title=Special:Userlogin&action=submitlogin", params, headers, -1 )

		# Read more cookies info
		resp.each do |key, val|
			if ( key == 'set-cookie' )
				val.split( /[;,] /).each do |c_entry|
					if ( c_entry.split( '=' )[0] == 'lyrikiUserID' || c_entry.split( '=' )[0] == 'lyrikiUserName' )
						@cookie += "; #{c_entry}"
					end
				end
			end
		end

		data = resp.body()
		data.gsub!( /[ \t\n]+/, ' ' )

		notify = ! @logged_in || ! force

		@logged_in = (/<h2>Login error:<\/h2>/.match( data ) == nil)
		@logged_in = (/<h1 class="firstHeading">Login successful<\/h1>/.match( data ) != nil) if ( @logged_in ) # recheck

		if ( notify )
			if ( @logged_in )
				notify( "logged in successfully as user <i>#{@username}</i>" );
			else
				notify( "there was an error login in as user <i>#{@username}</i>" )
			end
		end

		return @logged_in

	end

	def restore_session( session_file, username=@username, password=@password )

		return true if ( @logged_in && username == @username && password == @password )
		@username, @password = username, password
		return false if ( @username == nil || @password == nil )

		values = { 'usernamemd5' => nil, 'passwordmd5' => nil, 'cookie' => nil }
		if ( XMLHash.read( session_file, values ) )
			if ( MD5.hexdigest( username ) == values['usernamemd5'].to_s() &&
				 MD5.hexdigest( password ) == values['passwordmd5'].to_s() &&
				 values['cookie'] != nil )
				@username = username
				@password = password
				@cookie = values['cookie']
				@logged_in = true
				notify( "session restored for user <i>#{@username}</i>" )
				return true
			else
				notify( "there was an error restoring the session for user <i>#{@username}</i>" )
			end
		else
			notify( 'no saved session found' )
		end
		return false
	end

	def save_session( session_file )
		if ( ! @logged_in )
			notify( 'can\'t save session when not logged in' )
			return false
		end
		values = { 'usernamemd5' => MD5.hexdigest( @username ), 'passwordmd5' => MD5.hexdigest( @password ), 'cookie' => @cookie }
		if ( XMLHash.save( session_file, values ) )
			notify( "session saved for user <i>#{@username}</i>" )
			return true
		else
			notify( "there was an error saving the session for user <i>#{@username}</i>" )
			return false
		end
	end


	def fetch_page_edit_params( url, retry_on_error=1 )
		headers = { 'Keep-Alive'=>'300', 'Connection'=>'keep-alive', 'Referer'=>"#{url}", 'Cookie'=>@cookie }
		resp = HTTP.fetch_page_get( "#{url}&action=edit", headers )

		edit_params = {}
		return edit_params if ( resp.code != '200' )

		body = resp.body()
		body.tr_s!( " \n\r\t", ' ' )

		md = /<input type=['"]hidden['"] value=['"]([a-fA-F0-9]*)['"] name=['"]wpEditToken['"] ?\/>/.match( body )
		if ( md != nil )
			edit_params['edit_token'] = md[1]
		elsif ( retry_on_error > 0 )
			login( @username, @password, true )
			return fetch_page_edit_params( url, retry_on_error-1 )
		else
			return edit_params
		end

		md = /<input type=['"]hidden['"] value=['"]([0-9]+)['"] name=['"]wpEdittime['"] ?\/>/.match( body )
		edit_params['edit_time'] = md[1] if ( md != nil )
		md = /<input type=['"]hidden['"] value=['"]([0-9]+)['"] name=['"]wpStarttime['"] ?\/>/.match( body )
		edit_params['start_time'] = md[1] if ( md != nil )

		return edit_params
	end
	protected :fetch_page_edit_params

	def submit_page( url, page_content, summary='', watch=true )

		# Try to get the edit token for url, can't continue without it:
		edit_params = fetch_page_edit_params( url )
		return false if ( edit_params['edit_token'] == nil )

		params = [
			MultipartFormData.text_param( 'wpTextbox1', page_content ),
			MultipartFormData.text_param( 'wpSummary', summary ),
			MultipartFormData.text_param( 'wpWatchthis', watch ? 'on' : 'off' ),
			MultipartFormData.text_param( 'wpSave', 'Save page' ),
			MultipartFormData.text_param( 'wpSection', '' ),
			MultipartFormData.text_param( 'wpStarttime', edit_params['start_time'].to_s() ), # the new revision time
			MultipartFormData.text_param( 'wpEdittime', edit_params['edit_time'].to_s() ), # the previous revision time
			MultipartFormData.text_param( 'wpEditToken', edit_params['edit_token'] ),
		]

		headers = {
			'Keep-Alive'  => '300',
			'Connection'  => 'keep-alive',
			'Referer'     => "http://#{lyrics_site()}#{url}&action=edit",
			'Cookie'      => @cookie,
		}

		resp = HTTP.fetch_page_post_form_multipart( "#{url}&action=submit", params, headers, -1 )

		return resp.code == '302' # we should have recived a redirect

	end

	def submit_redirect_page( url, link, summary=nil )

		raise ArgumentError if ( Strings.empty?( url ) || Strings.empty?( link ) )

		if ( submit_page( url, "#redirect #{link}", summary ) )
			notify( "submitted redirect page to #{link}" )
			return url
		else
			notify( 'there was an error submitting the redirect page' )
			return nil
		end

	end

	def upload_file( src_file, dst_file, mime_type, description='', watch=true )

		begin
			data = File.new( src_file ).read()
		rescue Exception
			return false
		end

		params = [
			MultipartFormData.file_param( 'wpUploadFile', File.basename( src_file ), mime_type, data ),
			MultipartFormData.text_param( 'wpDestFile', dst_file ),
			MultipartFormData.text_param( 'wpUploadDescription', description ),
			MultipartFormData.text_param( 'wpWatchthis', watch ? 'true' : 'false' ),
			MultipartFormData.text_param( 'wpUpload', 'Upload file' ),
		]

		headers = {
			'Keep-Alive'  => '300',
			'Connection'  => 'keep-alive',
			'Referer'     => "http://#{lyrics_site()}/index.php?title=Special:Upload&wpDestFile=#{CGI.escape(dst_file)}",
			'Cookie'      => @cookie,
		}

		resp = HTTP.fetch_page_post_form_multipart( "http://#{lyrics_site()}/index.php?title=Special:Upload", params, headers, -1 )
		if ( resp.code == '302' ) # we should have received a redirect
			return true
		else # error, probably an expired session: relogin and try again
			login( @username, @password, true )
			resp = HTTP.fetch_page_post_form_multipart( "http://#{lyrics_site()}/index.php?title=Special:Upload", params, headers, -1 )
			return resp.code == '302' # again, we should have received a redirect
		end

	end

	def build_tracks( tracks )
		return self.class.build_tracks( tracks )
	end

	def build_album_page( autogen, artist, album, released, tracks, album_art )
		return self.class.build_album_page( autogen, artist, album, released, tracks, album_art )
	end

	def submit_album_page( album, year, tracks, image_path=nil, month=nil, day=nil )

		raise ArgumentError if ( !@logged_in || Strings.empty?( album ) || year.to_i() <= 1900 )

		tracks_data = parse_tracks( tracks )
		artist = cleanup_title_token( tracks_data['artist'] )
		raise ArgumentError if ( Strings.empty?( artist ) )

		url = build_album_url( artist, album, year )
		page_data = {
			'script_name'	=> script_name(),
			'url' 			=> url,
			'artist'		=> artist,
			'released'		=> month ? "#{month}#{day ? " #{day}" : day}, #{year}" : "#{year}",
			'album'			=> cleanup_title_token( album ),
			'tracks'		=> build_tracks( tracks ),
			'autogen'		=> true
		}

		page_data['album_art_name'] = find_album_art_name( page_data['artist'], page_data['album'], page_data['year'] )
		if ( page_data['album_art_name'] == nil ) # album art not found, we'll attempt to upload it
			page_data['image_path'] = image_path.to_s()
		end

		if ( @review && ! GUI.show_wikilyrics_submit_album_dialog( page_data ) )
			notify( 'album page submission cancelled by user' )
			return nil
		else
			ar, al, yr = parse_album_url( page_data['url'] )
			if ( Strings.empty?( yr ) ||  yr.to_i() <= 1900 )
				notify( 'invalid album url received' )
				return nil
			end
			year = yr.to_i()
		end

 		if ( page_data['album_art_name'] == nil )
			page_data['album_art_name'] = build_album_art_name( page_data['artist'], page_data['album'], year )
			page_data['album_art_desc'] = build_album_art_description( page_data['artist'], page_data['album'], year )
			attempt_upload = true
		else
			attempt_upload = false
		end

		page_content = build_album_page(
			page_data['autogen'],
			page_data['artist'],
			page_data['album'],
			page_data['released'],
			page_data['tracks'],
			page_data['album_art_name']
		)

		if ( attempt_upload && ! Strings.empty?( page_data['image_path'] ) )
			image_path, mime_type = prepare_image_file( page_data['image_path'] )
 			if ( Strings.empty?( image_path ) || Strings.empty?( mime_type ) )
				notify( 'there was an error converting the album cover to JPEG format' )
			elsif ( upload_file( image_path, page_data['album_art_name'], mime_type, page_data['album_art_desc'] ) )
				notify( "uploaded album cover for <i>#{page_data['album']}</i> by <i>#{page_data['artist']}</i>" )
			else
				notify( 'there was an error uploading the album cover' )
			end
		else
			notify( 'album cover won\'t be uploaded' )
		end

		summary = "#{page_data['autogen'].to_s() == 'true' ? "autogen. " : ''}album page (#{@@NAME}v#{@@VERSION})"
		if ( submit_page( page_data['url'], page_content, summary ) )
			notify( "submitted album page for <i>#{page_data['album']}</i> by <i>#{page_data['artist']}</i>" )
			return page_data['url']
		else
			notify( 'there was an error submitting the album page' )
			return nil
		end

	end

	def build_song_page( autogen, artist, album, year, title, credits, lyricist, lyrics )
		self.class.build_song_page( autogen, artist, album, year, title, credits, lyricist, lyrics )
	end

	def submit_song_page( lyrics, artist, title, album, year, credits, lyricist, edit_url=nil )

		raise ArgumentError if ( ! @logged_in || Strings.empty?( artist ) || Strings.empty?( title ) )

		edit_mode = edit_url != nil
		url = edit_mode ? edit_url : build_song_url( artist, title )

		lyrics = '' if ( lyrics == nil )

		page_data = {
			'script_name'	=> script_name(),
			'edit_mode'		=> edit_mode,
			'url' 			=> url,
			'artist'		=> cleanup_title_token( artist ),
			'year'			=> year.to_s(),
			'album'			=> cleanup_title_token( album.to_s() ),
			'song'			=> cleanup_title_token( title ),
			'lyrics'		=> Strings.cleanup_lyrics( lyrics ),
			'instrumental'	=> false,
			'credits'		=> credits.to_s(),
			'lyricist'		=> lyricist.to_s(),
			'autogen'		=> true
		}

		if ( @review && ! GUI.show_wikilyrics_submit_song_dialog( page_data ) )
			notify( 'song page submission cancelled by user' )
			return nil, lyrics
		end

		if ( Strings.empty?( page_data['lyrics'] ) && ! page_data['instrumental'] )
			notify( 'no lyrics to submit received' )
			return nil, nil
		elsif ( page_data['instrumental'] )
			page_data['lyrics'] = nil
		end

		page_content = build_song_page(
			page_data['autogen'],
			page_data['artist'],
			page_data['album'],
			page_data['year'],
			page_data['song'],
			page_data['credits'],
			page_data['lyricist'],
			page_data['lyrics']
		)

		summary = "#{page_data['autogen'].to_s() == 'true' ? "autogen. " : ''}song page (#{@@NAME}v#{@@VERSION})"
		if ( submit_page( page_data['url'], page_content, summary ) )
			notify( "submitted song page for <i>#{page_data['song']}</i> by <i>#{page_data['artist']}</i>" )
			return page_data['url'], page_data['lyrics']
		else
			notify( 'there was an error submitting the song page' )
			return nil, page_data['lyrics']
		end

	end


	def WikiLyrics.parse_search_results( body, content_matches=false )

		return [] if ( body == nil )

		body.tr_s!( " \n\r\t", ' ' )

		results = []

		return results if ( ! body.gsub!( /.*<h2>Article title matches<\/h2> ?<ol start='1'> ?/, '' ) &&
							! body.gsub!( /.*<h2>No page title matches<\/h2> ?/, '' ) )

 		if ( ! content_matches )
			body.gsub!( /(<\/ol> ?)?<a name="Page_text_matches">.*$/, '' )
			body.gsub!( /(<\/ol> ?)?<a name="No_page_text_matches">.*$/, '' )
		end

		return results if ( ! body.gsub!( /<form id="powersearch" method="get" action="\/Special:Search">.*$/, '' ) )
		body.gsub!( /<\/ol> ?<p>View \(previous .*$/, '' )

		body.split( '<li>' ).each() do |entry|

			md = /<a href="\/([^"]*)/.match( entry )
			next if ( md == nil )
			url = md[1]
			md = /<a .* title="([^"]+)"/.match( entry )
			next if ( md == nil )
			title = md[1]
			result = { 'url'=>"http://#{lyrics_site()}/index.php?title=#{url}", 'title'=>title }
			results << result if ( ! content_matches || ! results.include?( result ) )
		end

		return results
	end

	def parse_search_results( body, content_matches=false )
		self.class.parse_search_results( body, content_matches )
	end

	# TODO: nested templates are NOT SUPPORTED
	def WikiLyrics.parse_template( template )

		begin
			random_token = Strings.random_token()
		end while( template.include?( random_token ) )

		md = /\s*\{\{\s*([^\|]+)\s*\|([^}]+)\}\}\s*/.match( template )
		return nil, nil if ( md == nil )
		name, params = md[1], md[2].gsub( /\[\[([^\[\]]+\|[^\[\]]+)\]\]/ ) { |s| s.gsub( '|', random_token ) }
		params_list = []
		idx = 1
		params.split( /\s*\|\s*/ ).each() do |key_value|
			md = /([a-zA-Z0-9]+)\s*=\s*(.*)\s*/.match( key_value )
			if ( md != nil ) # unnamed arg
				key, value = md[1], md[2]
			else
				key, value = idx, key_value.strip()
				idx += 1
			end
			params_list.insert( -1, { 'key'=>key, 'value'=>value.gsub( random_token, '|' ) } )
		end
		return name.strip(), params_list
	end

	def parse_template( template )
		return self.class.parse_template( template )
	end

	def WikiLyrics.prepare_image_file( image_path, size_limit=153600 )
		4.times() do |trynumb|
			system( 'convert', '-quality', (100-trynumb*10).to_s(), image_path, '/tmp/AlbumArt.jpg' )
			return nil, nil if ( $? != 0 )
			size = FileTest.size?( '/tmp/AlbumArt.jpg' )
			return '/tmp/AlbumArt.jpg', 'image/jpeg' if ( (size ? size : 0) <= size_limit )
		end
		return nil, nil
	end

	def prepare_image_file( image_path, size_limit=153600 )
		return self.class.prepare_image_file( image_path, size_limit )
	end

	def WikiLyrics.parse_tracks( tracks, various_artists='(Various Artists)' )

		tracks_data = { 'genres' => [], 'length' => 0 }

		tracks_data['artist'] = tracks[0]['artist']
		normalized_artist = Strings.normalize_token( tracks_data['artist'] )
		tracks.each() do |track|
			if ( normalized_artist != Strings.normalize_token( track['artist'] ) )
				tracks_data['artist'] = various_artists
			end

			genre = track['genre']
			if ( genre != nil && ! tracks_data['genres'].include?( (genre = Strings.downcase!(genre.strip())) ) )
				tracks_data['genres'].insert( -1, genre )
			end

			tracks_data['length'] += track['length'].to_i()
		end

		return tracks_data
	end

	def parse_tracks( tracks, various_artists='(Various Artists)' )
		return self.class.parse_tracks( tracks, various_artists )
	end

	def WikiLyrics.cleanup_title_token( title, downcase=false )
		return cleanup_title_token!( String.new( title ), downcase )
	end

	def cleanup_title_token( title, downcase=false )
		return self.class.cleanup_title_token( title, downcase )
	end

	def cleanup_title_token!( title, downcase=false )
		return self.class.cleanup_title_token!( title, downcase )
	end

	def WikiLyrics.get_sort_name( title )
		return get_sort_name!( String.new( title ) )
	end

	def get_sort_name( title )
		return self.class.get_sort_name( title )
	end

	def WikiLyrics.get_sort_name!( title )

		title.gsub!( /á|ä|à|â|Á|Ä|À|Â/, 'a' )
		title.gsub!( /é|ë|è|ê|É|Ë|È|Ê/, 'e' )
		title.gsub!( /í|ï|ì|î|Í|Ï|Ì|Î/, 'i' )
		title.gsub!( /ó|ö|ò|ô|Ó|Ö|Ò|Ô/, 'o' )
		title.gsub!( /ú|ü|ù|û|Ú|Ü|Ù|Û/, 'u' )

		title.gsub!( /\[[^\]\[]*\]/, '' )
		Strings.titlecase!( title, false, true )

		title.gsub!( /[·\.,;:"`´¿\?¡!\(\)\[\]{}<>#\$\+\*%\^]/, '' )
		title.gsub!( /[\\\/_-]/, ' ' )
		title.gsub!( '&', 'And' )
		title.squeeze!( ' ' )
		title.strip!()

		title.gsub!( /^A /, '' ) # NOTE: only valid for English
		title.gsub!( /^An /, '' )
		title.gsub!( /^The /, '' )
		title.gsub!( /^El /, '' )
		title.gsub!( /^Le /, '' )
		title.gsub!( /^La /, '' )
		title.gsub!( /^L'[AEIOU]/i ) { |s| s.slice(2,1).upcase() }
		title.gsub!( /^Los /, '' )
		title.gsub!( /^Las /, '' )
		title.gsub!( /^Les /, '' )
		title.gsub!( '\'', '' )

		return title
	end

	def get_sort_name!( title )
		return self.class.get_sort_name!( title )
	end

	def WikiLyrics.get_sort_letter( title, normalize_title=false )
		title = get_sort_name( title ) if ( normalize_title )
		if ( ( idx = title.index( /[a-zA-Z0-9]/ ) ) != nil )
			s_letter = title.slice( idx, 1 )
			s_letter = '0-9' if ( s_letter.index( /[0-9]/ ) == 0 )
		else
			s_letter = ''
		end
		return s_letter
	end

	def get_sort_letter( title, normalize_title=false )
		return self.class.get_sort_letter( title, normalize_title )
	end



	# GENERAL FUNCTIONS

	def WikiLyrics.parse_link( link )
		md = /\[\[([^\|]+)(\|.+|)\]\]$/.match( link )
		return nil, nil if ( md == nil || md[1].strip() == '' )
		return	md[1].gsub( '_', ' ' ).strip(), # page
				md[2] == '' ? nil : md[2].slice( 1..-1 ).strip()  # display
	end

	def parse_link( link )
		return self.class.parse_link( link )
	end

	def WikiLyrics.build_link( article )
		return "[[#{article}]]"
	end

	def build_link( article )
		return self.class.build_link( article )
	end

	def WikiLyrics.cleanup_article( article )
		article = Strings.upcase( article.slice( 0, 1 ) ) + article.slice( 1..-1 )
		article.gsub!( '_', ' ' )
		article.strip!()
		return article
	end

	def cleanup_article( article )
		return self.class.cleanup_article( article )
	end

	def WikiLyrics.parse_url( url )
		url = CGI.unescape( url )
		url.gsub!( '_', ' ' )
		if ( (md = /(https?:\/\/[^\/]+\/|)(index.php\?title=|wiki\/|)([^&]+)(&.*|)$/.match( url )) == nil )
			return nil
		else
			return cleanup_article( md[3] ) # article title
		end
	end

	def parse_url( url )
		return self.class.parse_url( url )
	end

	def WikiLyrics.build_url( article )
		article = article.gsub( ' ', '_' )
		return "http://#{lyrics_site()}/index.php?title=#{CGI.escape(article)}"
	end

	def build_url( article )
		return self.class.build_url( article )
	end



	# SONG FUNCTIONS

	def WikiLyrics.parse_song_link( link )
		article, display = parse_link( link )
		return nil, nil if ( article == nil )
		if ( (md = /^([^:]+):(.+)$/.match( article )) == nil )
			return nil, nil
		else
			return md[1], md[2]
		end
	end

	def parse_song_link( link )
		return self.class.parse_song_link( link )
	end

	def WikiLyrics.build_song_link( artist, title )
		artist = cleanup_title_token( artist )
		title = cleanup_title_token( title )
		return build_link( "#{artist}:#{title}" )
	end

	def build_song_link( artist, title )
		return self.class.build_song_link( artist, title )
	end

	def WikiLyrics.parse_song_url( url )
		article = parse_url( url )
		return nil, nil if ( article == nil )
		if ( (md = /^([^:]+):(.+)$/.match( article )) == nil )
			return nil, nil
		else
			return md[1], md[2] # artist, song title
		end
	end

	def WikiLyrics.build_song_url( artist, title )
		artist = cleanup_title_token( artist )
		title = cleanup_title_token( title )
		return build_url( "#{artist}:#{title}" )
	end

	def build_song_url( artist, title )
		return self.class.build_song_url( artist, title )
	end

	def WikiLyrics.build_song_rawdata_url( artist, title )
		return build_song_url( artist, title ) + '&action=raw&ctype=text/javascript'
	end

	def build_song_rawdata_url( artist, title )
		return self.class.build_song_rawdata_url( artist, title )
	end

	def WikiLyrics.build_song_edit_url( artist, title )
		return build_song_url( artist, title ) + '&action=edit'
	end

	def build_song_edit_url( artist, title )
		return self.class.build_song_edit_url( artist, title )
	end

	def WikiLyrics.build_song_search_url( artist, title )
		artist = cleanup_title_token( artist )
		title = cleanup_title_token( title )
		search_string = CGI.escape( "#{artist}:#{title}" )
		return "http://#{lyrics_site()}/index.php?redirs=1&search=#{search_string}&fulltext=Search&limit=500"
	end

	def build_song_search_url( artist, title )
		return self.class.build_song_search_url( artist, title )
	end

	def WikiLyrics.find_song_page_url( artist, title )

		url = build_song_url( artist, title )
		response = HTTP.fetch_page_get( url + '&action=raw&ctype=text/javascript' )
		if ( response != nil && response.body().strip() != '' ) # page exists
			return url
		else
			artist = cleanup_title_token( artist, false )
			title = cleanup_title_token( title, false )
			target = Strings.normalize_token( "#{artist}:#{title}" )
			response = HTTP.fetch_page_get( build_song_search_url( artist, title ) )
			return nil if ( response == nil )
			parse_search_results( response.body(), true ).each() do |result|
				return result['url'] if ( target == Strings.normalize_token( result['title'] ) )
			end
			return nil
		end

	end

	def find_song_page_url( artist, title )
		return self.class.find_song_page_url( artist, title )
	end



	# ALBUM FUNCTIONS

	def WikiLyrics.parse_album_link( link )
		article, display = parse_link( link )
		return nil, nil, nil if ( article == nil )
		if ( (md = /^([^:]+):(.+) \(([0-9]{4,4})\)$/.match( article )) == nil )
			return nil, nil, nil
		else
			return md[1], md[2], md[3]
		end
	end

	def parse_album_link( link )
		return self.class.parse_album_link( link )
	end

	def WikiLyrics.build_album_link( artist, album, year )
		artist = cleanup_title_token( artist )
		album = cleanup_title_token( album )
		return build_link( "#{artist}:#{album} (#{year})" )
	end

	def build_album_link( artist, album, year )
		return self.class.build_album_link( artist, album, year )
	end

	def WikiLyrics.parse_album_url( url )
		article = parse_url( url )
		return nil, nil, nil if ( article == nil )
		if ( (md = /^([^:]+):(.+) \(([0-9]{4,4})\)$/.match( article )) == nil )
			return nil, nil, nil
		else
			return md[1], md[2], md[3]
		end
	end

	def parse_album_url( url )
		return self.class.parse_album_url( url )
	end

	def WikiLyrics.build_album_url( artist, album, year )
		artist = cleanup_title_token( artist )
		album = cleanup_title_token( album )
		return build_url( "#{artist}:#{album} (#{year})" )
	end

	def build_album_url( artist, album, year )
		return self.class.build_album_url( artist, album, year )
	end

	def WikiLyrics.build_album_rawdata_url( artist, album, year )
		return build_album_url( artist, album, year ) + '&action=raw&ctype=text/javascript'
	end

	def build_album_rawdata_url( artist, album, year )
		return self.class.build_album_rawdata_url( artist, album, year )
	end

	def WikiLyrics.build_album_edit_url( artist, album, year )
		return build_album_url( artist, album, year ) + '&action=edit'
	end

	def build_album_edit_url( artist, album, year )
		return self.class.build_album_edit_url( artist, album, year )
	end

	def WikiLyrics.build_album_search_url( artist, album, year )
		artist = cleanup_title_token( artist )
		album = cleanup_title_token( album )
		search_string = CGI.escape( "#{artist}:#{album} (#{year})" )
		return "http://#{lyrics_site()}/index.php?redirs=1&search=#{search_string}&fulltext=Search&limit=500"
	end

	def build_album_search_url( artist, album, year )
		return self.class.build_album_search_url( artist, album, year )
	end

	def WikiLyrics.find_album_page_url( artist, album, year )

		url = build_album_url( artist, album, year )
		response = HTTP.fetch_page_get( url + '&action=raw&ctype=text/javascript' )
		if ( response != nil && response.body().strip() != '' ) # page exists
			return url
		else
			artist = cleanup_title_token( artist, false )
			album = cleanup_title_token( album, false )
			target = Strings.normalize_token!( "#{artist}:#{album} (#{year})" )
			response = HTTP.fetch_page_get( build_album_search_url( artist, album, year ) )
			return nil if ( response == nil || response.body() == nil )
			parse_search_results( response.body(), true ).each() do |result|
				return result['url'] if ( Strings.normalize_token!( result['title'] ) == target )
			end
			return nil
		end

	end

	def find_album_page_url( artist, album, year )
		return self.class.find_album_page_url( artist, album, year )
	end


	# ALBUM ART FUNCTIONS

	def build_album_art_description( artist, album, year )
		return self.class.build_album_art_description( artist, album, year )
	end

	def build_album_art_name( artist, album, year, extension='jpg' )
		return self.class.build_album_art_name( artist, album, year, extension )
	end

	def find_album_art_name( artist, album, year )
		return self.class.find_album_art_name( artist, album, year )
	end

	def WikiLyrics.find_album_art_url( artist, album, year )
		if ( (album_art_name = find_album_art_name( artist, album, year )) != nil )
			album_art_name.gsub!( ' ', '_' )
			return "http://#{lyrics_site()}/index.php?title=Image:#{CGI.escape(album_art_name)}"
		else
			return nil
		end
	end

	def find_album_art_url( artist, album, year )
		return self.class.find_album_art_url( artist, album, year )
	end
end
