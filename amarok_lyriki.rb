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
require 'lyrics_lyriki'
require 'amarokwikilyrics'
require 'utils'
require 'gui'

class AmarokLyriki < Lyriki

	include AmarokWikiLyrics

	def initialize( cleanup_lyrics=true, log_file=$LOG_FILE, review=true, username=nil, password=nil,
					submit=false, prompt_new=false, prompt_autogen=false )
		super( cleanup_lyrics, log_file, review, username, password )
		@submit, @prompt_autogen, @prompt_new = submit, prompt_autogen, prompt_new
		if ( !@submit || !@review )
			@prompt_new = false
			@prompt_autogen = false
		end
	end

end

if ( $0 == __FILE__ )
	AmarokLyriki.new().main()
end
