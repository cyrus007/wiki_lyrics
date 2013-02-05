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
require 'wikilyrics'
require 'gui'
require 'md5'

class Lyriki < WikiLyrics

	def Lyriki.lyrics_site()
		return 'www.lyriki.com'
	end

	def Lyriki.script_name()
		return 'Lyriki'
	end

	def parse_lyrics( url, body, artist, title, album=nil, year=nil )

		lyrics_data = { 'custom' => {} }

		md = /\s*\{\{\s*([Ss]Song|[Ss]ong)\s*\|[^}]+\}\}\s*/.match( body )
		if ( md != nil )
			name, params = parse_template( md[0] )
			params.each() do |param|
				if ( ! Strings.empty?( param['key'].to_s ) && ! Strings.empty?( param['value'] ) )
					lyrics_data['custom'][param['key']] = param['value']
				end
			end
			if ( lyrics_data['custom'].include?( 'artist' ) )
				lyrics_data['artist'] = lyrics_data['custom']['artist']
				if ( ! Strings.empty?( lyrics_data['artist'] ) && name.downcase() == 'song' )
					page, display = Lyriki.parse_link( lyrics_data['artist'] )
					if ( ! Strings.empty?( display ) )
						lyrics_data['artist'] = display
					elsif ( ! Strings.empty?( page ) )
						lyrics_data['artist'] = page
					else
						lyrics_data['artist'].gsub!( /\[\[|\]\]/, '' )
					end
				end
			end
			lyrics_data['title'] = lyrics_data['custom']['song'] if ( lyrics_data['custom'].include?( 'song' ) )
			lyrics_data['album'] = lyrics_data['custom']['album'] if ( lyrics_data['custom'].include?( 'album' ) )
			lyrics_data['year'] = lyrics_data['custom']['year'] if ( lyrics_data['custom'].include?( 'year' ) )
		end

		lyrics_data['custom']['autogen'] = body.include?( '{{autoGenerated}}' ) || body.include?( '{{AutoGenerated}}' )

		if ( (md = /<lyrics>(.*)<\/lyrics>/im.match( body )) != nil )
	 		body = md[1]
			body.gsub!( /[ \t]*[\r\n][ \t]*/m, "\n" )
		else
			body.gsub!( /\{\{.*\}\}\n?/, '' )
			body.gsub!( /\[\[Category:.*\]\]\n?/, '' )
			body.gsub!( /\ *== *(External *Links|Links) *==.*$/im, '' )
			body = body.split( "\n" ).collect() do |line|
				if ( line.index( /\s/ ) == 0 )
					"\n" + line
				else
					line
				end
			end.join( '' )
			body.gsub!( /<br ?\/?>/i, "\n" )
		end

		if ( Strings.empty?( body ) )
			return lyrics_data
		else
			lyrics_data['lyrics'] = body
			return lyrics_data
		end

	end

