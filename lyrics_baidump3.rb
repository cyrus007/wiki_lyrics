#  Copyright (C) 2007 by Sergio Pistone
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
require 'iconv'

class BaiduMP3 < Lyrics

	def initialize( cleanup_lyrics=true, log_file=$LOG_FILE )
		super( cleanup_lyrics, log_file )
		@utf2gb = Iconv.new( 'gb18030', 'utf-8' )
		@gb2utf = Iconv.new( 'utf-8', 'gb18030' )
	end

	def BaiduMP3.lyrics_site()
		return 'mp3.baidu.com'
	end

	def BaiduMP3.script_name()
		return 'Baidu MP3'
	end

	def build_lyrics_fetch_data( artist, title, album=nil, year=nil )
		artist = CGI.escape( utf2gb( artist ) )
		title  = CGI.escape( utf2gb( title ) )
		return {'url'=>"http://#{lyrics_site()}/m?f=ms&tn=baidump3lyric&ct=150994944&lf=2&rn=10&word=#{title}+#{artist}&lm=-1"}
	end

	def parse_lyrics( url, body, artist, title, album=nil, year=nil )

		body = gb2utf( body )
		body.tr_s!( " \n\r\t", ' ' )

		lyrics_data = {}

		return lyrics_data if ( ! body.gsub!( /^.*<div style="background-color:white; z-index:10;position:relative;width:75%!important;width:92%">/, '' ) )
		return lyrics_data if ( ! body.gsub!( /<div style="padding-left:12px;padding-right:12px;">/, '' ) )
		body.gsub!( /<div class="pg">.*$/, '' )

		entry = nil

		if ( (md = /&count=([0-9]+)$/.match( url.to_s )) == nil )
			normalized_artist = Strings.normalize_token( artist )
			normalized_title = Strings.normalize_token( title )
			body.split( /<div class="BlueBG"><strong>歌曲：<\/strong><B>/ ).each() do |e|
				e.gsub!( /<font style=color:#e10900>([^<]+)<\/font>/, '\1' )
				md = /([^<]+)<\/B><\/div> <div style="[^"]+"> <strong>歌手：<\/strong><[Aa] href="[^"]+">([^<]+)<\/a> <strong>专辑：<\/strong><[Aa] href="[^"]+">([^<]+)<\/a>/.match( e )
				next if ( md == nil )
				if ( Strings.normalize_token( md[1] ) == normalized_title &&
					 Strings.normalize_token( md[2] ) == normalized_artist )
					lyrics_data['title'], lyrics_data['artist'], lyrics_data['album'] = md[1], md[2], md[3]
					entry = e
					break
				end
			end
		else
			entry = body.split( /<div class="BlueBG"><strong>歌曲：<\/strong><B>/ )[md[1].to_i]
			return lyrics_data if ( entry == nil )
			entry.gsub!( /<font style=color:#e10900>([^<]+)<\/font>/, '\1' )
			md = /([^<]+)<\/B><\/div> <div style="[^"]+"> <strong>歌手：<\/strong><[Aa] href="[^"]+">([^<]+)<\/a> <strong>专辑：<\/strong><[Aa] href="[^"]+">([^<]+)<\/a>/.match( entry )
			return lyrics_data if ( md == nil )
			lyrics_data['title'], lyrics_data['artist'], lyrics_data['album'] = md[1], md[2], md[3]
		end

		if ( entry != nil )
			entry.gsub!( /^.*<div style="padding-left:10px;line-height:20px;padding-top:1px">/, '' )
			entry.gsub!( /(<br> ?){0,}<\/div>.*$/, '' )
			entry.gsub!( /\ ?<br ?\/?> ?/i, "\n" )
			lyrics_data['lyrics'] = entry
		end

		return lyrics_data
	end

	def build_suggestions_fetch_data( artist, title, album=nil, year=nil )
		return build_lyrics_fetch_data( artist, title, album, year )
	end

	def parse_suggestions( url, body, artist, title, album=nil, year=nil )

		body = gb2utf( body )
		body.tr_s!( " \n\r\t", ' ' )

		suggestions = []

		return suggestions if ( ! body.gsub!( /^.*<div style="background-color:white; z-index:10;position:relative;width:75%!important;width:92%">/, '' ) )
		return suggestions if ( ! body.gsub!( /<div style="padding-left:12px;padding-right:12px;">/, '' ) )
		body.gsub!( /<div class="pg">.*$/, '' )

		count = -1
		body.split( /<div class="BlueBG"><strong>歌曲：<\/strong><B>/ ).each() do |entry|
			count += 1
			entry.gsub!( /<font style=color:#e10900>([^<]+)<\/font>/, '\1' )

			log( entry )
			log( "\n\n\n" )

			md = /([^<]+)<\/B><\/div> <div style="[^"]+"> <strong>歌手：<\/strong><[Aa] href="[^"]+&word=([^"]+)">/.match( entry )
			next if ( md == nil )
			s_title  = gb2utf( CGI.unescape( md[1] ) )
			s_artist = gb2utf( CGI.unescape( md[2] ) )
			if ( s_artist != '' && s_title != '' )
				suggestions << { 'url'=>"#{url}&count=#{count}", 'artist'=>s_artist, 'title'=>s_title }
			end
		end

		return suggestions
	end

	def gb2utf( text )
		begin
			return @gb2utf.iconv( text )
		rescue Exception
			log( 'warning: conversion from GB18030 to UTF-8 failed' ) if ( log?() )
			return text
		end
	end

	def utf2gb( text )
		begin
			return @utf2gb.iconv( text )
		rescue Exception
			log( 'warning: conversion from UTF-8 to GB18030 failed' ) if ( log?() )
			return text
		end
	end

end
