#!perl
#
# Documentation, copyright and license is at the end of this file.
#

package  Archive::TarGzip;

use 5.001;
use strict;
use warnings;
use warnings::register;

use vars qw($VERSION $DATE $FILE);
$VERSION = '0.02';
$DATE = '2003/09/12';
$FILE = __FILE__;

use vars qw(@ISA @EXPORT_OK);
require Exporter;
use Archive::Tar;
@ISA= qw(Exporter Archive::Tar);
@EXPORT_OK = qw(tar untar parse_header);

use SelfLoader;
use Tie::Gzip;
use Cwd;

######
#
#
sub new
{

     ####################
     # $class is either a package name (scalar) or
     # an object with a data pointer and a reference
     # to a package name. A package name is also the
     # name of a class
     #
     my ($class, @args) = @_;
     $class = ref($class) if( ref($class) );

     ######
     # Parse the last argument as options if it is a reference.
     #
     my $options = {};
     my ($tar_file, $compress);
     if( ref($args[-1]) ) {
          $options = pop @args;
          if(ref($options) eq 'ARRAY') {
              my %options = @{$options};
              $options = \%options;
          }
          ($tar_file, $compress) = @args;
          
     }
     else {
          ($tar_file, $compress, my @options) = @args;
          my %options = @options;
          $options = \%options;
     }

     #######
     # Using the Archive::Tar class and putting layer around it.
     # Bypassing the compress in Archive::Tar and using the 
     # compress herein. In this way if the Compress::Zlib package
     # is not present, the class methods herein will try to fall
     # back onto the gzip operating system common. A lot of Unix
     # ISP do not install Compress:Zlib because the availability of
     # the gzip command.
     #
     my $self = $class->Archive::Tar::new($tar_file, 0, $options);
     $options->{tar_file} = $tar_file if defined $tar_file;
     $options->{compress} = $compress if defined $compress;
     $self->{TarGzipDefault} = $options;
     $self;

}


######
#
#
sub taropen 
{
     my ($self,@args) = @_;

     ######
     # Parse the arguments
     #
     ######
     # Parse the last argument as options if it is a reference.
     #
     my $options = {};
     my ($tar_file, $compress);
     if( ref($args[-1]) ) {
          $options = pop @_;
          if(ref($options) eq 'ARRAY') {
              my %options = @{$options};
              $options = \%options;
          }
          ($tar_file, $compress) = @args;
          
     }
     else {
          ($tar_file, $compress, my @options) = @args;
          my %options = @options;
          $options = \%options;
     }

     ###############
     # The options in taropen method override any default options 
     # establihed by the new method
     #
     my %options = %{$self->{TarGzipDefault}};
     foreach my $key (%$options) {
         $options{$key} = $options->{$key};
     }
  
     $options{compress} = $compress if defined $compress;
     $options{tar_file} = $tar_file if defined $tar_file;
     $options{gz_suffix} = '.gz' unless $options{gz_suffix};
     $options{tar_suffix} = '.tar' unless $options{tar_suffix};
     $self->{TarGzip}  = \%options;

     unless(  defined $options{tar_file} ) {
         warn( "No tar file\n");
         return undef;
     }

     #######
     # Try to find a file by adding extension for the tar and gz
     #
     ($tar_file,$compress) = ($options{tar_file},$options{compress});

     my ($tar_suffix,$gz_suffix) = ($options{tar_suffix},$options{gz_suffix});
     my $targz_suffix = $tar_suffix . $gz_suffix;  
     my $tar_length = length($tar_suffix);
     my $targz_length = length($targz_suffix);

     my $flag = $self->{TarGzip}->{tar_flag};

     #########################
     # Always write to a file using the correct suffices. TarGzip follows very
     # strict rules on what it writes out.
     #
     if( $flag eq '>' ) {
         if( $compress ) {
             $tar_file .= $gz_suffix if substr($tar_file, -$tar_length, $tar_length) eq $tar_suffix;
             $tar_file .= $targz_suffix unless substr($tar_file, -$targz_length, $targz_length) eq $targz_suffix;
         }
         else {
             $tar_file .= $tar_suffix unless substr($tar_file, -$tar_length, $tar_length) eq $tar_suffix;
         }
     }

     ################
     # TarGzip is lenient on the file extensions it accepts for reading.
     #
     else {
         unless( -e $tar_file ) {
             if( $compress ) {
                 $tar_file .= $gz_suffix if substr($tar_file, -$tar_length, $tar_length) eq $tar_suffix;
                 $tar_file .= $targz_suffix unless substr($tar_file, -$targz_length, $targz_length) eq $targz_suffix;
             }
             else {
                 $tar_file .= $tar_suffix unless substr($tar_file, -$tar_length, $tar_length) eq $tar_suffix;
             }
             unless( -e $tar_file ) {
                 warn("Cannot find $tar_file\n");
                 return undef;
             }
         }
     }
     $options{tar_file} = $tar_file;

     ########
     # Use special tie to gzip if compressing
     # the tar file.
     # 
     tie *TAR, 'Tie::Gzip' if $compress;

     ######
     # Open tar file
     #
     unless (open TAR, "$flag $tar_file") {
         warn( "Cannot open $flag $tar_file\n");
         return undef;
     }
     binmode TAR;
     $self->{TarGzip}->{handle} = \*TAR;
     $self->{TarGzip}->{handle};

}