# 	def submit_page( url, page_content, summary='', watch=true )
# 		success = super( url, page_content, summary, watch )
# 		if ( success )
# 			article = parse_url( url )
# 			tc_article = Strings.titlecase( article, false )
# 			if ( article != tc_article )
# 				link = build_link( article )
# 				super( build_url( tc_article ), "#redirect #{link}", "autogen. redirect (#{@@NAME}v#{@@VERSION})", false )
# 			end
# 		end
# 		return success
# 	end

	def Lyriki.build_tracks( tracks, various_artists='(Various Artists)' )
		tracks_data = parse_tracks( tracks )
		album_artist = cleanup_title_token( tracks_data['artist'] )
		ret = ''
		tracks.each() do |track|
			if ( track['length'] != nil )
				secs = 0
				toks = track['length'].to_s().split( ':' ).reverse()
				toks.size().times() { |idx| secs += (60**idx)*toks[idx].to_i() }
				length = "|#{secs / 60}:#{secs % 60 < 10 ? "0#{secs % 60}" : secs % 60}"
			else
				length = ''
			end
			track_artist = cleanup_title_token( track['artist'] )
			track_title  = cleanup_title_token( track['title'] )
			if ( album_artist == various_artists )
				ret += "# {{song link va|#{track_artist}|#{track_title}#{length}}}\n"
			else
				ret += "# {{song link|#{track_artist}|#{track_title}#{length}}}\n"
			end
		end
		return ret
	end

	def Lyriki.build_album_page( autogen, artist, album, released, tracks, album_art )

		raise ArgumentError if ( Strings.empty?( artist ) || Strings.empty?( album ) || Strings.empty?( tracks ) )

		s_name = get_sort_name( album )
		s_letter = get_sort_letter( s_name )

		contents = \
		"#{autogen.to_s() != 'false' ? "{{autoGenerated}}\n" : ''}" \
		"{{album|\n" \
		"| image    = #{album_art}\n" \
		"| album    = #{album}\n" \
		"| artist   = #{artist}\n" \
		"| released = #{released}\n" \
		"| tracks   =\n"

		return \
		"#{contents}" \
		"#{tracks.strip()}\n" \
		"}}\n" \
		"\n" \
		"{{C:Album|#{s_letter}|#{s_name}}}"
	end

	def Lyriki.build_song_page( autogen, artist, album, year, title, credits, lyricist, lyrics )

		raise ArgumentError if ( artist == nil || title == nil )

		s_name = get_sort_name( title )
		s_letter = get_sort_letter( s_name )
		year = year.to_i() <= 1900 ? '' : year.to_s()

		song_page = autogen.to_s() != 'false' ? "{{autoGenerated}}\n" : ''

		if ( (md = /^([^\s].*)\s+feat\.\s+([^\s].*)$/i.match( artist.strip() )) == nil )
			song_page <<
			"{{SSong|\n" \
			"| song     = #{title}\n" \
			"| artist   = #{artist}\n" \
			"| album    = #{album}\n" \
			"| year     = #{year}\n" \
			"| credits  = #{credits}\n" \
			"| lyricist = #{lyricist}\n" \
			"}}\n" \
		else
			artist, fartist = md[1].strip(), md[2]
			song_page <<
			"{{Song|\n" \
			"| song     = #{title}\n" \
			"| artist   = [[#{artist}]]<br/>feat. [[#{fartist}]]\n" \
			"| albums   = [[#{artist}:#{album} (#{year})|#{album} (#{year})]]\n" \
			"| credits  = #{credits}\n" \
			"| lyricist = #{lyricist}\n" \
			"}}\n" \
		end

		return song_page <<
		"\n" \
		"<lyrics>#{Strings.empty?( lyrics ) ? '<tt>(Instrumental)</tt>' : lyrics}</lyrics>\n" \
		"\n" \
		"{{C:Song|#{s_letter}|#{s_name}}}"
	end

	def Lyriki.build_song_search_url( artist, title )
		artist = Strings.titlecase( cleanup_title_token( artist ), false )
		title = Strings.titlecase( cleanup_title_token( title ), false )
		search_string = CGI.escape( "#{artist}:#{title}" )
		return "http://#{lyrics_site()}/index.php?search=#{search_string}&fulltext=Search&limit=500"
	end

	def Lyriki.build_album_search_url( artist, album, year )
		artist = Strings.titlecase( cleanup_title_token( artist ), false )
		album = Strings.titlecase( cleanup_title_token( album ), false )
		search_string = CGI.escape( "#{artist}:#{album} (#{year})" )
		return "http://#{lyrics_site()}/index.php?search=#{search_string}&fulltext=Search&limit=500"
	end

	def Lyriki.build_album_art_name( artist, album, year, extension='jpg' )
		artist = cleanup_title_token( artist )
		album = cleanup_title_token( album )
		album_art_name = "AlbumArt-#{artist}-#{album}_(#{year})#{Strings.empty?( extension ) ? '' : ".#{extension.strip()}"}".gsub( ' ', '_' )
		return Strings.remove_invalid_filename_chars( album_art_name )
	end

	def Lyriki.build_album_art_description( artist, album, year )
		artist = cleanup_title_token( artist )
		album = cleanup_title_token( album )
		return "#{artist}:#{album} (#{year})"
	end

	def Lyriki.find_album_art_name( artist, album, year )

		normalized_artist = cleanup_title_token( artist )
		Strings.remove_invalid_filename_chars!( normalized_artist )
		Strings.normalize_token!( normalized_artist )
		normalized_artist.gsub!( ' ', '' )

		normalized_album = cleanup_title_token( album )
		Strings.remove_invalid_filename_chars!( normalized_album )
		Strings.normalize_token!( normalized_album )
		normalized_album.gsub!( ' ', '' )

		year = year.to_s().strip()

		artist = cleanup_title_token( artist )
		Strings.remove_invalid_filename_chars!( artist )
		search_url = "http://#{lyrics_site()}/index.php?ns6=1&search=#{CGI.escape( artist )}&searchx=Search&limit=500"
		response = HTTP.fetch_page_get( search_url )

		return nil if ( response == nil || response.body() == nil )

		candidates = []
		parse_search_results( response.body(), true ).each() do |result|

			next if ( result['title'].index( 'Image:' ) != 0 )

			normalized_title = Strings.normalize_token( result['title'] )
			normalized_title.gsub!( ' ', '' )

			matches = 0
			idx1 = normalized_title.index( 'albumart' )
			matches += 1 if ( idx1 != nil )
			idx1 = idx1 == nil ? 0 : idx1 + 'albumart'.size()
			idx2 = normalized_title.index( normalized_artist, idx1 )
			matches += 4 if ( idx2 != nil )
			idx2 = idx2 == nil ? idx1 : idx2 + normalized_artist.size()
			idx3 = normalized_title.index( normalized_album, idx2 )
			next if ( idx3 == nil )
			idx3 = idx3 == nil ? idx2 : idx3 + normalized_album.size()
			idx3 = normalized_title.index( year, idx3 )
			matches += 2 if ( idx3 != nil )

			candidates.insert( -1, [ matches, result['title'] ] )
		end

		if ( candidates.size > 0 )
			candidates.sort!() { |x,y| y[0] <=> x[0] }
			return URI.decode( candidates[0][1].slice( 'Image:'.size()..-1 ).gsub( ' ', '_' ) )
		else
			return nil
		end
	end

	def Lyriki.cleanup_title_token!( title, downcase=false )
		title.gsub!( /\[[^\]\[]*\]/, '' )
		title.squeeze!( ' ' )
		title.strip!()
		title.gsub!( '+', 'and' )
		Strings.titlecase!( title, true, downcase )
		return title
	end

end
