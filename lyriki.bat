@echo off
rem AMIP has troubles launching ruby directly.
rem Using a batch file to call lyriki solves this.
ruby.exe lyriki.rb %* 2>NUL