#######
# Close the TAR file
#
sub tarclose
{
     my ($self) = @_;
     my $handle = $self->{TarGzip}->{handle};
     return undef unless $handle;
     print $handle "\0" x 1024 if $self->{TarGzip}->{tar_flag} eq '>'; 
     my $success = close $handle;
     $self->{TarGzip}->{handle} = undef;
     $success;
}

1

__DATA__


#######
# add a file to the TAR file
#
sub taradd
{
     my ($self, $file_name, $file_contents) = @_;
     my $tar = $self->{tar};
     unless( defined $file_contents ) {
         unless (open FILE, $file_name) {
             warn "Cannot open $file_name\n";
             return undef;
         }
         binmode FILE;
         $file_contents = join '', <FILE>;
         close FILE;
 
         ############################
         # Do not add empty files to tar archive file
         #
         return 1 unless $file_contents;

     }
     return undef unless $self->add_data($file_name, $file_contents);

     #####################
     # Set the mode to 0777 for directories so chdir will work;
     # otherwise, a regular file and set the mode to 0666
     #
     $self->{_data}->[0]->{mode} = $file_contents ? 0666 : 0777;
     my $umask = $self->{TarGzip}->{umask};
     $umask = umask unless $umask;
     $self->{_data}->[0]->{mode} &= (0777 - $umask); 
     $self->tarwrite();

     1
}


#######
# 
#
sub tarwrite
{
     my ($self) = @_;
     my $tar_content = &Archive::Tar::format_tar_entry(shift @{$self->{'_data'}});
     my $handle = $self->{TarGzip}->{handle};
     my $bytes_written;
     unless($bytes_written = print $handle $tar_content ) {
          warn "print error\n" ;
          close $self->{TarGzip}->{handle};
          return undef;
     }
     $bytes_written;
}



######
# This is taken directly from big loop in Archive::Tar::read_tar
# Need to get it out of the loop for use in this module
#
sub parse_header
{
     ######
     # This subroutine uses no object data.
     #
     shift @_ if UNIVERSAL::isa($_[0],__PACKAGE__);

     unless(@_) {
         warn "No arguments.\n";
         return undef;
     }

     my ($header) = @_;

     ########
     # Apparently this should really be two blocks of 512 zeroes,
     # but GNU tar sometimes gets it wrong. See comment in the
     # source code (tar.c) to GNU cpio.
     return { end_of_tar => 1 } if $header eq "\0" x 512; # End of tar file
        
     my ($name,		# string
	 $mode,		# octal number
	 $uid,		# octal number
	 $gid,		# octal number
	 $size,		# octal number
	 $mtime,		# octal number
	 $chksum,		# octal number
	 $typeflag,		# character
	 $linkname,		# string
	 $magic,		# string
	 $version,		# two bytes
	 $uname,		# string
	 $gname,		# string
	 $devmajor,		# octal number
	 $devminor,		# octal number
	 $prefix) = unpack($Archive::Tar::tar_unpack_header, $header);
	
     $mode = oct $mode;
     $uid = oct $uid;
     $gid = oct $gid;
     $size = oct $size;
     $mtime = oct $mtime;
     $chksum = oct $chksum;
     $devmajor = oct $devmajor;
     $devminor = oct $devminor;
     $name = $prefix."/".$name if $prefix;
     $prefix = "";
 
     #########
     # some broken tar-s don't set the typeflag for directories
     # so we ass_u_me a directory if the name ends in slash
     $typeflag = 5 if $name =~ m|/$| and not $typeflag;
		
     my $error = '';
     substr($header,148,8) = "        ";
     $error .= "$name: checksum error.\n" unless (unpack("%16C*",$header) == $chksum);
     $error .= "$name: wrong header length\n" unless( $Archive::Tar::tar_header_length == length($header));

     my $end_of_tar = 0;
     # Guard against tarfiles with garbage at the end
     $end_of_tar = 1 if $name eq '';

     warn( $error ) if $error;

     return {
         name => $name,
	 mode => $mode,
	 uid => $uid,
	 gid => $gid,
	 size => $size,
	 mtime => $mtime,
	 chksum => $chksum,
	 typeflag => $typeflag,
	 linkname => $linkname,
	 magic => $magic,
	 version => $version,
	 uname => $uname,
	 gname => $gname,
	 devmajor => $devmajor,
	 devminor => $devminor,
	 prefix => $prefix,
         error => $error,
         end_of_tar => $end_of_tar,
         header_only => 0,
         skip_file => 0,
         data => ''};
}


