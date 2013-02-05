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

# {{album|
# | image = AlbumArt-Pink Floyd-The Final Cut_(1983).jpg
# | album = The Final Cut
# | artist = Pink Floyd
# | released = <br>March 21, 1983 (UK)<br>April 2, 1983 (US)
# | tracks =
# # [[Pink Floyd:The Post War Dream|The Post War Dream]] <small>(3:02)</small>
# # [[Pink Floyd:Your Possible Pasts|Your Possible Pasts]] <small>(4:22)</small>
# # [[Pink Floyd:One Of The Few|One Of The Few]] <small>(1:22)</small>
# # [[Pink Floyd:The Hero's Return|The Hero's Return]] <small>(2:57)</small>
# # [[Pink Floyd:The Gunners Dream|The Gunners Dream]] <small>(5:06)</small>
# # [[Pink Floyd:Paranoid Eyes|Paranoid Eyes]] <small>(3:46)</small>
# # [[Pink Floyd:Get Your Filthy Hands Off My Desert|Get Your Filthy Hands Off My Desert]] <small>(1:18)</small>
# # [[Pink Floyd:The Fletcher Memorial Home|The Fletcher Memorial Home]] <small>(4:11)</small>
# # [[Pink Floyd:Southampton Dock|Southampton Dock]] <small>(2:11)</small>
# # [[Pink Floyd:The Final Cut|The Final Cut]] <small>(4:46)</small>
# # [[Pink Floyd:Not Now John|Not Now John]] <small>(5:03)</small>
# # [[Pink Floyd:Two Suns In The Sunset|Two Suns In The Sunset]] <small>(5:17)</small>
# }}
#
# {{C:Album|F|Final Cut}}

def convert_page!( page, correct_case=false )
	if ( correct_case )
		page.gsub!( /(\s*\|\s*album\s*=\s*)([^\n]+)/ ) { $1 + Strings.titlecase!( $2, true ) }
		page.gsub!( /(\s*\|\s*artist\s*=\s*)([^\n]+)/ ) { $1 + Strings.titlecase!( $2, true ) }
	end
	convert_song_links!( page, correct_case )
	return page
end

def convert_song_links!( page, correct_case=false )
	# TODO some songs have the info param as <small>(VALUE)</small>
	page.gsub!( /\[\[([^:]+):([^\|]+)\|([^\]]+)\]\] *(<small>\s*\(?)?([0-9]+:[0-9]{2,2})?(\)<\/small>)?/ ) do
		if ( correct_case )
			m1 = Strings.titlecase!( $1, true )
			m2 = Strings.titlecase!( $2, true )
			m3 = Strings.titlecase!( $3, true )
		else
			m1 = $1
			m2 = $2
			m3 = $3
		end
		if ( m2 != m3 )
			"{{song link|#{m1}|#{m2}|#{$5}|disp=#{m3}}}"
		elsif ( º$5 != nil && ! $5.empty?() )
			"{{song link|#{m1}|#{m2}|#{$5}}}"
		else
			"{{song link|#{m1}|#{m2}}}"
		end
	end
	return page
end