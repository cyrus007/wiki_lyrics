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
require 'utils'
require 'lyrics'
require 'cgi'

class TerraLetras < Lyrics

	def TerraLetras.lyrics_site()
		return 'letras.terra.com.br'
	end

	def TerraLetras.script_name()
		return 'Terra Letras'
	end

	def build_lyrics_fetch_data( artist, title, album=nil, year=nil )
		artist = Strings.utf82latin1( artist )
		title  = Strings.utf82latin1( title )
		return { 'url' => "http://#{lyrics_site()}/winamp.php?musica=#{CGI.escape(title)}&artista=#{CGI.escape(artist)}" }
	end

	def parse_lyrics( url, body, artist, title, album=nil, year=nil )

		body = Strings.latin12utf8( body )
		body.tr_s!( " \n\r\t", ' ' )

		lyrics_data = {}

		if ( (md = /<h1><a href='[^']+' target='_blank'>([^<]+)<\/a><\/h1>/.match( body )) != nil )
			lyrics_data['title'] = md[1]
		end
		if ( (md = /<h2><a href='[^']+' target='_blank'>([^<]+)<\/a><\/h2>/.match( body )) != nil )
			lyrics_data['artist'] = md[1]
		end
		if ( (lyrics_data['title'] == nil || lyrics_data['artist'] == nil) && ((md = /<h2>([^<]+)<\/h2> <h2 id='sz'>([^<]+)<\/h2>/.match( body )) != nil) )
			lyrics_data['title'], lyrics_data['artist'] = md[1], md[2]
		end

		match = body.gsub!( /^.*<p id='cmp'>[^<]*<\/p> <p>/, '' )
		match = true if ( body.gsub!( /^.*<\/h2> <p>/, '' ) )
		match = false if ( ! body.gsub!( /<\/p>.*$/, '' ) )

		return lyrics_data if ( ! match || body.include?( '<h3>[^<]+</h3>' ) || body.strip() == '' )

		lyrics_data['lyrics'] = body
		lyrics_data['lyrics'].gsub!( /\ ?<br ?\/?> ?/i, "\n" )
		lyrics_data['lyrics'].gsub!( /\n{3,}/, "\n\n" )

		return lyrics_data
	end

	def build_suggestions_fetch_data( artist, title, album=nil, year=nil )
		return { 'url' => "http://#{lyrics_site()}/?q=#{CGI.escape( Strings.utf82latin1( title ) )}&busca=busca&tipo=1" }
	end

	def parse_suggestions( url, body, artist, title, album=nil, year=nil )

		body = Strings.latin12utf8( body )
		body.tr_s!( " \n\r\t", ' ' )

		suggestions = []

		return suggestions if ( ! body.gsub!( /^.*<h2>resultados encontrados: <b>/, '' ) )
		body.gsub!( /<\/ul><center>Sua busca retornou muitos resultados, por favor seja mais.*$/, '' )
		body.gsub!( /<div class='imp'><center><form action='[^']' name='fbs' id='fbs' onsubmit='return cb()'>.*$/, '' )

		body.split( '</small></a>' ).each do |entry|
			md = /<a href='(.+)'>(.+) - (.+)<small>[^<]+/.match( entry )
			next if ( md == nil )
			s_url, s_artist, s_title = md[1], md[2], md[3]
			if ( s_url != '' && s_title != '' && s_artist != '' )
				suggestions << { 'url'=>s_url, 'artist'=>s_artist, 'title'=>s_title }
			end
		end

		return suggestions
	end

end