#####
#
#
sub tarread
{

     my $self = shift @_;

     #######
     # Parse out any options
     #
     my $options;
     if( ref($_[-1]) eq 'ARRAY') {
          $options = $_[-1];
          my %options = @{$options};
          $options = \%options;
     }
     elsif (ref($_[-1]) eq 'HASH') {
          $options = pop @_;
     }

     foreach my $key (keys %$options) {
         $self->{TarGzip}->{$key} = $options->{$key}; 
     }

     ####### 
     # Add any @files to the extract selection hash
     # 
     my $extract_p = $self->{TarGzip}->{extract_files};
     FileList2Sel(@_, $extract_p);
     my $extract_count = keys %$extract_p;

     ########
     # Read header
     #
     my $data;
     return undef unless $self->target(\$data, $Archive::Tar::tar_header_length );

     ########
     # Parse header
     #
     my $file_position = undef;
     $file_position = tell $self->{TarGzip}->{handle};
     my $header = parse_header( $data );
     return undef if $header->{end_of_tar};
     $header->{file_position} = $file_position if $file_position;

     #######
     # Process header_only option
     # 
     $header->{data} = '';
     $header->{header_only} = 0;
     $header->{skip_file} = 0;
     my $buffer_p = \$header->{data};
     if ($self->{TarGzip}->{header_only}) {
         $buffer_p = undef;
         $header->{header_only} = 1;
     }

     #######
     # Process extract file list
     # 
     if( $extract_count && !$extract_p->{$header->{name}} ) {
         $buffer_p = undef;
         $header->{skip_file} = 1;
         $header->{name} = '';
     }

     #######
     # Process exclude file list
     # 
     my $exclude_p = $self->{TarGzip}->{extract_files};
     my $exclude_count = scalar(keys %$exclude_p);
     if( $exclude_count && $exclude_p->{$header->{name}} ) {
         $buffer_p = undef;
         $header->{skip_file} = 1;
         $header->{name} = '';
     }
    
     #######
     # Read file contents
     # 
     my $size = $header->{size};
     return $header unless $size;
     return undef unless $self->target($buffer_p, $header->{size});

     ######
     # Trash bye padding to put on 512 byte boundary
     #
     $size = ($size % 512);
     return $header unless $size;
     $self->target(undef, 512 - $size);
     $header;

}



#####
#
#
sub target
{
     my ($self, $buffer_p, $size) = @_;
     my $handle = $self->{TarGzip}->{handle};
     $handle = $self->{TarGzip}->{handle};
     my $bytes;
     if( $buffer_p ) {
         $$buffer_p = '';
         $bytes = read( $handle, $$buffer_p, $size);
         return undef unless $bytes == $size;
     }
     else {
         seek $handle, $size, 1;
         $bytes = $size;
     }
     $size
}




