subdl-perl
==========

A Perl script for downloading subtitles on the command-line. It will get *all* **english** subtitles for a single TV show episode or a movie from
[OpenSubtitles](www.opensubtitles.org).

Let me know if you want other features (multiple episodes, multiple movies...).

## Usage

    perl subdl-perl YourMovie.mkv
    
This will get all available subtitles in the current folder (unless the file already exists).
The first result is assumed to be the best so it will be renamed accordingly.
The other results will be named with an additional number (MyMovie(1).srt, MyMovie(2).srt and so on).

## Requirements

Perl should be installed. The only module which may not be installed is `XML::RPC`. Install it with :
 
    cpan
    > install XML::RPC
    
Other modules should be in your system already : `MIME::Base64` and `IO::Compress::Gunzip`.    

## Under the hood

The script computes a hash from the file and search all corresponding subtitles with the XML-RPC protocol.
The OpenSubtitles API is used. 
