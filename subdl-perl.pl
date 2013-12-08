# Download subtitles for a given movie/episode using Opensubtitles API

package SubDL;
use XML::RPC;
use strict;
use warnings;
use MIME::Base64;
use IO::Uncompress::Gunzip qw(gunzip $GunzipError);


sub new
{
    my $class = shift;
    my $self = {
        _movie => shift,
    };
    bless $self, $class;
    # Login
    $self->{_server} = XML::RPC->new('http://api.opensubtitles.org/xml-rpc');
    my $result = $self->{_server}->call( 'LogIn', '', '', 'en', 'SubDL v1');
    print "Login: ", $result->{'status'}, "\n";
    $self->{_token} = $result->{'token'};

    return $self;
}

sub check_status {
  my ( $self, $result ) = @_;
  if (!$result->{'status'} =~ /OK/) {
    print "Request : $result->{'status'}", "\n";
    exit;
  }
}

# Creates a list of ID for subtitles files and filenames for all subtitles found
sub search_subtitles {
  my ( $self ) = @_;
  my $file = $self->{_movie};
  print "Searching for $file\n";

  # Needs both hash and bytes size
  my $hash = $self->OpenSubtitlesHash($file);
  my $size = -s $file;

  my $result = $self->{_server}->call('SearchSubtitles', $self->{_token},
    [{moviehash=> $hash,
        sublanguageid => 'eng',
        moviebytesize=> $size 
      } ]);
  $self->check_status($result);
  print "Found ", scalar(@{$result->{'data'}}), " matches \n";

# Extract the list
  my (@subs, @names);
  foreach(@{$result->{'data'}}) {
    push @subs, $_->{'IDSubtitleFile'};
    push @names, $_->{'SubFileName'};
  }
  # References to array
  $self->{_subs} = [@subs];
  $self->{_names} = [@names];
}

# Download subtitles from a list of id and names
# Arguments : server, token, ref to array of subs, ref to array of names
sub download_subtitles {
  my ($self) = @_;

  # Download them
  print "Downloading \n";
  my $result = $self->{_server}->call('DownloadSubtitles', $self->{_token}, 
    [@{$self->{_subs}}]);
  $self->check_status($result);

  # Decode and extract
  foreach(@{$result->{'data'}}) {
    my $tmp = decode_base64($_->{'data'});
    my $output = shift $self->{_names};
    if (-e $output) { 
      print "File exists, skipping : $output \n";
      next;
    }
    my $z = gunzip(\$tmp, $output) or die "Failed to extract $GunzipError";
  }
}

#-------------------------------------------------------------------------------
# The following is taken from 
# http://trac.opensubtitles.org/projects/opensubtitles/wiki/HashSourceCodes
#-------------------------------------------------------------------------------
sub OpenSubtitlesHash {
  my ( $self, $filename ) = @_;

  open my $handle, "<", $filename or die $!;
  binmode $handle;

  my $fsize = -s $filename;

  my $hash = [$fsize & 0xFFFF, ($fsize >> 16) & 0xFFFF, 0, 0];

  $hash = AddUINT64($hash, ReadUINT64($handle)) for (1..8192);

  my $offset = $fsize - 65536;
  seek($handle, $offset > 0 ? $offset : 0, 0) or die $!;

  $hash = AddUINT64($hash, ReadUINT64($handle)) for (1..8192);

  close $handle or die $!;
  return UINT64FormatHex($hash);
}

sub ReadUINT64 {
  read($_[0], my $u, 8);
  return [unpack("vvvv", $u)];
}

sub AddUINT64 {
  my $o = [0,0,0,0];
  my $carry = 0;
  for my $i (0..3) {
    if (($_[0]->[$i] + $_[1]->[$i] + $carry) > 0xffff ) {
      $o->[$i] += ($_[0]->[$i] + $_[1]->[$i] + $carry) & 0xffff;
      $carry = 1;
    } else {
      $o->[$i] += ($_[0]->[$i] + $_[1]->[$i] + $carry);
      $carry = 0;
    }
  }
  return $o;
}

sub UINT64FormatHex {
  return sprintf("%04x%04x%04x%04x", $_[0]->[3], $_[0]->[2], $_[0]->[1], $_[0]->[0]);
}
sub DESTROY {
  my $self = shift;
  $self->{_server}->call( 'LogOut');
}
1;



#-------------------------------------------------------------------------------
# End of public code
#-------------------------------------------------------------------------------

die "Needs a filename" if ($#ARGV+1 != 1);
my $sub = new SubDL($ARGV[0]);
$sub->search_subtitles();
$sub->download_subtitles();