#######
# Store a number of files in one archive file in the tar format
#
sub tar
{
     ######
     # This subroutine uses no object data.
     #
     shift @_ if UNIVERSAL::isa($_[0],__PACKAGE__);

     ######
     # pop last argument if last argument is an option
     #
     my $options = pop @_ if ref($_[-1]);
     if( ref($options) eq 'ARRAY') {
          my %options = @{$options};
          $options = \%options;
     }

     ##############
     # Rest of the arguments are file names and must
     # have at least one file name
     #
     unless(@_) {
         warn "No files.\n";
         return undef;
     }

     ########
     # Create a new tar file
     #
     $options->{tar_flag} = '>';
     my $tar;  
     return undef unless $tar = new Archive::TarGzip($options);
     return undef unless $tar->taropen();

     #####
     # Bring in some needed program modules
     #   
     require File::Spec;
     require File::AnySpec;

     ######
     # Process dest_dir and src_dir options
     #
     $options->{dest_dir} = '' unless $options->{dest_dir};
     my $dest_dir = $options->{dest_dir};
     $dest_dir = File::AnySpec->os2fspec('Unix',$dest_dir,'nofile');
     $dest_dir .= '/' unless $dest_dir && substr($dest_dir, -1, 1) eq '/';

     $options->{src_dir} = '' unless $options->{src_dir};
     my $src_dir = $options->{src_dir};

     #####
     # change to the source directory
     #
     my $restore_dir = cwd();
     chdir $src_dir if $src_dir;
 
     ########
     # Add destination directory to the tar file
     #
     my $contents;     
     if( $dest_dir ) {
         unless ($tar->taradd($dest_dir, '')) {
             chdir $restore_dir;
             return undef;
         }
     }


     ##########
     # Make a separate copy of @files. Because changes in
     # $file_name are reflected back into @files, if @files
     # is @_, this would be reflected back into the calling
     # @_.
     #
     my @files = @_;

     ##############
     # Keep track of the directories put in tar archive so
     # do not duplicate any.
     #
     my %dirs = (); 
     foreach my $file_name (@files) {
 
         #######
         # Add directory path to the archive file
         #
         (undef, my $file_dir) = File::Spec->splitpath( $file_name ) ;
         my @file_dirs = File::Spec->splitdir($file_dir);
         my $dir_name = $dest_dir;
         foreach $file_dir (@file_dirs) {
             $dir_name = File::Spec::Unix->catdir( $dir_name, $file_dir) if $dir_name;
             unless( $dirs{$dir_name} ) {
                 $dirs{$dir_name} = 1;
                 $dir_name .= '/';
                 unless ($tar->taradd($dir_name, '')) { # add a directory name, no content
                     chdir $restore_dir;
                     return undef;
                 }
             }
         }

         ########
         # Read the contents of the file
         #
         unless( open( CONTENT, "< $file_name") ) {
             $file_name = File::Spec->rel2abs($file_name);
             warn "Cannot read contents of $file_name\n";
             chdir $restore_dir;
             $tar->tarclose( );
             return undef;
         }
         binmode CONTENT;
         my $file_contents = join '',<CONTENT>;
         close CONTENT;

         #######
         # Add the file to the tar archive file
         #  
         $file_name = File::AnySpec->os2fspec('Unix', $file_name);
         $file_name =  File::Spec::Unix->catfile($dest_dir,$file_name) if $dest_dir;
         unless ($tar->taradd($file_name, $file_contents)) {
             chdir $restore_dir;
             return undef;
         }
  
     }
     chdir $restore_dir;

     $tar->tarclose( );
     return $options->{tar_file};
}



#######
#
#
sub untar
{
     ######
     # This subroutine uses no object data.
     #
     shift @_ if UNIVERSAL::isa($_[0],__PACKAGE__);

     ######
     # pop last argument if last argument is an option
     #
     my $options  = {};
     my $tar;  
     if( ref($_[-1]) ) {

         $options = pop @_ ;
         if( ref($options) eq 'ARRAY') {
              my %options = @{$options};
              $options = \%options;
         }
         return undef unless $tar = new Archive::TarGzip($options);

         #######
         # Add any inputs files to the extract file hash
         #
         FileList2Sel(@_, $tar->{TarGzip}->{extract_files});
     }

     else {
         my %options = @_;
         $options = \%options;
         return undef unless $tar = new Archive::TarGzip($options);
     }

     ######
     # Process options
     #
     my $tar_file = $options->{tar_file};
     unless( $tar_file ) {
          warn( "No tar file\n" );
          return undef;
     }

     #####
     # Bring in some needed program modules
     #   
     require File::Spec;
     require File::AnySpec;
     require File::Path;
     File::Path->import( 'mkpath' );

     ########
     # Attach to an existing tar file
     #
     $options->{tar_flag} = '<';
     return undef unless $tar->taropen();


     ########
     # Change to the destination directory where place the 
     # extracted files.
     #
     my $restore_dir = cwd();
     if ($options->{dest_dir}) {
         mkpath($options->{dest_dir});
         chdir $options->{dest_dir};
     }

     my ($tar_dir, $file_name, $dirs);
     while( 1 ) {

         $tar_dir = $tar->tarread( );
         last unless defined $tar_dir;
         last if $tar_dir->{end_of_tar};
         next if $tar_dir->{skip_file};
         my $data = $tar_dir->{data};
         my $typeflag = $tar_dir->{typeflag};
         my $name = $tar_dir->{name};
         $typeflag = 5 if( substr($name,-1,1) eq '/' && !$data);
         $name = File::AnySpec->fspec2os('Unix', $name);
         if( $typeflag == 5 ) {
              mkpath( $name );
              next;
         }

         #######
         # Just in  case the directories where not
         # put in correctly, create them for files
         #
         (undef, $dirs) = File::Spec->splitpath($name);
         mkpath ($dirs);

         ########
         # Extract the file
         #
         open FILE, "> $name";
         binmode FILE;
         print FILE $data;
         close FILE;
     }

     $tar->tarclose( );
     chdir $restore_dir;

     1
}



