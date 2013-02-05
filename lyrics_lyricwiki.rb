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
require 'cgi'

class LyricWiki < WikiLyrics

	def LyricWiki.lyrics_site()
		return 'www.lyricwiki.org'
	end

	def LyricWiki.script_name()
		return 'LyricWiki'
	end

	def parse_lyrics( url, body, artist, title, album=nil, year=nil )

		body.gsub!( /â€™|�/, "'" ) # replace bizarre characters with apostrophes

		lyrics_data = { 'custom' => {} }

		lyrics_data['custom']['autogen'] = (/\[\[Category:[Rr]eview[_ ]Me\]\]/.match( body ) != nil )

		# Search album, year and artist information
		if ( (md = /\s*\{\{\s*[Ss]ong\s*\|[^}]+\}\}\s*/.match( body )) != nil )
			unnamed_params_names = { 1 => 'album_and_year', 2 => 'artist' }
			name, params = parse_template( md[0] )
			params.each() do |param|
				if ( ! Strings.empty?( param['key'].to_s ) && ! Strings.empty?( param['value'] ) )
					if ( param['key'].is_a?( String ) )
						lyrics_data['custom'][param['key']] = param['value']
					else
						param_name = unnamed_params_names[param['key']]
						lyrics_data['custom'][param_name] = param['value'] if ( param_name != nil )
					end
				end
			end
		elsif ( (md = /On (''')?\[\[[^\|]+\|([^\|]+)\]\](''')? by (''')?\[\[([^\]]+)\]\](''')?/.match( body )) != nil )
			lyrics_data['custom']['album_and_year'] = md[2]
			lyrics_data['custom']['artist'] = md[5]
		end

		if ( lyrics_data['custom'].include?( 'album_and_year' ) )
			if ( (md = /^(.+) \(([\?0-9]{4,4})\)$/.match( lyrics_data['custom']['album_and_year'] )) != nil )
				lyrics_data['album'] = md[1]
				lyrics_data['year'] = md[2] if ( md[2].to_i() > 1900 )
			end
		end

		#search title information (other information that hasn't been found yet)
		if ( (md = /\s*\{\{\s*[Ss]ongFooter\s*\|[^}]+\}\}\s*/.match( body )) != nil )
			name, params = parse_template( md[0] )
			params.each() do |param|
				if ( ! Strings.empty?( param['key'].to_s ) && ! Strings.empty?( param['value'] ) )
					lyrics_data['custom'][param['key'].to_s()] = param['value']
				end
			end
		elsif ( (md = /\[[^\s\]]+ ([^\]]+)\] on Amazon$/.match( body )) != nil )
			lyrics_data['custom']['song'] = md[1].strip()
		end

		if ( (md = /\*?\s*Composer: *([^\n]+)/.match( body )) != nil )
			lyrics_data['custom']['credits'] = md[1].strip()
		end
		if ( (md = /\*?\s*Lyrics by: *([^\n]+)/.match( body )) != nil )
			lyrics_data['custom']['lyricist'] = md[1].strip()
		end

		lyrics_data['artist'] = lyrics_data['custom']['artist'] if ( lyrics_data['custom'].include?( 'artist' ) )
		lyrics_data['title'] = lyrics_data['custom']['song'] if ( lyrics_data['custom'].include?( 'song' ) )
		lyrics_data['album'] = lyrics_data['custom']['album'] if ( lyrics_data['custom'].include?( 'album' ) )

		if ( (md = /<lyrics?>(.*)<\/lyrics?>/im.match( body )) != nil )
	 		body = md[1]
			body.gsub!( /[ \t]*[\r\n][ \t]*/m, "\n" )
		else
			if ( /\s*\{\{[Ii]nstrumental\}\}\s*/.match( body ) != nil )
				body = '<tt>(Instrumental)</tt>'
			else
				body.gsub!( /\{\{.*\}\}\n?/, '' )
				body.gsub!( /\[\[Category:.*\]\]\n?/, '' )
				body.gsub!( /On '''\[\[.*?\n/i, '' )
				body.gsub!( /By '''\[\[.*?\n/i, '' )
				body.gsub!( /\ *== *Credits *==.*$/im, '' )
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
		end

		if ( Strings.empty?( body ) )
			return lyrics_data
		else
			lyrics_data['lyrics'] = body
			lyrics_data['lyrics'].gsub!( /\{\{ruby\|([^\|]*)\|([^\}]*)\}\}/, '<ruby><rb>\1</rb><rp>(</rp><rt>\2</rt><rp>)</rp></ruby>' )
			# Take care of multiple lyrics tags:
			lyrics_data['lyrics'].gsub!( /(\{\|\s*\|-\s*\||\|\|)\s*==\s*([^=]+)\s*==/, '<br/><b>\2</b>' )
			lyrics_data['lyrics'].gsub!( /\s*==\s*([^=]+)\s*==/, "\n<br/><b>\\1</b>" )
			lyrics_data['lyrics'].gsub!( /<\/?lyric>/i, '' )
			return lyrics_data
		end
	end

	def LyricWiki.build_tracks( tracks )
		tracks_data = parse_tracks( tracks )
		album_artist = cleanup_title_token( tracks_data['artist'] )
		ret = ''
		tracks.each() do |track|
			track_artist = cleanup_title_token( track['artist'], false )
			track_title  = cleanup_title_token( track['title'], true )
			tc_track_title = Strings.titlecase( track_title )
			artist_param = (album_artist == '(Various Artists)' || album_artist == 'Various Artists') ? 'by' : 'artist'
			if ( track_title == tc_track_title )
				ret += "# {{track|title=#{track_title}|#{artist_param}=#{track_artist}}}\n"
			else
				ret += "# {{track|title=#{track_title}|#{artist_param}=#{track_artist}|display=#{tc_track_title}}}\n"
			end
		end
		return ret
	end

	def LyricWiki.build_album_page( autogen, artist, album, released, tracks, album_art )

		raise ArgumentError if ( Strings.empty?( artist ) || Strings.empty?( album ) || Strings.empty?( tracks ) )

		s_name = get_sort_name( album )
		s_letter = get_sort_letter( s_name )

		contents = \
		"#{autogen.to_s() != 'false' ? "[[Category:Review Me]]\n" : ''}" \
		"{{Album\n" \
		"|Artist   = #{artist}\n" \
		"|Album    = #{album}\n" \
		"|fLetter  = #{s_letter}\n" \
		"|Released = #{released}\n" \
		"|Cover    = #{album_art}\n" \
		"}}\n"
		# "|Genre    = #{genre}\n" \
		# "|Length   = #{length}\n" \

		return \
		"#{contents}" \
		"#{tracks.strip()}\n" \
		"\n" \
		"{{AlbumFooter\n" \
		"|artist=#{artist}\n" \
		"|album=#{album}\n" \
		"}}\n"
	end

	def LyricWiki.build_song_page( autogen, artist, album, year, title, credits, lyricist, lyrics )

		raise ArgumentError if ( artist == nil || title == nil )

		s_name = get_sort_name( title )
		s_letter = get_sort_letter( s_name )
		year = year.to_i() > 1900 ? year.to_s() : '????'

		if ( lyrics != nil )
			lyrics = lyrics.gsub( /<ruby><rb>([^<]*)<\/rb><rp>\(<\/rp><rt>([^<]*)<\/rt><rp>\)<\/rp><\/ruby>/, '{{ruby|\1|\2}}' )
		end

		return \
		"#{autogen.to_s() != 'false' ? "[[Category:Review Me]]\n" : ''}" \
		"{{Song|#{Strings.empty?( album ) ? '' : "#{album} (#{year})"}|#{artist}}}\n\n" \
		"#{Strings.empty?( lyrics ) ? '{{instrumental}}' : "<lyric>\n#{lyrics}\n</lyric>"}\n\n" \
		"#{Strings.empty?( credits ) && Strings.empty?( lyricist ) ? '' : "==Credits==\n"}" \
		"#{Strings.empty?( credits ) ? '' : "*Composer: #{credits}\n"}" \
		"#{Strings.empty?( lyricist ) ? '' : "*Lyrics by: #{lyricist}\n"}" \
		"\n" \
		"{{SongFooter\n" \
		"|artist=#{artist}\n" \
		"|song=#{title}\n" \
		"|fLetter=#{s_letter}\n" \
		"}}\n"

	end

	def LyricWiki.build_album_art_name( artist, album, year, extension='jpg' )
		artist = cleanup_title_token( artist )
		album = cleanup_title_token( album )
		album_art_name = "#{artist} - #{album}#{Strings.empty?( extension ) ? '' : ".#{extension.strip()}"}".gsub( ' ', '_' )
		return Strings.remove_invalid_filename_chars( album_art_name )
	end

	def LyricWiki.build_album_art_description( artist, album, year )
		artist = cleanup_title_token( artist )
		album = cleanup_title_token( album )
		return \
		"{{Albumcover/Upload|\n" \
		"|artist = #{artist}\n" \
		"|album  = #{album}\n" \
		"|year   = #{year}\n" \
		"}}\n"
	end

	def LyricWiki.find_album_art_name( artist, album, year )

		normalized_artist = cleanup_title_token( artist )
		Strings.remove_invalid_filename_chars!( normalized_artist )
		Strings.normalize_token!( normalized_artist )
		normalized_artist.gsub!( ' ', '' )

		normalized_album = cleanup_title_token( album )
		Strings.remove_invalid_filename_chars!( normalized_album )
		Strings.normalize_token!( normalized_album )
		normalized_album.gsub!( ' ', '' )

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
			idx1 = normalized_title.index( normalized_artist )
			matches += 1 if ( idx1 != nil )
			idx1 = idx1 == nil ? 0 : idx1 + normalized_artist.size()
			idx2 = normalized_title.index( normalized_album, idx1 )
			matches += 2 if ( idx2 != nil )

			candidates.insert( -1, [ matches, result['title'] ] ) if ( matches > 1 )
		end

		if ( candidates.size > 0 )
			candidates.sort!() { |x,y| y[0] <=> x[0] }
			return URI.decode( candidates[0][1].slice( 'Image:'.size()..-1 ).gsub( ' ', '_' ) )
		else
			return nil
		end
	end

	def LyricWiki.cleanup_title_token!( title, downcase=false )
		title.gsub!( /\[[^\]\[]*\]/, '' )
		title.squeeze!( ' ' )
		title.strip!()
		title.gsub!( '+', 'and' )
		Strings.titlecase!( title, false, downcase )
		return title
	end

end