sub FileList2Sel
{
     my ($list_p, $select_p) = @_;

     #######
     # Add any inputs files to the extract file hash
     #
     $select_p = {} unless $select_p;
     foreach my $item (@$list_p) {
         $item = File::AnySpec->os2fspec( 'Unix', $item );     
         $select_p->{$item} = 1
     };   
}


1


__END__


=head1 NAME

Archive::TarGzip - save and restore files to and from compressed tape archives (tar)

=head1 SYNOPSIS

 ######
 # Subroutine Interface
 #  
 use Archive::TarGzip qw(parse_header tar untar)

 $tar_file = tar(@file, \%options)
 $tar_file = tar(@file, \@options)

 $success = untar(@options)
 $success = untar(\%options)
 $success = untar(\@options)
 $success = untar(@file, \%options)
 $success = untar(@file, \@options)

 \%tar_header = parse_header($buffer)

 ###### 
 # Class Interface
 #
 use Archive::TarGzip
 use vars qw(@ISA)
 @ISA = qw(Archive::TarGzip)

 $tar_file = __PACkAGE__->tar(@file, \%options)
 $tar_file = __PACkAGE__->tar(@file, \@options)

 $success = __PACkAGE__->untar(@options)
 $success = __PACkAGE__->untar(\%options)
 $success = __PACkAGE__->untar(\@options)
 $success = __PACkAGE__->untar(@file, \%options)
 $success = __PACkAGE__->untar(@file, \@options)

 \%tar_header = __PACkAGE__->parse_header($buffer) 

 ######
 # Object Interface
 # 
 use Archive::TarGzip;

 $tar = new Archive::TarGip( ) 
 $tar = new Archive::TarGip( \%options )
 $tar = new Archive::TarGip( \@options ) 
 $tar = new Archive::TarGip( $filename or \*filehandle, \%options )
 $tar = new Archive::TarGip( $filename or \*filehandle, \@options )
 $tar = new Archive::TarGip( $filename or \*filehandle, $compress, @options)

 $tar_handle = $tar->taropen( $tar_file, $compress, [\%options or\@options])
 $success = $tar->taradd($file_name, $file_contents)
 $success  = $tar->tarwrite()

 \%tar_header = $tar->tarread(\%options)
 \%tar_header = $tar->tarread(\@options)
 \%tar_header = $tar->tarread(@file, \%options)
 \%tar_header = $tar->tarread(@file, \@options)

 $status = $tar->target( \$buffer, $size)
 $success = $tar->tarclose()


=head1 DESCRIPTION

The Archive::TarGzip module provides tar subroutine to archive a list of files
in an archive file in the tar format. 
The archve file may be optionally compressed using the gzip compression routines.
The ARchive::TarGzip module also provides a untar subroutine that can extract
the files from the tar or tar/gzip archive files.

The tar and untar top level subroutines use methods from the Archive::TarGzip
class. The Archive::TarGzip class is dervided from its parent Archive::Tar class.
The new methods supplied with the Archive::TarGzip derived class provide means
to access individual files within the archive file without bringing the entire
archive file into memory. When the gzip compression option is active, the
compression is performed on the fly without creating an intermediate uncompressed
tar file. The new methods provide a smaller memory footprint that enhances performance
for very large archive files.

Individual descriptions of the mehods and subroutines follows.

=over 4

=item tar subroutine

 $tar_file = Archive::TarGzip->tar(@file, [\%options or\@options]);
 $tar_file = tar(@file, [\%options or\@options]); # only if imported

The tar subroutine creates a tar archive file containing the files
in the @file list. The name of the file is $option{tar_file}.
The tar subroutine will enforce that the $option{tar_file} has
the .tar or .tar.gz extensions 
(uses the $option{compress} to determine which one).

The tar subroutine will add directories to the @file list in the
correct order needed to create the directories so that they will
be available to extract the @files files from the tar archive file.

If the $option{src_dir} is present, the tar subroutine will change
to the $option{src_dir} before reading the @file list. 
The subroutine will restore the original directory after 
processing.

If the $option{dest_dir} is present, the tar subroutine will
add the $option{dest_dir} to each of the files in the @file list.
The $options{dest_dir} name is only used for the name stored
in the tar archive file and not to access the files from the
site storage.

=item untar subroutine

 $success = Archive::TarGzip->untar([@file], \%options or\@options or @options);
 $success = untar([@file], \%options or\@options or @options); # only if imported

The untar subroutine extracts directories and files from a tar archive file.
The untar subroutine does not assume that the directories are stored in the
correct order so that they will be present as needed to create the files.

The name of the file is $option{tar_file}.
If tar subroutine that cannot find the $option{tar_file},
it will look for file with the .tar or .tar.gz extension 
(uses the $option{compress} to determine which one).

If the $option{dest_dir} is present, the tar subroutine will change
to the $option{dest_dir} before extracting the files from the tar archive file. 
The subroutine will restore the original directory after 
processing.

If the @file list is present or the @{$option{extract_file}} list is present,
the untar subroutine will extract only the files in these lists.

If the @{$option{exclude_file}} list is present, the untar subroutine will not
extract files in this list.

=item new method

 $tar = new Archive::TarGzip( );
 $tar = new Archive::TarGzip( $filename or filehandle, [$compress]);

 $tar = new Archive::TarGzip( \%options or\@options);

The new method creates a new tar object. 
The Archive::TarGzip::new method is the only methods that hides
a  Archive::Tar method with the same name.

The new method passes $filename and $compress inputs to the
Archive::Tar::new method which will read the entire
tar archive file into memory. 

The new method with the $filename is better
when using only the Archive::TarGzip methods.

=item taropen method

 $tar_handle = $tar->taropen( $tar_file, $compress, [\%options or\@options]);

The taropen method opens a $tar_file without bringing
any of the files into memory.

If $options{tar_flag} is '>', the taropen method
creats a new $tar_file; otherwise, 
it opens the $tar_file for reading.

=item taradd method

 $success = $tar->taradd($file_name, $file_contents);

The taradd method appends $file_contents using
the name $file_name 
to the end of the tar archive file taropen for writing.
If $file_contents is undefined, 
the taradd method will use the
contents from the file $file_name.

=item tarwrite method

 $success  = $tar->tarwrite();

The tarwrite method will remove the first file
in the Archive::Tar memory and append it
to the end of the tar archive file taropen for writing.

The tarwrite method uses the $option{compress} to
decide whether use gzip compress or normal writing
of the tar archive file.

=item tarread method

 \%tar_header = $tar->tarread(@file, [\%options or\@options]);
 \%tar_header = $tar->tarread(\%options or\@options);

The tarread method reads the next file from the tar archive file
taropen for reading. 
The tar file header and file contents are returned in
the %tar_header hash along with other information needed
for processing by the Archive::Tar and Archive::TarGzip
classes.

If the $option{header_only} exists the tarread method
skips the file contents and it is not return in the
%tar_header.

If either the @file or the @{$option{extract_files}} list is 
present, the tarread method will check to see if
the file is in either of these lists.
If the file name is not in the @files list or
the @{$option{extract_files}} list,
the tarread method will set the $tar_header{skip_file} key
and all other %tar_header keys are indetermined.

If the @{$option{exclude_files}} list is 
present, the tarread method will check to see if
the file is in this list.
If the file name is in the list,
the tarread method will set the $tar_header{skip_file} key
and all other %tar_header keys are indetermined.

If the tarread method reaches the end of the tar archive
file, it will set the $tar_header{end_of_tar} key and
all other %tar_header keys are indermeined.

The $tar_header keys are as follows:

 name
 mode
 uid
 gid
 size
 mtime
 chksum
 typeflag
 linkname
 magic
 version
 uname
 gname
 devmajor
 devminor
 prefix
 error
 end_of_tar
 header_only
 skip_file
 data
 file_position

=item target method

 $status = $tar->target( \$buffer, $size);

The target method gets bytes in 512 byte chunks from
the tar archive file taropen for reading.
If \$buffer is undefined, the target method skips
over the $size bytes and any additional bytes to pad out
to 512 byte boundaries.

The target method uses the $option{compress} to
decide whether use gzip uncompress or normal reading
of the tar archive file.

=item tarclose method

 $success = $tar->tarclose();

This closes the tar achive opened by the taropen method.

=item parse_header subroutine

 \%tar_header = Archive::TarGzip->parse_header($buffer) ;
 \%tar_header = parse_header($buffer);  # only if imported

The C<parse_header subroutine> takes the pack 512 byte tar file
header and parses it into a the Archive::Tar header hash
with a few additional hash keys.
This is the return for the C<target method>.

=back

=head1 REQUIREMENTS

The requirements are coming.

=head1 DEMONSTRATION

 ~~~~~~ Demonstration overview ~~~~~

Perl code begins with the prompt

 =>

The selected results from executing the Perl Code 
follow on the next lines. For example,

 => 2 + 2
 4

 ~~~~~~ The demonstration follows ~~~~~

 =>     use File::Package;
 =>     use File::AnySpec;
 =>     use File::SmartNL;
 =>     use File::Spec;

 =>     my $fp = 'File::Package';
 =>     my $snl = 'File::SmartNL';
 =>     my $uut = 'Archive::TarGzip'; # Unit Under Test
 =>     my $loaded;
 => my $errors = $fp->load_package($uut)
 => $errors
 ''

 =>      my @files = qw(
 =>          lib/Data/Str2Num.pm
 =>          lib/Docs/Site_SVD/Data_Str2Num.pm
 =>          Makefile.PL
 =>          MANIFEST
 =>          README
 =>          t/Data/Str2Num.d
 =>          t/Data/Str2Num.pm
 =>          t/Data/Str2Num.t
 =>      );
 =>      my $file;
 =>      foreach $file (@files) {
 =>          $file = File::AnySpec->fspec2os( 'Unix', $file );
 =>      }
 =>      my $src_dir = File::Spec->catdir('TarGzip', 'expected');
 => Archive::TarGzip->tar( @files, {tar_file => 'TarGzip.tar.gz', src_dir  => $src_dir,
 =>             dest_dir => 'Data-Str2Num-0.02', compress => 1} )
 'TarGzip.tar.gz'

 => Archive::TarGzip->untar( dest_dir=>'TarGzip', tar_file=>'TarGzip.tar.gz', compress => 1)
 1

 => $snl->fin(File::Spec->catfile('TarGzip', 'Data-Str2Num-0.02', 'MANIFEST'))
 'lib/Docs/Site_SVD/Data_Str2Num.pm
 MANIFEST
 Makefile.PL
 README
 lib/Data/Str2Num.pm
 t/Data/Str2Num.d
 t/Data/Str2Num.pm
 t/Data/Str2Num.t'

 => $snl->fin(File::Spec->catfile('TarGzip', 'expected', 'MANIFEST'))
 'lib/Docs/Site_SVD/Data_Str2Num.pm
 MANIFEST
 Makefile.PL
 README
 lib/Data/Str2Num.pm
 t/Data/Str2Num.d
 t/Data/Str2Num.pm
 t/Data/Str2Num.t'

=head1 QUALITY ASSURANCE

Running the test script 'Gzip.t' found in
the "Archive-TarGzip-$VERSION.tar.gz" distribution file verifies
the requirements for this module.

All testing software and documentation
stems from the 
Software Test Description (L<STD|Docs::US_DOD::STD>)
program module 't::Archive::TarGzip',
found in the distribution file 
"Archive-TarGzip-$VERSION.tar.gz". 

The 't::Archive::TarGzip' L<STD|Docs::US_DOD::STD> POD contains
a tracebility matix between the
requirements established above for this module, and
the test steps identified by a
'ok' number from running the 'Gzip.t'
test script.

The t::Archive::TarGzip' L<STD|Docs::US_DOD::STD>
program module '__DATA__' section contains the data 
to perform the following:

=over 4

=item *

to generate the test script 'Gzip.t'

=item *

generate the tailored 
L<STD|Docs::US_DOD::STD> POD in
the 't::Archive::TarGzip' module, 

=item *

generate the 'Gzip.d' demo script, 

=item *

replace the POD demonstration section
herein with the demo script
'Gzip.d' output, and

=item *

run the test script using Test::Harness
with or without the verbose option,

=back

To perform all the above, prepare
and run the automation software as 
follows:

=over 4

=item *

Install "Test_STDmaker-$VERSION.tar.gz"
from one of the respositories only
if it has not been installed:

=over 4

=item *

http://www.softwarediamonds/packages/

=item *

http://www.perl.com/CPAN-local/authors/id/S/SO/SOFTDIA/

=back
  
=item *

manually place the script tmake.pl
in "Test_STDmaker-$VERSION.tar.gz' in
the site operating system executable 
path only if it is not in the 
executable path

=item *

place the 't::Archive::TarGzip' at the same
level in the directory struture as the
directory holding the 'Tie::Gzip'
module

=item *

execute the following in any directory:

 tmake -test_verbose -replace -run -pm=t::Archive::TarGzip

=back



=head1 NOTES

=head2 FILES

The installation of the
"Archive-TarGzip-$VERSION.tar.gz" distribution file
installs the 'Docs::Site_SVD::Archive_TarGzip'
L<SVD|Docs::US_DOD::SVD> program module.

The __DATA__ data section of the 
'Docs::Site_SVD::Archive_TarGzip' contains all
the necessary data to generate the POD
section of 'Docs::Site_SVD::Archive_TarGzip' and
the "Archive-TarGzip-$VERSION.tar.gz" distribution file.

To make use of the 
'Docs::Site_SVD::Archive_TarGzip'
L<SVD|Docs::US_DOD::SVD> program module,
perform the following:

=over 4

=item *

install "ExtUtils-SVDmaker-$VERSION.tar.gz"
from one of the respositories only
if it has not been installed:

=over 4

=item *

http://www.softwarediamonds/packages/

=item *

http://www.perl.com/CPAN-local/authors/id/S/SO/SOFTDIA/

=back

=item *

manually place the script vmake.pl
in "ExtUtils-SVDmaker-$VERSION.tar.gz' in
the site operating system executable 
path only if it is not in the 
executable path

=item *

Make any appropriate changes to the
__DATA__ section of the 'Docs::Site_SVD::Archive_TarGzip'
module.
For example, any changes to
'Tie::Gzip' will impact the
at least 'Changes' field.

=item *

Execute the following:

 vmake readme_html all -pm=Docs::Site_SVD::Archive_TarGzip

=back

=head2 AUTHOR

The holder of the copyright and maintainer is

E<lt>support@SoftwareDiamonds.comE<gt>

=head2 COPYRIGHT NOTICE

Copyrighted (c) 2002 Software Diamonds

All Rights Reserved

=head2 BINDING REQUIREMENTS NOTICE

Binding requirements are indexed with the
pharse 'shall[dd]' where dd is an unique number
for each header section.
This conforms to standard federal
government practices, 490A (L<STD490A/3.2.3.6>).
In accordance with the License, Software Diamonds
is not liable for any requirement, binding or otherwise.

=head2 LICENSE

Software Diamonds permits the redistribution
and use in source and binary forms, with or
without modification, provided that the 
following conditions are met: 

=over 4

=item 1

Redistributions of source code must retain
the above copyright notice, this list of
conditions and the following disclaimer. 

=item 2

Redistributions in binary form must 
reproduce the above copyright notice,
this list of conditions and the following 
disclaimer in the documentation and/or
other materials provided with the
distribution.

=back

SOFTWARE DIAMONDS, http::www.softwarediamonds.com,
PROVIDES THIS SOFTWARE 
'AS IS' AND ANY EXPRESS OR IMPLIED WARRANTIES,
INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT
SHALL SOFTWARE DIAMONDS BE LIABLE FOR ANY DIRECT,
INDIRECT, INCIDENTAL, SPECIAL,EXEMPLARY, OR 
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE,DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING USE OF THIS SOFTWARE, EVEN IF
ADVISED OF NEGLIGENCE OR OTHERWISE) ARISING IN
ANY WAY OUT OF THE POSSIBILITY OF SUCH DAMAGE. 

=for html
<p><br>
<!-- BLK ID="NOTICE" -->
<!-- /BLK -->
<p><br>
<!-- BLK ID="OPT-IN" -->
<!-- /BLK -->
<p><br>
<!-- BLK ID="EMAIL" -->
<!-- /BLK -->
<p><br>
<!-- BLK ID="COPYRIGHT" -->
<!-- /BLK -->
<p><br>
<!-- BLK ID="LOG_CGI" -->
<!-- /BLK -->
<p><br>

=cut

### end of file ###